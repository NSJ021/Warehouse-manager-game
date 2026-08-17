# Two-machine Steam validation run

The Steam transport is the last unproven claim in Phase 0. This is the checklist for proving it.

## First, the question everyone asks: what about IPs?

**There are none.** Steam P2P needs no IP address, no port forwarding, no router configuration and no knowledge of your network at all. The only thing the two machines exchange is a **lobby ID** — a long number the host reads off its own HUD.

Under the bonnet Steam either punches through both NATs or falls back to relaying through Valve's own network. Either way it is Valve's problem, not ours. That convenience is the entire reason [ADR 8](../decisions/2026-08-16-enet-development-transport.md) puts Steam on the shipping path and keeps ENet for development.

## Second: a same-network test is necessary but not sufficient

Two machines on one LAN will connect to each other more or less **directly**, so you will measure about a millisecond of latency. That proves the Steam path *functions*. It tells you nothing about how the game *feels* over the internet, which is the more interesting question — ADR 13 stakes the whole grab design on the claim that lag reads as weight rather than as error.

So split it in two:

| Question | What it needs |
|---|---|
| Does the Steam path work at all — lobby, join, replication? | Two machines on any network. **This checklist.** |
| Does it still feel right at realistic latency? | **Not** a second machine. Valve's network simulator, below. |
| Does it survive real NAT, relays and jitter? | A genuinely remote player. A friend, later. |

The middle one is the surprise: injected latency is a **better** test than a real internet connection, because it is repeatable and dial-able. A one-off internet test gives you one unknown number that you cannot reproduce tomorrow.

## Already proven, so don't re-test it

Executed on 2026-08-17, on one machine:

- Every GodotSteam call in `steam_transport.gd` exists with the signature it assumes — methods, both signal argument lists, all lobby-type constants, and `SteamMultiplayerPeer.host_with_lobby` / `connect_to_lobby`.
- Steam **initialises** from an exported build, loads the API, and identifies the logged-in account.
- A lobby is **created** and the multiplayer peer binds to it. The world then loads and spawns normally.
- Export produces both required DLLs without any manual copying.

**What remains genuinely untested is the join half**, and that is what needs the second machine. Nothing else.

## Prerequisites

- [ ] Two Windows PCs.
- [ ] **Two different Steam accounts.** One account cannot play on two machines at once — the second login boots the first. Steam also permits only one logged-in client per PC, which is the whole reason four-player testing lives on ENet.
- [ ] Steam **running and logged in** on both machines. Not just installed.
- [ ] The two accounts are **Steam friends** — because the lobby defaults to friends-only.
      **The trap:** a brand-new Steam account is *limited* until it has spent about £5, and a limited account cannot add friends. If the second account is new, skip the whole problem with `--lobby=public` at launch. No re-export needed; that is why it is a flag.
- [ ] Nothing else. App ID **480** is Valve's Spacewar test app: every Steam account can run it, and no store page is required.

## Build it (machine 1)

One command from the repo root:

```powershell
& $godot --headless --path warehouse-manager --export-debug "Windows Desktop" ../build/windows/NiceLittleEarner.exe
```

Use **`--export-debug`** rather than release for this: you get a console window and readable logs, which is what you want the first time a network path runs.

`export_presets.cfg` is gitignored, since these files can carry signing credentials. Copy `export_presets.cfg.example` to `export_presets.cfg` if it is missing.

### Then the one manual step

```powershell
Copy-Item warehouse-manager\steam_appid.txt build\windows\
```

**This is the step that is easy to miss and fails confusingly.** `steam_appid.txt` gets packed inside the `.pck`, so it does not exist as a loose file beside the executable — and that loose file is how the Steam API knows which app it is when the game is launched directly rather than from Steam. Without it, Steam refuses to initialise.

The DLLs need no such help: `steam_api64.dll` is declared in the addon's `[dependencies]`, so Godot places it next to the executable itself.

### What the folder should contain

```
NiceLittleEarner.exe
NiceLittleEarner.console.exe
NiceLittleEarner.pck
libgodotsteam.windows.template_debug.x86_64.dll
steam_api64.dll
steam_appid.txt          <- the one you copied
```

Copy that **whole folder** to machine 2. Any way you like — USB stick, network share, cloud drive. It is self-contained.

## The run

Use `NiceLittleEarner.console.exe` on both machines, not the plain exe: it gives you a console window with the log, and every failure below is diagnosed from that log.

**Machine A — host:**

```
NiceLittleEarner.console.exe --host --steam --name=A
```

The HUD shows `lobby: <a long number>`. That number is the only thing you need to carry across. The console also prints it as `[net] hosting over Steam lobby <number>`.

**Machine B — join:**

```
NiceLittleEarner.console.exe --steam --join=<that number> --name=B
```

Or launch with just `--steam`, type the lobby ID into the address field, and click **Join Steam**. The command line is less error-prone with a nineteen-digit number.

### Pass criteria

Work down this list. Each one proves something specific.

- [ ] **B's HUD reads `CLIENT`, an id that is not 1, and `Steam lobby <same number>`.** The transport connected.
- [ ] **Both HUDs read `players: 2/4`.** The roster replicated both ways.
- [ ] **Each player can see the other's capsule move.** Character replication works over Steam, not just ENet.
- [ ] **B grabs a crate and A sees it lift.** This is the real prize: host-authoritative cargo over Steam.
- [ ] **Both grab the same crate — HUD reads `TWO-PLAYER CARRY`.** Contested authority over a real connection.
- [ ] **A lets go while B holds it; the crate stays up.** Handoff over Steam.
- [ ] **B walks into a loose crate and A sees it move.** The shove path crosses the authority line.
- [ ] **Neither console window shows `ERROR:` or `SCRIPT ERROR:`.**

If all eight pass, the Steam transport is proven and Phase 0's last gate is closed.

## The latency test, which is the more valuable half

Valve ships a network simulator and GodotSteam exposes it. Add user arguments **after a bare `--`**:

```
NiceLittleEarner.console.exe --host --steam --name=A -- --fake-lag=40 --fake-loss=1
```

The console confirms it: `[net] simulating 40 ms each way (80 ms round trip) and 1.0% packet loss`.

**Read the arithmetic carefully before dialling it up.** The flag applies to both send *and* receive on the machine that sets it. So `--fake-lag=40` on **one** machine gives roughly an **80 ms round trip**, which is a realistic same-country figure. Setting 40 on *both* machines doubles it to about 160 ms, which is a bad transatlantic connection — useful, but do not do it by accident and conclude the game is broken.

Suggested ladder, and what each one is asking:

| Setting | Represents | The question |
|---|---|---|
| none | LAN | Does it work at all? |
| `--fake-lag=40` on one machine | ~80 ms, same country | **Does the spring still read as weight?** (ADR 13) |
| `--fake-lag=40 --fake-loss=2` | 80 ms with a lossy line | Does cargo jitter or recover? |
| `--fake-lag=80` on one machine | ~160 ms, bad connection | Where does it stop being fun? |

The specific thing to judge at 80 ms: pick up a crate and walk briskly. ADR 13 predicts the lag renders as *mass* rather than as error, because a spring already lags by design. If it instead reads as the crate fighting you or snapping to catch up, that prediction is wrong and the ADR needs revisiting — which is exactly the sort of thing worth finding now rather than after Phase 3 is built on top of it.

## If it goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| `Steam did not initialise` | Steam not running, or `steam_appid.txt` missing beside the exe | Start Steam; copy the file |
| Steam initialises, but on machine 2 only | Same Steam account on both | Use two accounts |
| Lobby created; B fails with a lobby-enter response other than 1 | Accounts are not friends and the lobby is friends-only | Relaunch A with `-- --lobby=public` |
| `'...' is not a Steam lobby ID` | Lobby ID mistyped or truncated | Copy it from the console line, not the HUD |
| Firewall prompt on first launch | Windows being Windows | Allow on both private and public |
| Connects, then cargo lags badly | Possibly the physics budget, not Steam | Check crate count against [the budget](physics-budget.md) — remember traffic *falling* is the symptom of exceeding it |

## Afterwards

- Re-check the [physics budget](physics-budget.md) numbers here. They were measured headless on one machine, so they exclude rendering and real latency and are therefore optimistic.
- Tidy the deliberate belt-and-braces in `steam_transport.gd`: Steam is initialised with `embed_callbacks` **and** the transport pumps callbacks in `poll()`. That redundancy was left in on purpose for a first run; pick one once the path is proven.
- The forced-kill shutdown in testing logged `still have sockets open`. That was an abrupt process kill rather than a clean quit, so it is probably nothing — but confirm on a clean exit, since a transport that does not tear down cleanly will bite during session restarts.
