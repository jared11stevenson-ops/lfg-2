#!/usr/bin/env python3
"""Aggregate Grand Simulation results (tools/sim_match.gd output) into the tables used by docs/SIM_REPORT_*.md.
Usage: python3 tools/sim_report.py <dir with s*.json> [--md]"""
import json, glob, sys, collections

args = [a for a in sys.argv[1:] if not a.startswith("--")]
files = sorted(glob.glob(args[0] + "/s*.json"), key=lambda f: int(''.join(c for c in f.split('/')[-1] if c.isdigit()) or 0))
data = [json.load(open(f)) for f in files]
n = len(data)
if n == 0:
    sys.exit("no results")


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def alive_at(d, day):
    best = None
    for r in d["timeline"]:
        if r["day"] <= day:
            best = r
    return best["alive"] if best else 14


print(f"seeds={n} days={data[0]['end_day']-1}")
conq = sum(1 for d in data if d["total_conquest"])
one_w24 = sum(1 for d in data if alive_at(d, 169) <= 1)
print(f"total_conquest={conq}/{n}  exactly_one_alive_by_week24={one_w24}/{n} ({pct(one_w24, n):.0f}%)  one_alive_ever={sum(1 for d in data if d['solo_day'] >= 0)}/{n}")
for day, label in [(57, "week 8"), (85, "week 12"), (169, "week 24"), (337, "week 48")]:
    v = [alive_at(d, day) for d in data]
    print(f"  alive at {label}: mean {sum(v)/n:.1f}  min {min(v)}  max {max(v)}")
last = [d["last_territory_change_day"] for d in data]
after8 = sum(1 for x in last if x > 56)
print(f"territory: last change day mean {sum(last)/n:.0f}, min {min(last)}, seeds still changing after week 8: {after8}/{n}, after week 24: {sum(1 for x in last if x > 168)}/{n}")
wk = collections.defaultdict(list)
for d in data:
    for i, c in enumerate(d["territory_changes_by_week"]):
        wk[i].append(c)
print("  mean territory changes per week (weeks 1,5,9,13,17,25,33,45): " + ", ".join(f"w{i+1}={sum(wk[i])/len(wk[i]):.1f}" for i in [0, 4, 8, 12, 16, 24, 32, 44] if i in wk))
print(f"cpu: mean tick {sum(d['tick_avg_ms'] for d in data)/n:.2f} ms (max {max(d['tick_avg_ms'] for d in data):.2f}), wall/seed {sum(d['wall_s'] for d in data)/n:.0f}s")

# ---- personas
per = collections.defaultdict(lambda: dict(n=0, hold=0, caps=0, elim=0, with_deed=0, deeds=0, rank=0, maxrank=0, nodes=0, lk=0, kinds=collections.Counter(), r0_idle=0, par=0, trib=0))
cls = collections.defaultdict(lambda: dict(n=0, wins=0, elim=0, elim_days=[], caps=0, lk=0, hold=0, rank=0, nodes=0, deeds=0, sp=0, causes=collections.Counter(), alive=0))
for d in data:
    for v in d["factions"].values():
        p = per[v["persona"]]
        tot = sum(v["deeds"].values())
        p["n"] += 1; p["hold"] += v["final_holdings"]; p["caps"] += v["captures"]; p["elim"] += 1 if v["elim_day"] >= 0 else 0
        p["with_deed"] += 1 if tot > 0 else 0; p["deeds"] += tot; p["rank"] += v["final_rank"]; p["maxrank"] += v["max_rank"]
        p["nodes"] += len(v["nodes"]); p["lk"] += v["leader_kills"]; p["par"] += v["parties"]; p["trib"] += v["tributes"]
        for k, c in v["deeds"].items():
            p["kinds"][k] += c
        rw = v["rank_weeks"]
        # rank 0 for >8 consecutive weeks with zero deeds
        run = best = 0
        for r in rw:
            run = run + 1 if r == 0 else 0
            best = max(best, run)
        if best > 8 and tot == 0:
            p["r0_idle"] += 1
        c = cls[v["class"]]
        c["n"] += 1; c["wins"] += 1 if (d["total_conquest"] and v["class"] == d["winner"]) else 0
        if v["elim_day"] >= 0:
            c["elim"] += 1; c["elim_days"].append(v["elim_day"]); c["causes"][v["elim_cause"].split("/")[0] if v["elim_cause"] else "?"] += 1
        c["caps"] += v["captures"]; c["lk"] += v["leader_kills"]; c["hold"] += v["final_holdings"]; c["rank"] += v["final_rank"]
        c["nodes"] += len(v["nodes"]); c["deeds"] += tot; c["sp"] += v["sp_total"]; c["alive"] += 1 if v["alive"] else 0

print("\n## By persona")
print("persona | factions | avg final holdings | captures/faction | leader kills | % with >=1 deed | deeds/faction | avg final rank | avg max rank | eliminated % | R0>8wk&0 deeds | parties/faction | tributes")
for k, p in sorted(per.items()):
    m = p["n"]
    print(f"{k} | {m} | {p['hold']/m:.2f} | {p['caps']/m:.2f} | {p['lk']} | {pct(p['with_deed'], m):.0f}% | {p['deeds']/m:.1f} | {p['rank']/m:.2f} | {p['maxrank']/m:.2f} | {pct(p['elim'], m):.0f}% | {p['r0_idle']} | {p['par']/m:.1f} | {p['trib']}")
print("\n## Deed kinds by persona (total over all seeds)")
kinds = sorted({k for p in per.values() for k in p["kinds"]})
print("persona | " + " | ".join(kinds))
for k, p in sorted(per.items()):
    print(f"{k} | " + " | ".join(str(p['kinds'][x]) for x in kinds))

print("\n## By class")
print("class | n | avg final holdings | alive at end % | elim % | avg elim day | captures | leader kills | avg final rank | deeds/faction | skill pts | nodes | wins | elimination causes")
for k, c in sorted(cls.items(), key=lambda kv: -kv[1]["hold"]):
    m = c["n"]
    ed = sum(c["elim_days"]) / len(c["elim_days"]) if c["elim_days"] else -1
    print(f"{k} | {m} | {c['hold']/m:.2f} | {pct(c['alive'], m):.0f}% | {pct(c['elim'], m):.0f}% | {ed:.0f} | {c['caps']/m:.1f} | {c['lk']} | {c['rank']/m:.2f} | {c['deeds']/m:.1f} | {c['sp']/m:.0f} | {c['nodes']/m:.1f} | {c['wins']} | {dict(c['causes'])}")
holds = [c["hold"] / c["n"] for c in cls.values()]
mean_h = sum(holds) / len(holds)
print(f"class spread (avg final holdings): min {min(holds):.2f}, max {max(holds):.2f}, mean {mean_h:.2f}, max/min {max(holds)/max(min(holds),0.01):.1f}x")

# ---- ranks
rc = collections.Counter(); tot = 0
for d in data:
    for r in d["timeline"]:
        for rk in r["rank"].values():
            rc[rk] += 1; tot += 1
print("\n## Rank distribution (share of faction-weeks)")
print(" | ".join(f"R{r}: {pct(rc[r], tot):.0f}%" for r in range(6)))
marks = []
for d in data:
    ms = [r["mark"] for r in d["timeline"] if r["mark"] >= 0]
    marks.append((len(set(ms)), len(ms)))
print(f"Marked faction changes: mean distinct marked factions per seed {sum(a for a, b in marks)/n:.1f}; seeds with a single permanent mark (>=20 marked weeks): {sum(1 for a, b in marks if a == 1 and b >= 20)}/{n}")

# ---- abilities
ab = collections.defaultdict(collections.Counter)
for d in data:
    for k, row in d["ability_log"].items():
        for r, c in row.items():
            ab[k][r] += c
print("\n## Per-ability attempts (AI leaders via Abilities.use)")
print("ability | attempts | ok | failure reasons")
for k, row in sorted(ab.items()):
    t = sum(row.values())
    fails = {r: c for r, c in row.items() if r != "ok"}
    print(f"{k} | {t} | {row.get('ok',0)} ({pct(row.get('ok',0), t):.0f}%) | {fails}")

# ---- kills
kc = collections.Counter(); ec = collections.Counter(); ld = collections.Counter()
for d in data:
    kc.update(d["kill_causes"]); ld.update(d.get("leader_damage", {}))
    for v in d["factions"].values():
        if v["elim_day"] >= 0:
            ec[(v["elim_cause"] or "?").split("/")[0]] += 1
print(f"\n## Leader deaths by cause (last damage tag/source kind): {dict(kc)}")
print(f"## Faction eliminations by cause: {dict(ec)}")
print(f"## Damage taken by leaders by tag: {dict(ld)}")

# ---- nodes
br = collections.Counter(); nodes_c = collections.Counter()
for d in data:
    for v in d["factions"].values():
        for nd in v["nodes"]:
            br[nd.split(".")[1][0]] += 1; nodes_c[nd] += 1
print(f"\n## Skill nodes taken by branch (e=economy p=purge h=hybrid): {dict(br)}; distinct nodes taken {len(nodes_c)}/210")
fulltree = sum(1 for d in data for v in d["factions"].values() if len(v["nodes"]) >= 15)
print(f"factions that finished their whole tree: {fulltree}/{n*14}; mean nodes {sum(len(v['nodes']) for d in data for v in d['factions'].values())/(n*14):.1f}")
# ---- win/stall
print("\n## Per seed")
print("seed | end_day | conquest | alive@w24 | alive@end | neutral | last change day | leader deaths | winner")
for d in data:
    print(f"{d['seed']} | {d['end_day']-1} | {d['total_conquest']} | {alive_at(d,169)} | {len(d['alive_final'])} | {d['neutral_holdings']} | {d['last_territory_change_day']} | {sum(d['kill_causes'].values())} | {d['winner']}")
