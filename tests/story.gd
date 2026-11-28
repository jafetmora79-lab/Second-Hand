extends SceneTree
## Phase 3 rules, played directly against the game: asking at the door, the three things you can say, calling out a copy only with
## evidence, greetings that wait for the story (Toby's sled, the stranger's job), the stranger's robbery odds, and the ledger.
## Run: godot --headless -s tests/story.gd
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
	g.seed_override = 3
	root.add_child(g)
	await frames(5)
	g.skip_tutorial()
	# --- the door question: a robber's answer gives him away, a seller answers with a greeting
	g.state = "at_door"
	g.visitor = {"type": "robber", "id": "robber", "info": People.ROBBERS["robber"]}
	g.ask_door()
	check(g.ui._speech_text.text.contains("something to sell"), "the masked man's answer at the door")
	check(g.visitor.get("asked", false), "asking is remembered (once per caller)")
	g.state = "at_door"
	g.visitor = {"type": "seller", "id": "kid", "info": People.FOLK["kid"]}
	g.ask_door()
	check(g.ui._speech_text.text.contains("sled"), "Toby answers with his greeting")
	# --- talking: once a visit; each choice does its thing
	var k: Dictionary = Items.KINDS["lantern"]
	g.item = Items.make("lantern", g.rng, 0.0)
	g.item["floor"] = 40
	g.ask = 100
	g.patience = 3
	g.state = "talk"
	g.visitor = {"type": "seller", "id": "widow", "info": People.FOLK["widow"]}
	var t0: int = g._rec("widow")["trust"]
	check(g.can_talk(), "you can talk to a seller")
	g.talk("friendly")
	check(g.patience == 4 and int(g._rec("widow")["trust"]) == t0 + 3, "friendly: more patience, more trust")
	check(not g.can_talk(), "only one thing said per visit")
	g.visitor = {"type": "seller", "id": "trapper", "info": People.FOLK["trapper"]}
	g.state = "talk"
	g.talk("firm")
	check(g.ask == 90, "firm: the price comes down 8%% (got %d)" % g.ask)
	g.visitor = {"type": "seller", "id": "drifter", "info": People.FOLK["drifter"]}
	g.state = "talk"
	g._rec("drifter")["trust"] = 40
	g.talk("ask")
	check(not g._rec("drifter")["rumor_heard"] and int(g._rec("drifter")["trust"]) == 38, "asking a wary stranger: he bristles")
	g.visitor = {"type": "seller", "id": "trapper", "info": People.FOLK["trapper"]}
	g.state = "talk"
	g._rec("trapper")["fair_deals"] = 1
	g.talk("ask")
	check(g._rec("trapper")["rumor_heard"], "asking someone who trusts you: a rumour")
	check(Dialogue.SELLERS["trapper"]["rumor"] in g._rec("trapper")["notes"], "the rumour goes in the ledger")
	# --- calling out a copy: only with the evidence found
	g.item = Items.make("pocket_watch", g.rng, 1.0)
	check(g.item["fake"], "a copy for the test")
	g.state = "talk"
	g.visitor = {"type": "seller", "id": "collector", "info": People.FOLK["collector"]}
	check(not g.can_confront(), "no calling it a copy before finding the tell")
	for c: Dictionary in g.item["clues"]:
		if c.get("fake", false):
			g.item["found"].append(c["id"])
	g.item["seller"] = "collector"
	check(g.can_confront(), "calling it a copy once the tell is found")
	var s0: int = g.standing
	g.confront()
	check(int(g.town["fakes_exposed"]) == 1 and g.standing == s0 + 2 and int(g._rec("collector")["fake_exposed"]) == 1, "exposing a copy is remembered")
	await frames(2)
	# --- greetings wait for the story
	var r: Dictionary = g._rec("kid")
	r["visits"] = 4
	r["paid_total"] = 20
	check(not Dialogue.greeting("kid", r, g.town).contains("got my sled"), "no sled before he has the money")
	r["paid_total"] = 95
	check(Dialogue.greeting("kid", r, g.town).contains("got my sled"), "Toby's sled once you've paid him enough")
	var d: Dictionary = g._rec("drifter")
	d["visits"] = 4
	d["trust"] = 70
	check(not Dialogue.greeting("drifter", d, g.town).contains("job"), "no job before the lodge reopens")
	g.town["jo_sales"] = 2
	check(Dialogue.greeting("drifter", d, g.town).contains("job"), "the stranger's job once the lodge is reopening and he trusts you")
	# --- the stranger's robbery odds follow trust, and stop once he has work
	d["employed"] = false
	d["trust"] = 20
	check(is_equal_approx(g._drifter_risk(), 0.65), "a hostile stranger is a real risk")
	d["trust"] = 50
	check(is_equal_approx(g._drifter_risk(), 0.15), "a wary one, less so")
	d["employed"] = true
	check(g._drifter_risk() == 0.0, "a man with work doesn't rob you")
	# --- the ledger
	check(not g.ledger_customers().is_empty(), "the ledger lists customers")
	check(not g.ledger_accounts().is_empty(), "the ledger has today's accounts")
	g.ui.toggle_ledger()
	for tab in ["customers", "antiques", "accounts"]:
		g.ui._ledger_tab = tab
		g.ui._fill_ledger()
		await frames(1)
	g.ui.toggle_ledger()
	print("RESULT: story, %d failures" % fails)
	quit(1 if fails > 0 else 0)
