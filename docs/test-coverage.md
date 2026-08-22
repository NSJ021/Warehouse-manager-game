# Test coverage — what is guarded, what is not, and what to do about it

Audited 2026-08-22 by three independent sweeps — requirements against assertions, ADR-fixed numbers
against the api layer, and reachability of real player paths — then every load-bearing claim
re-verified by hand before it was written down here.

**Nothing in this document is done.** It is a ranked proposal. Items move out of it as they are
built, and the ones deliberately left undone stay here with their reason, because a declared gap is
tracked and an undeclared one is found by accident.

## Why this exists

The Phase 1 gate found **three real defects that a fully green suite missed** — a reach mismatch,
self-shedding on retrieval, and stranded stock. That is the standard this document is written
against. A green suite means *the assertions someone wrote still hold*. It never means the code is
right.

## What is genuinely well covered

Worth stating first, so the rest is read as a list of specific gaps rather than a verdict.

The risky multiplayer core — grab, two-player carry, handoff, solo drag and its promotion, rack
place and retrieve, LIFO, supply conservation, despawn replication, and three Phase 1 gate
regressions — is driven through the **real player path** on two real processes, with each peer
checking its own replicated state rather than trusting the other's. The pure-logic layer is unusually
strong, including design-property sweeps (the no-dominant-strategy check rejected a balance change on
its first run). 116 engine assumptions are pinned.

One thing the audit got right and is worth trusting it for: ADR 20's detection numbers are
deliberately pinned as **shape** — monotonicity, zero-at-lease-end, the no-dominant-strategy sweep —
rather than as literals, because the ADR says they are the first thing that will need retuning. That
is a considered split, not a gap.

---

## Tier 1 — DONE 2026-08-22 (`7ddee5a`)

All four closed. Recorded below with their reasoning intact, because the *why* is the part worth
keeping — each was correct code with nothing holding it in place, which is the shape to keep hunting.

- **1.1 `replication_mode`** — now asserted per property (five on-change, zero not), and the
  interval's label reworded so it stops implying it covers the whole decision.
- **1.2 The shed comment's arithmetic** — corrected, with the wrong reasoning preserved as a
  warning rather than deleted. **The behaviour question is still open** and belongs to the gate:
  measure a sprint-carry's real crate velocity at the sensor before the number moves.
- **1.3 The shed trigger measures speed where it needs momentum** — **STILL OPEN.** The comment now
  says so plainly; the fix waits on 1.2's measurement, since changing the quantity and the threshold
  blind would be guessing twice.
- **1.4 Goods zones after settling** — now re-asserted once the probe has settled, guarding the `|=`
  that keeps a settled crate visible to Goods OUT.

## Tier 1 — original findings

### 1.1 ADR 14's bandwidth fix is unguarded, and the test that looks like it covers it does not

The fix that took host upstream from **1497 kb/s to 93 kb/s** was moving cargo replication to
**on-change** at 20 Hz. Two halves, one guarded:

| Half | Status |
|---|---|
| `replication_interval` ≈ 0.05 (the 20 Hz part) | **Pinned**, under a label reading "cargo still replicates at 20 Hz" |
| `replication_mode = 2` (ON_CHANGE — the part that did the work) | **Asserted nowhere.** Verified by grep across the whole test tree |

So a green suite reads as covering ADR 14 and does not. Revert one property's mode — a copy-paste
from an older crate template would do it — and a 16× bandwidth regression returns. ADR 14 warns this
failure is **silent in play**: host traffic *falls* as crate count rises, crates lag on clients,
nothing announces it.

**Proposed:** assert `replication_mode == 2` for **every** replicated property in `crate.tscn`'s
`SceneReplicationConfig`, not just the interval — and reword the existing assertion's label so it
stops implying more than it checks.

### 1.2 The shed threshold's justification is arithmetically wrong, and sprint-carry may shed racks

`rack.gd`'s comment argues:

> 4.0 sits above the player's own 4.2 m/s walk speed only barely…

**4.0 is below 4.2.** The real argument underneath is that hold-spring lag keeps a carried crate
slower than its holder — which is untested — and the comment is **silent about `SPRINT_SPEED := 6.4`**.

Worse, `Crate.lag_compensation` is explicitly built to *cancel* steady-state lag ("1.0 cancels it
exactly"). A steady sprint-carry should therefore converge the crate toward the holder's speed —
toward 6.4 m/s, well over the 4.0 gate. **Sprint-carrying a crate into a rack corner may shed it.**

This joins a known Phase 1 gate finding — *"sprinting with a grabbed crate can jam the crate against
the player"* — that nobody connected to shedding. The comment itself admits the footing:
*"Confirmed with a thrown crate only; a human check with one actually in hand is still owed."*

**Proposed:** measure it first, then decide. Drive a two-player carry at sprint past a loaded rack
and record the crate's actual `linear_velocity` at the sensor. If it exceeds 4.0, this is a live bug
and the threshold, the comment, or both are wrong. **Fix the comment's arithmetic regardless** — a
justification built on a false premise will mislead the next reader even if the number survives.

### 1.3 The shed trigger measures the wrong quantity, and nothing asserts it at all

`rack.gd`: `if crate.linear_velocity.length() < shed_impact_speed`. Speed only, no mass.

Before wave 3 every crate weighed 12 kg, so this *was* a momentum test up to a constant. ADR 25 gave
crates real masses (5 kg textiles to 108 kg machine parts) and it silently stopped meaning what the
gate calibrated it to. A 5 kg Small trips it carrying 20 kg·m/s; a 108 kg Large trips it at the same
speed carrying twenty times that. **The gate-ratified 4.0 has no assertion anywhere.**

**Proposed:** switch the trigger to momentum (`mass × speed`), and add both a positive assertion and
the **negative case that does not exist today** — nothing currently proves an ordinary bump *fails*
to shed a row. The design model is worked out in `idea-book.md`'s "Rack shedding, revisited"; the
drama-versus-silly numbers belong to the gate, but the momentum fix is a defect fix and does not.

### 1.4 Goods OUT counting settled stock is correct, and one character breaks it

Settling does `collision_layer |= LAYER_WORLD` — ORing the world bit in, so a settled crate stays
tagged as cargo and `GoodsZone`'s mask still sees it. Deliberate, with the reasoning in the code.

The zone check runs **before** the probe crate settles and never re-checks after. Change that `|=`
to `=` and Goods OUT silently stops seeing stock that has sat there all day — the outbound half of
the entire loop — and nothing fails. The test that flagged this risk says so itself: *"That is a
design constraint on GoodsZone, not a test artefact — report it rather than working around it."*

**Proposed:** re-assert `GoodsZone.count()` **after** the crate settles, not only on entry.
One line, and it guards the loop's outbound half.

---

## Tier 2 — real gaps, moderate cost

### 2.1 The day clock and dock door have no behavioural coverage — PARTIALLY DONE 2026-08-22 (`f5a233a`)

**The clock half is closed.** `goods_session.gd` (02-07) is the first and only thing that ever
calls `begin_run()` — with a short `day_length_seconds`, asserting on **both peers** that the
phases transition in order (`MORNING → SHIFT → AFTER_HOURS → MIDNIGHT`), the day increments, and
the door reads open (via its own slab position, not the clock — see below). It also proved a real,
previously untested bug: the host's early-close request accepted ANY peer's call, not just the
host's own — fixed (`_sender_id() != 1`), then proven correctly refused by a client's own attempt.

**The dock door's `_wake_blocking_cargo` half is STILL OPEN.** `goods_session.gd`'s own run never
puts a settled crate in the door's path, so the "an `AnimatableBody3D` otherwise drives straight
through a frozen static body" case still has only the mechanical `engine_assumptions.gd` check
(the two bodies' interaction measured in isolation), not a live scenario proving the door actually
wakes and displaces real settled cargo. Needs its own scenario step: settle a crate in `DockDoor`'s
`PathSensor`, let the door start closing, assert it ends up displaced rather than clipped through.

Also still open, named but not built by 02-07: a peer joining **mid-phase** against an already-running
clock/door (both peers in `goods_session.gd` join before `begin_run()` is ever called) — the
late-joiner manifest catch-up itself IS proven (a targeted RPC, the same shape a rack snapshot
uses), but the clock/door's own continuously-broadcast-replication late-join claim is still reasoned
through rather than scenario-proven.

Full detail: `.planning/STATE.md`'s 02-07 block, `02-07-SUMMARY.md`.

### 2.2 A peer disconnecting mid-hold is never tested

`Net._on_peer_disconnected` → `CarryAuthority._on_player_left` force-releases what that peer held,
and `crate.gd` carries null-guard branches written specifically for a vanished holder. **None of it
ever runs.** The only mention of a disconnect anywhere in the integration tests is a code comment.

A disconnecting holder could leave a crate held by a ghost id, or a hold spring targeting a freed
node, with nothing catching it.

### 2.3 Hold-breaking is never triggered on purpose

Every reference to `break_distance` in the tests is about *avoiding* it — pacing, catch-up
distances, park points all tuned to stay "comfortably under 2.2 m". One comment even notes a break
*can* happen incidentally mid-transit and that it prints when it does — but nothing asserts the
cleanup.

So `_break_hold`'s bookkeeping — the signal, the referee's release, the client-side drop — is
unproven, for something a player does constantly by walking away from what they are carrying.

### 2.4 Goods OUT is only ever proven empty

Zone coverage asserts a crate is detected in Goods **IN**, and that Goods **OUT** stays empty. A
crate actually detected *inside* Goods OUT, and a crate *leaving* a zone (count returning to zero),
are never tested. That is the delivery half of the loop.

### 2.5 `PLACE_REACH`'s derivation is documented and unasserted

`GRAB_REACH` (2.0 m) is pinned. `PLACE_REACH` (3.0 m, derived as the ray plus half a cell diagonal)
appears in the api layer **only inside a comment** saying the two "move with this number".
`GRAB_REACH` has already moved once, 2.5 → 2.0. Nothing enforces that they move together.

---

## Tier 3 — structural, needs its own plan

### 3.1 Only ever exactly two peers

`EXPECTED_PLAYERS := 2` is hard-coded in both scenarios. Solo, three and four players never run —
against `SOLO-01`, ADR 6's 1–4 commitment, and ADR 25's crew-size-scaled delivery caps. A third peer
joining, a third grabber being refused on an already-two-held crate, and roster handling beyond two
have never actually executed.

This is the largest divergence between what the suite proves and what ships, and it cannot be tacked
onto an existing plan — the harness's two-peer shape is structural.

### 3.2 The 150-body ceiling has no automatic gate

Only `tools/run-stress.ps1` measures it, separately and manually. ADR 14 warns the failure is silent.
A day-content system that overshoots would not fail the suite or the pre-push hook.

### 3.3 The drag spring's floor-plane-only force is unchecked

Nothing asserts the drag force's Y component is zero. That constraint is what makes solo racking
physically impossible, which is the entire co-op incentive ADR 19 exists to protect. A refactor of
`_apply_drag_forces` could reintroduce lift with nothing catching it.

---

## Tier 4 — declared and accepted, not fixed

- **A Large cannot be racked**, and no test asserts today's refusal. Inert by design until 02-08 —
  but with no guard in either direction, nothing will notice if 02-08 half-lands.
- **ADR 25 (e)'s negative invariant** — condition must never move except by physics. Nothing to
  violate until Phase 3 builds damage, and no regression guard queued for when it does.
- **The Steam transport** — written, never executed, hardware-blocked. `docs/steam-validation-run.md`.
- **`morning_seconds >= 20.0`** is a floor with no ceiling, so an hour-long morning would pass.
  Deliberate — pinning today's default would fail the moment it is tuned — but weaker than its label.
- **Feel values** — hold stiffness, damping, drag, settle timing. Unassertable by nature; the gate
  is their test.

---

## Process changes already made

- **`guards` is now a required field** in the plan template: one entry per truth, naming the test
  that would fail if it broke, with `UNGUARDED — <reason>` as an explicit and acceptable answer.
- **Dimension 8: Coverage Guarantee** added to the plan checker, with a specific warning about
  thresholds calibrated while some variable happens to be uniform — the exact shape of 1.2 and 1.3.
- **The suite's verdict block now prints the engine's own error text**, not just a count, and names
  both log streams.
- **`TARGET_PEER_BROADCAST == 0` is pinned**, after `rpc_id(-1, …)` cost ninety minutes.

Both tooling changes live in the planning tool rather than this repo, so a tool update will drop
them. They are recorded in `.planning/STATE.md` so they can be reapplied.
