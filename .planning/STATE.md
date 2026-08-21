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
Plan: **01-01 through 01-07 complete** — waves 1–5 done, 2 of 9 plans remaining across waves 6–7
Status: **Executing** — wave 5 (01-07 shedding) complete; wave 6 (01-09 settled cargo) unblocked;
wave 7 (01-08, the human gate) waits on it
Last activity: 2026-08-21 — 01-07 executed: `Rack` gained a host-only `ImpactSensor` (`Area3D`,
mask 4/cargo, speed-thresholded, cooldown-limited) and `CarryAuthority` gained `shed_top_row`,
which clears exactly the occupied top-row cells over the existing `_cell_cleared` broadcast and
spawns each as a real falling crate with an outward-and-up impulse, bounded three ways against
ADR 14 (top row only, `MAX_SHED_PER_EVENT`, the rack's own cooldown). Proven on two real processes
over three consecutive clean runs: two top-row cells filled through the real place path, a
scripted high-speed impact, and — on both peers — both cells empty, the untouched mid-row cell
(8 synthetic fillers) unaffected, the loose-crate count up by exactly the delta, both visuals
gone. A small stacking step proved floor stacking still works. **Two deviations, both caught
before the first test run rather than by a failing one**: the plan's own worked cell numbers (8,
9, "for a 4×3 bay") don't exist as aimable cells on the actual `rack_wall` fixture — they're the
same permanently-unaimable depth=0 row 01-04 already found — fixed by using 10 and 11 instead,
the top-row cells on the aimable depth=1 side; and the plan's own impact-launch formula has no
lateral offset, which spawns the crate directly inside a corner upright's collision box — fixed
by centring the flight path on the rack's own width. **The audit's drag-speed/shed-threshold flag
is preserved and expanded** in `rack.gd`'s own doc comment for the wave 7 gate: a dragged crate's
~1.7 m/s ceiling can never reach the 4.0 m/s shed threshold, confirmed correct with a thrown
crate, not yet with one in hand. **The floor-stacking "blocks pathing" tension is written down,
not resolved** — full text in `01-07-SUMMARY.md`, carried verbatim for 01-08. Before that:
01-06 executed: a three-state cell highlight (none/actionable/blocked,
driven every frame from the local player's own aim and matching `try_toggle_hold`'s branch table
exactly, including the two ADR 19 drag rows the plan itself flagged as missing when first written)
and a tweened placement snap (travel-and-settle over 0.16s with a positional thud, replacing the
instant teleport-in 01-04 shipped with) both landed. Two real issues, both caught before commit —
see the 01-06 block below: the plan's own settle-assertion snippet compared against the bare cell
centre rather than the ADR 18 lattice offset each Small actually rests at, and the new WAV asset
needed a one-shot headless `--import` pass (editor closed, then reopened) before any test could
load it, now recorded as a standing constraint. Before that: 01-04 executed:
`CarryAuthority.request_place`/`request_retrieve` landed, host-validated and ADR 19-aware, with
`Carrier` resolving one aim ray to either a crate or a rack cell and the full
place/refuse/retrieve branch table. The integration test that proves it found and fixed a
structural bug in the aim mechanism itself — see the 01-04 block below, and read it before
touching rack aiming again. Before that: 01-05 executed: `GoodsZone` (Area3D, zero
networking machinery, kind IN/OUT with the difference derived locally) landed, with
`GoodsIn`/`GoodsOut` placed in the test room and both peers independently proven to agree on a
zone's contents over real ENet. Two real bugs found and fixed only by running the suite repeatedly
rather than trusting one green run — see the 01-05 block below. Before that: 01-03 executed:
`Rack` (12-cell occupancy, atomic by kind, LIFO, visuals derived from state) landed against ADR
18, with a greybox scene, twelve per-cell aim volumes, a zero-cost `racked_item.tscn`, two racks
placed in the test room, and host-side crate minting. Before that: 01-02 executed: `StorageGrid`
cell arithmetic (ADR 18) landed test-first, 183 unit checks, wired into the suite's `unit/` stage
alongside `dilemma_maths.gd`. Before that: 01-01 executed, `queue_free()` despawn replication
proven on both peers (no fallback needed), physics layer 4 named `storage` and asserted. Before
that: solo drag built and proved (ADR 19); detection and patch maths settled and put under test
(ADR 20); the economy settled (ADRs 21–22); a `unit/` test layer now exists; plan 01-04 patched
for ADR 19 before execution

Progress: [██████░░░░] Phase 0 complete bar one blocked item; Phase 1 waves 1-5 of 7 done
(7/9 plans)

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
> **Resolved 2026-08-20: the `phase-plan-index` wave misreport was a CRLF bug, now patched.**
> The audit patch had saved 01-04-PLAN.md with Windows line endings, and the tool's frontmatter
> parser anchored on `^---\n` — a CRLF file parsed as having *no frontmatter*, so `wave`
> defaulted to 1 and, worse, `autonomous` defaulted to true, which would strip a checkpoint plan
> of its human gate. Patched locally in the tool (CRLF-tolerant parsing, plus `files_modified`
> now reads the underscore key the template actually uses); verified against all nine plans.
> The patch is machine-local and a tool update overwrites it — re-verify after any update.

**Next session: wave 5 is complete, resume at wave 6.** 01-07 (shedding) landed.
`/gsd:execute-phase 1` from a fresh context will skip the seven plans with SUMMARYs and pick up
wave 6 (01-09, settled cargo) — the last autonomous plan before wave 7's human gate (01-08).

Things to carry in, from the audit above and from 01-04's and 01-05's own execution:

- **`gsd-tools phase-plan-index` still misreports 01-04 as wave 1.** It depends on 01-03. Read
  the frontmatter, not the tool. (Now moot for 01-04 itself, but the tool is presumably still
  wrong for others.)
- **`gsd-tools state advance-plan` / `state update-progress` cannot parse this project's
  hand-authored STATE.md** — both errored ("Cannot parse Current Plan or Total Plans", "Progress
  field not found") when tried for 01-04. STATE.md was updated by hand instead, matching the
  existing block style. Don't spend time retrying the tool here; it wants a format this file
  doesn't use.
- **The integration harness's `_take()` helper is deliberately unawaited at every call site** —
  tried awaiting it, made a different failure worse (see the 01-05 block below). If a future plan
  is tempted to "fix" this, read that block and `_take()`'s own docstring first.
- **A rack backed against a wall has a permanently unaimable back row**, independent of
  occupancy — flagged in detail in the 01-04 block below. **01-06 (cell highlighting) copies
  01-04's branch table verbatim and needs to know this before it paints a highlight on a cell
  nobody can reach.**
- **`Carrier._aim()`'s `CELL_RESOLVE_NUDGE` is load-bearing for every rack interaction, not just
  01-04's.** Without it, no rack anywhere is aimable at all — see the 01-04 block. Any future
  raycast-based rack code should call `Carrier._aim()` rather than reimplementing
  collision-point-to-cell resolution.

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

> **01-04 resolved 2026-08-20: place and retrieve landed, host-validated and ADR 19-aware.**
> `CarryAuthority` gained `request_place`/`request_retrieve` (validated in order: holding what's
> claimed, ADR 19's drag-can't-reach-above-floor rule, rack/cell resolution, ADR 18 atomicity,
> reach), the three broadcast RPCs, and late-joiner rack snapshots. `Carrier._aim()` resolves one
> ray to either a `Crate` or a `(Rack, cell_index)` pair, and `try_toggle_hold()` implements the
> full eight-row branch table. A second integration scenario, `storage_session.gd` (port 27097),
> proves the whole round trip over real ENet: place, a cell taking more than one, a full cell
> refusing without a drop, a dragged crate refused above the floor row while a carried one
> reaches it, LIFO retrieval (proven through `Rack.occupant()`'s own bookkeeping, not the id of
> whatever crate a retrieval hands back — `request_retrieve` always mints a fresh one, since
> placing one freed its body outright), and the body-cost budget.
> **Eight deviations, six of them real pre-existing bugs the integration test caught rather than
> introduced**: `Rack.occupant()`'s empty sentinel (`0`) collided with a real crate id (crate ids
> mint from 0) — changed to `-1`; the `crate_source` group the plan's own retrieval code depends
> on never existed — added; `rack.tscn`'s `CellSensor` volumes were nested under an intermediate
> node, which broke the aim code's one `get_parent()` call for every rack, not just this plan's —
> flattened. **The significant one**: a raycast's collision point always sits exactly on the
> surface it hit, and for the outermost reachable row of any rack that surface *is* the rack's own
> boundary — which `StorageGrid.cell_index_at()`'s half-open rule (correct for a body's centre,
> wrong for this) excludes. Every straight-on aim at any rack resolved to `-1`, unconditionally,
> until `Carrier._aim()` started nudging the point a centimetre inward first
> (`CELL_RESOLVE_NUDGE`) — load-bearing for every future rack interaction, not just this one. The
> remaining two were bugs in the test harness itself (a held crate teleported in one jump snaps
> its own hold; `queue_free()`'s deferred removal races a one-shot check, and one of those races
> was silently absorbed by `_expect_now` never failing the overall result).
> **One finding flagged rather than fixed, needs a design decision**: `rack_wall`'s depth=0 row
> (cells 0,1,4,5,8,9) is permanently unaimable, independent of occupancy — it's backed onto the
> room's wall, so the only approachable side is the depth=1 row's own side, and that row's
> `CellSensor` volumes physically block the ray to the row behind them no matter what either row
> holds. Not specific to this plan's original cell choice (moved from 5/4 to 7/6 to work around
> it); a property of any multi-deep rack against a wall under the current aim scheme. **01-06
> (cell highlighting) copies this plan's branch table verbatim and will need to account for
> it** — a highlighted cell nobody can actually reach is exactly the promise-versus-behaviour gap
> that plan exists to prevent. Full detail: `.planning/phases/01-storage/01-04-SUMMARY.md`
> (local-only, see the note above on `.planning/phases/`).

> **01-06 resolved 2026-08-21: aim feedback and the placement snap landed.** `Rack` gained a
> `CellHighlight` mesh with three states (`NONE`/`ACTIONABLE`/`BLOCKED`), coloured via a
> `resource_local_to_scene` material so two racks never share a mutable colour, and
> `Carrier._process` paints it every frame from the exact same `_aim()` query and branch rules
> `try_toggle_hold()` already enforces — including the two ADR 19 dragging rows the plan itself
> had flagged as missing when first written (see the audit block above). Only the local player's
> carrier runs `_process`; every other copy calls `set_process(false)` in `_ready()`, same as the
> existing `set_process_unhandled_input(false)` guard. `apply_cell_filled`/`apply_cell_cleared`
> were rewritten from "clear and rebuild the whole cell's visuals" to "spawn exactly the new
> arrival, free exactly the LIFO-popped top" — necessary once placement animates, since the old
> approach would restart every other item's already-finished tween on every unrelated change to
> the same cell. A placed item now tweens from its pickup point to its cell's lattice position
> over 0.16s (`TRANS_CUBIC`/`EASE_OUT`, plus a 1.06→1.0 scale settle) and plays a positional thud;
> the late-joiner snapshot path (`Vector3.ZERO` sentinel) still places everything instantly and
> silently. `tools/make-placeholder-audio.ps1` synthesises that thud from scratch — a RIFF header
> and raw 16-bit PCM written directly, no external audio.
> **Two real issues, both caught before anything broken was committed**: the plan's own
> settle-assertion snippet (`visual.position.is_equal_approx(rack.cell_to_local_position(cell))`)
> could never have passed — a Small's real resting spot is one of 8 lattice positions
> (`StorageGrid.small_offset`), not a cell's mathematical centre, and no sub-index (including 0)
> lands exactly on it; fixed by adding the offset into the comparison. And a new binary asset
> (`rack_place.wav`) needs Godot's importer to run once — producing a `.import` sidecar (committed)
> and a `.godot/imported/*.sample` cache (gitignored, machine-local) — before any headless test can
> load it; neither this project's test scripts nor a plain file write can trigger that. Resolved by
> closing the already-running GUI editor, running `godot --headless --path warehouse-manager
> --import` once, verifying both artefacts existed, then reopening the editor with the same
> `--editor --path` invocation the session-bootstrap hook uses. **Recorded as a standing
> constraint below** — the next new binary asset (a texture, another sound) needs the same
> treatment. Full detail: `.planning/phases/01-storage/01-06-SUMMARY.md` (local-only, see the note
> above on `.planning/phases/`), including the five feel questions (snap cleanliness, highlight
> legibility at distance/in dim light, colour-blind accessibility, whether 0.16s is right, whether
> the dragging-BLOCKED cue reads as "call someone over") that plan 01-08 needs to put in front of a
> human at the wave 7 gate.

> **01-07 resolved 2026-08-21: racks shed their top row, bounded and proven on two peers.**
> `Rack` gained an `ImpactSensor` (`Area3D`, `collision_layer=0`/`collision_mask=4`, host-only —
> disabled and disconnected on a client in `_ready`, the same split `Crate`'s own `PushSensor`
> uses) that fires `_on_impact` when a real, host-simulated `linear_velocity` clears
> `shed_impact_speed` (4.0) outside a `shed_cooldown` (1.5s) window, then resolves the referee
> lazily by group — the same pattern `Carrier._authority()` already uses, deliberately not
> cached. `CarryAuthority.shed_top_row` walks `rack.occupied_cells_in_top_row()` (bounded again by
> `MAX_SHED_PER_EVENT`, a defensive ceiling that never actually trips under today's 2×2×3
> geometry), broadcasts each clear over the same `_cell_cleared` RPC `request_retrieve` already
> uses, and spawns a fresh crate through the `crate_source` group with an outward-and-up impulse
> derived from the rack's own transform, so a rotated rack sheds forwards rather than sideways.
> `storage_session.gd` extends the same two-process scenario with three more steps — fill two
> top-row cells through the real grab-and-place path, launch a crate at the rack fast enough to
> clear the threshold, and assert on **both** peers that both top-row cells empty, the untouched
> mid-row cell (holding 8 synthetic fillers from an earlier step) is unaffected — the bound,
> proven rather than assumed — the loose-crate count rises by exactly the delta, and both racked
> visuals are gone. A small stacking step proves crates still rest on top of each other rather
> than sinking through. Three consecutive full-suite runs, all green, no flakes.
> **Two deviations, both caught before the first test run rather than by a failing one**: the
> plan's own worked cell numbers (8 and 9, "for a 4×3 bay") don't exist as aimable cells on
> `rack_wall` — they're the depth=0 row, the same permanently-unaimable row 01-04 already found
> and 01-06 already had to account for — fixed by using cells 10 and 11, the top-level cells on
> the depth=1 side `CELL_A`/`CELL_B` already proved aimable; and the plan's own impact-launch
> position formula has no lateral offset, which spawns the crate directly inside
> `UprightBackLeft`'s collision box — fixed with a lateral offset centring the flight path on the
> rack's own width, clear of both corner uprights.
> **The audit's drag-speed/shed-threshold flag (flagged, not patched, before execution) is
> preserved and expanded**, in `rack.gd`'s own doc comment rather than only in this file: a
> dragged crate's ADR 19 ceiling (~1.7 m/s) can never reach the 4.0 m/s shed threshold. That is
> correct — two-player carry is the only way to hit something hard enough to matter — confirmed
> with a thrown crate in the integration suite; a human check with one actually in hand is still
> owed at the wave 7 gate, per the plan's own instruction.
> **One finding surfaced rather than resolved, for 01-08 to put to NJ verbatim**: success
> criterion 5 / STORE-04 say floor stacking "blocks pathing," and it does not, today, for an
> empty-handed player — `player.tscn` stays at `collision_mask = 3` (no cargo layer), which is
> deliberate and load-bearing (the 3.39 m vs 0.01 m bulldozing measurement `crate.gd` already
> records). What is true: cargo *in transit* (a held crate) collides with a floor stack for real.
> No collision layer or mask was touched anywhere in this plan — confirmed by grep on both
> `player.tscn` and `crate.tscn`. Two options costed in `01-07-SUMMARY.md`: accept that "blocks
> pathing" means blocks cargo, or give players a cargo mask and solve puppet-bulldozing another
> way (an ADR 7-level change, not a tweak). Full detail:
> `.planning/phases/01-storage/01-07-SUMMARY.md` (local-only, see the note above on
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
| 23 — Early Access, same bar | Phase 6 (store page + wishlists before the date) and Phase 7 (the gate now means "EA-shippable", unchanged in content). Public roadmap sells axes, never parked features |

### Open

- **Steam join half is unproven** and needs a second machine. `docs/steam-validation-run.md`.
- ~~Detection and patch maths are undefined~~ — **settled 2026-08-19 (ADR 20)**. Reputation is priced in
  cash and decays with the lease, which is what makes the right answer move. `CargoCondition` and
  `Dilemma` are pure and under test; the sweep asserts no dominant strategy. **Nothing is wired to
  gameplay** — the tape gun, handover and damage sources are still Phase 3.
- **The storage unit is a 1.0 m cell** (ADR 18, superseding 16), and place/retrieve is now fully
  wired (01-04): `CarryAuthority.request_place`/`request_retrieve` call `apply_cell_filled`/
  `apply_cell_cleared` over the real keypress path, proven over real ENet. **01-06 added aim
  feedback and the placement snap** — a three-state cell highlight and a tweened travel with a
  positional thud, both proven to converge on both peers. **01-07 added the shed**: a hard enough
  impact clears exactly the occupied top-row cells and spawns each as a real falling crate,
  bounded three ways against ADR 14 and proven on both peers. Crate sizes must still match
  exactly before anyone builds art.
- **Floor stacking's "blocks pathing" is an open fork, not yet ruled on** (01-07): true for cargo
  in transit (a held crate collides with a stack for real), not true for an empty-handed player
  (`player.tscn` deliberately has no cargo bit in its mask — see the 3.39 m vs 0.01 m bulldozing
  measurement `crate.gd` records). Two costed options in `01-07-SUMMARY.md`, needs the wave 7 gate.
- **The drag-speed/shed-threshold tension flagged before 01-07 was executed is confirmed correct,
  not a gap**: a dragged crate's ADR 19 ceiling (~1.7 m/s) can never reach the 4.0 m/s shed
  threshold, verified with a thrown crate in the integration suite. A human check with one
  actually in hand is still owed at the wave 7 gate (the plan's own instruction, not a new ask).
- **A rack backed against a wall (`rack_wall`) has a permanently unaimable back row** (found by
  01-04), independent of occupancy — see the 01-04 block above. **01-06 mirrored this as-built
  rather than working around it**, as instructed: an unaimable cell simply never highlights,
  since `Carrier._aim()` never resolves a valid index for it. Still needs a design ruling at the
  wave 7 gate: island-only racks, a redesigned aim scheme for buried cells, or an explicit
  acceptance that wall racks only expose their front row.
- Plans 01-02 and 01-03 were **reworked for ADR 18's cell model** and re-verified. The
  re-check found two blockers, both caused by the slot → cell rename being a text substitution
  rather than a semantic one: 01-04 still enforced one item per cell, and two broadcast methods
  were called but never defined. Both fixed. **A cell now holds a stack of crate ids rather than
  a count**, so LIFO is observable through the real player path rather than only in a unit test.
- **Feel tuning is provisional.** Hold stiffness 2400 / damping 460 came from one play session. All exported and tunable live.
- **A first-pass economy model exists** (`tools/economy-sim.js` + `tools/economy-scenarios.js`,
  committed 2026-08-20) — candidate rents, value densities and the invoice-at-handover frame,
  embedding ADR 20's constants verbatim and calibrated to its £50–£2000 sweep envelope. Input to
  the Phase 4 ADR, not a decision. Its one load-bearing guess — ~15 moves per player per
  8-minute day — should be timed with a real carry loop at the Phase 1 gate.
- **`rack_wall`'s back row is permanently unaimable** (flagged by 01-04): the front row's
  sensors block the ray, the wall blocks the other side — wall racks are effectively 6 cells.
  Needs a design ruling; belongs with the gate's "does 2-deep read as one unit" question.
  01-06 (2026-08-21) mirrored as-built behaviour rather than inventing a fix, as instructed.

### Constraints learned the hard way

- Headless Godot runs uncapped, so frame counts are useless as timeouts. Use wall-clock deadlines.
  This applies to more than just top-level test timeouts: a fixed frame count used as a
  "let physics settle" pause between two teleports (01-04) bought almost no real physics time and
  silently dropped a held item — pace anything physics-dependent by `Time.get_ticks_msec()`.
- A raycast's collision point sits exactly ON the surface it hit. Feeding that directly into a
  half-open boundary test (`StorageGrid.cell_index_at`) fails for the outermost reachable layer of
  any bounded volume, because that surface coincides with the volume's own boundary, which the
  rule excludes by design. Nudge the point a little further along the ray first
  (`Carrier.CELL_RESOLVE_NUDGE`, 01-04).
- `queue_free()` defers the actual node removal. A check against `get_child_count()` or
  `get_node_or_null()` immediately after calling it can still see the old state — poll for the
  change, don't assert it once (01-04, 01-05 both hit this independently).
- A new `class_name` is invisible to headless runs until the editor rescans.
- One Godot editor at a time — the MCP bridge grabs port 9080 and will silently edit the wrong project.
- Close the editor before any branch switch that touches `addons/`; it holds the Steam DLLs open.
- A new binary asset (a `.wav`, a texture) needs Godot's importer to run once before any headless
  test can load it — a `.import` sidecar (commit it) plus a `.godot/imported/` cache entry
  (gitignored, machine-local), neither of which exists from a plain file write. With the GUI
  editor already open, close it first (two processes writing the same `.godot/` cache is asking
  for trouble), run `godot --headless --path warehouse-manager --import` once, verify both
  artefacts exist, then reopen the editor (01-06).

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
