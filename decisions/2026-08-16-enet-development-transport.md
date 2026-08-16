# ENet is the development transport, Steam P2P is the shipping transport

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ
- **Relates to:** [host-authoritative-netcode](2026-08-16-host-authoritative-netcode.md) — that ADR's choice of Steam P2P as the shipped transport is unchanged.

## Context

Phase 0's gate is a **four-player** test: pick up, drop, hand off, two-player carry, plus the contested case where a third player grabs at a crate two others are already carrying. Those races are the whole reason the phase exists.

Steam permits one logged-in Steam client per machine. Two PCs and two Steam accounts therefore cap a Steam-transport test at **two players**. There is no configuration that produces a third or fourth. The four-player race conditions the gate is meant to catch could never once be run.

Godot can run four instances of a project on one machine (`Debug > Customize Run Instances`), each a genuine network peer with real serialisation, real RPCs and a real host/client split — but only over a transport that does not depend on a per-machine Steam login.

## Decision

Both transports exist from the start, behind a `NetTransport` abstraction that turns a host/join request into a configured `MultiplayerPeer`. `Net` picks a subclass; nothing above that line knows which.

- **`ENetTransport`** — development. Four instances on one machine over loopback. This is where the spine is built and where all four-player behaviour is tested.
- **`SteamTransport`** — shipping. GodotSteam's `SteamMultiplayerPeer` bound to a Steam lobby. Validated two-up across two machines, and the only transport the released game uses.

Steam is **not deferred**. GodotSteam is installed and the Steam path is written now, so the dependency is proven early rather than discovered late.

## Consequences

**Easier:** the edit-test loop for netcode drops to seconds and needs no second machine, no second account and no Steam client running. Four-player cases become testable at all, which they otherwise would not be. Transport bugs are separable from gameplay bugs, because the same gameplay runs on both.

**Harder:** two transports mean two code paths, and a bug can hide in the one being exercised less. Loopback has no latency, so ENet testing flatters the game — anything that only breaks under real network conditions will not show up until the Steam pass. Mitigation: every Phase 0 milestone gets a two-machine Steam run before it is called done, and Steam-only concerns (lobby creation, invites, NAT traversal) are tested only on that path.

**Follow-up:** no artificial-latency tooling exists yet. Loopback masks anything timing-dependent. The intended fix is a `MultiplayerPeerExtension` that wraps the real peer and delays packet delivery by a configurable amount, giving a latency slider on the ENet path. Until that exists, latency feel is only assessable on the two-machine Steam run.

## Alternatives considered

**Steam only, from the start** — no abstraction, no second code path, and the shipping transport is exercised every day. Rejected because it makes the four-player gate untestable, which is the one thing Phase 0 must not compromise.

**ENet only, add Steam at the end of Phase 0** — least code now. Rejected because it leaves the single riskiest external dependency unproven until the phase is nominally finished, which is exactly when a nasty surprise is most expensive.
