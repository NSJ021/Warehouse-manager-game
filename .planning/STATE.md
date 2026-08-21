# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-17)

**Core value:** The dilemma is the game — patch and hope, confess, or comp.
**Current focus:** Phase 1 complete (gate passed 2026-08-21). Next up: Phase 2, Goods.

> **Narrative history lives in `docs/conversation-log.md`, not here.** This file tracks
> execution position only. Duplicating the story in two places guarantees one of them
> goes stale.

## Current Position

Phase: 1 of 7 (Storage) — **complete.** Next: Phase 2 (Goods).
Plan: **01-01 through 01-09 all complete** — all 9 plans, all 7 waves done.
Status: **Phase 1 closed 2026-08-21.** The gate (01-08) passed — verdict "storage feels
deliberate," NJ, explicit, after three play sessions. Task 2's rulings are written into
[ADR 24](../decisions/2026-08-21-rack-presentation-ratified.md) and `.planning/REQUIREMENTS.md`;
full detail in `01-08-SUMMARY.md`. Phase 2 has not started.
Last activity: 2026-08-21 — 01-08 executed, closing the phase: see the resolved block below for
the gate's own findings and rulings. Before that: 01-09 executed: `Crate` gained ADR 17's settle/wake state machine — a
crate at rest for half a second freezes to real `FREEZE_MODE_STATIC` world geometry and blocks
players client-side, wakes on a shove or a grab, proven on two real processes across four
assertions (settle, block, wake, never-while-held), four engine assumptions pinned, and the physics
budget re-measured to confirm it improved rather than regressed. Full detail in the resolved block
below and `01-09-SUMMARY.md`. Before that: 01-07 executed: `Rack` gained a host-only `ImpactSensor` (`Area3D`,
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

Progress: [█████████░] Phase 0 complete bar one blocked item; Phase 1 complete, all 9 plans, all
7 waves — gate passed 2026-08-21. Phase 2 not started.

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
> **01-05 ↔ 01-09 — resolved 2026-08-21.** The zone probe crate does settle static, and `Area3D`
> *does* still report it (verified, both in `engine_assumptions.gd` and in `carry_session.gd`'s own
> live zone check) — the actual bug turned out to be one line away: the *wait* that gated the check
> read `Crate.sleeping`, which a frozen body never reports true on its own, so the wait hung rather
> than the zone losing the crate. Fixed by checking `sync_settled` too. See the 01-09 block below.
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

**Next session: Phase 1 is closed. Start Phase 2 (Goods) planning.** `/gsd:plan-phase 2` (or
equivalent) from a fresh context — nothing in Phase 1 remains open that blocks it. Read this
file's Open section below first: three items are explicitly carried into Phase 2 planning (the
Large-orientation question, STORE-07's data shape, the cell-plaques recommendation), and the
seven follow-ups from the gate (i–vii, below) are candidates for Phase 2 or Phase 6 scope,
not yet plans. The wave 7 gate crib sheet (memory: `wave7-gate-crib-sheet`) has done its job and
does not need carrying forward again.

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

> **01-09 resolved 2026-08-21: settled cargo turns static and blocks players, proven on two
> peers.** `Crate` gained ADR 17's settle/wake state machine: a crate at rest for `settle_frames`
> (0.5s) freezes to `FREEZE_MODE_STATIC` and ORs the world layer bit into `collision_layer` — never
> replacing the cargo bit, so a `GoodsZone` still sees it — replicating `sync_settled` so every peer
> agrees without a round trip; blocking then resolves client-side, the puppet's own capsule against
> real static geometry (ADR 7 unchanged — no new authority question). A qualifying shove or being
> grabbed wakes it (`_wake()`), and `add_holder()` wakes on grab so the hold spring never pulls
> against a static body. `storage_session.gd` proves settle/block/wake/never-while-held on two real
> processes; `engine_assumptions.gd` pins the four engine behaviours this rests on (frozen body
> blocks and cannot be displaced; `Area3D` overlap detection works both as a child sensor and as an
> external observer of a frozen body — the latter is what closes the 01-05 ↔ 01-09 flag below). The
> physics budget was re-measured, not assumed: it improved (awake-mode solo cost down 24-35%, the
> awake/400-crate network figure down from 270 to 35 kb/s), because a genuinely-static body is
> cheaper than a merely-not-sleeping one — full numbers and the "why" in `docs/physics-budget.md`.
> **The ~150 body ceiling does not move, but now means "bodies actively moving," not "bodies in the
> world"** — settled floor stock is close to free once frozen, worth carrying into the Phase 4
> economy work.
> **Four deviations, one a real game-code bug and three pre-existing test-harness fragility that
> settling's timing shift exposed rather than caused** — the settle machine itself worked on the
> first run; nearly all execution time went into telling these two categories apart. (1) `_wake()`
> set `freeze = false` but not `sleeping = false`, so an unfrozen crate under an active hold spring
> could sit motionless — indistinguishable from a broken hold — until distance-break kicked in;
> fixed by setting `sleeping = false` explicitly. (2) `storage_session.gd`'s drag-attempt step drags
> a crate straight past two others sitting untouched in the same row, which now settle to real,
> immovable geometry within half a second and physically wedge the drag short of its target — **this
> is ADR 17 working as designed** (settled cargo blocks other cargo, not just players), fixed with a
> detour around the row for that one call site, not a game-code change. (3)
> `carry_session.gd`'s zone-probe wait read `Crate.sleeping`, which a frozen body was measured to
> never report true on its own — switched to `sync_settled` with `sleeping` kept as a fallback,
> closing the flag below. (4) `carry_session.gd`'s unawaited `_take()` retry helper has a genuine
> pre-existing race — a stale press can land up to six frames (real, variable wall-clock time under
> headless) after the press that actually succeeded, and settling's timing shift made it land badly
> (silently re-grabbing a crate the test had already released) far more often than before. **Two
> alternative fixes to `_take()`'s own retry cadence were tried and reverted** — both closed this
> race but caused a second, independently-reproducible flake in the solo-drag scenario, confirmed
> unrelated to settling by disabling `settle_frames` and reproducing it anyway. Fixed instead by
> checking both the replicated holder count and the carrier's own local state before trusting
> "released," plus a 500ms margin after the join is confirmed, comfortably longer than any observed
> six-frame span. 15 consecutive clean runs of the carry scenario alone, plus 5 consecutive clean
> full-suite runs, after the final fix. Full detail: `.planning/phases/01-storage/01-09-SUMMARY.md`
> (local-only, see the note above on `.planning/phases/`).

> **Wave 7 gate session findings, resolved 2026-08-21: three defects found live at the human gate
> playtest, all fixed and proven against the real path.** Not a numbered plan — ad hoc fixes made
> during the gate session itself, on `feat/phase-1-storage`, before 01-08's own write-up.
>
> **(1) Reach mismatch.** The cell highlight painted whenever the 2.5 m `GrabRay` connected, but
> `CarryAuthority.PLACE_REACH` measured camera → cell *centre*, not camera → the ray's hit point —
> and a cell centre can sit up to half the cell's own space diagonal (~0.87 m) behind that surface.
> Genuine aims in roughly the 2.1–2.5 m band painted green and were then silently refused.
> `PLACE_REACH` raised 2.6 → 3.5 (2.5 ray reach + 0.87 half diagonal + margin); its doc comment
> rewritten to show the arithmetic rather than assert the old, disproven claim that a genuine aim
> could never fail it. `GRAB_REACH` untouched — its own feel is a separate open question for the
> gate.
>
> **(2) Self-shed on retrieval.** `request_retrieve` and `shed_top_row` both mint a fresh crate at
> a cell's own centre — inside that rack's `ImpactSensor` volume by construction — so the hold
> spring (a retrieval) or the launch impulse (a shed) could accelerate the new body past
> `shed_impact_speed` while still overlapping the sensor it was born inside. Reproduced live:
> retrieving from a loaded top row shed the row. Fixed with a mint-grace — `Crate` now records its
> own spawn time in `_ready()` (`age_ms()`, host-side reasoning only, not replicated) and
> `Rack._on_impact` ignores anything younger than `MINT_GRACE_MS` (700 ms) before checking impact
> speed at all. The sensor's held-crate sensitivity is otherwise untouched — a swung or carried
> crate still sheds.
>
> **(3) Sensor-stranded loose crates.** A loose crate resting inside a rack's `CellSensor` volume
> (a shed crate landing there happened twice in play) was permanently unaimable: the combined ray
> hit the sensor's own surface before ever reaching the crate behind it, resolved to an empty
> cell, and `try_toggle_hold` did nothing — and supply conservation did not save it, since recovery
> only fires below the world. `Carrier._aim()` now runs a cargo-only physics query first, but only
> while empty-handed (same origin/length as `GrabRay`, masked to the cargo layer alone so the
> storage layer cannot block it); only if that finds nothing does aim fall through to the existing
> combined ray and cell resolution. While holding something, behaviour is unchanged — cells must
> still win, or a loose crate in front of a rack face would hijack a placement aim.
>
> **Fixture bump, same session:** the gate protocol needs 9+ crates on hand (a full cell of 8
> Smalls plus one in hand) — `TestRoom.crate_count` raised 6 → 12, a second row
> (`CRATE_ROW2_ORIGIN`, z=-9.0) rather than extending the first row along x, which would have run
> through rack_wall's own approach corridor and the integration suite's drag-avoidance detour. The
> second row's z is derived against `carry_session.gd`'s own `CLIENT_STAND_OFFSET_Z`, not
> guessed — a naive "one row back" at -7.5 would have sat the new crates inside that stand point's
> own capsule radius.
>
> **All three fixes proven with new regression steps (10-12) in `storage_session.gd`**, against
> `rack_island` rather than `rack_wall` so they cannot collide with rack_wall's already-exercised
> cell states: retrieving a crate beside a still-loaded top-row neighbour does not shed it;
> a crate teleported to rest inside a cell volume is grabbable through the real
> `try_toggle_hold` path; and a placement from a genuine near-maximum-range aim
> (`MAX_RANGE_STAND_OFFSET_Z`, deliberately near `GrabRay`'s own 2.5 m edge) succeeds. One test
> harness finding along the way: the existing `PARK_POINT` is calibrated for rack_wall's own
> corridor and sits over 11 m from rack_island — walking a release there and back left too little
> of the client's own 15 s window for a 20 Hz replication tick to land before a hold ended again,
> caught by an actual timeout on the first run of the stranded-crate step's cross-peer check. Fixed
> with a second, much closer `GATE_PARK_POINT` and a deliberate short hold-confirm pause, not by
> weakening the check. Three consecutive full clean suite runs after the fixes, with the regression
> steps included.

> **Reach ruling, 2026-08-21 (NJ, after it came up in two separate gate sessions): the whole
> reach chain read too long in play, shortened 2.5 → 2.0 m.** `GrabRay`'s own `target_position`,
> `CarryAuthority.GRAB_REACH` and `PLACE_REACH` (3.5 → 3.0, keeping PLACE_REACH's own
> half-diagonal margin so a genuine ray-limited aim still can never be refused — see that
> constant's own doc comment for the re-derived arithmetic) all moved together.
>
> Every stand point in the integration suite that assumed the old 2.5 m had to be checked against
> the new number, not just retuned where an assertion happened to fail first — a couple already
> had comfortable margin and needed nothing: `carry_session.gd`'s `HOST_STAND_OFFSET_Z` (1.6 →
> 1.15; camera → crate distance was ~2.16 m, already past the new reach), `storage_session.gd`'s
> `GRAB_STAND_OFFSET_Z` (1.5 → 1.15, the one number every loose-crate grab in the file shares),
> `MAX_RANGE_STAND_OFFSET_Z` (2.85 → 2.35, the wave 7 gate's own regression 12, re-derived for the
> new ray edge) and a new `STRANDED_STAND_OFFSET_Z` (regression 11's grab of a crate that settled
> below the cell's own mathematical centre, onto the rack's deck — a case `RACK_STAND_OFFSET_Z`'s
> own margin was never computed against).
>
> **Standing closer to grab a crate surfaced a real, separate hazard.** Walking a held crate from
> the crate row to rack_island's top-row cells crosses that rack's own `ImpactSensor` footprint —
> harmless while the rack is empty (`Rack._on_impact`'s own `is_empty()` guard), but once crate_6
> already occupies cell 10, the same crossing sheds it back out from under crate_7's own
> placement: `request_retrieve` then finds the cell already empty, `try_toggle_hold` grabs the
> loose shed crate sitting in the way instead of resolving the cell, and the "retrieval" reads as
> a hang waiting for a new body that was never minted. Reproduced with every reach constant held
> at its OLD value and only the stand offset moved — this is about where the walk starts, not
> about any reach distance check. Routed around it with a single corner-hugging waypoint
> (`RACK_ISLAND_CORNER_WAYPOINT`) rather than the file's existing `ROW_DETOUR_Z`-style two-leg
> detour, which added ~6.5 m of real walk and blew the client's own 15 s wait for the placement to
> replicate.
>
> **One unrelated finding along the way, not fixed here:** `storage_session.gd`'s client process
> intermittently leaked one resource at exit (`WARNING: ObjectDB instances leaked`, `ERROR: 1
> resources still in use`) — reproduced on the unmodified pre-reach-change code too (commit
> `2f1d9da`, same flake, roughly every other run across several attempts), so it predates and is
> unrelated to the reach work. Godot's export build doesn't carry the `--verbose` object-name
> detail needed to say what's actually leaking. Left alone — reach-only scope, and squarely inside
> code the gate session's own three fixes above already touch. 3 consecutive clean runs achieved
> for this change regardless.
>
> Two commits on `feat/phase-1-storage`: `9edf8db` (the production reach chain) and `a7fa715`
> (the test retunes and the corner-hug fix).

> **01-08 resolved 2026-08-21: the gate passed, Phase 1 is closed.** Task 1 was three real play
> sessions (NJ), not one — the two blocks immediately above (the three defect fixes and the reach
> ruling) came out of those sessions and were already fixed, regression-tested and recorded before
> this plan's own write-up. All eighteen numbered checks in the plan's `how-to-verify` passed;
> check 20, the gate itself, passed explicitly: ten relaxed minutes racking as you go, "felt
> fine" on both known-location and placement-reads-as-decision.
>
> **Task 2's five rulings, recorded in full in `01-08-SUMMARY.md`, written into
> [ADR 24](../decisions/2026-08-21-rack-presentation-ratified.md) and the requirements/GDD updates
> below:**
> 1. **Rack geometry** — the frame stays exactly as built (0.05 m decks, 0.1 m uprights); the
>    actual fix is presentational — a pallet spawns on first placement, items sit on it with a
>    small peer-deterministic seeded jitter, top clearance a quarter-Small. Named consequence:
>    top shelf = longer hold + real throw effort, bottom shelf = fast turnaround, an intended
>    optimisation axis. Phase 6 builds the pallet/jitter visuals; this ADR fixes the rule.
> 2. **Wall-rack back row** — accepted as a level-design property (front sensors block a
>    straight-on ray, the wall blocks the other side), corrected by one finding from play: it is
>    reachable through the rack's *end* faces, so a wall rack is 6 cells head-on plus whatever its
>    ends expose, not a flat loss of half its capacity.
> 3. **Shed stance** — bounded top-row shedding at the existing 4.0 m/s / 1.5 s cooldown is
>    correct for v1, unchanged; a dragged crate never reaching that threshold is a conscious call.
>    The fuller version (positional shed, wobble telegraph, a rare full topple that must never
>    cascade) stays in `docs/idea-book.md` ("The rack topple") and needs its own ADR to enter
>    scope.
> 4. **Floor stacking** — ADR 17 verified underfoot, no re-decision; checks 16-19 all passed,
>    including that it stays worse than racking with no upside.
> 5. **Colour-blind accessibility** — deferred to Phase 6; the ghost-preview aim-feedback rework
>    (follow-up iii, below) adds a shape/position channel that covers it independently of colour.
>
> **All six STORE requirements are now met and ticked in `REQUIREMENTS.md`** — STORE-04 in
> particular, previously unticked because "blocks pathing" was untrue for an empty-handed player
> before ADR 17/01-09, is now true and ticked.
>
> **Four things the gate surfaced that are durable and forward-looking, not gate defects — full
> text of each lives in `REQUIREMENTS.md`, `GDD.md` and/or the Open section below:** the
> round-trip invariant (STORE-07 — a racked/retrieved crate's full record, not just its kind,
> must survive the trip intact, or racking can launder Phase 3's damage model); cell plaques as a
> Phase 2 recommendation, anchored on the pallet's front edge; the open question of which two
> cells a Large actually occupies; and seven smaller follow-ups (i–vii) found at the gate and
> deliberately not fixed now, listed under Open below.
>
> **Nothing in this plan touched game code.** Every fix the gate needed was already made and
> committed during the play sessions themselves (the two blocks above); Task 3 was documentation
> only. `./tools/run-tests.ps1` re-run clean before closing, no code changed since the last green
> run recorded above.

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
| 14 — physics budget of ~150 | Floor clutter, rack shedding volume, items per day. Re-measured post-01-09: the ceiling now specifically means bodies actively moving, not total bodies in the world |
| 15 — GSD wraps the build order | This file, and everything else in `.planning/` |
| 17 — settled cargo turns static | Built and verified 01-09. Every future crate interaction (a new hold type, a new sensor) must account for the frozen/world-layer state, not just held/loose |
| 18 — 1.0 m cell, atomic, LIFO | The rack's whole occupancy model (01-03 onward). `Rack` delegates all arithmetic to `StorageGrid` — nothing downstream should recompute it |
| 23 — Early Access, same bar | Phase 6 (store page + wishlists before the date) and Phase 7 (the gate now means "EA-shippable", unchanged in content). Public roadmap sells axes, never parked features |
| 24 — rack geometry ratified | The Phase 1 gate. Frame numbers are fixed and must not be resized once rack art exists. Pallet/jitter/plaque presentation is Phase 6 scope, not built yet. Wall-rack back row is a level-design property, not a bug: 6 cells head-on, plus end access |

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
- ~~Floor stacking's "blocks pathing" is an open fork~~ — **resolved at the Phase 1 gate,
  2026-08-21.** Checks 16-19 confirmed it underfoot: an empty-handed player is stopped by a
  settled stack (not merely a held crate colliding with one), shoving it wakes and scatters it,
  nothing settled half-inside a rack or wall, and it stays a *tempting bad idea* rather than
  becoming either scenery or strictly worse than racking. STORE-04 is ticked in
  `REQUIREMENTS.md`. What 01-09 additionally proved true: a settled crate also blocks *other
  cargo*, not just players — a dragged crate can be physically wedged by a settled neighbour,
  real gameplay behaviour worth remembering when laying out future levels.
- ~~The drag-speed/shed-threshold tension~~ — **resolved at the Phase 1 gate.** Confirmed correct
  with a crate actually in hand, not just thrown: a dragged crate's ADR 19 ceiling (~1.7 m/s)
  cannot reach the 4.0 m/s shed threshold, and that reads as intended rather than as a dragged
  crate being oddly harmless — two-player carry or a throw are the only ways to hit hard enough.
  Shed threshold ratified unchanged at 4.0 m/s / 1.5 s cooldown (Task 2 ruling 3, `01-08`).
- ~~A rack backed against a wall has a permanently unaimable back row~~ — **ruled on at the
  Phase 1 gate, [ADR 24](../decisions/2026-08-21-rack-presentation-ratified.md).** Accepted as a
  level-design property, corrected by one finding from play: the back row is reachable through
  the rack's own *end* faces wherever the level exposes one (NJ racked cells 8 and 0 that way).
  A wall rack is 6 cells head-on plus whatever its ends expose, not a flat loss of half its
  capacity. `Carrier._aim()` is unchanged — this was a design ruling, not an aim-code fix.
- **STORE-07, the round-trip invariant, is new and unbuilt** (named at the Phase 1 gate,
  2026-08-21): racking frees a crate's body, retrieval mints a fresh one, and every field the
  crate record carries (today only `kind`) must survive that trip intact —
  `retrieve(place(crate)) == crate` for every field, LIFO handing back a *different* crate of the
  same kind excepted. Load-bearing for Phase 3: an unfaithful round trip would let racking
  launder damage. Needs a concrete data shape once Phase 2 gives goods more than `kind`. See
  `REQUIREMENTS.md`.
- **Cell plaques are a Phase 2 recommendation, not a requirement** (GDD §6.3, ADR 24): per-cell
  signage on the loading face, anchored on the pallet's front edge, derived locally from a cell's
  own contents. Worth costing alongside whatever Phase 2 already needs for a store-until date
  display.
- **Large orientation is an open question for Phase 2 planning** (GDD §6.1, `REQUIREMENTS.md`
  GOODS-01): which two cells a Large occupies — side-by-side across columns, or front-to-back
  through depth, which would be the one layout that uses a wall rack's dead back row. Must be
  answered before Large cargo is built.
- **Seven smaller follow-ups from the Phase 1 gate, deliberately not fixed now — candidates for
  Phase 2 or Phase 6 scope, not yet plans:**
  1. The red BLOCKED cell highlight is invisible on a full cell — occluded by the eight racked
     visuals inside it, unreadable exactly when it matters most. Folds into follow-up 3 below.
  2. A carried crate passes through racked stock — racked items deliberately have no collision.
     Cheap candidate fix: one static, unreplicated collision box per occupied cell. Needs its own
     small decision, not built here.
  3. **Ghost-preview rework** (NJ's spec): placement feedback becomes a translucent crate at the
     exact `StorageGrid` lattice slot the next item will fill, green for fits / red for no room,
     retiring the glowing cell cube. Answers follow-ups 1 and the colour-blind deferral (Task 2
     ruling 5) at once. Phase 6.
  4. A grabbable-target indicator — a reticle cue when a crate is in reach. Phase 6.
  5. Settle "planting" reads too hard; soften it. Direction: per-kind settle feel once cargo
     types exist (bricks sit hard, light goods softer). Phase 2/6.
  6. Sprinting with a grabbed crate can jam the crate against the player — hold-spring tracking
     at sprint speed. Tuning list; stiffness 2400 / damping 460 remain provisional.
  7. A pre-existing intermittent one-resource leak at `storage_session.gd`'s client exit
     (`WARNING: ObjectDB instances leaked`), reproduced on unmodified code, unrelated to any
     gate-session change. Known open item, not blocking.
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
  8-minute day — **was timed at the Phase 1 gate (extra check F): a relaxed IN → rack → other
  rack → OUT loop completed under 60 s**, with caveats (small room, perfect knowledge, no
  obstacles in the way). The assumption holds, conservatively — real play with a full warehouse
  and searching will be slower, not faster, which is the safe direction for a sim input.

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
- **Unfreezing a `RigidBody3D` (`freeze = false`) does not by itself guarantee the solver treats it
  as awake.** `sleeping` is an independent flag, and a hold spring applying real force to a body
  that never actually reactivates looks identical to a broken hold from the outside — the crate
  sits motionless while its holder walks away until distance-break kicks in. Set `sleeping = false`
  explicitly on every wake path, not just on the shove path that already did (01-09).
- **`Time.get_ticks_msec()` around a `for _i in N: await get_tree().process_frame` block can vary by
  an order of magnitude run to run** — measured 6 frames taking anywhere from under a millisecond to
  ~40ms depending on process contention. A retry loop that waits N frames then re-checks a network
  response has a real, variable-width blind window, not a fixed handful of milliseconds — don't
  budget races against "6 frames" as if it were a constant (01-09, `carry_session.gd`'s `_take()`).
- **Settled cargo (ADR 17) blocks other cargo, not just players.** A crate dragged past another that
  has settled can be physically wedged by it, same as a player would be — real gameplay behaviour,
  found in `storage_session.gd`'s drag-attempt step once two other crates in the same row settled
  mid-scenario (01-09). Worth remembering when laying out players with clutter near a path
  cargo needs to travel.
- **A reach check must measure against the same point the interaction actually validates, not a
  simplified proxy.** `PLACE_REACH` measured camera → cell *centre*, but the aim ray resolves and
  the highlight paints against the ray's hit *point* — up to half a cell's own space diagonal
  further away. Genuine aims in that gap painted green and were then silently refused. Found live
  at the Phase 1 gate, fixed by widening the constant and re-deriving its doc comment from the
  real arithmetic rather than an assumption (`34409df`).
- **A freshly-minted body can trigger its own container's sensors before it has cleared them.**
  `request_retrieve` and `shed_top_row` both mint a crate at a cell's own centre — inside that
  rack's `ImpactSensor` by construction — so the very same spring or impulse that moves it out
  could push it past the rack's own shed threshold before it has properly left. Anything that
  spawns a body inside a sensor volume needs a short mint-grace window before that sensor trusts
  velocity readings from it (`Crate.age_ms()` / `MINT_GRACE_MS`, `69c77e6`).
- **A combined aim ray can resolve to the wrong thing when a loose object rests inside another
  object's own aim volume** — a shed crate landing inside a rack's `CellSensor` was permanently
  unaimable, because the ray hit the sensor's surface first. Fixed with a narrower, cargo-only
  probe tried first, but *only* while empty-handed — while holding something, the container must
  still win, or a stray loose crate in front of a rack face would hijack a placement aim
  (`8be63f8`).

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

## Phase 1 outcome

**Complete and gate-passed, 2026-08-21.** All 9 plans, all 7 waves. Verdict: *storage feels
deliberate* (NJ, explicit, after three play sessions). All six STORE requirements met and
ticked; the phase's own gate crib sheet is retired.

Delivered: `StorageGrid` (pure cell arithmetic for ADR 18, test-first, 183 unit checks); `Rack`
— twelve cells as atomic, LIFO-ordered data, delegating every dimension to `StorageGrid`, with a
zero-cost `racked_item.tscn` visual and host-side minting on retrieval; `CarryAuthority.
request_place`/`request_retrieve`, host-validated and ADR 19-aware, with one aim ray resolving
either a crate or a rack cell; a three-state cell highlight and a tweened travel-and-thud
placement snap, both proven to converge on every peer including a late joiner; a host-only
`ImpactSensor` that sheds exactly a rack's occupied top row on a hard enough hit, bounded three
ways against ADR 14; `GoodsZone`, a plain `Area3D` with zero networking machinery, both peers
independently agreeing on its contents over real ENet; and, closing the phase's one named gap,
ADR 17's settle/wake state machine on `Crate` — settled cargo turns real static geometry and
blocks players client-side with no round trip, wakes on a qualifying shove or grab, and is now
verified true underfoot rather than only mechanically proven.

Three real defects and one reach ruling came out of the gate's own play sessions, all fixed,
regression-tested and proven on the real path before this closing plan ran (`34409df` through
`aab3396`; full detail in the resolved blocks above and `01-08-SUMMARY.md`): a reach check that
measured against the wrong point; a freshly-minted crate that could shed its own rack on the way
out; a loose crate stranded inside a rack's sensor volume with no way to grab it; and the whole
reach chain shortened 2.5 → 2.0 m on NJ's ruling after it read too long twice in play.

Rack geometry and presentation were ratified at the gate rather than changed: the frame stays
exactly as built, but cargo now sits on a pallet with a peer-deterministic seeded jitter instead
of floating in an identical stamped pose ([ADR 24](../decisions/2026-08-21-rack-presentation-ratified.md)).
The wall rack's long-flagged unaimable back row was accepted as a level-design property with one
correction from play — it is reachable through the rack's own end faces. Neither of these
touched code; both are recorded as rules for Phase 6's art pass to build against.

Four things the gate surfaced are carried forward rather than closed: **STORE-07**, the
round-trip invariant a racked crate's full record must satisfy, load-bearing for Phase 3 and
unbuilt beyond `kind`; **cell plaques**, a Phase 2 presentation recommendation; the **open
question of which two cells a Large occupies**, to be answered in Phase 2 planning; and **seven
smaller follow-ups** (highlight legibility, cargo passing through racked stock, the ghost-preview
rework, a grabbable-target reticle, settle feel, a sprint/hold-spring jam, and one pre-existing
intermittent test-harness resource leak unrelated to any of this phase's own changes) — none
blocking, all listed under Open above.

Nothing this plan touched changed game code — every fix the gate needed was already made,
committed and regression-tested during the play sessions themselves; this plan's own work was
entirely the write-up: one new ADR, six requirements ticked, one new requirement added, the GDD
and roadmap brought up to date, and this file closed out.
