# Physics body budget of 150, and cargo replicates at 20 Hz on change

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ

## Context

Phase 0 listed a physics budget stress test as a gate, on the grounds that the number silently constrains floor clutter, rack shedding and how many items a day can involve. Those three decisions were about to be made without it.

It has now been measured across four networked peers, in two modes — sleeping allowed, and nothing allowed to sleep, the latter because a **held** crate never sleeps by definition and nor does a rack mid-collapse. The evidence is in [docs/physics-budget.md](../docs/physics-budget.md).

Three things came out of it, and two were surprises.

**The physics solver is not the constraint.** 800 bodies with sleeping disabled cost 4.8 ms of a 16.67 ms tick. It was never going to be the thing that broke.

**Bandwidth nearly was.** At 100 crates the host was pushing **1497 kb/s** — roughly 12 Mbit/s upstream, for a warehouse in which nothing was happening. Cargo was replicating every property every network frame regardless of whether it had changed. On a P2P host with a domestic connection that is a shipping blocker, and it would have been discovered late, by a player, as "the game is unplayable at my mate's house".

**The real ceiling is client per-frame cost**, at roughly 40 µs per crate per frame — and it is the same whether the crates are moving or fast asleep. It costs what it costs for the bodies to *exist*. Sleeping saves the host; it saves a client nothing.

## Decision

**Design for a ceiling of 150 concurrent loose rigid bodies.** 200 is the point at which a client has spent a third of a 60 Hz frame before drawing anything. Beyond roughly 250, replication stops keeping up.

**Cargo replicates on change, at 20 Hz** — `replication_mode` on position and rotation moved from *always* to *on change*, and `replication_interval` set to 0.05. The existing puppet smoothing already covers the gap between updates, so the crate eases rather than steps. Measured effect: **1497 → 93 kb/s** at 100 crates, a 16× reduction.

**Treat the budget as a design input, not a performance target to chase.** The day loop, floor clutter and rack-shedding volumes are all sized against 150.

## Consequences

**Easier:** floor clutter, rack shedding and items-per-day can now be designed against a real number instead of a guess. The host's upstream stops being a shipping risk, which also leaves room for proximity voice (ADR 9) rather than competing with it.

**Harder:** the budget has to be respected by systems not yet built, and nothing enforces it automatically. A day that leaves 400 crates on the floor will not fail loudly — see below.

**The failure mode is silent, and that is the dangerous part.** Past the budget, Godot defers replication updates it cannot fit rather than saturating the link: host traffic actually *falls* as crate count rises, while crates visibly lag or sit wrong on clients. Nothing will announce that the budget has been exceeded. Any future stress work should watch for traffic going *down* as a symptom.

**It promotes [ADR 4](2026-08-16-grid-storage-physics-transport.md) from a feel decision to a performance-critical one.** Grid-snapped storage lets racked items be static, non-simulated and non-replicated, reserving physics for cargo in transit. Had storage been full physics, a warehouse holding 300 items would have been 300 rigid bodies merely existing — twice the budget before anyone picked anything up. That ADR must not be revisited without re-reading this one.

**Rules out:** full-physics storage, mass-collapse spectacles involving hundreds of bodies at once, and any "warehouse full of loose stock" fantasy. A rack shedding its top row is affordable; a rack shedding sixty crates is not.

**Follow-up:** the numbers are from headless runs on one machine, so they exclude rendering and real network latency, and are therefore optimistic. Re-measure on the two-machine Steam validation run, which is the first time real latency enters the picture. Also worth knowing: `PHYSICS_3D_ACTIVE_OBJECTS` and `PHYSICS_3D_COLLISION_PAIRS` are not populated by Jolt, so any future profiling must not trust them.

## Alternatives considered

**Leave replication on *always* and accept the bandwidth.** Simplest, and invisible during solo development. Rejected on the numbers: 12 Mbit/s upstream for an idle warehouse would have failed on ordinary domestic connections, and P2P hosting means a player's home connection *is* the server.

**Cut the body budget hard and keep 60 Hz replication** — fewer crates, updated more often. Rejected because the budget is what the design spends, and cargo lying about is the game's texture. Spending it on update rate the smoothing already hides would be a poor trade.

**Chase the client per-frame cost instead of budgeting around it.** Attempted, and the measurement said no: disabling puppet smoothing outright still left 5.5 ms per frame at 200 crates, because most of the cost is engine-side per-node overhead rather than our code. Optimising further would have been aiming at the wrong target — worth recording so nobody spends a day on it.
