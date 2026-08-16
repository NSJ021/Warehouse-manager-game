# Engine: Godot 4.6 with Jolt physics and Steam P2P

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ

## Context

Engine was open. NJ has two Godot projects in flight (On Tools, Mob Boss) and a full set of Godot skills and tooling. Critically: **a large share of implementation will be AI-assisted**, and all three major engines have editor tooling for that — so "which engine has integrations" was not the differentiator. "Which engine can an automated tool actually read and write" was.

## Decision

**Godot 4.6**, with the **Jolt** 3D physics backend and **Steam P2P networking** via GodotSteam.

## Consequences

**Easier:** GDScript *and* scenes (`.tscn`) are plain text — an agent can read, grep, diff and rewrite the entire project. Every change is reviewable. Matches NJ's existing skills, conventions and toolchain. Steam P2P means no game servers to run and no infrastructure cost.

**Harder:** Godot has no built-in client-side prediction or rollback for physics. Authority handling for held-object handoff and rack stability is hand-written. See the host-authoritative netcode ADR — the mitigation is the architecture itself.

**Rules out:** engine-provided replication of the quality Unreal ships with. Accepted knowingly.

## Alternatives considered

**Unity** — best-in-class 3D physics tooling and several mature netcode options. Lost on agent legibility: scenes and prefabs are YAML full of GUIDs, so direct file editing by an agent is fragile and every structural change has to be routed through editor operations. Also a new engine mid-portfolio.

**Unreal** — networked physics and replication largely solved out of the box, which is exactly this project's hardest problem. Lost decisively on agent legibility: **Blueprints are binary and invisible to an agent**, and a C++-only workflow means brutal compile-iteration loops. Heaviest learn, heaviest builds, overkill for low-poly art.
