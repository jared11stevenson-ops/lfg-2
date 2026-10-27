import json, glob, sys, collections
files = sorted(glob.glob(sys.argv[1] + "/s*.json"))
cls = collections.defaultdict(lambda: dict(n=0, wins=0, elim=0, elim_days=[], caps=0, kills=0, ab=0, hold=0, impl=False))
ended = 0
for f in files:
    d = json.load(open(f))
    if d["solo_last_standing"]: ended += 1
    for v in d["factions"].values():
        c = cls[v["class"]]; c["n"] += 1; c["impl"] = v["implemented"]
        c["wins"] += 1 if v["class"] == d["winner"] else 0
        if v["elim_day"] >= 0: c["elim"] += 1; c["elim_days"].append(v["elim_day"])
        c["caps"] += v["captures"]; c["kills"] += v["kills"]; c["ab"] += v["ability_uses"]
    for k, h in d["final_holdings"].items(): cls[k]["hold"] += h
print(f"matches={len(files)} ended_with_one_standing={ended}")
print("class   impl  wins elim% avgElimDay caps kills abilityUses avgFinalHoldings")
for k, c in sorted(cls.items(), key=lambda kv: -kv[1]["hold"]):
    ed = sum(c["elim_days"]) / len(c["elim_days"]) if c["elim_days"] else -1
    print(f"{k:6} {str(c['impl'])[0]:>4} {c['wins']:5} {100*c['elim']/c['n']:5.0f} {ed:9.0f} {c['caps']:5} {c['kills']:5} {c['ab']:7} {c['hold']/c['n']:8.2f}")
