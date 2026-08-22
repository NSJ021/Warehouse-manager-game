# Marketing research — findings and what they mean for this project

Distilled 2026-08-22 from Chris Zukowski's *How To Market A Game*: his "60 mistakes" ebook
(copyright 2023) and a sweep of the site's articles, dated where it matters.

**Read the dates.** This field moves fast and the material contradicts itself across years — the
2023 ebook and a 2026 article disagree on launch timing, and the newer one wins. Every claim below
carries its source date for that reason.

**Nothing here is a decision.** Where a finding challenges a ratified ADR it says so and stops; a
superseding ADR is the only thing that changes a decision. Conclusions are written in our own words
and the ebook is a mailing-list freebie whose licence forbids reproduction, so it is not in this
repo and is not quoted at length.

---

## 1. The finding that matters most: the genre has a clock

Zukowski models a hot genre in four phases — a proto-game, a genre-defining hit, a second wave
where small teams profitably fragment the audience, and finally consolidation, where studios with
budget and IP close the door on small entrants.

His worked example **is our genre**. He traces co-op "friend-slop" through Lethal Company → REPO →
Peak, and in **November 2025** put the remaining window for small entrants at **6–12 months** before
phase four closes it.

That article is now roughly **nine and a half months old.** We are at Phase 2 of 7, with the Early
Access gate at Phase 7 and no launch date.

**No ADR currently treats time-to-EA as a competitive clock.** ADR 23 gates Early Access on a
quality bar, and ADR 6 keeps scope lean to protect delivery — but neither is framed against a market
window that is closing independently of our build velocity. This is the single most consequential
gap the research found, and it is a scheduling question rather than a design one.

Two honest caveats, both his and ours:

- He states the survivorship bias himself: *"more than likely your Great Conjunction game will still
  fail."* This is a probabilistic argument, not a formula.
- A closing window does not make a good game bad. It changes what a realistic outcome looks like,
  which is worth knowing before an EA date is chosen, not after.

### The case studies do not transfer cleanly, and that matters

His August 2026 three-part series profiles recent successes, and the numbers are striking: two
developers and four months producing $361,657 in 24 hours; two developers and seven months producing
$163,842; seven developers and a year producing 242,000 units.

**None of them is a co-op physics game.** They are an incremental tower-defence, an incremental
node-buster and a roguelike — genres with no networking, no physics simulation and no multiplayer QA
burden. The four-to-seven-month figures come from a category whose costs we do not share, and using
them as a schedule benchmark would be a straight category error. Our genuine comparables in his own
taxonomy are Lethal Company, REPO and Peak, which he analyses only at concurrency level, never at
team size or dev time.

---

## 2. Where the research challenges a ratified decision

### ADR 10 — the £9.99 / $11.99 price and the "cheap co-op cluster"

Zukowski argues the opposite direction, consistently. Median indie prices **fell from $8.70 in 2012
to $7.30 in 2020** while AAA rose sharply, and his heuristic is to take your nearest comparables in
genre, quality and scope and price **above** them, with a further buffer so there is room to
discount. His framing: if everyone thinks your price is exactly right, you are probably the cheapest
game in your genre.

Two specific complications:

- **The genre price banding that supports a "cheap co-op cluster" is not his.** Similar-sounding
  bands circulate on other marketing sites, but the sweep could not find a Zukowski article drawing
  that line. It should not be cited as market-validated by his data. Our own 26-title study stands
  on its own; it just is not corroborated here.
- **Both direct comparables sit at $9.99** — Lethal Company and REPO, verified independently. Our
  $11.99 is above both, which is consistent with his advice and inconsistent with "the cheap
  cluster". Whichever way ADR 10 lands on re-reading, the two halves of its rationale are in tension.

And the uncomfortable one: **Moving Out 2 was in the cheap cluster at £6.24 and sold poorly anyway.**
Cheapness did not protect the closest mechanical relative we have. That is the strongest argument
against price as a positioning tool here.

### ADR 23 — Early Access

**The shape of ADR 23 is confirmed, and its central risk is one the research names as the single
worst mistake a developer can make.** Treating Early Access as a soft launch to test reception is
the first entry in a chapter titled "mistakes that cannot be taken back": the Steam algorithm treats
the EA launch *as the launch*, and the visibility keyed to that moment is spent. His prescribed
alternative for getting feedback — a beta, a Steam Playtest, or a demo — is exactly what ADR 23
already plans. We arrived at his recommendation independently.

**What ADR 23 lacks is an audience bar.** Its gate is quality-only. The research supplies numbers:

- **7,000 wishlists minimum** before an EA launch, which brackets neatly against the
  **7,000–10,000** needed for Steam's Popular Upcoming list.
- Correlation between EA-stage and 1.0-stage success is **0.75** across 2,313 games — strong.
- There is a documented **"valley of sadness"**: games sitting at 10–110 reviews a month after EA
  rarely recover. **80% of games that reached 1,000 reviews by 1.0 had at least 200 reviews in their
  first month of EA.**
- **Time spent in EA barely correlates with success (0.141).** A long, open-ended EA buys nothing by
  itself.

That last point cuts both ways for ADR 23's "sell axes, not features" roadmap: nothing punishes an
open-ended axis-based roadmap, but nothing rewards a long EA either. What decides the outcome is
month-one review count, which is decided by pre-EA wishlists, which is decided by how early the
store page went up.

EA done with discipline does outperform: median revenue **$2,847 for EA→1.0 versus $613** for a
normal launch, and among games with real traction (100+ reviews), **$77,000 versus $43,500**.

### ADR 6 — one map, and the store page

Lean scope parks extra maps for v1. The research turns that into a **gating condition rather than a
polish note**: his test for whether a game is ready for a store page lists **three distinct
environments**, because visual sameness across screenshots is the recognised signature of an
asset-flip, and shoppers are trained to spot it.

One warehouse means every screenshot is the same room. This is a genuine collision between a scope
decision and a store-page requirement, and it is a sequencing problem rather than a quality one.
Mitigations he offers — vary the UI state, vary what is happening in shot — are weaker when the
environment genuinely is identical.

---

## 3. The thing we are furthest behind on

**The Steam page is on the critical path and does not exist.** Valve's own data, cited repeatedly:
a Coming Soon page live **six or more months before launch correlates with 300% more sales** than
one posted 30 days out.

His trigger for creating it is not "the game is nearly finished" — it is that the art style is
settled and there is enough footage for a 30-second gameplay trailer. Add **three weeks** for Valve's
review, and months if a professional trailer editor is wanted.

Almost everything else compounds from that page existing: wishlist accumulation, Popular Upcoming
eligibility, Next Fest entry, creator outreach. And talking publicly about a game with no page, no
mailing list and no Discord is itself listed among the unrecoverable mistakes — if a post lands, the
traffic has nowhere to go and those wishlists never exist.

**A mailing list and a Discord should exist before any public posting**, and they cost nothing to
create. Build the audience on a channel we own, not one a platform can take away.

---

## 4. Numbers worth having written down

**Wishlist tiers at launch, with first-week conversion:**

| Tier | Wishlists | Conversion |
|---|---|---|
| Bronze | 5,000 | 11.93% |
| Silver | 8,000 | 20.49% |
| Gold | 50,000 | 25.35% |
| Diamond | 90,000 | 27.08% |

Weekly organic accrual at Bronze is 0–40 and at Silver 15–120, which is what sets the length of the
runway. Even highly anticipated games gather only around 300 wishlists a day. **10–12% of wishlists
get deleted as a matter of course** — it is not a signal.

**Other thresholds:**

- **Popular Upcoming:** 7,000–10,000 wishlists.
- **Next Fest:** enter the *last* one before launch, never the first available — visibility scales
  with the wishlists you bring in. Front-page featuring historically wanted 3,000–4,000 wishlists
  earned in the fortnight before; the ebook cites a much higher bar, and a 2023 festival saw the top
  cohort at 20,000. Treat this as competitive and rising, not fixed.
- **Demo featuring:** roughly 100 concurrent players. Easier to arrange deliberately for a co-op
  game via a Discord play session than for a single-player one.
- **Reviews:** ten unlocks the "Positive" badge. Free keys do not count toward it.
- **Discounting:** at least 20% at every opportunity, never below 20% for the first six months, then
  stairstep — shoppers are trained to wait for historic lows.

**One myth, corrected at source.** A widely repeated claim holds that Steam applies a hard 70%
"Mostly Positive" algorithmic threshold and that the first ten reviews carry an algorithmic boost.
Zukowski's own September 2023 article calls this a myth: games rated Mixed (40%+) receive equal
algorithmic treatment, and the ten-review boost does not exist. The badge is a **human**
click-through effect, which is a different and more modest mechanism.

---

## 5. Two things no decision currently covers

### The friend tax

For a 1–4 player co-op game, every additional player is another purchase. Split Fiction's "Friend's
Pass" — one buyer, friends play free — is a live counter-model, and nothing in `decisions/` mentions
it either way. There is also a claim in circulation (weaker sourcing, treat with care) that co-op
impulse pricing has a psychological cliff around the $10 mark, which would put $11.99 on the wrong
side of it.

Worth an explicit considered-and-rejected note if it is rejected, rather than silence.

### Where AI-assisted art can cap a ceiling

A documented case: the developer of *The Roottrees are Dead* concluded his game underperformed
because of its AI-generated art — his own market judgement, not a policy or a review-bombing event —
then spent roughly thirteen further months and hired an illustrator to replace it before a paid Steam
release that earned over $1M.

This does not map directly onto our pipeline: grid-critical geometry is hand-modelled, generated
assets are made on a paid tier with licences attached at generation time, and a Steam AI-content
disclosure at launch is already decided. But the case is specifically about **perceived visual
quality at the point of purchase**, which is the capsule, the trailer and the screenshots rather than
in-level geometry.

Which connects to the strongest single "spend money here" signal found:

**A capsule change alone took one game from 0–3 copies a day to 40–60** — roughly twentyfold, same
game, same page, nothing else altered. Commissioning one runs **$250–$1,000**, which at our price is
somewhere between 40 and 130 units to break even. Every source says the same thing: never make your
own capsule. It is currently the one asset the art pipeline plans to generate rather than commission.

---

## 6. Co-op specifically

Coverage here is thin and the sweep said so rather than padding it. What exists comes from his
Battlebit Remastered case study:

- **The cold start problem.** A multiplayer game only works when someone else is playing, so
  wishlists and concurrency are one funnel, not two. Battlebit took four years to reach 100
  concurrent players. **Our solo-viable design is a real structural hedge against this** — ADR 19's
  solo drag and SOLO-01 were argued on design grounds, and they happen to also mitigate the single
  worst marketing trap in the multiplayer category. Worth stating in any future marketing ADR.
- **Visual/mechanical mismatch is a named failure.** Battlebit *played* like a hardcore milsim and
  *looked* like Roblox, and buyers could not tell what it was. That is a live risk for a deliberately
  low-fidelity comedy that contains a genuinely deliberative dilemma system underneath.

Which leads to the sharpest positioning note in the research: **market the physics comedy, sell the
dilemma after purchase.** Every friend-slop success he cites hooks on instant, clippable chaos. The
patch/confess/comp pillar is slow and deliberative — it is what makes the game worth keeping, not
what makes someone click. The current one-line pitch names two lanes at once (chaotic physics comedy,
and a persistent business sim) and his taxonomy treats those as separate categories. Sharpening it to
one is a real piece of work and should happen before it has to go on a store page.

---

## 7. What this suggests, in order

Sequencing only. None of this is decided.

1. **Create a mailing list and a Discord before any public posting.** Free, and the alternative is
   losing traffic permanently.
2. **Commission the capsule professionally**, and treat it as the highest-return spend available.
3. **Decide when the store page goes up**, knowing the six-month figure and the three-environment
   gate. This likely argues for the page landing around the art pass rather than at the EA gate — a
   scheduling decision that touches ADR 23 and needs to be made deliberately.
4. **Give ADR 23 an audience bar** alongside its quality bar, if the wishlist evidence is accepted.
5. **Sequence demo → playtest → the last Next Fest before launch.** Never debut a demo at Next Fest.
6. **Re-read ADR 10** against $9.99 comparables and the underpricing argument.
7. **Rule on the friend tax**, either way.
8. **Track the genre clock as a project risk**, not a footnote.

---

## Sources

Everything below is Zukowski's site unless marked. Dates are publication dates.

**The golden age arc:** the founding piece (2025-11-04), the genre-cycle model that qualifies it
(2025-11-12), and the three case studies (2026-08-18, 2026-08-20, 2026-08-21).

**Pricing:** two 2022 articles on indie underpricing. **Early Access:** 2023-07-27 and 2023-08-21,
the latter built on 2,313 games. **Wishlists:** 2022-09-26 (updated June 2026), 2024-01-29, plus the
live benchmarks page. **Next Fest and demos:** 2023-08-16, 2024-07-31, 2025-08-26, 2026-04-13.
**Visibility and myths:** 2023-09-04, 2025-01-20. **Launch timing:** 2026-02-18, the article that
supersedes the ebook. **Multiplayer:** the Battlebit study, 2023-07-03. **Capsules:** 2020-04-13 and
2020-10-28. **Creator outreach:** 2025-09-16. **AI art:** 2025-04-28.

**The ebook:** *60 Game Marketing Mistakes And How To Avoid Them*, copyright 2023, obtained as a
mailing-list signup gift. Licence forbids reproduction, so it is excluded from this repo and only its
conclusions appear here.

**Not from this source, flagged as weaker:** a GameSpot piece on co-op impulse pricing that could not
be fetched directly, and genre price bandings that circulate on other marketing sites. Current Steam
prices for Lethal Company and REPO were verified independently.
