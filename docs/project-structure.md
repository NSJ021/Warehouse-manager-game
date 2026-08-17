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
└── test/                              Unit tests mirroring scripts/, plus integration/
```

Folders are created **on first use**. Empty directories are not tracked by git and rot; `world/`, `goods/`, `ui/`, `resources/`, `assets/` and `test/` above are the agreed destinations, not existing folders.

## The rules

**`scripts/` mirrors `scenes/` subfolder-for-subfolder.** A scene's script sits at the mirrored path with the same basename: `scenes/player/player.tscn` ↔ `scripts/player/player.gd`.

**Subfolders are domains, not node types.** No `entities/`. A new domain has to be a real system, not a home for one file.

**`levels/` versus `world/`:** a level is a whole map you can play. A fixture is a thing placed inside one. The test room is a level; a rack is a fixture.

**Script-only domains are normal.** `net/` and `autoloads/` have no counterpart under `scenes/` and must not be given an empty one.

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
