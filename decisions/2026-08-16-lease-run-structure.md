# Session structure: the Lease Run

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

The choice was framed as run-based roguelite (PlateUp!) vs persistent campaign (Schedule I) vs shift-based sandbox. NJ wanted elements of several and proposed a fourth: pick a map, then lease it for a fixed term — 10, 30 or 90 days — each with different goals.

## Decision

**The Lease Run.** A run is one warehouse lease: choose a map, choose a term, commit.

**Rent is the clock** — it comes out daily, and failure to pay means eviction and the run ends. No arbitrary timer; the pressure is financial and continuous.

Terms are difficulty *and* session-length selectors: 10 days is a sprint with no runway to invest; 30 days is the core experience where reputation compounds; 90 days becomes a build-and-optimise endurance run. Each lease carries a contract win condition beyond survival (profit target, reputation target, or a zero-damaged-deliveries clause that directly weaponises the fraud system).

Maps are **constraint sets**, not new assets — cold storage (spoilage, refrigeration bills), cramped city depot (tight aisles, more collisions), derelict hangar (large but unreliable power).

## Consequences

**Easier:** solves session length, difficulty selection, meta-progression and "when does the game end" with one mechanic. Bounded and restartable like a roguelite, but persistent *inside* a run — which is what the reputation and client-grudge systems need to work. Replayability comes from constraints rather than content, which suits a small team.

**Harder:** three term lengths must each be balanced as a distinct economy. Rent curves, income rates and escalation need separate tuning passes per term.

**v1 ships** one map and the 10 and 30-day terms. The 90-day term and additional maps are post-launch.

## Alternatives considered

**Pure roguelite** — highest replayability per unit of content, but a fresh warehouse each run kills the client-relationship and reputation-grudge systems that P1 depends on.

**Pure persistent campaign** — best for reputation, but no natural end point and no restart pressure, so no replayability engine.

**Shift-based sandbox** — easiest drop-in/drop-out for friends, but no arc and nothing compounds.

The Lease Run is a superset: it is a run on the outside and a campaign on the inside.
