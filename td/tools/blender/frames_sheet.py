"""Contact sheet of baked frames: rows idle / walk / attack / evolved forms, per creature."""
import sys, os
from PIL import Image
frames, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3:]
S = 128
rows = []
for cid in ids:
    rows.append([(f"{cid}_idle_{i}") for i in range(6)])
    rows.append([(f"{cid}_walk_{i}") for i in range(8)])
    rows.append([(f"{cid}_attack_{i}") for i in range(5)])
    rows.append([f"{cid}_a_idle_0", f"{cid}_a_idle_3", f"{cid}_a_attack_2", f"{cid}_b_idle_0", f"{cid}_b_idle_3", f"{cid}_b_attack_2"])
sheet = Image.new("RGBA", (S * 8, S * len(rows)), (58, 42, 90, 255))
for r, names in enumerate(rows):
    for c, n in enumerate(names):
        p = os.path.join(frames, n + ".png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA").resize((S, S), Image.LANCZOS)
            sheet.alpha_composite(im, (c * S, r * S))
sheet.convert("RGB").save(out)
