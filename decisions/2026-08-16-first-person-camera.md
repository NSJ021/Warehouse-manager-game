# First-person camera

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

The original pitch imagined watching 3–4 derpy characters running around a warehouse, which reads as third-person. But the game's environment is narrow aisles between tall racks, and its mechanics lean on spatial memory, view-blocking cargo, and (later) working in the dark.

## Decision

**First-person.** One camera, no third-person option in v1.

A third-person toggle may be added post-launch — co-op requires full character bodies and animations for other players anyway, so the marginal cost is camera work and IK polish, not an art pass.

## Consequences

**Easier:** lowest art and animation cost. Cargo naturally occludes vision — free difficulty and free comedy, and the justification for two-player carry. "Where did I put it?" becomes a real memory game, because that is how humans remember spaces. Future blackout events become genuinely tense.

**Harder:** players never see their own character flail, so self-directed slapstick is lost. Comedy must come from watching teammates and from audio. Layout build mode (post-launch) will need its own top-down placement view.

**Rules out:** couch co-op. Online only.

## Alternatives considered

**Third-person close** — best for visible slapstick and trailer clips, but a warehouse is close to the worst possible third-person camera environment: narrow aisles, tall shelving, constant clipping. Overcooked avoids this with a fixed camera; R.E.P.O. avoids it by being first-person. There is no third way. Also the highest animation cost.

**Top-down / isometric** — great for reading the whole warehouse, but that *destroys* the memory pillar (you can see everything), and tall racks occlude badly from above, which undercuts the warehouse fantasy.

**Deciding factor:** every successful game in this cohort — Schedule I (NJ's own tone reference), Lethal Company, R.E.P.O., Supermarket Simulator, Content Warning — is first-person. That is not a coincidence; it is the cheapest way for a very small team to make 3D feel good.
