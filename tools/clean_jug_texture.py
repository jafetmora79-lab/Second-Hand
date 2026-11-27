"""Paints the blue crown out of the Meshy jug's own texture (assets/items/jug_0.png).
Meshy baked a crown stamp into the jug, so every version showed it, and the RED WINGS copy showed both stamps. The stamp is now drawn per
version by scripts/marks.gd (the real crown, RED WINGS, the crown with ®), so the jug's glaze must be blank where it sat.
Every clearly blue pixel is filled from its unblue neighbours, working inward from the edge of the stamp, so the glaze's pixel pattern
continues across. Works from the untouched original, docs/concepts/marks/jug_0.orig.png. Run: python tools/clean_jug_texture.py  (needs Pillow, numpy, scipy)
"""
import os
import shutil
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TEX = os.path.join(ROOT, "assets", "items", "jug_0.png")
ORIG = os.path.join(ROOT, "docs", "concepts", "marks", "jug_0.orig.png")      # the untouched Meshy texture, kept in the repo


# where the baked stamp is in the jug's texture: the crown, and the two bluish lines of its label band (x0, y0, x1, y1 as fractions)
STAMP_AREAS = [(0.19, 0.56, 0.40, 0.71), (0.29, 0.36, 0.33, 0.54), (0.37, 0.36, 0.46, 0.5)]


def main():
    if not os.path.exists(ORIG):
        os.makedirs(os.path.dirname(ORIG), exist_ok=True)
        shutil.copy(TEX, ORIG)
    im = Image.open(ORIG).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    inky = (b > r - 32) & (lum > 25)                            # the stamp's grey-blue ink (the cream glaze is far warmer: b - r < -50)
    h, w = lum.shape
    area = np.zeros_like(inky)
    for (x0, y0, x1, y1) in STAMP_AREAS:                        # only where Meshy painted the stamp (fractions of the texture)
        area[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)] = True
    todo = ndimage.binary_dilation(inky & area, iterations=3) & area & (lum > 20)      # the ink and its soft edge; never the black gaps
    print("stamp pixels:", int(todo.sum()))
    filled = a.copy()
    known = ~todo & (lum > 60)                                  # fill from glaze only, never from the black gaps between islands
    while todo.any():
        ring = todo & ndimage.binary_dilation(known)
        if not ring.any():
            break
        acc = np.zeros_like(filled)
        cnt = np.zeros(todo.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                sh = np.roll(np.roll(filled, dy, 0), dx, 1)
                kn = np.roll(np.roll(known, dy, 0), dx, 1)
                acc += sh * kn[..., None]
                cnt += kn
        ys, xs = np.nonzero(ring)
        filled[ys, xs] = acc[ys, xs] / np.maximum(cnt[ys, xs], 1)[..., None]
        todo[ys, xs] = False
        known[ys, xs] = True                                    # filled pixels feed the next ring inward
    Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8)).save(TEX)
    print("cleaned", TEX)


if __name__ == "__main__":
    main()
