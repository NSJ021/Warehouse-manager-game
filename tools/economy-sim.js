// Nice Little Earner — first-pass economy skeleton simulation.
// Everything locked by ADRs is taken verbatim (marked ADR); everything else is
// the candidate number this sim exists to test (marked CAND).
//
// Frame: an item's "value" in the Dilemma (£50–£2000 sweep envelope) is read as
// its INVOICE — storage fees accrued over its stay plus bonuses, settled at
// handover. That makes long-stored precious cargo the £2000 case and makes the
// dilemma stake grow the longer something has sat on your racks.

// ---------- ADR-locked constants (Dilemma.gd, ADR 20 amended) ----------
const DETECTION_BY_DEPTH = [0.0, 0.15, 0.45, 0.80];
const VALUE_WEIGHT = 0.25, SUSPICION_WEIGHT = 0.30, VALUE_REFERENCE = 2000;
const DETECTION_FLOOR = 0.02, DETECTION_CEILING = 0.95;
const CONFESS_PAYOUT_BY_TIER = [1.0, 0.40, 0.28, 0.15];
const CONFESS_REP = 0.05, CONFESS_SUSP = -0.08;
const CAUGHT_REP = -0.25, CAUGHT_SUSP = 0.25, CAUGHT_VALUE_FLOOR = 0.5;
const COMP_REP = 0.15, COMP_SUSP = -0.10;
const REP_TO_CASH_PER_DAY = 90;
const TAPE_COST_PER_TIER = 15;

const vr = v => Math.min(Math.max(v / VALUE_REFERENCE, 0), 1);
function detectionChance(depth, value, susp) {
  if (depth <= 0) return 0;
  const d = Math.min(Math.max(depth, 1), 3);
  return Math.min(Math.max(
    DETECTION_BY_DEPTH[d] + VALUE_WEIGHT * vr(value) + SUSPICION_WEIGHT * Math.min(Math.max(susp, 0), 1),
    DETECTION_FLOOR), DETECTION_CEILING);
}
const repValue = days => REP_TO_CASH_PER_DAY * Math.max(days, 0);

// ---------- CAND: the skeleton under test ----------
const DAY_MINUTES = 8;                       // GDD locks 6–10; nominal midpoint-ish
const MOVES_PER_PLAYER_DAY = 15;             // carries/drags per player per 8-min day
const CREW_EFFICIENCY = 0.85;                // coordination loss
const CELLS_TOTAL = 72;                      // ~6 racks of 12 (map assumption)

// Value density: £ per cell per day (GDD §6: the portfolio decision)
const CLASSES = {
  bulk:     { density: 8,  weight: 0.35, fragile: 0.05 },
  standard: { density: 18, weight: 0.35, fragile: 0.10 },
  delicate: { density: 35, weight: 0.20, fragile: 0.22 },
  precious: { density: 70, weight: 0.10, fragile: 0.15 },
};
const DELIVERY_BONUS = 0.25;                 // on-time, share of storage fees
const CONDITION_BONUS = 0.10;                // pristine at handover
const LATE_PENALTY = 0.20;                   // share of invoice, plus the rep hit

// Rent: per day, 4-player baseline; scaled by crew size. 10-day carries a
// short-lease premium — that is what "brutal relative to income" cashes out as.
const RENT_4P = { 10: 900, 30: 550 };
const rentScale = p => 0.5 + (0.5 / 3) * (p - 1);  // 1p:0.5  2p:0.67  3p:0.83  4p:1.0 — "not enough to be comfortable"
// Rent escalates through the lease: soft opening days while the pipeline fills,
// expensive final days when reputation is nearly worthless — the schedule itself
// pushes toward ADR 20's late-lease gamble. Averages ~1.0 over the term.
const rentOnDay = (base, day, term) => base * (0.7 + 0.6 * day / term);
const SUPPLIES_PER_DAY = 20;
const STARTING_CASH = 500;

// Manifest generation: offered lots per day scale with crew (quotas scale, GDD §9)
const OFFER_CELLS_BASE = 2, OFFER_CELLS_PER_PLAYER = 2;

// Cash-flow shape fixes (found by run 1: universal day-1 eviction):
// clients pay a share of projected storage on arrival; the rest, plus bonuses,
// settles at handover — the settlement is what the dilemma puts at stake.
const INTAKE_ADVANCE = 0.30;
// The previous leaseholder's backlog is still racked when the lease starts, so
// collections exist from day 1. Share of capacity, staggered due dates.
const OPENING_STOCK_SHARE = 0.35;

// Damage: chance an item takes damage at some point in its life (handling+time)
const DAMAGE_PER_LIFECYCLE = 0.12;
const SEVERITY = [[1, 0.70], [2, 0.25], [3, 0.05]]; // tier: scuff/damaged/destroyed

// ---------- simulation ----------
function mulberry(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

function pickClass(rng) {
  let r = rng(), acc = 0;
  for (const [name, c] of Object.entries(CLASSES)) { acc += c.weight; if (r <= acc) return name; }
  return 'bulk';
}
function severity(rng) { let r = rng(), acc = 0; for (const [t, w] of SEVERITY) { acc += w; if (r <= acc) return t; } return 1; }

// Playstyles decide the fork when damage exists at handover.
// 'ev' follows Dilemma.best_choice (the model's own recommendation).
// 'honest' always confesses. 'fraud' always patches. 'comp' always comps if stock allows, else confesses.
function decide(style, invoice, tier, susp, daysLeft) {
  if (style === 'honest') return 'confess';
  if (style === 'fraud') return 'patch';
  if (style === 'comp') return 'comp';
  const pCaught = detectionChance(tier, invoice, susp);
  const caughtPenalty = CAUGHT_REP * (CAUGHT_VALUE_FLOOR + vr(invoice)) * repValue(daysLeft);
  const evPatch = (1 - pCaught) * invoice + pCaught * caughtPenalty - TAPE_COST_PER_TIER * tier;
  const evConfess = CONFESS_PAYOUT_BY_TIER[tier] * invoice + CONFESS_REP * repValue(daysLeft);
  const evComp = 0 + COMP_REP * repValue(daysLeft); // like-for-like nets zero cash
  if (evConfess >= evPatch && evConfess >= evComp) return 'confess';
  if (evComp >= evPatch) return 'comp';
  return 'patch';
}

function simulate({ players, term, style, seed }) {
  const rng = mulberry(seed);
  let cash = STARTING_CASH, rep = 0, susp = 0;
  const rent = RENT_4P[term] * rentScale(players);
  const movesPerDay = Math.floor(MOVES_PER_PLAYER_DAY * players * CREW_EFFICIENCY);
  let stored = []; // {class, cells, stay, dayIn, due}
  // Opening stock: inherited lots, no advance owed to us on them (the previous
  // tenant took it), but their settlements land in the first days.
  const openingLots = Math.round(CELLS_TOTAL * OPENING_STOCK_SHARE);
  for (let i = 0; i < openingLots; i++) {
    const cls = pickClass(rng);
    stored.push({ class: cls, cells: 1, dayIn: 1 - Math.floor(rng() * 4), due: 1 + Math.floor(rng() * 5), inherited: true });
  }
  let evictedDay = 0, totalIncome = 0, totalDamageIncidents = 0;
  const forks = { patch: 0, confess: 0, comp: 0, caught: 0 };
  const daily = [];

  for (let day = 1; day <= term; day++) {
    let movesLeft = movesPerDay;
    let income = 0, outgoings = 0;

    // 1) Departures first (collections are the day's obligation)
    const dueToday = stored.filter(s => s.due <= day);
    stored = stored.filter(s => s.due > day);
    for (const lot of dueToday) {
      if (movesLeft < lot.cells) { // could not haul it to Goods OUT in time → late
        lot.due = day + 1; stored.push(lot);
        income -= LATE_PENALTY * lotInvoice(lot, day) / 2; rep -= 0.03;
        continue;
      }
      movesLeft -= lot.cells;
      const invoice = lotInvoice(lot, day);
      // damage roll for its whole lifecycle, resolved at handover
      if (rng() < DAMAGE_PER_LIFECYCLE) {
        totalDamageIncidents++;
        const tier = severity(rng);
        const daysLeft = term - day;
        const fork = decide(style, invoice, tier, susp, daysLeft);
        forks[fork]++;
        if (fork === 'patch') {
          outgoings += TAPE_COST_PER_TIER * tier;
          if (rng() < detectionChance(tier, invoice, susp)) {
            forks.caught++; rep += CAUGHT_REP * (CAUGHT_VALUE_FLOOR + vr(invoice)); susp = Math.min(1, susp + CAUGHT_SUSP);
          } else income += invoice;
        } else if (fork === 'confess') {
          income += CONFESS_PAYOUT_BY_TIER[tier] * invoice;
          rep += CONFESS_REP; susp = Math.max(0, susp + CONFESS_SUSP);
        } else { // comp: like-for-like nets zero, big rep
          rep += COMP_REP; susp = Math.max(0, susp + COMP_SUSP);
        }
      } else income += invoice;
    }

    // 2) Arrivals: offers scale with crew and reputation; capped by moves and space
    const cellsFree = CELLS_TOTAL - stored.reduce((a, s) => a + s.cells, 0);
    const repMult = Math.min(1.5, Math.max(0.5, 1 + 0.15 * rep));
    // The manifest wants you working: offers track the crew's physical day
    // (each cell costs ~2 moves across its life), so the day clock binds and
    // the warehouse actually fills. Quota pressure, not idle hands.
    let offer = Math.round(0.35 * movesPerDay * repMult);
    offer = Math.min(offer, movesLeft, cellsFree);
    for (let i = 0; i < offer; i++) {
      const cls = pickClass(rng);
      const stay = term === 10 ? 2 + Math.floor(rng() * 5) : 3 + Math.floor(rng() * 8);
      const lot = { class: cls, cells: 1, dayIn: day, due: Math.min(day + stay, term) };
      stored.push(lot);
      movesLeft -= 1;
      // Advance on the projected storage component, paid on intake
      income += INTAKE_ADVANCE * CLASSES[cls].density * lot.cells * (lot.due - lot.dayIn);
    }

    // 3) CLOSE: rent and supplies
    outgoings += rentOnDay(rent, day, term) + SUPPLIES_PER_DAY;
    cash += income - outgoings;
    totalIncome += income;
    daily.push({ day, income: Math.round(income), out: Math.round(outgoings), cash: Math.round(cash), cells: stored.reduce((a, s) => a + s.cells, 0) });
    if (cash < 0 && !evictedDay) { evictedDay = day; break; }
  }
  return { players, term, style, evictedDay, cash: Math.round(cash), rep: +rep.toFixed(2), susp: +susp.toFixed(2), forks, totalDamageIncidents, daily };

  // The settlement due at handover: full invoice less any advance already paid.
  // This is the figure the dilemma puts at stake.
  function lotInvoice(lot, day) {
    const days = Math.max(day - lot.dayIn, 1);
    const storage = CLASSES[lot.class].density * lot.cells * days;
    const invoice = storage * (1 + DELIVERY_BONUS + CONDITION_BONUS);
    const advance = lot.inherited ? 0 : INTAKE_ADVANCE * CLASSES[lot.class].density * lot.cells * (lot.due - lot.dayIn);
    return Math.max(invoice - advance, 0);
  }
}

// ---------- runs ----------
const rows = [];
for (const term of [10, 30])
  for (const players of [1, 2, 4])
    for (const style of ['ev', 'honest', 'fraud', 'comp']) {
      // average 5 seeds to smooth the damage RNG
      let agg = null;
      for (let s = 1; s <= 5; s++) {
        const r = simulate({ players, term, style, seed: s * 7919 + term * 13 + players });
        if (!agg) agg = { ...r, cash: 0, evictions: 0 };
        agg.cash += r.cash / 5;
        if (r.evictedDay) agg.evictions++;
      }
      rows.push({ term, players, style, avgFinalCash: Math.round(agg.cash), evictions: agg.evictions + '/5' });
    }
console.table(rows);

// One detailed honest 4p/10d run for the daily shape
const detail = simulate({ players: 4, term: 10, style: 'ev', seed: 42 });
console.log('4p 10-day (ev) daily:', detail.daily.map(d => `d${d.day}: +${d.income}-${d.out}=£${d.cash} (${d.cells} cells)`).join('  '));
console.log('forks:', detail.forks, 'rep:', detail.rep, 'susp:', detail.susp);

// Solo detail
const solo = simulate({ players: 1, term: 10, style: 'ev', seed: 42 });
console.log('1p 10-day (ev) daily:', solo.daily.map(d => `d${d.day}: £${d.cash}`).join('  '));

// Invoice envelope check against the dilemma sweep (£50–£2000)
console.log('\nInvoice envelope (storage × stay × 1.35):');
for (const [name, c] of Object.entries(CLASSES))
  console.log(`  ${name}: 1 cell, 2d = £${Math.round(c.density * 2 * 1.35)}  |  10d = £${Math.round(c.density * 10 * 1.35)}  |  large(2 cells), 12d = £${Math.round(c.density * 2 * 12 * 1.35)}`);
