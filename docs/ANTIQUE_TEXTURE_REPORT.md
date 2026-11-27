# Antique texture and authenticity upgrade: implementation report

Branch `art/antique-texture-upgrade` (from `jam-roadmap`). Not merged; waiting for visual approval.

## What changed

- **Mark artwork.** The two supplied atlases (`docs/concepts/marks/atlas_1.webp`, `atlas_2.webp`) were cut into 26 transparent PNGs under
  `assets/textures/antiques/<kind>/` by `tools/extract_marks.py` (Pillow, numpy, scipy). Each mark is processed by how it is made:
  - *piece* (a separate object: the paper LINDQVIST label, the Pinecrest brass plaques and sticker, the 49¢ sticker): cut out, drop shadow removed;
  - *ring* (the three Tessar lens rings): cut out with the centre cleared so the lens glass shows;
  - *letters* (struck, engraved, embossed or carved into the object: the music box, watch, bear, compass and lantern marks): only the cut
    lettering is kept, measured against the plate face around it, with grain, scratches, rivets and plate rims removed, so the letters sit
    in the object's own metal or wood instead of on a plate;
  - *ink* (the three Red Wing stamps): only the cobalt ink, the paper dropped.
  Widths 128 px (rings, small stamps, stickers) or 256 px (two-line marks), nearest-neighbour filtered like the Meshy textures.
  `docs/concepts/marks/extracted_marks.png` shows them all.
- **On the models.** `scripts/marks.gd` lays each texture as a small grid mesh whose vertices are projected onto the Meshy model's own
  triangles along the clue's side: the mark follows a lantern tank, a jug's belly or a watch back, sits 0.7 mm above it (no z-fighting, no
  gap), turns with the object, is lit like it, and fades out where it would run off an edge (never floats). No Decal nodes, no Label3D.
- **Removed:** all the old floating Label3D marks, the ink styles, the drawn serial numbers and price sticker, and the generic "crack" boxes.
- **The jug** had a blue crown baked into its Meshy texture, so every version showed it (RED WINGS showed two stamps). The crown was
  painted out of `assets/items/jug_0.png` by `tools/clean_jug_texture.py` (original kept at `docs/concepts/marks/jug_0.orig.png`).
- **Physical damage details** (section 7), each now its own small mesh where its clue is: a comb with two teeth missing, a hairline crack in
  the watch crystal, a glue line on the bear's ear, a dent in the compass rim, a chip in the lantern glass, pinholes of light in the bellows,
  an air gap under the snow globe's dome, a chip of raw clay on the jug's lip. The copies' tells from phase 1 stay as they were (cross-head
  screws, tin movement, lifting paper dial, machine-even cuts, mould seam, painted patina, liquid bubble, spot welds, scratched plastic
  globe, glitter, tea stain, modern glaze).
- **A bug found on the way:** the watch's winding-crown clue had the id `crown`, the same as the jug's crown stamp in `MARK_IDS`, so on
  watch copies the winding crown was treated as a second maker's mark and carried the fake hallmark. Renamed to `winder`;
  `tests/clue_reach.gd` now fails if any kind has more than one mark id.

## Variant-to-texture mapping

| Kind | Real (version 0) | Copy 1 | Copy 2 | Copy 3 | Copy 4 |
|---|---|---|---|---|---|
| Music box | `lindqvist_struck` | `lindqvist_printed` (paper label) | `lindquist_struck` | real mark + tin movement | real mark + cross-head screws |
| Pocket watch | `925_1911` | `925_qqq` (plated case) | `952_1911` | real mark + lifting paper dial | real mark + `serials` |
| Carved bear | `eh` | real mark + machine-even cuts | `eh_1952` | `ek` | real mark + resin seam |
| Compass | `hall_sons` | real mark + painted patina | `hall_son` | real mark + liquid bubble | `made_in_china` |
| Oil lantern | `dietz_blizzard` | real mark + spot welds | `deitz_blizzard` | real mark + plastic globe | `dietz_repro` |
| Camera | `tessar_145` ring | `tessar_q` ring | `tesar_145` ring | real ring + vinyl bellows seam | real ring + plastic tripod socket |
| Snow globe | `pinecrest_1952` plaque | `pinecrest_sticker` (paper) | `pinecrest_1925` plaque | real plaque + metal glitter | real plaque + `price_49c` |
| Jug | `crown` | real stamp + tea-stained foot | `red_wings` | real stamp + modern glaze | `crown_r` |

Copies that share the real maker's mark keep the real texture; their status shows only in their other physical clue.

## Gameplay text that changed to match the supplied art (no values, probabilities or authenticity logic changed)

The atlases were drawn from the earlier mark list, before phase 1's 1956 provenance pass. Where they differ:

- **Bear, wrong date.** The atlas tile says "E.H. 2019", impossible in 1956. Phase 1 had already made this clue "E.H. 1952" (Eli Harlan died
  1949), so the game keeps 1952: the texture is the atlas's carved "E.H." with "1952" carved beside it by the script (the 2019 tile has no
  5 to reuse). The real bear and the E.K. copy now read "E.H." and "E.K." with no date, as in the art (phase 1 had added "1931").
- **Compass copy 4** reads "Made in China" as in the art (phase 1 had "Made in Occupied Japan"). Still a tell: Hall & Sons was London.
- **Watch copy 1** reads "925 ???" as in the art (phase 1 had "STERLING 925", printed).
- **Camera copy 1** reads "TESSAR?" as in the art (phase 1 had the full ring in white paint).
- **Music box copy 1** is the printed paper LINDQVIST label (phase 1 had the full mark in printed ink).
- **Snow globe copy 1**: "Not a brass plate at all: a thin printed paper sticker."
- **Jug real piece**: the crown stamp alone (phase 1 had "RED WING / UNION STONEWARE" text).
The loupe texts were updated to say what the new artwork shows. The 7-day simulation gives identical results before and after.

## Quality checks run

- `tests/clue_reach.gd`: all 111 clues on the 40 versions on the surface and reachable, none too close to another, one mark id per kind:
  0 failures.
- `tests/smoke.gd`: 0 failures. `tests/sim_week.gd` (3 seeds x 2 bots): 0 failures, identical outcomes to before the upgrade.
- Comparison sheets, one per kind: `docs/concepts/marks/compare_<kind>.png` (whole object; mark from the game's closest inspection
  distance and field of view; tell, or damage on the real piece). Rendered by `tests/variant_sheets.gd`, laid out by `tools/compose_sheets.py`.
- Web build: 60 fps in headless Chrome, 0 GL errors or warnings. Building one object (with its marks projected) takes about 120 ms on
  average and 264 ms at worst on desktop; that happens once, when a customer puts an object on the mat.

## Remaining artwork worth having

1. A carved **"E.H. 1952"** tile in the atlas style (the "1952" is drawn by the script; it matches well but is not hand-made art).
2. Stamped **watch serial numbers** ("31840 · 77215") in the atlas style (also drawn by the script).
3. Optional small textures for tells that are still simple meshes: cross-head screw heads, a stamped tin comb plate, a paper dial edge,
   spot welds, a moulded vinyl seam.
4. Known small leftovers: a couple of 2-3 px specks on the REPRO lantern plate, and a pale vertical line left in the jug texture (it looks
   like the edge of the cream band, not ink, so it was kept).
