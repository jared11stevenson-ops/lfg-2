// Canvas renderer: draws the shelf of jars, the tubes between them, and everything inside.
(function (g) {
  const BC = (g.BC = g.BC || {});
  const { RACES, SEALED } = BC.DATA;
  const { DAY_LEN, DUSK, JAR_W, JAR_H, SITES, TRAVEL } = BC.CONST;

  const W = 1200, H = 800, COLS = 4, ROWS = 3;
  const CW = W / COLS, CH = H / ROWS;
  const K = 1.2;                         // interior scale
  const JX = 30, JY = 52;                // jar interior offset inside a cell
  const JW = JAR_W * K, JH = JAR_H * K;

  const images = {};
  function loadImage(src) {
    return new Promise(res => { const im = new Image(); im.onload = () => res(im); im.onerror = () => res(null); im.src = src; });
  }
  async function loadAssets(onProgress) {
    const names = [];
    const sprites = RACES.map(r => r.sprite).concat(SEALED.map(r => r.sprite));
    for (const s of sprites) for (const a of ['idle', 'run']) for (let f = 0; f < 4; f++) names.push([`${s}_${a}_anim_f${f}`, `assets/sprites/${s}_${a}_anim_f${f}.png`]);
    for (const p of ['coin_anim_f0', 'coin_anim_f1', 'coin_anim_f2', 'coin_anim_f3', 'crate', 'flask_big_blue', 'flask_big_green', 'flask_big_red', 'flask_big_yellow',
      'weapon_regular_sword', 'weapon_axe', 'weapon_green_magic_staff', 'skull', 'column', 'chest_full_open_anim_f0', 'weapon_big_hammer'])
      names.push([p, `assets/props/${p}.png`]);
    for (let i = 1; i <= 8; i++) names.push([`floor_${i}`, `assets/props/floor_${i}.png`]);
    let done = 0;
    await Promise.all(names.map(async ([k, src]) => { images[k] = await loadImage(src); done++; if (onProgress) onProgress(done / names.length); }));
    return images;
  }

  const silCache = {};
  function silhouette(key) {
    if (silCache[key]) return silCache[key];
    const im = images[key]; if (!im) return null;
    const c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
    const x = c.getContext('2d'); x.drawImage(im, 0, 0);
    x.globalCompositeOperation = 'source-in'; x.fillStyle = '#0a0a14'; x.fillRect(0, 0, c.width, c.height);
    return (silCache[key] = c);
  }

  function cellOf(slot) { return { x: (slot % COLS) * CW, y: Math.floor(slot / COLS) * CH }; }
  function jarCenter(slot) { const c = cellOf(slot); return { x: c.x + JX + JW / 2, y: c.y + JY + JH / 2 }; }
  function houseXY(i) { return [14 + ((i % 8) * 24) % 172 + 8, 124 + (Math.floor(i / 8) % 2) * 12]; }

  function hex(c, a) {
    const n = parseInt(c.slice(1), 16);
    return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
  }
  function shade(c, f) {
    const n = parseInt(c.slice(1), 16);
    const r = Math.max(0, Math.min(255, ((n >> 16) * f) | 0)), g2 = Math.max(0, Math.min(255, (((n >> 8) & 255) * f) | 0)), b = Math.max(0, Math.min(255, ((n & 255) * f) | 0));
    return `rgb(${r},${g2},${b})`;
  }
  function rrect(ctx, x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }

  class Renderer {
    constructor(canvas, sim) {
      this.canvas = canvas; this.ctx = canvas.getContext('2d'); this.sim = sim;
      canvas.width = W; canvas.height = H;
      this.time = 0; this.selected = -1; this.hover = -1;
      this.stars = Array.from({ length: 30 }, (_, i) => [((i * 53) % 97) / 97 * JAR_W, ((i * 31) % 59) / 59 * 80, (i % 3) + 1]);
      this.particles = [];
      this.lastFlash = {};
    }
    slotAt(px, py) {
      for (let s = 0; s < 12; s++) {
        const c = cellOf(s);
        if (px >= c.x + JX && px <= c.x + JX + JW && py >= c.y + JY - 20 && py <= c.y + JY + JH + 36) return s;
      }
      return -1;
    }

    frame(dt) {
      this.time += dt;
      const ctx = this.ctx, sim = this.sim;
      ctx.imageSmoothingEnabled = false;
      this.drawShelf(ctx);
      this.drawTubes(ctx);
      for (let s = 0; s < 12; s++) {
        if (s < sim.civs.length) this.drawJar(ctx, sim.civs[s]); else this.drawSealed(ctx, s);
      }
      this.drawParties(ctx);
      this.drawParticles(ctx, dt);
    }

    drawShelf(ctx) {
      const night = this.sim.locked;
      const grd = ctx.createLinearGradient(0, 0, 0, H);
      grd.addColorStop(0, night ? '#14122a' : '#3a2a1e'); grd.addColorStop(1, night ? '#0c0a1a' : '#251810');
      ctx.fillStyle = grd; ctx.fillRect(0, 0, W, H);
      // brick-ish wall texture
      ctx.fillStyle = 'rgba(0,0,0,0.12)';
      for (let y = 0; y < H; y += 24) for (let x = (y / 24) % 2 ? 0 : 20; x < W; x += 40) ctx.fillRect(x, y, 38, 22);
      // shelves
      for (let r = 0; r < ROWS; r++) {
        const y = r * CH + JY + JH + 38;
        const g2 = ctx.createLinearGradient(0, y, 0, y + 22);
        g2.addColorStop(0, night ? '#2b2236' : '#7a5230'); g2.addColorStop(1, night ? '#17121f' : '#4a301c');
        ctx.fillStyle = g2; ctx.fillRect(0, y, W, 22);
        ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.fillRect(0, y + 22, W, 6);
      }
    }

    drawTubes(ctx) {
      const sim = this.sim, locked = sim.locked;
      for (const l of sim.links) {
        const a = jarCenter(l.a), b = jarCenter(l.b);
        const warring = sim.civs[l.a].war[l.b] != null;
        ctx.lineCap = 'round';
        ctx.strokeStyle = '#0d0d14'; ctx.lineWidth = 15; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        ctx.strokeStyle = locked ? '#3a3a50' : (warring ? 'rgba(255,90,70,0.55)' : 'rgba(140,235,200,0.40)');
        ctx.lineWidth = 10; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        ctx.strokeStyle = 'rgba(255,255,255,0.18)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(a.x, a.y - 3); ctx.lineTo(b.x, b.y - 3); ctx.stroke();
        // gate in the middle
        const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
        if (locked) { this.lock(ctx, mx, my, true, 0.7); }
      }
    }

    lock(ctx, x, y, closed, s) {
      ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
      ctx.strokeStyle = closed ? '#c9ccd6' : '#7ee59a'; ctx.lineWidth = 3;
      ctx.beginPath();
      if (closed) { ctx.arc(0, -4, 6, Math.PI, 0); ctx.lineTo(6, -2); ctx.moveTo(-6, -4); ctx.lineTo(-6, -2); }
      else { ctx.arc(6, -6, 6, Math.PI, 0); ctx.moveTo(0, -6); ctx.lineTo(0, -2); }
      ctx.stroke();
      ctx.fillStyle = closed ? '#e0a63a' : '#4a8f5d'; rrect(ctx, -9, -2, 18, 13, 3); ctx.fill();
      ctx.fillStyle = '#2a1b07'; ctx.fillRect(-1.5, 2, 3, 5);
      ctx.restore();
    }

    drawSealed(ctx, s) {
      const info = SEALED[s - 10]; const c = cellOf(s);
      const x = c.x + JX, y = c.y + JY;
      ctx.save();
      rrect(ctx, x, y, JW, JH, 26); ctx.fillStyle = '#0c0b14'; ctx.fill(); ctx.clip();
      const sil = silhouette(`${info.sprite}_idle_anim_f${Math.floor(this.time * 4) % 4}`);
      if (sil) { const w = sil.width * 4, h = sil.height * 4; ctx.globalAlpha = 0.55; ctx.drawImage(sil, x + JW / 2 - w / 2, y + JH / 2 - h / 2 + 10, w, h); ctx.globalAlpha = 1; }
      ctx.fillStyle = 'rgba(30,30,60,0.55)'; ctx.fillRect(x, y, JW, JH);
      ctx.restore();
      this.glass(ctx, x, y, '#6b6b88');
      // chains
      ctx.strokeStyle = '#8b8fa0'; ctx.lineWidth = 4; ctx.setLineDash([8, 5]);
      ctx.beginPath(); ctx.moveTo(x + 8, y + 22); ctx.lineTo(x + JW - 8, y + JH - 22); ctx.moveTo(x + JW - 8, y + 22); ctx.lineTo(x + 8, y + JH - 22); ctx.stroke(); ctx.setLineDash([]);
      this.lock(ctx, x + JW / 2, y + JH / 2 - 6, true, 2.2);
      this.cork(ctx, x, y, '#5a4a3a');
      this.label(ctx, x, y, info.jar, 'SEALED - future civilization', '#7b7b99');
    }

    glass(ctx, x, y, tint) {
      ctx.save();
      ctx.strokeStyle = tint; ctx.lineWidth = 5; rrect(ctx, x, y, JW, JH, 26); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,0.28)'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(x + 14, y + 40); ctx.lineTo(x + 14, y + JH - 40); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.beginPath(); ctx.moveTo(x + 24, y + 30); ctx.lineTo(x + 24, y + 62); ctx.stroke();
      ctx.restore();
    }
    cork(ctx, x, y, col) {
      const cx = x + JW / 2;
      ctx.fillStyle = 'rgba(210,235,255,0.25)'; ctx.strokeStyle = 'rgba(210,235,255,0.55)'; ctx.lineWidth = 3;
      rrect(ctx, cx - 40, y - 24, 80, 30, 6); ctx.fill(); ctx.stroke();
      ctx.fillStyle = col || '#9b6a3c'; rrect(ctx, cx - 30, y - 42, 60, 26, 5); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.2)'; for (let i = 0; i < 5; i++) ctx.fillRect(cx - 24 + i * 11, y - 36, 4, 3);
    }
    label(ctx, x, y, title, sub, color) {
      const cx = x + JW / 2, ly = y + JH + 6;
      ctx.fillStyle = 'rgba(14,10,6,0.75)'; rrect(ctx, x + 10, ly, JW - 20, 28, 5); ctx.fill();
      ctx.textAlign = 'center'; ctx.fillStyle = color; ctx.font = 'bold 14px system-ui, sans-serif'; ctx.fillText(title, cx, ly + 13);
      ctx.fillStyle = '#c9b99a'; ctx.font = '11px system-ui, sans-serif'; ctx.fillText(sub, cx, ly + 25);
      ctx.textAlign = 'left';
    }

    drawJar(ctx, civ) {
      const sim = this.sim, race = civ.race, t = this.time;
      const cell = cellOf(civ.slot), x = cell.x + JX, y = cell.y + JY;
      const night = sim.locked;
      ctx.save();
      rrect(ctx, x, y, JW, JH, 26); ctx.clip();
      // floor
      const fl = images['floor_' + (1 + (civ.id % 8))];
      ctx.fillStyle = '#2a2a30'; ctx.fillRect(x, y, JW, JH);
      if (fl) for (let ty = 0; ty < JH; ty += 16 * K) for (let tx = 0; tx < JW; tx += 16 * K) ctx.drawImage(fl, x + tx, y + ty, 16 * K + 0.5, 16 * K + 0.5);
      ctx.fillStyle = hex(race.color, 0.16); ctx.fillRect(x, y, JW, JH);
      // props
      this.drawProps(ctx, civ, x, y);
      // citizens (z-sorted)
      const list = [];
      for (const c of sim.civs) for (const cit of c.citizens) if (cit.loc === civ.id && !cit.hidden) list.push(cit);
      list.sort((a, b) => a.y - b.y);
      for (const cit of list) this.drawCitizen(ctx, cit, x, y);
      // sleepers' z's
      if (night) {
        let sleepers = 0; for (const cit of civ.citizens) if (cit.hidden && cit.loc === civ.id) sleepers++;
        ctx.fillStyle = 'rgba(200,210,255,0.85)'; ctx.font = 'bold 12px system-ui';
        for (let i = 0; i < Math.min(5, Math.ceil(sleepers / 3)); i++) {
          const [hx, hy] = houseXY(i);
          const ph = (t * 0.8 + i * 0.37) % 1;
          ctx.globalAlpha = 1 - ph; ctx.fillText('z', x + (hx + 4 + ph * 6) * K, y + (hy - 14 - ph * 14) * K);
        }
        ctx.globalAlpha = 1;
      }
      // night tint
      if (night) {
        ctx.fillStyle = 'rgba(8,14,52,0.52)'; ctx.fillRect(x, y, JW, JH);
        ctx.fillStyle = '#fff';
        for (const s of this.stars) { ctx.globalAlpha = 0.4 + 0.5 * Math.abs(Math.sin(t * 1.5 + s[0])); ctx.fillRect(x + s[0] * K, y + s[1] * K, s[2] * 0.8, s[2] * 0.8); }
        ctx.globalAlpha = 1;
        // lit windows over the darkness
        const hs = civ.houses;
        for (let i = 0; i < hs; i++) { const [hx, hy] = houseXY(i); ctx.fillStyle = 'rgba(255,214,120,0.95)'; ctx.fillRect(x + (hx - 2) * K, y + (hy - 8) * K, 4 * K, 4 * K); }
      }
      // flash effects
      if (civ.flashT > 0) {
        const f = civ.flash;
        const a = Math.min(0.35, civ.flashT * 0.18) * (0.6 + 0.4 * Math.sin(t * 18));
        ctx.fillStyle = f === 'battle' ? `rgba(255,50,40,${a})` : f === 'spy' ? `rgba(180,60,255,${a})` : `rgba(255,220,80,${a * 0.8})`;
        ctx.fillRect(x, y, JW, JH);
      }
      ctx.restore();
      if (civ.flashT > 0 && !this.lastFlash[civ.id + civ.flash + Math.floor(civ.flashT * 0.3)]) {
        this.lastFlash[civ.id + civ.flash + Math.floor(civ.flashT * 0.3)] = 1;
        this.burst(x + JW / 2, y + JH / 2, civ.flash);
      }
      if (this.selected === civ.id || this.hover === civ.id) {
        ctx.save(); ctx.strokeStyle = this.selected === civ.id ? '#ffd35a' : 'rgba(255,255,255,0.5)'; ctx.lineWidth = 4; ctx.setLineDash(this.selected === civ.id ? [] : [6, 4]);
        rrect(ctx, x - 6, y - 6, JW + 12, JH + 12, 30); ctx.stroke(); ctx.restore();
      }
      this.glass(ctx, x, y, hex(race.color, 0.9));
      this.cork(ctx, x, y);
      if (night) this.lock(ctx, x + JW / 2, y - 18, true, 0.95); else this.lock(ctx, x + JW / 2, y - 18, false, 0.95);
      const war = Object.keys(civ.war).length ? '  ⚔ at war' : '';
      this.label(ctx, x, y, `${civ.name}`, `${race.name} · ${civ.citizens.length} pop · ${race.skill}${war}`, race.color);
    }

    drawProps(ctx, civ, x, y) {
      const T = this.time;
      const P = (k, px, py, s) => { const im = images[k]; if (im) ctx.drawImage(im, x + px * K, y + py * K, im.width * (s || 1) * K, im.height * (s || 1) * K); };
      // fields
      const fx = x + 16 * K, fy = y + 78 * K;
      for (let r = 0; r < 4; r++) { ctx.fillStyle = r % 2 ? '#5b3b22' : '#6e482a'; ctx.fillRect(fx, fy + r * 8 * K, 44 * K, 6 * K); ctx.fillStyle = '#7fcf5a'; for (let c = 0; c < 8; c++) ctx.fillRect(fx + (3 + c * 5.4) * K, fy + (r * 8 + 1) * K, 2 * K, 3 * K); }
      // trees
      for (let i = 0; i < 4; i++) {
        const tx = x + (18 + i * 14) * K, ty = y + (28 + (i % 2) * 12) * K;
        ctx.fillStyle = '#4a2e18'; ctx.fillRect(tx - 1.5 * K, ty + 4 * K, 3 * K, 7 * K);
        ctx.fillStyle = i % 2 ? '#2e7a3c' : '#3a9448'; ctx.beginPath(); ctx.arc(tx, ty, 7 * K, 0, 7); ctx.fill();
      }
      // mine
      ctx.fillStyle = '#4a4a54'; ctx.beginPath(); ctx.moveTo(x + 142 * K, y + 58 * K); ctx.lineTo(x + 158 * K, y + 24 * K); ctx.lineTo(x + 184 * K, y + 58 * K); ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#16161c'; ctx.beginPath(); ctx.arc(x + 160 * K, y + 56 * K, 7 * K, Math.PI, 0); ctx.fill();
      ctx.fillStyle = '#e6b84a'; for (const [dx, dy] of [[150, 46], [172, 50], [165, 36]]) ctx.fillRect(x + dx * K, y + dy * K, 2.5 * K, 2.5 * K);
      // library / study
      ctx.fillStyle = shade(civ.race.color, 0.55); ctx.fillRect(x + 82 * K, y + 14 * K, 38 * K, 22 * K);
      ctx.fillStyle = shade(civ.race.color, 0.35); ctx.beginPath(); ctx.moveTo(x + 78 * K, y + 14 * K); ctx.lineTo(x + 101 * K, y + 2 * K); ctx.lineTo(x + 124 * K, y + 14 * K); ctx.closePath(); ctx.fill();
      P('flask_big_blue', 94, 18, 0.9); P('column', 82, 18, 0.0);
      // craft
      ctx.fillStyle = '#3a2a22'; ctx.fillRect(x + 136 * K, y + 76 * K, 34 * K, 20 * K);
      P('crate', 140, 78); P('crate', 154, 80); P('weapon_big_hammer', 160, 66, 0.9);
      // market
      ctx.fillStyle = shade(civ.race.color, 0.9); ctx.fillRect(x + 88 * K, y + 84 * K, 26 * K, 4 * K);
      ctx.fillStyle = '#e8e0cc'; ctx.fillRect(x + 90 * K, y + 76 * K, 22 * K, 8 * K);
      const cf = Math.floor(T * 6) % 4; P('coin_anim_f' + cf, 98, 78);
      // barracks flag
      ctx.fillStyle = '#6b5a45'; ctx.fillRect(x + 96 * K, y + 48 * K, 2 * K, 22 * K);
      ctx.fillStyle = civ.race.color; ctx.beginPath(); ctx.moveTo(x + 98 * K, y + 48 * K); ctx.lineTo(x + 112 * K, y + 53 * K + Math.sin(T * 4) * 1.5 * K); ctx.lineTo(x + 98 * K, y + 58 * K); ctx.closePath(); ctx.fill();
      // houses
      for (let i = 0; i < civ.houses; i++) {
        const [hx, hy] = houseXY(i);
        const bx = x + (hx - 9) * K, by = y + (hy - 10) * K;
        ctx.fillStyle = '#7a5a3a'; ctx.fillRect(bx, by, 18 * K, 12 * K);
        ctx.fillStyle = shade(civ.race.color, 0.75); ctx.beginPath(); ctx.moveTo(bx - 2 * K, by); ctx.lineTo(bx + 9 * K, by - 8 * K); ctx.lineTo(bx + 20 * K, by); ctx.closePath(); ctx.fill();
        ctx.fillStyle = '#2a1a0e'; ctx.fillRect(bx + 7 * K, by + 5 * K, 4 * K, 7 * K);
      }
    }

    drawCitizen(ctx, c, ox, oy) {
      const sim = this.sim;
      const dom = sim.dominant(c), race = RACES[dom];
      const moving = c.state === 'walk' || c.state === 'gohome';
      const anim = moving ? 'run' : 'idle';
      const fps = moving ? 10 : 6;
      const fr = Math.floor(this.time * fps + c.id) % 4;
      const im = images[`${race.sprite}_${anim}_anim_f${fr}`];
      if (!im) return;
      const s = (c.age < 2 ? 0.7 : 1) * K;
      const w = im.width * s, h = im.height * s;
      const px = ox + c.x * K, py = oy + c.y * K;
      const visitor = c.loc !== c.home;
      // ground ellipse
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(px, py, w * 0.4, 3, 0, 0, 7); ctx.fill();
      if (visitor) { ctx.strokeStyle = RACES[c.home].color; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(px, py, w * 0.55, 4.5, 0, 0, 7); ctx.stroke(); }
      ctx.save(); ctx.translate(px, py - h); if (c.face < 0) { ctx.translate(w, 0); ctx.scale(-1, 1); } ctx.translate(-w / 2 * (c.face < 0 ? -1 : 1), 0);
      ctx.drawImage(im, 0, 0, w, h); ctx.restore();
      if (c.role === 'soldier' && c.loc === c.home) { const sw = images.weapon_regular_sword; if (sw) ctx.drawImage(sw, px + 3 * c.face - (c.face < 0 ? sw.width * 0.6 * K : 0), py - h * 0.62, sw.width * 0.6 * K, sw.height * 0.6 * K); }
      // hybrid pips: one per ancestry slice
      if (sim.isHybrid(c)) {
        const keys = Object.keys(c.blood).sort((a, b) => c.blood[b] - c.blood[a]).slice(0, 3);
        keys.forEach((k, i) => { ctx.fillStyle = RACES[k].color; ctx.fillRect(px - (keys.length * 3) / 2 + i * 3, py - h - 4, 2.4, 2.4); });
      }
    }

    drawParties(ctx) {
      const sim = this.sim;
      for (const p of sim.parties) {
        if (p.state !== 'out' && p.state !== 'back') continue;
        const a = jarCenter(p.from), b = jarCenter(p.to);
        const x = a.x + (b.x - a.x) * p.p, y = a.y + (b.y - a.y) * p.p;
        const col = RACES[p.from].color;
        const raid = p.kind === 'raid';
        ctx.fillStyle = raid ? 'rgba(255,60,50,0.35)' : hex(col, 0.3);
        ctx.beginPath(); ctx.arc(x, y, 16 + Math.sin(this.time * 6) * 1.5, 0, 7); ctx.fill();
        const n = Math.min(3, p.members.length);
        for (let i = 0; i < n; i++) {
          const m = p.members[i], race = RACES[sim.dominant(m)];
          const im = images[`${race.sprite}_run_anim_f${Math.floor(this.time * 10 + i) % 4}`]; if (!im) continue;
          const dir = (b.x - a.x) * (p.state === 'out' ? 1 : -1) >= 0 ? 1 : -1;
          const w = im.width * 1.1, h = im.height * 1.1, px = x + (i - (n - 1) / 2) * 11;
          ctx.save(); ctx.translate(px, y + 8 - h); if (dir < 0) { ctx.translate(w, 0); ctx.scale(-1, 1); } ctx.translate(-w / 2 * (dir < 0 ? -1 : 1), 0);
          ctx.drawImage(im, 0, 0, w, h); ctx.restore();
        }
        ctx.font = 'bold 13px system-ui'; ctx.textAlign = 'center';
        ctx.fillText({ raid: '⚔', trade: '💰', envoy: '💍', spy: '🗡' }[p.kind] || '', x, y - 22);
        ctx.textAlign = 'left';
      }
    }

    burst(x, y, kind) {
      const col = kind === 'battle' ? '#ff5a46' : kind === 'spy' ? '#c46bff' : '#ffd35a';
      for (let i = 0; i < 14; i++) this.particles.push({ x, y, vx: (Math.random() - 0.5) * 140, vy: -Math.random() * 120 - 20, life: 1, col, ch: kind === 'battle' ? '✦' : kind === 'spy' ? '✧' : '●' });
    }
    drawParticles(ctx, dt) {
      for (const p of this.particles) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 220 * dt; p.life -= dt * 0.9;
        ctx.globalAlpha = Math.max(0, p.life); ctx.fillStyle = p.col; ctx.font = '12px system-ui'; ctx.fillText(p.ch, p.x, p.y);
      }
      ctx.globalAlpha = 1;
      this.particles = this.particles.filter(p => p.life > 0);
    }
  }

  BC.Renderer = Renderer;
  BC.loadAssets = loadAssets;
  BC.LAYOUT = { W, H, CW, CH, JX, JY, JW, JH };
})(typeof window !== 'undefined' ? window : globalThis);
