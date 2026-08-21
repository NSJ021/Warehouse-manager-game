# Physics budget

**How many rigid bodies survive across four networked peers?** Measured 2026-08-17. The decision this drives is [ADR 14](../decisions/2026-08-17-physics-budget.md); this document is the evidence.

Reproduce with `./tools/run-stress.ps1`.

## The answer

**Design for about 150 concurrent loose rigid bodies.** 200 runs but has spent a third of a 60 Hz frame on a client before anything is drawn. Past roughly 250, replication quietly stops keeping up.

The binding constraint is **not** what everyone expects. It is not the physics solver, and after one fix it is not bandwidth either — it is **per-frame cost on the clients**, which scales with how many bodies exist rather than with how many are moving.

## Pass 1 — solo, pure simulation cost

One peer, no replication. This isolates what Jolt actually costs.

| mode | crates | host physics ms |
|---|---|---|
| settled | 100 | 1.52 |
| settled | 400 | 2.39 |
| settled | 800 | 2.97 |
| awake | 100 | 1.98 |
| awake | 400 | 3.35 |
| awake | 800 | 4.80 |

**Physics is not the problem.** 800 bodies with nothing allowed to sleep costs 4.8 ms — under a third of a 60 Hz tick, on a 7900X. Sleeping saves roughly 40% at the same count, which is worth having but is not what decides the budget.

`awake` is the mode that matters, because a **held** crate never sleeps by definition, and neither does a rack mid-collapse.

## Pass 2 — four peers, the shipping maximum

| mode | crates | host physics ms | host sent kb/s | worst client frame ms |
|---|---|---|---|---|
| settled | 6 | 0.52 | 93 | 1.60 |
| settled | 50 | 0.58 | 93 | 3.77 |
| settled | 100 | 0.73 | 93 | 5.99 |
| settled | 200 | 1.20 | 80 | 8.98 |
| settled | 400 | 1.48 | 59 | 6.10 |
| awake | 100 | 1.27 | 115 | 5.91 |
| awake | 200 | 1.60 | 126 | 8.66 |
| awake | 400 | 2.56 | 270 | 4.96 |

Client frame cost is close to linear in crate count — about **40 µs per crate per frame** — and is almost identical in `settled` and `awake`. That is the important shape: **it costs what it costs to have the bodies exist**, not to have them moving. Sleeping does not save a client anything.

## The bandwidth fix, which was the near miss

Before any tuning, the host at 100 crates was sending **1497 kb/s** — about 12 Mbit/s upstream, more than plenty of domestic connections have, for a warehouse doing nothing at all. The crates were replicating every property every network frame whether or not anything had changed.

Two changes, and the numbers are the before and after:

| | settled, 100 crates | awake, 100 crates |
|---|---|---|
| Before | 1497 kb/s | 1333 kb/s |
| After | **93 kb/s** | **115 kb/s** |

- `replication_mode` on position and rotation moved from **always** to **on change**.
- `replication_interval` set to **0.05** (20 Hz), which the existing puppet smoothing already covers for — the crate eases between updates instead of stepping.

That is a **16× reduction**, and it turns the host's upstream from a shipping blocker into a rounding error. Voice chat in v1 (ADR 9) will want that headroom.

## Two things the sweep revealed that are not in the table

**Replication degrades silently rather than saturating.** In `settled` mode, host traffic *falls* between 100 and 400 crates (93 → 80 → 59 kb/s) while crate count quadruples. Godot is deferring updates it cannot fit, so the failure mode past the budget is **crates visibly lagging or sitting wrong on clients**, not a crash or a stall. Nothing will announce that the budget has been exceeded — which is exactly why the number needed measuring rather than assuming.

**The 400-crate client figures are not headroom.** Client frame cost appears to *improve* at 400 (6.1 ms versus 9.0 at 200). It has not improved; the client is simply receiving fewer updates because of the degradation above. Read those rows as "already past the limit", not as good news.

## Caveats, stated rather than buried

- **Headless means no rendering.** These are physics and network numbers only. A real client also has to draw those crates, so its true budget is *smaller* than these figures suggest, never larger.
- **All peers shared one machine** — a 24-thread 7900X, so contention is mild, but it is not four separate PCs on real internet. Latency and jitter are absent.
- **`PHYSICS_3D_ACTIVE_OBJECTS` and `PHYSICS_3D_COLLISION_PAIRS` read zero under Jolt.** Verified rather than assumed: they stayed at zero when sampled during the warm-up while 100 crates were visibly falling. The monitors are not populated by this backend, so ignore them — a confident zero is worse than a blank.
- **`TIME_PROCESS` is whole-frame time, not script time.** Disabling puppet smoothing entirely still left 5.5 ms per frame at 200 crates, so most of that cost is engine-side per-node and per-synchronizer overhead rather than our own code. Optimising the smoothing further would be aiming at the wrong target.

## What this constrains

The number feeds directly into design decisions that would otherwise be made blind:

- **Floor clutter** — how much cargo can be dumped on the floor before the game degrades.
- **Rack shedding** — how much a rack may throw when hit. A top row of 20 crates shedding at once is affordable; a whole rack of 60 is a spike.
- **Items per day** — the day loop should not leave more than roughly 150 loose bodies live at once.

**It also promotes [ADR 4](../decisions/2026-08-16-grid-storage-physics-transport.md) from a feel decision to a performance-critical one.** Grid-snapped storage means racked items can be static, non-simulated, non-replicated scenery. Physics is reserved for cargo in transit, which is a handful of items at a time. Had storage been full physics, a warehouse holding 300 items would have been 300 rigid bodies simply existing — twice the budget before a single one was picked up.

## Re-measured 2026-08-21, after ADR 17 (settled cargo turns static) — 01-09

ADR 17's own follow-up said the budget should *improve*, because a body that has genuinely turned static is cheaper than one that is merely asleep, and this ADR exists specifically to eliminate "should" as a word applied to this number. Re-ran `./tools/run-stress.ps1` unchanged, same machine, same counts.

**It improved. The ~150 ceiling does not move, but what it now applies to is narrower than before.**

### Before / after, solo pass (host physics ms — pure simulation cost)

| mode | crates | before | after |
|---|---|---|---|
| settled | 100 | 1.52 | **1.48** |
| settled | 400 | 2.39 | **2.41** |
| settled | 800 | 2.97 | **3.27** |
| awake | 100 | 1.98 | **1.49** |
| awake | 400 | 3.35 | **2.41** |
| awake | 800 | 4.80 | **3.12** |

`settled` is flat, within noise — expected, since those bodies were already asleep and cheap. `awake` dropped by 24–35%, and now tracks `settled` almost exactly at every count. That convergence is the headline, and it is explained below rather than left as a coincidence.

### Before / after, four peers (host sent kb/s, worst client frame ms)

| mode | crates | sent before | sent after | client ms before | client ms after |
|---|---|---|---|---|---|
| settled | 100 | 93 | **93** | 5.99 | **4.75** |
| settled | 400 | 59 | **82** | 6.10 | **5.14** |
| awake | 100 | 115 | **93** | 5.91 | **4.59** |
| awake | 200 | 126 | **93** | 8.66 | **7.43** |
| awake | 400 | 270 | **35** | 4.96 | **5.40** |

The `awake`/400 sent figure — 270 kb/s down to 35 — is the largest single move in this whole document. Same story as the client-ms convergence above: most of what this sweep calls "awake" no longer stays awake.

### Why `awake` moved this much: it measures a different thing now

The stress harness's `awake` mode does exactly one thing to keep bodies lively: it sets `can_sleep = false` once, at the start, and leaves it there. Before this plan, that was sufficient — a body that cannot sleep keeps costing full price indefinitely, which is what made `awake` the honest worst case the harness's own doc comment says it is.

[`Crate._update_settle_state`](../warehouse-manager/scripts/goods/crate.gd) does not consult `can_sleep` or `sleeping` at all. It watches `linear_velocity`/`angular_velocity` against [`settle_speed`](../warehouse-manager/scripts/goods/crate.gd) directly, and freezes anything that holds still for [`settle_frames`](../warehouse-manager/scripts/goods/crate.gd) regardless of what the sleep flags say. A crate dropped in a pile and told "never sleep" still stops moving — `can_sleep` only stops the *engine* from marking it asleep, it does not stop the crate from coming to rest — and once it is genuinely still, ADR 17 freezes it to static within half a second, `can_sleep` or no. That is why the two modes now measure within noise of each other: by the time this harness samples, most of both piles have already frozen.

**This is correct, not a harness bug**, and not something to "fix" by making the stress test fight the settle machine — a held crate never reads as at rest in the first place, because [`add_holder`](../warehouse-manager/scripts/goods/crate.gd) is what the real "never sleeps" case actually looks like, and holding resets the settle counter every frame for as long as the hold lasts (see [`_update_settle_state`](../warehouse-manager/scripts/goods/crate.gd)'s own first check). What this sweep's `awake` mode was always missing, before and after this plan, is that distinction: it forces a flag rather than a hold, and now that the flag alone is not enough to stay expensive, the gap is visible in the numbers instead of hidden by it.

### Does the ~150 ceiling move?

**No, but read it more narrowly than before.** ~150 concurrent bodies is still the number for genuinely active cargo — a rack mid-collapse, several players carrying and shoving at once, anything actually moving on a given frame. Nothing about ADR 17 changes the per-frame cost of a body that is *not* at rest; the 40 µs/crate figure for a truly moving body is untouched, because a moving body never reaches the settle threshold.

What changes is that **floor clutter sitting still no longer counts against that ceiling the way it used to.** Before this plan, 100 crates dumped on the floor and left alone still cost close to the `awake` figures once Jolt's own sleep timer lapsed if anything nearby kept nudging them awake, and always cost the full `settled`-but-still-simulated price for however long they took to actually go to sleep. After this plan, the same pile is frozen, off the solver, and off the wire within half a second of the last thing touching it — closer to zero than to 40 µs/crate. The distinction the budget now has to track is not "how many crates total" but **"how many are moving right now"**, which is exactly the distinction ADR 17 was built to introduce at the gameplay layer too (a settled pile blocks pathing for free; a moving one costs a frame).

Practically: the day-loop guidance stands (≈150 loose bodies actually in play at once), but a warehouse that has accumulated *far* more than 150 items of settled floor stock over a long lease is no longer the same kind of risk it would have been pre-ADR-17, provided most of that stock is genuinely sitting still rather than being circulated. That is a real loosening of a real constraint, not just a rounding change — but it is conditional on stock actually settling, so a day designed around constant churn (everything always mid-carry) still wants the original ~150 figure taken literally.
