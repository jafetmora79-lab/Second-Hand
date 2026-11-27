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
		"fake_clues": [
			{"id": "fake_mark", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.075, 0), "text": "The stamp says \"Lindqvist\" but the letters are printed, not struck: a modern copy.", "fake": true, "label": "LINDQVIST\n(printed)", "face": "bottom"},
		],
	},
	"pocket_watch": {
		"name": "Pocket watch", "cat": "watches", "base": 240, "fake_value": 20,
		"clues": [
			{"id": "hallmark", "from": "back", "at": Vector2(0.1, -0.1), "pos": Vector3(0, 0, -0.012), "text": "Hallmarks on the back of the case: sterling silver, 1911.", "mult": 1.5, "label": "925 · 1911", "face": "back"},
			{"id": "crystal", "from": "front", "at": Vector2(-0.05, -0.1), "pos": Vector3(0.0, 0.0, 0.016), "text": "A hairline crack across the crystal.", "mult": 0.8, "damage": true},
			{"id": "crown", "from": "top", "at": Vector2(-0.05, 0.0), "pos": Vector3(0, 0.055, 0), "text": "The winding crown turns smoothly: the movement runs.", "mult": 1.2},
		],
		"fake_clues": [
			{"id": "fake_hallmark", "from": "back", "at": Vector2(0.1, -0.1), "pos": Vector3(0, 0, -0.012), "text": "The \"silver\" hallmark is too crisp and the case is light: plated brass.", "fake": true, "label": "925 ???", "face": "back"},
		],
	},
	"carved_bear": {
		"name": "Carved bear", "cat": "folk art", "base": 120, "fake_value": 10,
		"clues": [
			{"id": "signature", "from": "bottom", "at": Vector2(0, 0), "pos": Vector3(0, -0.06, 0), "text": "Carved under the base: \"E.H.\" Eli Harlan, the old trapper-carver.", "mult": 2.2, "label": "E.H.", "face": "bottom"},
			{"id": "ear", "from": "top", "at": Vector2(0.35, 0.45), "pos": Vector3(0.05, 0.07, 0.03), "text": "One ear was snapped off and glued back.", "mult": 0.75, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_cuts", "from": "right", "at": Vector2(0.0, 0.1), "pos": Vector3(0.0, 0.03, 0.06), "text": "The knife cuts are too even: machine-carved, then roughened.", "fake": true},
		],
	},
	"compass": {
		"name": "Brass compass", "cat": "instruments", "base": 150, "fake_value": 12,
		"clues": [
			{"id": "maker", "from": "bottom", "at": Vector2(0, 0.1), "pos": Vector3(0, -0.012, 0), "text": "Engraved underneath: \"Hall & Sons, Survey No. 2\".", "mult": 1.5, "label": "HALL & SONS\nSURVEY No.2", "face": "bottom"},
			{"id": "needle", "from": "top", "at": Vector2(0.0, 0.15), "pos": Vector3(0, 0.012, 0), "text": "The needle still swings true to north.", "mult": 1.1},
			{"id": "dent", "from": "right", "at": Vector2(0.0, -0.55), "pos": Vector3(0.045, 0.0, 0.0), "text": "A dent in the rim from a fall.", "mult": 0.85, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_patina", "from": "bottom", "at": Vector2(0.3, 0.3), "pos": Vector3(0.0, -0.012, 0.0), "text": "The green patina rubs off on your finger: painted on.", "fake": true},
		],
	},
	"lantern": {
		"name": "Oil lantern", "cat": "household", "base": 70, "fake_value": 8,
		"clues": [
			{"id": "stamp", "from": "front", "at": Vector2(0.0, -0.8), "pos": Vector3(0, -0.1, 0.0), "text": "Embossed on the tank: \"Dietz No. 2 Blizzard\". Collectors want these.", "mult": 1.8, "label": "DIETZ No.2\nBLIZZARD", "face": "bottom"},
			{"id": "glass", "from": "front", "at": Vector2(0.2, 0.0), "pos": Vector3(0.04, 0.0, 0.0), "text": "The glass globe has a chip near the top.", "mult": 0.8, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_weld", "from": "right", "at": Vector2(0.0, -0.6), "pos": Vector3(0.0, -0.06, 0.04), "text": "Spot welds where there should be rivets: a reproduction.", "fake": true},
		],
	},
	"camera": {
		"name": "Folding camera", "cat": "instruments", "base": 160, "fake_value": 15,
		"clues": [
			{"id": "lens", "pos": Vector3(0, 0.0, 0.09), "text": "The lens ring reads \"Tessar 1:4.5\": a good lens.", "mult": 1.4, "label": "TESSAR 1:4.5", "face": "front"},
			{"id": "bellows", "pos": Vector3(0.04, 0.0, 0.04), "text": "Pinholes in the bellows: light leaks.", "mult": 0.7, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_lens", "pos": Vector3(0, 0.0, 0.09), "text": "The lens is plastic under the chrome paint.", "fake": true, "label": "TESSAR?", "face": "front"},
		],
	},
	"snow_globe": {
		"name": "Snow globe", "cat": "curios", "base": 60, "fake_value": 5,
		"clues": [
			{"id": "plate", "pos": Vector3(0, -0.035, 0.05), "text": "The brass plate reads \"Pinecrest 1952\": made here in town.", "mult": 1.7, "label": "PINECREST\n1952", "face": "front"},
			{"id": "water", "pos": Vector3(0.0, 0.07, 0.0), "text": "An air bubble at the top: some water has leaked out.", "mult": 0.85, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_plate", "pos": Vector3(0, -0.035, 0.05), "text": "The \"brass\" plate is a sticker.", "fake": true, "label": "PINECREST", "face": "front"},
		],
	},
	"jug": {
		"name": "Stoneware jug", "cat": "household", "base": 55, "fake_value": 6,
		"clues": [
			{"id": "crown", "pos": Vector3(0.0, 0.0, 0.075), "text": "A blue crown stamp: the Red Wing pottery, early 1900s.", "mult": 1.9, "label": "♛", "face": "front"},
			{"id": "chip", "pos": Vector3(0.0, 0.13, 0.02), "text": "A chip on the lip of the neck.", "mult": 0.85, "damage": true},
		],
		"fake_clues": [
			{"id": "fake_glaze", "pos": Vector3(0.0, -0.09, 0.0), "text": "The base is unglazed and too clean: a new jug, aged with tea.", "fake": true},
		],
	},
}

## One object as it comes through the door: a kind, which of its clues apply, whether it is a fake, and so what it is really worth.
static func make(kind: String, rng: RandomNumberGenerator, fake_chance: float = 0.2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var fake := rng.randf() < fake_chance
	var clues: Array = []
	for c0: Dictionary in k["clues"]:
		var c := c0.duplicate()
		if c.has("damage") and rng.randf() < 0.45:
			continue                                     ## not every piece is damaged
		if fake and c["id"] in ["mark", "hallmark", "signature", "maker", "stamp", "lens", "plate", "crown"]:
			continue                                     ## a fake's mark is the fake tell instead
		clues.append(c)
	if fake:
		for f0: Dictionary in k["fake_clues"]:
			clues.append(f0.duplicate())
	var value := float(k["base"])
	for c2: Dictionary in clues:
		value *= float(c2.get("mult", 1.0))
	if fake:
		value = float(k["fake_value"])
	return {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": fake, "value": roundi(value), "found": [], "base": k["base"]}

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
