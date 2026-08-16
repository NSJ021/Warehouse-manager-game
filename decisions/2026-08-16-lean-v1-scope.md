# Lean v1 scope; co-op-first with solo playable

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

The initial pitch contained a lot of genuinely good ideas: forklifts, layout build mode, cleaning and mess, power cuts, police raids, price bartering at the door, multiple maps, upgrades. NJ explicitly wants a small-to-medium game, not a monster. Every one of those features is fun; collectively they are several years of work on top of a hard netcode problem.

## Decision

**Lean v1 — prove the loop.**

**In:** goods in → grid-snapped storage → goods out · physics carry, two-player carry, drag · drop and collision damage · condition tiers · tape gun with patch / confess / comp · client trust and suspicion · rent clock and eviction · one map · 10 and 30-day lease terms · 1–4 co-op over Steam P2P · solo playable.

**Out (parked, not cancelled):** forklift · layout build mode · cleaning and mess · blackout and police-raid events · price bartering · 90-day term · additional maps · upgrade trees · proximity voice chat.

**Solo posture:** co-op-first, solo playable but punishing — the Lethal Company position. Quotas and rent scale with player count, but not enough to be comfortable. Large cargo is drag-only when alone. Marketing states plainly that this is a co-op game.

## Consequences

**Easier:** a finishable project. Phases 0 and 3 (netcode and the dilemma system) get the attention they need to actually be good, instead of being rushed to make room for features.

**Harder:** the launch feature list looks thin next to the pitch. The game must survive on the *quality* of handling, damage and the dilemma rather than on breadth.

**Guardrail:** anything on the Out list re-entering v1 requires a **superseding ADR**. Not a conversation — a document. This ADR exists specifically to be the thing that says no.

**Named exception:** **proximity voice chat is the first feature back in.** It is the highest-ROI item on the parked list — every breakout in this genre has it, and it is what converts a decent co-op game into shareable clips, which is the entire marketing budget for a game this size. The audio bus should be designed for it now even though it is cut from v1.

## Alternatives considered

**Core scope** (Lean plus forklift, build mode, cleaning, chaos events, full client relationships) — this is the full original pitch, and it is a genuine 12–18 month project on top of unsolved netcode.

**Full scope** (Core plus three maps, upgrade trees, proximity voice, meta-progression) — this is where "small-to-medium" stops being true, and it directly contradicts pillar P4.

**Co-op only** — would focus every design decision, but costs a meaningful share of sales and review scores. Very few games survive it.
