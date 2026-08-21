# Requirements: Nice Little Earner

**Defined:** 2026-08-17
**Core Value:** The dilemma is the game — patch and hope, confess, or comp.

> **Derived from GDD §10, not invented alongside it.** Every requirement below traces to a
> line already in the design doc. If scope changes, **change the GDD first**, then mirror
> it here. Anything on the Out list needs a superseding ADR to come back
> ([ADR 6](../decisions/2026-08-16-lean-v1-scope.md)).

## v1 Requirements

### Multiplayer (NET)

- [x] **NET-01**: 1–4 players in a host-authoritative session; each client owns only its own capsule
- [ ] **NET-02**: A session runs over Steam P2P between two machines *(host half proven; join half blocked on a second PC)*
- [x] **NET-03**: A session runs over ENet, four instances on one machine, for development
- [ ] **NET-04**: Proximity voice chat, 3D-positioned and distance-attenuated

### Carrying (CARRY)

- [x] **CARRY-01**: A player can pick up, carry and drop cargo, and it reads as weight rather than lag
- [x] **CARRY-02**: Two players can carry one item together, and hand it between them
- [ ] **CARRY-03**: Any item can be dragged by one player — slow, noisy, with a scuff chance, and floor level only
- [x] **CARRY-04**: Walking into cargo shoves it, identically whether host or client

### Storage (STORE)

- [x] **STORE-01**: Racks expose **cells** that hold cargo — 8 Smalls, or 1 Medium, or half a Large *(01-03, twelve cells per rack against ADR 18; Phase 1 gate passed 2026-08-21)*
- [x] **STORE-02**: Cargo snaps into cells on insert, with no physics jitter *(01-04 place/retrieve, 01-06 the tweened travel-and-thud snap; verified clean on both peers and confirmed at the gate)*
- [x] **STORE-03**: Goods IN and Goods OUT zones detect what is inside them *(01-05, both peers proven to agree independently over real ENet)*
- [x] **STORE-04**: Floor stacking is allowed, blocks pathing, and counts as clutter *(ADR 17 / 01-09 — settled cargo turns static and blocks players for real, not only cargo in transit; verified underfoot at the Phase 1 gate, checks 16-19)*
- [x] **STORE-05**: Racks have stability; hit one hard enough and the top row sheds *(01-07, bounded three ways against ADR 14; confirmed at the gate to read as punishment, not noise — a dragged crate can never reach the threshold, a thrown or two-player-carried one can)*
- [x] **STORE-06**: A cell is atomic — one kind of cargo at a time — and retrieval within it is last-in-first-out *(01-03/01-04; atomicity challenged and upheld in play at the Phase 1 gate — the mixed zones are Goods IN, the floor, and shed aftermath, not a rack)*
- [ ] **STORE-07**: The round-trip invariant — racking frees a crate's body and retrieval mints a fresh one, so every field of a crate's record (kind today; condition, apparent condition, scuffs, fragility, store-until date, owner and value as later phases add them) must survive a place/retrieve cycle intact: `retrieve(place(crate)) == crate` for every field. LIFO returning a *different* crate of the same kind is correct; losing or corrupting a field is not. *(Named at the Phase 1 gate, 2026-08-21 — not yet built beyond `kind`; Phase 2/3 scope, load-bearing for the Phase 3 pillar, since an unfaithful round trip would let racking launder damage.)*

### Goods (GOODS)

- [ ] **GOODS-01**: Size classes — Small (0.5 m, 8 per cell), Medium (1.0 m, one whole cell, view-blocking), Large (2.0 × 1.0 × 1.0, two cells) *(open question, raised at the Phase 1 gate: which two cells a Large occupies — side-by-side across columns, or front-to-back through depth, which would uniquely use a wall rack's dead row — is undecided; answer in Phase 2 planning)*
- [ ] **GOODS-02**: Fragility 0–3, from crated machinery to glassware
- [ ] **GOODS-03**: A store-until date that is both the deadline and the spoilage limit
- [ ] **GOODS-04**: Condition tiers — Pristine, Scuffed, Damaged, Destroyed
- [ ] **GOODS-05**: Apparent condition, which diverges from actual condition when patched

### Damage (DMG)

- [ ] **DMG-01**: Damage from drop height, collision velocity, rack collapse, teammates, spoilage and darkness
- [ ] **DMG-02**: Every condition tier has an unmistakable visual *and* audio tell

### The dilemma (DIL)

- [ ] **DIL-01**: A tape gun raises apparent condition by one tier, costing time and materials
- [ ] **DIL-02**: At handover, any item below Pristine offers patch / confess / comp
- [ ] **DIL-03**: Detection is a weighted roll driven by patch quality, item value and client suspicion
- [ ] **DIL-04**: Whoever holds the item decides, unilaterally, with no group vote

### Clients (CLIENT)

- [ ] **CLIENT-01**: A named roster of 4–6 clients, each with a personality — including dodgy ones whose cargo everybody can see through, played entirely through trust and suspicion with no contraband system
- [ ] **CLIENT-02**: Trust, which gates contract quality and volume
- [ ] **CLIENT-03**: Suspicion, which is raised permanently by being caught

### Economy (ECON)

- [ ] **ECON-01**: Income from storage fees, on-time delivery and condition bonuses
- [ ] **ECON-02**: Daily rent, plus costs for tape, supplies and rack repairs
- [ ] **ECON-03**: Failing to make rent evicts you and ends the run
- [ ] **ECON-04**: Storage fees price **volume (per cell per day), never per item** — forced by ADR 18, since per-item fees make Smalls strictly dominant
- [ ] **ECON-05**: Value density varies by cargo type, and Large gets **no size premium** — its reward is fewer journeys

### The run (RUN)

- [ ] **RUN-01**: A run is one lease — pick a map and a 10 or 30-day term, then you are committed
- [ ] **RUN-02**: A day runs morning → shift → close in 6–10 minutes
- [ ] **RUN-03**: Ending a lease scores profit, reputation and condition record, and unlocks
- [ ] **RUN-04**: One map in v1

### Solo (SOLO)

- [ ] **SOLO-01**: Solo is playable and punishing; quotas and rent scale down, but not enough to be comfortable

## Non-functional

- [x] **NFR-01**: ~150 concurrent loose rigid bodies is the ceiling; racked items are static and unreplicated ([ADR 14](../decisions/2026-08-17-physics-budget.md))
- [x] **NFR-02**: One command runs the whole test suite, and it gates every push
- [ ] **NFR-03**: Ships at £9.99 / $11.99 with a launch-week discount ([ADR 10](../decisions/2026-08-16-launch-price.md))
- [ ] **NFR-04**: The Steam page carries an AI-content disclosure at launch

## Out of Scope (v1)

Each needs a superseding ADR to return, and the reasoning lives in ADR 6 so it is not re-argued from scratch:

- Forklift, layout build mode, cleaning and mess — scope, and none of them serve the pillar
- Blackouts and police raids — louder consequences should be *earned* by burning clients, not rolled randomly
- Price bartering at the door — overlaps the sales counter proposal, and neither is decided
- 90-day term, additional maps, upgrade trees — content breadth, not depth
- Named character specialties — *proposed, undecided*, see `docs/idea-book.md`
