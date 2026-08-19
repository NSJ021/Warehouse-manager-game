# Idea book

Developed ideas that are **not decided**. Nothing on this page is in scope.

This exists because good ideas arrive mid-build and have two bad fates: forgotten, or quietly implemented. An idea written down here is safe from the first without being at risk of the second. **Anything here entering v1 needs a superseding ADR** — the [lean v1 scope](../decisions/2026-08-16-lean-v1-scope.md) guardrail applies to new ideas exactly as it does to the parked list.

---

## The crew — named characters with specialties

**Raised:** 2026-08-17 (NJ) · **Status:** proposal, not in v1 scope

### The idea

Distinct named characters rather than four identical capsules. Each gets a **specialty** and a **persona**, so the crew has a feel rather than being four colours of the same bloke.

The four below are the founding idea. Unique picks (settled, below) then push the shipping roster to about eight, drawn from the name and perk pools further down.

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

### Unique picks — settled, with a consequence

**One character per player per run; no duplicates** (NJ, 2026-08-17). The lobby becomes a real conversation about who is doing what, and nobody has to look at four identical Rodneys.

It carries one structural consequence that decides the roster size: **unique picks only offer a choice if the roster is bigger than the party.** Ship exactly four characters and a four-player group has no decision to make at all — everyone simply gets the one left over, and the "specialty" is an allocation rather than a pick. So the shipping roster wants to be roughly **double the party size — eight or so** — which is what the name pool below is for. Four is the minimum that *functions*; eight is the minimum that is *a choice*.

Two smaller consequences worth writing down before they surprise anyone:

- **Solo hardens the constraint.** One pick for a whole lease and the other seven are simply unavailable. Conveniences, never keys — this is the rule the whole idea lives or dies on.
- **Late join needs a rule.** v1 only allows joining between days, so a returning player reclaiming their character is fine, but two people wanting the same one on rejoin needs a tiebreak.

### Open question

- **Sid's perk must be time-and-materials, not detection odds.** Cheaper patching is a convenience. Better odds of getting away with it edits the core dilemma maths — which is already flagged as the thinnest part of the design — and would make one character strictly better at the pillar.
- **Does Brenda's competence undercut the comedy?** Probably not — the straight man is load-bearing in an ensemble — but it is the one persona that could read as "the good option" rather than "a funny option".
- **Balance surface.** Four asymmetric kits × two lease lengths is a real multiplier on economy tuning, and each term is already effectively its own economy.

### The name pool

**The rule the nicknames follow**, taken from Big Dave: *a nickname does two jobs at once — it names the trait and it takes the piss.* "Dumbell" says strong and says thick in one word. "Rocket" says fast and says no brakes. Anything that only does one job is a label, not a nickname, and the crew wouldn't use it.

Twenty to pick a shipping roster of eight from. A couple of formidable women in there deliberately — a warehouse full of only lads is less funny than a warehouse where two of them are frightened of Brenda.

| Name | Nickname | Why it lands |
|---|---|---|
| Big Dave | **Dumbell** | Strong as an ox. Thick as one. |
| Rodney Rodders | **Rocket** | Quickest on the floor, and about as controllable. |
| Sidney Pike | **Sticky Sid** | The tape. And the fingers. |
| Brenda Nunn | **Clipboard** | Laminated, indexed, unbearable. |
| Terrence Nolan | **Two-Ton Tel** | Can shift anything. Weighs roughly the same as it. |
| Cyril Beach | **Tortoise** | Has never broken a single item. Has never once been on time. |
| Vincent Doyle | **Teflon Vin** | Nothing sticks to him. Blame least of all. |
| Gary Plunkett | **Gaz the Gap** | Finds the shortcut. Also the hole in the stock count. |
| Maureen Stubbs | **Health-and-Safety** | Knows every regulation. Observes her favourites. |
| Barry Cottle | **Bubblewrap** | Obsessed with protecting things. Pops under pressure. |
| Nigel Frayne | **Wingnut** | Big ears, slightly loose, holds the whole thing together regardless. |
| Charlie Ames | **Crowbar** | Gets anything open. Closes nothing gently. |
| Stanley Rooke | **Stan the Van** | Practically lives in it. Knows every route in the building. |
| Doreen Mapp | **Sat Nav** | Knows exactly where everything is. Tells you one turn too late. |
| Micky Vaughan | **Two-Trips** | Refuses to make two trips. Which is why he makes four. |
| Alfred Dann | **Breeze Block** | Heavy. Dependable. Thick. *(same joke as Dumbell — pick one, not both)* |
| Kevin Lidgate | **Clingfilm** | Thin, transparent, sticks to everything. |
| Derek Vance | **Half-Inch Del** | Accurate to the millimetre, and half-inches anything not nailed down. |
| Ronnie Spall | **Pallet** | Flat, load-bearing, permanently underfoot. |
| Tracey Bowe | **Magpie** | Spots the valuable one instantly. Cannot leave it alone. |

### The perk pool

Each is a **PRO with a CON in the same system**, so no perk is a straight upgrade. Column three is the system it touches — a roster wants a spread down that column, not eight movement perks.

| Character | Perk | PRO | CON | Touches |
|---|---|---|---|---|
| **Dumbell** | Built Like a Fridge | Carries a Medium at full walking pace and holds it low, so it never blocks his view | Cannot place precisely — clouts anything on the top row as he passes, and fumbles the slot when two are free | Movement · storage |
| **Rocket** | All Gas, No Brakes | Noticeably quicker with empty hands | Light as a crisp: cargo shoves *him*, he can't stop on demand, and he scuffs more per carry | Movement · damage |
| **Sticky Sid** | Confidence Trick | Patches in half the time for half the materials | He's *known* — client suspicion of him climbs faster with every patch he ships | Dilemma |
| **Clipboard** | Laminated | Reads store-until dates and client labels from across the warehouse; overdue stock stands out | Trusted, so betrayal costs double — a patch of hers that gets detected hits reputation twice as hard | Memory · dilemma |
| **Tortoise** | Never Dropped One | No scuff accrual, and drop damage heavily reduced | Slowest carry and slowest drag in the game, by a distance | Damage · movement |
| **Teflon Vin** | Wasn't Me | When a patch of his is detected, the client's suspicion lands on whoever was seen holding it last | Nobody trusts him: his own handovers pay less | Dilemma · social |
| **Half-Inch Del** | Creative Accounting | Comping a replacement costs noticeably less — he sources it cheap | Small daily chance an item goes quietly missing from your own stock | Economy · dilemma |
| **Two-Trips** | One Trip Or Death | Can carry two Small items at once | Take a shove while double-carrying and he drops both | Movement · damage |
| **Sat Nav** | Knows a Shortcut | Once a day, pings the aisle holding a crate on today's manifest | The aisle, not the slot — and a few seconds later than useful | Memory |
| **Bubblewrap** | Better Safe | Anything he racks personally never takes rack-shed damage | Slow to rack, and wastes materials re-taping things that were fine | Damage · economy |
| **Crowbar** | Gets It Open | Handles awkward cargo faster, and frees a wedged crate instantly | Everything he opens loses a condition tier | Damage |
| **Health-and-Safety** | By The Book | Immune to the working-in-the-dark penalty, and unstable racks are obvious to her | Physically will not floor-stack — she puts it back, and there goes your shortcut | Damage · storage |
| **Magpie** | Ooh, That's Nice | High-value items pay a bonus when she personally hands them over | Double reputation hit if *she* is the one who damages a high-value item | Economy |
| **Wingnut** | Holds It Together | Two-player carry with him is unusually steady — he compensates for the other end | Solo, he's the twitchiest carrier on the roster | Co-op · movement |
| **Pallet** | Load-Bearing Ron | Teammates can stand on him to reach a high slot | While being stood on he can't move, and he wears the damage if the crate comes down | Co-op · storage |

**Two of these deserve a second look before anyone builds them.**

*Teflon Vin* is the most interesting perk on the list and the most dangerous. Misdirecting suspicion onto a teammate is the social engine of the game turned up to eleven — and it edges close to breaking the *"whoever is holding it decides"* rule, because his choice now lands on someone else's reputation. Worth prototyping precisely because it might be the best idea here or the one that makes people stop playing together.

*Pallet* and *Wingnut* are the two whose perks only pay out **in co-op**, which is exactly the shape the design wants: teamwork rewarded by being better, never by being required. A roster with two or three of these makes the co-op case without gating anything — Ronnie solo is simply a bloke, and that is allowed.

### Where this sits against scope

Not in v1's In list, and it is not on the parked list either — it is new. If it comes in, it needs its own ADR, and that ADR should be honest that the *cost* is balance work rather than art.

**Cheap partial version worth considering separately:** the personas without the specialties. Four named, visually distinct crew members with no mechanical differences at all would deliver the character-led identity and the clippability at almost the full art saving and *zero* balance cost. The specialties are the expensive half; the names and silhouettes are the half that does the marketing work.

---

## The sales counter

**Raised:** 2026-08-17 (NJ) · **Developed:** 2026-08-19 · **Status:** proposal, not in v1 scope · needs an ADR

### The idea

Two halves, as originally raised: **sell the cargo you are meant to be storing**, and **short-change depositors at intake** — accept forty crates, record thirty-eight, keep the difference.

It converges hard with the name. [ADR 11](../decisions/2026-08-16-game-name.md) already notes that *Nice Little Earner* "implies actively making money in ways you would rather not itemise", which is this proposal described exactly.

### Four strands, and separating them is the whole point

"The sales counter" is not one idea, and treating it as one is how parked scope gets in through the side door. It is at least four, with different costs and different scope status:

| # | Strand | What it is | Scope status |
|---|---|---|---|
| 1 | **Fencing** | Sell a client's stored crate for cash today | **New scope.** The core proposal |
| 2 | **Short-changing intake** | Under-record what arrived, pocket the difference | **New scope.** Independent of 1 |
| 3 | **Lien sale** | Sell stock the client abandoned past its store-until date | **New scope**, and the only strand that is not fraud |
| 4 | **Bartering at the door** | Haggling on price | **Parked** — explicitly on the ADR 6 Out list |

Strand 4 is the trap. It is already parked, and a "sales counter" that quietly includes haggling adopts parked scope without a superseding ADR. **Any ADR that takes this on must say which strands it takes**, and strand 4 needs its own reasoning or its own explicit exclusion.

Strand 3 is the surprise. Selling uncollected goods to recover storage costs is real, legal warehousing practice, and it is the one version that adds a decision **without** adding fraud. It also solves a problem the design currently has no answer for — what to do with stock whose store-until date has passed and whose owner never came.

### The framing that makes it work: borrowing, not stealing

NJ's framing from the day it was raised, and it is the thing that stops this being a different game: **cash now, a certain reckoning on collection day.**

You are not stealing a crate, you are *borrowing against* it. The client's collection day is already in the design (§6.1's store-until date), so the debt has a fixed maturity written into the item itself. When they turn up, it is not there, and you are back at the fork — comp it from someone else's stock, or confess.

That is why it is worth considering at all: **it manufactures more dilemmas rather than replacing them.** A mechanic that let you cash out cleanly would compete with the pillar. This one feeds it.

### The risk that would kill it — and it is new since ADR 21

**The endgame fire-sale.**

[ADR 21](../decisions/2026-08-19-two-currencies-and-the-crew-split.md) settled that reputation is an interest rate that decays to nothing as the lease runs out. That is correct and load-bearing for the dilemma — but it means the cost of a reputation hit *falls every day*. Point that at a mechanic that converts stock into cash and the consequence is immediate:

> On day 29 of 30, sell the entire warehouse. Every reputation hit lands when reputation is nearly worthless. Bank the cash, split it at the checkout, walk away rich.

That is a dominant endgame strategy and it would hollow out the last third of every run. Three mitigations, all of which need deciding rather than assuming:

1. **The reckoning must be denominated in cash, not only reputation.** Failing to produce a crate on collection day should cost its full value plus a penalty. Then selling is a loan with interest rather than free money, and the fire-sale prices itself out.
2. **Contract win conditions already exist** (§4) and are the natural counter — *"move 200 crates with zero damaged deliveries"* is failed by a fire-sale automatically.
3. **Cap what is sellable.** Restricting clean sales to strand 3 — genuinely abandoned stock — removes the exploit entirely, at the cost of most of the fun.

**This risk did not exist when the idea was raised.** It is a consequence of ADR 21, and it is the single strongest argument for keeping the whole thing parked until the economy is real enough to test the fire-sale against actual numbers.

### Two things it would fill that are currently empty

- **The rent clock has no escape valve.** Today, "cannot make rent" has exactly one answer: should have played better three days ago. A sales counter is the desperate lever — a bad decision available at the worst moment, which is a better failure state than arithmetic.
- **Expired stock has no purpose.** Cargo past its store-until date currently just sits there being a spoilage penalty.

The honest counter-argument to the first one: **the game may not want an escape valve.** Eviction being final is part of what makes rent frightening, and a lever that softens it could defang the clock the whole run is built around. Unresolved, and it should be resolved before this is built rather than discovered afterwards.

### Constraints it must not break

1. **It must feed the dilemma, never bypass it.** The moment selling becomes a clean alternative to patch/confess/comp, it competes with the pillar instead of supplying it.
2. **It must not be the optimal default.** If selling stored cargo beats storing it, the game is about fencing and the warehouse is set dressing.
3. **It must stay a decision, not a routine.** Once per crisis is a story; a sales loop every morning is a second job.

### The cheap version

**No counter, no NPC, no haggling UI — a bloke in a van round the back.**

A dead drop: a marked spot by the loading door. Put a crate there, it is gone by morning, cash appears. That removes the shop fixture, the buyer character, the price negotiation and — crucially — strand 4 entirely, which is the parked half. It is also funnier and more in keeping with the tone than a shopfront, and it costs one trigger volume and one audio cue.

If this ever enters scope, it should enter as the van, not as the counter.

### Where it sits with the other parked ideas

It reinforces the crew and is reinforced by it — **Half-Inch Del** and **Gaz the Gap** are already in the name pool as characters whose entire joke is stock quietly going missing. Neither idea needs the other, but if either lands the second gets cheaper and funnier.

It also gets a **free evidence trail** from ADR 21's contribution tally: *"sold 3 of other people's crates"* is a column, and it is the most damning line the host could read at the split.

### Open questions

- **Does a sale show up on the day's tally, or only at the final reckoning?** ADR 21 posts the tally at each day's CLOSE, which would make secret selling impossible. Hiding it until the checkout fits the unilateral-decision pillar better and is considerably funnier, but it is an explicit exception to a rule just made.
- **Who can sell?** If any player can fence any crate, one person can bankrupt the crew's reputation alone. That is consistent with the pillar — and it is a far bigger unilateral act than patching one item.
- **Does the client find out it was sold, or only that it is missing?** Different reputation consequences, and the second is more interesting because it leaves room for a lie.
- **Strand 2 (short-changing intake) has had no design at all.** It is listed here because it was raised, not because it has been thought about.
