# Early Access, not straight to 1.0 — two launch beats, one unchanged bar

- **Date:** 2026-08-20
- **Status:** Accepted
- **Deciders:** NJ
- **Constrains:** Phase 7's meaning, the store page timing in Phase 6, and the shape of every post-launch plan. Settles the "Early Access vs 1.0" question that has sat open since the scope lock.

## Context

The question was open, and it quietly decides what "shippable" means: Phase 7's gate reads
differently if the thing being shipped is a finished statement or the first public build of a
living game.

Three structural facts about this specific game bear on it:

**The shelf treats Early Access as the normal state of a living co-op game.** Lethal Company,
R.E.P.O., Schedule I and Supermarket Simulator all launched EA; the price band this game
deliberately joined (ADR 10) carries no EA stigma. The one relevant full-launch comparable in
the research set is Moving Out 2 — the warning, not the model. In this cluster a "1.0" label
buys no credibility, and EA costs none.

**The economy has said in writing that it needs live players.** ADR 20 calibrates its constants
against each other, not against a real economy, and warns that its uniform sweep may not match
what real sessions produce. The two lease terms are effectively two economies to tune. A closed
playtest can rough them in; only a live population produces the play-distribution data ADR 20
names as missing.

**Discovery is stochastic and the marketing budget is zero.** This genre's breakouts travelled
on streamer virality, which is a dice roll. An EA launch and a 1.0 launch are two independent
rolls; a straight 1.0 concentrates all discovery risk in one day, which is a luxury for games
with marketing spend behind them.

Against all that stands one real cost: EA reviews are permanent. The first week's score carries
into 1.0, so EA punishes a rough launch exactly as hard as a full launch does — while tempting
a developer to launch rougher because the label seems to excuse it.

## Decision

**Nice Little Earner launches into Steam Early Access.** Four clauses make that safe rather
than soft:

### The bar does not move

The EA gate is Phase 7's gate, unchanged: solo playable and honestly marketed as lesser, both
lease economies coherent, a stranger can complete a full run. Early Access widens what the game
honestly *contains* at launch — one map, two terms — and never what it excuses. A build that
would embarrass a 1.0 launch is not ready for an EA launch either, because the reviews are the
same reviews.

### Validation precedes launch

The Steam P2P two-machine validation (the open Phase 0 item) and a **Steam Playtest** — free,
opt-in, separate from EA — both happen before the EA date. "Can't play with my friends" is the
one launch-day failure this game cannot afford a single week of, and the playtest doubles as
the economy's first live data.

### The public roadmap sells axes, never features

The store page and EA statement promise *directions* — more maps, longer leases, more clients —
and a stated duration of 12–18 months. They never name parked features, because un-parking
anything still requires a superseding ADR (lean-scope ADR), and the store page must not
pre-commit decisions the ADR process has not made. Under-promise is the policy; the parked
list is the private menu, not the public promise.

### 1.0 is a headline, not a label change

The Early Access exit ships something a stranger can see — the second map or the 90-day term —
and takes its own discovery round. It is also the natural score-repair release. Pricing at that
exit stays ADR 10's domain; that ADR already names the EA exit as one of its revisit points,
and nothing here pre-empts it.

## Consequences

**Easier:** Phase 7 has a defined finish line with balance *breadth* explicitly moved to where
the data lives. The store page can go live around Phase 6, when clips exist, and accrue
wishlists ahead of the date — wishlists are the launch lever, and they accrue from page-live,
not from launch. The content roadmap already exists as the parked list read forwards; no
redesign is needed to feed an update cadence, because the Lease Run structure was accidentally
built for one.

**Harder:** the review-permanence risk now has a name and an owner — the unchanged bar is the
whole defence, and it will be tested by every temptation to ship a month early. Version
discipline starts costing effort from Phase 5-ish: version in `project.godot`, visible in-game,
git-tagged builds, so playtest reports name a build. And the game's internals are public longer
before the "finished" verdict — though the dilemma's constants were always one decompile away
in GDScript, and the odds are hidden to protect drama, not secrecy; a spreadsheet on a wiki
does not tell anyone whether to gamble on eviction night.

**Watch for:** roadmap drift by community pressure. EA populations ask for parked features by
name, loudly, and the pressure will arrive dressed as feedback. The ADR process is the shield:
a parked feature enters scope through a superseding ADR or not at all, exactly as before —
EA changes where the requests come from, not how they are decided.

**Rules out:** launching 1.0 first; using the EA label to lower any Phase 7 criterion; naming
parked features on the store page; an EA date before the Steam P2P validation has passed on
real hardware.

## Alternatives considered

**Straight to 1.0.** One concentrated beat, a "finished" first impression, no EA skepticism.
Rejected on all three structural facts: it forfeits the second discovery roll, demands the
economy be tuned without the live data ADR 20 says it needs, and asks one map and two terms to
carry a "complete game" claim at a price point where the EA norm makes that claim unnecessary.

**Early Access earlier, at a lower bar** — launch after Phase 5-ish and finish in public.
Maximum data, earliest revenue. Rejected outright: reviews are permanent, this genre's failures
are discovery failures, and a rough first week is the one mistake that cannot be patched. The
entire value of EA here depends on the bar not moving.

**Decide later, at Phase 6.** Tempting, since no store page exists yet. Rejected because the
decision is load-bearing now: Phase 7's gate text, the Phase 6 store-page timing, and the
versioning discipline all read differently under EA, and leaving it open invites re-litigating
it in every planning conversation between now and then.
