# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-17)

**Core value:** The dilemma is the game — patch and hope, confess, or comp.
**Current focus:** Phase 1, Storage

> **Narrative history lives in `docs/conversation-log.md`, not here.** This file tracks
> execution position only. Duplicating the story in two places guarantees one of them
> goes stale.

## Current Position

Phase: 1 of 7 (Storage)
Plan: none yet
Status: Ready to plan
Last activity: 2026-08-17 — Phase 0 closed except the Steam join; physics budget measured; GSD adopted

Progress: [█░░░░░░░░░] Phase 0 complete bar one blocked item

## Accumulated Context

### Decisions

All decisions live in `decisions/` and are indexed in `decisions/decision-log.md`.
**ADRs are authoritative over anything in `.planning/`** (ADR 15). The ones that most
constrain upcoming work:

| ADR | Constrains |
|---|---|
| 4 — grid storage, physics transport | Phase 1 directly. Racked items must be static, never simulated |
| 7 — client owns its capsule only | Every interaction. A client asks; the host decides |
| 12 — project structure | Where every new file goes. Racks are `world/`, cargo is `goods/` |
| 13 — force-driven held items | Never freeze or reparent a held crate; it deletes throwing |
| 14 — physics budget of ~150 | Floor clutter, rack shedding volume, items per day |
| 15 — GSD wraps the build order | This file, and everything else in `.planning/` |

### Open

- **Steam join half is unproven** and needs a second machine. `docs/steam-validation-run.md`.
- **Detection and patch maths are undefined** — the thinnest part of the GDD, and Phase 3 depends on it entirely.
- **The grid module is 0.5 m** (ADR 16). Nothing is modelled to it yet, and the crate must match exactly before anyone builds art.
- **Feel tuning is provisional.** Hold stiffness 2400 / damping 460 came from one play session. All exported and tunable live.

### Constraints learned the hard way

- Headless Godot runs uncapped, so frame counts are useless as timeouts. Use wall-clock deadlines.
- A new `class_name` is invisible to headless runs until the editor rescans.
- One Godot editor at a time — the MCP bridge grabs port 9080 and will silently edit the wrong project.
- Close the editor before any branch switch that touches `addons/`; it holds the Steam DLLs open.

## Phase 0 outcome

Complete and verified, except NET-02's join half.

Delivered: transport abstraction with ENet and Steam behind one interface, session
lifecycle and spawn handshake, client-authoritative first-person capsule, host-simulated
force-driven cargo, a carry referee enforcing one crate per player and two holders per
crate, host-authoritative shoving, an integration suite that proves all of it, and a
measured physics budget.

Two things it changed along the way: held items became force-driven rather than parented
(ADR 13), and cargo replication moved to 20 Hz on-change, cutting host upstream 16×.
