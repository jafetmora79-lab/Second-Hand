extends SceneTree
## Plays the first customer: waits for them, inspects, finds every clue, makes offers until a deal or they leave.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	var fails := 0
	await wait(7.0)
	if g.state != "talk" or g.item.is_empty():
		fails += 1
		print("FAIL: no seller at the counter (state ", g.state, ")")
	else:
		g.start_inspect()
		for c: Dictionary in g.item["clues"]:
			g.item["found"].append(c["id"])
		var est: Vector2 = Items.estimate(g.item)
		print("item ", g.item["name"], " fake=", g.item["fake"], " value=", g.item["value"], " est=", est, " ask=", g.ask)
		if g.item["value"] < est.x * 0.7 or g.item["value"] > est.y * 1.3:
			fails += 1
			print("FAIL: estimate with every clue found misses the value")
		g.start_haggle()
		g.money = 5000
		var money0: int = g.money
		g.make_offer(int(g.ask))
		await wait(0.5)
		if g.money >= money0:
			fails += 1
			print("FAIL: paying the asking price did not buy it")
		if g.stock.size() != 1:
			fails += 1
			print("FAIL: the object did not go on the shelf")
	print("RESULT: smoke, %d failures" % fails)
	quit(1 if fails > 0 else 0)
