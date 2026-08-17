# Roadmap: Nice Little Earner

> **This roadmap is a projection of GDD §13, not a second opinion.** Phase numbers and
> names match it exactly, so there is one build order with two views rather than two
> roadmaps competing. If a phase needs adding, reordering or rescoping, **change GDD §13
> first** and mirror it here. See [ADR 15](../decisions/2026-08-17-gsd-wraps-the-build-order.md).

## Overview

Build the netcode spine before any gameplay, because retrofitting multiplayer onto a
finished physics game is how projects of this shape die. Then storage, then the goods that
fill it, then the damage system that makes storage matter — and only then the dilemma the
whole game is actually about. Economy, run structure and polish follow, and the game is
tuned for solo last.

Phases 0 and 3 are the two that decide whether this game exists. Everything else is
execution.

## Phases

**Phase Numbering:** integers mirror GDD §13. Decimal phases (e.g. 2.1) are urgent
insertions and are marked INSERTED.

- [x] **Phase 0: Netcode spine** - 4 players, an empty room, one physics crate
- [ ] **Phase 1: Storage** - Racks, grid snap, Goods IN / Goods OUT zones
- [ ] **Phase 2: Goods** - Size classes, expiry, collection day, the day clock
- [ ] **Phase 3: The dilemma** - Damage, condition tiers, tape gun, patch / confess / comp
- [ ] **Phase 4: Consequence** - Clients, trust, suspicion, economy, rent, eviction
- [ ] **Phase 5: The run** - Lease Run wrapper, scoring, unlocks
- [ ] **Phase 6: Presentation** - Art pass, audio, proximity voice chat, juice
- [ ] **Phase 7: Shippable** - Solo tuning, balance, playtest

## Phase Details

### Phase 0: Netcode spine
**Goal:** Four players, an empty room, one physics crate. Pick up, drop, hand off, two-player carry. Nothing else.
**Depends on:** Nothing
**Requirements**: NET-01, NET-02, NET-03, CARRY-01, CARRY-02, CARRY-04
**Gate (GDD §13)**: *If this isn't rock solid, the project stops here.*
**Success Criteria** (what must be TRUE):
  1. Four peers connect, agree on the roster, and spawn matching bodies — **done, verified**
  2. A player can pick up, carry and drop a crate, and it reads as weight rather than lag — **done, confirmed in play**
  3. Two players can carry one crate, and hand it between them — **done, verified by the integration suite**
  4. Walking into cargo shoves it, identically for host and clients — **done, verified**
  5. The same session works over Steam P2P between two machines — **BLOCKED: needs a second PC**

Plans:
- [x] 00-01: Transport abstraction, session lifecycle, spawn handshake
- [x] 00-02: First-person player, client-authoritative capsule
- [x] 00-03: Physics crate, force-driven grab, carry authority
- [x] 00-04: Host-authoritative shoving
- [x] 00-05: Integration harness and physics budget
- [ ] 00-06: Two-machine Steam validation — see `docs/steam-validation-run.md`

### Phase 1: Storage
**Goal:** Racks with cells, grid-snapped insertion, and Goods IN / Goods OUT zones.
**Depends on:** Phase 0
**Requirements**: STORE-01, STORE-02, STORE-03, STORE-04, STORE-05
**Gate (GDD §13)**: *Storage feels deliberate.*
**Success Criteria** (what must be TRUE):
  1. A player carrying a crate can aim at a rack cell and place it, and it snaps cleanly
  2. Every peer agrees which cell holds which crate, and how many are in it
  3. Racked items are static and unreplicated, so they cost nothing against the body budget (ADR 14)
  4. Goods IN and Goods OUT zones detect what is inside them
  5. Floor stacking still works, and is still a tempting bad idea
  6. Hitting a rack hard enough sheds from the top row, and it reads as punishment rather than noise

**Plans:** 9 plans in 7 waves

Plans:
- [ ] 01-01-PLAN.md — Prove the spawner despawns a freed crate on both peers; name physics layer 4 `storage` *(wave 1)*
- [ ] 01-02-PLAN.md — `StorageGrid` cell arithmetic and the 2×2×2 lattice, test-first, unit layer wired into the suite *(wave 1)*
- [ ] 01-03-PLAN.md — The rack fixture: cell geometry, atomic occupancy as data, derived local visuals *(wave 2)*
- [ ] 01-04-PLAN.md — Place and retrieve: referee RPCs, one aim ray for crates and cells, a second integration session *(wave 3)*
- [ ] 01-05-PLAN.md — Goods IN / Goods OUT zones, agreed on both peers *(wave 3)*
- [ ] 01-06-PLAN.md — Aim feedback and the snap: cell highlight, travel, placement sound *(wave 4)*
- [ ] 01-07-PLAN.md — Rack shedding, bounded; and what floor stacking actually costs *(wave 5)*
- [ ] 01-09-PLAN.md — Settled cargo turns solid and disturbed cargo wakes, so floor stacking finally blocks pathing (ADR 17) *(wave 6)*
- [ ] 01-08-PLAN.md — The gate: a human judges whether storage feels deliberate, and the ADRs that follow *(wave 7)*

### Phase 2: Goods
**Goal:** Goods with size classes, fragility, store-until dates, and the day clock that makes them matter.
**Depends on:** Phase 1
**Requirements**: GOODS-01, GOODS-02, GOODS-03, CARRY-03, RUN-02
**Gate (GDD §13)**: *The loop closes.*
**Success Criteria** (what must be TRUE):
  1. Items come in Small (8 per cell), Medium (one whole cell) and Large (two cells) — ADR 18
  2. A lone player can drag any item, badly, and cannot rack a Large one above floor level
  3. A day runs morning → shift → close in 6–10 minutes
  4. Items have a store-until date, and being late costs something

Plans: TBD

### Phase 3: The dilemma
**Goal:** Damage, condition tiers, the tape gun, and the patch / confess / comp choice.
**Depends on:** Phase 2
**Requirements**: DMG-01, DMG-02, GOODS-04, GOODS-05, DIL-01, DIL-02, DIL-03, DIL-04
**Gate (GDD §13)**: ***The pillar works or the game doesn't.***
**Success Criteria** (what must be TRUE):
  1. Dropping or colliding damages goods in proportion to height, speed and fragility
  2. Every condition tier has an unmistakable visual and audio tell
  3. The tape gun raises *apparent* condition without touching actual condition
  4. Detection is a weighted roll, not a menu outcome
  5. **The right answer changes with your situation** — no option is always correct
  6. Whoever holds the item decides, alone, with no group vote

Plans: TBD

### Phase 4: Consequence
**Goal:** Clients with trust and suspicion, the economy, rent, and eviction.
**Depends on:** Phase 3
**Requirements**: CLIENT-01, CLIENT-02, CLIENT-03, ECON-01, ECON-02, ECON-03
**Gate (GDD §13)**: *A run can be lost.*
**Success Criteria** (what must be TRUE):
  1. A small named client roster, each with trust and suspicion that move with your behaviour
  2. Burning a client dries up their contracts
  3. Rent comes out daily and missing it evicts you, ending the run

Plans: TBD

### Phase 5: The run
**Goal:** The Lease Run wrapper — pick a map and a term, get scored, unlock.
**Depends on:** Phase 4
**Requirements**: RUN-01, RUN-03, RUN-04
**Gate (GDD §13)**: *A run can be won.*
**Success Criteria** (what must be TRUE):
  1. A run is 10 or 30 days on one map, and is committed to at the start
  2. Ending a lease scores profit, reputation and condition record
  3. Scoring unlocks something that changes the next run

Plans: TBD

### Phase 6: Presentation
**Goal:** Art pass, audio, proximity voice chat, and juice.
**Depends on:** Phase 5
**Requirements**: NET-04, plus the art pipeline
**Gate (GDD §13)**: *It's a game, not a prototype — and it can clip itself.*
**Success Criteria** (what must be TRUE):
  1. Proximity voice chat, 3D-positioned and distance-attenuated
  2. The sound of broken glass inside a sealed box exists and is as good as the design says
  3. A clip taken straight from play is worth posting

Plans: TBD

### Phase 7: Shippable
**Goal:** Solo tuning, balance across both lease terms, and playtest.
**Depends on:** Phase 6
**Requirements**: SOLO-01
**Gate (GDD §13)**: *Shippable.*
**Success Criteria** (what must be TRUE):
  1. Solo is playable, punishing, and honestly marketed as the lesser experience
  2. Both the 10 and 30-day economies are tuned — each is effectively its own economy
  3. Someone who has never seen it can play a full run

Plans: TBD
