# Nice Little Earner

**1–4 players run a leased warehouse. Take goods in, store them, get them back out on time and undamaged. You will fail at the third one — and then you have to decide whether to tell the customer.**

A first-person co-op physics comedy about logistics, clumsiness, and quiet fraud. Cardboard, expiry dates, wobbling racks, and a tape gun you use to hide your crimes.

> *Overcooked's panic, R.E.P.O.'s breakables, and a moral choice at the loading door.*

---

## The hook

Damage isn't a fail state — it's a **fork**. When a client turns up for the crate you just dropped, whoever is holding it decides, alone, with no group vote:

| Choice | Cash | Reputation | Risk |
|---|---|---|---|
| **Patch & ship** | Full | None *if undetected* | Detection → no pay, heavy rep hit, permanent suspicion |
| **Confess** | 40 / 28 / 15% by damage | Small gain | Thin margins, rent still due |
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
docs/project-structure.md  Where files go and what things are called
docs/physics-budget.md     Measured limits — how many rigid bodies, and why
docs/idea-book.md          Developed ideas that are deliberately not in scope
docs/art-pipeline.md       Art production — build vs generate, tooling, asset register
docs/conversation-log.md   Session-by-session record of decisions and progress
decisions/                 Architecture Decision Records (append-only)
  decision-log.md          Index — start here
tools/run-tests.ps1        The whole test suite, one command
warehouse-manager/         The Godot project
```

**`decisions/` is the source of truth.** ADRs win over the GDD and over this README until superseded. Changing course means writing a *new* ADR, not editing an old one.

## Status

**Phase 0 complete except the Steam join. Phase 1 — storage — is next.**

Godot 4.6, Forward+, Jolt. The multiplayer spine is built and proven by an automated suite rather than by hand: two real processes over real networking agree on the roster, spawn matching bodies, and carry, hand off, drag and release a physics crate with both sides agreeing throughout.

**Held cargo is force-driven and never parented.** A held crate stays an awake rigid body pulled toward a hold point by a spring — so it collides with the world for real, sags under its own weight, and renders its own network latency as *weight* rather than as error. Throwing fell out of that for free: swing and release lobs a crate, and there is no throw button, animation or code.

**Solo drag** hauls anything along the floor at 40% speed. Its spring acts only on the floor plane, so nothing lifts the crate — which makes it catch on obstacles for free, and means a lone player physically cannot reach a high rack slot. A second player grabbing the other end promotes the drag into a carry.

Transport sits behind a `NetTransport` abstraction. Development runs on **ENet**, because four instances on one machine is the only way to test four players — Steam permits one client per PC. **Steam P2P** via GodotSteam is written and vendored; the host half works and the join half is pending a two-machine run.

### Testing

`./tools/run-tests.ps1` — one command, about three seconds, and it runs on every push.

| Layer | What it proves |
|---|---|
| `api` | The engine and addon assumptions the project is built on still hold |
| `unit` | The condition model and the dilemma maths, including *no dominant strategy* as an assertion |
| `smoke` | Every scene loads **and instances** |
| `integration` | Two real processes over real networking, driving the real keypress path |

Weighted toward integration deliberately: host authority and held-item handoff are exactly what unit tests cannot reach. It has caught several bugs that reasoning did not, including a two-player carry that a client's HUD would have reported as carrying alone.

See [§13 of the GDD](docs/GDD.md) for the full build order.

## v1 scope

**In:** goods in → grid-snapped storage → goods out · physics carry, two-player carry, drag · drop and collision damage · condition tiers · tape gun and the dilemma · client trust and suspicion · rent clock and eviction · one map · 10 and 30-day terms · 1–4 co-op · proximity voice chat · solo playable.

**Parked:** forklift · layout build mode · cleaning and mess · blackouts and police raids · price bartering · 90-day term · extra maps · upgrade trees.

**Price:** £9.99 / $11.99 at launch, with a launch-week discount.

Anything moving from *parked* to *in* requires a superseding ADR — see [`decisions/2026-08-16-lean-v1-scope.md`](decisions/2026-08-16-lean-v1-scope.md).
