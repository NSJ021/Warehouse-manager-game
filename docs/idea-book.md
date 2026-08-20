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

### Variant proposed 2026-08-20 — the trait picker

**Raised:** NJ, mid-session. Decouple the cosmetic identity from the mechanical one: **~6 character
models with changeables** (hi-vis, hats, colours), then a **points-based trait picker** in the
Project Zomboid mould — buffs cost points, debuffs pay them, weighted so that affording any real
buff means taking debuffs. **Nicknames are generated from the picks**, using the name pool below
as the generator's vocabulary and keeping its rule: the name names the trait and takes the piss.

What it fixes outright — the entry's two sharpest risks dissolve structurally:

- **The roster-size problem disappears.** No eight-character minimum, no leftover pick, no
  duplicate rule needed. Combinatorial builds mean four players always have a real choice.
- **The solo problem disappears.** One pick no longer locks seven doors for a whole lease — a
  solo player assembles their own texture. "Conveniences, not keys" stops being a discipline to
  hold and becomes a property of the system.

The debuff weighting is proven design: Zomboid players voluntarily take *more* debuffs than they
need because debuffs are funny, and self-inflicted chaos is consented chaos — the same
philosophy as the host splitting the pot. Guardrails that carry over from the fixed-cast
version, plus two new ones:

1. **Debuffs must be physics-visible** — drops things when shoved, can't stop on demand, clips
   rack corners. A stat tax is a spreadsheet; a fumble is a clip.
2. **Cap the picks** (roughly two buffs, three debuffs) so the lobby stays a conversation, not a
   spreadsheet.
3. **Any trait touching the dilemma's constants must be a parameter the no-dominant-strategy
   sweep can iterate** (a suspicion-ramp rate, a replacement-cost multiplier), and the sweep
   runs per-build. This turns "balance work" from a vibe into a testable cost.

**What it loses, and the rescue:** the fixed sitcom cast. "Rodney did it again" works across
every streamer's video because Rodney is the same Rodney; custom builds make stories personal
but not franchisable, and capsule art wants a recognisable cast. The synthesis: **the eight
become curated presets** — canonical look, canonical build, canonical nickname — sitting on top
of the trait system. Trailers and capsule art use the cast; players pick a preset or build
custom and get christened by the generator. Marketing keeps its sitcom, players keep their
freedom.

**Teflon Vin, revisited harder:** his perk breaks two load-bearing rules, not one — the
pillar's "holder decides, holder owns it", and ADR 21's deliberate refusal to mechanise blame
(damage is named but never netted precisely because attribution is unprovable). Keep him in the
name pool, keep him out of any shipping set.

**Sequencing (per ADR 23):** models and cosmetics at the EA launch — close to a marketing
requirement, since the store page needs clippable characters and ADR 11's positioning demands
them. The trait system is a post-EA headline update, priced against live economy data that will
not exist sooner. The decoupling in this variant is exactly the seam that split needs.

### Where this sits against scope

Not in v1's In list, and it is not on the parked list either — it is new. If it comes in, it needs its own ADR, and that ADR should be honest that the *cost* is balance work rather than art.

**Cheap partial version worth considering separately:** the personas without the specialties. Four named, visually distinct crew members with no mechanical differences at all would deliver the character-led identity and the clippability at almost the full art saving and *zero* balance cost. The specialties are the expensive half; the names and silhouettes are the half that does the marketing work.

---

## The sales counter

**Raised:** 2026-08-17 (NJ) · **Developed:** 2026-08-19 · **Revised:** 2026-08-19 after ADR 22 · **Status:** proposal, not in v1 scope · needs an ADR

### The idea

Two halves, as originally raised: **sell the cargo you are meant to be storing**, and **short-change depositors at intake** — accept forty crates, record thirty-eight, keep the difference. A third, **buying stock back in**, was added on 2026-08-19 and turns out to be the piece that makes the rest work.

It converges hard with the name. [ADR 11](../decisions/2026-08-16-game-name.md) already notes that *Nice Little Earner* "implies actively making money in ways you would rather not itemise", which is this proposal described exactly.

### It is a payday loan, not an escape valve

The framing, settled 2026-08-19 and built on NJ's original *borrowing, not stealing*: **selling never saves a run. It defers eviction at ruinous interest.**

You sell tomorrow's stock to pay today's rent, and tomorrow arrives anyway — now short of goods you have promised to someone. Eviction stays exactly as frightening as it was; you have simply chosen a worse death. That is thematically native to a leased warehouse, and it is the only version that does not defang the rent clock the whole design is built around.

**The buy/sell spread is the interest rate**, and that is why buying matters. Sell below value, buy back above it. Without a buy side, fencing is a one-way conversion with a vague penalty bolted on. With one, the cost is legible, self-inflicted and countable: *sold for £60, costs £140 to replace before Thursday.* A pawnbroker, not a shop.

### Five strands, and separating them is the whole point

"The sales counter" is not one idea, and treating it as one is how parked scope gets in through the side door.

| # | Strand | What it is | Status |
|---|---|---|---|
| 1 | **Fencing** | Sell a client's stored crate for cash today | Core. Worth taking |
| 2 | **Short-changing intake** | Under-record what arrived, pocket the difference | Worth taking. Least designed |
| 3 | **Lien sale** | Sell stock the client abandoned past its store-until date | Worth taking. The only strand that is not fraud |
| 5 | **Buying stock in** | Cash back into goods, at a worse rate | Worth taking. Makes 1 legible |
| 4 | **Bartering at the door** | Haggling on price | **Excluded.** Parked under ADR 6 and stays parked |

Strand 4 is the trap, and it is named here so it cannot ride in as part of a bundle. It is already parked, and a "sales counter" that quietly includes haggling adopts parked scope without a superseding ADR.

Strand 3 is the surprise. Selling uncollected goods to recover storage costs is real, legal warehousing practice, and it adds a decision **without** adding fraud. It also answers something the design currently has no answer for — what to do with stock whose store-until date passed and whose owner never came. Cheapest of the five, and the sensible first build.

### What ADR 22 changed, and it changed a lot

Three things, all of which strengthen the proposal:

**The fire-sale risk is largely solved.** The version of this entry written earlier flagged the endgame fire-sale as the thing that would kill it — reputation decays to nothing by the final night ([ADR 21](../decisions/2026-08-19-two-currencies-and-the-crew-split.md)), so on day 29 you could sell the whole warehouse and every reputation hit would land when reputation was worthless. [ADR 22](../decisions/2026-08-19-orders-are-manifests-reputation-is-a-market.md) established that **dodgy clients punish in cash, and cash consequences do not decay.** That was mitigation #1 on the old list; it is now a design principle rather than a proposal. The fire-sale prices itself out.

**The consequence is proportional now.** Orders are manifests, so selling one crate of three is part-fulfilment rather than a failed order. Fencing becomes a dial rather than a detonator — sell one crate to make rent and eat a proportional hit.

**And it has a home instead of being bolted on.** Who buys stolen warehouse goods? Not legit clients — the unsavoury end. And selling stock drops your reputation, which shifts your client mix toward the unsavoury end. **The buyer and the consequence are the same people.** Fencing is not a new system; it is the transaction connecting two things ADR 22 already created — your stock, and the low-reputation market.

```
sell → cannot fulfil → order fails → reputation drops
     → mix shifts unsavoury → more buyers, more above-rate work → sell
```

A feedback loop, so it needs a brake, and it has one: dodgy clients punish in cash and their goods must not be damaged, so the deeper in you go the more brutal failure gets. Self-limiting.

That also shrinks the cost — if the low-reputation market exists, the buyer already exists, and what remains is a place to sell, a price and the reckoning. **Honest caveat: ADR 22 is decided, not built.** Both are Phase 4. This makes them one system rather than two; it does not make either free.

### Buying, and why it earns its place

Cash back into goods, at a worse rate than you sold at.

It plugs a hole ADR 22 opened. Comping requires like-for-like, so if nobody stored matching goods you simply cannot comp. Buying converts that into *cannot comp without cash* — **so you can buy your way out of a mistake when you are flush and cannot when you are broke.** The dilemma gets hardest exactly when you are struggling, which is when it should be.

**The risk to design against:** buying must never trivialise the fork. If a replacement is always purchasable, every damaged item becomes "pay to make it go away" and the pillar is bypassed rather than fed. The price has to make it worse than confessing in most situations — it is the option for when reputation matters more than cash, which is early in a lease and with a client you cannot afford to lose.

**Out of scope even if this comes in:** buying stock to trade for profit. That is a merchant game and a different one — the warehouse would become a trading floor, and P2 is order under pressure, not market speculation. Buying exists to replace what you owe, not to speculate.

### Short-changing intake, which was listed but never thought about

Sign for thirty-eight when forty arrived. The least designed of the five, but it has a genuinely distinct risk profile that makes it worth keeping separate from fencing:

- **Fenced stock has a reckoning with a date.** The client is coming for it on a known day.
- **Skimmed stock was never on the books**, so there is no collection day and nothing to explain — unless the discrepancy itself is spotted.

So fencing is high-volume with a guaranteed reckoning, and skimming is low-volume with uncertain detection. You can only take a little before the count is obviously wrong. It is a **paperwork lie rather than a physical one**, which makes it the natural counterpart to the tape gun, and it produces **untraceable stock** — exactly what comping needs. Strand 2 quietly feeds strand 1 and the comp mechanic both.

### Two things it would fill that are currently empty

- **The rent clock has no lever at all.** Today, "cannot make rent" has exactly one answer: should have played better three days ago. A payday loan is a bad decision available at the worst moment, which is a better failure than arithmetic.
- **Expired stock has no purpose.** Cargo past its store-until date currently just sits there being a spoilage penalty.

### Constraints it must not break

1. **It must feed the dilemma, never bypass it.** The moment selling or buying becomes a clean alternative to patch/confess/comp, it competes with the pillar instead of supplying it.
2. **It must not be the optimal default.** If selling stored cargo beats storing it, the game is about fencing and the warehouse is set dressing.
3. **It must stay a decision, not a routine.** Once per crisis is a story; a sales loop every morning is a second job.
4. **It must never save a run.** See the payday-loan framing. The moment it becomes a comeback mechanic, the rent clock stops being frightening.

### The cheap version

**No counter, no NPC, no haggling UI — a bloke in a van round the back.**

A dead drop: a marked spot by the loading door. Put a crate there, it is gone by morning, cash appears. Want something, order it the night before and it turns up. That removes the shop fixture, the buyer character, the price negotiation and — crucially — strand 4 entirely, which is the parked half. It is funnier and more in keeping with the tone than a shopfront, and it costs a trigger volume and an audio cue.

If this ever enters scope, it should enter as the van, not as the counter. The name of the idea is the most misleading thing about it.

### Where it sits with the other parked ideas

It reinforces the crew and is reinforced by it — **Half-Inch Del** and **Gaz the Gap** are already in the name pool as characters whose entire joke is stock quietly going missing, and **Clipboard Brenda**'s laminated competence is the obvious counterweight to strand 2's paperwork lie. Neither idea needs the other, but if either lands the second gets cheaper and funnier.

It also gets a **free evidence trail** from ADR 21's contribution tally: *"sold 3 of other people's crates"* is a column, and it is the most damning line the host could read at the split.

### Two couplings found 2026-08-20

**Fencing a damaged item is a fourth dilemma fork, and nobody had named it.** A damaged crate in
hand can be sold to the van and reported as never arrived — same order-of-cash as confessing,
no suspicion, reckoning deferred. That bypasses the pillar (constraint 1) through a side door:
fencing as *evidence disposal*. Any ADR for this must either price "gone missing" at least as
harshly as a failed order, or set the spread below the worst confession band (15%) so the honest
forks always beat the van on damaged stock — and if it is built, the no-dominant-strategy sweep
needs the fourth fork added or the design property is unverified.

**The spread can be derived rather than guessed.** The first-pass economy model
(`tools/economy-sim.js`) gives the "never saves a run" rule a tunable shape: **one fence must
never cover one night's rent.** At the model's candidate numbers, a good crate fenced at ~40%
yields ~£235 against a ~£585 eviction night — two or three sales can save the night, each
digging a visible hole in promised stock, which is exactly the "decision with a count" texture
constraint 3 wants.

**Sequencing (per ADR 23):** the lien sale (strand 3) is the low-controversy door and naturally
rides alongside Phase 4's economy ADRs. The van proper needs ADR 22's unsavoury market not just
decided but live-proven — a post-EA headline update, which is precisely the shape ADR 23 wants
updates to take.

### Open questions

- **Does a sale show up on the day's tally, or only at the final reckoning?** ADR 21 posts the tally at each day's CLOSE, which makes a sale **unilateral in the moment but accountable by nightfall** — you can hide it for an afternoon, not for a run. That is probably the right balance and consistent with the pillar, but it is worth confirming rather than assuming.
- **Who can sell?** Consistent with the pillar, any player. But one person fencing the warehouse is a far bigger unilateral act than patching one crate, and the tally is the only thing holding it accountable.
- **Does the client find out it was sold, or only that it is missing?** Different reputation consequences, and the second is more interesting because it leaves room for a lie.
- **What is the spread?** The single most important number if this is ever built, because it is the interest rate on the whole mechanic and it decides whether the loan is tempting or absurd.
