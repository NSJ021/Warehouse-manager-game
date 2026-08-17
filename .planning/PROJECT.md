# Nice Little Earner

> **This file is a pointer, not a source.** The design lives in `docs/GDD.md` and the
> decisions live in `decisions/`. Where anything here disagrees with an ADR, **the ADR
> wins** — see [ADR 15](../decisions/2026-08-17-gsd-wraps-the-build-order.md). Do not
> restate design here; link to it, so there is only ever one copy to keep true.

## What This Is

A 1–4 player first-person co-op physics comedy about running a leased warehouse. Take
goods in, store them, get them back out on time and undamaged. You will fail at the
third one — and then you have to decide whether to tell the customer.

Godot 4.6, Jolt physics, host-authoritative networking over Steam P2P. Solo playable and
deliberately punishing.

## Core Value

**The dilemma is the game.** Damage is not a fail state, it is a fork: patch it and hope,
confess and eat the loss, or comp the customer from someone else's stock. If that choice
is not tense, nothing else saves the game.

## Requirements

See `.planning/REQUIREMENTS.md`, which is derived from GDD §10 rather than invented
separately. In and out of scope are settled by [ADR 6](../decisions/2026-08-16-lean-v1-scope.md);
anything on the Out list needs a superseding ADR to come back.

### Validated

- **Netcode spine** — four peers, host-authoritative, verified by the integration suite.
- **Force-driven carry** — grab, two-player carry, handoff, shove, all verified.

### Out of Scope (v1)

Forklift · layout build mode · cleaning & mess · blackouts and raids · price bartering ·
90-day term · additional maps · upgrade trees. Reasoning in ADR 6. Character specialties
and the sales counter are *proposed, undecided* — see `docs/idea-book.md`.

## Context

Read these before planning any phase:

| Source | What it settles |
|---|---|
| `decisions/decision-log.md` | Every locked decision, and what has been superseded. **Check first.** |
| `docs/GDD.md` | The design, and §13 the build order this roadmap mirrors |
| `docs/project-structure.md` | Where files go and what things are called (ADR 12) |
| `docs/physics-budget.md` | ~150 concurrent rigid bodies. Constrains clutter, shedding, items per day (ADR 14) |
| `warehouse-manager/test/README.md` | How to prove anything works |
| The local project instructions (untracked, machine-local) | Working rules, environment traps, current status |

**Constraints that bind every phase:**

- **Host-authoritative, client owns only its own capsule** (ADR 7). A client asks; the host decides.
- **Held items are force-driven, never parented** (ADR 13). Freezing or reparenting a held crate silently deletes throwing.
- **Storage snaps to a grid; transport is full physics** (ADR 4). Never mix them — and since ADR 14 this is performance-critical, not just a feel decision.
- **~150 concurrent loose rigid bodies** (ADR 14). Racked items must be static and unreplicated.
- **The repo is public.** No AI-tooling or vendor names in any tracked file, filename, or commit message.

## Working Agreements

- Feature branches, conventional commits, PR merges. **Never push without explicit approval.**
- `./tools/run-tests.ps1` must be green. It runs on push via the `pre-push` hook.
- Verify with a tool rather than recalling. State what was actually checked, and distinguish verified from inferred.
