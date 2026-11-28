(function () {
  const { Sim, Renderer, loadAssets, DATA, CONST } = BC;
  const { RACES, SEALED } = DATA;
  const q = new URLSearchParams(location.search);
  const sim = new Sim(q.has('seed') ? +q.get('seed') : undefined);
  const canvas = document.getElementById('c');
  const rd = new Renderer(canvas, sim);
  let speed = +q.get('speed') || 1, paused = false;
  window.__bc = { sim, rd };
  const $ = id => document.getElementById(id);

  document.querySelectorAll('[data-s]').forEach(b => b.onclick = () => { speed = +b.dataset.s; paused = false; syncBtns(); });
  $('pause').onclick = () => { paused = !paused; syncBtns(); };
  function syncBtns() {
    document.querySelectorAll('[data-s]').forEach(b => b.classList.toggle('on', !paused && +b.dataset.s === speed));
    $('pause').classList.toggle('on', paused);
  }
  addEventListener('keydown', e => {
    if (e.key === ' ') { paused = !paused; syncBtns(); e.preventDefault(); }
    const i = '12345'.indexOf(e.key); if (i >= 0) { speed = [1, 2, 4, 8, 20][i]; paused = false; syncBtns(); }
  });
  function toWorld(e) { const r = canvas.getBoundingClientRect(); return [(e.clientX - r.left) * canvas.width / r.width, (e.clientY - r.top) * canvas.height / r.height]; }
  canvas.addEventListener('click', e => { const s = rd.slotAt(...toWorld(e)); rd.selected = s >= 0 ? s : -1; renderInfo(); });
  canvas.addEventListener('mousemove', e => { rd.hover = rd.slotAt(...toWorld(e)); });
  canvas.addEventListener('mouseleave', () => { rd.hover = -1; });

  const fmt = n => Math.round(n);
  function renderInfo() {
    const el = $('info'), s = rd.selected;
    if (s < 0) {
      el.innerHTML = `<h2>The Shelf</h2><div class="dim"><small>Click a jar to inspect its civilization. Space pauses; keys 1-5 change speed.<br>By day the tubes between jars are open: caravans trade, raiders raid, envoys carry romance. At dusk every jar locks. Whoever is still outside is stuck in the neighbour's jar until dawn - which is how hybrids happen.</small></div>`;
      return;
    }
    if (s >= sim.civs.length) { const i = SEALED[s - 10]; el.innerHTML = `<h2 style="color:#8b8ba8">${i.jar}</h2><div class="dim">Sealed. The ${i.name} are not awake yet.</div>`; return; }
    const c = sim.civs[s], r = c.race;
    const hy = c.citizens.filter(x => sim.isHybrid(x)).length;
    const rc = Object.entries(c.roleCount).map(([k, v]) => `<span class="chip">${k} ${v}</span>`).join('');
    const rels = c.links.map(j => ({ j, v: c.rel[j] })).sort((a, b) => b.v - a.v).map(({ j, v }) => {
      const o = sim.civs[j], w = Math.abs(v) / 2;
      const war = c.war[j] != null ? ' ⚔' : '';
      return `<div class="rel"><span class="n" style="color:${o.race.color}">${o.race.name}${war}</span><span class="b"><i style="${v >= 0 ? 'left:50%;background:#7ee59a;' : 'right:50%;background:#ff7a66;'}width:${w}%"></i></span><span style="width:30px;text-align:right">${fmt(v)}</span></div>`;
    }).join('');
    el.innerHTML = `<h2 style="color:${r.color}">${c.name} <small class="dim">· ${r.name}</small></h2>
      <small class="dim"><b>${r.skill}.</b> ${r.blurb}</small>
      <div class="chips"><span class="chip">👥 ${c.citizens.length}/${sim.capacity(c)}</span><span class="chip">🏠 ${c.houses}</span><span class="chip">🧬 hybrids ${hy}</span><span class="chip">🔬 tech ${c.tech}</span></div>
      <div class="chips">${['food','wood','ore','goods','lore','gold'].map(k => `<span class="chip">${{food:'🌾',wood:'🪵',ore:'⛏',goods:'📦',lore:'📖',gold:'🪙'}[k]} ${fmt(c.stock[k])}</span>`).join('')}</div>
      <div class="chips">${rc}</div>
      <small class="dim">births ${c.stats.births} (hybrid ${c.stats.hybridBirths}) · raids ${c.stats.raids} · defended ${c.stats.defended} · kills ${c.stats.kills}/lost ${c.stats.losses} · trades ${c.stats.trades}</small>
      <div style="margin-top:6px"><small class="dim">Relations with neighbours</small>${rels}</div>`;
  }
  let logLen = -1;
  function renderLog() {
    const ev = sim.events; const key = ev.length + ':' + (ev.length ? ev[ev.length - 1].text : '');
    if (key === logLen) return; logLen = key;
    const el = $('log'); const atTop = el.scrollTop < 8;
    el.innerHTML = ev.slice(-80).reverse().map(e => `<div class="k-${e.kind}"><span class="dim">D${e.day}</span> ${e.text}</div>`).join('');
    if (atTop) el.scrollTop = 0;
  }
  function renderHud() {
    $('day').textContent = 'Day ' + sim.day;
    document.querySelector('#bar i').style.width = (sim.t * 100) + '%';
    $('phase').textContent = sim.locked ? '🌙 locked' : '☀ open';
    const hy = sim.stats.hybrids;
    $('world').textContent = `pop ${sim.totalPop()} · battles ${sim.stats.battles} · trades ${sim.stats.trades} · hybrids ${hy}`;
  }

  loadAssets(p => { $('pct').textContent = Math.round(p * 100) + '%'; }).then(() => {
    $('load').style.display = 'none';
    renderInfo(); syncBtns();
    let last = performance.now(), acc = 0, ui = 0;
    function loop(now) {
      const dt = Math.min(0.1, (now - last) / 1000); last = now;
      if (!paused) {
        acc += dt * speed;
        let n = 0; while (acc >= 1 / 20 && n < 400) { sim.step(1 / 20); acc -= 1 / 20; n++; }
        if (n >= 400) acc = 0;
      }
      rd.frame(paused ? 0 : dt);
      ui += dt; if (ui > 0.25) { ui = 0; renderHud(); renderLog(); if (rd.selected >= 0) renderInfo(); }
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
  });
})();
