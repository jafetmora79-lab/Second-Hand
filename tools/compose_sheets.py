"""Lays out tests/variant_sheets.gd's shots as one comparison sheet per antique type: docs/concepts/marks/compare_<kind>.png.
Columns: the real piece, then copies 1-4. Rows: the whole object, its maker's mark at closest inspection, its tell (damage on the real one).
Run: python tools/compose_sheets.py"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHOTS = os.path.join(ROOT, "tools", "shots")
OUT = os.path.join(ROOT, "docs", "concepts", "marks")
KINDS = ["music_box", "pocket_watch", "carved_bear", "compass", "lantern", "camera", "snow_globe", "jug"]
CW, CH = 300, 200


def tile(path, crop):
    if not os.path.exists(path):
        return Image.new("RGB", (CW, CH), (40, 34, 30))
    im = Image.open(path).convert("RGB")
    w, h = im.size
    if crop:                                   # the middle of a close-up: where the mark or tell is
        im = im.crop((w * 0.2, h * 0.15, w * 0.8, h * 0.85))
    return im.resize((CW, CH))


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind in KINDS:
        sheet = Image.new("RGB", (CW * 5 + 6 * 4, 26 + CH * 3 + 4 * 4), (28, 24, 22))
        d = ImageDraw.Draw(sheet)
        for v in range(5):
            x = 4 + v * (CW + 4)
            d.text((x + 4, 6), "real" if v == 0 else "copy %d" % v, fill=(240, 220, 170))
            for r, row in enumerate(["over", "mark", "tell"]):
                sheet.paste(tile(os.path.join(SHOTS, "cmp_%s_%d_%s.png" % (kind, v, row)), row != "over"), (x, 26 + r * (CH + 4)))
        path = os.path.join(OUT, "compare_%s.png" % kind)
        sheet.save(path)
        print(path)


if __name__ == "__main__":
    main()
