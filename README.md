# Warehouse Manager

**1–4 players run a leased warehouse. Take goods in, store them, get them back out on time and undamaged. You will fail at the third one — and then you have to decide whether to tell the customer.**

A first-person co-op physics comedy about logistics, clumsiness, and quiet fraud. Cardboard, expiry dates, wobbling racks, and a tape gun you use to hide your crimes.

> *Overcooked's panic, R.E.P.O.'s breakables, and a moral choice at the loading door.*

---

## The hook

Damage isn't a fail state — it's a **fork**. When a client turns up for the crate you just dropped, whoever is holding it decides, alone, with no group vote:

| Choice | Cash | Reputation | Risk |
|---|---|---|---|
| **Patch & ship** | Full | None *if undetected* | Detection → no pay, heavy rep hit, permanent suspicion |
| **Confess** | ~40% | Small gain | Thin margins, rent still due |
| **Comp a replacement** | Negative | Large gain | The replacement belonged to *another client* |

Detection is a weighted roll, not a menu outcome. The player who broke it can quietly tape it up and ship it before anyone else notices — that unilateral choice is the social engine of the whole game.

## The Lease Run

Pick a map, pick a term, commit. **Rent is the clock** — miss it and you're evicted.

- **10 days** — a sprint. No runway to invest. Pure execution. One session.
- **30 days** — the core game. Room to build, and reputation starts compounding.
- **90 days** *(post-launch)* — endurance. Spoilage, wear and burnt clients compound viciously.

Variety comes from **constraints**, not assets: cold storage bleeds money on refrigeration, a cramped city depot means more collisions, a derelict hangar has unreliable power.

## Pillars

1. **The dilemma is the game** — Cash vs Reputation is the spine, not a side system.
2. **Order under pressure** — storage is deliberate, plannable and memorable. Chaos threatens it; it never replaces it.
3. **Clumsiness is the comedy** — physical incompetence, not written jokes.
4. **Small, deep, replayable** — one warehouse done properly beats five done thinly.

---

## Tech

| | |
|---|---|
| Engine | Godot 4.6 |
| Physics | Jolt |
| Networking | Steam P2P (GodotSteam), host-authoritative |
| Players | 1–4 online co-op. Solo playable, deliberately punishing. |
| Perspective | First-person |

## Repo layout

```
docs/GDD.md                Design document — pitch, systems, scope, build order
docs/conversation-log.md   Session-by-session record of decisions and progress
decisions/                 Architecture Decision Records (append-only)
  decision-log.md          Index — start here
warehouse-manager/         The Godot project
```

**`decisions/` is the source of truth.** ADRs win over the GDD and over this README until superseded. Changing course means writing a *new* ADR, not editing an old one.

## Status

**Design complete. Godot project scaffolded — no gameplay code yet.**

The project is on Godot 4.6 with Forward+ rendering and the Jolt physics backend, matching the engine ADR. Nothing else is built.

Next milestone is **Phase 0: the netcode spine** — four players, an empty room, one physics crate, pick up / drop / hand off / two-player carry. Nothing else. This is a project gate: if it isn't rock solid, the project stops there rather than building on a broken foundation.

See [§12 of the GDD](docs/GDD.md) for the full build order.

## v1 scope

**In:** goods in → grid-snapped storage → goods out · physics carry, two-player carry, drag · drop and collision damage · condition tiers · tape gun and the dilemma · client trust and suspicion · rent clock and eviction · one map · 10 and 30-day terms · 1–4 co-op · solo playable.

**Parked:** forklift · layout build mode · cleaning and mess · blackouts and police raids · price bartering · 90-day term · extra maps · upgrade trees · proximity voice chat.

Anything moving from *parked* to *in* requires a superseding ADR — see [`decisions/2026-08-16-lean-v1-scope.md`](decisions/2026-08-16-lean-v1-scope.md).
