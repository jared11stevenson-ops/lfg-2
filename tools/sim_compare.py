#!/usr/bin/env python3
"""Before/after per-class comparison of two Grand Simulation result directories (docs/SIM_REPORT_pass3b.md).
Usage: python3 tools/sim_compare.py <before dir> <after dir>"""
import json, glob, sys, collections

def load(d):
    return [json.load(open(f)) for f in sorted(glob.glob(d + "/s*.json"), key=lambda f: int(''.join(c for c in f.split('/')[-1] if c.isdigit())))]

def stats(data):
    cls = collections.defaultdict(lambda: dict(n=0, elim=0, hold=0, caps=0, days=0, wins=0, h24=0, deeds=0))
    def snap(d, c, day):
        best = None
        for r in d["timeline"]:
            if r["day"] <= day:
                best = r
        return 0 if best is None else best["holdings"].get(c, 0)
    for d in data:
        for v in d["factions"].values():
            c = cls[v["class"]]
            c["n"] += 1; c["elim"] += 1 if v["elim_day"] >= 0 else 0; c["hold"] += v["final_holdings"]; c["caps"] += v["captures"]
            c["days"] += v["elim_day"] if v["elim_day"] >= 0 else d["end_day"] - 1; c["deeds"] += sum(v["deeds"].values())
            c["h24"] += snap(d, v["class"], 169)
        if d["total_conquest"]:
            cls[d["winner"]]["wins"] += 1
    return cls

a, b = load(sys.argv[1]), load(sys.argv[2])
sa, sb = stats(a), stats(b)
ma = sum(c["hold"] / c["n"] for c in sa.values()) / 14; mb = sum(c["hold"] / c["n"] for c in sb.values()) / 14
ha = sum(c["h24"] / c["n"] for c in sa.values()) / 14; hb = sum(c["h24"] / c["n"] for c in sb.values()) / 14
print(f"| class | eliminated before | after | final holdings x mean before | after | holdings wk24 x mean before | after | wins before | after |")
print("|---|---|---|---|---|---|---|---|---|")
for k in sorted(sb, key=lambda k: -sb[k]["hold"]):
    x, y = sa[k], sb[k]
    print(f"| {k} | {100*x['elim']/x['n']:.0f}% | {100*y['elim']/y['n']:.0f}% | {x['hold']/x['n']:.2f} ({x['hold']/x['n']/ma:.2f}x) | {y['hold']/y['n']:.2f} ({y['hold']/y['n']/mb:.2f}x) | {x['h24']/x['n']:.2f} ({x['h24']/x['n']/ha:.2f}x) | {y['h24']/y['n']:.2f} ({y['h24']/y['n']/hb:.2f}x) | {x['wins']} | {y['wins']} |")
def summary(data, st):
    n = len(data)
    mx = max(100 * c["elim"] / c["n"] for c in st.values())
    return n, sum(1 for d in data if d["total_conquest"]), mx, sum(1 for c in st.values() if 100 * c["elim"] / c["n"] > 75), sum(d["tick_avg_ms"] for d in data) / n
for name, data, st in (("before", a, sa), ("after", b, sb)):
    n, conq, mx, over, ms = summary(data, st)
    print(f"{name}: seeds {n}, conquests {conq}, max class elimination {mx:.0f}%, classes above 75%: {over}/14, cpu {ms:.2f} ms/tick")
