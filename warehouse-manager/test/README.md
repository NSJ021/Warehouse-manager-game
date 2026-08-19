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
| `api/` | The engine and addon APIs we depend on still exist and behave as assumed | <1s |
| `smoke/` | Every scene under `res://scenes/` loads *and instances* | ~1s |
| `integration/` | Two processes: grab, two-player carry, handoff, release, **solo drag and its promotion to a carry**, all agreeing | ~2s |
| `unit/` | The condition model and the dilemma maths, including *no dominant strategy* as an assertion | <1s |

### api

Runs first, because a broken engine assumption explains every other failure.

Every check here started life as a throwaway probe — written, run once, deleted. Six of them in one day, verifying things like whether a `RayCast3D` reports a shape it starts inside, whether Jolt populates the physics monitors, and what GodotSteam's init signature actually is. Deleting them meant the next session re-derived the same facts, and meant an engine upgrade would break those assumptions **silently**.

Three sections: engine methods and properties; engine *behaviours* where the shape of the answer matters (`Basis.looking_at` still points −Z at its target; a 270° rotation error still resolves to 90° the short way); and **invariants fixed by decisions** — a Small crate is exactly 0.5 m (ADR 18), cargo replicates at 20 Hz (ADR 14), players do not share a collision mask with cargo, two holders remains the carry ceiling, dragging still costs ~60% of your speed (GDD §6.1), and a Small stays light enough to lift solo.

That last section is the one to extend when an ADR fixes a number. Code drifting from a decision is exactly as bad as code drifting from a spec, and nothing else checks it.

GodotSteam is checked by **argument count**, not just existence, because the transport runs rarely — a changed signature would otherwise fail on its first line, on a second machine, mid-validation.

Two gotchas it has already hit, both recorded in the file: `ClassDB` property and method lookups take `no_inheritance`, and passing `true` reports inherited members as missing. And referencing a `class_name` statically makes the test compile-depend on that script — which fails in a `--script` run if the script touches an autoload, because autoloads are not registered there. Load at runtime instead.

### unit

`dilemma_maths.gd` covers `CargoCondition` and `Dilemma` — the tape gun, apparent versus actual condition, and the detection and payout maths behind GDD §6.5.

This layer sat empty and marked "reserved" until those two existed, on the stated grounds that nothing in the project was pure enough to be worth testing this way: the risk was all in networked physics, which unit tests are worst at. That is still true of everything else. It stopped being true the moment the game's pillar became arithmetic.

**No GUT.** The suite already has a working `--script` runner idiom, and adding a framework to run pure arithmetic would be more moving parts than the tests themselves. If a future need genuinely wants fixtures and parameterised cases, revisit it then.

The valuable half of this file is not the arithmetic — it is the assertion that **there is no dominant strategy**. GDD §6.5 only works if the right answer changes with the situation, which is a claim about the *shape* of the numbers rather than any one of them, and it is exactly what a later balance tweak breaks silently. So it sweeps 192 situations across item value, damage depth, client suspicion and days remaining, and requires that all three forks win somewhere and none wins more than 75%. It reports the realistic one-tier slice separately, because a uniform sweep can look healthy while the common case has quietly settled.

### smoke

`load_all_scenes.gd` walks `res://scenes/`, loads each scene and instances it. Loading catches a stale path after a file move; instancing catches broken `@onready` node paths, which a plain load lets straight through.

It does no networking at all, so it can never fight a live play session for a port.

### integration

`carry_session.tscn` runs in **both** processes, told apart by `--role=host` / `--role=client`. They synchronise on replicated state rather than sleeps — the client waits until it can see the host holding the crate, then joins the carry.

It asserts, in order: session up, world loaded, both peers in the roster, all six crates replicated to the client, own body spawned, host grabs, **a second holder joins**, the crate is lifted off the floor, the handoff leaves one holder, it is still held afterwards, and finally everyone has let go. The lift is asserted on the client too, which proves it replicated rather than only that the host believes it.

Then a second scenario for **solo drag**, on a different crate, with the *client* doing the dragging so every verdict has to survive a real RPC — a host-side drag would only exercise the local branch, which is the half that cannot break. It asserts the host granted a drag rather than a carry, that the 40% speed penalty applied on the dragger's own machine, that the crate **stays on the floor while the dragger looks straight up** (a carry would have hauled it to eye level; this is the mechanical reason a solo player cannot rack anything), that it follows them as they back away, that a second holder **promotes the drag into a carry** and lifts it, and that the promotion reached the dragger so their speed penalty lifts.

The two roles hand over through replicated state rather than a clock: the host waits for the crate to have *moved*, which is simultaneously a real assertion and proof the client has finished its own checks.

That last scenario found a bug the day it was written. The drag request was stored per crate rather than per holder, so when a helper joined a drag and the original dragger let go, the helper inherited a drag they had never asked for.

It uses port **27099**, deliberately not 27015, so running the suite never collides with someone playing.

## When it fails

The runner prints every step from both sides, then the state at the point of failure — roster size, crate count, holder ids, crate position, own position. That is the useful diff: enough to see which side disagreed without rerunning anything.

Two failure modes worth recognising:

- **`Could not find type "X"`** — a new `class_name` is not in the script class cache, which only the editor writes. The runner prints the fix. Rescan and re-run.
- **`host never reported READY-TO-ACCEPT`** — the host process died during startup. Its log is in the printed log directory.

## Adding a test

Integration tests belong here when they cover something two peers have to agree about. Prefer extending `carry_session.gd` with more asserted steps over adding a second session, since starting processes is most of the runtime.

Anything that can be checked without a session goes in `unit/` if it is pure logic, or `smoke/` if it needs a scene.
