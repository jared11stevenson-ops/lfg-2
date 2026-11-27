// Persistent PTD1 session. POST /act with JSON {steps:[{c:[x,y]}|{w:ms}|{k:"key"}|{shot:"name"}|{drag:[x1,y1,x2,y2]}]}; returns {shots:[paths]}
const { chromium } = require('playwright');
const fs = require('fs'); const http = require('http');
const OUT = '/tmp/claude-0/ptdshots'; fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await b.newContext({ viewport: { width: 800, height: 600 } });
  const p = await ctx.newPage();
  await ctx.route(/ptd\.onl/, async route => {
    const u = route.request().url();
    if (u.includes('PTD1.swf')) return route.fulfill({ status: 200, contentType: 'application/x-shockwave-flash', headers: { 'access-control-allow-origin': '*' }, body: fs.readFileSync('/tmp/claude-0/ptd/game.swf') });
    if (u.includes('ptd1Version')) return route.fulfill({ status: 200, contentType: 'text/plain', headers: { 'access-control-allow-origin': '*' }, body: 'version=1' });
    return route.fulfill({ status: 404, body: '' });
  });
  const errs = [];
  p.on('console', m => { const t = m.text(); if (/error/i.test(t) && !/naga|wgpu|GL Driver|WebGL/i.test(t)) errs.push(t.slice(0, 240)); });
  await p.goto('http://localhost:8877/index.html?swf=wrapper.swf');
  let n = 0;
  http.createServer(async (req, res) => {
    let body = ''; req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { steps } = JSON.parse(body || '{}'); const shots = [];
        for (const s of steps || []) {
          if (s.c) await p.mouse.click(s.c[0], s.c[1]);
          else if (s.m) await p.mouse.move(s.m[0], s.m[1]);
          else if (s.w) await p.waitForTimeout(s.w);
          else if (s.k) await p.keyboard.press(s.k);
          else if (s.md) await p.mouse.down({}) 
          else if (s.mm) await p.mouse.move(s.mm[0], s.mm[1], { steps: s.st || 1 })
          else if (s.mu) await p.mouse.up()
          else if (s.at) await p.mouse.move(s.at[0], s.at[1])
          else if (s.drag) { await p.mouse.move(s.drag[0], s.drag[1]); await p.mouse.down(); await p.mouse.move(s.drag[2], s.drag[3], { steps: 12 }); await p.mouse.up(); }
          else if (s.shot) { const f = `${OUT}/${s.shot}_${n++}.png`; await p.screenshot({ path: f }); shots.push(f); }
        }
        res.end(JSON.stringify({ shots, errs: errs.splice(0).slice(-4) }));
      } catch (e) { res.end(JSON.stringify({ error: String(e) })); }
    });
  }).listen(9000);
  console.log('daemon up');
})();
