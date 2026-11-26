"""Face close-up render:  python3 closeup.py <creature> <out.png>"""
import sys, os, importlib
sys.path.insert(0, os.path.dirname(__file__))
from rig import *
FACE = {"tickindle": ((0.75, 0.0, 1.35), 1.9), "dugloom": ((1.25, 0.0, 1.05), 2.2), "hutzin": ((0.95, 0.0, 1.95), 1.8),
        "shuckit": ((1.2, 0.0, 1.25), 1.9), "zapnose": ((0.9, 0.0, 1.55), 2.0), "glomm": ((0.9, 0.0, 0.9), 2.2)}
name, out = sys.argv[1], sys.argv[2]
mod = importlib.import_module(name)
r = mod.build("")
tgt, ortho = FACE[name]
closeup(r, mod.pose, out, tgt, ortho)
print("closeup ok")
