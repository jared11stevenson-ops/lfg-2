#!/usr/bin/env python3
"""Per-class leader-death and elimination analysis of Grand Simulation output (needs the pass-3b death log). Usage: python3 tools/sim_deaths.py <dir>"""
import json, glob, sys, collections
files = sorted(glob.glob(sys.argv[1] + "/s*.json"))
data = [json.load(open(f)) for f in files]
cls = collections.defaultdict(lambda: dict(n=0, elim=0, deaths=0, by_tag=collections.Counter(), by_at=collections.Counter(), hp=[], day=[], killers=collections.Counter(), lost_day=[], kit=collections.Counter(), hold=[]))
for d in data:
    for v in d["factions"].values():
        c = cls[v["class"]]
        c["n"] += 1
        c["elim"] += 1 if v["elim_day"] >= 0 else 0
        for k, n in v.get("kit", {}).items():
            c["kit"][k] += n
        for dt in v.get("deaths", []):
            c["deaths"] += 1
            c["by_tag"][dt["tag"] + "/" + dt["src"]] += 1
            c["by_at"][dt["at"]] += 1
            c["hp"].append(dt["hp_before"]); c["day"].append(dt["day"])
            c["killers"][dt["killer_class"] or "-"] += 1
            c["hold"].append(dt["holdings"])
        if v["elim_day"] >= 0 and v["elim_cause"] == "holdings_lost":
            c["lost_day"].append(v["elim_day"])
print("class  n elim% deaths | at | mean hp_before | mean day | holdings at death | tags | top killers | kit uses")
for k, c in sorted(cls.items(), key=lambda x: -x[1]["elim"]):
    m = lambda a: sum(a) / len(a) if a else 0
    print(f"{k:6} {c['n']:3} {100*c['elim']/c['n']:3.0f}% d={c['deaths']:3} at={dict(c['by_at'])} hp={m(c['hp']):.2f} day={m(c['day']):.0f} h={m(c['hold']):.1f} tags={dict(c['by_tag'].most_common(3))} killers={dict(c['killers'].most_common(3))} lostland_day={m(c['lost_day']):.0f}(n={len(c['lost_day'])}) kit={dict(c['kit'].most_common(3))}")
