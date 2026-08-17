# Nice Little Earner — Game Design Document

*(working title until 2026-08-16: "Warehouse Manager" — see ADR 11)*

- **Version:** 0.4 — held items are force-driven rather than parented (ADR 13); project structure ratified (ADR 12)
- **Date:** 2026-08-17
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
| 7 | Client owns its capsule, host owns everything else | `decisions/2026-08-16-client-authoritative-character.md` |
| 8 | ENet for development, Steam P2P for shipping | `decisions/2026-08-16-enet-development-transport.md` |
| 9 | Proximity voice chat is in v1 | `decisions/2026-08-16-proximity-voice-in-v1.md` |
| 10 | Launch price £9.99 / $11.99 | `decisions/2026-08-16-launch-price.md` |
| 11 | The game is called Nice Little Earner | `decisions/2026-08-16-game-name.md` |
| 12 | Project structure, file layout and naming | `decisions/2026-08-17-project-structure.md` |
| 13 | Held items are force-driven, not parented | `decisions/2026-08-17-springy-held-item-grab.md` |
| 14 | Physics body budget of 150; cargo replicates at 20 Hz | `decisions/2026-08-17-physics-budget.md` |
| 15 | Planning tool wraps the build order, never replaces it | `decisions/2026-08-17-gsd-wraps-the-build-order.md` |
| 16 | The storage grid module is 0.5 m | `decisions/2026-08-17-storage-grid-module.md` |
| 17 | Settled cargo becomes solid; disturbed cargo wakes | `decisions/2026-08-17-settled-clutter-is-solid.md` |

ADRs 7 and 9 supersede parts of ADRs 5 and 6 respectively, and ADR 13 supersedes the held-item clause of ADR 5. Check `decisions/decision-log.md` for current status before relying on any of them.

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
- **One slot is 0.5 m** (ADR 16). Small = 1 slot, Medium = 2 (1.0 × 0.5), Large = 4 (1.0 × 1.0). A rack bay four slots wide is 2.0 m. Every grid-critical asset is modelled to this exactly — see the art pipeline.
- Racks have **stability**. Hit one hard enough and it wobbles; the top row may shed. Chaos is a *punishment for recklessness*, not ambient noise.
- **Floor stacking is allowed.** It's faster, it blocks pathing, it counts as clutter, and it's begging to be kicked over. A tempting shortcut with a real cost.
- **How the blocking works (ADR 17):** a crate that settles on the floor turns *static* and becomes solid — you walk around it like a wall. Shove it hard enough and it wakes back into a physics body and scatters. Cargo in transit stays dynamic and stays out of your way, so nothing you are carrying can be bulldozed. This is what makes "blocks pathing" real rather than aspirational.

> **Budget note (ADR 14).** Grid snapping is not only a feel decision — it is what makes the game affordable. Racked items can be static, non-simulated and non-replicated, so physics is reserved for cargo actually in transit. The measured ceiling is **~150 concurrent loose rigid bodies** across four peers, which sizes floor clutter, how much a rack may shed, and how many items a day can involve. Full-physics storage would have spent the entire budget on stock merely sitting there. See [`docs/physics-budget.md`](physics-budget.md).

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

- **Host-authoritative over everything that isn't a player.** The host simulates every rigid body, owns every held-item state, and decides every pick up, drop and hand off.
- **Each client owns its own capsule.** It simulates its own movement locally — no prediction, no reconciliation — and replicates the result for other peers to ease toward. Movement is zero-latency for everyone; anything you *touch* costs one round trip. (ADR 7 — this replaces the earlier input-prediction plan.)
- **Held items are force-driven, never parented.** A held crate stays an awake rigid body simulated by the host, pulled toward a hold point in front of the holder by a spring and released if dragged too far. It collides with the world for real — that's where the comedy and the damage data both come from — and it sags under its own weight, which tells you how heavy it is without a UI element. Two holders means two hold points and the crate tracks their midpoint. (ADR 13 — this replaces the earlier parenting plan.)
  - **Throwing came free.** Confirmed in the first playable test: a held crate keeps its momentum, so swinging and releasing throws it, and swinging harder throws it further. No throw button, no throw animation, no throw code — it falls out of the crate being a real rigid body. A parented crate could not do this at all. Phase 3's damage model reads those release velocities without extra work.
- **Steam P2P lobbies** via GodotSteam — no servers to run, no infrastructure cost. Development runs on ENet so four instances can be tested on one machine; Steam allows only one client per PC (ADR 8).
- **Proximity voice chat**, 3D-positioned and distance-attenuated, via Steam Voice (ADR 9).
- **Late join:** v1 allows joining between days only. Mid-day drop-in is a post-launch problem.
- **No host migration.** If the host drops, the run ends.
- 1–4 players.

**This is built first.** Retrofitting multiplayer onto a finished physics game is where projects like this die.

---

## 8. Solo play

Playable, punishing, clearly not the intended experience — the Lethal Company posture. Quotas and rent scale down with player count, but not enough to make it comfortable. Large cargo is drag-only. Marketing is honest that this is a co-op game.

---

## 9. Art & audio direction

**Visual:** low-poly, flat and gradient textures, near-zero texture work. Chunky proportions. Derpy humanoids — oversized hands, no fingers, simple rig, a walk cycle with too much bounce. Industrial grey and beige, punctuated by high-vis orange and yellow so gameplay-critical things read instantly. Cardboard is the hero material.

**Audio does the heavy lifting.** Cardboard scrape on concrete. The groan of a loaded rack. Tape screech. Forklift beep. And the glass tinkle — the sound that turns a small mistake into a decision.

**Lighting is a gameplay system, not a mood.** Hard fluorescent strips overhead, aisles lit as bright lanes separated by shadow. This is cheap to build and it serves P2 directly: you navigate by pools of light, which is the mental map the memory game wants you to form.

**Voice is part of the mix, not on top of it.** Proximity chat ships in v1 (ADR 9) and the bus is designed around it — voice ducks against crate and rack sounds rather than drowning them, because both are carrying the comedy. The pillar depends on it: a lie is only dramatic if the others can hear it being told, or hear the pause where the truth should have been.

---

## 10. v1 scope

### In
Goods in → grid-snapped storage → goods out · physics carry, two-player carry, drag · drop and collision damage · condition tiers · tape gun, patch / confess / comp · client trust & suspicion · rent clock, eviction fail state · one map · 10 and 30-day lease terms · 1–4 co-op over Steam P2P · **proximity voice chat** · solo playable.

### Out (parked, not cancelled)
Forklift · layout build mode · cleaning & mess system · blackout and police-raid events · price bartering at the door · 90-day term · additional maps · upgrade trees.

> **Proximity voice chat moved from Out to In** — see ADR 9. It was already flagged as the first feature back, and two things settled it: the acquisition channel for this game is short-form video, and a physics-comedy clip with no voices in it is not a clip; and the Steam Voice API turned out to already be in the GodotSteam build the project now carries, so it costs integration time rather than a new dependency.
>
> **This is the exception, not the precedent.** Everything remaining on the Out list still needs its own superseding ADR. The guardrail is now more important, not less — one door opening is the moment the others start being pushed.

---

## 11. Positioning & price

### What this game is not sold on

**The warehouse is not the hook.** As of August 2026 three warehouse titles exist on Steam — one dead on arrival, one single-player, and one (*Pack and Ship*, 2026) a co-op physics logistics sim with forklifts, contracts and layout optimisation. The setting is being colonised, and it was always the weakest claim available.

Every one of those competitors is an **earnest optimisation sim**. Not one has a moral dilemma, and not one is trying to be funny. That gap is the position.

### The name does the first half of the job

**Nice Little Earner** (ADR 11) states the crew's motive before a single mechanic is explained: *we are here for the money and we are not fussy how*. It commits the game to a **character-led** identity rather than the deadpan-institutional register the genre defaults to — the joke is who you are, not what the paperwork says.

That raises the floor on tone. A game with this name has to actually be funny, and it will be judged against that promise. Flat, earnest execution reads worse under this title than under a neutral one.

### The line

> **A co-op game where the person holding the broken thing decides whether to lie about it.**

That is the pitch, and it leads everywhere: store page, trailer, capsule text, and the first thirty seconds of play. P1 was already the pillar; this section commits to it being the *marketing* too. A player should hit their first patch-or-confess fork inside the first session, not in hour two.

### Price

**£9.99 / $11.99, with a 10% launch-week discount** (ADR 10). Deliberately in the cheap co-op cluster rather than the £16.75 sim shelf, because a four-player game's real price is four times its listed one, and because sim-lane pricing is underwritten by solo depth this game has openly chosen not to build.

### Comparable set

| Game | Price | Reviews | Why it matters |
|---|---|---|---|
| R.E.P.O. | £7.99 | 418k | The build target. Physics cargo, first person, proximity voice. |
| Lethal Company | £8.50 | 510k | Cheapest art on the shelf, best-selling game on it. Darkness does the work of detail. |
| PEAK | £3.19 | 352k | Flat-shaded low-poly reads as style, not budget, when the palette is disciplined. |
| Schedule I | £16.75 | 313k | The sim lane's one breakout — and it went viral on the same streamer mechanics. |
| Supermarket Simulator | £16.75 | 84k | The subject-matter reference: shelving, stock, aisles, labels. |
| **Moving Out 2** | £6.24 | **616** | **The warning.** Co-op physics, carrying awkward objects with friends — and it failed. |

*Review counts are lifetime and a proxy for sales, not a measure of them.*

### The Moving Out 2 lesson

The closest mechanical relative this game has sold almost nothing. The differences are instructive, and four of the five are already locked in our favour: it was top-down where we are first person, level-based where we are run-based, score-resetting where we have persistent rent, and silent where we now have voice. **A top-down camera lets you watch the chaos. A first-person camera puts you inside it.** ADR 1 is independently confirmed by every breakout in this genre.

---

## 12. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Networked physics eats the schedule | **Critical** | Host-authoritative by design. Build it in Phase 0 and stop the project if it isn't solid. |
| Falling between the two price/design lanes | **High** | Present as chaos-first, sim-underneath. Price in the cheap cluster. The dilemma must be legible in the first session. |
| Physics jitter ruins precise storage | High | Grid-snap on insert. Physics only in transit. |
| Scope creep from the parked fun list | High | ADR 6 is the guardrail. Anything from the Out list needs a superseding ADR — ADR 9 is the exception, not the precedent. |
| Genre saturation — "another Lethal Company clone" | High | Saturation is measurably above the Steam average. The 2025–26 breakouts all cleared it by pushing somewhere unexpected. The dilemma is that direction; spooky scavenging is not. |
| A competitor ships the warehouse first | Medium | *Pack and Ship* is due 2026. It is an optimisation sim with no comedy and no dilemma — different game, same shelf. Avoid its realistic art direction so the two don't get filed together. |
| Solo play is boring | Medium | Accepted and stated up front. Co-op-first is the honest position. |

---

## 13. Build order

| Phase | Goal | Gate |
|---|---|---|
| **0** | **Netcode spine.** 4 players, an empty room, one physics crate. Pick up, drop, hand off, two-player carry. Nothing else. | *If this isn't rock solid, the project stops here.* |
| 1 | Racks, grid snap, Goods IN / Goods OUT zones | Storage feels deliberate |
| 2 | Goods, size classes, expiry, collection day, day clock | The loop closes |
| 3 | Damage, condition tiers, tape gun, patch / confess / comp | **The pillar works or the game doesn't** |
| 4 | Clients, trust, suspicion, economy, rent, eviction | A run can be lost |
| 5 | Lease Run wrapper, scoring, unlocks | A run can be won |
| 6 | Art pass, audio, **proximity voice chat**, juice | It's a game, not a prototype — and it can clip itself |
| 7 | Solo tuning, balance, playtest | Shippable |

Phases 0 and 3 are the two that decide whether this game exists. Everything else is execution.
