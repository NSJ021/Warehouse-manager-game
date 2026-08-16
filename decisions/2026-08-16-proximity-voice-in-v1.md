# Proximity voice chat is in v1

- **Date:** 2026-08-16
- **Status:** Accepted
- **Deciders:** NJ
- **Supersedes:** the proximity-voice-chat entry on the Out list in [lean-v1-scope](2026-08-16-lean-v1-scope.md). Every other parked feature stays parked, and the superseding-ADR guardrail stands unchanged.

## Context

The lean-scope ADR parked proximity voice chat but named it "the first feature back in", and the GDD repeated that. This ADR is that document.

Two things changed.

**The marketing case got stronger than the feature case.** Reviewing why this genre's breakouts spread, proximity voice is consistently described as the *mechanism* rather than a feature sitting alongside one. The comedy in Lethal Company, R.E.P.O., PEAK and Content Warning is people talking — panicking, lying, going quiet at the wrong moment. A clip of physics slapstick with no audio is not a clip. For a game whose entire acquisition channel is short-form video and word of mouth, cutting voice chat cuts the product's ability to market itself.

**The cost case collapsed.** The GodotSteam GDExtension installed for Phase 0 already exposes the full Steam Voice API — `startVoiceRecording`, `getVoice`, `decompressVoice`, `getVoiceOptimalSampleRate`, `setInGameVoiceSpeaking` — verified present in the shipped binary. This is integration work against a dependency the project already carries, not a new dependency, a new service, or a per-user cost.

There is also a direct design argument. This game's pillar is a *social* dilemma: whoever holds the damaged item decides alone whether to patch it and lie. That decision is only dramatic if the other players can hear the decision being made, or hear the suspicious silence where it should have been. Without voice, the pillar degrades into a menu choice with a dice roll. The dilemma and voice chat are the same feature.

## Decision

**Proximity voice chat ships in v1.** Steam Voice capture and playback, distance-attenuated and positioned in 3D so a voice comes from where the speaker is standing. Push-to-talk and open-mic both available, mic selection and per-player volume in options, and a visible speaking indicator so a muted or broken mic is diagnosable by the player rather than mysterious.

It is **not** a Phase 0 concern. Phase 0 remains the netcode spine and nothing else. Voice lands in **Phase 6** alongside the audio pass, where the bus design and mix already have to be solved — but the audio bus is designed for it from the start, as the lean-scope ADR already required.

## Consequences

**Easier:** the pillar works as designed, and the game becomes capable of producing its own marketing. Cheap to reach, because the API is already vendored.

**Harder:** voice is a support-load and moderation surface — bad mics, echo, push-to-talk conflicts, and players being unpleasant to each other. Mitigation is per-player mute and volume in v1; nothing more ambitious. It also adds a real audio-mix problem, since voice has to duck against the crate and rack sounds that carry the comedy rather than drowning them.

**Rules out nothing**, but it does spend the one exception this project had budgeted. The Out list is now materially harder to argue against re-opening, so the guardrail matters more, not less: forklift, build mode, cleaning, blackouts, raids, bartering, extra maps and upgrade trees each still need their own superseding ADR, and the existence of this one is not precedent for them. This ADR is a re-scoping on evidence, not a scope creep.

## Alternatives considered

**Keep it parked, add post-launch** — the original plan. Rejected because launch is exactly when the marketing value is realised; a clip factory that switches on three months after release has missed the only moment that mattered.

**Ship with third-party voice (Vivox, Discord-dependency, or similar)** — better quality and moderation tooling. Rejected on cost, on adding an external dependency and account requirement to a game that currently needs neither, and because Steam Voice is already paid for and already installed.

**Text chat instead** — trivially cheap. Rejected outright: it does not produce clips, and it cannot carry a lie.
