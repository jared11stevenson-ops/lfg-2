// Headless simulation of interconnected bottle civilizations. No DOM access here.
(function (g) {
  const BC = (g.BC = g.BC || {});
  const { RES, RACES, SEALED, GRID } = BC.DATA;

  const DAY_LEN = 100;      // sim seconds per full day
  const DUSK = 0.72;        // fraction of the day at which jars lock
  const TRAVEL = 12;        // seconds to cross a link
  const DECISIONS = [0.0, 0.28, 0.5];
  const JAR_W = 200, JAR_H = 150;
  const SITES = {           // jar-local work sites
    farm: [38, 98], wood: [40, 42], mine: [162, 44], craft: [152, 92],
    study: [100, 36], trade: [100, 90], soldier: [96, 62],
  };
  const ROLE_RES = { farm: 'food', wood: 'wood', mine: 'ore', craft: 'goods', study: 'lore', trade: 'gold' };
  const RAIDER_MIN = 3;

  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  class Sim {
    constructor(seed) {
      this.seed = seed == null ? (Math.random() * 1e9) | 0 : seed;
      this.rand = mulberry32(this.seed);
      this.day = 1; this.clock = 0;       // clock: seconds into the day
      this.locked = false;
      this.nextId = 1;
      this.events = []; this.parties = []; this.civs = [];
      this.decisionsDone = 0;
      this.stats = { battles: 0, trades: 0, hybrids: 0, envoys: 0, spies: 0 };
      RACES.forEach((r, i) => this.civs.push(this.makeCiv(r, i)));
      this.links = this.makeLinks();
      this.civs.forEach(c => { c.links = this.links.filter(l => l.a === c.id || l.b === c.id).map(l => (l.a === c.id ? l.b : l.a)); });
      this.initRelations();
      this.assignRoles(true);
      this.log(`Twelve jars sit on the shelf. Ten are awake; two stay sealed.`, 'sys');
    }
    get t() { return this.clock / DAY_LEN; }
    r() { return this.rand(); }
    rr(a, b) { return a + (b - a) * this.rand(); }
    pick(arr) { return arr[Math.floor(this.rand() * arr.length)]; }

    log(text, kind, civs) {
      this.events.push({ day: this.day, t: this.t, text, kind: kind || 'info', civs: civs || [] });
      if (this.events.length > 300) this.events.shift();
    }

    makeCiv(race, id) {
      const c = {
        id, race, slot: id, name: race.jar, alive: true, citizens: [], links: [], rel: {}, war: {},
        stock: { food: 40, wood: 25, ore: 15, goods: 10, lore: 0, gold: 12 },
        houses: 3, tech: 0, flash: null, flashT: 0, posture: 'peace',
        stats: { births: 0, hybridBirths: 0, deaths: 0, kills: 0, losses: 0, raids: 0, defended: 0, trades: 0, envoys: 0, plunder: 0, raised: 0 },
        roleCount: {}, launches: 0,
      };
      const n = 14;
      for (let i = 0; i < n; i++) this.spawnCitizen(c, { [id]: 1 }, this.rr(3, race.traits.lifespan * 0.5));
      return c;
    }

    makeLinks() {
      const live = this.civs.length, links = [], { cols } = GRID;
      const at = (x, y) => (x < 0 || y < 0 || x >= cols || y >= 3 ? -1 : y * cols + x);
      const seen = new Set();
      for (let i = 0; i < live; i++) {
        const x = i % cols, y = Math.floor(i / cols);
        for (const [dx, dy] of [[1, 0], [0, 1], [1, 1], [-1, 1]]) {
          const j = at(x + dx, y + dy);
          if (j < 0 || j >= live) continue;
          const key = Math.min(i, j) + '-' + Math.max(i, j);
          if (seen.has(key)) continue; seen.add(key);
          links.push({ a: i, b: j });
        }
      }
      return links;
    }

    initRelations() {
      for (const a of this.civs) for (const b of this.civs) {
        if (a === b) continue;
        a.rel[b.id] = clamp(this.baseRel(a, b) + this.rr(-12, 12), -90, 90);
      }
    }
    baseRel(a, b) {
      let v = 0;
      if (a.race.like.includes(b.race.id)) v += 35;
      if (a.race.dislike.includes(b.race.id)) v -= 35;
      if (b.race.like.includes(a.race.id)) v += 15;
      if (b.race.dislike.includes(a.race.id)) v -= 15;
      return v;
    }

    // ---------- citizens ----------
    spawnCitizen(civ, blood, age, loc) {
      const home = this.houseSpot(civ);
      const c = {
        id: this.nextId++, home: civ.id, loc: loc == null ? civ.id : loc, blood, age,
        role: 'child', x: home[0], y: home[1], tx: home[0], ty: home[1], timer: this.rr(0, 4),
        state: 'idle', hp: 1, face: 1, xp: 0, lifeMul: this.rr(0.8, 1.2), party: null, hidden: false,
      };
      civ.citizens.push(c);
      return c;
    }
    houseSpot(civ) {
      const n = civ.houses || 1;
      const i = Math.floor(this.rand() * n);
      return [14 + ((i % 8) * 24) % 172 + 8, 124 + (Math.floor(i / 8) % 2) * 12];
    }
    dominant(c) {
      let best = null, bv = -1;
      for (const k in c.blood) if (c.blood[k] > bv) { bv = c.blood[k]; best = +k; }
      return best;
    }
    isHybrid(c) { return c.blood[this.dominant(c)] < 0.93; }
    mixedMult(c, key) {
      let v = 0;
      for (const k in c.blood) v += c.blood[k] * RACES[k].mult[key];
      return v * (this.isHybrid(c) ? 1.06 : 1);
    }
    isAdult(c) { return c.age >= 2; }
    mightOf(c) {
      let hp = 0;
      for (const k in c.blood) hp += c.blood[k] * (RACES[k].hp || 1);
      return this.mixedMult(c, 'might') * (0.75 + 0.25 * Math.min(2, 1 + c.xp)) * (0.6 + 0.4 * hp);
    }
    removeCitizen(c, cause) {
      const civ = this.civs[c.home];
      const i = civ.citizens.indexOf(c);
      if (i >= 0) civ.citizens.splice(i, 1);
      if (c.party) { const j = c.party.members.indexOf(c); if (j >= 0) c.party.members.splice(j, 1); }
      civ.stats.deaths++;
      c.dead = cause || 'dead';
    }

    // ---------- main loop ----------
    step(dt) {
      dt = Math.min(dt, 0.25);
      const prevClock = this.clock;
      this.clock += dt;
      if (this.clock >= DAY_LEN) { this.clock -= DAY_LEN; this.newDay(); }
      if (!this.locked && this.t >= DUSK) this.lockJars();
      // decision windows
      if (!this.locked) {
        while (this.decisionsDone < DECISIONS.length && this.t >= DECISIONS[this.decisionsDone]) {
          this.decisionsDone++;
          this.decide();
        }
      }
      this.updateParties(dt);
      this.updateCitizens(dt);
      for (const c of this.civs) if (c.flashT > 0) c.flashT -= dt;
    }

    // ---------- dawn ----------
    newDay() {
      // release locked jars first
      this.locked = false;
      this.day++;
      this.decisionsDone = 0;
      for (const c of this.civs) c.launches = 0;
      this.dawnBirths();
      for (const p of this.parties) if (p.state === 'guest') { p.state = 'back'; p.p = 1; p.dir = -1; this.releaseGuests(p); }
      for (const c of this.civs) {
        const grow = c.citizens.length;
        // age & eat
        const eat = c.race.eats == null ? 1 : c.race.eats;
        for (const cit of c.citizens.slice()) {
          cit.age += 1;
          if (cit.age > this.lifespan(cit) * cit.lifeMul && this.r() < 0.5) {
            this.removeCitizen(cit, 'age');
            if (c.race.id !== 'skeleton') this.log(`${c.name}: an elder of the ${c.race.name} passed away.`, 'death', [c.id]);
          }
        }
        let need = 0;
        for (const cit of c.citizens) need += this.isAdult(cit) ? eat : eat * 0.5;
        c.stock.food -= need;
        if (c.stock.food < 0) {
          const starve = Math.min(c.citizens.length - 2, Math.ceil(-c.stock.food / 3), Math.ceil(c.citizens.length * 0.2));
          c.stock.food = 0;
          if (starve > 0) {
            for (let i = 0; i < starve; i++) {
              const v = this.pick(c.citizens);
              if (v && c.citizens.length > 2) this.removeCitizen(v, 'starved');
            }
            this.log(`${c.name} starves: ${starve} of the ${c.race.name} died of hunger.`, 'death', [c.id]);
          }
        }
        // lore -> tech
        const nt = Math.floor(Math.sqrt(c.stock.lore / 8) * (c.race.techBonus || 1));
        if (nt > c.tech) { c.tech = nt; this.log(`${c.name} reaches tech level ${nt}.`, 'tech', [c.id]); }
        // build houses
        if (c.houses < 9 && c.citizens.length >= this.capacity(c) - 3 && c.stock.wood >= 14 && c.stock.goods >= 6) {
          c.stock.wood -= 14; c.stock.goods -= 6; c.houses++;
        }
        // brewing ogres: surplus grain -> gold
        if (c.race.brew && c.stock.food > c.citizens.length * 6) { c.stock.food -= 10; c.stock.gold += 6; }
        // wanderers drift in to struggling jars; skeletons assemble new bodies at their crypt
        const popNow = c.citizens.length;
        if (c.race.raiseDead) {
          if (c.stock.ore >= 3 && popNow < this.capacity(c) && this.r() < Math.min(0.85, 0.2 + popNow * 0.04)) {
            c.stock.ore -= 3; this.spawnCitizen(c, { [c.id]: 1 }, 3); c.stats.births++;
          }
        } else if (popNow < this.capacity(c) * 0.45 && c.stock.food > 6 && this.r() < 0.6) {
          this.spawnCitizen(c, { [c.id]: 1 }, 3);
          if (popNow < 5) this.log(`Wanderers settle in ${c.name}.`, 'sys', [c.id]);
        }
        if (popNow < 2) { this.spawnCitizen(c, { [c.id]: 1 }, 3); this.spawnCitizen(c, { [c.id]: 1 }, 3); }
        // relations drift & war timers
        for (const o of this.civs) {
          if (o === c) continue;
          c.rel[o.id] += (this.baseRel(c, o) - c.rel[o.id]) * 0.04;
          if (c.war[o.id] != null && this.day >= c.war[o.id]) {
            delete c.war[o.id]; delete o.war[c.id];
            c.rel[o.id] = Math.max(c.rel[o.id], -10); o.rel[c.id] = Math.max(o.rel[c.id], -10);
            this.log(`${c.name} and ${o.name} agree to a truce.`, 'peace', [c.id, o.id]);
          }
        }
        c.stats.births += 0;
        void grow;
      }
      this.assignRoles(false);
      this.log(`Day ${this.day} dawns. The jars unlock.`, 'sys');
    }
    lifespan(cit) {
      let v = 0;
      for (const k in cit.blood) v += cit.blood[k] * RACES[k].traits.lifespan;
      return v;
    }
    capacity(c) { return 12 + c.houses * 4; }

    dawnBirths() {
      for (const c of this.civs) {
        if (!c.pendingBirths || !c.pendingBirths.length) continue;
        for (const b of c.pendingBirths) {
          const target = this.civs[b.home];
          const baby = this.spawnCitizen(target, b.blood, 0, b.home);
          target.stats.births++;
          if (b.hybrid) { target.stats.hybridBirths++; this.stats.hybrids++; this.log(`A hybrid child of ${RACES[b.a].name} and ${RACES[b.b].name} is born in ${target.name}.`, 'birth', [b.a, b.b]); }
          void baby;
        }
        c.pendingBirths = [];
      }
      // natural births (settled over the night)
      for (const c of this.civs) {
        if (c.race.traits.fertility <= 0) continue;
        const adults = c.citizens.filter(x => this.isAdult(x) && x.loc === c.id);
        const room = this.capacity(c) - c.citizens.length;
        if (room <= 0 || c.stock.food < c.citizens.length * 1.5) continue;
        let births = 0;
        const pairs = Math.floor(adults.length / 2);
        for (let i = 0; i < pairs && births < room; i++) if (this.r() < c.race.traits.fertility * 1.6) births++;
        for (let i = 0; i < births; i++) {
          const a = this.pick(adults);
          this.spawnCitizen(c, Object.assign({}, a.blood), 0);
          c.stats.births++;
        }
      }
    }

    assignRoles(initial) {
      for (const c of this.civs) {
        const adults = c.citizens.filter(x => this.isAdult(x));
        for (const x of c.citizens) if (!this.isAdult(x)) x.role = 'child';
        const n = adults.length;
        if (!n) continue;
        const hunger = c.stock.food < c.citizens.length * 3 ? 2.6 : (c.stock.food > c.citizens.length * 8 ? 0.55 : 1);
        const m = {};
        for (const k of Object.keys(c.race.mult)) m[k] = c.race.mult[k];
        const atWar = Object.keys(c.war).length > 0;
        const wBuild = c.stock.wood < 20 ? 1.6 : 1;
        const w = {
          farm: 1.9 * m.food * hunger,
          wood: 0.9 * m.wood * wBuild,
          mine: 0.9 * m.ore,
          craft: 0.8 * m.goods,
          study: 0.7 * m.lore,
          trade: 0.55 * m.gold,
          soldier: (0.25 + c.race.traits.aggression * 0.9 * (c.race.soldierShare ? 1.4 : 1)) * (atWar ? 1.6 : 1) * m.might,
        };
        if (c.race.id === 'skeleton') w.farm = 0.4;
        const sum = Object.values(w).reduce((a, b) => a + b, 0);
        const quota = {}; let left = n; const rema = [];
        for (const k in w) { const q = (w[k] / sum) * n; quota[k] = Math.floor(q); left -= quota[k]; rema.push([k, q - quota[k]]); }
        rema.sort((a, b) => b[1] - a[1]);
        for (let i = 0; i < left; i++) quota[rema[i % rema.length][0]]++;
        // keep at least 1 farmer unless skeleton
        if (!quota.farm && c.race.id !== 'skeleton') { quota.farm = 1; const big = Object.keys(quota).sort((a, b) => quota[b] - quota[a])[0]; if (big !== 'farm') quota[big]--; }
        // assign: stay where possible
        const free = [];
        const cnt = {};
        for (const a of adults) {
          if (!initial && quota[a.role] > (cnt[a.role] || 0)) cnt[a.role] = (cnt[a.role] || 0) + 1;
          else free.push(a);
        }
        for (const k in quota) {
          while ((cnt[k] || 0) < quota[k] && free.length) {
            const a = free.pop(); a.role = k; cnt[k] = (cnt[k] || 0) + 1;
          }
        }
        for (const a of free) a.role = 'farm';
        c.roleCount = cnt;
        for (const a of adults) this.setWork(a);
      }
    }
    setWork(a) {
      const s = SITES[a.role] || [100, 116];
      a.tx = s[0] + this.rr(-14, 14); a.ty = s[1] + this.rr(-10, 10);
      a.state = 'walk'; a.timer = this.rr(2, 6);
    }

    // ---------- AI ----------
    surplus(c) {
      const n = c.citizens.length;
      return { food: c.stock.food - n * 4, wood: c.stock.wood - 25, ore: c.stock.ore - 20, goods: c.stock.goods - 14, lore: -999, gold: -999 };
    }
    soldiers(c) { return c.citizens.filter(x => x.role === 'soldier' && x.loc === c.id && !x.party); }
    power(list) { let p = 0; for (const x of list) p += this.mightOf(x); return p; }

    decide() {
      const order = this.civs.slice().sort(() => this.r() - 0.5);
      for (const c of order) {
        if (c.launches >= 1 && this.r() < 0.6) continue;
        const choices = [{ w: 0.9, act: 'none' }];
        const soldiers = this.soldiers(c);
        const myPow = this.power(soldiers);
        const mySur = this.surplus(c);
        for (const jId of c.links) {
          const o = this.civs[jId];
          if (this.parties.some(p => p.from === c.id && p.to === jId && p.state !== 'done')) continue;
          const rel = c.rel[jId];
          const atWar = c.war[jId] != null;
          const theirPow = this.power(this.civs[jId].citizens.filter(x => x.role === 'soldier' && x.loc === jId)) + 0.2 * o.citizens.length;
          // trade
          const oSur = this.surplus(o);
          let give = null, take = null, gv = 6, tv = 6;
          for (const r of RES) { if (mySur[r] > gv) { gv = mySur[r]; give = r; } }
          for (const r of RES) { if (r !== give && oSur[r] > tv) { tv = oSur[r]; take = r; } }
          if (!atWar && rel > -30) {
            const wt = (give && take ? 0.5 : 0.08) + c.race.traits.openness * 0.7 + c.race.traits.greed * 0.4 + (c.race.tradeBonus ? 0.6 : 0) + rel / 150;
            choices.push({ w: Math.max(0.02, wt), act: 'trade', to: jId, give, take });
          }
          // raid
          if (this.day >= 4 && soldiers.length >= RAIDER_MIN && o.citizens.length >= 8 && !(c.lastRaid && c.lastRaid[jId] === this.day) && !(o.war[c.id] == null && o.citizens.length < c.citizens.length * 0.35)) {
            const ratio = clamp(myPow / Math.max(2, theirPow), 0.3, 2.5);
            const hostile = rel < 20 ? 1 : 0.12;
            const need = (c.stock.food < c.citizens.length * 3 ? 0.5 : 0) + (c.race.traits.greed > 0.6 ? 0.2 : 0);
            const wt = c.race.traits.aggression * 0.95 * ratio * hostile * (atWar ? 1.8 : 1) + need * hostile;
            if (wt > 0.04) choices.push({ w: wt, act: 'raid', to: jId });
          }
          // envoy / marriage party
          if (!atWar && rel > -10 && c.race.traits.fertility > 0 && o.race.traits.fertility > 0) {
            const wt = c.race.traits.openness * (rel > 10 ? 0.9 : 0.25) * (c.race.charm || 1) * (o.race.like.includes(c.race.id) ? 1.3 : 0.8);
            choices.push({ w: wt, act: 'envoy', to: jId });
          }
          // spy
          if (c.race.spy && rel < 60) choices.push({ w: 0.5 + c.race.traits.greed * 0.4, act: 'spy', to: jId });
        }
        let total = 0; for (const ch of choices) total += ch.w;
        let roll = this.r() * total, chosen = choices[0];
        for (const ch of choices) { roll -= ch.w; if (roll <= 0) { chosen = ch; break; } }
        if (chosen.act !== 'none') { this.launch(c, chosen); c.launches++; }
      }
    }

    pickMembers(c, role, n) {
      const pool = c.citizens.filter(x => x.loc === c.id && !x.party && this.isAdult(x) && (!role || x.role === role));
      pool.sort(() => this.r() - 0.5);
      return pool.slice(0, n);
    }

    launch(c, a) {
      const o = this.civs[a.to];
      let members = [], cargo = {};
      if (a.act === 'trade') {
        members = this.pickMembers(c, 'trade', 2); if (!members.length) members = this.pickMembers(c, null, 2);
        if (a.give) { const amt = Math.min(c.stock[a.give], Math.max(5, Math.floor(this.surplus(c)[a.give] * 0.6))); c.stock[a.give] -= amt; cargo[a.give] = amt; }
        cargo.wantRes = a.take;
      } else if (a.act === 'raid') {
        const s = this.soldiers(c); s.sort((x, y) => this.mightOf(y) - this.mightOf(x));
        const k = clamp(Math.ceil(s.length * 0.7), RAIDER_MIN, 9);
        members = s.slice(0, k);
        if (c.war[a.to] == null) { c.war[a.to] = this.day + 3; o.war[c.id] = this.day + 3; c.rel[a.to] -= 25; o.rel[c.id] -= 35; this.log(`${c.name} declares war on ${o.name}!`, 'war', [c.id, a.to]); }
        c.stats.raids++; (c.lastRaid = c.lastRaid || {})[a.to] = this.day;
      } else if (a.act === 'envoy') {
        members = this.pickMembers(c, null, 2);
        c.stats.envoys++; this.stats.envoys++;
      } else if (a.act === 'spy') {
        members = this.pickMembers(c, null, 1); this.stats.spies++;
      }
      if (!members.length) return;
      const p = { id: this.nextId++, kind: a.act, from: c.id, to: a.to, members, cargo, p: 0, dir: 1, state: 'out', hostT: 0, loot: {}, captives: [] };
      for (const m of members) { m.party = p; m.loc = -1; m.hidden = false; }
      this.parties.push(p);
      const verb = { trade: 'sends a trade caravan to', raid: 'sends a raiding party against', envoy: 'sends envoys to', spy: 'sends a spy into' }[a.act];
      this.log(`${c.name} ${verb} ${o.name}.`, a.act === 'raid' ? 'war' : 'info', [c.id, a.to]);
    }

    // ---------- parties ----------
    updateParties(dt) {
      for (const p of this.parties) {
        if (p.state === 'done') continue;
        if (!p.members.length) { this.dissolve(p); continue; }
        if (p.state === 'out') {
          p.p += dt / TRAVEL;
          if (p.p >= 1) { p.p = 1; this.arrive(p); }
        } else if (p.state === 'host') {
          p.hostT -= dt;
          if (p.hostT <= 0) { p.state = 'back'; p.dir = -1; for (const m of p.members) m.loc = -1; }
        } else if (p.state === 'back') {
          p.p -= dt / TRAVEL;
          if (p.p <= 0) { p.p = 0; this.homecoming(p); }
        }
      }
      this.parties = this.parties.filter(p => p.state !== 'done');
    }

    arrive(p) {
      const to = this.civs[p.to], from = this.civs[p.from];
      p.state = 'host'; p.hostT = 5;
      for (const m of p.members) { m.loc = p.to; m.x = 100; m.y = 130; m.tx = 90 + this.rr(-10, 10); m.ty = 100 + this.rr(-8, 8); m.state = 'walk'; }
      if (p.kind === 'trade') this.doTrade(p, from, to);
      else if (p.kind === 'raid') this.doBattle(p, from, to, false);
      else if (p.kind === 'envoy') {
        const gain = 8 * (from.race.charm || 1) * (to.race.charm || 1);
        from.rel[to.id] += gain; to.rel[from.id] += gain;
        p.hostT = 8;
        to.flash = 'trade'; to.flashT = 2;
      } else if (p.kind === 'spy') this.doSpy(p, from, to);
    }

    homecoming(p) {
      const from = this.civs[p.from];
      for (const m of p.members) {
        m.party = null; m.loc = from.id; m.x = 100; m.y = 140; m.state = 'idle';
        this.setWork(m);
      }
      for (const k of RES) if (p.cargo[k]) from.stock[k] += p.cargo[k];
      for (const k of RES) if (p.loot[k]) { from.stock[k] += p.loot[k]; from.stats.plunder += p.loot[k]; }
      for (const cap of p.captives) {
        // captives are adopted: they keep their blood but belong to the captor
        const old = this.civs[cap.home];
        const i = old.citizens.indexOf(cap); if (i >= 0) old.citizens.splice(i, 1);
        cap.home = from.id; cap.loc = from.id; cap.party = null; cap.role = 'farm'; cap.x = 100; cap.y = 140;
        from.citizens.push(cap); this.setWork(cap);
      }
      p.state = 'done';
      if (p.kind === 'trade') { from.flash = 'trade'; from.flashT = 2; }
    }

    dissolve(p) {
      // all members died
      const from = this.civs[p.from];
      p.state = 'done';
      void from;
    }

    doTrade(p, from, to) {
      const bonus = (from.race.tradeBonus || 1) * (to.race.tradeBonus || 1);
      const give = Object.keys(p.cargo).find(k => RES.includes(k));
      const want = p.cargo.wantRes;
      this.stats.trades++; from.stats.trades++; to.stats.trades++;
      if (give && want) {
        const amt = p.cargo[give];
        const back = Math.floor(Math.min(to.stock[want], amt * bonus * 0.9));
        to.stock[give] += amt; to.stock[want] -= back; p.cargo = {}; p.cargo[want] = back;
        this.log(`${from.name} swaps ${amt} ${give} for ${back} ${want} with ${to.name}.`, 'trade', [from.id, to.id]);
      } else if (give) {
        const amt = p.cargo[give]; to.stock[give] += amt; const gold = Math.floor(amt * 0.7 * bonus);
        const pay = Math.min(to.stock.gold, gold); to.stock.gold -= pay; p.cargo = { gold: pay };
        this.log(`${from.name} sells ${amt} ${give} to ${to.name} for ${pay} gold.`, 'trade', [from.id, to.id]);
      } else { p.cargo = {}; }
      delete p.cargo.wantRes;
      from.rel[to.id] += 6; to.rel[from.id] += 6;
      from.stock.gold += 1; to.stock.gold += 1;
      to.flash = 'trade'; to.flashT = 2.5; from.flash = 'trade'; from.flashT = 2.5;
    }

    doSpy(p, from, to) {
      const steal = Math.floor(to.stock.gold * this.rr(0.08, 0.2));
      to.stock.gold -= steal; p.loot.gold = (p.loot.gold || 0) + steal;
      this.log(`An Imp from ${from.name} sneaks into ${to.name} and steals ${steal} gold.`, 'spy', [from.id, to.id]);
      if (this.r() < 0.6) {
        const others = to.links.filter(j => j !== from.id);
        if (others.length) {
          const v = this.civs[this.pick(others)];
          to.rel[v.id] -= 22; v.rel[to.id] -= 22;
          this.log(`The crime is blamed on ${v.name}. Relations between ${to.name} and ${v.name} sour.`, 'spy', [to.id, v.id]);
        }
      }
      if (this.r() < 0.25) { // caught
        const imp = p.members[0]; if (imp) this.removeCitizen(imp, 'caught');
        this.log(`The imp is caught and hanged in ${to.name}.`, 'death', [to.id]);
      }
      p.hostT = 3;
      to.flash = 'spy'; to.flashT = 2;
    }

    // Resolve a fight between a raiding party and the defenders of `to`.
    doBattle(p, from, to, night) {
      const atk = p.members.slice();
      const defSold = to.citizens.filter(x => x.role === 'soldier' && x.loc === to.id && !x.party);
      const defOther = to.citizens.filter(x => x.role !== 'soldier' && this.isAdult(x) && x.loc === to.id && !x.party);
      let aPow = this.power(atk) * (1 + from.tech * 0.06) * (night ? 0.75 : 1);
      let dPow = (this.power(defSold) + 0.22 * this.power(defOther)) * (1 + to.tech * 0.06) * (night ? 1.3 : 1.15);
      aPow = Math.max(0.1, aPow); dPow = Math.max(0.1, dPow);
      const ratio = aPow / dPow;
      const cfD = clamp(0.32 * ratio * this.rr(0.7, 1.3), 0.04, 0.85);
      const cfA = clamp(0.32 / ratio * this.rr(0.7, 1.3), 0.06, 0.95);
      const attackerWins = cfD > cfA;
      let dead = 0;
      const killFrom = (list, frac) => {
        let k = Math.round(list.length * frac);
        if (frac > 0.05 && k === 0) k = 1;
        list = list.slice().sort(() => this.r() - 0.5);
        const out = [];
        for (let i = 0; i < k && i < list.length; i++) { out.push(list[i]); }
        return out;
      };
      const aDead = killFrom(atk, cfA);
      const dKill = killFrom(defSold, cfD).concat(killFrom(defOther, cfD * 0.35));
      const dedupe = new Set(dKill);
      for (const x of aDead) { this.removeCitizen(x, 'battle'); from.stats.losses++; to.stats.kills++; dead++; }
      for (const x of dedupe) { this.removeCitizen(x, 'battle'); to.stats.losses++; from.stats.kills++; dead++; }
      this.stats.battles++;
      from.rel[to.id] -= 12; to.rel[from.id] -= 18;
      from.flash = 'battle'; from.flashT = 3; to.flash = 'battle'; to.flashT = 4;
      for (const m of p.members) { m.xp = Math.min(2, m.xp + 0.25); }
      let msg = `${night ? 'Night battle' : 'Battle'}: ${from.name} (${atk.length}) vs ${to.name} - ${aDead.length} raiders and ${dedupe.size} defenders fall.`;
      if (attackerWins) {
        const frac = 0.18 * (from.race.plunder || 1) * clamp(ratio, 0.6, 1.8);
        for (const k of ['food', 'goods', 'gold', 'ore', 'wood']) {
          const take = Math.floor(to.stock[k] * frac * 0.8);
          to.stock[k] -= take; p.loot[k] = (p.loot[k] || 0) + take;
        }
        // captives
        const pool = to.citizens.filter(x => this.isAdult(x) && x.loc === to.id && !x.party && x.role !== 'soldier');
        const capN = Math.min(pool.length, this.r() < 0.5 ? 1 : 2);
        for (let i = 0; i < capN; i++) { const c = this.pick(pool); if (c && !p.captives.includes(c)) { p.captives.push(c); c.party = p; c.loc = -1; } }
        msg += ` ${from.name} wins and carries off loot${p.captives.length ? ' and ' + p.captives.length + ' captive(s)' : ''}.`;
        from.stats.defended += 0; to.stats.defended += 0;
        if (dead && from.race.raiseDead) { this.raiseDead(from, Math.ceil(dedupe.size * 0.6) + 1); }
      } else {
        msg += ` ${to.name} holds the jar.`;
        to.stats.defended++;
        if (dead && to.race.raiseDead) this.raiseDead(to, Math.ceil(aDead.length * 0.6));
        // survivors flee with nothing
      }
      this.log(msg, 'war', [from.id, to.id]);
      p.hostT = night ? 0 : 6;
      // exhaustion -> ends war sooner
      if (!attackerWins && from.war[to.id] != null && this.r() < 0.5) { from.war[to.id] = Math.min(from.war[to.id], this.day + 1); to.war[from.id] = from.war[to.id]; }
      if (!p.members.length) this.dissolve(p);
    }

    raiseDead(civ, n) {
      n = Math.min(n, Math.max(0, this.capacity(civ) + 6 - civ.citizens.length));
      if (n <= 0) return;
      for (let i = 0; i < n; i++) { const s = this.spawnCitizen(civ, { [civ.id]: 1 }, 5); s.role = 'soldier'; this.setWork(s); }
      civ.stats.raised += n;
      this.log(`${civ.name} raise ${n} fallen warriors as new skeletons.`, 'war', [civ.id]);
    }

    // ---------- night ----------
    lockJars() {
      this.locked = true;
      this.log(`Dusk. Every jar locks for the night.`, 'sys');
      for (const p of this.parties) {
        if (p.state === 'done') continue;
        if (p.state === 'out') {
          if (p.p < 0.5) { p.state = 'back'; this.log(`A ${p.kind} party from ${this.civs[p.from].name} turns back at dusk.`, 'info', [p.from]); }
          else { p.p = 1; this.arriveLocked(p); }
        } else if (p.state === 'back') {
          if (p.p < 0.5) { p.p = 0; this.homecoming(p); }
          else { p.p = 1; p.dir = 1; this.becomeGuest(p, false); }
        } else if (p.state === 'host') {
          this.becomeGuest(p, false);
        }
      }
      this.parties = this.parties.filter(p => p.state !== 'done');
      this.nightMingle();
    }
    arriveLocked(p) {
      const from = this.civs[p.from], to = this.civs[p.to];
      for (const m of p.members) { m.loc = p.to; m.x = 100; m.y = 130; m.state = 'walk'; }
      if (p.kind === 'raid') this.doBattle(p, from, to, true);
      else if (p.kind === 'trade') this.doTrade(p, from, to);
      else if (p.kind === 'spy') this.doSpy(p, from, to);
      else if (p.kind === 'envoy') { from.rel[to.id] += 6; to.rel[from.id] += 6; }
      if (p.state !== 'done') this.becomeGuest(p, true);
    }
    becomeGuest(p, fresh) {
      p.state = 'guest'; void fresh;
      for (const m of p.members) { m.loc = p.to; m.tx = 70 + this.rr(0, 60); m.ty = 100 + this.rr(-6, 14); m.state = 'walk'; }
      if (p.members.length) this.log(`${p.members.length} traveller(s) from ${this.civs[p.from].name} are locked in ${this.civs[p.to].name} overnight.`, 'info', [p.from, p.to]);
    }
    releaseGuests(p) { for (const m of p.members) m.loc = -1; }

    nightMingle() {
      for (const p of this.parties) {
        if (p.state !== 'guest') continue;
        const host = this.civs[p.to], from = this.civs[p.from];
        if (from.war[host.id] != null) continue;     // wartime guests do not mingle (battle already happened)
        const rel = from.rel[host.id];
        for (const g of p.members) {
          if (!this.isAdult(g)) continue;
          const fertG = this.fertility(g);
          if (fertG <= 0) continue;
          const mates = host.citizens.filter(h => this.isAdult(h) && h.loc === host.id && !h.party && this.fertility(h) > 0);
          if (!mates.length) continue;
          const chance = clamp(0.1 + rel / 220 + (from.race.charm || 1) * 0.04, 0, 0.55);
          if (this.r() < chance) {
            const mate = this.pick(mates);
            const blood = {};
            for (const k in g.blood) blood[k] = (blood[k] || 0) + g.blood[k] / 2;
            for (const k in mate.blood) blood[k] = (blood[k] || 0) + mate.blood[k] / 2;
            const homeId = this.r() < 0.55 ? host.id : from.id;
            const a = this.dominant(g), b = this.dominant(mate);
            const hybrid = a !== b;
            const dest = this.civs[homeId];
            dest.pendingBirths = dest.pendingBirths || [];
            dest.pendingBirths.push({ home: homeId, blood, hybrid, a, b });
            from.rel[host.id] += 3; host.rel[from.id] += 3;
          }
        }
      }
    }
    fertility(c) { let v = 0; for (const k in c.blood) v += c.blood[k] * RACES[k].traits.fertility; return v; }

    // ---------- citizens ----------
    updateCitizens(dt) {
      for (const civ of this.civs) {
        for (const c of civ.citizens) {
          if (c.loc < 0) continue;
          const night = this.locked;
          const visitor = c.loc !== c.home;
          if (night && !visitor) {
            if (c.state !== 'sleep') {
              const h = this.houseSpot(civ);
              c.tx = h[0]; c.ty = h[1]; c.state = 'gohome';
            }
          } else if (!night && (c.state === 'sleep' || c.state === 'gohome')) {
            c.hidden = false; this.setWork(c);
          }
          const dx = c.tx - c.x, dy = c.ty - c.y, d = Math.hypot(dx, dy);
          if (d > 1.2 && c.state !== 'sleep' && c.state !== 'work') {
            const sp = (c.state === 'gohome' ? 26 : 20) * (c.role === 'child' ? 0.8 : 1);
            c.x += (dx / d) * sp * dt; c.y += (dy / d) * sp * dt;
            if (Math.abs(dx) > 0.5) c.face = dx > 0 ? 1 : -1;
          } else if (c.state === 'walk') {
            c.state = 'work'; c.timer = this.rr(4, 7);
          } else if (c.state === 'gohome') {
            c.state = 'sleep'; c.hidden = true;
          } else if (c.state === 'work') {
            c.timer -= dt;
            if (c.timer <= 0) { this.produce(civ, c); c.timer = this.rr(5, 7); if (c.role === 'child' || this.r() < 0.3) this.jitter(c); }
          } else if (c.state === 'idle') {
            c.timer -= dt;
            if (c.timer <= 0) { this.jitter(c); }
          }
        }
      }
    }
    jitter(c) {
      const base = SITES[c.role] || [100, 118];
      c.tx = base[0] + this.rr(-16, 16); c.ty = base[1] + this.rr(-10, 10);
      c.state = 'walk';
      if (c.role === 'child') c.timer = this.rr(2, 5);
    }

    produce(civ, c) {
      if (c.loc !== c.home || this.locked) return;
      const techM = 1 + civ.tech * 0.06;
      const role = c.role;
      if (role === 'soldier') { c.xp = Math.min(2, c.xp + 0.02); civ.stock.food -= 0.05; return; }
      const res = ROLE_RES[role];
      if (!res) return;
      const base = { food: 0.55, wood: 0.5, ore: 0.45, goods: 0.45, lore: 0.35, gold: 0.4 }[res];
      let amt = base * this.mixedMult(c, res) * techM;
      if (role === 'craft') {
        if (civ.stock.ore >= 0.5 && civ.stock.wood >= 0.3) { civ.stock.ore -= 0.5; civ.stock.wood -= 0.3; amt *= 1.5; } else amt *= 0.4;
      }
      civ.stock[res] += amt;
    }

    // ---------- helpers for UI ----------
    totalPop() { return this.civs.reduce((n, c) => n + c.citizens.length, 0); }
  }

  BC.Sim = Sim;
  BC.CONST = { DAY_LEN, DUSK, TRAVEL, JAR_W, JAR_H, SITES, GRID, SEALED };
})(typeof window !== 'undefined' ? window : globalThis);
