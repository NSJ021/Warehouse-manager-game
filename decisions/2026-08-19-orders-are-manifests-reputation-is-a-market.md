# Orders are manifests, and reputation is a market position rather than a score

- **Date:** 2026-08-19
- **Status:** Accepted
- **Deciders:** NJ
- **Corrects:** [two-currencies-and-the-crew-split](2026-08-19-two-currencies-and-the-crew-split.md) (ADR 21), which left reputation one-dimensional. It does not change ADR 21's currency model, decay, pot or split.
- **Depends on:** [detection-and-patch-maths](2026-08-19-detection-and-patch-maths.md) (ADR 20).

## Context

Two gaps surfaced from one question: *what happens when an order physically cannot be completed?*

**The first was a softlock risk.** If an order needs three crates, and crates can leave the world,
a run can become mathematically impossible while the rent clock keeps running. That is worse than
losing — it is ninety minutes with no way to reach an ending.

Two things turned out to already answer it. `DESTROYED` is a condition tier, not deletion, so
**v1 has no crate sink** — nothing removes cargo except handing it to a client. And **confessing is
unconditional**: it needs no stock, no replacement, nothing physical. Worst case you confess on
everything and the run ends properly. The chain `patch → comp → confess` always terminates.

What was genuinely undefined was whether an order is atomic, and that mattered because
all-or-nothing is a cliff: two crates delivered perfectly and one short would score the same as
delivering nothing.

**The second gap was in ADR 21, made an hour earlier.** It treated reputation as one-dimensional —
high means better and more contracts, low means fewer. That makes **low reputation purely
punishing**, with no counterplay: burn your clients and the back half of the run is a death spiral
you cannot trade your way out of. It also left the patch-and-hope path strategically incoherent,
because the ratchet of accumulating suspicion had nowhere to lead except a worse version of the
same game.

## Decision

### The crate is the unit of handover; the order is a manifest

An order is a list, not an atomic transaction. Each crate is handed over individually, and each one
independently resolves as delivered, patched, confessed or comped. **The order's outcome is the
sum**, plus a **completion bonus** for a clean full delivery.

Part-fulfilment therefore needs no mechanism at all — it is what happens when you confess on one
crate of three. The cliff becomes a gradient, the completion bonus keeps "finish the order" a real
goal, and no new state is introduced.

**Wrong-type handover is possible and always spotted.** You can physically hand someone water when
they ordered food; they notice immediately, with no roll. The game does not stop a player being an
idiot — that would be paternalistic and off-brand — but it does not pretend idiocy might work
either. Concealment is the tape gun's job, and one concealment axis is enough.

**Comping requires like-for-like**, which makes it *conditional on what the building contains*. If
nobody else stored food, a food order cannot be comped and the fork is only two wide. That is a
feature: the stock mix becomes an input to the pillar, and comping reads as a resource that can run
out rather than a button that is always there.

### Reputation is a market position, not a score

**High reputation and low reputation are different businesses, not more and less of one.**

| | **High reputation** — the legit trade | **Low reputation** — the unsavoury end |
|---|---|---|
| **Pays** | Rate. You are one of several warehouses | **Far above rate**, cash, no questions |
| **Volume** | Steady, predictable, plannable | Irregular, arrives when it arrives |
| **They inspect** | Yes — professional clients have procedures, so patching is harder to get away with | Yes, and harder: their goods must not be damaged *or examined* |
| **Cares about your history** | Completely. It is the whole relationship | Not at all. They care about this crate |
| **Burning them costs** | **Reputation** — contracts dry up, slowly | **Cash** — a penalty far exceeding the item, extracted now |

**The symmetry is the decision: legit clients punish you in reputation, dodgy clients punish you in
cash.** That maps exactly onto ADR 21's two currencies and inverts the risk profile at each end. The
legit market is forgiving today and unforgiving across a run, because reputation compounds. The
unsavoury market does not care what you did last week and wants paying tonight.

**Success is its own pressure at the high end.** The reward for a good reputation is *more work*,
and more crates through the door is more chances for a physics comedy to happen to you. Being good
is how you get busy, and being busy is how you break things.

**This is what stops low reputation being a death spiral.** Losing standing no longer shrinks the
game — it moves you sideways into a rougher one that still pays. The suspicion ratchet from ADR 20
finally has somewhere to lead: get caught often enough and you stop being the sort of firm legit
clients use, but the cash-in-hand crowd was never checking references.

**And it fixes an endgame hole in ADR 20.** Reputation decays to nothing as the lease ends, which
is correct and load-bearing — but it means reputation-denominated consequences stop biting on the
final nights, and recklessness goes unpunished exactly when it is most tempting. **A cash
consequence does not decay.** So the unsavoury market is self-balancing against endgame
recklessness, and it is the model any future mechanic with the same problem should copy.

**It is a continuum, not tiers.** Reputation shifts the *mix* of work being offered rather than
unlocking bands at thresholds. Visible tier boundaries would be gamed; a shifting mix is felt
instead of calculated.

**Climbing back is possible and expensive.** Taking dodgy work damages legit standing (GDD §6.6), so
recovering means turning down the best-paying work available to you and grinding lower-margin
legitimate contracts. That is a real strategic decision with a real cost, which is what makes the
drift downward meaningful.

**You cannot sustain both ends at once.** That is the guardrail that stops "take the dodgy money
*and* keep the good clients" being strictly optimal — a dodgy contract accepted while your standing
is high is a deliberate hit to it.

## Consequences

**Easier:** the back half of a bad run is now playable rather than a formality. Patch-and-hope has a
coherent destination. Order fulfilment has a defined granularity for Phase 4, and part-fulfilment
costs nothing to build. GDD §6.6's dodgy clients stop being flavour and become the low end of a
system that already needed one.

**Cheaper than it looks:** the content already exists. §6.6 has the personalities, the above-rate
pay and the reputational-risk-with-legit-clients rule written down. What is new is *gating the mix
on reputation*, which is a rule rather than a system.

**Harder — and this is the honest cost:** it doubles the client-behaviour surface that has to be
balanced. Two markets with opposite risk profiles is two economies, and each lease term is already
effectively its own economy. This is the single biggest addition to Phase 4's tuning load.

**Watch for:** the unsavoury end being strictly better. It pays more and forgives your history, so
the only things holding it in check are that its goods must not be damaged and that taking the work
costs legit standing. If either weakens in tuning, tanking reputation deliberately becomes the
optimal opening move.

**Also watch for:** the cash penalty for burning a dodgy client needs a floor *and* a ceiling. Too
small and the low end has no risk at all; large enough to end a run outright and it is an
instant-loss button attached to a physics accident.

**Rules out:** all-or-nothing order fulfilment, comping with goods of a different type, atomic
orders, and reputation as a single good-to-bad axis.

**Does not bring in raids, blackouts or police events.** Those remain parked under ADR 6. GDD §6.6
already states the louder consequences are post-launch and are *earned* by burning clients rather
than rolled randomly — this ADR is consistent with that and does not advance it.

## Alternatives considered

**Keep reputation one-dimensional.** What ADR 21 assumed, and simplest to balance. Rejected because
it makes the second half of a damaged run a death spiral with no counterplay, and because it leaves
the suspicion ratchet leading nowhere — the player is punished for the exact behaviour the pillar is
built to tempt them into, with no alternative destination.

**Discrete reputation tiers with thresholds.** Easier to communicate and to build. Rejected because
visible thresholds get played to: a player who knows the boundary sits just above or just below it
deliberately, which converts a felt drift into an arithmetic exercise.

**Punish dodgy clients reputationally too, like legit ones.** Consistent and simpler. Rejected
because it wastes the opportunity: an entirely reputation-denominated economy has no consequence
that survives ADR 20's end-of-lease decay, so the final nights of every run would be consequence-free
for everything except cash. The cash penalty is what gives the endgame teeth.

**Refuse wrong-type handovers outright.** Considered and rejected as paternalistic. The game's whole
posture is that you are allowed to make the wrong call and then live with it. Refusing the input is
a different game from allowing it and having the client look at you.
