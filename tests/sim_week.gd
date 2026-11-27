extends SceneTree
## Plays whole seven-day weeks headless, fast-forwarded, with two bot players, over several seeds:
##  - cautious: finds every clue, offers low, keeps out the masked man and anyone who robbed or cheated the shop, hits the alarm;
##  - average: finds about half the clues, offers the middle of the estimate, lets everyone in, hands over the cash.
## After every day it checks the books: money = start + earned - spent (- rent), every shelf piece is a live node on a shelf,
## nothing is left on the mat. Prints one line per day and a summary per run; exits non-zero if any check fails.
## Run: godot --headless -s tests/sim_week.gd [-- --seeds=1,2,3 --policies=cautious,average]

const SPEED := 40.0
var fails := 0

func _initialize() -> void:
	call_deferred("run_all")

func arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return def

func frames(n: int) -> void:
	for i in n:
		await process_frame

func run_all() -> void:
	Engine.time_scale = SPEED
	var seeds := arg("seeds", "1,2,3,4,5,6").split(",")
	var policies := arg("policies", "cautious,average").split(",")
	var results := []
	for pol in policies:
		for sd in seeds:
			results.append(await run_week(int(sd), pol))
	print("\n==== summary ====")
	for r in results:
		print(r)
	print("RESULT: sim_week, %d failures" % fails)
	quit(1 if fails > 0 else 0)

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)

func run_week(sd: int, pol: String) -> String:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.seed_override = sd                 ## the game seeds itself from this in _ready, before day 1 starts
	root.add_child(g)
	await frames(2)
	var bot := RandomNumberGenerator.new()
	bot.seed = sd * 31 + (7 if pol == "average" else 3)
	var earned := 0
	var spent := 0
	var rent_paid := false
	var bought := 0
	var fakes_bought := 0
	var robbed := 0
	var outcome := ""
	var last_visitor = null
	var steps := 0
	while outcome == "" and steps < 200000:
		steps += 1
		await process_frame
		var st: String = g.state
		if st == "at_door" and not g.visitor.get("bot", false):
			g.visitor["bot"] = true
			var id: String = g.visitor["id"]
			var r: Dictionary = g.rep.get(id, {})
			var keep_out: bool = pol == "cautious" and (id == "robber" or int(r.get("robbed", 0)) > 0 or int(r.get("fakes", 0)) >= 2)
			if keep_out:
				g.turn_away()
			else:
				g.buzz_in()
		elif st == "talk" and not g.visitor.get("bot", false) == false and not g.visitor.get("bot_deal", false):
			g.visitor["bot_deal"] = true
			var it: Dictionary = g.item
			g.start_inspect()
			for c: Dictionary in it["clues"]:
				if pol == "cautious" or bot.randf() < 0.5:
					it["found"].append(c["id"])
			var est: Vector2 = Items.estimate(it)
			var fake_seen := false
			for c2: Dictionary in it["clues"]:
				if c2["id"] in it["found"] and c2.get("fake", false):
					fake_seen = true
			if fake_seen:
				g._caught_fake(it)
				g.decline()
				continue
			g.start_haggle()
			var offer := est.x if pol == "cautious" else (est.x + est.y) * 0.5
			var cap := (est.x + est.y) * 0.5 * 0.85 if pol == "cautious" else est.y * 0.9
			var tries := 0
			while g.state == "haggle" and tries < 8:
				tries += 1
				var o := roundi(minf(offer, cap) / 5.0) * 5
				if o > g.money or o <= 0:
					g.decline()
					break
				var m0: int = g.money
				g.make_offer(o)
				await frames(2)
				if g.money < m0:
					bought += 1
					spent += m0 - g.money
					if it["fake"]:
						fakes_bought += 1
					break
				offer *= 1.15
			if g.state == "haggle":
				g.decline()
		elif st == "sell" and not g.visitor.get("bot_deal", false):
			g.visitor["bot_deal"] = true
			var wanted: Array = g.visitor["info"]["want"]
			var pick: Dictionary = {}
			for s2: Dictionary in g.stock:
				if s2["item"]["cat"] in wanted and (pick.is_empty() or int(s2["paid"]) > int(pick["paid"])):
					pick = s2
			if pick.is_empty():
				continue
			g.present(pick)
			await frames(2)
			if g.state == "sell" and g.visitor.has("deal"):
				if g.ask <= int(pick["paid"]):
					g.sell_push()
					await frames(2)
				if g.state == "sell":
					var m1: int = g.money
					g.sell_accept()
					earned += g.money - m1
		elif st == "robbery" and not g.visitor.get("bot_deal", false):
			g.visitor["bot_deal"] = true
			robbed += 1
			var m2: int = g.money
			if pol == "cautious":
				g.rob_alarm()
			else:
				g.rob_pay()
				spent += m2 - g.money
		elif st == "day_end" or st == "over":
			var d: int = g.day
			if d == g.RENT_DAY and st == "day_end":
				rent_paid = true
			var expect: int = g.START_MONEY + earned - spent - (g.RENT if rent_paid else 0)
			check(g.money == expect, "seed %d %s day %d: money $%d, the books say $%d" % [sd, pol, d, g.money, expect])
			for s3: Dictionary in g.stock:
				check(s3["node"] != null and is_instance_valid(s3["node"]) and s3["node"].get_parent() == g, "a shelf piece is not on a shelf")
				check(s3["slot"] != Vector3.INF, "a bought piece has no shelf spot")
			check(g.pivot.get_child_count() == 0 or g.item_node == null and g.pivot.get_child_count() == 0, "something is left on the mat")
			print("seed %d %-8s day %d  money $%4d  stock %2d  shelf value $%d" % [sd, pol, d, g.money, g.stock.size(), g._stock_value()])
			if st == "over":
				outcome = "The Last Customer (rent unpaid)"
			elif d >= g.RENT_DAY:
				outcome = "rent paid"
			else:
				g.day += 1
				g._start_day()
				await frames(2)
	if outcome == "":
		check(false, "seed %d %s: the week never finished (stuck in %s, day %d)" % [sd, pol, g.state, g.day])
		outcome = "stuck"
	var line := "seed %d %-8s -> %-30s money $%d, bought %d (%d fakes), robberies %d, shelf $%d" % [sd, pol, outcome, g.money, bought, fakes_bought, robbed, g._stock_value()]
	g.queue_free()
	await frames(3)
	return line
