# Running PTD1 (the Android APK) headless
1. Unzip the APK: `assets/PTD1.swf` is an AIR wrapper (129 KB). It downloads the real game (13.6 MB) from `http://ptd.onl/android/PTD1.swf` and asks `.../ptd1Version.php` for `version=<n>`.
2. Serve a folder with Ruffle (`@ruffle-rs/ruffle@0.9.0-nightly`, `ruffle.js` + wasm), the wrapper as `wrapper.swf`, and this `index.html` (`?swf=wrapper.swf`).
3. `ptd_daemon.js` (Playwright + Chromium) routes the two ptd.onl requests to local files and exposes `POST :9000/act` with steps `c` (click), `at`/`md`/`mm`/`mu` (staged drag), `w` (wait), `k` (key), `shot`.
Game quirks: drags must be staged (move, press, move in steps, wait, release); towers only drop on the orange free spots; progress only persists after the main-menu **Save** button (it also auto-saves on some screens); waves run in real time even at x1.
The game files themselves are third-party and are not committed.
