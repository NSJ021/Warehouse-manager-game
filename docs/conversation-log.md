# Conversation Log

Session-by-session record of what was decided and why. Append new sessions at the top — never overwrite.

---

## Session 1 — 2026-08-16

**From a loose concept to a merged design foundation and a scaffolded project.**

### What was discussed

Opened with the raw pitch: a goofy logistics game where players accept, store and dispatch goods with expiry dates, physics damage, and the option to patch up a broken box and hope the customer doesn't notice. Comparables identified as R.E.P.O. (co-op physics, fragile cargo), PlateUp! (fixed shell, player-built layout, run-based replay) and Schedule I / Lethal Company (cheap low-poly art, quota pressure, solo-dev scale). None of them is a warehouse game — the lane is open.

### Decisions made

Six ADRs written and merged (see `decisions/decision-log.md`):

| Decision | Short reasoning |
|---|---|
| First-person camera | Narrow aisles between tall racks are hostile to a third-person camera; lowest art cost; best for the spatial-memory pillar. Every successful game in this cohort is FP. |
| Godot 4.6 + Jolt + Steam P2P | Matches the existing toolchain; plain-text scenes and scripts stay reviewable; no servers to run. |
| The Lease Run | Pick a map and a term (10/30 days in v1). Rent is the daily clock, eviction is the fail state. A run on the outside, a campaign on the inside. |
| Grid-snapped storage, physics transport | Resolves the tension between careful organisation and physics slapstick without simulating arbitrary shapes settling into shelving. |
| Host-authoritative networking | Proven architecture for the genre. Built in Phase 0 as a project gate. |
| Lean v1 scope | Forklift, build mode, cleaning, blackouts, raids and bartering parked behind a superseding-ADR guardrail. |

**The reframe that shaped everything:** the hook isn't the warehouse, it's the *dilemma*. Every damaged item forks into patch-and-hope, confess, or comp a replacement — a Cash vs Reputation trade with detection as a weighted roll rather than a menu outcome. In co-op it becomes a social mechanic, so **whoever holds the item decides unilaterally**, with no group vote. That is the pillar.

**Design calls made inside Lean scope:**

- **Drag mechanic** — any item draggable by one player: slow, noisy, scuff chance. Solves solo play for Large cargo and is funny.
- **Two-player carry is optional, never required.** Full speed, no scuffing, and — the real incentive — it can rack at *any* height. A lone player dragging a Large crate can only leave it at floor level: clutter, blocks pathing, one bump from disaster. Teamwork becomes the efficient choice without solo ever being blocked. This also de-risks Phase 0, since contested two-client authority needn't be perfect before moving on.
- **Floor stacking allowed** — faster, blocks pathing, counts as clutter, easy to kick over.
- **One crate mesh + swappable label decals** for dozens of distinct goods at near-zero art cost. Spend the saving on audio — the glass tinkle inside a sealed box you just dropped is the highest-value asset in the game.
- **Days target 6–10 minutes**, so a 10-day lease is roughly a 90-minute co-op session. Everything else balances against that.

### Progress

- `docs/GDD.md` written — pitch, four pillars, the Lease Run, day loop, all v1 systems, scope in/out, risks, build order.
- Six ADRs + `decision-log.md` index established as the project's source of truth, append-only.
- Repo created, `README.md` written, `.gitignore` covering Godot exports and secrets.
- Merged to `main` via PR #1.
- Godot project scaffolded at `warehouse-manager/` — 4.6, Forward+, Jolt physics backend.

### Open questions

- Detection weighting and patch quality in the dilemma system still need real numbers before they're implementable. Currently the thinnest part of the GDD.
- Balance passes for the 10-day and 30-day economies are untouched — each term is effectively a distinct economy.

### Next steps

**Phase 0: the netcode spine.** Four players, an empty room, one physics crate, pick up / drop / hand off / two-player carry, host-authoritative over Steam P2P. No racks, no goods, no clients. It's a project gate — if the handoff doesn't feel right, no amount of content saves it.
