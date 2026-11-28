#!/usr/bin/env python3
"""Diff two JSON simulation reports: future_report.py a.json b.json [--tol 0.05]
Prints changed/added/removed leaf values (numbers flagged if relative change > tol). Exit 1 if differences."""
import json, sys
def flat(x, p=""):
    if isinstance(x, dict):
        for k, v in x.items(): yield from flat(v, f"{p}.{k}" if p else k)
    elif isinstance(x, list):
        for i, v in enumerate(x): yield from flat(v, f"{p}[{i}]")
    else: yield p, x
def main():
    a = sys.argv[1:]; tol = 0.05
    if "--tol" in a: i = a.index("--tol"); tol = float(a[i+1]); del a[i:i+2]
    A = dict(flat(json.load(open(a[0])))); B = dict(flat(json.load(open(a[1]))))
    n = 0
    for k in sorted(set(A) | set(B)):
        if k not in B: print(f"- {k} = {A[k]}"); n += 1
        elif k not in A: print(f"+ {k} = {B[k]}"); n += 1
        elif A[k] != B[k]:
            x, y = A[k], B[k]
            if isinstance(x, (int, float)) and isinstance(y, (int, float)) and not isinstance(x, bool):
                rel = abs(y - x) / max(abs(x), 1e-9)
                if rel <= tol: continue
                print(f"~ {k}: {x} -> {y} ({rel*100:+.1f}%)")
            else: print(f"~ {k}: {x!r} -> {y!r}")
            n += 1
    print(f"{n} difference(s)"); sys.exit(1 if n else 0)
main()
