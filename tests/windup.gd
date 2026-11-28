extends SceneTree
## Wind-up pieces in the shop: winding the music box's key plays its tune (two notes missing when the comb has lost teeth, thin and
## buzzy on a cheap tin copy) and finds those clues by ear; the toy car runs, unless its spring is broken, which is then found by ear.
## Run headless: godot --headless -s tests/windup.gd
var fails := 0

func _initialize() -> void:
	call_deferred("run")

func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func piece(g: Node, kind: String, ids: Array, tell: Dictionary = {}) -> Living:
	var k: Dictionary = Items.KINDS[kind]
	var clues: Array = []
	for c: Dictionary in k["clues"]:
		if not c.has("damage") or c["id"] in ids:
			clues.append(c.duplicate())
	if not tell.is_empty():
		var t := tell.duplicate()
		t["id"] = "tell"
		t["pos"] = Vector3.ZERO
		t["fake"] = true
		clues.append(t)
	g.item = {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": not tell.is_empty(), "value": k["base"], "found": [], "base": k["base"]}
	g._place_item()
	g.start_inspect()
	await wait(0.5)
	return g._living()

func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait(2.0)
	g.skip_tutorial()
	# a sound music box: winds, plays the whole tune, nothing to find by ear
	var lv := await piece(g, "music_box", [])
	check(lv != null and lv.has_key(), "the music box has a key")
	check(String(lv.run_sound.resource_path).ends_with("tune.wav"), "a sound box plays the whole tune (got %s)" % lv.run_sound.resource_path)
	lv.toggle("Key")
	check(lv.winding > 0.0, "clicking the key winds it")
	await wait(Living.WIND_TIME + 0.3)
	check(lv.running > 0.0, "once wound, it plays")
	check(not "comb" in g.item["found"], "nothing heard on a sound box")
	# a comb with teeth missing: two notes drop out, and that is found
	lv = await piece(g, "music_box", ["comb"])
	check(String(lv.run_sound.resource_path).ends_with("tune_gap.wav"), "a gapped comb plays the gapped tune")
	lv.toggle("Key")
	await wait(Living.WIND_TIME + 0.3)
	check("comb" in g.item["found"], "the missing teeth are heard")
	# the cheap tin copy: thin, buzzy, and caught
	var tin: Dictionary = (Items.COPIES["music_box"][2] as Dictionary)["tell"]
	lv = await piece(g, "music_box", [], tin)
	check(String(lv.run_sound.resource_path).ends_with("tune_tin.wav"), "a tin movement plays the tin tune")
	lv.toggle("Key")
	await wait(Living.WIND_TIME + 0.3)
	check("tell" in g.item["found"], "the tin movement is heard")
	# a working car runs, wheels turning
	lv = await piece(g, "toy_car", [])
	check(lv != null and lv.has_key(), "the car has a key")
	check(lv.works, "a sound car works")
	lv.toggle("")                                          ## E on a piece with nothing to open: winds it
	check(lv.winding > 0.0, "E winds the car")
	await wait(Living.WIND_TIME + 0.3)
	check(lv.running > 0.0, "once wound, it runs")
	var turned := false
	for p: Dictionary in lv.parts:
		if p.get("role", "") == "wheel" and absf(float(p["a"])) > 0.5:
			turned = true
	check(turned, "its wheels turn")
	# a broken spring: the key turns, nothing runs, and it's heard
	lv = await piece(g, "toy_car", ["spring"])
	check(not lv.works, "a broken spring doesn't work")
	lv.toggle("")
	await wait(Living.WIND_TIME + 0.3)
	check(lv.running == 0.0, "a broken spring doesn't run")
	check("spring" in g.item["found"], "the broken spring is heard")
	print("RESULT: windup, %d failures" % fails)
	quit(1 if fails > 0 else 0)
