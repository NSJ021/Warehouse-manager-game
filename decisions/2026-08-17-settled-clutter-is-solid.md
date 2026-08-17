# Settled cargo becomes solid; disturbed cargo wakes

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ

## Context

GDD §6.2 promises that floor stacking "blocks pathing" — that dumping cargo on the floor is
a tempting shortcut with a real cost. It did not.

Cargo and players deliberately do not share a collision mask. That separation was not
arbitrary: sharing one let a puppet capsule — whose position is *written* rather than
simulated — resolve overlaps with unlimited force, bulldozing cargo 3.39 m across the room
from remote players while the host was simply blocked by its own cargo. Measured, not
guessed. Separating the masks removed both behaviours and moved all pushing to one clamped
host-side force.

The consequence was noted at the time but never designed: clutter became an obstacle to
**cargo** and not to **people**. An empty-handed player walks through a stack; the same
player carrying a crate finds their cargo snags on it, because cargo still collides with
cargo. That is inconsistent in a way players notice — you stroll through a pile you cannot
then carry a crate past — and it quietly made a GDD promise untrue.

## Decision

**A crate that settles on the floor becomes static and joins the world layer.** It is then
a real obstacle: you walk around it, exactly as you walk around a wall.

**Disturbing it wakes it.** The existing push sensor still detects players while the body is
frozen, so walking into settled clutter unfreezes it back to a dynamic body and it scatters
— which is the kicking-over behaviour GDD §6.2 asks for.

**Cargo in transit is unchanged.** Held crates and crates in flight stay dynamic and stay
off the players' mask, so nothing can be bulldozed.

Verified before deciding, not after:

| Assumption | Result |
|---|---|
| A dynamic cargo crate does not block a player | Capsule passed through, as today |
| A frozen static crate on the world layer blocks a player | Blocked at exactly crate face + capsule radius |
| A static crate can still be bulldozed | Moved **0.000 m** — it cannot |
| The push sensor still fires while frozen | **Yes** — so it can always be woken |

## Consequences

**This does not conflict with [ADR 7](2026-08-16-client-authoritative-character.md), and the
reason is the whole elegance of it.** A static crate is, to the physics engine, world
geometry. Clients already simulate their own capsule against world geometry authoritatively
— that is precisely what ADR 7 grants them. So the blocking happens client-side against
static geometry with no round trip and no authority question, while *pushing* remains a
request the host clamps. Nothing about the authority line moves.

**Easier:** the GDD's promise becomes true. Floor stacking now costs pathing, which is what
makes it a real decision rather than a free shortcut, and it does so without a single new
network message.

**Harder:** the crate gains a state machine — dynamic, held, settled, and later racked — and
every transition has to be right. A crate that freezes while a player is standing inside it,
or that fails to wake, is a stuck player or permanent scenery.

**The budget wants re-measuring, and it should improve.** [ADR 14](2026-08-17-physics-budget.md)
measured client cost scaling with bodies that *exist*, not bodies that move. Settled crates
becoming static should reduce that cost, not raise it — but "should" is exactly the word
that ADR got written to avoid. Re-run the stress harness once this lands.

**Rules out:** kicking a settled crate by *walking* into it at zero speed. Waking is driven
by the shove sensor, which has a minimum closing speed, so leaning on cargo does nothing.
That seems right — you should have to mean it.

**Watch for:** a crate settling half-inside a rack or a wall becoming an immovable obstacle,
and the wake threshold interacting with the shove force clamp. Both are tuning, and both are
the sort of thing that only shows up with a human walking around.

## Alternatives considered

**Leave it — clutter blocks cargo only.** Zero risk, already built, already verified. Rejected
because it leaves a GDD line untrue, and the honest version of this option was to reword the
GDD rather than pretend the game kept the promise.

**Put players back on the cargo mask.** The naive fix, and rejected on measurement rather
than taste: it reintroduces the asymmetric bulldozing that the mask separation was
introduced to cure — 3.39 m of launch from remote players, host blocked outright.

**Defer to the Phase 1 gate**, deciding it with a real warehouse to walk around. Genuinely
tempting, and it was the planner's staging. Rejected because the mechanism turned out to be
cheap to verify up front, and because leaving it open meant Phase 1 could close with STORE-04
decided but not built.
