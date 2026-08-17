# Conversation Log

Session-by-session record of what was decided and why. Append new sessions at the top — never overwrite.

---

## Session 3 — 2026-08-17

**Phase 0 finishes and gets proven rather than asserted. Five ADRs, a test harness that immediately caught its own author, and a physics budget that changed a design decision's status.**

### Foundations closed

Three of the four foundations raised at the end of Session 2 are done.

**Structure ratified (ADR 12).** Split `scenes/` + `scripts/` trees kept, subfolders are *domains* rather than node types — deliberately deviating from the shared conventions, because an `entities/` folder holding the capsule, the crate, the rack and the dock door tells you nothing. `levels/` split from `world/`, and `test_room` moved so the only level in the project stopped violating the convention it establishes. The rule most likely to be broken by accident got written down: **node names are protocol**, since `player.gd` derives authority from `name.to_int()` and renaming one fails on remote peers only, silently.

**A test harness that is actually bombproof (foundation #1).** `./tools/run-tests.ps1`, about a second, gating every push. Two layers: smoke loads *and instances* every scene and checks declared dependencies resolve; integration runs two real processes over real ENet asserting grab → two-player carry → handoff → release. Weighted towards integration on purpose — host authority and held-item handoff are exactly what unit tests cannot reach.

It paid for itself three times before it was finished. It **verified two-player carry and handoff**, which no human had tested. It caught that `holder_count()` was host-only, so a client's HUD would have called a two-player carry "carrying alone". And when the gate was tested by planting a broken scene, the smoke layer reported PASS on it — Godot loads and instances a scene with a missing script quite happily — so smoke now parses each `.tscn` and asserts every declared path resolves.

**The planning tool adopted as a wrapper (ADR 15).** The decision was made before the first command rather than after: its roadmap mirrors GDD §13 exactly, changes go to the GDD first, and ADRs win over anything in `.planning/` including anything an agent writes there. Running its own new-project flow would have generated a second roadmap next to §13, and two roadmaps do not stay in agreement — one quietly becomes real and the other becomes a lie that still gets read.

### Decisions made

| ADR | Decision | Short reasoning |
|---|---|---|
| 12 | Project structure and naming | Deciding late is expensive: `.uid` sidecars mean a stale path still resolves, so a botched move is silent rather than loud |
| 13 | **Held items are force-driven, not parented** | Supersedes ADR 5's parenting clause |
| 14 | Physics budget of 150; cargo replicates at 20 Hz on change | Measured, not guessed |
| 15 | Planning tool wraps the build order | Never two roadmaps |
| 16 | The storage grid module is 0.5 m | Blocks both storage and art until fixed |

**ADR 13 is the one that shaped the session.** Parenting a held crate was rejected for three reasons that only became visible once the spine existed: it suppresses the clumsiness pillar; it renders the round trip as a *visible fault* rather than as weight, because the holder's capsule is client-authoritative so the hand position is always one RTT stale; and it starves Phase 3's damage model of the collision data it runs on. A spring lags by design, so the same staleness reads as mass.

It was right. **Throwing came free** — swing and release lobs a crate, harder swing throws it further, with no throw button, animation or code. A parented crate could not do that at all, which makes it a mechanic that any future change to freezing or reparenting would silently delete.

### What was built

The physics crate, the carry referee, host-authoritative shoving, on-screen controls, the test harness, the stress harness, and an exported Windows build.

**Three bugs worth remembering, all found by measurement rather than reasoning:**

*Shoving was asymmetric and nobody would have guessed which way.* A puppet capsule has its position written rather than simulated, so the solver resolved overlaps with unlimited force: every remote player was an unstoppable bulldozer (3.39 m of launch) while the host was simply blocked by its own cargo (0.01 m). Fixed by taking players off the cargo mask entirely and having the host apply one clamped force for everyone.

*Sprint clipping and absurd throws were the same bug, and it was arithmetic.* A damped spring's steady-state lag is `damping × velocity / stiffness` — about 0.9 m at a sprint — so with a 1.1 m reach the crate settled inside the holder's head, and all that stored displacement became release velocity. The hold target is now aimed ahead by exactly the predicted lag.

*The grab ray hit the crate you were already holding*, so you could never aim past your own cargo. Harmless while E just drops it; fatal in Phase 1 where a rack slot has to be aimed at with a crate in hand.

### The physics budget, and what it changed

Measured across four peers in two modes. **Design for ~150 concurrent loose rigid bodies.**

The solver was never the constraint — 800 bodies with sleeping disabled cost 4.8 ms of a 16.67 ms tick. **Bandwidth nearly was**: 100 crates was pushing 1497 kb/s, roughly 12 Mbit/s upstream *for a warehouse where nothing was happening*, because cargo replicated every property every network frame. On a P2P host that is a player's home connection acting as the server, and it would have surfaced late as "unplayable at my mate's house". Moving to on-change at 20 Hz took it to 93 kb/s — 16×.

The real ceiling is client per-frame cost, and the shape of it is the finding: **identical whether crates move or sleep.** It costs what it costs for bodies to *exist*. Sleeping saves the host and saves a client nothing.

**This promoted ADR 4 from a feel decision to a performance-critical one.** Grid-snapped storage lets racked items be static and unreplicated; full-physics storage would have spent the entire budget on stock merely sitting there.

Two traps recorded: past the budget replication **degrades silently** — host traffic *falls* as crate count rises while crates lag on clients — and Jolt does not populate `PHYSICS_3D_ACTIVE_OBJECTS` or `COLLISION_PAIRS`, verified by them reading zero while 100 crates were visibly falling.

### Steam

The transport had never been executed. It has now been, and the **host half works**: an exported build initialises the API, creates a lobby and binds the peer. Every GodotSteam call was checked against the shipped extension first, because a wrong signature fails on line one and would have wasted a trip to the second machine. Only the **join** half remains, and it is the only thing that needs a second PC.

Two things became launch flags rather than code, since re-exporting for another machine is the expensive step: `--lobby=` (the default friends-only lobby needs both accounts to be friends, and a new Steam account cannot add friends until it has spent money) and `--fake-lag=` / `--fake-loss=`, wiring up Valve's own network simulator.

That last one answers the "both machines are on my LAN" question: two LAN machines connect directly and measure about a millisecond, so a same-network test proves the path functions and says nothing about feel. **Injected latency is a better test than a real connection** — repeatable and dial-able.

### Open questions

- **The Steam join half** — blocked on a second machine. `docs/steam-validation-run.md` is the checklist.
- **Detection and patch maths** — still the thinnest part of the GDD, and Phase 3 rests entirely on it.
- **Does Large read as a two-person job?** ADR 16 puts it at 1.0 m across. If it doesn't, the fix is mass and awkwardness, not size — size is now locked into modelled geometry.
- **Feel tuning is provisional.** Stiffness 2400 / damping 460 came from one session. All exported and live-tunable.
- **A named crew with specialties** — proposed, undecided, in `docs/idea-book.md`. Unique picks settled; roster wants to be about double the party size or nobody actually chooses.

### Later the same session — Phase 1 planned, and storage redesigned

**The planning tool was adopted as a wrapper (ADR 15)**, then used to plan Phase 1: research, nine plans across seven waves, and an independent verification pass that returned clean. The decision that mattered was made before the first command — the roadmap mirrors GDD §13 rather than generating a rival, because two roadmaps do not stay in agreement.

**Foundation #4 stopped being only a rule.** `test/api/engine_assumptions.gd` now asserts 77 engine and addon assumptions, including three whose failure would otherwise be invisible. It exists because six throwaway probes were written, run and deleted in one day. It immediately caught two bugs in itself: `ClassDB` lookups take `no_inheritance` and reported inherited members as missing, and referencing a `class_name` statically made the test compile-depend on an autoload that does not exist in a `--script` run — it reported a pass and *then* failed to compile.

**Two design decisions came out of playing the numbers rather than building.**

**ADR 17 — settled cargo becomes solid.** GDD §6.2 promised floor stacking "blocks pathing" and it did not: cargo and players share no collision mask, so clutter obstructed cargo but not people. A crate that settles now turns static and joins the world layer; the push sensor still fires while frozen, so walking into it wakes it and it scatters. Verified before deciding — a static crate blocks a capsule at exactly crate face plus capsule radius and cannot be bulldozed (0.000 m). It does not disturb ADR 7, and the reason is the elegance: a static crate is *world geometry*, and clients already simulate against that authoritatively.

**ADR 18 — storage cells, superseding ADR 16 four hours after it was fixed.** The trigger was an innocent question: how much does a rack hold? ADR 16 had fixed footprints only, never depth, height or pitch. Answering exposed something worse — its Medium (1.0 × 0.5 × 0.5) does not occlude your view and its Large (1.0 m square) does not need two people, so the model was quietly undermining the co-op incentive the whole game leans on.

The new model: a **cell is 1.0 m**, a Small is 0.5 m and eight fit a cell, a Medium *is* a cell, a Large is two. A cell is **atomic** and retrieval within it is **LIFO**, which turns FIFO discipline from a habit into something the building enforces — unstack six crates while a client waits. A rack is 2 × 2 × 3 = 12 cells: 96 Smalls, 12 Mediums or 6 Larges. And **placement decides burial**: a 2-deep rack against a wall buries its back row, the same rack as an island has two front rows.

Two things fell out of that discussion worth recording. **Fees must price volume, not items** — otherwise eight Smalls in a cell earn eight times a Medium in the same space and the packing decision collapses. And **Large gets no size premium**: for the same commodity, large and small pay the same per volume, and the reward for Large is *fewer journeys*, which scales with how many mates you have. That is the co-op incentive expressed through the economy rather than a rule.

**The dodgy-client idea landed in scope by being reframed.** Contraband as a cargo system implies police, and raids are parked. As a *client personality* it needs nothing new: a Tony Montana knock-off shipping "legitimate baby talcum powder", paying far above rate, risk borne entirely by reputation with legitimate clients. The joke does the work.

### Open questions

- **Steam join half** — still blocked on a second machine.
- **Plans 01-02 and 01-03** were written against the superseded slot model and need rework before Phase 1 executes.
- **Does two-deep racking plus in-cell burial become tedious rather than tense?** Two layers of awkwardness stacked. Relieve with island placement before touching either rule.
- **The memory game gets coarser** under cells — twelve addresses instead of twenty-four. Traded knowingly for physical rummaging.

### Next steps

Rework 01-02 and 01-03 for the cell model, then execute Phase 1.

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
