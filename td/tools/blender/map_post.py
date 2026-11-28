"""Painterly finishing for the rendered map: bloom, tilt-shift, grade, mist, vignette, grain -> 1920x1080 PNG.
  python3 map_post.py <in.png> <out.png>"""
import sys
import numpy as np
from PIL import Image, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
BLOOM = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0   # <1 for bright snow scenes
THRESH = float(sys.argv[4]) if len(sys.argv) > 4 else 0.62
WARM = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0   # scale of the warm highlight tint
MIST = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
im = Image.open(src).convert("RGB")
W, H = im.size
a = np.asarray(im).astype(np.float32) / 255.0
# bloom from bright/emissive areas
lum = a @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
mask = np.clip((lum - THRESH) * 3.0, 0, 1)[..., None]
bright = Image.fromarray((a * mask * 255).astype(np.uint8))
bl = np.asarray(bright.filter(ImageFilter.GaussianBlur(W / 90))).astype(np.float32) / 255.0
bl2 = np.asarray(bright.filter(ImageFilter.GaussianBlur(W / 30))).astype(np.float32) / 255.0
a = a + (bl * 0.65 + bl2 * 0.5) * BLOOM
# tilt-shift: soften top and bottom edges
blur = np.asarray(im.filter(ImageFilter.GaussianBlur(W / 330))).astype(np.float32) / 255.0
yy = np.linspace(0, 1, H)[:, None, None]
edge = np.clip(np.maximum((0.14 - yy) / 0.14, (yy - 0.86) / 0.14), 0, 1)
a = a * (1 - edge * 0.85) + blur * (edge * 0.85)
# colour grade: teal shadows, warm highlights, mild contrast
l2 = (a @ np.array([0.3, 0.59, 0.11], dtype=np.float32))[..., None]
shadow = np.array([0.02, 0.05, 0.12], dtype=np.float32)
warm = np.array([0.08, 0.03, -0.03], dtype=np.float32)
a = a + shadow * (1 - l2) ** 2 + warm * WARM * l2 ** 2
a = np.clip((a - 0.5) * 1.07 + 0.5, 0, 1)
# soft mist along the bottom and in hollows
rng = np.random.RandomState(4)
n = rng.rand(H // 8 + 1, W // 8 + 1).astype(np.float32)
n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(W / 40))).astype(np.float32) / 255.0
mist = (np.clip((yy[..., 0] - 0.55) / 0.45, 0, 1) * 0.16 + np.clip(n - 0.45, 0, 1) * 0.28)[..., None]
mist = mist * MIST
a = a * (1 - mist) + np.array([0.55, 0.66, 0.85], dtype=np.float32) * mist
# vignette
xx = np.linspace(-1, 1, W)[None, :, None]; yv = np.linspace(-1, 1, H)[:, None, None]
v = 1 - 0.34 * np.clip((xx ** 2 * 0.75 + yv ** 2) - 0.35, 0, 1)
a = a * v
# grain
a = a + (rng.rand(H, W, 1).astype(np.float32) - 0.5) * 0.018
out = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
out = out.resize((1920, 1080), Image.LANCZOS)
out.save(dst, optimize=True)
print("post ok", out.size)
