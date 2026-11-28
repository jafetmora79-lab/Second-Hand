extends SceneTree
## Saving: a week saved between days comes back whole in a new game (money, standing, every caller's memory, the story, the ledger,
## the shelves with their pieces, the dice), an old save missing newer fields still loads with defaults, and a newer save is refused.
## Run: godot --headless -s tests/save.gd
var fails := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)
func frames(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	g.seed_override = 11
	root.add_child(g)
	await frames(5)
	g.skip_tutorial()
	# buy two pieces, so the shelves and the ledger have something in them
	for kind in ["compass", "music_box"]:
		g.visitor = {"type": "seller", "id": "widow", "info": People.FOLK["widow"]}
		g.item = Items.make(kind, g.rng, 0.0)
		g.item["seller"] = "widow"
		g.item["found"].append(g.item["clues"][0]["id"])
		g._place_item()
		g._buy(60)
		await frames(3)
	g._rec("kid")["visits"] = 2
	g._note("kid", "I'm nearly halfway to the sled!")
	g.town["jo_sales"] = 2
	g.day = 4
	g.standing = 73
	g.accounts.append({"day": 3, "spent": 120, "earned": 200, "profit": 80, "robbed": 0, "bought": 2, "sold": 1, "money": 580})
	var dice: int = g.rng.state
	var money: int = g.money
	g.cinematics = true                                   ## saving is for real play only
	g.save_game()
	g.cinematics = false
	check(g.has_save() and g.saved_day() == 4, "the week is saved, at day 4")
	g.queue_free()
	await frames(3)
	# a new game continues it
	var h: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	h.cinematics = false
	h.seed_override = 99
	root.add_child(h)
	await frames(5)
	check(h.load_game(), "the saved week loads")
	await frames(2)
	check(h.day == 4 and h.money == money and h.standing == 73, "day, money and standing come back")
	check(h.stock.size() == 2, "both pieces are back on the shelves (got %d)" % h.stock.size())
	for st: Dictionary in h.stock:
		check(st["node"] != null and is_instance_valid(st["node"]) and st["slot"] != Vector3.INF, "a saved piece sits in a shelf slot")
		check(not (st["record"] as Dictionary).is_empty(), "a saved piece keeps its ledger line")
	check(h.purchases.size() == 2 and String(h.purchases[0]["kind"]) == "compass", "the ledger's antiques come back")
	check("I'm nearly halfway to the sled!" in h._rec("kid")["notes"], "what callers told you comes back")
	check(int(h.town["jo_sales"]) == 2 and h.accounts.size() == 1, "the story and the accounts come back")
	check(h.rng.state == dice, "the dice come back: the day plays as it would have")
	h.queue_free()
	await frames(3)
	# an old save, from before trust, the town and the ledger had pictures
	var old := {"version": 0, "day": 2, "money": 410, "rep": {"trapper": {"visits": 1, "fakes": 0, "robbed": 0}},
		"purchases": [{"name": "Oil lantern", "from": "Old Amos", "day": 1, "paid": 40}]}
	var f := FileAccess.open("user://week.save", FileAccess.WRITE)
	f.store_var(old)
	f.close()
	var k: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	k.cinematics = false
	root.add_child(k)
	await frames(5)
	check(k.load_game(), "an old save still loads")
	check(k.day == 2 and k.money == 410 and k.standing == k.STANDING_START, "old values kept, missing ones defaulted")
	check(int(k._rec("trapper")["trust"]) == 50 and k._rec("trapper").has("notes"), "an old caller record gets the newer fields")
	check(String(k.purchases[0]["kind"]) == "" and k.purchases[0].has("findings"), "an old ledger line gets the newer fields")
	# a save from a newer game is refused rather than half-read
	f = FileAccess.open("user://week.save", FileAccess.WRITE)
	f.store_var({"version": 99, "day": 5})
	f.close()
	check(not k.load_game(), "a save from a newer version is refused")
	k.delete_save()
	check(not k.has_save(), "the save can be deleted")
	print("RESULT: save, %d failures" % fails)
	quit(1 if fails > 0 else 0)
