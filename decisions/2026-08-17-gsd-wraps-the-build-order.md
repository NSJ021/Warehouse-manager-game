# The planning tool wraps the build order; it does not replace it

- **Date:** 2026-08-17
- **Status:** Accepted
- **Deciders:** NJ

## Context

The GSD planning commands and agents were installed but the project had no `.planning/`
state, so none of them could run. Turning it on raised a question that had to be answered
before the first command rather than after: **this project already has a roadmap.**

GDD §13 lays out Phases 0–7 with a goal and a gate each. Fourteen ADRs hold the decisions.
`decision-log.md` indexes them. `docs/conversation-log.md` carries the narrative, and the
project's local instruction file — untracked, machine-local — carries the current status.

GSD wants to own `ROADMAP.md` (phase structure), `REQUIREMENTS.md` (scope), `PROJECT.md`
(context) and `STATE.md` (memory). Three of those four overlap something that already
exists and is already authoritative.

The obvious route — run `/gsd:new-project` and let it interview and generate — would have
produced a second roadmap derived from scratch, with its own numbering and its own phase
names, sitting alongside GDD §13. Two roadmaps do not stay in agreement. One of them
silently becomes the real one and the other becomes a lie that still gets read.

## Decision

**GSD wraps the existing build order. It never replaces it, and it is never the source.**

- **`.planning/ROADMAP.md` mirrors GDD §13 exactly** — same phase numbers, same names,
  same gates, quoted rather than paraphrased. It adds success criteria and plan
  breakdowns, which the GDD does not carry.
- **Changes go to the GDD first, then get mirrored.** Adding, reordering or rescoping a
  phase is a design change, and design changes happen in the design document.
- **`REQUIREMENTS.md` is derived from GDD §10**, not written alongside it. It exists to
  give requirements stable IDs so phases can reference them; every line traces to
  something already in the design.
- **`PROJECT.md` is a pointer, not a restatement.** It links to the GDD, the ADRs, the
  structure doc and the physics budget rather than summarising them.
- **`STATE.md` is the one genuinely new artefact** — execution position, resumable. The
  narrative stays in `conversation-log.md`; duplicating the story guarantees one copy goes
  stale.
- **ADRs win over everything in `.planning/`, including anything a GSD agent writes
  there.** A generated plan that contradicts an ADR is a conflict to surface, not a
  decision that has been made.
- **`/gsd:new-project` is not to be run on this project.** The state was hand-authored
  precisely to avoid what that command would generate.

Phase numbering keeps the GDD's 0–7 rather than shifting to a 1-based scheme. Checked
rather than assumed: GSD names phase directories `{NN}-{name}` and nothing requires phases
to start at 1, so Phase 0 costs nothing and a renumbering would have created exactly the
translation layer this ADR exists to prevent.

## Consequences

**Easier:** per-phase planning, execution and verification machinery on top of a roadmap
that was already agreed, without re-litigating it. `STATE.md` gives a resumable position
across context resets, which the conversation log — being append-only narrative — never
did.

**Harder:** the build order now lives in two files, and they can drift. The mitigation is
the ordering rule (GDD first, mirror second) and the fact that ROADMAP.md opens by saying
so. This is a real discipline cost, accepted knowingly rather than waved away.

**Rules out:** `/gsd:new-project` and `/gsd:new-milestone` here without revisiting this
ADR, since both generate roadmap structure from scratch.

**The risk worth naming:** GSD agents write to `.planning/` autonomously. If one proposes
something that quietly contradicts an ADR — re-adding parked scope is the likely case,
since the parked list is full of obviously fun features — nothing in the tool will stop
it. The guard is that `PROJECT.md` and `STATE.md` both point at `decision-log.md` and
state the authority order, and that generated plans get read before they get executed.

**Follow-up:** if the two files do drift in practice, the answer is to make ROADMAP.md
generated from GDD §13 rather than maintained, not to abandon one of them.

## Alternatives considered

**Run `/gsd:new-project` and let GSD own the roadmap.** Fastest to set up, and it is what
the tool is designed for. Rejected because it discards the reasoning already captured in
GDD §13 and the ADRs, and creates precisely the two-competing-roadmaps failure that was
flagged as the thing to avoid before GSD was ever switched on.

**Don't adopt GSD at all.** Zero duplication risk, and the project has managed without it.
Rejected because the per-phase plan/execute/verify loop is genuinely useful at this size,
and because `STATE.md` solves a real problem — picking work back up mid-phase — that the
append-only conversation log does not.

**Use GSD for state only, with no roadmap file.** Minimal duplication. Rejected because
the commands expect a roadmap to route against, so most of the tool would not function.
