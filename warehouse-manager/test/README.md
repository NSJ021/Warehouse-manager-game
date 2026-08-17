# Tests

```powershell
./tools/run-tests.ps1            # everything
./tools/run-tests.ps1 -SmokeOnly # the fast half, while editing
```

One command, and it also runs automatically on `git push` via the `pre-push` hook.

## Why it is shaped like this

The risky parts of this game — host authority, held-item handoff, two-player carry — are exactly the parts unit tests are worst at. **A green suite of unit tests would prove almost nothing about whether Phase 0 works.** So the weight is on the integration layer, which runs two real processes talking over real ENet.

Four rules it holds to, each of which exists because of something that actually went wrong here:

**It drives the real path.** Grabs go through `Carrier.try_toggle_hold()` — the same function a keypress calls — so the aim ray is exercised. A test that called the referee directly would have passed happily while the ray was broken, and the ray *was* broken: a held crate blocked its own owner's aim, and that had to be found by hand.

**It uses the production world.** The integration test instances the real level, not a bespoke test scene, so it cannot pass against wiring the game does not actually use.

**It waits on state, never on time.** Every step polls until true or gives up on a wall-clock deadline. Frame budgets are useless here: headless Godot runs uncapped, so `--quit-after` counts iterations rather than seconds and any fixed frame count is meaningless as a timeout.

**Zero tolerance on engine errors and warnings.** A clean run has none, so any at all fail the suite. A flaky netcode test is worse than no test, because it trains you to ignore red.

## The layers

| Layer | What it proves | Cost |
|---|---|---|
| `smoke/` | Every scene under `res://scenes/` loads *and instances* | ~1s |
| `integration/` | Two processes: grab, two-player carry, handoff, release, all agreeing | ~1s |
| `unit/` | Reserved. Nothing pure enough to be worth it yet | — |

### smoke

`load_all_scenes.gd` walks `res://scenes/`, loads each scene and instances it. Loading catches a stale path after a file move; instancing catches broken `@onready` node paths, which a plain load lets straight through.

It does no networking at all, so it can never fight a live play session for a port.

### integration

`carry_session.tscn` runs in **both** processes, told apart by `--role=host` / `--role=client`. They synchronise on replicated state rather than sleeps — the client waits until it can see the host holding the crate, then joins the carry.

It asserts, in order: session up, world loaded, both peers in the roster, all six crates replicated to the client, own body spawned, host grabs, **a second holder joins**, the crate is lifted off the floor, the handoff leaves one holder, it is still held afterwards, and finally everyone has let go. The lift is asserted on the client too, which proves it replicated rather than only that the host believes it.

It uses port **27099**, deliberately not 27015, so running the suite never collides with someone playing.

## When it fails

The runner prints every step from both sides, then the state at the point of failure — roster size, crate count, holder ids, crate position, own position. That is the useful diff: enough to see which side disagreed without rerunning anything.

Two failure modes worth recognising:

- **`Could not find type "X"`** — a new `class_name` is not in the script class cache, which only the editor writes. The runner prints the fix. Rescan and re-run.
- **`host never reported READY-TO-ACCEPT`** — the host process died during startup. Its log is in the printed log directory.

## Adding a test

Integration tests belong here when they cover something two peers have to agree about. Prefer extending `carry_session.gd` with more asserted steps over adding a second session, since starting processes is most of the runtime.

Anything that can be checked without a session should go in `smoke/`, or in `unit/` once GUT is installed.
