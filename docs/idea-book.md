# Idea book

Developed ideas that are **not decided**. Nothing on this page is in scope.

This exists because good ideas arrive mid-build and have two bad fates: forgotten, or quietly implemented. An idea written down here is safe from the first without being at risk of the second. **Anything here entering v1 needs a superseding ADR** — the [lean v1 scope](../decisions/2026-08-16-lean-v1-scope.md) guardrail applies to new ideas exactly as it does to the parked list.

---

## The crew — four named characters with specialties

**Raised:** 2026-08-17 (NJ) · **Status:** proposal, not in v1 scope

### The idea

Four distinct characters rather than four identical capsules. Each gets a **specialty** and a **persona**, so the crew has a feel rather than being four colours of the same bloke.

| | Persona | Specialty | Matching handicap |
|---|---|---|---|
| **Big Dave** | All brawn, no brain. Talks to the cargo. Owns one dumbbell and has never used it. | Carries a Medium crate at full walking speed, no movement penalty | Hopeless at fine placement, and clouts things off racks as he passes |
| **Rodney "Rocket" Rodders** | Skinny, quick, mouthy little bastard. Never stops talking, never stops moving. | Speed boost when not carrying anything | Light as a crisp — cargo shoves *him*, and he scuffs more when he does carry |
| **"Sticky" Sid** *(proposed)* | Chain-smoking optimist. Believes everything is fixable with tape and confidence. Would sell you your own crate. | Tape gun is faster and cheaper — patching costs him less time and fewer materials | He's *known*. Client suspicion of Sid climbs faster, so his edge decays the more he uses it |
| **"Clipboard" Brenda** *(proposed)* | Terrifyingly officious. Laminated everything. The only competent person in the building, which is the joke. | Reads store-until dates and labels at a distance — finds things nobody else can | She's trusted, so betrayal costs more: if a patch of hers is detected, the reputation hit is bigger |

**Alternate for the fourth slot — "Careful" Cyril.** Forty years on the job, moves like continental drift, has never damaged a single item. Specialty: no scuff accrual and reduced drop damage. Handicap: slowest carry in the game, by a distance. Pick Cyril over Brenda if the fourth perk should touch **damage** rather than **information**.

### Why this might be more than flavour

Three arguments that make it worth a real look rather than a nice-to-have:

- **It is already the locked positioning.** [ADR 11](../decisions/2026-08-16-game-name.md) committed the game to a **character-led** identity — *the joke is who you are, not what the paperwork says*. A named crew delivers exactly that; four identical capsules quietly walk it back.
- **It suits the acquisition channel.** §11 names short-form video as the route to players. Named characters with fixed traits are dramatically more clippable than anonymous ones — "Rodney did it again" is a format, "the green player did it again" is not.
- **The art cost is lower than it looks**, *if* it stays one rig. §9's direction is derpy humanoids with oversized mitten hands and a simple rig. Four silhouettes on one skeleton — tall and wide, short and thin, stooped, rigid — plus a prop each, is the same trick as one crate mesh with swappable decals (§6.1).

### Three constraints it must not break

1. **No character is ever required.** The same rule as two-player carry: teamwork and specialties are the *efficient* path, never the *only* path. The moment a job needs Dave, the design has broken its own promise.
2. **Solo must survive it.** This is the sharpest risk and the easiest to miss. A solo player picks one character and permanently lacks the other three — for a 10 or 30-day lease. So specialties must be **conveniences, not keys**: Brenda finds things faster, but everyone can find things; Dave carries Medium comfortably, but everyone can carry it. If any specialty unlocks a capability, solo play breaks and §8 goes with it.
3. **Every specialty needs a matching handicap in the same system**, or the roster is just four difficulty settings with hats. The table above deliberately pairs them — Sid's advantage is in the dilemma and so is his cost; Brenda's advantage is trust and so is her penalty.

### The observation that makes it deeper rather than wider

Dave and Rodney are both **movement** perks. Four movement perks would be a thin roster — it would only ever change how fast the same game is played.

Aiming the other two at *different pillars* is what turns this from a re-skin into content: Sid sits on **the dilemma** (§6.5, the actual pillar), Brenda on **the memory game** (§6.3, the depth that costs no content). That gives each character a distinct relationship to the rules — muscle, mouth, chancer, jobsworth — which is also what makes the unilateral patch-or-confess choice *socially* funny rather than just mechanically interesting.

### Open questions

- **Unique picks, or can two players be Rodney?** This changes the whole design. Unique picks make the lobby a real conversation about who does what — but in a four-player game every character is always taken, so nobody actually chooses. Duplicates preserve choice at the cost of a party of four Rodneys.
- **Sid's perk must be time-and-materials, not detection odds.** Cheaper patching is a convenience. Better odds of getting away with it edits the core dilemma maths — which is already flagged as the thinnest part of the design — and would make one character strictly better at the pillar.
- **Does Brenda's competence undercut the comedy?** Probably not — the straight man is load-bearing in an ensemble — but it is the one persona that could read as "the good option" rather than "a funny option".
- **Balance surface.** Four asymmetric kits × two lease lengths is a real multiplier on economy tuning, and each term is already effectively its own economy.

### Where this sits against scope

Not in v1's In list, and it is not on the parked list either — it is new. If it comes in, it needs its own ADR, and that ADR should be honest that the *cost* is balance work rather than art.

**Cheap partial version worth considering separately:** the personas without the specialties. Four named, visually distinct crew members with no mechanical differences at all would deliver the character-led identity and the clippability at almost the full art saving and *zero* balance cost. The specialties are the expensive half; the names and silhouettes are the half that does the marketing work.

---

## The sales counter

**Status:** proposal, needs an ADR · roughly half of it is parked scope

Selling stored cargo over a counter rather than only dispatching it to its owner. Noted here so it stops living only in an untracked working file. Overlaps price bartering, which is explicitly on the parked list, so it cannot enter piecemeal without deciding that too.
