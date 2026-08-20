# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-17)

**Core value:** The dilemma is the game — patch and hope, confess, or comp.
**Current focus:** Phase 1, Storage

> **Narrative history lives in `docs/conversation-log.md`, not here.** This file tracks
> execution position only. Duplicating the story in two places guarantees one of them
> goes stale.

## Current Position

Phase: 1 of 7 (Storage)
Plan: **01-01, 01-02, 01-03 and 01-05 complete** — waves 1–2 done, wave 3 half done (01-05
landed; 01-04 still executing in parallel), 5 of 9 plans remaining
Status: **Executing** — wave 3: 01-05 (Goods IN/OUT zones) complete; 01-04 (place/retrieve)
still in progress in a parallel session against the same working tree
Last activity: 2026-08-20 — 01-05 executed: `GoodsZone` (Area3D, zero networking machinery,
kind IN/OUT with the difference derived locally) landed, with `GoodsIn`/`GoodsOut` placed in the
test room and both peers independently proven to agree on a zone's contents over real ENet. Two
real bugs found and fixed only by running the suite repeatedly rather than trusting one green
run — see the 01-05 block below. Before that: 01-03 executed: `Rack` (12-cell occupancy, atomic
by kind, LIFO, visuals derived from state) landed against ADR 18, with a greybox scene, twelve
per-cell aim volumes, a zero-cost `racked_item.tscn`, two racks placed in the test room, and
host-side crate minting. Before that: 01-02 executed: `StorageGrid` cell arithmetic (ADR 18)
landed test-first, 183 unit checks, wired into the suite's `unit/` stage alongside
`dilemma_maths.gd`. Before that: 01-01 executed, `queue_free()` despawn replication proven on
both peers (no fallback needed), physics layer 4 named `storage` and asserted. Before that: solo
drag built and proved (ADR 19); detection and patch maths settled and put under test (ADR 20);
the economy settled (ADRs 21–22); a `unit/` test layer now exists; plan 01-04 patched for ADR 19
before execution

Progress: [███░░░░░░░] Phase 0 complete bar one blocked item; Phase 1 waves 1-2 of 7 done, wave 3
half done (4/9 plans)

> **⚠ Read before executing Phase 1.** The nine plans were written on 2026-08-17, **before**
> solo drag existed, and **not one of them mentions it**.
>
> **All nine have now been audited** — 01-04 on 2026-08-19, the other eight immediately after,
> against ADRs 17 and 19–22 and against what is actually on disk. **The patches live only on this
> machine**: `.planning/phases/` is in `.git/info/exclude`, so they are not committed and will not
> survive a fresh clone. This block is the durable record.
>
> **Six conflicts found and patched:**
>
> | Plan | Conflict | Patch |
> |---|---|---|
> | **01-01** | Despawn probe used `crate_5` — now `LOST_CRATE_NAME`, the supply-conservation crate. Freeing it would have failed the integration layer a few steps later. | Moved to `crate_2`; a crate-name allocation table added so this stops recurring. It had already happened twice. |
> | **01-02** | Task 3 built the `unit/` layer, renumbered the banners to `[1/4]…[4/4]` and rewrote the README row. **All three already exist** (built 2026-08-19). | Task 3 rewritten: the real work is that the unit stage runs *one hardcoded script*, so it must enumerate `test/unit/*.gd` and require a `PASS` marker from each. |
> | **01-02** | Objective and house-style reference both assumed `test/unit/` was empty. | Corrected; `dilemma_maths.gd` named as the precedent to follow. |
> | **01-04** | The ADR 19 patch added the drag rule host-side but never updated the client-side `try_toggle_hold()` branch table. | Two dragging rows added, with the reason spelled out. |
> | **01-06** | Highlight table says it matches 01-04's "exactly" — and had no drag rows. A dragger would see a top-row cell painted green, then be silently refused, breaking the one invariant this plan exists to protect. | Two dragging rows added; above-floor = BLOCKED, not NONE, because "not noticed" and "refused" must not look alike. |
> | **01-08** | Presented floor stacking as an open blocking decision. **ADR 17 decided it and 01-09 builds it in the wave before.** Its rack-geometry option also quoted superseded ADR 16 numbers (4 columns, 0.8 m pitch) that contradict ADR 18, and its context block loaded ADR 16 rather than ADR 18. | Stacking fork replaced with a *verification* of ADR 17; geometry option rescoped to the rack frame only; ADR references swapped; ADRs 19–22 flagged as new rows in the log. |
>
> **Three interactions flagged rather than patched**, recorded in the plans themselves:
> **01-05 ↔ 01-09** — the zone probe crate will settle static in wave 6, and if `Area3D` does not
> report frozen bodies the zone count silently drops to 0 and reads as a 01-09 regression. That
> is a real design constraint on zones, since Goods OUT must detect stock sat there all day.
> **01-07** — a dragged crate tops out near 1.7 m/s and can never reach the 4.0 m/s shed
> threshold; correct, but it should be a conscious call at the gate.
> **01-09** — checked clean against ADR 19: "never settle while `_holders` is not empty" already
> covers dragging, and `add_holder()` wakes a settled crate. No special case needed.
>
> **Also corrected: `gsd-tools phase-plan-index` reports 01-04 as wave 1.** Its frontmatter and
> ROADMAP.md both say wave 3, `depends_on: ["01-03"]`. The tool is wrong; trust the frontmatter,
> or place/retrieve runs before the rack it places into exists.

**Next session: finish wave 3, then continue to wave 4.** 01-05 (Goods IN/OUT zones) is complete.
01-04 (place and retrieve) was still executing in a parallel session against the same working
tree as of 01-05's completion — check for its SUMMARY before resuming; if absent, `/gsd:execute-phase 1`
from a fresh context should pick it up (it depends only on 01-03, already complete).

Three things to carry in, from the audit above and from 01-05's own execution:

- **`gsd-tools phase-plan-index` still misreports 01-04 as wave 1.** It depends on 01-03. Read
  the frontmatter, not the tool.
- **01-04 is the first plan to touch the referee**, and the drag rule now lives in two places:
  host-side validation in `request_place`, and the client-side branch table that 01-06 copies.
  Both were patched; keep them saying the same thing.
- **The integration harness's `_take()` helper is deliberately unawaited at every call site** —
  tried awaiting it, made a different failure worse (see the 01-05 block below). If a future plan
  is tempted to "fix" this, read that block and `_take()`'s own docstring first.

> **01-01 resolved 2026-08-19: `queue_free()` despawn replication holds, no fallback needed.**
> A despawn probe in `carry_session.gd` has the host free a crate spawned through the level's
> custom `spawn_function`, and both host and client independently observe it gone. **Plans
> 01-03 onward can rely on plain `queue_free()`** for "racked = freed, not frozen" (ADR 14) —
> none of the three ranked fallbacks (RPC-based despawn, `set_visibility_for()`, escalation)
> were needed. Physics layer 4 is named `storage`, asserted in the api test layer, and
> documented in `docs/project-structure.md`. Full detail, including two harness-race deviations
> found and fixed along the way: `.planning/phases/01-storage/01-01-SUMMARY.md` (local-only,
> see the note above on `.planning/phases/`).

> **01-02 resolved 2026-08-19: `StorageGrid` cell arithmetic (ADR 18) landed test-first.**
> `scripts/world/storage_grid.gd` — pure static functions, no nodes, no state — covers cell
> count, index↔coords↔centre conversion, out-of-rack detection (`-1`, with the half-open
> boundary rule asserted on all six faces plus one internal seam), the 2×2×2 Small lattice, and
> an exact-inverse LIFO fill/remove pair. `test/unit/storage_grid_test.gd` was written and run
> against nothing first — observed failing by naming the missing script, not crashing — then
> made to pass: 183 checks, 0 failures. `tools/run-tests.ps1`'s `unit/` stage now enumerates
> `test/unit/*.gd` rather than one hardcoded path, so the next pure module costs nothing to add.
> **Coordinate order is non-obvious and documented in the file itself**: `cell_coords()` returns
> `Vector3i(column, depth, level)`, not world axes — `cell_centre()` is the one place that gets
> remapped onto Godot's actual x/y/z. 01-03 needs to read that comment before writing rack
> placement code against it. Full detail: `.planning/phases/01-storage/01-02-SUMMARY.md`
> (local-only, see the note above on `.planning/phases/`).

> **01-03 resolved 2026-08-19: the rack fixture landed against ADR 18.** `Rack`
> (`scripts/world/rack.gd`) holds 12 cells as `{kind, ids}`, delegating every dimension to
> `StorageGrid` (12 `StorageGrid.` calls, zero direct `CELL_SIZE` arithmetic — both grepped).
> `can_accept()` enforces atomicity; `add_to_cell`/`remove_from_cell` are LIFO; `apply_cell_filled`/
> `apply_cell_cleared` are the broadcast entry points 01-04's host-authoritative RPCs will call.
> `rack.tscn` is a CSG greybox with **twelve** individual `CellSensor` `Area3D` volumes — one per
> cell rather than one covering the whole rack, because a single hull would only ever return its
> front surface to a raycast and a buried back-row cell would be permanently unaimable.
> `racked_item.tscn` is a bare `MeshInstance3D` — no body, no collision, no synchronizer, grepped
> at 0. Two racks (`rack_wall`, `rack_island`) are in the test room, named exactly as the plan
> specified since 01-04 resolves a rack over the wire by group and name. `TestRoom.spawn_crate_at()`
> mints from a monotonic counter shared with the starting batch; `Crate` gained `id`/`kind`.
> **One deviation, caught by the integration suite doing its job**: the wall rack's first placement
> (against the north wall, centred near the crate row) collided with the drag scenario's step-back
> point — the dragged crate hit the rack's own frame and the test timed out. Fixed by moving both
> racks to the room's east side; no test code changed. Full detail:
> `.planning/phases/01-storage/01-03-SUMMARY.md` (local-only, see the note above on
> `.planning/phases/`).

> **01-05 resolved 2026-08-20: Goods IN / Goods OUT zones landed with zero networking machinery.**
> `GoodsZone` (`scripts/world/goods_zone.gd`) is a plain `Area3D` — no `MultiplayerSpawner`, no
> `MultiplayerSynchronizer`, no `@rpc`, grepped at 0 — because every peer loads the same static
> level content and evaluates it against cargo transforms `Crate` already replicates itself. One
> scene serves both `IN`/`OUT` kinds, tint and label derived locally per instance exactly as
> `player.gd` colours a capsule from `peer_id`. `GoodsIn`/`GoodsOut` are placed in the test room
> and the integration suite proves both peers independently agree on a zone's contents over real
> ENet, not merely that the host believes it.
> **Two real bugs, both caught only by running the suite repeatedly rather than trusting one green
> pass**: the zone probe crate was landed exactly on the zone's floor-level origin (y=0), half-
> burying a Small and — combined with the plan's `sleeping = false` — leaving it unable to settle
> back asleep, so it jittered indefinitely and eventually fell out of the level over a full run
> (fixed: land it at rest height, +0.25m, not on the floor plane itself); and that same
> perpetually-awake crate, still replicating during the carry/handoff scenario that immediately
> follows in the suite, was intermittently enough to collapse a two-holder state out of a single
> 20 Hz replication tick before the client observed it (fixed: wait, host-only, for the probe to
> settle back to sleep before the zone check returns). **A third avenue was tried and reverted**:
> awaiting every `_take()` call site in the harness fixed one narrow, independently-reproduced race
> but made the replication-collapse failure worse by serialising the carry/handoff sequence: this
> is a real property of the existing harness, and `_take()`'s docstring now records why it stays
> deliberately unawaited rather than leaving that discovery to be re-made later.
> **Placement also moved off the plan's literal coordinates**: the plan's `(7,-7)`/`(7,7)` puts
> both zones on the *same* side of the room as the racks (both at positive x) and overlaps
> `rack_wall`'s footprint by 0.5m — moved to x=-7 (the room's west side), which is both actually
> clear and actually opposite the racks, as the plan's own prose intended. Full detail:
> `.planning/phases/01-storage/01-05-SUMMARY.md` (local-only, see the note above on
> `.planning/phases/`).

## Accumulated Context

### Decisions

All decisions live in `decisions/` and are indexed in `decisions/decision-log.md`.
**ADRs are authoritative over anything in `.planning/`** (ADR 15). The ones that most
constrain upcoming work:

| ADR | Constrains |
|---|---|
| 4 — grid storage, physics transport | Phase 1 directly. Racked items must be static, never simulated |
| 7 — client owns its capsule only | Every interaction. A client asks; the host decides |
| 12 — project structure | Where every new file goes. Racks are `world/`, cargo is `goods/` |
| 13 — force-driven held items | Never freeze or reparent a held crate; it deletes throwing |
| 14 — physics budget of ~150 | Floor clutter, rack shedding volume, items per day |
| 15 — GSD wraps the build order | This file, and everything else in `.planning/` |
| 18 — 1.0 m cell, atomic, LIFO | The rack's whole occupancy model (01-03 onward). `Rack` delegates all arithmetic to `StorageGrid` — nothing downstream should recompute it |

### Open

- **Steam join half is unproven** and needs a second machine. `docs/steam-validation-run.md`.
- ~~Detection and patch maths are undefined~~ — **settled 2026-08-19 (ADR 20)**. Reputation is priced in
  cash and decays with the lease, which is what makes the right answer move. `CargoCondition` and
  `Dilemma` are pure and under test; the sweep asserts no dominant strategy. **Nothing is wired to
  gameplay** — the tape gun, handover and damage sources are still Phase 3.
- **The storage unit is a 1.0 m cell** (ADR 18, superseding 16). The cell arithmetic
  (`StorageGrid`, 01-02) and the rack fixture itself (`Rack`, greybox scene, two racks placed,
  01-03) are both built and under test. **Nothing is wired to the actual place/retrieve
  interaction yet** — every rack starts and stays empty, since no RPC calls `apply_cell_filled`
  — that is 01-04. Crate sizes must still match exactly before anyone builds art.
- Plans 01-02 and 01-03 were **reworked for ADR 18's cell model** and re-verified. The
  re-check found two blockers, both caused by the slot → cell rename being a text substitution
  rather than a semantic one: 01-04 still enforced one item per cell, and two broadcast methods
  were called but never defined. Both fixed. **A cell now holds a stack of crate ids rather than
  a count**, so LIFO is observable through the real player path rather than only in a unit test.
- **Feel tuning is provisional.** Hold stiffness 2400 / damping 460 came from one play session. All exported and tunable live.

### Constraints learned the hard way

- Headless Godot runs uncapped, so frame counts are useless as timeouts. Use wall-clock deadlines.
- A new `class_name` is invisible to headless runs until the editor rescans.
- One Godot editor at a time — the MCP bridge grabs port 9080 and will silently edit the wrong project.
- Close the editor before any branch switch that touches `addons/`; it holds the Steam DLLs open.

## Phase 0 outcome

Complete and verified, except NET-02's join half. **Solo drag closed the last build item on
2026-08-19** — the Steam join is now the only thing outstanding, and it is blocked on hardware
rather than on work.

Delivered: transport abstraction with ENet and Steam behind one interface, session
lifecycle and spawn handshake, client-authoritative first-person capsule, host-simulated
force-driven cargo, a carry referee enforcing one crate per player and two holders per
crate, host-authoritative shoving, an integration suite that proves all of it, and a
measured physics budget.

Two things it changed along the way: held items became force-driven rather than parented
(ADR 13), and cargo replication moved to 20 Hz on-change, cutting host upstream 16×.
