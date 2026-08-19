# Detection and patch maths: reputation decays, so the right answer moves

- **Date:** 2026-08-19
- **Status:** Accepted · **amended 2026-08-19** (confess payout scaled by condition tier — see *Amendment* below)
- **Deciders:** NJ
- **Constrains:** Phase 3 in full, and the Phase 4 economy. Supersedes nothing; it fills the gap GDD §6.5 left open.

## Context

The dilemma is the pillar (P1). GDD §6.5 has always described the three forks — patch and hope,
confess, comp a replacement — and has always said "detection is a weighted roll, not a menu
outcome, driven by patch quality, item value, and that client's accumulated suspicion".

It never said by how much. It has been flagged in every session since as **the thinnest part of
the GDD**, and Phase 3 rests on it entirely. Worse, the failure mode is not "the numbers are a
bit off" — it is that the pillar quietly stops being a decision:

- If patching is usually right, the game is a fraud simulator with a formality attached.
- If patching is usually wrong, the tape gun is a trap and the fork has one correct branch.

Either way the pillar becomes decoration and nobody notices until the game is being played.

The hard part was never the probability curve. It was that **cash and reputation are different
currencies**, and any comparison between the three options needs an exchange rate between them.
Without one, "is confessing worth it?" is unanswerable.

## Decision

### Reputation is priced in cash, and the price decays with the lease

`rep_value = REP_TO_CASH_PER_DAY × days_remaining`, at **£90 per point per day**.

This is the whole design, not a convenience. Reputation only pays out by gating future
contracts, so a point earned on day 1 of a 30-day lease has thirty days to compound and a point
earned on the final day has none. Everything else follows from it.

The consequence is the property the pillar needed: **the same item, with the same damage, has
the opposite correct answer depending on when it happens.** Early in a long lease, comping is
the strongest play. On the last day of a short one, reputation is worthless and the correct move
is to tape it and gamble. That is a decision a player can *feel* without being taught it, and it
is not a fudge factor — it is what reputation actually is.

### Detection

```
P(detect) = base[patch_depth] + 0.25 × value_ratio + 0.30 × suspicion
            clamped to [0.02, 0.95],  and exactly 0 when patch_depth is 0

base = [0.00, 0.15, 0.45, 0.80]   indexed by tiers of damage concealed
value_ratio = min(item_value / 2000, 1)
```

**The base curve is super-linear, and that shape is the decision.** A flat curve collapses the
choice from either end: if hiding one scuff were a coin toss nobody would reach for the tape,
and if hiding a destroyed item were 20% everybody would patch everything and never confess.
Rising steeply keeps a shallow lie a genuine gamble and a deep one close to suicide — while
leaving it *possible*, because the desperate hail-mary is the story players tell afterwards.

**Suspicion outweighs value** (0.30 versus 0.25) because it is the consequence that has to bite
hardest. It is what stops "patch everything" being a strategy: get caught once and that client
checks your work forever.

**Never 0% and never 100% while a lie is being told.** A guaranteed escape makes shallow patches
free; a guaranteed catch removes the gamble at the deep end, and the gamble is the point.

### Payouts

| Fork | Cash | Reputation | Suspicion |
|---|---|---|---|
| **Patch, undetected** | full fee, less tape | — | — |
| **Patch, detected** | nothing | −0.25 × (0.5 + value_ratio) | **+0.25, permanent** |
| **Confess** | 40% / 28% / 15% of fee by tier | +0.05 | **−0.08** |
| **Comp** | fee − replacement (≤ 0) | +0.15 | −0.10 |

Tape costs £15 and **12 seconds** per tier. The seconds matter more than the money — the day
clock is the pressure in this game, so a three-tier cover-up costs most of a minute of it.

Three of these earn their specifics:

**The caught penalty scales with value** (half to one-and-a-half times). Without it, "always
patch the expensive ones" is a live strategy, because the cash swing grows with value while a
flat reputation hit does not. Scaling it puts the punishment where the temptation is.

**Confessing reduces suspicion.** Deliberately, because it hands the player a real tactic: own
up on something cheap to buy back the room to gamble on something expensive later. It is
smaller in magnitude than the increase from being caught (0.08 against 0.25), so a bad
reputation cannot be cheaply confessed away and the ratchet still tightens over a run.

**Comp's reputation gain is fixed rather than scaled by value**, so making it right on cheap
cargo is the efficient way to buy goodwill and comping something precious is a real sacrifice.
Its cash is the fee minus the replacement you gave away, which for a like-for-like swap is zero.
The deferred debt — the client whose crate you gave away is now short — is **not priced here**.
It is a future event for the client system to own, not a number to fold in and lose sight of.

### Expected value is not the whole decision, and that is the point

Everything above prices the *average* outcome. A player facing eviction tomorrow does not care
about averages: they need £400 tonight, and only the gamble can produce it. Confessing is worth
more on paper and loses the run.

**That gap is the drama.** It is a feature to protect, not a rough edge to sand off, and it is
why the maths must never be surfaced to the player as a recommendation.

## Consequences

**Easier:** Phase 3 has numbers to build against instead of a paragraph. The tape gun has a
defined effect. Client suspicion has a defined meaning and a defined decay path. The economy in
Phase 4 has an exchange rate between its two currencies, which it was going to need anyway.

**Verified rather than asserted.** A new `test/unit/` layer sweeps 192 situations across value,
depth, suspicion and days remaining, and requires that all three forks win somewhere and that
none wins more than 75%. On the realistic slice — ordinary one-tier damage, which is most of
what a session produces — it comes out **patch 25 / confess 23 / comp 16 of 64**, near enough a
three-way split. The promised reversals are asserted by name rather than left to the sweep.

**Harder — and this is the honest cost:** these numbers are calibrated against *each other*, not
against a real economy. Item values, rent and the day length do not exist yet. When they do, the
£90-per-point-per-day rate is the first thing that will need re-tuning, and it moves every
result at once. It is a single constant on purpose so that re-tuning is one edit.

**Watch for:** the sweep weights every situation equally and play does not. If real sessions turn
out to produce mostly deep damage rather than mostly scuffs, the uniform sweep will keep looking
healthy while the common case has settled on confessing.

**Also watch for:** nothing here is wired to gameplay yet. No tape gun item, no handover UI, no
damage sources — those are Phase 3. This is the model underneath them, deliberately built first
so that the pillar is not being designed for the first time while also being implemented.

**Rules out:** presenting detection odds to the player, and any design where the tape gun repairs
actual condition rather than concealing it.

## Amendment — 2026-08-19: confessing scales with how bad it actually is

**What changed:** the confess payout was a flat 40% of the fee. It is now banded by the item's
*actual* condition — **40% Scuffed, 28% Damaged, 15% Destroyed**.

**Why.** A flat rate made damage severity invisible on the honest path. A player who had already
decided to own up was indifferent between scuffing something and obliterating it, so being careful
earned them nothing unless they intended to lie about it. Severity mattered on the patch route
— one tape application versus three, 15% detection versus 80% — and nowhere else.

Banding it hands each tier a natural default fork, which the other inputs then argue with: a scuff
is the live gamble, a total loss is where comping earns its place.

**It scales downward from 40% rather than upward toward it, and that was measured rather than
reasoned.** The first attempt paid 70% for a scuff, on the intuitive argument that light damage
should be cheap to admit. The sweep rejected it on the first run — patching fell from 25 wins to
2, because confessing a scuff became so nearly free that the gamble stopped being worth taking.
The flat 40% had been tuned against scuffs all along, since they are the common case. So 40% stays
exactly where it was and only the worse tiers move.

**Effect on the sweep:** the one-tier slice is unchanged at 25 / 23 / 16, which is the point. Across
all tiers, confess falls from 61% to 51% of situations and comping rises to 33% — destroyed items
now push toward making it right, which is the behaviour the design wanted and did not previously
have.

**Recorded as an amendment rather than a superseding ADR** because it fills a point this ADR left
underspecified on the same day, before anything was built on it beyond the module and its tests.
It does not reverse a decision made here.

## Alternatives considered

**A flat detection chance per patch, tuned by feel.** Simplest, and the version most games would
ship. Rejected because it makes patch depth meaningless: a scuff and a destroyed item become the
same bet, so the tape gun stops being a decision about *how far to push it*.

**Detection as a deterministic threshold** — patch quality above X always passes. Rejected
outright: GDD §6.5 requires a roll. A threshold is a lookup table players solve once and then
execute, and the tension dies the moment it is solved.

**Reputation as a flat cash equivalent, not decaying.** Much simpler to reason about, and
rejected because it removes the single mechanism that makes the answer change over a run.
Without decay the ranking of the three forks is fixed for a given item and client, which is the
dominant-strategy failure the whole design is trying to avoid.

**A separate random "patch quality" roll per tape application.** Considered and rejected: it adds
variance without adding any decision texture, since the player has no lever over it. Patch depth
already carries the quality signal, and it is a number they control.
