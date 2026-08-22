# Run variety: procedural layout, lease tiers, modifiers, and how a run can end

- **Date:** 2026-08-22
- **Status:** Accepted
- **Deciders:** NJ
- **Builds on:** [lean-v1-scope](2026-08-16-lean-v1-scope.md) (ADR 6), [lease-run-structure](2026-08-16-lease-run-structure.md) (ADR 8), [physics-budget](2026-08-17-physics-budget.md) (ADR 14), [storage-cells](2026-08-17-storage-cells.md) (ADR 18), [detection-and-patch-maths](2026-08-19-detection-and-patch-maths.md) (ADR 20), [two-currencies-and-the-crew-split](2026-08-19-two-currencies-and-the-crew-split.md) (ADR 21), [orders-are-manifests-reputation-is-a-market](2026-08-19-orders-are-manifests-reputation-is-a-market.md) (ADR 22), [rack-presentation-ratified](2026-08-21-rack-presentation-ratified.md) (ADR 24), [goods-taxonomy-dates-and-the-day-clock](2026-08-22-goods-taxonomy-dates-and-the-day-clock.md) (ADR 25).
- **Amends:** ADR 6's parked "additional maps" clause — see (a). ADR 6's parked "upgrade trees" clause is **not** amended and stands.
- **Supersedes:** Nothing.

## Context

A retention question was put directly: **does this game have enough variety, and will it?**

The honest audit that prompted this ADR found the gap precisely. The game has variety in **what you
carry** (ADR 25's ten categories) and in **what you decide** (ADR 20's dilemma, whose sweep proves
all three forks win somewhere across 192 situations and none wins more than 75%). It has almost no
variety in **what you do**. Every run is the same verbs — pick up, carry, rack, retrieve, hand over —
in the same building, on days with an identical shape.

The comparison with the genre is uncomfortable and worth stating rather than avoiding. Lethal
Company and R.E.P.O. get variety from procedural generation plus threat. Overcooked and Moving Out
get it from many hand-designed levels. This game had neither, while using a **run-based structure**
that advertises replayability the content did not supply.

Three further facts framed the decision:

- **Only one way to lose exists** — eviction by unpaid rent (ADR 8). One failure mode means every
  run tenses identically.
- **Nothing escalates.** ADR 21 defines where meta-progression comes from but not what it *does*, so
  there is no difficulty curve at all.
- **Every day is structurally identical** — dump, shift, close — because ADR 25 (f) gave the day a
  rhythm and nothing gives a run an arc.

A parallel finding from marketing research (`docs/marketing-research.md`) pointed the same way from
outside: a store page is gated on **three visually distinct environments**, which one warehouse
cannot supply.

## Decision

### (a) Warehouse layout is procedurally generated, and it lands in v1

**Procedural generation is not what ADR 6 parked.** That list names *layout build mode* (the player
constructing a warehouse) and *additional maps* (hand-authoring more of them). Generation is a third
thing, and this clause rules it in. **Hand-authored additional maps stay parked**; if variety is
wanted, it comes from the generator.

It is also the *cheaper* answer on the constraint that actually binds. A modular kit — wall segments,
corners, pillars, floor tiles, door and roof pieces — is reused across every layout, where N bespoke
maps means N sets of bespoke art. Given that the art pass has not begun and is the schedule's long
pole, generation costs less art than the alternative it replaces.

**The design rule that makes it safe: constrain what the economy depends on, vary what it does not.**

| Held within a band (protects balance) | Free to vary (supplies the variety) |
|---|---|
| Total cell count | Building shape and proportions |
| Dock-to-rack distance | Rack count, placement, orientation |
| Goods IN / OUT adjacent to the dock door | Aisle topology, dead ends, sightlines |

Hard constraints every generated layout must satisfy:

1. **Every cell is reachable.** Wall racks get ADR 24's end-face access to the buried back row;
   island racks are approachable on both faces.
2. **Aisle width admits a 2.0 m Large carried by two people, turning.** This is the load-bearing
   constraint and the easiest to get wrong — a layout that a solo player can walk but a pair cannot
   navigate with a Large is a broken layout, not a hard one.
3. **No rack blocks the dock door, and never the side way through** — ADR 25 (f) rules that a player
   is never locked in or out.
4. **Clear floor remains for the morning dump to land in**, sized against ADR 25 (f)'s delivery caps.

**Validation is a sweep, not inspection.** Generate several hundred layouts and assert every one
satisfies every constraint above, in the same style as ADR 20's 192-situation dilemma sweep and the
cargo taxonomy's 489 checks. A generator that is "probably fine" is not acceptable; the sweep is what
fails on the day it stops being fine.

**The integration suite is unaffected, and this was initially misjudged.** The suite instances
`test_room.tscn` as a **fixture**. Tests keep a fixed room; play uses generated ones. The belief that
the suite blocked generation confused "cannot change the test room" with "cannot generate layouts" —
they are different things and only the first is true.

### (b) Escalation is lease tiers, and it is a ladder, not a tree

Completing a lease unlocks a harder one: **rent up, cargo value up, fragility up, deadlines tighter,
delivery caps closer to what a crew can actually clear.**

This is deliberately **pure numbers on systems already built** — no new mechanics, no new art, no new
verbs. It is the cheapest possible answer to "nothing escalates," and it supplies the difficulty
curve whose absence was the real gap.

It sits at ADR 21's **crew tier**, which already sanctions run-affecting unlocks (maps, gear tiers,
client tiers) earned by run profit and completion and applied by the host at lobby creation. An
earlier reading of ADR 21 as permitting *cosmetics only* was wrong: that clause governs what an
individual's cut of the pot buys, and exists to keep the host's unilateral split socially safe. The
two tiers are distinct and only the personal one is cosmetic.

**A ladder, explicitly not a tree.** ADR 6 parks *upgrade trees* and that stays parked. Lease tiers
are linear; there is no branching progression to build, balance or explain.

**A gear ladder was considered and is not taken** — see Alternatives. Anything that ever touches the
dilemma's constants must enter ADR 20's no-dominant-strategy sweep as a parameter, and that sweep has
already rejected one balance change on its first run.

### (c) Run modifiers, all reusing systems that exist

Modifiers stress the game's two engines — **capacity** and **the dilemma**. Monsters and threat, the
genre's usual answer, do neither and are not adopted.

| Modifier | Reuses | What it stresses |
|---|---|---|
| **Wet dock** — rain lowers friction so crates slide and drags overshoot | Jolt, unchanged | Physics comedy, free |
| **Truck timing variance** — due today, hour unknown | Day clock + manifest | Keeps Goods IN contested all day, not only at the dump |
| **Rush order** — needed today, off-schedule | Manifest | Capacity |
| **Inspection** — condition checked on demand | The dilemma | Makes a patched crate suddenly live |
| **Rack condemned** — a bay out of service mid-lease | Rack | Capacity, forces a re-pack |
| **Client goes bust** | Idea book strand 3 | Their stored goods become lien-sale material |

**Truck timing variance is the highest value per unit of cost on this list.** Both systems it needs
already exist, and it changes behaviour rather than decoration: not knowing the hour means Goods IN
must stay clear all day, which turns floor space into a live resource instead of an eight-o'clock
problem. ADR 25 (f)'s klaxon and roller door already telegraph the arrival, so the player gets
**warning without a schedule** — which is the difference between tension and unfairness.

**Blackouts and police raids are NOT adopted.** Both are named on ADR 6's parked list and were
considered and declined here rather than quietly absorbed. They remain parked and would need their
own superseding ADR.

### (d) Three routes to losing, one ending

The run still ends one way — **eviction**. What changes is that more than one road leads there. One
fail *state* with several fail *routes* reads more clearly than several unrelated endings, and keeps
the game legibly about the same pressure.

1. **Rent unpaid** — the existing route (ADR 8), unchanged.
2. **Capacity death, made legible.** ADR 25 (e) already creates this: overdue stock keeps occupying
   cells and starves a capacity-gated manifest. Pushed far enough, no work can be accepted, income
   stops and rent follows. **This is emergent from systems already built — the work is surfacing it
   as a visible spiral rather than a squeeze nobody notices until it is over.**
3. **Suspicion ceiling** — enough clients stop believing you that nobody offers work. It uses the
   per-client suspicion ADR 20 and ADR 21 already define, and **must stay within-run**: suspicion
   that crossed a lease boundary would put a permanent price on being caught, which is precisely what
   collapses ADR 20's late-lease flip.
4. **Voluntary walk-away** — break the lease early and accept a penalty. A deliberate choice to lose
   is more interesting than only ever being killed by arithmetic, and it gives a doomed run a
   dignified exit instead of a grind to an inevitable ending.

## Consequences

**Easier:** the run-based structure finally has a variety engine behind the replayability it
advertises. The store page's three-distinct-environments requirement is satisfied by generation
rather than by art budget. A difficulty curve exists where there was none. A losing run can end in
more than one way and can be ended on purpose.

**Harder — the honest cost:** (a) is a real system, not a setting. A generator, a constraint solver,
a validation sweep, and a modular art kit that tiles cleanly are all new work, and they land while the
art pass has not started and the schedule's long pole is art. The recommendation put to NJ was to
defer generation to a post-Early-Access headline for exactly that reason; **he ruled for v1, and the
schedule risk is accepted deliberately rather than overlooked.** It should be tracked as the largest
single schedule item in the project.

**Watch for:** aisle-width failures that only appear with two players and a Large, which no
single-player test will catch — the sweep must model the pair, not the person. Watch also for the
generator producing layouts that are *valid but boring*; passing every constraint is not the same as
being worth playing, and only play will tell the difference.

**Rules out:** hand-authored additional maps as the answer to variety; branching upgrade trees;
blackout and raid events; monsters or any threat actor; cross-run suspicion; and any gear that
changes a dilemma constant without passing ADR 20's sweep.

## Alternatives considered

**Deferring procedural generation to a post-EA headline.** The recommendation. ADR 23 already says
1.0 ships a headline feature rather than a label change, and generation is a strong one; it would also
have been informed by real play, since nobody has yet played a full lease and the definition of a good
layout is currently a guess. Rejected by NJ on the grounds that Early Access reviews would land on a
single layout during the period that matters most for word of mouth.

**No generation at all** — one map plus visual variants and combinatorial variety. The cheapest option
and defensible: the warehouse starts empty every lease, so the manifest re-poses the spatial problem
each run, making the layout the *board* rather than the game. Rejected because the board itself is
solved once and stays solved, and routes and bottlenecks are exactly what a returning player has
already learned.

**A gear ladder alongside lease tiers** — the truck-schedule perk, better tape, a condition scanner.
More tangible progression and a reason to care about profit beyond rent. Not taken, to keep escalation
to pure numbers on built systems; anything touching the dilemma's constants must go through ADR 20's
sweep, which is real balance work rather than a free addition. The door is not closed, but it needs
its own decision.

**A gear ladder instead of lease tiers.** Rejected outright: progression by acquisition with no
difficulty curve makes the game *easier* as it goes, which is the wrong direction for a game about
mounting pressure.

**Monsters or a threat actor**, the genre's usual variety engine. Rejected because it stresses neither
capacity nor the dilemma, and would make this a different game — the one the parked raid events would
also have made.
