# Rack geometry is ratified: pallets, buried rows, and two speeds of shelf

- **Date:** 2026-08-21
- **Status:** Accepted
- **Deciders:** NJ
- **Builds on:** [storage-cells](2026-08-17-storage-cells.md) (ADR 18, which this ADR does not touch) and reuses the resizing argument from [storage-grid-module](2026-08-17-storage-grid-module.md) (ADR 16, superseded by 18). Cross-references [grid-storage-physics-transport](2026-08-16-grid-storage-physics-transport.md) (ADR 4).
- **Supersedes:** Nothing.

## Context

ADR 18 fixed the rack's cell math — 2 wide × 2 deep × 3 high, twelve 1.0 m cells, level centres
at 0.5 / 1.5 / 2.5 m against a 1.6 m eyeline and a grab ray that was 2.5 m at the time (since
shortened to 2.0 m, a separate reach ruling recorded in `.planning/STATE.md`). It never fixed the
physical frame those cells hang inside — upright thickness, deck depth, whether a 2-deep rack
reads as one unit or two — and plan 01-03 built reasoned defaults (CSG decks 0.05 m thick, 0.1 m
square corner uprights) rather than ratified ones. Plan 01-08 existed to close that gap with a
play session.

Two things came out of playing it that the plan itself did not anticipate in this shape.

**The packed-cell look was wrong, not merely unratified.** A full cell of eight Smalls read as
items floating in a grid, and every item in a cell sat in an identical pose — mathematically
correct, visually stamped. NJ's own diagnosis, watching it live: warehouses don't hold stock like
that, they hold it on pallets, and the pallet is what was missing.

**The wall rack's unaimable back row, flagged by 01-04 and carried forward as an open flag in
every plan since, needed a ruling.** `rack_wall`'s depth-0 row is permanently unaimable head-on —
the front row's own `CellSensor` volumes block the ray, and the wall blocks the only other
approach. 01-06 mirrored that as-built rather than working around it, as instructed, but the
open question — island-only racks, a redesigned aim scheme, or accepting the loss — was
explicitly deferred to this gate.

## Decision

**The frame stays exactly as built.** 0.05 m CSG decks, 0.1 m square corner uprights, decks at
y = 0 / 1 / 2 giving level centres of 0.5 / 1.5 / 2.5 m. No number changes. An open-beam frame
and thinner decks were both considered and rejected — the frame was never the problem.

**Racked cargo gets a pallet.** An empty cell shows nothing. The first item placed into it spawns
a wooden pallet, and every item after that — including the one that triggered it — sits *on* the
pallet rather than floating at the cell's mathematical floor, with no clipping into the deck
below.

**Racked items get a small seeded jitter.** A little rotation and offset within the cell's own
footprint, seeded from the crate's id plus its cell and slot index — never from an unseeded
random source, because independent randomness on each peer would desync the look between machines
running the same replicated state. Side margins between an item and its cell walls are sized to
absorb this jitter, not only to look tidy.

**Top clearance is fixed at a quarter of a Small (0.125 m) below the deck above**, and racked
visuals are inset to fit inside that whole envelope — pallet, jitter room, and headroom — at
roughly a 0.78 vertical scale of a cell's own 1.0 m. That figure is a starting point, not a final
one: art finalises the exact numbers during the Phase 6 presentation pass. Nothing here blocks
that from happening later; this ADR fixes the *rule*, not the asset.

**The pallet's front edge is the anchor for a signage feature this ADR does not build.**
Per-cell plaques — "SUGAR 3/8", a Medium's or Large's own count — are a Phase 2 recommendation,
tracked in `.planning/REQUIREMENTS.md` and `docs/GDD.md` §6.3, not built here.

**The wall rack's back row is accepted as a level-design property, corrected by one finding from
play.** The front sensors blocking a straight-on ray is not a bug to route around — it is what a
rack backed against a wall *is*. But it is not a flat loss of half the rack's capacity: NJ racked
cells 8 and 0 in play by approaching from the rack's own end faces, where the level exposes one.
A wall rack is **6 cells reachable head-on, plus whatever its ends expose** — which depends on
level layout, exactly as ADR 18 already says placement decides what gets buried. Island-only
racks and a redesigned aim scheme were both considered and rejected: the first throws away a
compact, legitimate rack shape over a problem that turns out to have a real in-fiction answer,
and the second would touch `Carrier._aim()`, which every rack interaction in the game depends on,
to fix something that is not actually broken.

**The 2-deep legibility gap is a follow-up, not an aim change.** NJ mistook a back cell for a
front slot once in play. That is a *readability* problem — answered by the plaque (above) and the
ghost-preview aim-feedback rework already queued for Phase 6 (`.planning/STATE.md` open items) —
not a reason to change what a raycast can hit.

**Named consequence, worth stating because nobody had:** the top row and the bottom row are not
equivalent, and that is intended. The top row costs a longer hold to reach and turns a throw into
something you have to actually mean; the bottom row is a fast in-and-out. That is a real
optimisation axis — store your fast movers low and your slow movers high — and it falls out of
the geometry ADR 18 already fixed, at no extra cost.

## Consequences

**Easier:** the rack frame is now settled the same way the cell math already was, which unblocks
hand-modelling rack art on the same terms ADR 18's own argument makes — a module that keeps
changing after art exists means re-modelling every rack. The wall-rack question stops being an
open flag repeated at the top of every plan's context block.

**Harder — the honest cost:** the pallet spec adds a presentation state machine to every cell
(empty → pallet-spawned → populated) that plan 01-03's data model (`{kind, ids}`) does not
currently carry, and the seeded jitter needs a stable, peer-agreed seed derived from data the
cell already has. Neither is built by this ADR; both are Phase 6 work, and Phase 6 planning needs
to read this document before touching cell visuals.

**Watch for:** the 0.78 vertical scale figure is a napkin number from a design conversation, not
a measurement — treat it as disposable, and let art's own pass override it freely, provided the
*rules* above (pallet-first, seeded jitter, quarter-Small headroom) survive.

**Rules out:** resizing the rack's bay once rack art exists, for the reason ADR 16 gave about the
module — the cost of redoing hand-modelled, dimensionally-exact art is what "ratified" is
supposed to prevent. Also rules out: an open-beam frame, thinner decks, island-only racks as the
fix for buried rows, and re-deriving `Carrier._aim()`'s cell-resolution scheme to reach a buried
row some other way.

## Alternatives considered

**An open-beam frame.** Considered for its warehouse-shelving read. Rejected — the CSG decks
already read correctly in play once cargo sat on a pallet rather than floating; the frame was
never what looked wrong.

**Thinner decks.** Considered to open up sightlines between levels. Rejected for the same
reason — the fix the play session actually called for was at the cell-contents layer, not the
frame.

**Island-only racks**, eliminating wall racks and their buried row entirely. Rejected: it throws
away a real, compact rack shape to solve a problem that turned out to have an in-fiction answer
(approach from the end), and ADR 18 already prices the wall-versus-island trade-off deliberately.

**A redesigned aim scheme for buried cells** — multiple raycasts, a "reach through" gesture, or
resolving occupancy without a clean ray hit. Rejected: `Carrier._aim()`'s existing scheme is
load-bearing for every rack in the game (`CELL_RESOLVE_NUDGE` already patches one real bug in it),
and the buried row is not actually broken — it has a working, discoverable answer that play
surfaced on its own.
