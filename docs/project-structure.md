# Project structure

Where files go and what things are called. The decision and its reasoning live in [ADR 12](../decisions/2026-08-17-project-structure.md) — this document is the map you check while building, and it is updated as folders appear.

The Godot project is the **`warehouse-manager/` subfolder**, not the repo root. Any `--path` argument points there.

## The map

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
├── scripts/
│   ├── main/         main.gd
│   ├── levels/       test_room.gd
│   ├── world/
│   ├── goods/
│   ├── player/       player.gd
│   ├── ui/
│   ├── components/
│   ├── autoloads/    net.gd                                     ← script-only domain
│   └── net/          net_transport.gd, enet_transport.gd,        ← script-only domain
│                     steam_transport.gd
├── resources/                         .tres by domain — resources/goods/…
├── assets/                            Art pipeline output — models/ materials/ textures/ audio/
└── test/                              See test/README.md
    ├── smoke/                         Every scene loads and instances
    ├── integration/                   Two real processes over real ENet
    └── unit/                          Pure logic — the condition model and dilemma maths
```

The suite is one command, `./tools/run-tests.ps1`, and runs automatically on push via the `pre-push` hook. `tools/hooks/pre-push` is the tracked copy — git only runs hooks from the untracked `.git/hooks/`, so it needs installing once per clone.

Folders are created **on first use**. Empty directories are not tracked by git and rot; `world/`, `goods/`, `ui/`, `resources/`, `assets/` and `test/` above are the agreed destinations, not existing folders.

## The rules

**`scripts/` mirrors `scenes/` subfolder-for-subfolder.** A scene's script sits at the mirrored path with the same basename: `scenes/player/player.tscn` ↔ `scripts/player/player.gd`.

**Subfolders are domains, not node types.** No `entities/`. A new domain has to be a real system, not a home for one file.

**`levels/` versus `world/`:** a level is a whole map you can play. A fixture is a thing placed inside one. The test room is a level; a rack is a fixture.

**Script-only domains are normal.** `net/` and `autoloads/` have no counterpart under `scenes/` and must not be given an empty one.

**Autoloads are a last resort, and there is currently one.** `Net` earns it: session lifecycle is genuinely global and genuinely single. Nothing else has, and the bar is deliberately high — an autoload is global mutable state that also **destroys testability in a way that fails silently**. A script with a `class_name` that touches an autoload cannot be loaded in a `--script` run, because autoloads are not registered there. That has already bitten this project once, and the shape of it is nasty: the test file failed to compile *after* reporting a pass.

So, before adding one, in order:

1. **Pure static functions or a `RefCounted`** — `CargoCondition` and `Dilemma` are this. No tree, no globals, unit-testable in a bare `--script` run.
2. **A node in the level**, found by group. `CarryAuthority` is this: every level needs exactly one referee, and `add_to_group("carry_authority")` survives the tree being rearranged without a global.
3. **An autoload**, only if it must outlive every scene *and* be reachable from everywhere.

The coming temptations are a day clock, a client roster and an economy ledger (Phases 3–4). Each is reachable from the level instead. **Keep game rules out of autoloads** — the moment `Dilemma` reads a global, the unit layer stops compiling and says so only by disappearing.

**Scene or plain script?** A scene when the thing needs a node tree — visuals, collision, child nodes — or is instanced more than once at runtime. A plain script when it's pure logic, a base class or interface, or a `Resource` type.

| | Example | Why |
|---|---|---|
| Scene | `crate.tscn` | Mesh, collision shape, instanced constantly |
| Plain script | `enet_transport.gd` | No tree, one instance, pure logic |
| Plain script | `net_transport.gd` | An interface — nothing to put in a tree |

## Naming

| Thing | Rule | Example |
|---|---|---|
| Script and scene files | `snake_case` | `test_room.gd`, `test_room.tscn` |
| Scene root node | `PascalCase` of the file basename | `test_room.tscn` → `TestRoom` |
| `class_name` | Matches the root node name | `class_name TestRoom` |
| Nodes inside a scene | `PascalCase`, named for **role**, never type | `BodyMesh`, `CameraPivot`, `SpawnPoints` |
| Resources | `snake_case.tres` under `resources/<domain>/` | `resources/goods/glassware.tres` |

**No engine-default node names survive.** `Camera` is fine; `Camera3D` is not — the type is already visible in the editor and in the script's type hint. `MeshInstance3D2` is a bug report waiting to happen.

**`class_name` is declared when another script refers to the type** — `Player`, `TestRoom`, `NetTransport`. Omitted for one-off scene glue like `main.gd`, where a global name buys nothing and pollutes autocomplete.

Code style — static typing, script section order, past-tense signals — is governed separately and is not repeated here.

## Physics layers

Named in `project.godot` (`layer_names/3d_physics/layer_N`) and pinned in `test/api/engine_assumptions.gd` so a new layer cannot appear silently inside a `.tscn`.

| Layer | Name | Bit value | What lives there |
|---|---|---|---|
| 1 | `world` | 1 | Static level geometry — floors, walls, dock doors |
| 2 | `players` | 2 | Player capsules. Deliberately does not share a mask with cargo — a puppet capsule's position is written rather than simulated, so a shared mask lets the solver bulldoze cargo at full walking speed |
| 3 | `cargo` | 4 | Crates and other held or thrown goods — host-simulated rigid bodies |
| 4 | `storage` | 8 | Rack cell aim-volumes (Phase 1) — `Area3D`s with `monitoring` and `monitorable` both off, hittable by the grab ray without joining the cargo layer |

## ⚠ Node names are protocol, not decoration

The rule most likely to be broken by accident and the most expensive when it is.

`player.gd` derives its multiplayer authority from `name.to_int()`, and `MultiplayerSpawner` matches nodes across peers by path. **Renaming a networked node does not fail locally.** It fails on *remote* peers, as an authority mismatch, with no error and no warning.

So: any node whose name encodes identity carries a comment saying so, and renaming one is a netcode change, not a tidy-up.

## ⚠ A new `class_name` is invisible to headless runs until the editor rescans

Global class names live in `.godot/global_script_class_cache.cfg`, and **only the editor writes it.** Add a script with a new `class_name` on disk and a headless run will fail with `Parse Error: Could not find type "X" in the current scope` — on every file that refers to it, which makes it look like a much bigger breakage than it is.

The fix is a rescan, not a code change:

```gdscript
EditorInterface.get_resource_filesystem().scan()
```

Then confirm before re-running, rather than hoping:

```bash
grep -E '"(YourNewClass)"' warehouse-manager/.godot/global_script_class_cache.cfg
```

## Moving a file later

Every script has a `.uid` sidecar, so UIDs survive a move and a stale path still resolves — which makes a botched move **silent rather than loud**. If a move is unavoidable:

1. Close the Godot editor first. An open editor can rewrite scenes from its in-memory copy.
2. Move the `.gd`, its `.gd.uid`, and the `.tscn` together, with `git mv` so history follows.
3. Update the `path=` string in every `.tscn` that referenced it, and every `preload()` that named it.
4. Run the paired headless test before trusting it. Loading a scene is what proves the references, not the editor opening without complaint.
