# Client-authoritative player capsule, host-authoritative everything else

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ
- **Supersedes:** the character-prediction clause of [host-authoritative-netcode](2026-08-16-host-authoritative-netcode.md). The rest of that ADR — host simulates all rigid bodies, held items parent on the host, Steam P2P, Phase 0 as a project gate — stands unchanged.

## Context

The original netcode ADR specified that clients "send input and locally predict only their own character, reconciled against the host." That is full input-based prediction with rewind-and-replay reconciliation: input ring buffers, sequence numbers, redundant input packets, state snapshots and per-frame smoothing. It is a multi-week subsystem in its own right.

It is also not what the games cited as proof of the architecture actually do. Lethal Company and R.E.P.O. let each client own its own character outright and reserve host authority for physics objects. Prediction-and-reconciliation exists to defeat cheating and to keep competitive play fair. This is four friends in a PvE co-op game with no leaderboard, no ranked mode and no advantage worth cheating for.

The GDD already warns against this exact failure: *"Get it feeling good; don't let it become the gate."* Building a reconciliation layer would make the reconciliation layer the gate, not the handoff feel — which is the thing Phase 0 exists to prove.

## Decision

**Each client is authoritative over its own character capsule.** It simulates its own movement locally and replicates position and look direction to all peers. No prediction, no reconciliation, no rewind.

**The host remains authoritative over everything else** — every rigid body, every held-item state, every pick up / drop / hand off, and the resolution of two-player carry. A client asks to pick something up; the host decides and tells everyone.

The authority line sits exactly at the capsule boundary. Player movement is instant and local. Anything a player *touches* is host-owned and costs one round trip.

## Consequences

**Easier:** movement has zero input latency for every player, not just the host — which matters more in a game about squeezing a crate down a narrow aisle than any anti-cheat guarantee does. Removes the single largest engineering risk from Phase 0. Handoff logic stays simple because the item never changes authority; only its parent changes, and the host owns that decision either way.

**Harder:** a modified client can teleport or fly. Accepted — the blast radius is one friend group's own session. Player-vs-rigid-body collision now crosses the authority line: a client pushing a crate is a client colliding with a host-owned body, so the push must be requested rather than applied directly. This needs care in Phase 0 and is the main thing to watch.

**Rules out:** public matchmaking with strangers, and any competitive or leaderboard mode where movement integrity matters. Neither is in v1 scope.

**Follow-up:** if a future version ever wants public lobbies, this ADR is the one to supersede — the host-authority core underneath it does not need to change.

## Alternatives considered

**Input prediction + reconciliation (the original clause)** — correct for competitive games, cheat-resistant, best-in-class feel under latency. Rejected on engineering budget: it costs weeks, and it would delay or replace the actual Phase 0 gate, which is whether the handoff feels good.

**Host-authoritative characters with no prediction** (clients send input, wait for the host to move them) — simplest possible model and fully cheat-proof, but every non-host player feels their own movement lag by a full round trip. Unacceptable in a first-person game.
