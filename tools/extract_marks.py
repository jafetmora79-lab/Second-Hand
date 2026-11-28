"""Cuts the antique-mark atlases (docs/concepts/marks/atlas_1.webp, atlas_2.webp) into the game's mark textures (assets/textures/antiques/<kind>/).

Three kinds of processing, by how the mark is made on the object:
  piece   a separate thing on the object (a paper sticker, a brass plaque, a lens ring): cut out with its shadow removed;
  letters lettering struck, engraved, embossed or carved INTO the object: only the dark letters are kept, so they sit in the object's own
          metal or wood instead of on a plate;
  ink     a blue pottery stamp: only the blue ink is kept, the paper behind it is dropped.
Two marks are drawn here because the atlas has no tile for them: the carved date "1952" on the bear copy (the atlas tile says 2019, which
the 1956 story cannot use, and its digits have no 5), and the serial numbers stamped in the mismatched watch.
Run: python tools/extract_marks.py  (needs Pillow, numpy and scipy)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "docs", "concepts", "marks")
OUT = os.path.join(ROOT, "assets", "textures", "antiques")

# name: (atlas, box (x0, y0, x1, y1), kind of processing, output width in px, settings for "letters":
#   thr how much darker than the plate face a pixel must be to count as cut; inset (x, y) of the plate's rim to leave out;
#   oval True for an oval plate (the rim follows an ellipse))
MARKS = {
    "music_box/lindqvist_struck": ("atlas_1", (214, 10, 575, 134), "letters", 256, {"thr": 30, "inset": (0.08, 0.16)}),
    "music_box/lindqvist_printed": ("atlas_1", (600, 11, 925, 129), "piece", 256, {}),
    "music_box/lindquist_struck": ("atlas_1", (949, 10, 1319, 133), "letters", 256, {"thr": 30, "inset": (0.08, 0.16)}),
    "pocket_watch/925_1911": ("atlas_1", (251, 148, 555, 226), "letters", 256, {"thr": 30, "inset": (0.07, 0.16)}),
    "pocket_watch/925_qqq": ("atlas_1", (619, 147, 912, 225), "letters", 256, {"thr": 30, "inset": (0.07, 0.16)}),
    "pocket_watch/952_1911": ("atlas_1", (984, 148, 1285, 225), "letters", 256, {"thr": 30, "inset": (0.07, 0.16)}),
    "carved_bear/eh": ("atlas_1", (202, 240, 571, 355), "letters", 256, {"thr": 20, "inset": (0.06, 0.1), "close": 2, "minsz": 60}),
    "carved_bear/ek": ("atlas_1", (967, 240, 1327, 355), "letters", 256, {"thr": 20, "inset": (0.06, 0.1), "close": 2, "minsz": 60}),
    "compass/hall_sons": ("atlas_1", (207, 363, 564, 509), "letters", 256, {"thr": 26, "oval": True}),
    "compass/hall_son": ("atlas_1", (590, 362, 941, 508), "letters", 256, {"thr": 26, "oval": True}),
    "compass/made_in_china": ("atlas_1", (966, 362, 1323, 508), "letters", 256, {"thr": 26, "oval": True}),
    "lantern/dietz_blizzard": ("atlas_2", (787, 89, 1019, 253), "letters", 256, {"thr": 22, "inset": (0.12, 0.13), "erase": [(0.0, 0.0, 0.3, 0.34)]}),
    "lantern/deitz_blizzard": ("atlas_2", (1032, 91, 1262, 252), "letters", 256, {"thr": 22, "inset": (0.12, 0.13)}),
    "lantern/dietz_repro": ("atlas_2", (1276, 91, 1505, 252), "letters", 256, {"thr": 22, "inset": (0.12, 0.13), "erase": [(0.93, 0.0, 1.0, 0.3), (0.9, 0.64, 1.0, 1.0)]}),
    "camera/tessar_145": ("atlas_1", (160, 663, 398, 902), "ring", 128, {}),
    "camera/tessar_q": ("atlas_1", (469, 662, 705, 902), "ring", 128, {}),
    "camera/tesar_145": ("atlas_1", (778, 663, 1016, 902), "ring", 128, {}),
    "snow_globe/pinecrest_1952": ("atlas_1", (1080, 536, 1406, 663), "piece", 256, {}),
    "snow_globe/pinecrest_sticker": ("atlas_1", (1082, 682, 1400, 791), "piece", 256, {}),
    "snow_globe/pinecrest_1925": ("atlas_1", (1078, 809, 1408, 939), "piece", 256, {}),
    "snow_globe/price_49c": ("atlas_1", (884, 908, 1050, 1017), "piece", 128, {}),
    "jug/crown": ("atlas_1", (132, 908, 308, 1017), "ink", 128, {}),
    "jug/red_wings": ("atlas_1", (338, 914, 600, 1010), "ink", 128, {}),
    "jug/crown_r": ("atlas_1", (630, 907, 849, 1017), "ink", 128, {}),
}


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name + ".webp")).convert("RGBA")).astype(np.float32)


def trim(a, pad=2):
    ys, xs = np.nonzero(a[..., 3] > 8)
    if len(xs) == 0:
        return a
    return a[max(ys.min() - pad, 0):ys.max() + pad + 1, max(xs.min() - pad, 0):xs.max() + pad + 1]


def piece(c):
    """A separate object: keep it, drop the soft drop shadow (low alpha) and fringe."""
    a = c.copy()
    al = a[..., 3]
    al[al < 200] = 0                                    # the shadow is the half-transparent halo round the piece
    a[..., 3] = al
    return a


def ring(c):
    """A lens ring: the piece, with its centre cleared so the lens glass shows through."""
    a = piece(c)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - w / 2.0, yy - h / 2.0)
    inner = min(w, h) * 0.5 * 0.62                      # a hole wide enough that the ring sits on the rim, clear of the lens glass
    a[..., 3][r < inner] = 0
    return a


def letters(c, thr=30.0, inset=(0.1, 0.18), oval=False, close=1, minsz=12, erase=()):
    """Lettering pressed into a plate: keep what is clearly darker than the plate's face, inside its rim, as whole strokes."""
    a = c.copy()
    rgb = a[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    solid = a[..., 3] > 200
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w]
    if oval:                                            # the rim of an oval plate follows the ellipse
        inner = (((xx - w / 2.0) / (w * 0.42)) ** 2 + ((yy - h / 2.0) / (h * 0.38)) ** 2 < 1.0) & solid
    else:
        inner = (xx > w * inset[0]) & (xx < w * (1 - inset[0])) & (yy > h * inset[1]) & (yy < h * (1 - inset[1])) & solid
    # darker than the plate face AROUND it (a wide blur of the face), so uneven light on the plate doesn't eat strokes
    face = ndimage.gaussian_filter(np.where(inner, lum, np.median(lum[inner])), sigma=max(h, w) * 0.06)
    dark = np.clip((face - lum - thr) / 40.0, 0.0, 1.0)
    dark = np.where(inner, dark, 0.0)
    # whole strokes only: join the pieces of each letter, then drop loose specks (grain, scratches) smaller than a full stop
    mask = ndimage.binary_closing(dark > 0.3, iterations=close)
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(np.ones_like(dark), lab, range(1, n + 1))
    keep_ids = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        bh = sl[0].stop - sl[0].start
        bw = sl[1].stop - sl[1].start
        cx = (sl[1].start + sl[1].stop) / 2.0 / w
        if sizes[i] < minsz:
            continue                                    # a speck
        if bw > 3 * bh and bh < h * 0.2:
            continue                                    # a thin streak: wood grain, a scratch, the plate's rim
        if cx < 0.11 or cx > 0.89:
            continue                                    # what is left of the rim at the ends
        cy = (sl[0].start + sl[0].stop) / 2.0 / h
        if cy < 0.3 and (cx < 0.2 or cx > 0.8) and sizes[i] < 400:
            continue                                    # the curve of an arched plate's top corners
        if sl[0].stop < h * 0.3:
            continue                                    # anything lying wholly in the top band is the plate's arch, not lettering
        if sl[0].start > h * 0.82 and sizes[i] < 150:
            continue                                    # rivet traces along the bottom edge
        if bw > 1.6 * bh and cy < 0.36 and (cx < 0.25 or cx > 0.75) and sizes[i] < 900:
            continue                                    # a flat arc of the plate's top, at a corner
        keep_ids.append(i + 1)
    keep = np.isin(lab, keep_ids)
    keep = ndimage.binary_dilation(keep, iterations=1)
    al = np.where(keep, np.maximum(dark, 0.55 * keep), 0.0) * 255.0
    for (ex0, ey0, ex1, ey1) in erase:                  # hand-cleared spots: a leftover of the plate the rules above miss
        al[int(ey0 * h):int(ey1 * h), int(ex0 * w):int(ex1 * w)] = 0.0
    out = np.zeros_like(a)
    out[..., :3] = rgb * 0.75                           # the letter colour, a touch deeper: the shadow inside a cut
    out[..., 3] = al
    return out


def ink(c):
    """A blue stamp on paper: keep the blue ink, drop the cream paper."""
    a = c.copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = np.clip((b - r - 4.0) / 22.0, 0.0, 1.0) ** 0.7
    out = np.zeros_like(a)
    out[..., :3] = np.array([38.0, 62.0, 150.0], np.float32)       # one cobalt stamp blue, worn only through its alpha
    out[..., 3] = blue * (a[..., 3] > 200) * 255.0
    return out


def save(name, a, width):
    a = trim(a)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    h = max(1, round(im.height * width / im.width))
    im = im.resize((width, h), Image.LANCZOS)
    path = os.path.join(OUT, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("%-36s %dx%d" % (name, im.width, im.height))
    return im


def drawn_letters(text, font_path, size, colour, italic_shear=0.0):
    """Lettering drawn here in the atlas's style (dark, cut in): for the two marks the atlas has no tile for."""
    f = ImageFont.truetype(font_path, size)
    l, t, r, b = f.getbbox(text)
    shade = tuple(max(0, int(c * 0.6)) for c in colour)
    im = Image.new("RGBA", (r - l + 16, b - t + 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.text((9 - l, 9 - t), text, font=f, fill=shade + (255,))                # the deep side of the cut
    d.text((8 - l, 8 - t), text, font=f, fill=colour + (255,))
    if italic_shear:
        im = im.transform(im.size, Image.AFFINE, (1, italic_shear, -italic_shear * im.height * 0.5, 0, 1, 0), Image.BICUBIC)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    return np.asarray(im).astype(np.float32)


def main():
    atlases = {n: load(n) for n in ("atlas_1", "atlas_2")}
    made = {}
    for name, (atlas, (x0, y0, x1, y1), how, width, opts) in MARKS.items():
        c = atlases[atlas][y0:y1, x0:x1]
        a = letters(c, **opts) if how == "letters" else {"piece": piece, "ring": ring, "ink": ink}[how](c)
        made[name] = trim(a)
        save(name, a, width)
    fonts = "C:/Windows/Fonts/"
    serif_i = fonts + ("georgiaz.ttf" if os.path.exists(fonts + "georgiaz.ttf") else "timesbi.ttf")      # bold italic, like the carving
    serif = fonts + ("georgiab.ttf" if os.path.exists(fonts + "georgiab.ttf") else "timesbd.ttf")
    # the bear copy: the atlas's carved "E.H." with a carved "1952" beside it, in the same dark carved colour
    eh = made["carved_bear/eh"]
    col = tuple(int(v) for v in np.median(eh[..., :3][eh[..., 3] > 180], axis=0))
    digits = drawn_letters("1952", serif_i, int(eh.shape[0] * 0.72), col)
    h = max(eh.shape[0], digits.shape[0])
    both = np.zeros((h, eh.shape[1] + digits.shape[1] + 10, 4), np.float32)
    both[(h - eh.shape[0]) // 2:(h - eh.shape[0]) // 2 + eh.shape[0], :eh.shape[1]] = eh
    off = eh.shape[1] + 10
    both[(h - digits.shape[0]) // 2:(h - digits.shape[0]) // 2 + digits.shape[0], off:off + digits.shape[1]] = digits
    save("carved_bear/eh_1952", both, 256)
    # the watch marriage: two serial numbers stamped in, the case's and the movement's
    wt = made["pocket_watch/925_1911"]
    col2 = tuple(int(v) for v in np.median(wt[..., :3][wt[..., 3] > 180], axis=0))
    save("pocket_watch/serials", drawn_letters("31840 · 77215", serif, 44, col2), 256)
    # the tin toy car's maker, printed on its tin: a stand-in drawn here until the batch-7 mark atlas (docs/CHATGPT_PROMPTS.md) arrives
    save("toy_car/brandt", drawn_letters("BRANDT · NÜRNBERG", serif, 44, (236, 222, 186)), 256)


if __name__ == "__main__":
    main()
