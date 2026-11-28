// Headless soak test:  node tools/headless.js [days] [seed]
require('../js/data.js'); require('../js/sim.js');
const { Sim, CONST } = BC;
const days = +process.argv[2] || 150, seed = +process.argv[3] || 1;
const sim = new Sim(seed);
const t0 = Date.now();
let steps = 0;
function check() {
  for (const c of sim.civs) {
    for (const k in c.stock) if (!Number.isFinite(c.stock[k])) throw new Error(`NaN stock ${c.name}.${k}`);
    for (const x of c.citizens) if (!Number.isFinite(x.x + x.y)) throw new Error('NaN citizen pos');
  }
}
while (sim.day <= days) { sim.step(1 / 30); steps++; if (steps % 300 === 0) check(); }
check();
console.log(`seed ${seed}: simulated ${days} days (${steps} steps) in ${Date.now() - t0}ms, ${(steps / ((Date.now() - t0) / 1000) / 30).toFixed(0)}x realtime`);
for (const c of sim.civs) {
  const s = c.stats;
  console.log(c.name.padEnd(12), 'pop', String(c.citizens.length).padStart(3), 'food', String(Math.round(c.stock.food)).padStart(4),
    'gold', String(Math.round(c.stock.gold)).padStart(4), 'tech', c.tech, 'b/h', s.births + '/' + s.hybridBirths,
    'raids', s.raids, 'def', s.defended, 'trades', s.trades, 'k/l', s.kills + '/' + s.losses, 'war', Object.keys(c.war).length);
}
console.log('world', sim.stats, 'pop', sim.totalPop());
const kinds = {}; sim.events.forEach(e => kinds[e.kind] = (kinds[e.kind] || 0) + 1); console.log('recent events', kinds);
