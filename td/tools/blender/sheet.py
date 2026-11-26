"""Tile the 4 preview views of a creature into one contact sheet on a night-purple backdrop."""
import sys
from PIL import Image
prefix, out = sys.argv[1], sys.argv[2]
views = ["side", "three_quarter", "front", "back"]
ims = [Image.open(f"{prefix}_{v}.png").convert("RGBA") for v in views]
w, h = ims[0].size
sheet = Image.new("RGBA", (w * 2, h * 2), (58, 42, 90, 255))
for i, im in enumerate(ims):
    sheet.alpha_composite(im, ((i % 2) * w, (i // 2) * h))
sheet = sheet.resize((w * 2 // 2, h * 2 // 2), Image.LANCZOS)
sheet.convert("RGB").save(out)
