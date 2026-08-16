# Conversation Log

Session-by-session record of what was decided and why. Append new sessions at the top — never overwrite.

---

## Session 2 — 2026-08-16

**The netcode spine connects, the market gets checked, and the game gets its real name.**

### What was built

**GodotSteam 4.21 GDExtension vendored** (win64 only — 8.3MB, against 99MB for the upstream six-platform archive). It ships `SteamMultiplayerPeer` inside the same binary, so no second addon is needed. The full Steam Voice API turned out to be in there too, which changed a scope decision later the same session.

**Phase 0 netcode spine**, transport-agnostic behind a `NetTransport` abstraction:

- `ENetTransport` — development. Four instances on one machine.
- `SteamTransport` — shipping. `host_with_lobby` / `connect_to_lobby`.
- `Net` autoload owning session lifecycle, roster, and the spawn handshake.
- First-person `Player` with client-authoritative movement and puppet smoothing.
- `TestRoom` greybox with host-driven spawning via `MultiplayerSpawner`.

**Verified, not assumed.** Two headless processes connected over real networking, agreed on both peer IDs, spawned matching bodies at distinct spawn points, and exited clean with zero errors or warnings. Testing found a genuine teardown bug — player bodies querying authority for a frame after the peer was gone — which was fixed and re-verified.

### Decisions made

Five ADRs (see `decisions/decision-log.md`):

| Decision | Short reasoning |
|---|---|
| Client-authoritative capsule | Input prediction with reconciliation is weeks of work whose payoff is cheat resistance. Four friends in PvE have nothing to cheat for, and building it would have made the reconciliation layer the Phase 0 gate instead of the handoff feel. Partly supersedes ADR 5. |
| ENet for dev, Steam for ship | Steam allows one client per machine, so a Steam-only test caps at two players and could never exercise the four-player races the gate exists to catch. |
| Proximity voice chat into v1 | Partly supersedes ADR 6. The acquisition channel is short-form video and a physics-comedy clip with no voices is not a clip. Cost collapsed once the Steam Voice API was found in the build already vendored. Lands in Phase 6. |
| Launch price £9.99 / $11.99 | Comparable data splits the field into a cheap chaos cluster and a £16.75 sim shelf with almost nothing between. A four-player game's real price is 4×, and sim pricing is underwritten by solo depth this game has chosen not to build. |
| **Renamed to `Nice Little Earner`** | "Warehouse Manager" collided with an existing Steam title, promised the sim shelf the price ADR rejected, and named the setting rather than the tone. |

### Research

Steam storefront and review data pulled for 26 comparable titles. Full report published as an artifact with the reference art board.

- **"The lane is open" is no longer true.** Three warehouse titles now exist; `Pack and Ship` ships in 2026 with co-op and physics. But all of them are earnest optimisation sims — none has a dilemma, none is trying to be funny. The setting was never the moat.
- **Moving Out 2 is the cautionary tale.** The closest mechanical relative that has ever shipped — co-op, physics, carrying awkward objects with friends — has 616 lifetime reviews at 75%, against R.E.P.O.'s 417,685 at 96%. Of the five dimensions separating them, four already match the winner: first-person, run-based, persistent stakes, cheap art. The fifth was voice chat, now fixed.
- **Naming.** Roughly sixty candidates collision-checked across four registers. Runners-up: `Sold As Is`, `Chancers`, `No Warranty`. `No Questions Asked` was the best conceptual match and is already taken.

### Open questions

- **Sales counter** — proposal to let players sell the cargo they are meant to be storing, and short-change depositors at intake. Strong idea that converges with the new name, but half of it (bartering at the door) is on the parked list and the other half is new scope. Recommended framing is *borrowing, not stealing*: cash now, certain reckoning on collection day, so it manufactures more damage dilemmas rather than replacing them. Needs an ADR before anything is built.
- **Early Access or 1.0** — leaning EA, undecided. Needs settling before a store page, not before Phase 1.
- **Detection and patch-quality maths** — still the thinnest part of the design. The dilemma only works if the right answer changes with your situation; if patching dominates on average, the pillar collapses into a button. Solvable as a spreadsheet before Phase 3.
- **Trademark search** on the new name, outstanding.
- **Folder and remote renames** — the game is renamed but `warehouse-manager/`, the outer project folder and the GitHub remote still carry the old name. Renaming the Godot folder requires updating `.git/info/exclude` in the same move, or the MCP addon silently becomes trackable in a public repo.

### Foundations raised

Four engineering foundations identified as prerequisites for a project of this size. Detail lives in the local development notes; each becomes a skill, ADR or tracked doc as it is worked through.

1. **A test harness that is bombproof.** The risky parts here — networked physics, handoff, authority — are the parts unit tests are worst at, so the integration layer matters more than the unit layer. The paired headless run used to verify the spine is the seed of it; it needs to become one command, deterministic, wired into the pre-push path. A flaky netcode test is worse than none.
2. **Get GSD running.** Blocked on one decision first: this project already has a roadmap (GDD §13, Phases 0–7) and eleven ADRs as its source of truth. Decide whether GSD wraps that or replaces it — two competing roadmaps would be worse than neither.
3. **Naming conventions and structure, agreed once and enforced.** Code style is covered by the GDScript standards skill. The *folder layout* was invented during Phase 0 and never ratified. **This has a deadline:** moving files rewrites `.tscn` paths and UIDs, which is cheap at six files and expensive once Phase 1 adds racks and zones. Settle it before Phase 1.
4. **Accuracy — check, never assume.** Verify with tools rather than recall; state what was actually checked; distinguish verified from inferred; treat `decisions/` as the source of truth and check `decision-log.md` for supersessions first.

### Housekeeping

Git hooks installed to enforce the publishing rules automatically — `pre-commit` blocks staged filenames, text contents and stray editor temp files; `commit-msg` blocks the message, which `pre-commit` cannot see. Verified against seven cases including binaries. They live in `.git/`, so they are machine-local by design and need reinstalling on a fresh clone: a tracked file listing the blocked terms would itself be the leak it prevents.

### Next steps

Finish Phase 0: the physics crate, pick up / drop / hand off, two-player carry. Then a **physics budget stress test** — how many rigid bodies survive across four networked clients — because that number silently constrains floor clutter, rack shedding and how many items a day can involve. Then the two-machine Steam validation run, which is the first test of the shipping transport.

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
