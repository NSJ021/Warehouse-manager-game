# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-17)

**Core value:** The dilemma is the game — patch and hope, confess, or comp.
**Current focus:** Phase 2 (Goods) planned 2026-08-21, **plan-checked and revised 2026-08-22 — cleared for execution.** 02-01 is **complete**: ADR 25 ratified and committed. NJ ruled `defer-it` on the save point (Phase 5 owns it) and rejected a fixed 24-crate delivery number in favour of two exported-tunable caps (body count, cell-equivalent volume) plus per-size composition limits, tuned in play against four named feel criteria. **02-02 is complete**: `CargoRecord` and `CargoCatalogue` (11 categories) landed, test-first, 489 checks including the design-property sweep. **02-03 is complete**: `DayClock` (host-authoritative, replicated `IDLE→MORNING→SHIFT→AFTER_HOURS→MIDNIGHT`) and `DockDoor` (an `AnimatableBody3D` roller door deriving itself from the clock) landed — inert until `main.gd` calls `begin_run()`, proven on two real headless peers, both existing integration scenarios byte-identical to before. **02-04 is complete**: Medium and Large crate scenes (inherited from `crate.tscn`) landed, `Crate.setup()` now rebuilds a full `CargoRecord` at spawn, and a mixed heavy row in `test_room.tscn` makes ADR 25 (c)'s weight deception real. Found and fixed a genuine bug along the way — `Rack.apply_cell_filled` hard-coded the stored cell kind to `&"small"`, silently correct only while every crate's kind really was that literal constant; this plan's own repurposing of `kind` into a real category broke that silently, caught before any test ran. **Wave 3 is now fully done.** **02-05 is complete**: `StorageGrid` gained ADR 25 (d)'s Large-pair geometry and ADR 24's corner-upright `mint_offset`, and `Rack`'s whole occupancy model was rebuilt around whole `CargoRecord` dictionaries and self-describing Large pairs — see the block below for the full detail, including the exact, single-line integration failure this plan hands to 02-06 by design. **Wave 4 is now done.**

> **Narrative history lives in `docs/conversation-log.md`, not here.** This file tracks
> execution position only. Duplicating the story in two places guarantees one of them
> goes stale.

## Current Position

Phase: 1 of 7 (Storage) — **complete.** Next: Phase 2 (Goods) — **cleared for execution 2026-08-22; waves 1-4 complete (02-01, 02-02, 02-03, 02-04, 02-05).**
Plan: Phase 2 planned 2026-08-21, revised 2026-08-22 — 11 plans (02-01 … 02-11) in **8 waves**, `.planning/phases/02-goods/`.
**02-01 complete, 2026-08-22.** ADR 25 (`decisions/2026-08-22-goods-taxonomy-dates-and-the-day-clock.md`)
is ratified and committed, with the three contradicted documents (`decisions/decision-log.md`,
`.planning/REQUIREMENTS.md`, `docs/GDD.md`) brought into line with it. NJ's rulings, verbatim per
`02-01-SUMMARY.md`:
1. **Save point — `defer-it`.** Clause (f) now says the ceremony *will be* the save point once
   saving is built, and names **Phase 5 (the run)** as the phase that owns it — the Lease Run
   wrapper lives there, and a 30-day term at 6–10 minutes a day makes saving mandatory. Phase 2
   builds no persistence.
2. **The delivery ceiling — rule shape, not a fixed number.** NJ agreed a ceiling is needed but
   rejected fixing 24 (or any number) in the ADR. Clause (f) now commits to two exported-tunable
   caps — a body-count cap guarding ADR 14's ~150-body envelope, and a separate cell-equivalent
   volume cap (a Large is 16× a Small in cell-equivalents per `storage_grid.gd`, mirroring ADR
   18's volume-not-items reasoning for storage fees) — plus per-size composition limits (Larges,
   Mediums), all scaling with crew size and settled in play at the Phase 2 gate. Four feel
   criteria are recorded as the tuning target: a morning delivery must feel worthy, deliberate,
   achievable and like earning your pay.

**Waves 1-4 done (`02-01`, `02-02`, `02-03`, `02-04`, `02-05`). Wave 5 (`02-06`) is next.**
Phase 1: 01-01 through 01-09 all complete — all 9 plans, all 7 waves done.
Status: **Phase 1 closed 2026-08-21.** The gate (01-08) passed — verdict "storage feels
deliberate," NJ, explicit, after three play sessions. Task 2's rulings are written into
[ADR 24](../decisions/2026-08-21-rack-presentation-ratified.md) and `.planning/REQUIREMENTS.md`;
full detail in `01-08-SUMMARY.md`.

> **✓ BOTH PRE-EXECUTION BLOCKERS RESOLVED 2026-08-22. Phase 2 is cleared for `/gsd:execute-phase 2`.**
>
> 1. **Plan check — DONE.** Ran plan-check → revise → re-check. The first pass found **three
>    blockers, all the same species**: the wave graph was arithmetically sound but ignored what
>    `.planning/config.json` actually does (`plan_level` parallelism, 3 concurrent agents), so
>    **every multi-plan wave had a coordination hazard**. (a) 02-01, the ADR checkpoint whose own
>    text says "do not begin any other Phase 2 work while this is open", shared wave 1 with 02-02
>    and 02-03 — `execute-phase.md:203` lets parallel agents *complete* while a checkpoint waits,
>    so both would have committed code against an unratified ADR. (b) 02-05 declares its own
>    integration stage red ("that is 02-06's job") while same-wave 02-07 required a green suite
>    over three runs — structurally unreachable in one working tree. (c) 02-09 and 02-10 both
>    edited `rack.gd` in wave 6, undeclared in 02-10's `files_modified`. All three fixed by
>    dependency edges and one API relocation; re-check returned **zero blockers**.
> 2. **Save logic — RULED.** NJ ruled **`defer-it`** at the 02-01 checkpoint, 2026-08-22: the
>    midnight ceremony's save-point clause in ADR 25 is reworded to say it *will be* the save
>    point once saving is built, naming **Phase 5 (the run)** as the phase that owns it — the
>    Lease Run wrapper lives there, and a 30-day term at 6–10 minutes a day makes saving
>    mandatory. Phase 2 builds no persistence of any kind; the day boundary and the v1 join
>    window are the only two of the three ceremony roles this phase actually builds, and ADR 25
>    now says so plainly rather than asserting a save point nothing implements.

> **Revision detail (2026-08-22), since `.planning/phases/` is repo-excluded and this is the durable record:**
> Wave graph went 7 → **8 waves**: w1 `02-01` (alone) | w2 `02-02`, `02-03` | w3 `02-04` |
> w4 `02-05` | w5 `02-06` | w6 `02-07`, `02-08` | w7 `02-09`, `02-10` | w8 `02-11` (gate, alone).
> 02-07's new dependency on 02-06 is a **scheduling fence, not a code dependency** — a note in the
> plan tells its agent that a red suite on arrival is a real regression to diagnose, not 02-05
> leftovers. The `rack.gd` conflict was fixed **at source** rather than by serialising: the
> write-through API `Rack.apply_record_update(cell, crate_id, changes)` moved into 02-05 (which
> owns the cell-record data model), while its RPC wrapper `CarryAuthority._record_updated(...)`
> went to 02-06 — because 02-05 is deliberately wire-free and `rack.gd` has **no RPCs at all**, a
> property 02-09's verification greps to preserve. 02-10 now touches neither file and carries a
> `git diff --stat …/rack.gd shows nothing` assertion. **No plan's build content changed otherwise.**
> Verified independently: every wave == max(dep waves)+1, zero same-wave `files_modified`
> collisions, both checkpoints alone in their waves, no cycles, all 11 files byte-scanned **pure
> LF, zero CR** (a re-check warning claiming CRLF was a false positive from its own grep quoting).

Last activity: 2026-08-22 — **02-05 executed: the rack holds three sizes and remembers whole
records, wave 4 complete.** `scripts/world/storage_grid.gd` gained ADR 25 (d)'s Large-across-
two-cells arithmetic — `capacity_for_size`/`cells_for_size` (deliberately different questions:
a Large's capacity in a cell is 1, its footprint is 2, and conflating them is how a Large ends
up thought of as "capacity 0.5"), `large_partner_cell` (the `1 - n` flip that only works because
ADR 18 fixes `RACK_COLUMNS`/`RACK_DEPTH` at exactly 2, asserted directly rather than merely relied
on), `pair_centre`, `large_yaw` — and ADR 24's corner-upright fix, `mint_offset`: a body minted at
a bare cell centre intersects the rack's own uprights unless it's small enough to clear them
(true of nothing bigger than a Small), so a Medium or Large now mints shifted toward the rack's
own horizontal centre by `MINT_CLEARANCE` (0.12 m) on whichever axis it doesn't already span the
full 2 m width. **The occupancy DECISIONS moved here too** — `cell_can_accept` and
`cell_apply_record_update` — specifically so a bare `--script` unit test could call the real
production rule rather than reimplement it a second time and risk the two silently disagreeing
(`Rack` is a `Node3D` and cannot be instantiated in that kind of run). `scripts/world/rack.gd`'s
whole `_cells` shape was rebuilt: `{kind, ids}` (bare crate ids) became
`{category, items, size, partner, anchor, orientation}` (a LIFO stack of **whole** `CargoRecord`
dictionaries), and all seven of 01-03's Small-shaped methods were re-decided against it rather
than patched — `can_accept` now delegates to `StorageGrid.cell_can_accept` and gained a `size`
argument (a Large routes to the new `can_accept_large` instead); `add_to_cell`/`remove_from_cell`
move whole records; `add_large`/`remove_large` are the only two functions ever allowed to touch a
Large's `partner`/`anchor`/`orientation` fields, and a Large's two cells each hold their **own**
duplicated copy of the same record (self-describing halves, not one record plus a link — a late
joiner or a future plaque reads either half with no link to resolve first); `apply_cell_filled`/
`apply_cell_cleared` handle a Large's two halves as one unit and stop hard-coding
`Crate.KIND_SMALL`; `occupancy_snapshot` ships full records for a late joiner; and
`occupied_cells_in_top_row` returns a Large's anchor only, so a shed can never spawn the same
Large twice (supply conservation). **`apply_record_update(cell, crate_id, changes)` is new**: the
write-through editor for a record already racked (02-10 needs this to bump a missed collection's
`store_until_day`), local-only — `rack.gd` still has zero RPC annotations of any kind, verified by
grep, and two doc comments were rewritten mid-plan once that same grep turned up 4 hits from
**prose describing the property**, not real ones. Racked visuals now scale the node per size
(base 0.5 m mesh unchanged, so the api layer's own mesh-size assertion stays true) with ADR 24's
inset applied on top, and 01-06's placement tween was fixed to animate from/to that inset scale
rather than the literal `1.0`/`1.06` it used before — unfixed, a Medium or Large would have
snapped to roughly a quarter size mid-flight.
**One real, deliberate deviation, empirically verified rather than assumed**: `apply_cell_filled`'s
two new parameters (a record, an orientation) are left **without a GDScript static type**,
confirmed by three isolated headless experiments that a statically-typed mismatch against a
known-typed caller (`carry_authority.gd`'s `rack: Rack`) is a **parse-time** failure in this
engine, not a runtime one — typing them properly would have made the still-stale
`_cell_filled` RPC handler fail to *load*, taking every scene using `CarryAuthority` down with it
in `smoke`, rather than the clean, isolated `integration`-only runtime failure this plan is
supposed to end with. **`can_accept`'s three call sites, in `carrier.gd` and `carry_authority.gd`,
were fixed in this plan** (not left stale) — the plan's own Task 2 text explicitly instructed
this, a mechanical `.size` argument addition using a field `Crate` already has (02-04); a Large
still cannot be racked through either path, since nothing chooses an orientation yet.
**`./tools/run-tests.ps1` confirms exactly the intended shape, twice, byte-identical**: `api`
(115 assumptions) / `unit` (491 cell-arithmetic checks, up from 183, plus the existing 489+56) /
`smoke` (11 scenes) all green; `integration`'s `carry` scenario is fully green and untouched
(27/23 steps); its `storage` scenario fails **exactly once**, on both peers, at
`Rack.apply_cell_filled` (`rack.gd:628`), reached via `CarryAuthority._cell_filled` — the exact
call site this plan's own doc comments named as 02-06's to fix, with the wire itself needing a
record and an orientation instead of a bare crate id and kind. No other engine error, warning,
leak or crash anywhere in either run. Two commits: `7bef143` (StorageGrid geometry + occupancy
rules + 308 new unit checks), `76cd7b2` (Rack's rewrite + the two mandated caller fixes). Full
detail, including the exact cell shape and the precise call-site fix 02-06 inherits:
`02-05-SUMMARY.md`.

Before that, 2026-08-22 — **02-04 executed: Medium and Large cargo landed, weight decides the
hold, wave 3 complete.** `crate.gd` gained a real `record: CargoRecord`, a `size`
(`CargoCatalogue.Size`), and repurposed `kind` (ADR 25 (a): "kind" is now the category — atomicity
in `Rack.can_accept` keys off it exactly as it always did, unchanged). `setup()` widened to
`setup(record_data: Dictionary, spawn_point: Vector3)`, rebuilding the record with
`CargoRecord.from_dict()` and applying `id`/`kind`/`size`/`mass` from it — mass comes from the
record, never the scene, so one Medium can be light textiles and the next heavy masonry.
`crate_medium.tscn` (1.0 m cube) and `crate_large.tscn` (2.0 × 1.0 × 1.0 m) both **inherit**
`crate.tscn` rather than duplicating it, each resizing `Collision`/`BodyMesh` to ADR 18's exact
dimensions and `PushSensor` to body size + 0.12 m on every axis; the Large's `editor_description`
fixes the orientation convention 02-05/02-07 depend on — **the 2 m axis is local X**. `test_room.gd`
spawns through a size-keyed `CRATE_SCENES` dictionary and mints every starting crate's full
`CargoRecord`; rows 1-2 (`crate_0`..`crate_11`) stay Small in the same positions (every category
checked in code against `SOLO_CARRY_MASS_LIMIT`, printed rather than `push_warning`'d), and a new
mixed heavy row (`crate_12`..`crate_16`, checked against every corridor and fixture before
placement) adds a heavy masonry Small, a light textiles Medium, a heavy masonry Medium, and two
Larges of different categories (machine_parts 108 kg, white_goods 96 kg) — `crate_count` 12 → 17.
`engine_assumptions.gd` gained ADR 18's Medium/Large dimensions, the always-strictly-larger
`PushSensor` rule, the pinned layer/mask, the Large's 2 m-axis-is-X assertion (ADR 25 (d)), and
confirmation the Large scene's own fallback mass alone exceeds the solo-carry limit.
**One real bug found and fixed before any test ran, not by a red run**: `Rack.apply_cell_filled`
hard-coded the stored cell kind to `Crate.KIND_SMALL`, silently correct only because every crate's
own `kind` was *also* always that same literal constant before this plan. The moment `kind` became
a real category, the hard-code became actively wrong — the first crate into an empty cell always
succeeds, but the *stored* kind stays `&"small"`, so a second, same-category crate into that cell
would be refused as a false mismatch (`storage_session.gd`'s own "client racks crate_1 into the same
cell" step exercises exactly this). Fixed by threading the crate's real kind through
`Rack.apply_cell_filled` (now takes a `kind: StringName` parameter) and `CarryAuthority._cell_filled`
(the RPC gained the matching parameter) — **`rack.gd` still has zero `@rpc` of its own**, so 02-09's
"no RPCs in rack.gd" property (see the wave-revision block above) still holds; verified by grep.
`crate_0`/`crate_1` (the pair `storage_session.gd` racks into one cell) are deliberately given the
same category (`textiles`) so that step keeps proving genuine same-category stacking. **Touches two
files outside this plan's own `files_modified`** (`rack.gd`, `carry_authority.gd`) — a deliberate,
narrow Rule 1 fix, not scope creep; full reasoning in `02-04-SUMMARY.md`. **02-05, which owns the
rack's full occupancy-model redesign, should build on this rather than revert it** —
`apply_cell_filled`'s signature is now `(cell, crate_id, kind, from_position)`, not the 3-arg form
the wave-revision notes above were written against. No live human playtest of the heavy row was
performed (this plan has no checkpoint); the mass→drag wiring is proven by 02-02's own catalogue
sweep plus the untouched, already-tested `_refresh_hold_mode()` mass check, not by a new interactive
session — the heaviest Large's hold-spring sag (~44 cm at 108 kg) is measured and recorded as a
question for the wave-7-equivalent gate (02-10), not pre-tuned. `./tools/run-tests.ps1` green three
consecutive runs (no red seen at any point — the atomicity bug was caught by code review before the
first run, not by a failing one); `./tools/run-stress.ps1` re-run clean, host upstream unchanged at
93.4 kb/s across the sweep. Three commits: `8825b8f` (crate scenes + record), `c871368` (spawn by
size + heavy row + the atomicity fix), `f7f0fba` (api layer invariants). Full detail:
`02-04-SUMMARY.md`.

Before that, 2026-08-22 — **02-03 executed: `DayClock` and `DockDoor` landed, wave 2 complete.**
`scripts/world/day_clock.gd` (`class_name DayClock`) is a level-scoped, host-authoritative,
group-found `Node` (never an autoload — the exact temptation `docs/project-structure.md` names ahead
of time), replicating `sync_day`/`sync_phase`/`sync_elapsed` at 5 Hz via a `MultiplayerSynchronizer`
(day/phase on-change, elapsed always). Five phases (`IDLE→MORNING→SHIFT→AFTER_HOURS→MIDNIGHT`), five
past-tense signals, `begin_run()`/`advance_to_next_day()`/host-gated `request_call_it_a_night()`
(ADR 21's precedent — ignored from a non-host or outside `AFTER_HOURS`). **Inert by construction**:
`_advance_host()`'s first line returns while `sync_phase == IDLE`, and nothing but `main.gd`'s
`_on_session_started()` (host-only) ever calls `begin_run()` — `TestRoom` itself was not touched.
`scripts/world/dock_door.gd` (`class_name DockDoor`) derives its own open/closed position from the
clock's replicated phase every physics frame (zero networking of its own, `GoodsZone`'s own shape),
driven by an `AnimatableBody3D` slab (`sync_to_physics`) lerped toward a target rather than a `Tween`
— self-correcting for a late joiner or a missed update, no special case needed. Before a close starts,
the host wakes any settled (`FREEZE_MODE_STATIC`) crate caught in the doorway via a new public
`Crate.wake()` (delegates to the existing private `_wake()`) — an `AnimatableBody3D` cannot displace a
frozen static body, only intersect it, measured and pinned in `engine_assumptions.gd` rather than
assumed. `test_room.tscn`'s north wall is cut around a 3.0 m door gap (above `GoodsIn`) and its west
wall around a permanent, doorless 2.0 m personnel gap (ADR 25 (f): a player is never locked in or out
— the simplest possible implementation is a hole, not a mechanic); neither cut touches any
integration-suite corridor, checked against the actual stand-points and waypoints in both test files
before either position was chosen. `main.gd` calls `begin_run()` once, host-only, after the world
loads; a new `--day-length=N` launch arg overrides it for hand-testing; the HUD gained a
day/phase/countdown line that reads "DOORS CLOSING IN" inside the klaxon window (ADR 25 (f):
information asymmetry lives on the screen, never only in audio); "N" (`call_it_a_night`, added
through the running editor's own `ProjectSettings` + `save()`, not a direct file edit, since the open
editor rewrites `project.godot` from its in-memory copy) requests the early close. `engine_assumptions.gd`
gained RUN-02's day-length **bound** (360–600s, not a value — ADR 25 (f) leaves the number unagreed),
`open_fraction`'s and `morning_seconds`' own bounds, and a measured AnimatableBody3D-vs-dynamic/frozen-
static behaviour pin. **Both existing integration scenarios are byte-identical to before this plan**
(`git diff --stat` empty on both) — proven, not merely intended, across five full-suite runs at
identical step counts. A real two-headless-peer run through `main.tscn` (`--day-length=48`, outside
the committed suite) showed the whole loop close on both peers' own logs: `day 1 -> MORNING -> SHIFT
-> AFTER-HOURS -> MIDNIGHT -> day 2 -> MORNING`. **Two new `class_name`s needed the editor rescan**
(`DayClock`, `DockDoor`) — same raw-WebSocket approach as 02-02, verified against
`global_script_class_cache.cfg` before trusting a result. The plan's summary reported the
`storage_session.gd` client-exit leak recurring twice across five runs and recorded it as a standing
flake; **that was re-checked immediately afterwards and is not reproducible — the leak was fixed in
`2300da7` and has since passed 11 consecutive clean runs.** See the corrected note in the traps
list below for what actually explains a red storage run. Three
commits: `8d54e6f` (the clock), `c9fd83b` (the door), `631970c` (wiring + the HUD + the bound). Full
detail: `02-03-SUMMARY.md`.

Before that, 2026-08-22 — **02-02 executed: `CargoRecord` and `CargoCatalogue` landed, test-first.**
`scripts/goods/cargo_record.gd` is STORE-07's round-trip snapshot (id, category, variant, size,
fragility, mass, declared_value, store_until_day, owner, condition actual/apparent, drag_distance),
pure `RefCounted`, `to_dict()`/`from_dict()` wire-safe and tolerant of a missing field.
`scripts/goods/cargo_catalogue.gd` is the ADR 25 taxonomy: 11 categories (masonry, tinned, textiles,
powders, machine_parts, ceramics, glassware, electronics, white_goods, novelty, dodgy), each with a
weight band per size, 0-3 fragility, a value density, a plaque label, 3+ variants and a greybox decal
tint, built as a lazily-cached static table rather than `.tres` Resources. `test/unit/cargo_taxonomy_test.gd`
was written first against neither file (watched fail by naming both missing scripts), then made to
pass task by task: 489 checks, including a design-property sweep proving the ADR 25 (c) weight
deception both ways (2 categories' Smalls over `Crate.SOLO_CARRY_MASS_LIMIT`, 6 under half of it),
every Large over the limit and under ~110kg (hold-spring sag bound), Mediums split both ways, every
category's value staying inside `Dilemma.VALUE_REFERENCE` (2000) across a 1-10 day sweep, the dodgy
flag, and fragility/value as independent axes. The 30-day value overflow the planner already flagged
is now a proven, not just anticipated, Phase 4 finding (worst case at 10 days is 945, comfortably
inside; the same categories at 30 days would reach 2835). **Two new `class_name`s needed the editor
rescan** (`CargoRecord`, then `CargoCatalogue`) — triggered both times via the MCP bridge's raw
WebSocket protocol directly (no MCP tool was exposed to the executing agent's own toolset; a small
one-shot Node script sent `get_project_info` then `execute_editor_script`), verified both times by
grepping `global_script_class_cache.cfg` before trusting a test result. **Full suite green, three
consecutive clean runs** — but getting there surfaced and fixed a real, if minor, side issue: an
early attempt at automating the retry (a backgrounded PowerShell loop) left two orphaned Godot
processes squatting on port 27097 between iterations, found via `tasklist`/`netstat` and killed;
even after confirming a clean process/port state, `storage_session.gd`'s already-documented
client-exit resource leak (see the wave-7-gate block below) still surfaced intermittently — confirmed
unrelated to this plan's files (`grep -rl "CargoRecord\|CargoCatalogue"` finds only the three files
this plan created) before accepting it as the same pre-existing flake. Three commits:
`91422b0` (failing test), `3d125c5` (CargoRecord), `b7ffea9` (CargoCatalogue). Full detail:
`02-02-SUMMARY.md`.

Before that, 2026-08-22 — **02-01 resumed and completed: NJ's rulings applied, ADR 25 committed.**
Save point ruled `defer-it` (clause (f) reworded to say the ceremony will be the save point once
saving is built, naming Phase 5 as the owning phase — no save point is claimed for Phase 2). The
delivery ceiling reframed from a fixed 24-crate commitment to a rule shape: a body-count cap
guarding ADR 14, a separate cell-equivalent volume cap (a Large is 16× a Small in cell-equivalents
per `storage_grid.gd`, mirroring ADR 18's volume-not-items reasoning), and per-size composition
limits, all exported tunables scaling with crew size, tuned in play against four named feel
criteria (worthy, deliberate, achievable, earning your pay) rather than fixed in the ADR. One
commit: `docs(02-01): ratify the goods taxonomy, Large orientation, dates and the day clock`. Full
detail: `02-01-SUMMARY.md`. Before that, same day — **02-01 execution started, Tasks 1–2 done,
paused at the Task 3 checkpoint.** ADR 25 drafted in full (six clauses, all four Consequences
sub-headings, four alternatives) and `decisions/decision-log.md` / `.planning/REQUIREMENTS.md` /
`docs/GDD.md` brought into line with it. **Nothing committed at that point** — the plan's own
instruction held the ADR uncommitted until NJ named the save-point ruling, since it could still
change clause (f)'s wording. One deviation beyond the plan's literal task list: the plan named only
GOODS-01/02/03 for `REQUIREMENTS.md`, but its own verification greps both `REQUIREMENTS.md` and
`GDD.md` for the word "spoilage" and expects nothing left claiming it damages cargo — that also
caught `DMG-01` (still listing spoilage as a damage source) and one flavour line in GDD §4's 90-day
row (a different, pre-existing spoilage mention, about a future 90-day term's own environmental
pressure, not the store-until-date mechanic). Both fixed to match ADR 25 rather than left to fail
the plan's own check. Before that, earlier the same day —
**Phase 2 plan-checked and revised**: three scheduling blockers found and fixed, re-check clean,
7 → 8 waves (see the resolved blocker block above). Before that,
2026-08-21 — **Phase 2 planned**: 11 plans written and cross-checked
against the tool's plan index (CRLF frontmatter trap checked — all files LF). Wave 1 blocks on a
human checkpoint (02-01, the ADR 25 draft); the **wave 8** gate is 02-11. Three planner findings
worth reading before executing: the rack's corner uprights sit inside corner-cell footprints, so
Medium/Large minting needs `StorageGrid.mint_offset` (02-05/02-06); the day clock must stay inert
in `test_room.tscn` until `begin_run()` or both existing integration scenarios break (02-03); and
value bands overflow ADR 20's £2000 detection ceiling on 30-day contracts (assertion bounded at
10 days, recorded as a Phase 4 finding — densities left as ADR 20 calibrated them). Roadmap
update committed as `5d930a2` on `feat/phase-2-goods`, nothing pushed. Before that: 01-08 executed, closing the phase: see the resolved block below for
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
7 waves — gate passed 2026-08-21. Phase 2: waves 1-4 complete (`02-01`, `02-02`, `02-03`, `02-04`,
`02-05` — 5 of 11 plans); waves 5-8 still to execute.

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
| 25 — goods taxonomy, dates, day clock | Phase 2 directly. Category-level atomicity (`CargoCatalogue`, 02-02) is the definition of ADR 18's "kind"; store-until dates are contract properties with no spoilage timer; both Large orientations are player-chosen; the roller door is the day clock, save point deferred to Phase 5 |

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
- ~~Large orientation is an open question for Phase 2 planning~~ — **answered, ADR 25 (d), 2026-08-21:
  both orientations are player-chosen, not fixed.** The convention the code now depends on (2 m axis
  is local X) is built and pinned: `crate_large.tscn`'s own `editor_description` and
  `engine_assumptions.gd` (02-04, 2026-08-22). The two-cell footprint and the rotate control itself
  are still 02-05/02-07's own work, not built yet.
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
- **The day loop's frame is built** (02-03): `DayClock` and `DockDoor` land the phases, replication,
  the klaxon/HUD warning and the host's early-close, all inert until `main.gd` calls `begin_run()`.
  **No committed test yet exercises a peer joining mid-phase against a running clock/door** — the
  late-joiner claim rests on the clock's continuously-broadcast replication shape and the door's
  stateless lerp target, reasoned through rather than proven by a dedicated scenario. Whichever of
  02-06/02-07 first calls `begin_run()` with a short day length should add this as one more
  assertion. Feel questions (does 8 minutes read right once real content exists; does the greybox
  door/gap read as intended) are carried to the Phase 2 gate, not answered here.

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
- **A bare `--script` `SceneTree` run does not register the `Net` autoload — this reaches further
  than "don't reference a `class_name` statically."** `engine_assumptions.gd` already knew not to
  hold a static reference to `Crate`/`Rack` for that reason, but it also never calls `add_child()`
  on anything it builds, so `_ready()` never runs. Actually **adding** `test_room.tscn` to a live
  tree in a bare `--script` run (tried once, 02-03, as a manual verification shortcut) crashes
  repeatedly with `Invalid call. Nonexistent function 'phase' in base 'Nil'` the moment any node's
  `_ready()` touches `Net` (`TestRoom`, `CarryAuthority`, …) — because the autoload genuinely is not
  there, not because of a compile-time dependency. A real headless host+client through `main.tscn`
  is the only way to exercise `_ready()` for real outside the committed test harness.
- **The godot-mcp bridge's `execute_editor_script` `print()`→`custom_print()` rewrite truncates on
  the first closing paren, not the statement's own.** `print(ProjectSettings.get_setting("x"))`
  fails with `Script parsing error: 43`, because the regex stops at `get_setting("x")`'s own `)`.
  Not the documented "one statement only" limit — don't wrap a nested call in `print()` over this
  bridge; verify by grepping the affected file on disk instead (02-03).
- **The `storage_session.gd` client-exit resource leak is FIXED (`2300da7`), and the instruction
  that briefly stood here — "re-run rather than treat it as a regression" — is WITHDRAWN.**

  Diagnosed 2026-08-22 by running the client with `--verbose` against the **editor** binary: the
  last rack placement's positional thud was still in flight at `quit()`, so its
  `AudioStreamPlaybackWAV` outlived the tree and `rack_place.wav` was still referenced at exit.
  `_finish()` now silences audio first. An earlier attempt had concluded the detail was
  unavailable because the *export* build carries no leaked-object names; the suite uses the editor
  binary, which does.

  **Evidence it is fixed: 11 consecutive clean runs** — 6 targeted storage-client runs, then 5 full
  suites. At the original "roughly every other run" rate, 11 clean in a row is about a 1-in-2000
  coincidence.

  02-03's summary reported it recurring 2 of 5 runs and recorded it as a standing flake. **That is
  not reproducible and the conclusion was wrong.** Two documented causes in this same session
  explain a red storage run without any leak: **orphaned Godot processes squatting on port 27097**
  (02-02 hit exactly this and had to kill them by hand), and **editing `test_room.tscn` through the
  editor bridge while a suite is running**. Both look like an unrelated failure if you assume a
  known flake instead of reading the log.

  **The standing rule is the project's own:** a flaky suite is worse than none, because it trains
  you to ignore red. Never re-run to get past a failure. Read the log, confirm the actual error
  lines, and check for stray processes. If a genuine leak signature returns, it is a new defect and
  needs its own diagnosis, not a re-run.

- **⚠ How to tell a stray test process from NJ's editor — get this wrong and you kill the editor.**
  List them with `Get-CimInstance Win32_Process -Filter "name like 'Godot%'"` and read the **full**
  command line.

  **Match on `--headless`, never on `--editor`.** Every test process is launched `--headless`; the
  editor never is. An earlier version of this note said to spare "the one whose command line
  contains `--editor`" — **that is wrong and dangerous**, because Godot accepts the short form `-e`,
  and the editor commonly appears as:

  `Godot_v4.6.2-stable_win64.exe --path "…/warehouse-manager" -e res://scenes/levels/test_room.tscn`

  A `--editor` substring test does not match that, so an agent tidying up orphans would have killed
  the open editor — taking the MCP bridge and the class-cache rescan with it. **Kill only processes
  carrying `--headless`.** Everything else is left alone.

- **⚠ `rpc_id(-1, …)` is not valid in Godot 4, and it fails in the most misleading way available.**
  `0` is broadcast, any **positive** value targets one peer. Godot 3's "negative peer means everyone
  *except* that peer" form was removed and **there is no exclude form at all** — to skip a peer you
  loop `multiplayer.get_peers()` and skip the id yourself.

  **Why this earned a trap entry rather than a code comment:** it does not raise where you wrote it.
  The engine drops the call with `ERROR: Attempt to call RPC with unknown peer ID: -1` into
  **stderr**, the host's own state stays perfectly correct, and the symptom appears as a **20-second
  timeout in whichever client assertion was waiting on state that was never sent** — potentially
  dozens of steps away from the bug. On 02-06 that read as a sync/race problem and cost about ninety
  minutes; the host was passing all 96 of its own steps the entire time.

  Now guarded three ways: an api-layer assumption pins `TARGET_PEER_BROADCAST == 0` with the
  reasoning; `run-tests.ps1` repeats the engine's own error text in the **verdict block** rather than
  only mid-run; and this entry exists.

- **⚠ Read BOTH log streams. Assertions go to `*.out.log`; engine errors go to `*.err.log`.**
  A failing assertion and the engine error that *caused* it live in different files. Tailing only
  `.out` shows you a timeout with no cause anywhere near it. The suite's verdict block now echoes the
  engine lines, but when reading raw logs, open both — this is the single cheapest habit for cutting
  debugging time on this project.
- **A hard-coded fallback constant that happens to equal every real value today will silently stop
  matching the moment one field stops being a constant.** `Rack.apply_cell_filled` stored
  `Crate.KIND_SMALL` (`&"small"`) as a cell's kind regardless of what was actually placed — invisible
  through all of Phase 1 because every crate's own `kind` was *also* always that same literal
  constant, so the mismatch check it fed (`Rack.can_accept`) always agreed with itself. The moment
  02-04 made `kind` a real category, the hard-code became wrong for every crate, and the bug was
  only ever going to be caught by a test that stacks two different real crates in one cell —
  exactly what `storage_session.gd` already did. Fixed by threading the real kind through
  `apply_cell_filled` and the `_cell_filled` RPC rather than deferring it, because it blocked this
  plan's own required green suite (02-04). **`rack.gd` still has zero `@rpc` of its own** — 02-09's
  "no RPCs in rack.gd" property (see the wave-revision note above) still holds; `apply_cell_filled`'s
  signature is now `(cell, crate_id, kind, from_position)`, a 4th parameter 02-05 needs to know about
  before touching this file again.

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
