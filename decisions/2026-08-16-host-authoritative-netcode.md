# Host-authoritative networking, built in Phase 0

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

Four-player networked physics is the single hardest technical problem in this concept — harder than the art, the AI, the economy or the events combined. Held-object handoff, two-player carry, and authority over a wobbling rack are all genuinely difficult. Godot provides no built-in client-side prediction or rollback for physics.

## Decision

**Host-authoritative simulation.** The host simulates every rigid body. Clients send input and locally predict only their own character, reconciled against the host. Held items parent to the holder on the host and replicate their transform to clients. Steam P2P lobbies via GodotSteam, 1–4 players.

**This is Phase 0.** Before racks, goods, clients or economy: four players, an empty room, one physics crate, pick up / drop / hand off / two-player carry. Nothing else.

**This phase is a project gate.** If it isn't rock solid, the project stops rather than continues on a broken foundation.

## Consequences

**Easier:** one authority means no distributed-consensus problems and no desync between players. It is the shipped, proven architecture for this exact genre — Lethal Company and R.E.P.O. both do it. Steam P2P means no servers and no running costs.

**Harder:** host hardware quality affects everyone. Clients see a small latency on interacting with physics objects. Host migration is not viable — if the host drops, the run ends.

**Follow-up:** late join is restricted to between-days in v1. Mid-day drop-in is deferred.

## Alternatives considered

**Distributed authority** (each client owns objects it touches) — lower interaction latency, but handoff races and contested ownership produce exactly the desync bugs that kill co-op physics games.

**Deterministic lockstep with rollback** — best-in-class feel, but requires deterministic physics that Godot/Jolt does not guarantee across machines, and is far beyond this project's engineering budget.

**Build multiplayer later** — rejected outright. Retrofitting networking onto a finished single-player physics game is the most common way projects of this shape die.
