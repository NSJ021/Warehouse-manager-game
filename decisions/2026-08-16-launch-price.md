# Launch price: £9.99 / $11.99, with a launch-week discount

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

Price had never been decided. Comparable-set research made it urgent, because the data splits the co-op field into two clusters with almost nothing between them.

| Cluster | Price | Examples | Lifetime reviews |
|---|---|---|---|
| Co-op physics chaos | £3–£8.50 | Lethal Company £8.50 · R.E.P.O. £7.99 · PEAK £3.19 · Content Warning £6.39 | 163k–510k |
| Management sim | £15.49–£17.75 | Schedule I £16.75 · Supermarket Simulator £16.75 · TCG Card Shop £17.75 · PlateUp! £16.75 | 4k–313k |

Warehouse Manager is deliberately both — physics comedy in a run-based management shell — which means it can be priced into either lane and belongs natively to neither.

Two facts pushed toward the cheaper lane. First, this genre sells in groups: a four-player game's real price is four times its listed one, so £16.75 is a £67 decision for a group of friends and £9.99 is a £40 one. Second, the sim lane's pricing is supported by solo-player depth, and the lean-scope ADR has already honestly conceded that solo play here is punishing and not the intended experience. Charging sim-lane prices for a game that openly tells solo players it isn't for them is not a position that survives contact with reviews.

Against that, this is not *only* a chaos game. There is a real economy, a lease structure and a memory game underneath, and pricing at £7.99 undersells that and leaves money on the table for no benefit.

## Decision

**£9.99 GBP / $11.99 USD at launch**, with regional pricing following Steam's recommended conversions.

**A 10% launch-week discount**, bringing the effective entry price to about £8.99 — inside the traction cluster, next to Lethal Company's £8.50 — while the headline price stays at the £10 mark the game is aiming to be worth.

Deliberately *not* £16.75. That number is achievable later, through content updates and a proven game, and any move toward it is a future ADR rather than a launch decision.

## Consequences

**Easier:** removes friction from the four-friend purchase, which is the only purchase shape that matters here. Sits close enough to the cluster that price is never the reason someone doesn't buy. Leaves obvious headroom for a paid content update or a price rise on a 1.0 exit from Early Access, which is a much easier move than a cut.

**Harder:** at £9.99 the game is priced above every comparable in the chaos cluster, so it must visibly offer more than they do within the first ten minutes — the lease, the rent clock and the dilemma have to be legible early, not after an hour. Revenue per sale is roughly 40% lower than the sim lane, so this decision only pays off if unit volume is genuinely higher; if wishlist data before launch suggests sim-lane positioning is landing better with the actual audience, this ADR should be revisited rather than defended.

**Follow-up:** revisit once real wishlist numbers exist, and again before any Early Access exit. Price is one of the few launch decisions that is cheap to re-decide with better information, and the store page will not exist for some time.

## Alternatives considered

**£7.99, matching R.E.P.O.** — safest possible placement in the winning cluster. Rejected as leaving money on the table for a game with a genuine management layer, and because pricing at the exact floor invites the "another Lethal Company clone" read the game is trying to avoid.

**£16.75, the sim lane** — highest revenue per sale, and the shelf where Supermarket Simulator and PlateUp! sit. Rejected because it multiplies to £67 for four players, and because it demands solo depth this game has deliberately chosen not to build.

**Free with paid cosmetics** — Supermarket Together reached 97k reviews free. Rejected outright: it is a fundamentally different product, funding model and live-ops commitment, and none of that is compatible with a solo developer shipping a lean v1.
