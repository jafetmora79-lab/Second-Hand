extends SceneTree
## The restoration bench: bought pieces arrive grimy; scrubbing a genuine piece clean raises its value; scrubbing a copy reveals its
## tell; stopping halfway (or a caller at the door) puts it back on its shelf with its progress kept.
## Run: godot --headless -s tests/bench.gd
var fails := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func frames(n: int) -> void:
	for i in n:
		await process_frame
func buy(g: Node, kind: String, fake: bool) -> Dictionary:
	g.visitor = {"type": "seller", "id": "drifter", "info": People.FOLK["drifter"]}
	g.item = Items.make(kind, g.rng, 1.0 if fake else 0.0)
	g.item["seller"] = "drifter"
	g._place_item()
	g._buy(50)
	await frames(3)
	return g.stock[-1]
## Scrubs back and forth over the piece on the bench, `strokes` times.
func scrub(g: Node, strokes: int) -> void:
	await wait(0.8)                                      ## let it reach the bench
	var at: Vector2 = g.cam.unproject_position((g.restore_st["node"] as Node3D).global_position)
	for i in strokes:
		if not g.restoring:
			return
		g._scrub(Vector2(120 if i % 2 == 0 else -120, 10), at)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	g.seed_override = 21
	root.add_child(g)
	await frames(5)
	g.skip_tutorial()
	g.queue.clear()
	g.state = "idle"
	var real: Dictionary = await buy(g, "lantern", false)
	check(float(real["item"]["grime"]) == 1.0, "a bought piece arrives grimy")
	var v0 := int(real["item"]["value"])
	g.start_restore(real)
	check(g.restoring and g.restore_st == real, "the piece goes to the bench")
	await scrub(g, 4)
	check(g.restoring and float(real["item"]["grime"]) > 0.0 and float(real["item"]["grime"]) < 1.0, "a few strokes take some grime off")
	g.stop_restore()
	var part := float(real["item"]["grime"])
	await wait(0.8)
	check(not g.restoring and (real["node"] as Node3D).global_position.distance_to(real["slot"] + Vector3(0, 0.12, 0)) < 0.02, "put back: it's on its shelf again")
	g.start_restore(real)
	await frames(2)
	check(float(real["item"]["grime"]) == part, "its progress was kept")
	await scrub(g, 40)
	check(not g.restoring and float(real["item"]["grime"]) == 0.0, "scrubbed clean, it goes back to its shelf")
	check(int(real["item"]["value"]) == roundi(v0 * g.RESTORE_GAIN), "a cleaned genuine piece is worth more (%d -> %d)" % [v0, real["item"]["value"]])
	check("Cleaned and polished on the bench." in real["record"]["findings"], "the ledger notes the cleaning")
	# a copy gives itself away
	var copy: Dictionary = await buy(g, "pocket_watch", true)
	var fakes0 := int(g._rec("drifter")["fakes"])
	var vc := int(copy["item"]["value"])
	g.start_restore(copy)
	await scrub(g, 40)
	var told := false
	for c: Dictionary in copy["item"]["clues"]:
		if c.get("fake", false) and c["id"] in copy["item"]["found"]:
			told = true
	check(told, "cleaning a copy reveals its tell")
	check(int(g._rec("drifter")["fakes"]) == fakes0 + 1, "and the shop remembers who brought it")
	check(int(copy["item"]["value"]) == vc, "a copy isn't worth more for the cleaning")
	print("RESULT: bench, %d failures" % fails)
	quit(1 if fails > 0 else 0)
