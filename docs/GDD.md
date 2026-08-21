# Nice Little Earner — Game Design Document

*(working title until 2026-08-16: "Warehouse Manager" — see ADR 11)*

- **Version:** 0.9 — the Phase 1 gate: rack geometry ratified, pallets and buried-row access decided (ADR 24), and Phase 1 (Storage) closed
- **Date:** 2026-08-21
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
| 16 | ~~The storage grid module is 0.5 m~~ *(superseded by 18)* | `decisions/2026-08-17-storage-grid-module.md` |
| 17 | Settled cargo becomes solid; disturbed cargo wakes | `decisions/2026-08-17-settled-clutter-is-solid.md` |
| 18 | Storage cells bundle small cargo; a cell is atomic | `decisions/2026-08-17-storage-cells.md` |
| 19 | Solo drag is a hold mode, not a parallel system | `decisions/2026-08-19-solo-drag-is-a-hold-mode.md` |
| 20 | Detection and patch maths; reputation decays with the lease | `decisions/2026-08-19-detection-and-patch-maths.md` |
| 21 | Reputation expires with the run; the crew splits one pot | `decisions/2026-08-19-two-currencies-and-the-crew-split.md` |
| 22 | Orders are manifests; reputation is a market position | `decisions/2026-08-19-orders-are-manifests-reputation-is-a-market.md` |
| 23 | Early Access, not straight to 1.0 — same bar, two launch beats | `decisions/2026-08-20-early-access-launch.md` |
| 24 | Rack geometry ratified: pallets, buried rows, two speeds of shelf | `decisions/2026-08-21-rack-presentation-ratified.md` |

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

**End of lease** → scored on **profit and contract completion** → unlock currency → new maps, gear, client tiers.

> **Reputation is deliberately not in that list (ADR 21).** It gates contract quality and volume *within* a lease and then expires — it is an interest rate, not a score. It never pays you directly; it changes what you're offered next, so a five-star rating handed to you on the final morning is worth nothing. That decay is exactly what ADR 20 prices, and it's what makes gambling on the last night correct. If reputation also bought permanent unlocks it would never reach zero value, and the pillar's late-lease flip would quietly stop happening.

**Then the checkout.** Whatever's left after rent and crew costs is split by the **host, unilaterally** — no vote, no confirmation. It's the pillar at run scale: the game already says whoever holds the item decides alone, and a host deciding Teflon Vin gets five percent is the same joke one level up. **Two tiers of unlock** make that safe rather than savage:

| Tier | Earned by | Applies to |
|---|---|---|
| **Crew progression** — maps, gear, client tiers | Run profit and completion | The whole lobby, via the host |
| **Personal** — cosmetics, outfits, crew characters | Your individual cut | You alone |

A cut buys **cosmetics only**, so being handed five percent stings socially and costs you nothing mechanically. Run-affecting unlocks stay at the crew tier and apply to everyone, so a player who joins having unlocked nothing is never a liability.

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
            The day's contribution tally goes up (§6.8) — who delivered,
            who racked, who broke things, who got caught.
```

Days are short — target **6–10 minutes**. A 10-day lease is roughly a 90-minute session.

---

## 6. Systems (v1)

### 6.1 Goods

Every item carries:

| Property | Values |
|---|---|
| **Size class** | Small (0.5 m cube, one-handed, **8 fit a cell**) · Medium (1.0 m cube = **a whole cell**, two-handed, **occludes your view**) · Large (2.0 × 1.0 × 1.0 = **2 cells**, two-player carry or drag) — ADR 18. **Open question, raised at the Phase 1 gate:** which two cells a Large actually occupies — side-by-side across columns, or front-to-back through depth, which would be the one thing that puts a wall rack's dead row to use — is not yet decided. Answer it in Phase 2 planning. |
| **Value density** | What it earns per cell per day. Bricks are bulky and cheap; jewellery is compact and enormous. This is the portfolio decision across a lease. |
| **Fragility** | 0–3 (crated machinery → glassware) |
| **Store-until date** | The day it must leave. Also the spoilage deadline. |
| **Condition** | Pristine · Scuffed · Damaged · Destroyed |
| **Apparent condition** | What the customer sees. **Diverges from real condition when patched.** |
| **Client** | Who owns it. Determines who turns up angry. |

**Production note:** everything is a cardboard box. One crate mesh + swappable label/decal + size variants = dozens of distinct-feeling goods for almost no art budget. Spend the saved time on sound.

**The drag mechanic:** any item, any size, can be dragged along the floor by one player — slowly, noisily, with a scuff chance. This is the solo player's answer to Large cargo, and it is funny. Keep it bad but possible.

**Built, and it is a hold *mode* rather than a separate system** (ADR 19). `F` drags anything; anything too heavy for one person to lift is dragged whether or not you asked. The drag spring acts only on the floor plane, so gravity holds the crate down and nothing ever lifts it — which is what makes it catch on obstacles, and what makes racking impossible for a lone player, since the hold point follows your *body*, not where you are looking. **A mate grabbing the other end promotes a drag into a two-player carry**, and it drops back when they let go.

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

- Racks expose **cells**. Items **snap** in on insert — a travelled, tweened placement with a
  thud, not a physics-jittered drop. Storage is a clean spatial puzzle, unpolluted by physics
  jitter.
- **The storage unit is a cell: 1.0 m cubed** (ADR 18). Eight Smalls fill one, a Medium *is* one,
  a Large takes two. **A cell is atomic** — one kind of cargo at a time — so filling a cell with
  Smalls is efficient and spending it on a Medium is not. That trade is the packing decision,
  **challenged and upheld at the Phase 1 gate**: sorting is the job, and the mixed zones are
  Goods IN, the floor, and shed aftermath, not a rack.
- **Retrieval within a cell is last-in-first-out.** You take what's reachable. Badly-ordered stock
  is *physically painful* to get at, which is what turns FIFO discipline (§6.3) from a good habit
  into something the building enforces — unstacking six crates while a client waits.
- **A rack is 2 cells wide × 2 deep × 3 high = 12 cells:** 96 Smalls, or 12 Mediums, or 6 Larges.
  The top level sits at 2–3 m, so a solo player (floor level only) reaches the bottom row and
  nothing else — **confirmed in play at the Phase 1 gate**: the bottom row costs no fight with
  the camera, the top row needs no jump. The two rows are not equivalent by design: the top row
  costs a longer hold and turns a throw into something you have to actually mean, while the
  bottom row is a fast in-and-out. Store your fast movers low and your slow movers high.
- **Rack frame and cell presentation are ratified** (ADR 24, the Phase 1 gate). The frame — CSG
  decks and corner uprights — is kept exactly as built. What was missing was the cell's
  *contents*: an empty cell shows nothing, and the first item placed spawns a wooden pallet, with
  every item after it sitting on that pallet rather than floating at the cell's mathematical
  floor. Racked items carry a small seeded rotation and offset within the cell (seeded off the
  crate's own id plus its cell and slot, so every peer derives the identical pose without a
  network message), so a full cell reads as *packed* rather than *stamped*. The pallet's front
  edge is where per-cell signage will anchor (§6.3, Phase 2).
- **Placement decides whether stock gets buried.** A 2-deep rack against a wall has a buried back
  row — unaimable head-on, because the front row's own sensors block the ray. **Ratified at the
  gate:** that row is still reachable through the rack's *end* faces wherever the level exposes
  one, so a wall rack is 6 cells head-on plus whatever its ends expose, not a flat loss of half
  its capacity. The same rack built as an island, reachable from every side, has no buried row at
  all. Islands store better and eat aisle space; wall racks are compact and cost you a route to
  the back.
- Racks have **stability**. Hit one hard enough and the top row sheds — bounded, and **confirmed
  in play at the Phase 1 gate** to read as punishment, not ambient noise. A dragged crate can
  never carry enough speed to trigger it; only a thrown or two-player-carried crate can. A fuller
  version — a wobble telegraph, and a rare full topple that must never cascade to a neighbouring
  rack — is proposed, not built; see `docs/idea-book.md` ("The rack topple").
- **Floor stacking is allowed.** It's faster, it blocks pathing, it counts as clutter, and it's
  begging to be kicked over. A tempting shortcut with a real cost, **confirmed in play at the
  Phase 1 gate** — even once it genuinely blocks pathing (below), it stays worse than racking
  with no upside, which is exactly what makes it a *bad* idea rather than a dead one.
- **How the blocking works (ADR 17):** a crate that settles on the floor turns *static* and
  becomes solid — you walk around it like a wall. Shove it hard enough and it wakes back into a
  physics body and scatters. Cargo in transit stays dynamic and stays out of your way, so nothing
  you are carrying can be bulldozed. This is what makes "blocks pathing" real rather than
  aspirational.
- **The round-trip invariant.** Racking frees a crate's physics body outright; retrieving one
  mints a fresh body. Nothing about that trip is allowed to be lossy — every field a crate
  carries (today just its kind; condition, apparent condition, scuffs, fragility, store-until
  date, owner and value as later phases add them) rides the cell's own data as a record and comes
  back exactly as it went in. Get this wrong and racking quietly launders damage, which deletes
  P1. Named at the Phase 1 gate; tracked as STORE-07 in `.planning/REQUIREMENTS.md`. Returning a
  *different* crate of the same kind via LIFO is correct behaviour, not a violation of this.

> **Budget note (ADR 14).** Grid snapping is not only a feel decision — it is what makes the game affordable. Racked items can be static, non-simulated and non-replicated, so physics is reserved for cargo actually in transit. The measured ceiling is **~150 concurrent loose rigid bodies** across four peers, which sizes floor clutter, how much a rack may shed, and how many items a day can involve. Full-physics storage would have spent the entire budget on stock merely sitting there. See [`docs/physics-budget.md`](physics-budget.md).

### 6.3 The memory game

Over 30 days you'll handle dozens of items. When a client turns up for crate #7 of an order placed three weeks ago, **you have to find it**. FIFO discipline, zoning, and aisle signage stop being flavour and start being survival. This is P2 in action and it needs no extra content to be deep.

**Proposed for Phase 2, recommended at the Phase 1 gate:** per-cell signage on the loading face — a plaque reading e.g. "SUGAR 3/8", or "SUGAR 1/1" centred across a Large's two cells — derived locally from a cell's own contents and anchored on the pallet's front edge (§6.2, ADR 24). This is the concrete form "aisle signage" above has meant since the first draft; not built in v1.

### 6.4 Damage

Damage sources: drop height × fragility · collision velocity · rack collapse · being run into by a teammate · spoilage past the store-until date · working in the dark.

Each condition tier has an unmistakable **visual and audio tell** — a dented corner, a tear, a dark stain, and the single most important sound in the game: *the shift and tinkle of broken glass inside a sealed box*.

### 6.5 The dilemma (P1 — the core system)

At handover, for any item below Pristine, the player holding it chooses:

| Choice | Cash | Reputation | Risk |
|---|---|---|---|
| **Patch & ship** | Full | None *if undetected* | Detection → no pay, heavy rep hit, client suspicion permanently raised |
| **Confess** | 40% / 28% / 15% by tier | Small gain | Thin margins, rent still due. Scaled so being careful is worth something even when you intend to own up (ADR 20, amended) |
| **Comp a replacement** | Negative | Large gain | The replacement belonged to **another client**. The problem moves; it doesn't vanish. **Like-for-like only** (ADR 22), so comping is conditional on what the building actually contains |

**The tape gun** raises *apparent* condition by one tier per application. £15 and 12 seconds each — the seconds are the real cost, because the day clock is the pressure. Apparent ≠ actual. **New damage drags apparent back down**, so a patch is a gamble rather than a licence to keep dropping the thing.

**Detection is a weighted roll**, not a menu outcome — driven by patch quality, item value, and that client's accumulated suspicion. That's what makes it a gamble instead of a decision tree.

**The maths is settled (ADR 20).** Detection rises steeply with how many tiers you're hiding — 15% / 45% / 80% for one, two and three — plus up to 25 points for a valuable item and up to 30 for a suspicious client, never below 2% or above 95%. Getting caught raises that client's suspicion **permanently** by 0.25; confessing walks it back by 0.08, which makes owning up on something cheap a real tactic for buying back room to gamble later.

> **The mechanism that makes the fork a real decision:** reputation is priced in cash at **£90 per point per day of lease remaining**. It only pays out by gating future contracts, so it's worth a lot on day 1 of a 30-day term and nothing on the last night of a 10-day one. Early in a lease, comping is the strongest play. At the end, reputation is worthless and the right move is to tape it up and gamble. **Same item, same damage, opposite answer** — that's what stops the pillar becoming a decision tree with one correct branch.
>
> Verified rather than hoped: a unit sweep over value, damage depth, suspicion and days remaining requires all three forks to win somewhere and none to win more than 75%. On ordinary one-tier damage it lands at roughly a three-way split.

**Expected value is deliberately not the whole decision.** The maths prices the *average* outcome, and a player facing eviction tomorrow doesn't care about averages — they need the full fee tonight, and only the gamble produces it. Confessing is worth more on paper and loses the run. That gap is the drama, which is why **the odds are never shown to the player**.

> **Co-op rule: whoever is holding the item decides.** No vote, no confirmation from the group. The player who broke it can quietly patch and ship it before anyone notices. Do not gate this — the unilateral choice *is* the social engine.

### 6.5a Handover: the crate is the unit, the order is a manifest

**An order is a list, not an all-or-nothing transaction** (ADR 22). Each crate is handed over
individually and resolves on its own — delivered, patched, confessed or comped — and the order's
result is the **sum**, plus a **completion bonus** for a clean full delivery.

Part-fulfilment therefore needs no mechanism: it's what happens when you confess on one crate of
three. The cliff becomes a gradient, and finishing the order still matters because the bonus is real.

**You can hand over the wrong goods, and it's always spotted.** Water when they ordered food gets
noticed immediately, no roll. The game doesn't stop you being an idiot — that would be
paternalistic — but it doesn't pretend idiocy might work either. Concealment is the tape gun's job,
and one concealment axis is enough.

> **There is no softlock, and it's worth knowing why.** `Destroyed` is a condition, not deletion, so
> nothing removes cargo except handing it to a client — **supply is conserved**, and cargo that
> falls out of the world is recovered rather than freed. And **confessing is unconditional**: it
> needs no stock and no replacement. So `patch → comp → confess` always terminates, and a run always
> reaches an ending. Eviction is a valid ending; stuck is not.

### 6.6 Clients

A small named roster (4–6 in v1), each with a personality, a **trust** value and a **suspicion** value. Burn one and their contracts dry up. Keep one happy and they bring volume.

**Some of them are dodgy, and that's a personality rather than a system.** The high-value end of the roster is where the film piss-takes live — a Tony Montana knock-off shipping crates of "legitimate baby talcum powder", that sort of thing. Everyone knows what's in the box; nobody says it.

This needs **no contraband mechanic and no police**. It runs entirely on trust and suspicion: dodgy clients pay far above rate, their goods must not be damaged or examined, and the risk is **reputational with your legitimate clients**. Raids and law enforcement stay parked (§10) — the joke does the work, and it costs one line of dialogue rather than a new system.

**Reputation is a market position, not a score** (ADR 22). High and low aren't more and less of one
thing — they're different businesses:

| | **High rep** — the legit trade | **Low rep** — the unsavoury end |
|---|---|---|
| Pays | Rate. You're one of several warehouses | **Far above rate**, cash, no questions |
| Volume | Steady, predictable, plannable | Irregular |
| Inspection | Professional clients have procedures | Harder — goods must not be damaged *or examined* |
| Your history | Is the whole relationship | Irrelevant to them |
| Burning them costs | **Reputation** — contracts dry up, slowly | **Cash** — a penalty far exceeding the item, now |

**That symmetry is the design.** Legit clients punish you in reputation; dodgy ones punish you in
cash. The legit market is forgiving today and unforgiving across a run; the unsavoury market doesn't
care what you did last week and wants paying tonight.

Three things fall out of it. **Losing reputation stops being a death spiral** — it moves you
sideways into a rougher game that still pays, so the suspicion ratchet finally leads somewhere.
**Success is its own pressure**, because the reward for a good reputation is more work, and more
crates is more chances for a physics comedy to happen to you. And it **fixes an endgame hole in
ADR 20** — reputation decays to nothing by the final night, so reputation-shaped consequences stop
biting exactly when recklessness is most tempting, but *a cash consequence doesn't decay*.

It's a **continuum, not tiers** — reputation shifts the mix of work on offer rather than unlocking
bands at thresholds, because visible thresholds get played to. Climbing back is possible and
expensive: you have to turn down the best-paying work available and grind lower-margin legitimate
contracts. And you **can't sustain both ends at once**, which is what stops "take the dodgy money and
keep the good clients" being strictly optimal. The louder consequences (raids, cut power) are post-launch and are *earned* by burning clients, not rolled randomly.

### 6.7 Economy

**In:** storage fee **per cell per day** · on-time delivery bonus · condition bonus.

> **Fees price volume, not items — this is forced, not a preference (ADR 18).** With per-item fees, eight Smalls in a cell earn eight times what a Medium earns in the same space, Smalls become strictly dominant and the packing decision collapses.
>
> **Large cargo gets no size premium either.** For the same commodity, large and small pay the same per unit volume — a tonne of bricks is a tonne of bricks. The reward for handling Large is **fewer journeys**, which scales with how many players you have and vanishes when you're alone. A premium on top would let Large win on both axes and make Small cargo something you take only when nothing better is offered.
>
> What *does* vary the money is **value density by cargo type**, and it pays for itself twice: compact high-value goods earn more per cell **and make the dilemma hotter**, because dropping something precious turns patch-or-confess from a shrug into a crisis. Bulky cheap cargo is safe money that eats your warehouse.
**Out:** daily rent · tape and supplies · rack repairs.
**Fail:** can't make rent → evicted → run ends.

**Money is one company pot** (ADR 21). Rent is a shared fail state, so the money that pays it is shared — per-player wallets would make the run hostage to whoever's holding cash when they disconnect or decide to be difficult.

**Three axes, and two of them are easy to conflate:**

| | What it is | Scope | Gates |
|---|---|---|---|
| **Money** | Hard, spendable, immediate | The run | Rent, tape, repairs, gear. Running out ends the run |
| **Reputation** | Soft, expiring | The run | Contract quality and volume |
| **Client trust / suspicion** | Per client, permanent within a run | One client | Whether *that* client catches you patching (§6.5) |

Suspicion is **not** global reputation. Reputation decides what work you're offered; suspicion decides whether a specific client believes you.

### 6.8 The contribution tally

Alongside the pot, the game records what each player did — shown at each day's **CLOSE**, so the final split reads as a judgement rather than a robbery, without being a live HUD that gets optimised against.

**Its job is to be legible and arguable, not correct.** If attribution were fair and complete the split could be automatic; the only reason a human decides is that the numbers *can't* tell the whole story. So: **columns, never a total** — one net figure per player turns the host into someone reading a leaderboard and the judgement disappears. And it's **not zero-sum** — two players who carry a crate together both get full credit, not half each, because being generous on earns is what keeps people helping.

| Earns | Attributed to | | Costs | Attributed to |
|---|---|---|---|---|
| Handed over at Goods OUT | whoever handed it over | | Caught patching | whoever made the call |
| Racked into a cell | whoever placed it | | Damaged | last holder at the time |
| Signed for at Goods IN | whoever accepted it | | Tape used | whoever patched |
| Confessed | whoever confessed | | Rack knocked over | whoever hit it |

The first two earns are deliberately in tension: the gate-stander takes full credit for hauling someone else did, which manufactures the best grievance in the game — *"Vin stood at the door all day"* — and the racking column is the counterweight that proves it.

**Caught patching is the strongest rule here.** The dilemma is already unilateral, so its consequence must be too — that's Sid's line, not the crew's.

**Damage is named but never netted off.** It sits in its own column and the host weighs it. Attaching a cash value and subtracting it would make players afraid to touch the glassware, which fights P3 head-on: clumsiness is the comedy.

**Crew costs, pinned on nobody:** rent, racks and gear, and **late deliveries** — a crate nobody could find is a planning failure, and blaming it would need "who buried it three days ago", which is unprovable and would discredit the whole tally.

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

### Proposed, undecided
Ideas raised during development that are neither in scope nor parked — they have never been decided either way. They live in **[`docs/idea-book.md`](idea-book.md)** so they are neither lost nor quietly built: a named crew with specialties, and the sales counter (developed 2026-08-19, still parked). Same rule as the Out list — each needs its own ADR to enter v1.

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
