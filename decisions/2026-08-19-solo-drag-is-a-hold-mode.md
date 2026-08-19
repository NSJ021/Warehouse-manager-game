# Solo drag is a hold mode, not a parallel system

- **Date:** 2026-08-19
- **Status:** Accepted
- **Deciders:** NJ
- **Builds on:** [springy-held-item-grab](2026-08-17-springy-held-item-grab.md) (ADR 13) and
  [client-authoritative-character](2026-08-16-client-authoritative-character.md) (ADR 7). Supersedes nothing.

## Context

GDD §6.1 has promised solo drag since the first session — "any item, any size, can be dragged
along the floor by one player — slowly, noisily, with a scuff chance" — and built a load-bearing
incentive on top of it. The whole reason two-player carry is worth organising is the last row of
the GDD's comparison table: **a dragged crate can only be left at floor level.** A lone player
cannot rack anything. That is what makes teamwork the *efficient* choice without ever making it
mandatory.

None of it was specified beyond that paragraph, and it was the last unbuilt item in Phase 0.

Three questions had to be answered before any of it could be written:

1. **Is drag its own system, or a variant of holding?** ADR 13 made held items force-driven
   rigid bodies pulled by a spring. A separate drag system would mean a second way to be
   attached to a crate, with its own break rules, its own referee path and its own bugs.
2. **What triggers it?** Automatically, by weight? Or an explicit input?
3. **Who enforces the speed penalty?** ADR 7 gives each client authority over its own capsule,
   so the host *cannot* slow anybody down.

## Decision

**Drag is a hold mode.** Same referee, same grant/revoke round trip, same break distance, same
never-parented rule. A crate has one way of being held and two ways of behaving while held.

**The drag spring acts only on the floor plane.** This is the whole mechanism. Gravity is left
holding the crate down and nothing ever pushes it upward, so it is never lifted. Two properties
fall out of that rather than needing to be built:

- **It catches on things.** With no vertical force there is nothing to lift the crate over a
  lip, so it snags on obstacles for free. The GDD asked for "snags, catches on corners"; this
  delivers it without a snagging system.
- **A solo dragger physically cannot rack.** The hold point is taken from the capsule's **yaw**,
  not the camera, so looking up at a rack does not haul the crate off the floor. The incentive
  the whole co-op design rests on is now geometry rather than a rule someone has to enforce.

No alignment torque either. A carried crate is held square so its label stays readable (Phase
2); a dragged one is meant to slew about and scrape.

**Both triggers, not one.** Anything heavier than one person can lift is dragged whether or not
it was asked for; `F` deliberately drags anything, however light. Automatic alone would make the
GDD's "any item, any size" false. Explicit alone would leave a solo player pressing `E` at a
Large crate and getting nothing, with no explanation.

**Two holders always carry, so a drag promotes.** A mate walking over and grabbing the other end
lifts a dragged crate off the floor, and it drops back to a drag when they let go. This is not a
special case — it falls out of re-deciding the mode whenever the holder set changes.

**The drag request is stored per holder, not per crate.** If A drags a crate, B grabs on to
help, and A lets go, B is *carrying* — B never asked to drag. One flag per crate gets this
wrong, which is not hypothetical: it was written that way first and the integration suite caught
it the same day.

**The dragger's own machine applies the 40% speed penalty**, because under ADR 7 nothing else
can. That makes the mode something clients must be *told*, so the host's grant carries it and a
targeted RPC announces any later change. Without that, a player whose drag got promoted would
keep walking at 40% for no reason they could see.

**Distance dragged accrues on the crate now**, ahead of Phase 3 needing it for scuffing. It
costs one multiply per frame on cargo that is already awake, and it means the damage model
arrives to find data already flowing rather than needing a new hook cut into the physics.

## Consequences

**Easier:** Phase 0 closes on gameplay. The co-op incentive is now enforced by physics rather
than by a rule. Phase 3's scuff input already exists. Throwing, shoving and two-player carry are
untouched, because nothing about the carry path changed.

**Harder — and this is the honest cost:** there are now two force paths on cargo instead of one,
so anything that changes hold feel has to be judged twice. The mitigation is that they share the
referee, the break logic and the never-parented rule, so only the spring itself differs.

**Watch for:** the mass threshold is **provisional**. It keys off `RigidBody3D.mass` alone
because size classes do not exist yet — ADR 18 fixes crate *dimensions*, not masses, so there is
no Large to calibrate against. The intent is that Large is the only thing a solo player cannot
lift. Revisit when Large exists.

**Also watch for:** drag currently has no audio and no scuffing, so it is presently only *slow*
rather than slow, noisy and damaging. It will read as under-punished until Phase 3 lands.

**Rules out:** parenting or freezing a dragged crate, for the same reason ADR 13 ruled it out
for a carried one — it would delete throwing, and here it would also delete the snagging.

## Alternatives considered

**A separate drag system with its own attachment.** A joint or a pin constraint to the capsule.
Rejected because it doubles the ways of being attached to a crate, and every referee rule —
one crate per player, two holders per crate, break on distance, release on disconnect — would
need writing twice and would drift apart.

**Automatic by weight only.** No new input. Rejected because GDD §6.1 explicitly promises that
*any* item can be dragged, and because deliberately dragging something light past a low obstacle
is exactly the sort of stupid-but-valid idea this game should reward.

**A modifier held alongside `E`.** Rejected as harder to discover and harder to explain on the
controls overlay than a second key that always means the same thing.

**Letting the host enforce the speed penalty.** Cleanest on paper, impossible in practice: ADR 7
gives the client authority over its own capsule, and taking that back to police a walk speed
would trade zero-latency movement for a cheat protection this game does not need. It is co-op
over Steam with friends.
