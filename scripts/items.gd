extends RefCounted
class_name Items
## The objects people bring in. Each kind has a base value, a few clues hidden on it (a maker's mark, damage, the tells of a fake), and a stand-in shape
## built from simple parts until its Meshy model is in (assets/items/<id>.glb is used when it exists).
## A clue: where it sits on the object (model space, the object is about 0.3 m across), how close the loupe must be, what you learn, and what it does to
## the value: "mult" multiplies it; "fake" means the piece is a reproduction (worth `fake_value`).

const KINDS := {
	"music_box": {
		"name": "Music box", "cat": "curios", "base": 180, "fake_value": 15,
		"clues": [
			{"id": "mark", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.075, 0), "text": "Struck into the wood underneath: \"J. Lindqvist, Oslo 1904\". A known maker.", "mult": 1.6, "label": "J.LINDQVIST\nOSLO 1904", "ink": "struck", "tex": "music_box/lindqvist_struck", "w": 0.085, "face": "bottom"},
			{"id": "comb", "from": "top", "at": Vector2(-0.15, 0.35), "pos": Vector3(-0.021, 0.0, 0.048), "text": "The steel comb is missing two teeth: it plays, but not every note.", "mult": 0.7, "damage": true, "heard": true, "tex": "music_box/comb_gap", "w": 0.022},
			{"id": "inlay", "from": "front", "at": Vector2(0.0, -0.35), "pos": Vector3(0.0, 0.08, 0.06), "text": "The flower inlay is real pearwood, cut by hand.", "mult": 1.15},
		],
	},
	"pocket_watch": {
		"name": "Pocket watch", "cat": "watches", "base": 240, "fake_value": 20,
		"clues": [
			{"id": "hallmark", "from": "back", "at": Vector2(0.1, -0.1), "pos": Vector3(0, 0, -0.012), "text": "Hallmarks on the back of the case: sterling silver, 1911.", "mult": 1.5, "label": "925 · 1911", "ink": "struck", "tex": "pocket_watch/925_1911", "w": 0.05, "face": "back"},
			{"id": "crystal", "from": "front", "at": Vector2(-0.05, -0.1), "pos": Vector3(0.0, 0.0, 0.016), "text": "A hairline crack across the crystal.", "mult": 0.8, "damage": true, "part": "crack"},
			{"id": "winder", "from": "front", "at": Vector2(0.0, 0.62), "pos": Vector3(0, 0.055, 0), "text": "The winding crown turns smoothly: the movement runs.", "mult": 1.2},
		],
	},
	"carved_bear": {
		"name": "Carved bear", "cat": "folk art", "base": 120, "fake_value": 10,
		"clues": [
			{"id": "signature", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.06, 0), "text": "Carved under the base: \"E.H.\" Eli Harlan, the trapper-carver up the mountain (1874-1949).", "mult": 2.2, "label": "E.H.", "ink": "carved", "tex": "carved_bear/eh", "w": 0.06, "face": "bottom"},
			{"id": "ear", "from": "top", "at": Vector2(0.35, 0.45), "pos": Vector3(0.05, 0.07, 0.03), "text": "One ear was snapped off and glued back.", "mult": 0.75, "damage": true, "part": "glue"},
		],
	},
	"compass": {
		"name": "Brass compass", "cat": "instruments", "base": 150, "fake_value": 12,
		"clues": [
			{"id": "maker", "from": "bottom", "at": Vector2(0, 0.1), "pos": Vector3(0, -0.012, 0), "text": "Engraved underneath: \"Hall & Sons, Survey No. 2\".", "mult": 1.5, "label": "HALL & SONS\nSURVEY No.2", "ink": "engraved", "tex": "compass/hall_sons", "w": 0.07, "face": "bottom"},
			{"id": "needle", "from": "top", "at": Vector2(0.0, 0.15), "pos": Vector3(0, 0.012, 0), "text": "The needle still swings true to north.", "mult": 1.1},
			{"id": "dent", "from": "right", "at": Vector2(0.0, -0.55), "pos": Vector3(0.045, 0.0, 0.0), "text": "A dent in the rim from a fall.", "mult": 0.85, "damage": true, "part": "dent"},
		],
	},
	"lantern": {
		"name": "Oil lantern", "cat": "household", "base": 70, "fake_value": 8,
		"clues": [
			{"id": "stamp", "from": "back", "at": Vector2(0.0, -0.71), "pos": Vector3(0, -0.1, 0.0), "text": "Embossed on the tank: \"Dietz No. 2 Blizzard\". Collectors want these.", "mult": 1.8, "label": "DIETZ No.2\nBLIZZARD", "ink": "embossed", "tex": "lantern/dietz_blizzard", "w": 0.066, "face": "bottom"},
			{"id": "glass", "from": "front", "at": Vector2(0.2, 0.0), "pos": Vector3(0.04, 0.0, 0.0), "text": "The glass globe has a chip near the top.", "mult": 0.8, "damage": true, "part": "chip_glass"},
		],
	},
	"camera": {
		"name": "Folding camera", "cat": "instruments", "base": 160, "fake_value": 15,
		"clues": [
			{"id": "lens", "from": "front", "at": Vector2(0.075, -0.32), "pos": Vector3(0, 0.0, 0.09), "text": "The lens ring reads \"Tessar 1:4.5\": a good lens.", "mult": 1.4, "label": "TESSAR 1:4.5", "ink": "engraved", "tex": "camera/tessar_145", "w": 0.095, "face": "front"},
			{"id": "bellows", "from": "right", "at": Vector2(0.4, 0.05), "pos": Vector3(0.04, 0.0, 0.04), "text": "Pinholes in the bellows: light leaks.", "mult": 0.7, "damage": true, "part": "pinholes"},
		],
	},
	"snow_globe": {
		"name": "Snow globe", "cat": "curios", "base": 60, "fake_value": 5,
		"clues": [
			{"id": "plate", "from": "front", "at": Vector2(0.0, -0.615), "pos": Vector3(0, -0.035, 0.05), "text": "The brass plate reads \"Pinecrest 1952\": made here in town, at the Pinecrest works.", "mult": 1.7, "label": "PINECREST\n1952", "ink": "struck", "tex": "snow_globe/pinecrest_1952", "w": 0.06, "face": "front"},
			{"id": "water", "from": "top", "at": Vector2(0.0, 0.0), "pos": Vector3(0.0, 0.07, 0.0), "text": "An air gap at the top of the dome: some water has leaked out.", "mult": 0.85, "damage": true, "part": "airgap"},
		],
	},
	"toy_car": {
		"name": "Tin toy car", "cat": "toys", "base": 95, "fake_value": 8,
		"clues": [
			{"id": "mark", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.04, 0), "text": "Printed on the tin underneath: \"Brandt, Nürnberg\". The Nuremberg toy works made the best tin toys in the world before the war.", "mult": 1.6, "label": "BRANDT
NÜRNBERG", "ink": "printed", "tex": "toy_car/brandt", "w": 0.08, "face": "bottom"},
			{"id": "spring", "from": "bottom", "at": Vector2(0.45, 0.4), "pos": Vector3(0, 9, 0), "text": "Wound up, the key just turns and turns: the mainspring is broken. It won't run.", "mult": 0.55, "damage": true, "heard": true, "ear_only": true},
			{"id": "litho", "from": "left", "at": Vector2(0.1, 0.1), "pos": Vector3(0.0, 0.02, 0.03), "text": "The paint is printed on the tin before it was folded: the pattern runs unbroken into the seams. Proper German tinwork.", "mult": 1.25},
		],
	},
	"candlestick_phone": {
		"name": "Candlestick telephone", "cat": "household", "base": 140, "fake_value": 12,
		"clues": [
			{"id": "plate", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.1, 0), "text": "A nickel plate under the base: \"Northern Bell, No. 20\". The telephone company's own desk set, from before the dial.", "mult": 1.6, "label": "NORTHERN BELL\nNo. 20", "ink": "struck", "tex": "candlestick_phone/northern_bell", "w": 0.08, "face": "bottom"},
			{"id": "earpiece", "from": "left", "at": Vector2(0.0, 0.1), "pos": Vector3(-0.05, 0.0, 0.0), "text": "The earpiece is hard black rubber, gone brown at the edges with age: the original.", "mult": 1.15},
			{"id": "dent", "from": "front", "at": Vector2(0.05, 0.62), "pos": Vector3(0.0, 0.08, 0.03), "text": "A dent in the mouthpiece's rim: it has been knocked off a desk.", "mult": 0.8, "damage": true, "part": "dent"},
		],
	},
	"dog_bank": {
		"name": "Cast-iron dog bank", "cat": "toys", "base": 125, "fake_value": 10,
		"clues": [
			{"id": "mark", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.1, 0), "text": "Cast into the base: \"Halvorsen Iron, Pat. 1888\". One of the old foundry banks.", "mult": 1.7, "label": "HALVORSEN IRON\nPAT. 1888", "ink": "embossed", "tex": "dog_bank/halvorsen", "w": 0.09, "face": "bottom"},
			{"id": "slot", "from": "top", "at": Vector2(0.15, 0.1), "pos": Vector3(0.0, 0.08, 0.0), "text": "The coin slot is worn bright and smooth: years of pennies went in here.", "mult": 1.15},
			{"id": "dent", "from": "front", "at": Vector2(0.35, -0.72), "pos": Vector3(0.03, -0.08, 0.04), "text": "The base has been dropped: a dent along its edge.", "mult": 0.8, "damage": true, "part": "dent"},
		],
	},
	"duck_decoy": {
		"name": "Duck decoy", "cat": "folk art", "base": 110, "fake_value": 9,
		"clues": [
			{"id": "signature", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.06, 0), "text": "Branded into the wood underneath: \"W. Pike, 1921\". Walt Pike carved for the duck hunters on the lake below town.", "mult": 1.9, "label": "W. PIKE\n1921", "ink": "carved", "tex": "duck_decoy/w_pike", "w": 0.08, "face": "bottom"},
			{"id": "eyes", "from": "left", "at": Vector2(-0.5, 0.35), "pos": Vector3(-0.08, 0.04, 0.0), "text": "Glass eyes, set in by hand, and real wear on the paint where it rode in a hunter's sack.", "mult": 1.15},
			{"id": "neck", "from": "top", "at": Vector2(-0.45, 0.0), "pos": Vector3(-0.06, 0.06, 0.0), "text": "The head was snapped off at the neck and glued back on.", "mult": 0.75, "damage": true, "part": "glue"},
		],
	},
	"jug": {
		"name": "Stoneware jug", "cat": "household", "base": 55, "fake_value": 6,
		"clues": [
			{"id": "crown", "from": "front", "at": Vector2(-0.1, -0.12), "pos": Vector3(0.0, 0.0, 0.075), "text": "A blue crown stamp: the mark of Red Wing Union Stoneware, Minnesota, 1906 to 1936.", "mult": 1.9, "label": "♛", "ink": "blue", "tex": "jug/crown", "w": 0.045, "face": "front"},
			{"id": "chip", "from": "front", "at": Vector2(0.15, 0.85), "pos": Vector3(0.0, 0.13, 0.02), "text": "A chip on the lip of the neck.", "mult": 0.85, "damage": true, "part": "chip_ceramic"},
		],
	},
}

## Every kind comes in five versions: number 0 is the real piece, 1 to 4 are copies. Each copy is physically different on the model:
## its finish (a tint, and gloss for plastic and resin), and its tell, which is either its mark (printed instead of struck, a wrong
## name or date, a give-away line) or a part added to it where you can find it with the loupe (cross-head screws, a mould seam, spot welds,
## machine-even cuts, a paper sticker, painted patina, a liquid bubble, glitter, a tea stain, a tin plate, bright modern glaze).
## The real piece in the glass case is the one to compare with. Every version, real or copy, also carries harmless wear (Models), so
## scratches alone prove nothing. The town's year is 1956: no tell may need anything newer.
## A copy: {"label": a new mark text or "" to keep the real one, "ink": how the mark is made, "mark_text": what the loupe says when the
## mark itself gives it away ("" when it does not), "tell": a fake clue elsewhere {from, at, text, part, part_text} or {}, "tint", "gloss"}.
const MARK_IDS := ["mark", "hallmark", "signature", "maker", "stamp", "lens", "plate", "crown"]
const COPIES := {
	"candlestick_phone": [
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.5, -0.4), "part": "screws", "text": "Cross-head screws hold the base plate on. The telephone works used slotted screws; these are new."}, "tint": Color(1.0, 0.95, 0.95), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.0, 0.0), "part": "seam_short", "text": "A moulding seam runs up the stand: it's cast plastic painted black, not lacquered brass."}, "tint": Color(0.9, 0.9, 0.95), "gloss": 0.3},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "front", "at": Vector2(0.0, -0.5), "part": "brassy", "text": "The brass showing through the black is painted on: flat even blotches, not worn edges."}, "tint": Color(1.05, 1.0, 0.92), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, -0.2), "part": "welds", "text": "Spot welds where the stand meets the base: a telephone works would have screwed it together."}, "tint": Color(0.92, 0.92, 0.98), "gloss": -1.0},
	],
	"dog_bank": [
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.0, 0.1), "part": "seam_short", "text": "A fine moulding seam down the dog's side: it's resin, not iron. Far too light in the hand, too."}, "tint": Color(1.05, 1.0, 0.95), "gloss": 0.25},
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "front", "at": Vector2(-0.2, -0.1), "part": "rust", "text": "The rust and wear are painted on in flat blotches: nothing has worn through to the iron."}, "tint": Color(1.08, 1.02, 0.95), "gloss": -1.0},
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.5, 0.4), "part": "screws", "text": "A cross-head screw holds the two halves together. The old foundries used a single slotted bolt."}, "tint": Color(0.95, 0.95, 1.0), "gloss": -1.0},
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, -0.4), "part": "glaze", "text": "The red of the base is bright, glossy and even: new paint over a cheap casting."}, "tint": Color(1.12, 1.0, 0.98), "gloss": 0.15},
	],
	"duck_decoy": [
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.2, 0.1), "part": "grooves", "text": "The feather cuts on the back are all exactly alike: cut by a machine, not a carver's knife."}, "tint": Color(1.0, 1.0, 0.95), "gloss": -1.0},
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "front", "at": Vector2(0.2, -0.2), "part": "chips", "text": "The chipped paint is painted on: the 'chips' are flat blotches, with no bare wood under them."}, "tint": Color(1.06, 1.0, 0.92), "gloss": -1.0},
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.5, 0.4), "part": "stain", "text": "The bottom is stained with tea to look old, but the wood under the stain is fresh and pale."}, "tint": Color(1.1, 1.05, 0.95), "gloss": -1.0},
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "left", "at": Vector2(0.3, -0.3), "part": "seam_short", "text": "A moulding seam along the body: it's cast resin, not carved cedar. It wouldn't float."}, "tint": Color(0.95, 0.95, 0.9), "gloss": 0.3},
	],
	"toy_car": [
		{"label": "", "ink": "printed", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.45, -0.35), "part": "screws", "text": "Cross-head screws hold the base on. The old German toy works folded tin tabs to close a car; never screws."}, "tint": Color(1.08, 0.98, 0.95), "gloss": -1.0},
		{"label": "", "ink": "printed", "mark_text": "", "tell": {"from": "left", "at": Vector2(0.0, -0.2), "part": "welds", "text": "A row of spot welds along the body: tin toys were folded and tabbed, not welded. A cheap new copy."}, "tint": Color(0.95, 0.95, 1.0), "gloss": -1.0},
		{"label": "", "ink": "printed", "mark_text": "", "tell": {"from": "top", "at": Vector2(0.1, 0.0), "part": "rust", "text": "The wear is painted on: even flat blotches of rust colour, not real rubbed-through tin."}, "tint": Color(1.05, 1.0, 0.92), "gloss": -1.0},
		{"label": "", "ink": "printed", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.0, 0.1), "part": "seam_short", "text": "A moulding seam runs down the body: it isn't tin at all, it's painted plastic."}, "tint": Color(1.1, 0.9, 0.9), "gloss": 0.3},
	],
	"music_box": [
		{"label": "LINDQVIST", "ink": "printed", "tex": "music_box/lindqvist_printed", "mark_text": "A printed paper label glued underneath, not a stamp struck into the wood: a modern copy.", "tell": {}, "tint": Color(1.1, 1.02, 0.9), "gloss": -1.0},
		{"label": "J.LINDQUIST\nOSLO 1904", "ink": "struck", "tex": "music_box/lindquist_struck", "mark_text": "It says \"Lindquist\". The maker spelled it Lindqvist, always.", "tell": {}, "tint": Color(0.92, 0.9, 1.05), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "top", "at": Vector2(-0.45, -0.3), "part": "tin", "heard": true, "text": "Under the lid: a stamped tin movement, not a steel comb. A cheap new box."}, "tint": Color(1.16, 1.08, 0.95), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, 0.0), "part": "screws", "text": "Cross-head screws hold the back on. Lindqvist used slotted screws; these went in long after 1904."}, "tint": Color(0.8, 0.74, 0.72), "gloss": -1.0},
	],
	"pocket_watch": [
		{"label": "925 ???", "ink": "struck", "tex": "pocket_watch/925_qqq", "mark_text": "The hallmark stops at 925: no date, no assay mark, only a blur. And the case is light: gold-plated brass.", "tell": {}, "tint": Color(1.15, 1.05, 0.78), "gloss": 0.25},
		{"label": "952 · 1911", "ink": "struck", "tex": "pocket_watch/952_1911", "mark_text": "The hallmark reads 952, not 925: struck by someone who didn't know silver.", "tell": {}, "tint": Color(0.95, 0.95, 1.0), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "front", "at": Vector2(0.18, 0.25), "part": "glue", "text": "The dial is printed paper glued behind the glass, not enamel: its edge is lifting."}, "tint": Color(1.05, 1.0, 0.92), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "back", "at": Vector2(-0.35, 0.3), "part": "numbers", "part_text": "31840\n77215", "tex": "pocket_watch/serials", "w": 0.05, "text": "Two serial numbers that don't match: a 1911 case with a cheap pin-lever movement put in it. A marriage."}, "tint": Color(0.86, 0.86, 0.9), "gloss": -1.0},
	],
	"carved_bear": [
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.0, 0.1), "part": "grooves", "text": "The knife cuts are all the same depth and spacing: machine-carved, then roughened by hand."}, "tint": Color(1.14, 1.05, 0.9), "gloss": -1.0},
		{"label": "E.H. 1952", "ink": "carved", "tex": "carved_bear/eh_1952", "mark_text": "Signed \"E.H. 1952\". Eli Harlan died in 1949.", "tell": {}, "tint": Color(0.9, 0.85, 0.8), "gloss": -1.0},
		{"label": "E.K.", "ink": "carved", "tex": "carved_bear/ek", "mark_text": "The initials are \"E.K.\", not Eli Harlan's \"E.H.\".", "tell": {}, "tint": Color(1.0, 0.92, 0.82), "gloss": -1.0},
		{"label": "", "ink": "carved", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, 0.2), "part": "seam_short", "text": "It's resin, not wood: cold, too light, with a mould seam down its back."}, "tint": Color(0.8, 0.7, 0.62), "gloss": 0.2},
	],
	"compass": [
		{"label": "", "ink": "engraved", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.45, -0.4), "part": "paint", "text": "The green patina rubs off on your finger: painted on to look old."}, "tint": Color(0.9, 1.05, 0.9), "gloss": -1.0},
		{"label": "HALL & SON\nSURVEY No.2", "ink": "engraved", "tex": "compass/hall_son", "mark_text": "\"Hall & Son\": the London firm was Hall & Sons, always plural.", "tell": {}, "tint": Color(1.12, 1.08, 0.85), "gloss": -1.0},
		{"label": "", "ink": "engraved", "mark_text": "", "tell": {"from": "top", "at": Vector2(0.25, -0.25), "part": "bubble", "text": "The needle floats in liquid with a bubble in it: a modern hiking compass set in an old case."}, "tint": Color(1.0, 0.92, 0.85), "gloss": -1.0},
		{"label": "HALL & SONS\nMADE IN CHINA", "ink": "engraved", "tex": "compass/made_in_china", "mark_text": "Under the maker's name: \"Made in China\". Hall & Sons was a London firm: an export copy.", "tell": {}, "tint": Color(0.86, 0.86, 0.8), "gloss": -1.0},
	],
	"lantern": [
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "right", "at": Vector2(0.0, -0.6), "part": "welds", "text": "A row of spot welds where Dietz used rivets: a reproduction."}, "tint": Color(1.1, 0.85, 0.85), "gloss": -1.0},
		{"label": "DEITZ No.2\nBLIZZARD", "ink": "embossed", "tex": "lantern/deitz_blizzard", "mark_text": "\"Deitz\", not Dietz: a knock-off.", "tell": {}, "tint": Color(0.85, 0.9, 1.05), "gloss": -1.0},
		{"label": "", "ink": "embossed", "mark_text": "", "tell": {"from": "front", "at": Vector2(-0.3, 0.3), "part": "scratches", "text": "The globe is plastic, not glass: it gives when you press it, and it's scratched all over."}, "tint": Color(1.14, 1.1, 1.0), "gloss": 0.15},
		{"label": "DIETZ No.2\nREPRO", "ink": "embossed", "tex": "lantern/dietz_repro", "mark_text": "Small letters under the name: \"REPRO\". An honest reproduction, sold as old.", "tell": {}, "tint": Color(0.8, 0.8, 0.8), "gloss": -1.0},
	],
	"camera": [
		{"label": "TESSAR?", "ink": "engraved", "tex": "camera/tessar_q", "mark_text": "The ring says \"TESSAR\" and then nothing: no aperture, no serial. Zeiss engraved both. The lens is plastic.", "tell": {}, "tint": Color(1.1, 1.05, 1.0), "gloss": 0.3},
		{"label": "TESAR 1:4.5", "ink": "engraved", "tex": "camera/tesar_145", "mark_text": "\"Tesar\" with one S: a fake lens ring.", "tell": {}, "tint": Color(0.9, 0.9, 1.0), "gloss": -1.0},
		{"label": "", "ink": "engraved", "mark_text": "", "tell": {"from": "right", "at": Vector2(-0.4, 0.35), "part": "seam_short", "text": "The bellows are vinyl, not leather: no cracks at the folds, and a moulded seam along them."}, "tint": Color(1.0, 0.9, 0.85), "gloss": 0.25},
		{"label": "", "ink": "engraved", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.0, 0.0), "part": "screws", "text": "A plastic tripod socket held in with cross-head screws: put together recently."}, "tint": Color(0.8, 0.82, 0.88), "gloss": -1.0},
	],
	"snow_globe": [
		{"label": "PINECREST", "ink": "printed", "tex": "snow_globe/pinecrest_sticker", "mark_text": "Not a brass plate at all: a thin printed paper sticker.", "tell": {}, "tint": Color(1.1, 1.05, 0.95), "gloss": -1.0},
		{"label": "PINECREST\n1925", "ink": "struck", "tex": "snow_globe/pinecrest_1925", "mark_text": "The plate says 1925. Pinecrest wasn't founded until 1938.", "tell": {}, "tint": Color(0.9, 0.95, 1.1), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "front", "at": Vector2(0.35, 0.35), "part": "glitter", "text": "The snow is metal glitter. Pinecrest globes used bone-white flakes."}, "tint": Color(1.1, 1.0, 1.1), "gloss": -1.0},
		{"label": "", "ink": "struck", "mark_text": "", "tell": {"from": "bottom", "at": Vector2(0.0, 0.0), "part": "sticker", "part_text": "49¢", "tex": "snow_globe/price_49c", "w": 0.035, "text": "A Woolworth's price sticker under the base, 49¢: a dime-store souvenir, not Pinecrest work."}, "tint": Color(0.85, 0.8, 0.78), "gloss": -1.0},
	],
	"jug": [
		{"label": "", "ink": "blue", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, -0.8), "part": "stain", "text": "The unglazed foot is too clean under a brown tea stain: a new jug made to look old."}, "tint": Color(1.05, 0.95, 0.85), "gloss": -1.0},
		{"label": "RED WINGS", "ink": "blue", "tex": "jug/red_wings", "w": 0.06, "mark_text": "The stamp says \"Red Wings\": the pottery was Red Wing.", "tell": {}, "tint": Color(0.95, 0.98, 1.08), "gloss": -1.0},
		{"label": "", "ink": "blue", "mark_text": "", "tell": {"from": "back", "at": Vector2(0.0, 0.4), "part": "glaze", "text": "The glaze on the shoulder is bright white and perfectly even: modern glaze."}, "tint": Color(1.12, 1.1, 1.05), "gloss": 0.15},
		{"label": "♛ ®", "ink": "blue", "tex": "jug/crown_r", "mark_text": "A ® beside the crown. Red Wing Union never marked it so; the sign wasn't used until 1946, after they stopped.", "tell": {}, "tint": Color(0.85, 0.82, 0.78), "gloss": -1.0},
	],
}

## One object as it comes through the door: a kind, which version (0 real, 1-4 copies), which of its clues apply, and so what it is really worth.
static func make(kind: String, rng: RandomNumberGenerator, fake_chance: float = 0.2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var fake := rng.randf() < fake_chance
	var variant := 0 if not fake else 1 + rng.randi() % 4
	var copy: Dictionary = COPIES[kind][variant - 1] if fake else {}
	var clues: Array = []
	for c0: Dictionary in k["clues"]:
		var c := c0.duplicate()
		if c.has("damage") and rng.randf() < 0.45:
			continue                                     ## not every piece is damaged
		if fake and c["id"] in MARK_IDS:
			if String(copy["label"]) != "":
				c["label"] = copy["label"]
			c["ink"] = copy["ink"]
			if copy.has("tex"):                          ## its own mark artwork; copies that share the real mark keep the real texture
				c["tex"] = copy["tex"]
			if copy.has("w"):
				c["w"] = copy["w"]
			if String(copy["mark_text"]) != "":           ## the mark itself gives it away
				c["text"] = copy["mark_text"]
				c["fake"] = true
				c.erase("mult")
		clues.append(c)
	if fake and not (copy["tell"] as Dictionary).is_empty():
		var t: Dictionary = (copy["tell"] as Dictionary).duplicate()
		t["id"] = "tell"
		t["pos"] = Vector3.ZERO
		t["fake"] = true
		clues.append(t)
	var value := float(k["base"])
	for c2: Dictionary in clues:
		value *= float(c2.get("mult", 1.0))
	if fake:
		value = float(k["fake_value"])
	return {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": fake, "value": roundi(value), "found": [], "base": k["base"],
		"variant": variant, "tint": Color.WHITE if not fake else copy["tint"], "gloss": -1.0 if not fake else float(copy["gloss"]),
		"wear_seed": rng.randi()}

## The estimate the player can make from what they have found so far. It narrows with each clue found, by the same amount whatever the
## object, so it never gives away how many details are still hidden on it (or that there are none left).
static func estimate(item: Dictionary) -> Vector2:
	var k: Dictionary = KINDS[item["kind"]]
	var known := float(k["base"])
	var fake_found := false
	var n_found := 0
	for c: Dictionary in item["clues"]:
		if c["id"] in item["found"]:
			n_found += 1
			if c.get("fake", false):
				fake_found = true
			known *= float(c.get("mult", 1.0))
	if fake_found:
		return Vector2(float(k["fake_value"]) * 0.7, float(k["fake_value"]) * 1.3)
	var spread := maxf(0.75 * pow(0.62, float(n_found)), 0.18)
	return Vector2(known * (1.0 - spread), known * (1.0 + spread * 1.6))

## True if the player has found the tell that gives away a copy (so offering it as genuine is knowing).
static func known_fake(it: Dictionary) -> bool:
	if not it.get("fake", false):
		return false
	for c: Dictionary in it["clues"]:
		if c.get("fake", false) and c["id"] in it["found"]:
			return true
	return false
