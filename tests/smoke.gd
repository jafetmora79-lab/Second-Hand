extends SceneTree
## Plays the first caller: waits for the doorbell, buzzes them in, inspects, finds every clue, makes offers until a deal or they leave.
## Also checks the item versions (every kind: one real version and four copies, each copy with a tell) and a robbery.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func wait_state(g: Node, want: String, t: float) -> bool:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		if g.state == want:
			return true
		await process_frame
	return false
func run() -> void:
	var fails := 0
	# the versions
	var rng := RandomNumberGenerator.new()
	for kind: String in Items.KINDS:
		if Items.COPIES[kind].size() != 4:
			fails += 1
			print("FAIL: ", kind, " does not have four copies")
		var seen := {}
		for i in 300:
			var it: Dictionary = Items.make(kind, rng, 0.7)
			seen[it["variant"]] = true
			var tells := 0
			for c: Dictionary in it["clues"]:
				if c.get("fake", false):
					tells += 1
			if it["fake"] != (tells > 0) or it["fake"] != (it["variant"] != 0):
				fails += 1
				print("FAIL: ", kind, " version ", it["variant"], " fake=", it["fake"], " with ", tells, " tells")
				break
		if seen.size() != 5:
			fails += 1
			print("FAIL: ", kind, " only ever came as versions ", seen.keys())
	# a day in the shop
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	if not await wait_state(g, "at_door", 12.0):
		fails += 1
		print("FAIL: nobody rang at the door (state ", g.state, ")")
	else:
		print("at the door: ", g.visitor["id"], "  memory: ", g._memory(g.visitor["id"]))
		g.buzz_in()
	if not await wait_state(g, "talk", 8.0) or g.item.is_empty():
		fails += 1
		print("FAIL: no seller at the counter (state ", g.state, ")")
	else:
		g.start_inspect()
		for c: Dictionary in g.item["clues"]:
			g.item["found"].append(c["id"])
		var est: Vector2 = Items.estimate(g.item)
		print("item ", g.item["name"], " version ", g.item["variant"], " fake=", g.item["fake"], " value=", g.item["value"], " est=", est, " ask=", g.ask)
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
		if g._memory(g.visitor["id"]).find("Been in 1 time") < 0:
			fails += 1
			print("FAIL: the shop did not remember the visit: ", g._memory(g.visitor["id"]))
	# a robbery: next caller is the masked man
	if not await wait_state(g, "at_door", 15.0):
		fails += 1
		print("FAIL: the next caller never rang (state ", g.state, ")")
	else:
		g.figure.queue_free()
		g.visitor = {"type": "robber", "id": "robber"}
		g.queue.push_front(g.visitor.duplicate())
		g.visitor = g.queue.pop_front()
		g.queue.push_front(g.visitor)
		g.figure = null
		g._next_visitor()
		await wait_state(g, "at_door", 8.0)
		g.buzz_in()
		if not await wait_state(g, "robbery", 8.0):
			fails += 1
			print("FAIL: the robber did not hold up the shop (state ", g.state, ")")
		else:
			var m0: int = g.money
			g.rob_pay()
			if g.money >= m0:
				fails += 1
				print("FAIL: handing over the cash took nothing")
			if g._memory("robber").find("ROBBED") < 0:
				fails += 1
				print("FAIL: the shop does not remember the robbery")
			print("robbed: $", m0 - g.money, "  memory: ", g._memory("robber"))
	print("RESULT: smoke, %d failures" % fails)
	quit(1 if fails > 0 else 0)
