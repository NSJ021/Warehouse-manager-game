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
