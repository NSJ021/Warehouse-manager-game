# Grid-snapped storage, physics transport

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

The concept holds two mechanics in tension. Warehouse **organisation** rewards care, planning and memory. Physics **slapstick** rewards chaos. Left unresolved, the fun mechanic destroys the satisfying one — players who lose a carefully built layout to a random bump resent the physics rather than laughing at it. The original pitch also floated arbitrarily shaped goods, which compounds the problem.

## Decision

Split the two by **context**:

- **Storage is grid-snapped.** Racks expose slots; goods snap in on insert. Size classes are fixed footprints (1, 2 or 4 slots). No free-form packing of arbitrary shapes into shelves.
- **Transport is fully physical.** Carrying, two-player carry, dragging, dropping and collisions are all rigid-body simulation. This is where every comedic moment lives.
- **Racks wobble but are not fragile.** A hard enough impact makes a rack shed its top row. Chaos is possible but it is a *punishment for recklessness*, not ambient noise.
- **Floor stacking is permitted** — faster, blocks pathing, counts as clutter, easy to kick over. A tempting shortcut with a real cost.

## Consequences

**Easier:** both fantasies coexist. Storage stays legible and plannable, which is what the memory game needs. Sidesteps the genuine nightmare of simulating arbitrary-shaped rigid bodies settling into shelving — a well-known sink of physics-programmer months.

**Harder:** the snap-on-insert transition must feel good, not abrupt. Needs a deliberate animation and audio pass or it reads as cheap.

**Rules out:** free-form Tetris-style spatial packing as a skill expression. Accepted — the depth moves to *zoning and recall* instead of *cramming*.

## Alternatives considered

**Full physics storage** — maximum emergent chaos, but jitter, drift and settling bugs would make precise organisation impossible and would undermine P2 entirely.

**Full abstraction (menu/inventory storage)** — trivially stable, but deletes the physical comedy that is the whole point of the game.
