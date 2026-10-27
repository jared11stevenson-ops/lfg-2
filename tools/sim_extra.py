#!/usr/bin/env python3
"""Pass 5 extra Grand Simulation analysis (docs/SIM_REPORT_1.md): who kills whom, death place/hp, snowball vs comeback, stalls,
win share by class/persona, match-length distribution, event counts.  Usage: python3 tools/sim_extra.py <dir with s*.json>"""
import json, glob, sys, collections

files = sorted(glob.glob(sys.argv[1] + "/s*.json"), key=lambda f: int(''.join(c for c in f.split('/')[-1] if c.isdigit())))
data = [json.load(open(f)) for f in files]
n = len(data)
CL = ["judd", "mira", "bram", "tavi", "pip", "oren", "vex", "sable", "quill", "forge", "nyx", "rook", "dune", "halo"]
print(f"seeds={n}")

# match length / outcome
ends = [(d["conquest_day"] if d["total_conquest"] else d["end_day"] - 1) for d in data]
conq = [d for d in data if d["total_conquest"]]
print(f"conquests {len(conq)}/{n}; days {sorted(d['conquest_day'] for d in conq)}")
print(f"survivors at end: {collections.Counter(len(d['alive_final']) for d in data)}; solo_day>=0: {sum(1 for d in data if d['solo_day']>=0)}")
print(f"neutral holdings at end (non-conquest): mean {sum(d['neutral_holdings'] for d in data if not d['total_conquest'])/max(1,n-len(conq)):.1f}")
def maxstall(d):
    best = run = 0
    wk = d["territory_changes_by_week"]
    last = max((i for i, c in enumerate(wk) if c > 0), default=-1)
    for c in wk[:last + 1] if d["total_conquest"] else wk:
        run = 0 if c > 0 else run + 7
        best = max(best, run)
    return best
stalls = [maxstall(d) for d in data]
print(f"max stall (days w/o territory change): mean {sum(stalls)/n:.1f}, max {max(stalls)}, seeds >56d: {sum(1 for s in stalls if s>56)}; list {sorted(stalls)[-8:]}")
print(f"last change day mean {sum(d['last_territory_change_day'] for d in data)/n:.0f}")

# winners (conquest) + dominant final holder in non-conquest
wins = collections.Counter(d["winner"] for d in conq)
lead = collections.Counter()
for d in data:
    fh = d["final_holdings"]
    top = max(fh, key=lambda c: fh[c])
    lead[top] += 1
print(f"conquest winners {dict(wins)}")
print(f"largest-holder at end (all seeds) {dict(lead)}")
# winner persona
wp = collections.Counter()
for d in conq:
    wp[d["factions"][str(d["winner_faction"])]["persona"]] += 1
print(f"winner persona {dict(wp)}")

# killers
print("\n## leader deaths: victim class -> killer class (top)")
kv = collections.defaultdict(collections.Counter)
kk = collections.Counter(); vc = collections.Counter()
place = collections.Counter(); hp = []; src = collections.Counter(); tag = collections.Counter(); timing = []
for d in data:
    for v in d["factions"].values():
        for de in v["deaths"]:
            kv[v["class"]][de["killer_class"] or "none"] += 1
            kk[de["killer_class"] or "none"] += 1; vc[v["class"]] += 1
            place[de["at"]] += 1; hp.append(de["hp_before"]); src[de["src"]] += 1; tag[de["tag"]] += 1; timing.append(de["day"])
print(f"deaths {len(timing)} mean day {sum(timing)/max(1,len(timing)):.0f}; place {dict(place)}; src {dict(src)}; tag {dict(tag)}")
if hp:
    print(f"hp_before killing blow: mean {sum(hp)/len(hp):.2f}, share >=0.9 (one-shot-ish) {sum(1 for h in hp if h>=0.9)/len(hp):.0%}")
tot = sum(kk.values())
print("killer class share of leader kills: " + ", ".join(f"{c} {kk[c]}" for c, _ in kk.most_common()))
print("victim class: " + ", ".join(f"{c} {vc[c]}" for c, _ in vc.most_common()))

# eliminations: cause by class, timing buckets
print("\n## elimination day buckets (share of all 14n factions)")
b = collections.Counter()
for d in data:
    for v in d["factions"].values():
        e = v["elim_day"]
        b["alive" if e < 0 else f"<{((e-1)//28+1)*28}"] += 1
print(dict(sorted(b.items(), key=lambda kv: (kv[0] == 'alive', int(kv[0][1:]) if kv[0] != 'alive' else 0))))
cause = collections.Counter(); famine = collections.Counter()
for d in data:
    for v in d["factions"].values():
        if v["elim_day"] >= 0:
            c = (v["elim_cause"] or "?").split("/")[0]
            cause[c] += 1
            if c == "famine":
                famine[v["class"]] += 1
print(f"elim causes {dict(cause)}; famine by class {dict(famine)}")
print(f"starve_days total {sum(v['starve_days'] for d in data for v in d['factions'].values())}; factions with starve_days>0: {sum(1 for d in data for v in d['factions'].values() if v['starve_days']>0)}/{14*n}")

# snowball vs comeback: holder rank at week 12 / 24 vs end
print("\n## snowball vs comeback (leader by holdings at snapshot vs final-largest)")
for day in (57, 85, 169, 253):
    same = 0; tot_ = 0; top_alive_end = 0; rank_final = []
    for d in data:
        snap = None
        for r in d["timeline"]:
            if r["day"] <= day:
                snap = r
        if not snap or not snap["holdings"]:
            continue
        top = max(snap["holdings"], key=lambda c: snap["holdings"][c])
        fh = d["final_holdings"]; ftop = max(fh, key=lambda c: fh[c])
        tot_ += 1; same += 1 if top == ftop else 0
        top_alive_end += 1 if fh.get(top, 0) > 0 else 0
        rk = sorted(fh.values(), reverse=True).index(fh[top]) + 1
        rank_final.append(rk)
    print(f"day {day}: leader == final largest in {same}/{tot_}; leader still alive at end {top_alive_end}/{tot_}; mean final rank of snapshot leader {sum(rank_final)/max(1,len(rank_final)):.1f}")

# land curves by class (mean holdings at snapshot days)
print("\n## mean holdings by class at day (alive or 0)")
days = [8, 29, 57, 85, 141, 197, 253, 309, 337]
print("class | " + " | ".join(f"d{x}" for x in days))
for c in sorted(CL):
    row = []
    for day in days:
        s = 0
        for d in data:
            snap = None
            for r in d["timeline"]:
                if r["day"] <= day:
                    snap = r
            s += (snap["holdings"].get(c, 0) if snap else 0)
        row.append(s / n)
    print(f"{c} | " + " | ".join(f"{x:.1f}" for x in row))

# persona
print("\n## by persona")
pc = collections.defaultdict(lambda: dict(n=0, elim=0, hold=0, par=0, caps=0, win=0, days=0))
for d in data:
    for v in d["factions"].values():
        p = pc[v["persona"]]
        p["n"] += 1; p["elim"] += 1 if v["elim_day"] >= 0 else 0; p["hold"] += v["final_holdings"]; p["par"] += v["parties"]; p["caps"] += v["captures"]
        p["days"] += v["elim_day"] if v["elim_day"] >= 0 else d["end_day"] - 1
for k, p in sorted(pc.items()):
    print(f"{k}: n {p['n']} elim {100*p['elim']/p['n']:.0f}% final hold {p['hold']/p['n']:.2f} parties {p['par']/p['n']:.1f} captures {p['caps']/p['n']:.1f} days alive {p['days']/p['n']:.0f} wins {wp[k]}")

# degenerate strategy indicators
print("\n## degenerate indicators")
ev = collections.Counter()
for d in data:
    ev.update(d.get("ev_counts", {}))
print(f"events: {dict(ev)}")
print(f"steals total {sum(v['steals'] for d in data for v in d['factions'].values())}; tributes {sum(v['tributes'] for d in data for v in d['factions'].values())}; revolts {sum(v['revolts'] for d in data for v in d['factions'].values())}; pacify {sum(v['pacified'] for d in data for v in d['factions'].values())}")
ab = collections.Counter()
for d in data:
    for k, row in d["ability_log"].items():
        ab[k] += sum(row.values())
print("ability attempts: " + ", ".join(f"{k} {c}" for k, c in ab.most_common()))
print(f"marked weeks max per faction: {max(v['marked_weeks'] for d in data for v in d['factions'].values())}; mean tick ms {sum(d['tick_avg_ms'] for d in data)/n:.2f} max {max(d['tick_avg_ms'] for d in data):.2f}; wall/seed {sum(d['wall_s'] for d in data)/n:.0f}s")
# turtle: factions alive at end with <=2 holdings after day 200
tt = sum(1 for d in data for v in d["factions"].values() if v["alive"] and v["final_holdings"] <= 2)
print(f"alive at end holding <=2: {tt}; alive at end total {sum(len(d['alive_final']) for d in data)}")
