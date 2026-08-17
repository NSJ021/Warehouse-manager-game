# Project structure, file layout and naming conventions

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ

## Context

Code *style* has been governed since the start — static typing everywhere, script section order, `snake_case` functions, past-tense signals. What was never agreed is everything one level up: which folders exist, what goes in them, when something is a scene versus a plain script, and how nodes inside a scene are named. All of it was invented file-by-file while building the Phase 0 netcode spine.

The cost of deciding late is specific, and it is not "some refactoring". Moving a script rewrites the `path=` string in every `.tscn` that references it and every `preload()` that names it. Every script in the project already has a `.uid` sidecar, so UIDs survive a move and a stale path still resolves — which makes a botched move *silent* rather than loud. That is worse than a hard error. Right now the project is ten files and the whole thing is a five-minute job. Phase 1 adds racks, rack slots, grid logic and two zone types; Phase 2 adds goods, size classes and a day clock. The window closes at Phase 1.

Two layouts were genuinely in play:

- **Split parallel trees** — `scenes/` mirrored by `scripts/`. What Phase 0 already does.
- **Feature co-location** — one folder per feature, script sitting next to its scene.

Co-location is the fashionable answer and it has a real argument: you see everything a feature owns in one place, and you move a feature by moving one folder. But the project's shared Godot conventions — the ones its code-generation tooling applies, across this developer's other Godot projects too — already prescribe split trees, `snake_case` files and `PascalCase` nodes. Those conventions defer to a project that states its own layout, so diverging is *allowed*; it just has to be worth paying for on every generated file forever. It isn't. Split trees also give the scripts that have no scene at all — the transports, the autoload — an obvious home, which co-location has to invent a special case for.

## Decision

**Split parallel trees, confirmed.** `scripts/` mirrors `scenes/` subfolder-for-subfolder. A scene's script lives at the mirrored path with the same basename: `scenes/player/player.tscn` ↔ `scripts/player/player.gd`.

**Subfolders are domains, not node types.** This is the one deliberate deviation from the shared conventions, which suggest `entities/ ui/ levels/ components/`. `entities/` is a bag: by Phase 2 it would hold the player capsule, the crate, the rack and the dock door, which have nothing in common except being things. Domains stay legible as the project grows.

```
warehouse-manager/
├── scenes/
│   ├── main/         main.tscn        Entry point and menu shell
│   ├── levels/       test_room.tscn   Whole playable maps
│   ├── world/                         Fixtures placed inside levels: racks, shelving, dock doors, zones
│   ├── goods/                         Cargo and its size variants
│   ├── player/       player.tscn      The capsule
│   ├── ui/                            HUD, prompts, menus beyond the shell
│   └── components/                    Sub-scenes instanced into other scenes
├── scripts/                           Mirrors scenes/ exactly, plus two script-only domains:
│   ├── autoloads/    net.gd
│   └── net/          net_transport.gd, enet_transport.gd, steam_transport.gd
├── resources/                         .tres by domain — resources/goods/…
├── assets/                            Art pipeline output — models/ materials/ textures/ audio/
└── test/                              Unit tests mirroring scripts/, plus integration/
```

**Folders are created on first use.** No speculative empty directories: git cannot track them and they rot.

**`levels/` and `world/` are separate, and that distinction is load-bearing.** A level is a whole map you can play. A fixture is a thing placed inside one. Collapsing them recreates the `entities/` bag with extra steps.

**Script-only domains are normal.** `net/` and `autoloads/` have no counterpart under `scenes/` and must not be given an empty one.

**Scene versus plain script.** A scene exists when the thing needs a node tree — visuals, collision, child nodes — or is instanced more than once at runtime. A plain script when it is pure logic, a base class or interface, or a `Resource` type. The transports are scripts because they have no tree; `NetTransport` is a script because it is an interface. The crate is a scene.

**Naming, all of it:**

| Thing | Rule | Example |
|---|---|---|
| Script and scene files | `snake_case` | `test_room.gd`, `test_room.tscn` |
| Scene root node | `PascalCase` of the file basename | `test_room.tscn` → `TestRoom` |
| `class_name` | Matches the root node name | `class_name TestRoom` |
| Nodes inside a scene | `PascalCase`, named for **role**, never type | `BodyMesh`, `CameraPivot`, `SpawnPoints` |
| Resources | `snake_case.tres` under `resources/<domain>/` | `resources/goods/glassware.tres` |

**No engine-default node names survive.** `MeshInstance3D2` is a bug report waiting to happen. `Camera` is fine; `Camera3D` is not, because the type is already visible in the editor and in the script's type hint.

**`class_name` is declared when another script refers to the type** — `Player`, `TestRoom`, `NetTransport`, `ENetTransport`, `SteamTransport`. It is omitted for one-off scene glue such as `main.gd`, where a global name buys nothing and pollutes autocomplete.

**Node names are protocol, not decoration.** This is the rule most likely to be broken by accident and the most expensive when it is. `player.gd` derives its multiplayer authority from `name.to_int()`, and `MultiplayerSpawner` matches nodes across peers by path. Renaming a networked node does not fail locally — it fails on *remote* peers, as an authority mismatch, with no error. Therefore: **any node whose name encodes identity carries a comment saying so**, and renaming one is a netcode change, not a tidy-up.

**One move lands with this ADR:** `test_room.{tscn,gd}` moves from `world/` to `levels/`, because a convention that starts out violated by the only example in the project is not a convention.

## Consequences

**Easier:** the layout now matches what the code-generation tooling produces, so generated and hand-written files are indistinguishable and neither has to be corrected. Phase 1 has somewhere obvious to put racks, slots and zones before it needs it. Reviewing a diff tells you which domain changed from the paths alone.

**Harder:** every new scene touches two trees, so adding a file is two directory decisions rather than one. Renaming a domain is a wide diff. Both accepted — they are the standing cost of split trees, and they are lower than the cost of the alternative on every generated file.

**Rules out:** feature co-location, unless a later ADR supersedes this one *and* budgets the path rewrite. Also rules out silently adding a folder: a new domain needs to be a real system, not a home for one file.

**Follow-up:** `test/` is described here but does not exist yet — it arrives with the integration harness, which is the other pre-Phase-1 foundation. `assets/` arrives with the first GLB from the art pipeline, which is deliberately silent about `res://` paths and now defers to this map.

## Alternatives considered

**Feature co-location** (`game/player/player.tscn` + `player.gd` together) — better cohesion, one folder to move a feature, and genuinely the stronger layout in the abstract. Rejected because the project's shared Godot conventions prescribe split trees, so co-location would mean correcting the path of every generated file for the life of the project, and because script-only domains need a special case under it.

**The shared conventions verbatim** (`entities/ ui/ levels/ components/`) — zero deviation, nothing to write down. Rejected on `entities/`: a folder that will hold the capsule, the crate, the rack and the dock door is a folder that tells you nothing.

**A single `src/` tree, no scenes/scripts split** — fewest directory decisions. Rejected for the same tooling-friction reason as co-location, with none of its cohesion benefit.
