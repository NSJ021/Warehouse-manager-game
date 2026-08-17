# Storage cells bundle small cargo, and a cell is atomic

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ
- **Supersedes:** [storage-grid-module](2026-08-17-storage-grid-module.md) (ADR 16) **in full**. The 0.5 m module survives as the size of a Small item; everything ADR 16 said about slot counts is replaced.

## Context

ADR 16 fixed the grid module at 0.5 m and gave the size classes as 1, 2 and 4 slots. It fixed
**footprints only** — it never settled the third dimension, rack depth or shelf pitch. That
gap surfaced the moment anyone asked the obvious question: how much does a rack actually hold?

Answering it exposed something worse than a gap. ADR 16's sizes do not match what the GDD says
each class should *feel* like:

- A Medium is supposed to be **two-handed and to occlude your view** (§6.1). ADR 16's Medium is
  1.0 × 0.5 × 0.5 — a longish box you carry on one hip. It occludes nothing.
- A Large is supposed to be **a two-player carry or a drag**. ADR 16's Large is a metre square.
  One person manages that, awkwardly. And the *entire* co-op incentive rests on Large genuinely
  needing two people — ADR 16 flagged this as the risk to watch, and it was right to.

So the model was quietly undermining the thing the co-op design is built on.

## Decision

**The storage unit is a cell: 1.0 m cubed.** Cargo is sized against it:

| Class | Size | Cells | In smalls |
|---|---|---|---|
| **Small** | 0.5 m cube | 8 per cell (2 × 2 × 2) | 1 |
| **Medium** | 1.0 m cube | 1 cell | 8 |
| **Large** | 2.0 × 1.0 × 1.0 | 2 cells | 16 |

A Medium held in front of you is a metre cube — it occludes your view because it genuinely
does. A Large is two metres long, so it takes someone at each end. The sizes now deliver what
the design already promised.

**A cell is atomic.** One kind of cargo at a time. Eight Smalls fill a cell efficiently; one
Medium fills the same cell and wastes nothing but *earns* the same space. That sting is the
point — it is the packing decision, and without atomicity there isn't one.

**Retrieval within a cell is last-in-first-out.** You take what is accessible. This is not a
limitation, it is the feature: badly-ordered stock becomes *physically painful* to retrieve,
which turns §6.3's FIFO discipline from a good habit into something the building enforces.
Get it wrong and you are unstacking six crates to reach the one a client is waiting for.

**A rack is 2 cells wide × 2 deep × 3 high = 12 cells**, holding 96 Smalls, or 12 Mediums, or
6 Larges. The top level sits at 2–3 m, so a solo player — floor level only, per §6.1 — can use
the bottom row and nothing else. The co-op incentive is in the geometry rather than in a rule.

**Rack placement decides whether stock gets buried.** A 2-deep rack against a wall has a buried
back row; the same rack as an island, reachable from both sides, has two front rows and no
buried stock at all. Island racks store better and eat aisle space; wall racks are compact and
bury half their contents. That trade falls out of the geometry for free.

**Storage fees must price by volume, not per item.** This is forced, not a preference: with
per-item fees, eight Smalls in a cell earn eight times what a Medium earns in the same space,
Smalls become strictly dominant, and the packing decision collapses into "always take Smalls".

**Large cargo gets no price premium.** For the same commodity, large and small pay the same per
unit volume — a tonne of bricks is a tonne of bricks. The reward for handling Large is **fewer
journeys**, which scales with how many players you have and disappears when you are alone.
Adding a premium on top would let Large win on both axes at once and make Small cargo something
you take only when nothing better is offered.

## Consequences

**Easier:** Large finally reads as a two-person job, which repairs the risk ADR 16 named.
Packing becomes a real decision. Buried stock creates drama and gives the memory game teeth.
Rack placement becomes strategic at no implementation cost.

**Harder — and this is the honest cost:** the memory game gets *coarser*. Twelve cells is a
smaller address space than twenty-four individually-labelled slots, so recalling where something
is becomes easier, not harder. The mitigation is that a cell must be **searched** rather than
read — you walk over and look — which trades precise recall for physical rummaging. That is
probably better drama, but it is a trade against P2 and it was made knowingly.

**Watch for:** two-deep racks *and* in-cell burial is two layers of awkwardness stacked. If
retrieval becomes tedious rather than tense, relieve it by placing more racks as islands before
touching either rule.

**Rules out:** per-item storage fees, and any size premium for Large.

**Supersedes ADR 16 in full.** The 0.5 m module survives as the size of a Small; the 1/2/4 slot
counts do not.

**Follow-up:** plans 01-02 (slot arithmetic) and 01-03 (rack fixture) were written against the
old model and need rework before Phase 1 executes. No budget re-measurement is needed — racked
items are static meshes with no body, so capacity does not touch ADR 14's ceiling.

## Alternatives considered

**Keep ADR 16 — one item per slot, 1/2/4.** Simpler, already planned, already asserted in the
api layer. Rejected because it left Large too small to need two people, which quietly weakens
the co-op incentive the whole game leans on, and because a slot holding exactly one thing makes
placement a pure location choice with no packing trade at all.

**Keep 1/2/4 but allow vertical stacking within a slot column.** A middle path that preserves
the GDD's numbers while adding some packing feel. Rejected because "2 slots" would then mean
different things horizontally and vertically, which is the sort of ambiguity that produces
bugs in the slot arithmetic and confusion in the player.
