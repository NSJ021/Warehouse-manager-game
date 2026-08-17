# Held items are force-driven, not parented

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ
- **Supersedes:** the held-item clause of [host-authoritative-netcode](2026-08-16-host-authoritative-netcode.md) — "Held items parent to the holder on the host and replicate their transform to clients" — and the reaffirmation of that clause in the header of [client-authoritative-character](2026-08-16-client-authoritative-character.md). Host authority over held items is unchanged and absolute; only the *attachment mechanism* changes.

## Context

Phase 0's remaining work is the crate: pick up, drop, hand off, two-player carry. Before writing it, the attachment model has to be settled, because Phase 1's rack snapping is built on top of whatever it is and Phase 3's damage system reads its collisions.

ADR 5 specified parenting: freeze the body, reparent it to a hold anchor on the host, replicate the transform. That is the precise option, and it is the wrong one here for three reasons that only became visible once the spine existed.

**It fights the pillar.** P3 is *clumsiness is the comedy*. A rigidly parented crate cannot be clumsy — it tracks the hands exactly, passes through door frames as a decoration, and never once swings into a rack. The comedy would then have to be added back later as an effect, on top of a system built to prevent it.

**It exposes the round trip as a bug.** Under ADR 7 the holder's capsule is client-authoritative, so on the host the holder's hand position is always one round trip stale. With a rigid parent that staleness renders as the crate visibly trailing the holder's hands and snapping to catch up — which reads as a network fault, because it is one. A spring lags *by design*. The same stale input renders as weight. The latency does not go away; it stops looking like an error and starts looking like mass.

**It throws away the data Phase 3 needs.** The damage system is driven by drop height, collision velocity and being run into by a teammate. A force-driven body generates all three as a side effect of being simulated. A frozen, parented body generates none of them and would need a parallel fake-collision system to fill the gap.

## Decision

**A held crate stays an awake `RigidBody3D` in the level, simulated by the host. It is never frozen and never reparented.**

The host applies a spring-damper force pulling the body toward a **hold target** derived from the holder's camera — reach distance along the look vector — plus a torque toward an upright, forward-facing orientation so that labels stay readable. Both are clamped to a maximum, and the hold releases if the body is dragged past a break distance: walked into a wall, wedged under a rack, or yanked by someone else.

**Sag is a feature.** A held crate hangs below its hold point by an amount set by its weight against the spring stiffness. That is free, continuous feedback about how heavy the thing is, delivered without a single UI element. Do not tune it out.

**Two-player carry needs no second mechanism.** Two holders means two hold targets and the body is driven toward their midpoint. Stiffness is normalised per holder, so two people carrying is *steadier*, not twice as violent — which is exactly the GDD's promise that co-op is the better path rather than the required one.

**Authority is untouched.** The host owns the body and every hold-state transition. A client asks; the host decides and tells everyone. ADR 7 stands in full.

## Consequences

**Easier:** the comedy is free and immediate rather than a Phase 6 juice task. Phase 3 gets real impact velocities with no extra system. Two-player carry is the same code with a second target, which is the single biggest de-risking of the remaining Phase 0 work. Latency reads as physics.

**Harder — and this is the real cost:** tuning. The stiffness, damping, force clamp and break distance *are* the feel of the game, and there is no correct answer to look up; it is iteration with four instances running. Springs also go unstable when stiffness outruns the solver, so the force clamp is load-bearing rather than a nicety.

**Precise placement gets worse.** You cannot set a crate down to the centimetre by hand any more. This is absorbed by grid-snapped storage — [grid-storage-physics-transport](2026-08-16-grid-storage-physics-transport.md) — which now carries more weight than when it was written: it is no longer only a tidiness decision, it is what makes the springy grab survivable. Get near the slot; the slot does the rest.

**It guarantees the collision ADR 7 flagged to watch.** A client capsule walking into a host-owned held crate was listed there as "the main thing to watch". Under this decision it is not incidental, it is constant — players will bat each other's cargo around, on purpose, because it is funny. The push has to be requested rather than applied locally, and it now needs to work well rather than merely not crash.

**Rules out:** any UI or system that assumes a held item has an exact known transform, and hand-placement precision finer than the storage grid.

**Follow-up:** the Phase 0 gate explicitly includes "does the grab feel good" — it was always implied by *"get it feeling good; don't let it become the gate"*, and it is now the thing being judged. The physics budget stress test must count **held** bodies under spring forces, not just loose ones settling, because a held body is awake by definition and never sleeps.

## Alternatives considered

**Rigid parent and freeze** (ADR 5's original clause) — predictable, cheap, precise, and the obvious choice for a game about careful storage. Rejected on all three counts above: it suppresses the pillar, renders the round trip as a visible fault, and starves the damage system.

**Hybrid — rigid position, spring-damped visual anchor** — the crate parents rigidly but its mesh wobbles cosmetically. Keeps netcode simple and looks funny. Rejected because the wobble is a lie: the crate appears to clout the door frame and nothing happens. Every physics comedy in this cohort earns its laughs from real collisions, and a game whose damage model is its core pillar cannot afford decorative impacts.
