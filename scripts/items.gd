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
			{"id": "mark", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.075, 0), "text": "Stamped underneath: \"J. Lindqvist, Oslo 1904\". A known maker.", "mult": 1.6, "label": "J.LINDQVIST\nOSLO 1904", "face": "bottom"},
			{"id": "comb", "from": "top", "at": Vector2(0.0, 0.15), "pos": Vector3(0.05, 0.06, 0.0), "text": "The steel comb is missing two teeth: it plays, but not every note.", "mult": 0.7, "damage": true},
			{"id": "inlay", "from": "front", "at": Vector2(0.0, -0.35), "pos": Vector3(0.0, 0.08, 0.06), "text": "The flower inlay is real pearwood, cut by hand.", "mult": 1.15},
		],
	},
	"pocket_watch": {
		"name": "Pocket watch", "cat": "watches", "base": 240, "fake_value": 20,
		"clues": [
			{"id": "hallmark", "from": "back", "at": Vector2(0.1, -0.1), "pos": Vector3(0, 0, -0.012), "text": "Hallmarks on the back of the case: sterling silver, 1911.", "mult": 1.5, "label": "925 · 1911", "face": "back"},
			{"id": "crystal", "from": "front", "at": Vector2(-0.05, -0.1), "pos": Vector3(0.0, 0.0, 0.016), "text": "A hairline crack across the crystal.", "mult": 0.8, "damage": true},
			{"id": "crown", "from": "top", "at": Vector2(-0.05, 0.0), "pos": Vector3(0, 0.055, 0), "text": "The winding crown turns smoothly: the movement runs.", "mult": 1.2},
		],
	},
	"carved_bear": {
		"name": "Carved bear", "cat": "folk art", "base": 120, "fake_value": 10,
		"clues": [
			{"id": "signature", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.06, 0), "text": "Carved under the base: \"E.H.\" Eli Harlan, the old trapper-carver.", "mult": 2.2, "label": "E.H.", "face": "bottom"},
			{"id": "ear", "from": "top", "at": Vector2(0.35, 0.45), "pos": Vector3(0.05, 0.07, 0.03), "text": "One ear was snapped off and glued back.", "mult": 0.75, "damage": true},
		],
	},
	"compass": {
		"name": "Brass compass", "cat": "instruments", "base": 150, "fake_value": 12,
		"clues": [
			{"id": "maker", "from": "bottom", "at": Vector2(0, 0.1), "pos": Vector3(0, -0.012, 0), "text": "Engraved underneath: \"Hall & Sons, Survey No. 2\".", "mult": 1.5, "label": "HALL & SONS\nSURVEY No.2", "face": "bottom"},
			{"id": "needle", "from": "top", "at": Vector2(0.0, 0.15), "pos": Vector3(0, 0.012, 0), "text": "The needle still swings true to north.", "mult": 1.1},
			{"id": "dent", "from": "right", "at": Vector2(0.0, -0.55), "pos": Vector3(0.045, 0.0, 0.0), "text": "A dent in the rim from a fall.", "mult": 0.85, "damage": true},
		],
	},
	"lantern": {
		"name": "Oil lantern", "cat": "household", "base": 70, "fake_value": 8,
		"clues": [
			{"id": "stamp", "from": "front", "at": Vector2(0.0, -0.8), "pos": Vector3(0, -0.1, 0.0), "text": "Embossed on the tank: \"Dietz No. 2 Blizzard\". Collectors want these.", "mult": 1.8, "label": "DIETZ No.2\nBLIZZARD", "face": "bottom"},
			{"id": "glass", "from": "front", "at": Vector2(0.2, 0.0), "pos": Vector3(0.04, 0.0, 0.0), "text": "The glass globe has a chip near the top.", "mult": 0.8, "damage": true},
		],
	},
	"camera": {
		"name": "Folding camera", "cat": "instruments", "base": 160, "fake_value": 15,
		"clues": [
			{"id": "lens", "from": "front", "at": Vector2(0.0, 0.1), "pos": Vector3(0, 0.0, 0.09), "text": "The lens ring reads \"Tessar 1:4.5\": a good lens.", "mult": 1.4, "label": "TESSAR 1:4.5", "face": "front"},
			{"id": "bellows", "from": "right", "at": Vector2(0.4, 0.05), "pos": Vector3(0.04, 0.0, 0.04), "text": "Pinholes in the bellows: light leaks.", "mult": 0.7, "damage": true},
		],
	},
	"snow_globe": {
		"name": "Snow globe", "cat": "curios", "base": 60, "fake_value": 5,
		"clues": [
			{"id": "plate", "from": "front", "at": Vector2(0.0, -0.58), "pos": Vector3(0, -0.035, 0.05), "text": "The brass plate reads \"Pinecrest 1952\": made here in town.", "mult": 1.7, "label": "PINECREST\n1952", "face": "front"},
			{"id": "water", "from": "top", "at": Vector2(0.0, 0.0), "pos": Vector3(0.0, 0.07, 0.0), "text": "An air bubble at the top: some water has leaked out.", "mult": 0.85, "damage": true},
		],
	},
	"jug": {
		"name": "Stoneware jug", "cat": "household", "base": 55, "fake_value": 6,
		"clues": [
			{"id": "crown", "from": "front", "at": Vector2(-0.1, -0.12), "pos": Vector3(0.0, 0.0, 0.075), "text": "A blue crown stamp: the Red Wing pottery, early 1900s.", "mult": 1.9, "label": "♛", "face": "front"},
			{"id": "chip", "from": "top", "at": Vector2(0.22, 0.0), "pos": Vector3(0.0, 0.13, 0.02), "text": "A chip on the lip of the neck.", "mult": 0.85, "damage": true},
		],
	},
}

## Every kind comes in five versions: number 0 is the real thing, 1 to 4 are copies, each with its own look (a tint on the model)
## and its own tell. A copy either has a wrong mark (the mark itself is the tell: misspelt, wrong date, "repro") or a mark that looks right
## and a tell somewhere else on it. So the real mark is worth learning, and the colour of a piece is a hint once you have seen the real one.
## Each copy: [mark label or "" to keep the real one, is the mark the tell?, mark text when it is, tell side, tell spot, tell text, tint]
const MARK_IDS := ["mark", "hallmark", "signature", "maker", "stamp", "lens", "plate", "crown"]
const COPIES := {
	"music_box": [
		["LINDQVIST
(printed)", true, "The stamp says \"Lindqvist\" but the letters are printed, not struck: a modern copy.", "", Vector2.ZERO, "", Color(1.12, 1.02, 0.9)],
		["J.LINDQUIST
OSLO 1904", true, "The name is misspelt, \"Lindquist\". The real maker spelled it Lindqvist: a copy.", "", Vector2.ZERO, "", Color(0.92, 0.9, 1.05)],
		["", false, "", "top", Vector2(0.0, 0.15), "Under the lid: a stamped tin movement, not a steel comb. A cheap new box.", Color(1.18, 1.08, 0.95)],
		["", false, "", "back", Vector2(0.0, 0.0), "Phillips-head screws hold the back on. Nobody used those before the 1930s.", Color(0.78, 0.72, 0.72)],
	],
	"pocket_watch": [
		["925 ???", true, "The \"silver\" hallmark is too crisp and the case is light: plated brass.", "", Vector2.ZERO, "", Color(1.15, 1.05, 0.8)],
		["952 · 1911", true, "The hallmark reads 952, not 925: stamped by someone who didn't know silver.", "", Vector2.ZERO, "", Color(0.95, 0.95, 1.0)],
		["", false, "", "front", Vector2(0.15, 0.25), "The dial is printed paper behind the glass, not enamel.", Color(1.05, 1.0, 0.92)],
		["", false, "", "top", Vector2(0.0, 0.0), "The crown is glued in place: there's a battery movement inside.", Color(0.85, 0.85, 0.9)],
	],
	"carved_bear": [
		["", false, "", "right", Vector2(0.0, 0.1), "The knife cuts are too even: machine-carved, then roughened.", Color(1.15, 1.05, 0.9)],
		["E.H. 2019", true, "Under the base: \"E.H.\" and a tiny \"2019\". Eli Harlan died in 1961.", "", Vector2.ZERO, "", Color(0.9, 0.85, 0.8)],
		["E.K.", true, "The initials are \"E.K.\", not Eli Harlan's \"E.H.\".", "", Vector2.ZERO, "", Color(1.0, 0.92, 0.82)],
		["", false, "", "top", Vector2(0.0, -0.3), "It's resin, not wood: cold, too light, with a mould seam down the back.", Color(0.8, 0.7, 0.62)],
	],
	"compass": [
		["", false, "", "bottom", Vector2(0.4, -0.4), "The green patina rubs off on your finger: painted on.", Color(0.9, 1.05, 0.9)],
		["HALL & SON
SURVEY No.2", true, "\"Hall & Son\": the real firm was Hall & Sons, always plural.", "", Vector2.ZERO, "", Color(1.12, 1.08, 0.85)],
		["", false, "", "top", Vector2(0.0, -0.2), "The needle floats in liquid with a bubble: a modern hiking compass in an old case.", Color(1.0, 0.92, 0.85)],
		["HALL & SONS
MADE IN CHINA", true, "Under the maker's name, faintly: \"Made in China\".", "", Vector2.ZERO, "", Color(0.85, 0.85, 0.8)],
	],
	"lantern": [
		["", false, "", "right", Vector2(0.0, -0.6), "Spot welds where there should be rivets: a reproduction.", Color(1.1, 0.85, 0.85)],
		["DEITZ No.2
BLIZZARD", true, "\"Deitz\", not Dietz: a knock-off.", "", Vector2.ZERO, "", Color(0.85, 0.9, 1.05)],
		["", false, "", "front", Vector2(0.25, 0.2), "The globe is plastic, not glass. It flexes when you press it.", Color(1.15, 1.1, 1.0)],
		["DIETZ No.2
REPRO", true, "Tiny letters under the name: \"REPRO\". An honest reproduction, sold as old.", "", Vector2.ZERO, "", Color(0.8, 0.8, 0.8)],
	],
	"camera": [
		["TESSAR?", true, "The lens is plastic under the chrome paint.", "", Vector2.ZERO, "", Color(1.1, 1.05, 1.0)],
		["TESAR 1:4.5", true, "\"Tesar\" with one S: a fake lens ring.", "", Vector2.ZERO, "", Color(0.9, 0.9, 1.0)],
		["", false, "", "right", Vector2(0.4, 0.05), "The bellows are vinyl, not leather: no cracks, too new.", Color(1.0, 0.9, 0.85)],
		["", false, "", "bottom", Vector2(0.0, 0.0), "A modern tripod socket with a plastic insert.", Color(0.8, 0.82, 0.88)],
	],
	"snow_globe": [
		["PINECREST", true, "The \"brass\" plate is a sticker.", "", Vector2.ZERO, "", Color(1.1, 1.05, 0.95)],
		["PINECREST
1925", true, "The plate says 1925. Pinecrest wasn't founded until 1938.", "", Vector2.ZERO, "", Color(0.9, 0.95, 1.1)],
		["", false, "", "top", Vector2(0.1, 0.1), "The snow is glitter and the liquid is too thick: a new globe.", Color(1.1, 1.0, 1.1)],
		["", false, "", "bottom", Vector2(0.0, 0.0), "A barcode sticker, half scraped off, under the base.", Color(0.85, 0.8, 0.78)],
	],
	"jug": [
		["", false, "", "bottom", Vector2(0.0, 0.0), "The base is unglazed and too clean: a new jug, aged with tea.", Color(1.05, 0.95, 0.85)],
		["RED WINGS", true, "The stamp says \"Red Wings\": the pottery was Red Wing.", "", Vector2.ZERO, "", Color(0.95, 0.98, 1.08)],
		["", false, "", "top", Vector2(0.0, 0.0), "Inside the neck the glaze is bright white and even: modern glaze.", Color(1.12, 1.1, 1.05)],
		["♛ ®", true, "A little ® beside the crown. The old pottery never marked it like that.", "", Vector2.ZERO, "", Color(0.85, 0.82, 0.78)],
	],
}

## One object as it comes through the door: a kind, which version (0 real, 1-4 copies), which of its clues apply, and so what it is really worth.
static func make(kind: String, rng: RandomNumberGenerator, fake_chance: float = 0.2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var fake := rng.randf() < fake_chance
	var variant := 0 if not fake else 1 + rng.randi() % 4
	var copy: Array = COPIES[kind][variant - 1] if fake else []
	var clues: Array = []
	for c0: Dictionary in k["clues"]:
		var c := c0.duplicate()
		if c.has("damage") and rng.randf() < 0.45:
			continue                                     ## not every piece is damaged
		if fake and c["id"] in MARK_IDS:
			if String(copy[0]) != "":
				c["label"] = copy[0]
			if copy[1]:                                  ## the mark itself gives it away
				c["text"] = copy[2]
				c["fake"] = true
				c.erase("mult")
		clues.append(c)
	if fake and not copy[1]:
		clues.append({"id": "tell", "from": copy[3], "at": copy[4], "pos": Vector3.ZERO, "text": copy[5], "fake": true})
	var value := float(k["base"])
	for c2: Dictionary in clues:
		value *= float(c2.get("mult", 1.0))
	if fake:
		value = float(k["fake_value"])
	return {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": fake, "value": roundi(value), "found": [], "base": k["base"],
		"variant": variant, "tint": Color.WHITE if not fake else copy[6]}

## The estimate the player can make from what they have found so far: a range that narrows with each clue.
static func estimate(item: Dictionary) -> Vector2:
	var k: Dictionary = KINDS[item["kind"]]
	var known := float(k["base"])
	var fake_found := false
	for c: Dictionary in item["clues"]:
		if c["id"] in item["found"]:
			if c.get("fake", false):
				fake_found = true
			known *= float(c.get("mult", 1.0))
	if fake_found:
		return Vector2(float(k["fake_value"]) * 0.7, float(k["fake_value"]) * 1.3)
	var total: int = item["clues"].size()
	var n_found := 0
	for c3: Dictionary in item["clues"]:
		if c3["id"] in item["found"]:
			n_found += 1
	var left := clampf(1.0 - float(n_found) / maxf(float(total), 1.0), 0.0, 1.0)
	var spread := lerpf(0.12, 0.75, left)
	return Vector2(known * (1.0 - spread), known * (1.0 + spread * 1.6))
