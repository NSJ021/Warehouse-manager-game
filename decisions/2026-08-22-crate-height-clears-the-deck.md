# Medium and Large are 0.9 m tall, so a crate fits the shelf it is stored in

- **Date:** 2026-08-22
- **Status:** Accepted
- **Deciders:** NJ
- **Amends:** [storage-cells](2026-08-17-storage-cells.md) (ADR 18) — the **height** of Medium and
  Large only. Every footprint, the cell size, capacities and the eight-Small lattice are untouched.
- **Builds on:** [rack-presentation-ratified](2026-08-21-rack-presentation-ratified.md) (ADR 24),
  [solo-drag-is-a-hold-mode](2026-08-19-solo-drag-is-a-hold-mode.md) (ADR 19).
- **Supersedes:** Nothing.

## Context

**A Medium did not fit the shelf it was stored in, and had not since the day Mediums existed.**

Two ratified decisions met, and neither was wrong on its own:

- **ADR 18** fixes a Medium at a 1.0 m cube and a cell at 1.0 m.
- **ADR 24** makes the rack's decks 0.05 m thick and places them **on the cell boundaries**.

So each deck eats 0.025 m from the cell above and 0.025 m from the cell below, and a cell's nominal
metre of height is really **0.95 m of clear air**. A 1.0 m Medium is 5 cm too tall for it.

Racked, this is invisible: a racked item is a bare mesh with no collision at all (ADR 14), inset to
78% by ADR 24's presentation rule, so a shelved crate looks entirely comfortable. The full-size body
only exists during a **retrieval** — and it mints at the cell centre, interpenetrating **both** decks
by 2.5 cm. Whether the solver squeezes it free or pins it decides whether that retrieval works, which
is why NJ's own report was *"sometimes they pull fine, others they snag."*

It explains the whole size pattern exactly. A **Small** is 0.5 m with 0.45 m to spare and behaves
perfectly. A **Medium** is marginal. A **Large** is the same height but twice as long, so any
rotation has twice the leverage to bind it — reported worst of the three.

**This had been found before and was worked around rather than reported.** 02-06 hit the identical
contact deadlock, diagnosed it correctly, and measured a body drifting **0.0024 m over 2000 frames** —
then moved its test to a non-floor-level cell. The suite went green and the defect stayed in the game
until a human played it. That is precisely what this project's own rule forbids: *report it rather
than working around it.*

## Decision

**Medium is 1.0 × 0.9 × 1.0 m. Large is 2.0 × 0.9 × 1.0 m. Only the height changes.**

Footprints stay exactly as ADR 18 fixed them, and that is the point of choosing this option:

- A **Medium still occupies one whole cell**, a **Large still spans two**, and a cell still holds
  **eight Smalls** in a 2×2×2 lattice that depends on 0.5 × 2 = 1.0 exactly.
- `StorageGrid`'s arithmetic — cell centres, capacities, partner cells, mint offsets — is untouched,
  and so are the 491 unit assertions resting on it.
- Nothing about packing, atomicity, LIFO or ADR 18's fees-price-volume reasoning changes, because
  none of it was ever a function of height.

0.9 m leaves 0.05 m of clearance in a 0.95 m opening. That is deliberately modest: enough to stop the
body being born inside the deck, not so much that a crate rattles in its cell or stops reading as
filling the shelf.

**The guard that never existed now does.** `engine_assumptions.gd` asserts that a crate of each size
physically fits the clear air of the cell it is stored in, reading the dimensions from the **built
scenes** rather than restating them, and naming the shortfall in metres when it fails. That assertion
is what caught this, and it is what stops a future resize of either the crates or the decks
reintroducing it silently.

## Consequences

**Easier:** a Medium or Large can actually leave a shelf. Retrieval stops being a coin flip decided
by contact resolution. The `_wait_for_crate_catch_up` stall that the integration suite had been
absorbing in silence loses one of its causes.

**Harder — the honest cost:** crates are no longer cubes. A Medium is now visibly a slightly squat
box rather than a perfect 1 m cube, and the art pipeline's hand-modelled grid-critical geometry must
match the new dimensions exactly. **Grid-critical geometry is hand-modelled precisely because
generators cannot hit exact measurements** — that rule now has one more measurement to hit.

**Watch for:** the racked visual's 78% vertical inset now applies to a 0.9 m crate rather than a 1.0 m
one, so shelved stock reads about 7 cm shorter than before. If that makes a shelf look empty or the
inset look excessive, the inset is the number to revisit — not the crate, which is now the right size
for the space it lives in.

**Rules out:** any crate taller than the clear air of the cell it is stored in. That is now an
assertion, not a convention.

## Alternatives considered

**Move the decks out of the cell envelope** — a 1.05 m vertical pitch, so every cell keeps a true
metre of clear air and every crate dimension survives untouched. Rejected on risk: `CELL_SIZE` serves
as both footprint and pitch throughout `StorageGrid`, and separating those two roles would put 491
unit assertions and every cell-centre calculation in play to fix a 5 cm problem. It also makes the
rack taller, which reaches into ADR 24's ratified frame and the 2.0 m interaction reach.

**Mint a retrieval below the deck** and let the crate clear the shelf before the hold spring engages.
Touches neither ADR and fixes the symptom. Rejected because it leaves the underlying geometry false —
a crate that does not fit its cell, permanently papered over by a special case in one code path — and
because it adds a size-specific branch to a retrieval path that is currently uniform across all three
sizes. It would also have hidden the defect again rather than resolving it, which is exactly how this
survived the first time.
