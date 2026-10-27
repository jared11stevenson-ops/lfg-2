#!/usr/bin/env python3
"""Compare headline numbers of result dirs (same seeds) : python3 tools/sim_variant.py base varA varB ..."""
import json, glob, sys
def maxstall(d):
    best = run = 0
    wk = d["territory_changes_by_week"]
    for c in wk:
        run = 0 if c > 0 else run + 7
        best = max(best, run)
    return best
for dr in sys.argv[1:]:
    ds = [json.load(open(f)) for f in glob.glob(dr + "/s*.json")]
    n = len(ds)
    conq = sum(d["total_conquest"] for d in ds)
    solo = sum(d["solo_day"] >= 0 for d in ds)
    alive = sum(len(d["alive_final"]) for d in ds) / n
    el = 14 - alive
    st = [maxstall(d) for d in ds]
    neutral = sum(d["neutral_holdings"] for d in ds if not d["total_conquest"]) / max(1, sum(1 for d in ds if not d["total_conquest"]))
    wins = {}
    for d in ds:
        if d["total_conquest"]: wins[d["winner"]] = wins.get(d["winner"], 0) + 1
    rev = sum(v["revolts"] for d in ds for v in d["factions"].values()) / n
    print(f"{dr.split('/')[-1]}: n={n} conquests {conq}, solo {solo}, mean alive at end {alive:.1f} (elim/match {el:.1f}), seeds with stall>56d {sum(1 for s in st if s>56)}, max stall {max(st)}, neutral at end {neutral:.1f}, revolts/match {rev:.0f}, wins {wins}, cpu {sum(d['tick_avg_ms'] for d in ds)/n:.2f}")
