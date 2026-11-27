const { chromium } = require('playwright');
module.exports = async function open() {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const p = await b.newPage({ viewport: { width: 800, height: 600 } });
  const logs = [];
  p.on('console', m => logs.push(m.text().slice(0, 200)));
  p.on('pageerror', e => logs.push('ERR ' + String(e).slice(0, 200)));
  await p.goto('http://localhost:8877/index.html');
  return { b, p, logs };
};
