// Concrete scenarios through the exact Dilemma maths + candidate economy numbers.
const BASE = [0.0, 0.15, 0.45, 0.80], VW = 0.25, SW = 0.30, REF = 2000;
const CONFESS = [1.0, 0.40, 0.28, 0.15], REP_DAY = 90, TAPE = 15;
const vr = v => Math.min(v / REF, 1);
const pDet = (d, v, s) => Math.min(Math.max(BASE[Math.min(d, 3)] + VW * vr(v) + SW * s, 0.02), 0.95);
const caughtPen = (v, days) => -0.25 * (0.5 + vr(v)) * REP_DAY * days;
const evPatch = (v, d, s, days) => (1 - pDet(d, v, s)) * v + pDet(d, v, s) * caughtPen(v, days) - TAPE * d;
const evConfess = (v, t, days) => CONFESS[t] * v + 0.05 * REP_DAY * days;
const evComp = days => 0.15 * REP_DAY * days;
// settlement invoice: density x cells x daysStored x 1.35 bonuses, minus 30% advance on storage
const settle = (density, cells, stored) => density * cells * stored * 1.35 - 0.3 * density * cells * stored;

function show(name, v, tier, susp, daysLeft) {
  const p = evPatch(v, tier, susp, daysLeft), c = evConfess(v, tier, daysLeft), k = evComp(daysLeft);
  const best = c >= p && c >= k ? 'CONFESS' : k >= p ? 'COMP' : 'PATCH';
  console.log(`${name}\n  stake £${v.toFixed(0)}, tier ${tier}, suspicion ${susp}, ${daysLeft} days left`
    + ` | detect ${(pDet(tier, v, susp) * 100).toFixed(0)}%`
    + `\n  patch £${p.toFixed(0)}  confess £${c.toFixed(0)}  comp £${k.toFixed(0)}  -> ${best}\n`);
}

console.log('=== 1. Same crate, same scuff, opposite answers ===');
const glass = settle(35, 1, 6); // delicate, 1 cell, 6 days stored
show('Day 4 of a 30-day lease (26 left):', glass, 1, 0.2, 26);
show('Day 9 of a 10-day lease (1 left):', glass, 1, 0.2, 1);

console.log('=== 2. The eviction-night gamble ===');
const talc = settle(70, 1, 8); // precious, 8 days stored, DAMAGED (tier 2)
show('Final day, suspicion 0.35:', talc, 2, 0.35, 0);
console.log(`  rent due tonight (solo, day 10/10): £${(900 * 0.5 * (0.7 + 0.6)).toFixed(0)}`
  + `\n  confess pays £${(0.28 * talc).toFixed(0)} -> evicted with certainty`
  + `\n  patch: ${(100 - pDet(2, talc, 0.35) * 100).toFixed(0)}% chance of £${talc.toFixed(0)} -> survival\n`);

console.log('=== 3. The confess-cheap tactic ===');
const cheap = settle(8, 1, 2); // bulk scuff: tiny stake
const expensive = settle(70, 1, 10);
const before = evPatch(expensive, 1, 0.35, 12), after = evPatch(expensive, 1, 0.35 - 0.08, 12);
console.log(`Confess a £${cheap.toFixed(0)} bulk scuff (forgo £${(0.6 * cheap).toFixed(0)}), suspicion 0.35 -> 0.27.`
  + `\nNext week's £${expensive.toFixed(0)} precious patch EV: £${before.toFixed(0)} -> £${after.toFixed(0)} (+£${(after - before).toFixed(0)})\n`);

console.log('=== 4. The portfolio, per cell over 5 days ===');
for (const [n, d, f] of [['bulk', 8, '5%'], ['standard', 18, '10%'], ['delicate', 35, '22%'], ['precious', 70, '15%']])
  console.log(`  ${n}: invoice £${(d * 5 * 1.35).toFixed(0)} (fragility ${f})`);

console.log('\n=== 5. Rent schedule, 4p 10-day (base 900) ===');
console.log([1, 3, 5, 8, 10].map(d => `d${d}: £${(900 * (0.7 + 0.6 * d / 10)).toFixed(0)}`).join('  '));
