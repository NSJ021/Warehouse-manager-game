# Reputation expires with the run; the crew splits one pot

- **Date:** 2026-08-19
- **Status:** Accepted
- **Deciders:** NJ
- **Amends:** GDD §4's end-of-lease scoring line, which listed reputation as feeding unlock currency. It does not.
- **Depends on:** [detection-and-patch-maths](2026-08-19-detection-and-patch-maths.md) (ADR 20). This exists partly to protect it.

## Context

Two currencies had been described since session 1 and neither had been pinned down. GDD §6.6 said
"reputation gates contract quality and volume — that's the whole loop in v1". GDD §6.7 listed
money in and money out. GDD §4 said a lease ends "scored on profit, reputation, and condition
record → unlock currency → new maps, gear, client tiers".

**ADR 20, written the same day, put those on a collision course.** It priced reputation at £90 per
point per day of lease *remaining*, decaying to exactly zero on the final day — and that decay is
the entire mechanism that makes the pillar work. It is what makes "tape it up and gamble on the
last night" the correct play, and therefore what stops the patch-or-confess fork being a decision
tree with one right branch.

If reputation also converts into permanent unlocks, it never actually reaches zero value.
Comping stays defensible on the last night because it still buys something. The late-lease flip
disappears and ADR 20's central mechanism quietly dies — without failing any test, because
nothing had connected the two.

Three further things were undefined and had to be settled at the same time, because they turn out
to be the same decision: whether money is shared or per-player, what happens to it when a run
ends, and what a run's output actually buys.

## Decision

### Reputation is an in-run currency and it expires

**Reputation never crosses a run boundary.** It gates contract quality and volume *within* a
lease, and on the last day it is worth nothing, exactly as ADR 20 prices it.

Meta-progression comes from **profit and contract completion** instead. That keeps ADR 20 intact
and it is also the more honest model: reputation is not a score, it is **an interest rate**. It
never pays you directly — it changes the quality of what you are offered next. A five-star rating
handed to you on the final morning is worth precisely nothing, and the design should say so.

**GDD §4 is amended** to remove reputation from the scoring line.

### Three axes, not two

Worth stating plainly because two of them are easy to conflate:

| | What it is | Scope | Gates |
|---|---|---|---|
| **Money** | Hard, spendable, immediate | The run | Rent, tape, repairs, gear. Running out ends the run |
| **Reputation** | Soft, expiring | The run | Contract quality and volume |
| **Client trust / suspicion** | Per client, permanent within a run | Per client | Whether *that* client catches you patching (ADR 20) |

Suspicion is **not** global reputation. Global reputation decides what work you are offered;
suspicion decides whether a specific client believes you. `Dilemma` already assumes both.

### Money is one company pot

Rent is a shared fail state, so the money that pays it is shared. Per-player wallets would make
the run hostage to whoever happens to be holding cash when they disconnect or decide to be a
prick — a griefing surface bolted onto a system that is not the game.

### The contribution tally is evidence, not accounting

Alongside the pot, the game records what each player did. **The tally's job is to be legible and
arguable, not correct.** If attribution were fair and complete the split could be automatic — the
only reason a human decides is that the numbers *cannot* tell the whole story.

Three rules follow, and they matter more than the metrics:

1. **Columns, never a total.** No net figure, no ranking. One number per player turns the host
   into someone reading a leaderboard, and the judgement — the entire point — disappears.
2. **Not zero-sum.** The tally does not divide the pot; it sits beside it. Two players who carry
   a crate together **both get full credit**, not half each. Generous on earns is what keeps
   people helping each other.
3. **Shown at each day's CLOSE**, which the day loop already has. Visible enough that the final
   split reads as a judgement rather than a robbery, without being a live HUD that gets optimised
   against — a running counter on screen would have everyone crowding the Goods OUT door instead
   of doing the work.

**Earns**

| Metric | Attributed to |
|---|---|
| Handed over at Goods OUT | whoever handed it to the client |
| Racked into a cell | whoever placed it |
| Signed for at Goods IN | whoever accepted it |
| Confessed | whoever confessed |

The first two are deliberately in tension. The gate-stander gets full credit for work someone
else hauled, which manufactures the best grievance available — *"Vin stood at the door all day"* —
and the racking column is the counterweight that proves it.

**Costs**

| Metric | Attributed to |
|---|---|
| Caught patching | whoever made the call |
| Damaged | last holder at the moment of damage |
| Tape used | whoever patched |
| Rack knocked over | whoever hit it |

**Caught patching is the strongest rule in the system.** The dilemma is already unilateral — no
vote, no confirmation (GDD §6.5) — so its consequence must be too. It is Sid's line, not the
crew's.

**Damage is named but never netted off.** It sits in its own column next to the deliveries and the
host weighs them. Attaching a cash value and subtracting it would make players afraid to touch
the glassware, which fights P3 directly: clumsiness is the comedy, and a crew that will not
handle fragile cargo is playing a worse game.

**Crew costs, attributed to nobody:** rent, racks and gear, and **late deliveries**. That last one
is deliberate — a crate nobody could find is a planning failure, and pinning it would require
"who buried it three days ago", which is unprovable and would discredit the whole tally.

### The host splits the pot, unilaterally

At the end-of-run checkout, whatever is left after rent and crew costs is divided by the host,
who sets each cut with no vote and no confirmation.

This is the pillar at run scale. The game already says *whoever is holding the item decides,
alone* — a host who decides Teflon Vin is getting five percent is the same joke, one level up. It
is also the most clippable thirty seconds in the run, which matters for the acquisition channel
§11 depends on.

### Two tiers of unlock, and this is what makes the split safe

| Tier | Earned by | Applies to |
|---|---|---|
| **Crew progression** — maps, gear tiers, client tiers | Run profit and completion | The whole lobby, through the host |
| **Personal** — cosmetics, outfits, crew characters | Your individual cut | You alone |

**A player's cut buys cosmetics and crew flavour only.** That is what de-risks the unilateral
split: being handed five percent is socially brutal and mechanically harmless, because nobody's
next run is worse for it. The two decisions protect each other, and neither works alone.

Run-affecting unlocks stay at the crew tier and are applied by the host at lobby creation, so
everyone plays the same run. A drop-in player who has unlocked nothing is not a liability, which
is the Lethal Company and R.E.P.O. posture and the right one for a game people will join
mid-campaign.

## Consequences

**Easier:** ADR 20 survives, and is now protected by an assertion rather than by nobody having
connected the two systems. The economy has a defined shape for Phase 4. The end-of-run checkout
has a reason to exist beyond a results screen.

**Verified rather than asserted:** the unit layer now asserts directly that reputation is worth
nothing once the lease is over. That single check is what stops a future "rep should carry over a
bit" tweak from silently breaking the pillar.

**Harder — and this is the honest cost:** the contribution tally is a real feature, not a readout.
It needs per-player attribution plumbed through delivery, racking, damage and the dilemma, and
every one of those is host-authoritative and has to survive a client disconnecting mid-run. It is
Phase 4 work and it is not small.

**Watch for:** the tally being visible at day CLOSE will change behaviour, and that is the point,
but the direction is not certain. If it turns out crews start hoarding the Goods OUT door despite
the racking column, the mitigation is to show fewer columns rather than to hide the tally.

**Also watch for:** the host split assumes a friends lobby. It is correct for Steam P2P co-op and
it would be hostile in a public matchmaking context. If public lobbies ever appear, this needs
revisiting — not the unlock model, just who holds the pen.

**Rules out:** reputation as XP, per-player wallets during a run, automatic or contribution-weighted
splits, and run-affecting unlocks bought with an individual's cut.

**Does not decide:** buying and selling cargo. That is the sales-counter proposal, half of which is
parked bartering scope under ADR 6, and it needs its own superseding ADR rather than arriving
through this one.

## Alternatives considered

**Reputation as the meta currency**, per GDD §4 as written. Rejected because it breaks ADR 20 the
day both are implemented, and breaks it *silently* — comping would remain worth something on the
final night, so the late-lease flip that makes the fork a real decision would quietly stop
happening. Nothing would fail; the game would just be less interesting for reasons nobody could
name.

**Per-player wallets during the run.** Genuinely more social texture, and the version that matches
the instinct that whoever works the gate holds the cash. Rejected because rent is a shared fail
state: tying it to one player's balance means a disconnect or a sulk ends the run for reasons
that have nothing to do with warehousing.

**Automatic even split, or a contribution-weighted one.** Safe, and much less interesting. A
weighted split in particular is the worst of both — it removes the judgement while implying the
numbers were complete enough to judge with, which is exactly what they are not.

**A single net contribution score per player.** Considered because it is far easier to display.
Rejected because it settles the argument instead of starting one. The host would read a winner
rather than form a view, and the social moment the whole design is built around would collapse
into a scoreboard.
