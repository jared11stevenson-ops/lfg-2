"""Lineup of all baked creatures at in-game size (idle row + attack row) to check scale/colour/face consistency."""
import sys, os
from PIL import Image
frames, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3:]
S = 150
sheet = Image.new("RGBA", (S * len(ids), S * 3), (70, 60, 70, 255))
for c, cid in enumerate(ids):
    for r, name in enumerate((f"{cid}_idle_0", f"{cid}_attack_2", f"{cid}_walk_3")):
        p = os.path.join(frames, name + ".png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA").resize((S, S), Image.LANCZOS)
            sheet.alpha_composite(im, (c * S, r * S))
sheet.convert("RGB").save(out)
