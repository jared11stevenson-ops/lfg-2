"""Offline audio synthesis for Wellfall: warm fantasy palette (plucks, FM bells, pads, filtered noise, reverb).
  python3 synth.py <out_dir>
Writes 32 kHz mono 16-bit WAVs: sfx, creature voices, music stems (base + drums, loop-safe) and an ambient bed."""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter, sosfilt

SR = 32000
rng = np.random.RandomState(7)

def T(d): return np.arange(int(SR * d)) / SR
def midi(m): return 440.0 * 2 ** ((m - 69) / 12.0)

def adsr(n, a=0.01, d=0.08, s=0.7, r=0.1):
    a_, d_, r_ = int(a * SR), int(d * SR), int(r * SR)
    e = np.ones(n) * s
    a_ = min(a_, n); e[:a_] = np.linspace(0, 1, a_, endpoint=False) if a_ else e[:0]
    d_end = min(n, a_ + d_)
    e[a_:d_end] = np.linspace(1, s, d_end - a_, endpoint=False) if d_end > a_ else e[a_:d_end]
    r_ = min(r_, n); e[n - r_:] *= np.linspace(1, 0, r_) if r_ else 1
    return e

def lp(x, fc, order=2): return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x)
def hp(x, fc, order=2): return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), x)
def bp(x, lo, hi, order=2): return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)

def sine(f, d, vib=0.0, vibf=5.5):
    t = T(d)
    f = f * (1 + vib * np.sin(2 * np.pi * vibf * t)) if np.isscalar(f) else f
    ph = 2 * np.pi * np.cumsum(f if not np.isscalar(f) else np.full(len(t), f)) / SR
    return np.sin(ph)

def saw(f, d, detune=0.0):
    t = T(d)
    return 2 * np.mod(t * f * (1 + detune), 1.0) - 1

def sweep(f0, f1, d, wave='sine', curve=1.0):
    n = int(SR * d); k = np.linspace(0, 1, n) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == 'sine': return np.sin(ph)
    if wave == 'saw': return 2 * np.mod(ph / (2 * np.pi), 1) - 1
    if wave == 'square': return np.sign(np.sin(ph))
    return np.sin(ph)

def noise(d): return rng.randn(int(SR * d)) * 0.5

def pluck(freq, d, damp=0.5, g=0.995, vol=1.0):
    n = int(SR * d); N = int(round(SR / freq))
    ex = np.zeros(n); ex[:N] = rng.uniform(-1, 1, N)
    ex[:N] = lp(ex[:N], min(6000, freq * 6)) if N > 20 else ex[:N]
    a = np.zeros(N + 2); a[0] = 1; a[N] = -g * damp; a[N + 1] = -g * (1 - damp)
    y = lfilter([1.0], a, ex)
    y = y / (np.max(np.abs(y)) + 1e-9)
    return y * vol * adsr(n, 0.002, 0.05, 1.0, min(0.15, d * 0.4))

def fm_bell(f, d, ratio=3.5, index=2.5, decay=3.5, vol=1.0):
    t = T(d)
    e = np.exp(-decay * t)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * e
    y = np.sin(2 * np.pi * f * t + mod) * e
    return y * vol

def pad(freqs, d, a=0.6, r=0.9, cutoff=1400, vol=1.0):
    y = np.zeros(int(SR * d))
    for f in freqs:
        for det in (-0.006, 0.0, 0.006):
            y += saw(f, d, det) * 0.33
    y = lp(y, cutoff) * adsr(len(y), a, 0.3, 0.85, r)
    return y / max(1, len(freqs)) * vol

def comb(x, delay, g):
    a = np.zeros(delay + 1); a[0] = 1; a[delay] = -g
    return lfilter([1.0], a, x)

def allpass(x, delay, g):
    b = np.zeros(delay + 1); b[0] = g; b[delay] = 1
    a = np.zeros(delay + 1); a[0] = 1; a[delay] = g
    return lfilter(b, a, x)

def reverb(x, wet=0.25, size=1.0, damp=3500):
    ds = [int(SR * s * size) for s in (0.0297, 0.0371, 0.0411, 0.0437)]
    y = sum(comb(x, d, 0.82) for d in ds) / 4
    y = allpass(y, int(SR * 0.005), 0.7); y = allpass(y, int(SR * 0.0017), 0.7)
    y = lp(y, damp)
    return x * (1 - wet * 0.5) + y * wet * 1.6

def place(layers, total):
    out = np.zeros(int(SR * total) + SR * 4)
    for start, y in layers:
        i = int(start * SR)
        out[i:i + len(y)] += y[:len(out) - i]
    return out

def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak

def trim_tail(x, thr=0.002):
    idx = np.nonzero(np.abs(x) > thr * np.max(np.abs(x)))[0]
    return x[:idx[-1] + int(0.05 * SR)] if len(idx) else x

def save(path, x, peak=0.9, trim=True):
    if trim:
        x = trim_tail(x)
    x = norm(x, peak)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())

def fade(x, a=0.002, r=0.01):
    n = len(x); x = x.copy()
    ai, ri = int(a * SR), int(r * SR)
    x[:ai] *= np.linspace(0, 1, ai); x[n - ri:] *= np.linspace(1, 0, ri)
    return x

# ------------------------------------------------------------------ SFX
def sfx():
    S = {}
    S["click"] = fade(sine(900, 0.03) * np.exp(-T(0.03) * 90) * 0.6 + noise(0.03) * np.exp(-T(0.03) * 200) * 0.15)
    th = sweep(190, 80, 0.12) * np.exp(-T(0.12) * 22)
    S["place"] = reverb(place([(0, th * 0.9), (0.0, noise(0.03) * np.exp(-T(0.03) * 150) * 0.3), (0.05, fm_bell(1046, 0.5, 3.0, 1.5, 6.0, 0.35))], 0.6), 0.2)
    S["coin"] = reverb(place([(0, fm_bell(1319, 0.4, 3.5, 2.0, 7.0, 0.7)), (0.07, fm_bell(1760, 0.5, 3.5, 2.0, 6.0, 0.7))], 0.6), 0.15)
    tinkles = [(0.0 + 0.06 * i, fm_bell(rng.choice([1568, 1760, 2093, 1397]), 0.35, 3.5, 2.0, 8.0, 0.4)) for i in range(5)]
    whoosh = lp(noise(0.6), 2500) * np.sin(np.linspace(0, np.pi, int(SR * 0.6))) * 0.5
    S["steal"] = reverb(place(tinkles + [(0.12, whoosh)], 0.9), 0.2)
    S["leak"] = reverb(place([(0, sweep(210, 70, 0.4) * np.exp(-T(0.4) * 5) * 0.8), (0.02, fm_bell(311, 0.7, 1.4, 3.0, 3.0, 0.4))], 0.8), 0.2)
    sh = bp(noise(0.06), 1500, 3800) * np.exp(-T(0.06) * 35) * 0.7 + sweep(620, 940, 0.06) * np.exp(-T(0.06) * 30) * 0.25
    S["shoot"] = fade(sh)
    S["hit"] = fade(sweep(170, 85, 0.05) * np.exp(-T(0.05) * 40) * 0.9 + noise(0.05) * np.exp(-T(0.05) * 90) * 0.25)
    puff = lp(noise(0.22), 1800) * np.exp(-T(0.22) * 12) * 0.7
    S["pop"] = reverb(place([(0, puff), (0, sweep(420, 110, 0.18) * np.exp(-T(0.18) * 14) * 0.4), (0.04, fm_bell(1568, 0.25, 3.0, 1.5, 10.0, 0.2))], 0.4), 0.15)
    arp = [(0.00, 523.25), (0.07, 659.25), (0.14, 783.99), (0.21, 1046.5)]
    S["up"] = reverb(place([(t, fm_bell(f, 0.6, 3.0, 1.6, 5.0, 0.55)) for t, f in arp], 0.9), 0.25)
    S["pulse"] = reverb(sweep(240, 700, 0.3) * adsr(int(SR * 0.3), 0.02, 0.1, 0.5, 0.15) * 0.6, 0.25)
    S["horn"] = reverb(lp(saw(146.8, 0.9) + saw(220.0, 0.9) * 0.8 + saw(293.7, 0.9) * 0.5, 900) * adsr(int(SR * 0.9), 0.25, 0.2, 0.8, 0.35), 0.3)
    S["boss"] = reverb(lp(saw(55, 1.6) + saw(58, 1.6) + saw(82.4, 1.6) * 0.5, 500) * adsr(int(SR * 1.6), 0.5, 0.3, 0.9, 0.6), 0.3)
    win = [(0.0, 587.33), (0.14, 739.99), (0.28, 880.0), (0.42, 1174.7), (0.6, 1480.0)]
    S["win"] = reverb(place([(t, fm_bell(f, 1.2, 3.0, 1.4, 2.5, 0.5)) for t, f in win] + [(0.0, pad([293.7, 369.99, 440], 2.4, 0.3, 1.0, 1100, 0.5))], 2.6), 0.35)
    lose = [(0.0, 440.0), (0.3, 392.0), (0.6, 329.63), (0.9, 293.66)]
    S["lose"] = reverb(place([(t, pluck(f * 0.5, 1.2, 0.5, 0.996, 0.8)) for t, f in lose] + [(0.0, pad([146.8, 174.6, 220], 2.6, 0.4, 1.4, 700, 0.4))], 2.8), 0.35)
    S["capture_throw"] = reverb(place([(0, hp(noise(0.4), 700) * np.sin(np.linspace(0, np.pi, int(SR * 0.4))) * 0.35), (0.0, sweep(500, 1500, 0.38) * adsr(int(SR * 0.38), 0.02, 0.1, 0.5, 0.15) * 0.3)], 0.5), 0.2)
    ok = [(0.0, 783.99), (0.09, 987.77), (0.18, 1174.66), (0.27, 1567.98)]
    S["capture_ok"] = reverb(place([(t, fm_bell(f, 1.0, 3.0, 1.5, 3.5, 0.55)) for t, f in ok] + [(0.3, hp(noise(0.7), 4000) * np.exp(-T(0.7) * 5) * 0.18)], 1.4), 0.35)
    S["capture_fail"] = reverb(place([(0, pluck(392, 0.6, 0.5, 0.993, 0.8)), (0.12, pluck(294, 0.7, 0.5, 0.993, 0.8)), (0, sweep(300, 140, 0.4) * np.exp(-T(0.4) * 7) * 0.4)], 0.9), 0.25)
    S["goal"] = reverb(place([(0.0, fm_bell(880, 0.9, 3.0, 1.5, 3.5, 0.55)), (0.14, fm_bell(1108.7, 0.9, 3.0, 1.5, 3.5, 0.55)), (0.28, fm_bell(1318.5, 1.1, 3.0, 1.5, 3.0, 0.6))], 1.5), 0.3)
    S["levelup"] = reverb(place([(0.05 * i, fm_bell(midi(72 + 2 * i), 0.8, 3.0, 1.5, 4.0, 0.45)) for i in range(7)] + [(0.3, hp(noise(0.9), 3500) * np.exp(-T(0.9) * 4) * 0.12)], 1.4), 0.3)
    return S

def voices():
    V = {}
    def say(f0, f1, d, vib, bright, hurt=False):
        s = 1.35 if hurt else 1.0
        base = sweep(f0 * s, f1 * s, d, 'saw') * 0.6 + sweep(f0 * s * 2, f1 * s * 2, d, 'sine') * 0.25
        y = lp(base, bright)
        y = y * (1 + 0.15 * np.sin(2 * np.pi * vib * T(d)))
        return reverb(fade(y * adsr(len(y), 0.01, 0.05, 0.8, d * 0.35)), 0.15)
    for name, (f0, f1, d, vib, br) in {
        "tickindle": (165, 105, 0.26, 28, 1200), "dugloom": (310, 190, 0.42, 5, 900), "hutzin": (680, 360, 0.3, 20, 2600),
        "shuckit": (520, 300, 0.2, 14, 2200), "glomm": (95, 62, 0.34, 6, 600), "zapnose": (1100, 640, 0.14, 40, 3000)}.items():
        V["v_" + name] = say(f0, f1, d * 0.8, vib, br)
        V["v_" + name + "_hurt"] = say(f0, f1 * 0.8, d * 0.55, vib * 1.4, br, True)
    # Hutzin cackle: three quick pulses
    c = [say(680, 420, 0.1, 30, 2600), say(760, 460, 0.1, 30, 2600), say(840, 400, 0.14, 30, 2600)]
    V["v_hutzin"] = place([(0, c[0]), (0.12, c[1]), (0.24, c[2])], 0.45)
    return V

# ------------------------------------------------------------------ music
BPM = 76.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
CHORDS = [  # Dm9 | Bbmaj7 | Fmaj7 | Cadd9
    dict(root=38, tones=[50, 53, 57, 60, 64]),
    dict(root=34, tones=[46, 50, 53, 57, 62]),
    dict(root=41, tones=[53, 57, 60, 64, 67]),
    dict(root=36, tones=[48, 55, 60, 62, 64]),
]
PENTA = [62, 64, 65, 69, 72, 74, 76, 77]   # D minor-pentatonic-ish melody pool

def tiled(build, bars=8):
    """Build a layer over two loops, add reverb, return the second loop (seamless tail wrap)."""
    L = bars * BAR
    x = build(bars * 2)
    x = reverb(x, 0.32, 1.4)
    i = int(L * SR)
    return x[i:i + i]

def base_layer(bars):
    layers = []
    for b in range(bars):
        ch = CHORDS[(b % 8) // 2 % 4] if False else CHORDS[(b // 1) % 4]
        t0 = b * BAR
        layers.append((t0, pad([midi(m) for m in ch["tones"][:4]], BAR + 1.2, 0.7, 1.1, 1200, 0.5)))
        layers.append((t0, pluck(midi(ch["root"]) * 1.0, BAR * 0.95, 0.5, 0.997, 0.55)))
        layers.append((t0 + 2 * BEAT, pluck(midi(ch["root"] + 7), BAR * 0.5, 0.5, 0.996, 0.3)))
        pat = [0, 2, 1, 3, 2, 4, 3, 2]
        for i, p in enumerate(pat):
            layers.append((t0 + i * BEAT / 2, pluck(midi(ch["tones"][p % len(ch["tones"])] + 12), BEAT * 1.6, 0.5, 0.995, 0.36)))
        if b % 2 == 1 or b % 8 in (0, 4):
            mel = [PENTA[(b * 3 + j * 2) % len(PENTA)] for j in range(3)]
            for j, m in enumerate(mel):
                layers.append((t0 + (0.5 + j * 1.25) * BEAT, fm_bell(midi(m + 12), 1.6, 3.0, 1.2, 2.4, 0.22)))
    return place(layers, bars * BAR + 3)

def drums_layer(bars):
    layers = []
    for b in range(bars):
        t0 = b * BAR
        ch = CHORDS[b % 4]
        for beat in range(4):
            tb = t0 + beat * BEAT
            if beat in (0, 2):
                layers.append((tb, sweep(130, 46, 0.3) * np.exp(-T(0.3) * 9) * 0.9))
            if beat in (1, 3):
                sn = bp(noise(0.18), 1200, 5000) * np.exp(-T(0.18) * 18) * 0.35
                sn[:int(0.12 * SR)] += sweep(230, 170, 0.12) * np.exp(-T(0.12) * 24) * 0.3
                layers.append((tb, sn))
            for h in range(2):
                layers.append((tb + h * BEAT / 2 + BEAT / 4 * (h == 0) * 0, hp(noise(0.05), 6000) * np.exp(-T(0.05) * 60) * (0.16 if h == 0 else 0.1)))
        layers.append((t0, pluck(midi(ch["root"]) * 2, BEAT * 0.9, 0.5, 0.995, 0.4)))
        for i in range(8):
            layers.append((t0 + i * BEAT / 2 + BEAT / 4, pluck(midi(ch["tones"][(i * 2 + 1) % 5] + 24), BEAT * 0.7, 0.5, 0.993, 0.18)))
        if b % 4 == 3:
            for k in range(4):
                layers.append((t0 + 3 * BEAT + k * BEAT / 4, sweep(210 - k * 25, 90, 0.2) * np.exp(-T(0.2) * 12) * 0.5))
    return place(layers, bars * BAR + 3)

def ambient():
    d = 24.0
    t = T(d)
    wind = lp(noise(d), 450) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 12.0 + 1.0)) * 0.9 + lp(noise(d), 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0)) * 0.18
    cr = np.zeros(len(t))
    for _ in range(16):
        s = rng.uniform(0, d - 0.6); f = rng.uniform(4100, 4700)
        n = int(0.28 * SR)
        tt = np.arange(n) / SR
        burst = np.sin(2 * np.pi * f * tt) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 26 * tt))) * np.sin(np.pi * tt / 0.28) * 0.07
        for rep in range(3):
            i = int((s + rep * 0.33) * SR)
            if i + n < len(cr): cr[i:i + n] += burst
    chimes = np.zeros(len(t))
    for s, f in ((3.0, 1568), (11.5, 1318.5), (18.0, 1760)):
        c = fm_bell(f, 2.5, 3.0, 1.0, 1.8, 0.05); i = int(s * SR); chimes[i:i + len(c)] += c[:len(chimes) - i]
    x = wind + cr + chimes
    x = reverb(x, 0.2, 1.2)
    xf = int(0.8 * SR)    # loop crossfade
    out = x[:-xf].copy()
    out[:xf] = out[:xf] * np.linspace(0, 1, xf) + x[-xf:] * np.linspace(1, 0, xf)
    return out

def main(out):
    os.makedirs(out, exist_ok=True)
    for k, v in sfx().items():
        save(os.path.join(out, k + ".wav"), v, 0.85)
    for k, v in voices().items():
        save(os.path.join(out, k + ".wav"), v, 0.8)
    L = int(8 * BAR * SR)
    base = tiled(base_layer)[:L]
    drums = tiled(drums_layer)[:L]
    ref = np.max(np.abs(base)) + 1e-9
    save(os.path.join(out, "music_base.wav"), fade(base / ref, 0.004, 0.004), 0.8, False)
    save(os.path.join(out, "music_drums.wav"), fade(drums / (np.max(np.abs(drums)) + 1e-9), 0.004, 0.004), 0.8, False)
    save(os.path.join(out, "ambient.wav"), ambient(), 0.7, False)
    print("synth ok", len(base) / SR, "s music loop")

if __name__ == "__main__":
    main(sys.argv[1])
