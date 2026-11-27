"""Cuts the user's UI sheet (assets/ui/ui_sheet.png, transparent background) into the pieces the HUD uses, as 9-slice textures.

Pieces with words baked in (the green and red buttons, the title plaque) are cleaned: the middle is rebuilt by repeating a clean
strip from just inside the left corner, so the game can write its own words on them.
Run: python -I tools/slice_ui.py
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "assets", "ui", "ui_sheet.png")
OUT = os.path.join(ROOT, "assets", "ui")

# name: (x0, y0, x1, y1) on the sheet, and for baked words the clean strip (from, to) to repeat, measured from the left edge
PIECES = {
    "icon_calendar": ((1084, 22, 1243, 132), None),
    "icon_coins": ((1272, 22, 1440, 132), None),
    "icon_shelf": ((1470, 22, 1632, 132), None),
    "parch_wide": ((488, 24, 1058, 286), None),
    "btn_go": ((1288, 152, 1666, 250), (24, 36)),
    "btn_plank": ((1075, 154, 1277, 230), None),
    "parch_tall": ((15, 175, 467, 824), None),
    "btn_paper": ((1075, 249, 1277, 328), None),
    "dark_wide": ((482, 310, 1058, 515), None),
    "btn_plank2": ((1074, 347, 1277, 426), None),
    "btn_stop": ((1293, 431, 1665, 519), (24, 36)),
    "btn_dark": ((1074, 441, 1277, 520), None),
    "arrow_ll": ((1294, 530, 1381, 606), None),
    "arrow_l": ((1393, 530, 1475, 606), None),
    "arrow_r": ((1487, 530, 1568, 606), None),
    "arrow_rr": ((1580, 530, 1665, 606), None),
    "parch_strip": ((485, 534, 1263, 714), None),
    "pip_full": ((1294, 692, 1342, 739), None),
    "pip_empty": ((1543, 692, 1591, 738), None),
    "dark_square": ((487, 737, 650, 914), None),
    "dark_long": ((667, 741, 1659, 912), None),
    "parch_tag": ((22, 840, 283, 916), None),
}

SCALE = 0.5
sheet = Image.open(SHEET).convert("RGBA")
for name, (box, strip) in PIECES.items():
    p = sheet.crop(box)
    if strip is not None:
        w, h = p.size
        a, b = strip
        src = p.crop((a, 0, b, h))
        sw = b - a
        x = b
        while x < w - a:
            piece = src if x + sw <= w - a else src.crop((0, 0, w - a - x, h))
            p.paste(piece, (x, 0))
            x += sw
    p = p.resize((round(p.width * SCALE), round(p.height * SCALE)), Image.BOX)   ## the sheet is drawn at twice the HUD's size
    p.save(os.path.join(OUT, name + ".png"))
    print(name, p.size)
