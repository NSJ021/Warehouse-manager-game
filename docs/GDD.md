# Warehouse Manager — Game Design Document

- **Version:** 0.1 (initial)
- **Date:** 2026-08-16
- **Status:** Living document. Locked decisions live in `decisions/` and win over this doc until superseded.

---

## 1. Pitch

**1–4 players run a leased warehouse. Take goods in, store them, get them back out on time and undamaged. You will fail at the third one — and then you have to decide whether to tell the customer.**

A first-person co-op physics comedy about logistics, clumsiness, and quiet fraud. Cardboard, forklifts, expiry dates, and a tape gun you use to hide your crimes.

**Logline:** *Overcooked's panic, R.E.P.O.'s breakables, and a moral choice at the loading door.*

---

## 2. Pillars

Every design decision must serve one of these. If it serves none, cut it.

### P1 — The dilemma is the game
Damage is not a fail state, it's a **fork**. Patch it and hope, confess and eat the loss, or comp the customer from someone else's stock. The Cash vs Reputation tension is the spine of the economy and the source of every good story players tell about the game.

### P2 — Order under pressure
Storage is deliberate, plannable, and memorable. You *decide* where things go and you have to *remember* later. Chaos threatens that order — it never replaces it.

### P3 — Clumsiness is the comedy
The humour comes from physical incompetence, not written jokes. A wobbling rack, a crate blocking your view, the sound of glass shifting inside a box you just dropped.

### P4 — Small, deep, replayable
One warehouse done properly beats five done thinly. Variety comes from **constraints**, not assets.

---

## 3. Locked decisions

| # | Decision | ADR |
|---|---|---|
| 1 | First-person camera | `decisions/2026-08-16-first-person-camera.md` |
| 2 | Godot 4.6 + Jolt + Steam P2P | `decisions/2026-08-16-engine-godot.md` |
| 3 | The Lease Run structure | `decisions/2026-08-16-lease-run-structure.md` |
| 4 | Grid-snapped storage, physics transport | `decisions/2026-08-16-grid-storage-physics-transport.md` |
| 5 | Host-authoritative networking, built first | `decisions/2026-08-16-host-authoritative-netcode.md` |
| 6 | Lean v1 scope; co-op-first, solo hard | `decisions/2026-08-16-lean-v1-scope.md` |

---

## 4. The Lease Run

A **run** is one warehouse lease. You pick a **map** and a **term**, and you're committed.

**Rent is the clock.** Rent comes out daily. Miss it and you're evicted — run over. There is no arbitrary timer; the pressure is financial and it never stops.

| Term | Feels like | Design intent |
|---|---|---|
| **10 days** | A sprint | Rent is brutal relative to income. No runway to invest. Pure execution. One co-op session. |
| **30 days** | The core game | Enough room to buy racks and gear. Reputation begins to compound. |
| **90 days** | The campaign | Becomes build-and-optimise. Spoilage, wear and burnt clients compound viciously. Endurance run. |

Each lease carries a **contract win condition** beyond survival — e.g. *clear £X net profit*, *finish at 5★ with three named clients*, *move 200 crates with zero damaged deliveries*. The last one deliberately weaponises the fraud system: suddenly patching isn't a shortcut, it's a lie you have to sustain.

**End of lease** → scored on profit, reputation, and condition record → unlock currency → new maps, gear, client tiers.

*(v1 ships one map and the 10/30 day terms. 90-day and additional maps are post-launch — see §10.)*

---

## 5. The day loop

```
MORNING     Manifest posted. See what's arriving and what's due out today.
            Plan: where does it go, what needs finding.

SHIFT       Goods IN  — accept deliveries, sign for them, haul them to storage.
            STORAGE   — snap into racks. Or dump on the floor and regret it.
            Goods OUT — find today's collections, haul them to the door, hand over.
                        (This is where the dilemma fires.)

CLOSE       Rent due. Income banked. Reputation settles.
            Anything not collected today is late — penalty, rep hit.
```

Days are short — target **6–10 minutes**. A 10-day lease is roughly a 90-minute session.

---

## 6. Systems (v1)

### 6.1 Goods

Every item carries:

| Property | Values |
|---|---|
| **Size class** | Small (1 slot, one-handed) · Medium (2 slots, two-handed, **occludes your view**) · Large (4 slots, two-player carry or drag) |
| **Fragility** | 0–3 (crated machinery → glassware) |
| **Store-until date** | The day it must leave. Also the spoilage deadline. |
| **Condition** | Pristine · Scuffed · Damaged · Destroyed |
| **Apparent condition** | What the customer sees. **Diverges from real condition when patched.** |
| **Client** | Who owns it. Determines who turns up angry. |

**Production note:** everything is a cardboard box. One crate mesh + swappable label/decal + size variants = dozens of distinct-feeling goods for almost no art budget. Spend the saved time on sound.

**The drag mechanic:** any item, any size, can be dragged along the floor by one player — slowly, noisily, with a scuff chance. This is the solo player's answer to Large cargo, and it is funny. Keep it bad but possible.

**Two-player carry is always optional, never required.** Nothing in the game is gated behind having a second player. Teamwork is rewarded by being *better*, not by being mandatory:

| | Two-player carry | Solo drag |
|---|---|---|
| Speed | Full walking pace | ~40% |
| Stability | Steady | Snags, catches on corners |
| Damage | No scuff accrual | Scuff chance per distance dragged |
| **Racking** | **Can be lifted into any rack slot** | **Floor level only** |

That last row is the real incentive. A lone player dragging a Large crate physically cannot lift it into a high slot — so they either dump it on the floor (clutter, blocks pathing, one bump from disaster) or wait for a mate. Teamwork becomes the *efficient* choice without solo play ever being blocked.

**Netcode note:** because two-player carry is a fast path rather than a hard requirement, Phase 0 can prove it without solving contested two-client authority perfectly. Get it feeling good; don't let it become the gate.

### 6.2 Storage

- Racks expose **slots**. Items **snap** in on insert. Storage is a clean spatial puzzle, unpolluted by physics jitter.
- Racks have **stability**. Hit one hard enough and it wobbles; the top row may shed. Chaos is a *punishment for recklessness*, not ambient noise.
- **Floor stacking is allowed.** It's faster, it blocks pathing, it counts as clutter, and it's begging to be kicked over. A tempting shortcut with a real cost.

### 6.3 The memory game

Over 30 days you'll handle dozens of items. When a client turns up for crate #7 of an order placed three weeks ago, **you have to find it**. FIFO discipline, zoning, and aisle signage stop being flavour and start being survival. This is P2 in action and it needs no extra content to be deep.

### 6.4 Damage

Damage sources: drop height × fragility · collision velocity · rack collapse · being run into by a teammate · spoilage past the store-until date · working in the dark.

Each condition tier has an unmistakable **visual and audio tell** — a dented corner, a tear, a dark stain, and the single most important sound in the game: *the shift and tinkle of broken glass inside a sealed box*.

### 6.5 The dilemma (P1 — the core system)

At handover, for any item below Pristine, the player holding it chooses:

| Choice | Cash | Reputation | Risk |
|---|---|---|---|
| **Patch & ship** | Full | None *if undetected* | Detection → no pay, heavy rep hit, client suspicion permanently raised |
| **Confess** | ~40% | Small gain | Thin margins, rent still due |
| **Comp a replacement** | Negative | Large gain | The replacement belonged to **another client**. The problem moves; it doesn't vanish. |

**The tape gun** raises *apparent* condition by one tier per application. Time and materials cost. Apparent ≠ actual.

**Detection is a weighted roll**, not a menu outcome — driven by patch quality, item value, and that client's accumulated suspicion. That's what makes it a gamble instead of a decision tree.

> **Co-op rule: whoever is holding the item decides.** No vote, no confirmation from the group. The player who broke it can quietly patch and ship it before anyone notices. Do not gate this — the unilateral choice *is* the social engine.

### 6.6 Clients

A small named roster (4–6 in v1), each with a personality, a **trust** value and a **suspicion** value. Burn one and their contracts dry up. Keep one happy and they bring volume.

Reputation gates contract quality and volume — that's the whole loop in v1. The louder consequences (raids, cut power) are post-launch and are *earned* by burning clients, not rolled randomly.

### 6.7 Economy

**In:** storage fee per item per day · on-time delivery bonus · condition bonus.
**Out:** daily rent · tape and supplies · rack repairs.
**Fail:** can't make rent → evicted → run ends.

---

## 7. Multiplayer model

- **Host-authoritative.** The host simulates every rigid body. Clients send input and predict only their own character, reconciled against the host.
- **Held items** parent to the holder on the host; transform replicates to clients.
- **Steam P2P lobbies** via GodotSteam — no servers to run, no infrastructure cost.
- **Late join:** v1 allows joining between days only. Mid-day drop-in is a post-launch problem.
- 1–4 players.

**This is built first.** Retrofitting multiplayer onto a finished physics game is where projects like this die.

---

## 8. Solo play

Playable, punishing, clearly not the intended experience — the Lethal Company posture. Quotas and rent scale down with player count, but not enough to make it comfortable. Large cargo is drag-only. Marketing is honest that this is a co-op game.

---

## 9. Art & audio direction

**Visual:** low-poly, flat and gradient textures, near-zero texture work. Chunky proportions. Derpy humanoids — oversized hands, no fingers, simple rig, a walk cycle with too much bounce. Industrial grey and beige, punctuated by high-vis orange and yellow so gameplay-critical things read instantly. Cardboard is the hero material.

**Audio does the heavy lifting.** Cardboard scrape on concrete. The groan of a loaded rack. Tape screech. Forklift beep. And the glass tinkle — the sound that turns a small mistake into a decision.

---

## 10. v1 scope

### In
Goods in → grid-snapped storage → goods out · physics carry, two-player carry, drag · drop and collision damage · condition tiers · tape gun, patch / confess / comp · client trust & suspicion · rent clock, eviction fail state · one map · 10 and 30-day lease terms · 1–4 co-op over Steam P2P · solo playable.

### Out (parked, not cancelled)
Forklift · layout build mode · cleaning & mess system · blackout and police-raid events · price bartering at the door · 90-day term · additional maps · upgrade trees · proximity voice chat.

> **First thing back in:** proximity voice chat. It is the highest-ROI feature available to this game — every breakout in the genre has it, and it is what turns a decent co-op game into a clip factory. Design the audio bus for it now even though it's cut.

---

## 11. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Networked physics eats the schedule | **Critical** | Host-authoritative by design. Build it in Phase 0 and stop the project if it isn't solid. |
| Physics jitter ruins precise storage | High | Grid-snap on insert. Physics only in transit. |
| Scope creep from the parked fun list | High | ADR 6 is the guardrail. Anything from the Out list needs a superseding ADR. |
| Solo play is boring | Medium | Accepted and stated up front. Co-op-first is the honest position. |

---

## 12. Build order

| Phase | Goal | Gate |
|---|---|---|
| **0** | **Netcode spine.** 4 players, an empty room, one physics crate. Pick up, drop, hand off, two-player carry. Nothing else. | *If this isn't rock solid, the project stops here.* |
| 1 | Racks, grid snap, Goods IN / Goods OUT zones | Storage feels deliberate |
| 2 | Goods, size classes, expiry, collection day, day clock | The loop closes |
| 3 | Damage, condition tiers, tape gun, patch / confess / comp | **The pillar works or the game doesn't** |
| 4 | Clients, trust, suspicion, economy, rent, eviction | A run can be lost |
| 5 | Lease Run wrapper, scoring, unlocks | A run can be won |
| 6 | Art pass, audio, juice | It's a game, not a prototype |
| 7 | Solo tuning, balance, playtest | Shippable |

Phases 0 and 3 are the two that decide whether this game exists. Everything else is execution.
