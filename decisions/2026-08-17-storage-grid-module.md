# The storage grid module is 0.5 m

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ

## Context

[ADR 4](2026-08-16-grid-storage-physics-transport.md) settled that storage snaps to a grid,
but never said what the grid *is*. GDD §6.1 then fixed the size classes in terms of slots —
Small 1, Medium 2, Large 4 — which makes the slot the unit everything else derives from.

This has to be settled before Phase 1 and before any art, for two reasons.

**The art pipeline depends on it.** `docs/art-pipeline.md` puts the crate, racks, shelving
and dock doors in the hand-modelled column specifically because their dimensions are
load-bearing for grid snapping, and generative tools do not do precise measurement. Nothing
grid-critical can be modelled until the module exists.

**Phase 0 deliberately did not ratify it.** The greybox crate is 0.5 m, and the code
carries an explicit note that the module is a Phase 1 decision and that nothing about that
number is agreed. That note now gets resolved rather than inherited by accident.

## Decision

**One slot is 0.5 m × 0.5 m.**

| Class | Slots | Footprint |
|---|---|---|
| Small | 1 | 0.5 × 0.5 |
| Medium | 2 | 1.0 × 0.5 |
| Large | 4 | 1.0 × 1.0 |

The Phase 0 crate becomes the **Small** item unchanged. A rack bay four slots wide is
2.0 m; three shelves is roughly 2.4 m tall.

## Consequences

**Easier:** nothing already built has to move. The crate keeps its dimensions, its mass and
its collision shape, and the hold tuning — stiffness, damping, sag, reach — all stay valid,
which matters because those came from a play session rather than a formula.

**Harder, and this is the one to watch:** Large is only 1.0 m across, and the entire co-op
incentive rests on Large cargo *feeling* like a two-person job. If a metre-wide crate reads
as something one person should manage, the two-player carry stops being the efficient path
and becomes a curiosity.

The fix, if that happens, is **mass and awkwardness, not size** — the drag speed penalty,
the scuffing, the inability to rack above floor level. Size is now locked into modelled
geometry, so changing it later means re-modelling every grid-critical asset. Watch it in
Phase 2 when size classes land, and tune the handicaps rather than the dimensions.

**Rules out:** resizing the crate once art exists. That is the whole point of settling it
now rather than discovering it during an art pass.

**Follow-up:** the hand-modelled crate must be exactly 0.5 m — not approximately. Add the
module to the art pipeline doc as a hard constraint before the first grid-critical asset is
made.

## Alternatives considered

**A 0.6 m slot, with the current crate demoted to Small and a new 0.6 m Medium.** Chunkier
cargo, and Large at 1.2 m genuinely reads as a two-person item, which is the strongest
argument available and goes directly to the co-op incentive. Rejected on cost: it resizes
the one asset that already exists and invalidates hold tuning that was arrived at by feel
rather than calculation, for a benefit that can be recovered through handicaps instead.

**Defer and decide from play** — build racks with the module as one exported constant, try
both with a crate in hand, ratify the winner. Genuinely tempting, since this is a feel
decision and the tuning constants are already exported. Rejected because it leaves the art
pipeline blocked on an open question, and grid-critical geometry is exactly what cannot
start until the number is fixed.
