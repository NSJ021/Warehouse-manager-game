class_name Dilemma
extends RefCounted

## The maths behind the game's pillar: patch and hope, confess, or comp (GDD §6.5).
##
## Whoever is holding a damaged item at handover picks one, alone, with no group
## vote. This script prices those three options. It does not present them, and it
## does not decide — it is the numbers underneath a choice a player makes.
##
## [b]The design target, and the only thing that makes this work:[/b] there must
## be no dominant strategy. The right answer has to change with the situation, or
## the fork is a decision tree with one correct branch and the pillar is decoration.
## Four inputs move it, and all four are live:
##
## [codeblock]
##   patch depth       how many tiers of damage the tape is hiding
##   item value        expensive cargo gets looked at
##   client suspicion  permanent, and raised every time you are caught
##   days remaining    what a point of reputation is still worth
## [/codeblock]
##
## That last one is the mechanism, not a fudge. Reputation is only worth anything
## because it gates future contracts, so its cash value decays as the lease runs
## out. Early in a 30-day term, comping is the strongest play. On the final day of
## a 10-day term, reputation is worth nothing and the correct move is to tape it
## up and gamble. The same item, the same damage, the opposite answer.
##
## [b]Expected value is not the whole decision, deliberately.[/b] Everything below
## prices the [i]average[/i] outcome, and a player facing eviction tomorrow does
## not care about averages — they need £400 tonight, and only the gamble can
## produce it. Confessing is worth more on paper and loses the run. That gap
## between what the maths says and what the situation demands is the drama, so it
## is a feature to protect rather than a rough edge to sand off.
##
## Pure logic: no nodes, no autoloads, no networking, so it unit-tests in a bare
## `--script` run and the host can evaluate it without a scene.

## Which fork was taken. Named for what the player does, not what it costs.
enum Choice { PATCH, CONFESS, COMP }

# ----------------------------------------------------------- detection

## Base detection chance per tier of concealed damage, indexed by patch depth.
##
## Super-linear on purpose, and this shape is the decision. A flat curve collapses
## the choice either way: if hiding one scuff were a coin toss nobody would ever
## reach for the tape, and if hiding a destroyed item were 20% everybody would
## patch everything and never confess. Rising steeply keeps a shallow lie a real
## gamble and a deep one close to suicide — while leaving it *possible*, because
## the desperate hail-mary is a story players tell afterwards.
const DETECTION_BY_DEPTH: Array[float] = [0.0, 0.15, 0.45, 0.80]

## How much the most valuable cargo in the game adds to being found out.
## Expensive things get unpacked and looked at; a cheap box gets signed for.
const VALUE_WEIGHT := 0.25
## How much a maximally suspicious client adds. Larger than [constant
## VALUE_WEIGHT] because it is the consequence that has to bite hardest — it is
## what stops "patch everything" from being a strategy. Get caught, and that
## client checks your work forever after.
const SUSPICION_WEIGHT := 0.30
## The value at which cargo is as scrutinised as it ever gets. Above this the
## value term stops growing, so one absurd item cannot make detection certain
## on its own.
const VALUE_REFERENCE := 2000.0

## Never certain in either direction while a lie is being told. A guaranteed
## escape would make deep patches free at the low end; a guaranteed catch would
## remove the gamble at the high end, and the gamble is the point.
const DETECTION_FLOOR := 0.02
const DETECTION_CEILING := 0.95

# ------------------------------------------------------------- payouts

## What confessing pays, indexed by the item's [i]actual[/i] condition tier
## (Pristine, Scuffed, Damaged, Destroyed). Thin at every tier, and rent is still
## due.
##
## Scaled rather than flat, because a flat rate makes damage severity invisible
## on the honest path — a player who has already decided to own up would be
## indifferent between scuffing something and obliterating it, so being careful
## would earn them nothing. GDD §6.5's "~40%" survives as the middle case, which
## is the one it was describing.
##
## The shape hands each tier a natural default fork: a scuff is the live gamble,
## a total loss is where comping earns its place. The other inputs — value,
## suspicion, days remaining — then decide when to deviate from that default.
##
## [b]It scales downward from 40%, not upward toward it, and that was measured
## rather than reasoned.[/b] A first attempt paid 70% for a scuff on the argument
## that light damage should be cheap to admit. The sweep rejected it immediately:
## patching fell from 25 wins to 2, because confessing a scuff became so nearly
## free that the gamble stopped being worth taking. The flat 40% it replaced had
## been tuned against scuffs all along — they are the common case — so 40% stays
## exactly where it was and only the worse tiers move.
const CONFESS_PAYOUT_BY_TIER: Array[float] = [1.0, 0.40, 0.28, 0.15]
## Owning up is noticed. Small, because honesty is the baseline expectation
## rather than an achievement.
const CONFESS_REP := 0.05
## Confessing also walks suspicion back down — deliberately, because it hands the
## player a real strategic tool: own up on something cheap to buy back the room
## to gamble on something expensive later. Smaller in magnitude than
## [constant CAUGHT_SUSPICION], so a bad reputation cannot be cheaply confessed
## away and the ratchet still tightens over a run.
const CONFESS_SUSPICION := -0.08

## Being caught costs the fee entirely and hits reputation hard.
const CAUGHT_REP := -0.25
## Permanent, per GDD §6.5. This is the memory that makes the loop a loop.
const CAUGHT_SUSPICION := 0.25
## Getting caught lying about a valuable item is worse than about a cheap one.
## Scales the reputation hit from half to one-and-a-half times, which is what
## stops "always patch the expensive ones" — the branch where the cash swing is
## biggest is also where the punishment is.
const CAUGHT_VALUE_FLOOR := 0.5

## Comping is the big reputation play. Fixed per incident rather than scaled by
## value, so making it right on cheap cargo is the efficient way to buy goodwill
## and comping something precious is a genuine sacrifice.
const COMP_REP := 0.15
const COMP_SUSPICION := -0.10

## What one point of reputation is worth in cash for each day still on the lease.
##
## The exchange rate between the two currencies, and the reason the answer moves.
## Reputation pays out by gating future contracts, so a point earned on day 1 of a
## 30-day lease has 30 days to compound and a point earned on the last day has
## none.
const REP_TO_CASH_PER_DAY := 90.0

## Tape costs money and, more importantly, time — the day clock is the pressure
## in this game, so a three-tier cover-up costing most of a minute is a real price
## even when the roll goes your way.
const TAPE_COST_PER_TIER := 15.0
const PATCH_SECONDS_PER_TIER := 12.0


## The odds a client spots the lie. Returns 0.0 for an honest handover — there is
## nothing to detect, and that is a different thing from being lucky.
static func detection_chance(patch_depth: int, item_value: float, suspicion: float) -> float:
	if patch_depth <= 0:
		return 0.0
	var depth := clampi(patch_depth, 1, DETECTION_BY_DEPTH.size() - 1)
	var chance := DETECTION_BY_DEPTH[depth]
	chance += VALUE_WEIGHT * _value_ratio(item_value)
	chance += SUSPICION_WEIGHT * clampf(suspicion, 0.0, 1.0)
	return clampf(chance, DETECTION_FLOOR, DETECTION_CEILING)


## What a point of reputation is currently worth in cash.
static func rep_value(days_remaining: int) -> float:
	return REP_TO_CASH_PER_DAY * float(maxi(days_remaining, 0))


## What patching costs before any roll is made: tape, and seconds off the day.
static func patch_cost(patch_depth: int) -> float:
	return TAPE_COST_PER_TIER * float(maxi(patch_depth, 0))


static func patch_seconds(patch_depth: int) -> float:
	return PATCH_SECONDS_PER_TIER * float(maxi(patch_depth, 0))


## The reputation hit for being caught, scaled by how valuable the lie was about.
static func caught_rep_penalty(item_value: float) -> float:
	return CAUGHT_REP * (CAUGHT_VALUE_FLOOR + _value_ratio(item_value))


# --------------------------------------------------- expected outcomes
#
# All three return a single cash-equivalent number so they can be compared, and
# so a test can sweep situations and assert that each choice wins somewhere. They
# are the *average* outcome — see the note in the class docs about why that is
# deliberately not the whole story.

static func patch_expected_value(
	item_value: float, patch_depth: int, suspicion: float, days_remaining: int
) -> float:
	var caught := detection_chance(patch_depth, item_value, suspicion)
	var penalty := caught_rep_penalty(item_value) * rep_value(days_remaining)
	return (1.0 - caught) * item_value + caught * penalty - patch_cost(patch_depth)


## What fraction of the fee owning up pays, for an item in this real condition.
static func confess_payout_ratio(actual_tier: int) -> float:
	return CONFESS_PAYOUT_BY_TIER[clampi(actual_tier, 0, CONFESS_PAYOUT_BY_TIER.size() - 1)]


## Takes the item's [i]actual[/i] tier rather than a patch depth: confessing hides
## nothing, so what matters is how bad it really is.
static func confess_expected_value(item_value: float, actual_tier: int, days_remaining: int) -> float:
	return confess_payout_ratio(actual_tier) * item_value + CONFESS_REP * rep_value(days_remaining)


## Comping pays for the delivery but spends stock that belonged to someone else,
## so a like-for-like swap nets to zero cash plus a large reputation gain. The
## problem moves rather than vanishing (GDD §6.5): the client whose crate you gave
## away is now short, and that lands later. That deferred debt is not priced here
## on purpose — it is a future event for the client system to own, not a number to
## fold into this one and lose sight of.
static func comp_expected_value(
	item_value: float, replacement_value: float, days_remaining: int
) -> float:
	return item_value - replacement_value + COMP_REP * rep_value(days_remaining)


## Rank the three by expected value. Ties break toward honesty, which matters
## only for a tutorial hint or an AI, never for the player — the player just picks.
## [param actual_tier] is the item's real condition, which sets both the confess
## payout and — because the fork being weighed is hiding the damage *completely* —
## the patch depth. Patching only part way is available to the player and is a
## strictly worse version of the same bet, so it is not one of the three.
static func best_choice(
	item_value: float,
	actual_tier: int,
	suspicion: float,
	days_remaining: int,
	replacement_value: float,
) -> Choice:
	var patch := patch_expected_value(item_value, actual_tier, suspicion, days_remaining)
	var confess := confess_expected_value(item_value, actual_tier, days_remaining)
	var comp := comp_expected_value(item_value, replacement_value, days_remaining)
	if confess >= patch and confess >= comp:
		return Choice.CONFESS
	if comp >= patch:
		return Choice.COMP
	return Choice.PATCH


static func _value_ratio(item_value: float) -> float:
	return clampf(item_value / VALUE_REFERENCE, 0.0, 1.0)
