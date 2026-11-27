extends Node3D
## Second Hand: the day in the shop.
## Customers come in one at a time. A seller puts their object on the mat: inspect it (drag to turn, scroll to zoom, hold the loupe over details to find
## clues), then make an offer and haggle, or send them away. A buyer looks over your shelves and makes you an offer for what they like.
## Rent is due on day 7. Everyone rings at the electric door first: look at them on the porch camera and buzz them in, or don't.
## The shop remembers who brought fakes and who robbed it, and says so on the camera next time.

const START_MONEY := 500
const RENT := 600
const RENT_DAY := 7
const LOUPE_DWELL := 0.45                  ## seconds the loupe must rest on a detail to read it
const LOUPE_REACH := 0.032                 ## metres from a clue's spot that still counts
const ZOOM_READ := 0.62                    ## the camera must be at least this close to read a detail
const PORCH := Vector3(-2.2, 0, -5.6)      ## where callers wait, outside the door
const STREET := Vector3(2.0, 0, -7.6)      ## where they come from and go back to, along the lane
const INSIDE := Vector3(-2.2, 0, -3.3)     ## just inside the door

const DEFAULT_SEED := 2026
var rng := RandomNumberGenerator.new()     ## everything that decides the game: who comes, what they bring, prices, robberies
var fx_rng := RandomNumberGenerator.new()  ## looks only (animals, how an object lies on the mat): never touches the game's own dice
var game_seed := DEFAULT_SEED              ## a run is fully reproducible from this; set with --seed=N after -- on the command line
var seed_override := -1                    ## set before the node enters the tree (tests) to choose the seed without the command line
var cam: Camera3D
var shop: Dictionary
var ui: ShopUi
var money := START_MONEY
var day := 1
var queue: Array = []                      ## today's visitors: {"type": "seller"/"buyer", "id": ...}
var visitor: Dictionary = {}               ## who is at the counter
var figure: Node3D = null
var item: Dictionary = {}                  ## the object on the mat
var item_node: Node3D = null
var pivot: Node3D
var stock: Array = []                      ## {"item", "paid", "node"}
var state := "idle"                        ## idle, walking, talk, inspect, haggle, sell, day_end, over
var ask := 0                               ## the price on the table
var patience := 0
var dwell := 0.0
var dwell_clue := ""
var zoom := 0.85
var dragging := false
var want_q := Quaternion.IDENTITY          ## where the held object is turning to (drags and the turn buttons set it; it eases there)
var rest_q := Quaternion.IDENTITY          ## how it lay on the mat, for "Reset"
const REST_H := 0.15                       ## the object's centre above the mat while it lies there
const HELD_H := 0.3                        ## ...and while you hold it up to look: clear of the mat however you turn it
var day_log := {"bought": 0, "sold": 0, "spent": 0, "earned": 0}
var shelf_slots: Array = []
var rep := {}                              ## what the shop remembers about each caller: {"visits", "fakes", "robbed"}
var feed: SubViewport                      ## the porch camera
var day_total := 1                         ## callers today, for the time of day: morning at the first, night after the last
var day_time := 0.0                        ## 0 morning .. 1 night, shown through the window
var tutorial := 0                          ## the guided first customer on day 1: the step shown (0 not started, -1 done or skipped)

## The tips for the guided first customer, in order. Each shows when the player reaches that moment.
const TIPS := [
	"",
	"Someone's at the door. Check them on the porch camera, then buzz them in.",
	"Old Amos has put a music box on the mat. Take a closer look before you pay anything.",
	"Drag to turn it, or use Turn over: makers stamp the underside. Zoom in and rest the loupe on what catches your eye.",
	"Found one. The music box in the glass case is a real Lindqvist: compare the stamp. Keep looking for more details.",
	"Each detail narrows your estimate. When you're ready, make an offer.",
	"Offer under their price. Watch their patience: push too hard and they walk out.",
	"What you buy goes on your shelves. Buyers come later in the day: show them what they collect. Rent is due on day 7.",
]

func _ready() -> void:
	game_seed = seed_override if seed_override >= 0 else _seed_from_args()
	rng.seed = game_seed
	fx_rng.seed = game_seed + 1
	shop = Shop.build(self)
	shelf_slots = shop["shelves"]
	_build_feed()
	_decorate()
	_animal_loop()
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	add_child(cam)
	cam.current = true
	_shop_view(true)
	pivot = Node3D.new()
	pivot.position = Shop.MAT + Vector3(0, 0.15, 0)
	add_child(pivot)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = ShopUi.new()
	ui.game = self
	layer.add_child(ui)
	_start_day()

## --seed=N among the user arguments (godot ... -- --seed=N) picks the run; otherwise DEFAULT_SEED.
func _seed_from_args() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			return int(a.substr(7))
	return DEFAULT_SEED

## Array.shuffle() uses the global generator; this uses the game's own, so a seed always gives the same week.
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

# ---- the day -----------------------------------------------------------------------------------------------------------------------

func _start_day() -> void:
	day_log = {"bought": 0, "sold": 0, "spent": 0, "earned": 0}
	queue.clear()
	var sellers := ["trapper", "widow", "kid", "collector", "drifter"]
	_shuffle(sellers)
	if day == 1 and tutorial == 0:                      ## the guided first customer: Old Amos, first in, with a real piece
		sellers.erase("trapper")
		sellers.push_front("trapper")
	var n_sellers := mini(2 + mini(day, 3), sellers.size())
	var legit := rng.randi() % n_sellers                ## one seller a day always brings the real thing, so the rent can be made
	for i in n_sellers:
		queue.append({"type": "seller", "id": sellers[i], "legit": i == legit})
	if day == 1 and tutorial == 0:
		queue[0]["legit"] = true
		queue[0]["tutorial"] = true
	if day >= 1:
		var b: String = ["collector_b", "decorator"][day % 2]
		queue.insert(mini(2, queue.size()), {"type": "buyer", "id": b})
		if day >= 3:
			queue.append({"type": "buyer", "id": ["collector_b", "decorator"][(day + 1) % 2]})
	if day >= 2 and rng.randf() < 0.55:                 ## from day 2, trouble: a masked man, or the stranger turned bad
		queue.insert(rng.randi_range(1, queue.size()), {"type": "robber", "id": "robber" if rng.randf() < 0.6 else "drifter"})
	ui.show_day_title("Day %d" % day, "Rent of $%d due on day %d" % [RENT, RENT_DAY] if day < RENT_DAY else "Rent is due tonight: $%d" % RENT)
	state = "idle"
	day_total = maxi(1, queue.size())
	_set_time(0.0, 0.1)
	get_tree().create_timer(2.2).timeout.connect(_next_visitor)

func _next_visitor() -> void:
	if queue.is_empty():
		_set_time(1.0, 3.0)
		get_tree().create_timer(3.2).timeout.connect(_end_day)
		return
	_set_time(0.85 * float(day_total - queue.size()) / float(day_total), 4.0)      ## the day wears on with each caller; dusk by the last
	visitor = queue.pop_front()
	var info: Dictionary
	match String(visitor["type"]):
		"seller":
			info = People.FOLK[visitor["id"]]
		"buyer":
			info = People.BUYERS[visitor["id"]]
		_:
			info = People.ROBBERS["robber"].duplicate()
			if visitor["id"] != "robber":                ## someone you know, come to rob you
				info.merge(People.FOLK[visitor["id"]], false)
				info["name"] = People.FOLK[visitor["id"]]["name"]
	visitor["info"] = info
	figure = People.figure(info, visitor["id"])
	figure.position = STREET
	add_child(figure)
	People.set_layers(figure, 2)                         ## outside: lit by the cold daylight and the porch lamp
	state = "walking"
	figure.look_at(PORCH + Vector3(0, 0, 0.001), Vector3.UP, true)
	People.play(figure, "walk")
	var tw := create_tween()
	tw.tween_property(figure, "position", PORCH, 2.4)
	tw.tween_callback(_at_door)

## Moves the light outside toward a time of day (0 morning, 1/3 midday, 2/3 sunset, 1 night) over `secs`.
func _set_time(t: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		day_time = v
		Outside.set_time(v), day_time, t, secs).set_trans(Tween.TRANS_SINE)

## Now and then an animal wanders past the window (a rabbit, a wolf, a bear far off, a raven overhead).
func _animal_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(fx_rng.randf_range(12.0, 30.0)).timeout
		if state != "inspect" and state != "haggle":
			Outside.spawn_animal(self, fx_rng)

## Shows the guided first customer's tip for step `n`, only while that customer is here and only moving forward.
func _tip(n: int) -> void:
	if tutorial < 0 or not visitor.get("tutorial", false) or n <= tutorial:
		return
	tutorial = n
	ui.show_tip(TIPS[n])

func skip_tutorial() -> void:
	tutorial = -1
	ui.hide_tip()

## They ring. The porch camera comes on and shows them, with what the shop remembers about them.
func _at_door() -> void:
	figure.look_at(PORCH + Vector3(0, 0, 1.0), Vector3.UP, true)
	if not People.play(figure, "idle"):
		People.stop(figure)
	ui.bell()
	state = "at_door"
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var id: String = visitor["id"]
	var r: Dictionary = rep.get(id, {})
	var title := String(visitor["info"]["name"]) if int(r.get("visits", 0)) > 0 else "Someone at the door"
	ui.show_door(title, "*Bzzz.*  " + String(People.DOOR_LOOK.get(id, "")), _memory(id), feed.get_texture())
	_tip(1)

## What the shop remembers about a caller, for the camera.
func _memory(id: String) -> String:
	var r: Dictionary = rep.get(id, {})
	if r.is_empty():
		return "Never been in before."
	var lines: Array = ["Been in %d time%s." % [r["visits"], "" if r["visits"] == 1 else "s"]]
	if r["fakes"] > 0:
		lines.append("Brought you %d fake%s." % [r["fakes"], "" if r["fakes"] == 1 else "s"])
	if r["robbed"] > 0:
		lines.append("ROBBED THE SHOP.")
	return "  ".join(lines)

func _remember(id: String, what: String) -> void:
	if not rep.has(id):
		rep[id] = {"visits": 0, "fakes": 0, "robbed": 0}
	rep[id][what] += 1

func buzz_in() -> void:
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	ui.hide_feed()
	_remember(visitor["id"], "visits")
	state = "walking"
	_door(true)
	var f := figure
	People.play(f, "walk")
	f.look_at(INSIDE + Vector3(0, 0, 0.001), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(f, "position", Vector3(PORCH.x, 0, -4.0), 0.6)
	tw.tween_callback(func() -> void: People.set_layers(f, 1))
	tw.tween_property(f, "position", INSIDE, 0.6)
	tw.tween_callback(func() -> void:
		_door(false)
		f.look_at(Shop.CUSTOMER_SPOT + Vector3(0, 0, 0.01), Vector3.UP, true))
	tw.tween_property(f, "position", Shop.CUSTOMER_SPOT, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_arrived)

func turn_away() -> void:
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	ui.hide_feed()
	ui.say("", "You leave the door locked. After a moment they turn and trudge off up the lane.")
	state = "walking"
	var f := figure
	People.play(f, "walk")
	f.look_at(STREET + Vector3(0, 0, 0.001), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(f, "position", STREET, 2.4)
	tw.tween_callback(func() -> void:
		f.queue_free()
		_next_visitor())

## Swings the electric door open (in toward the shop) or shut; the lock light goes green while it is open.
func _door(open: bool) -> void:
	var hinge: Node3D = shop["door"]
	create_tween().tween_property(hinge, "rotation:y", -1.75 if open else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	var led := shop["lock_led"] as MeshInstance3D
	var m := led.material_override as StandardMaterial3D
	m.albedo_color = Color(0.1, 0.9, 0.2) if open else Color(0.9, 0.1, 0.08)
	m.emission = m.albedo_color
	if open:
		ui.bell()

## The porch camera: a camera over the door looking down at the step, drawn into a small picture for the UI.
func _build_feed() -> void:
	feed = SubViewport.new()
	feed.size = Vector2i(384, 288)
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(feed)
	var c := Camera3D.new()
	c.fov = 62.0
	var eye := Vector3(PORCH.x + 0.6, 2.3, -4.2)
	c.transform = Transform3D(Basis.looking_at(PORCH + Vector3(0.0, 1.0, 0) - eye), eye)
	feed.add_child(c)
	c.current = true

## The shop's own collection in the glass counter, not for sale: one of each kind of object, the real thing.
func _decorate() -> void:
	var kinds := Items.KINDS.keys()
	var spots: Array = shop["decor"]
	for i in spots.size():
		var n := Models.build({"kind": kinds[i % kinds.size()], "clues": []})
		var spot: Vector3 = spots[i]
		n.position = spot + Vector3(0, 0.1, 0)
		n.scale = Vector3.ONE * 0.75
		n.rotation.y = fx_rng.randf_range(-0.5, 0.5) + PI
		add_child(n)

func _arrived() -> void:
	var info: Dictionary = visitor["info"]
	figure.rotation = Vector3.ZERO                       ## face the counter
	if not People.play(figure, "idle") and not People.play(figure, "talk"):      ## no idle clip: a talking gesture that ends on a standing pose
		People.stop(figure)
		figure.set_meta("bob", true)
	if visitor["type"] == "robber":
		_robbery(info)
		return
	if visitor["type"] == "seller":
		var kinds := Items.KINDS.keys()
		var kind: String = kinds[rng.randi() % kinds.size()]
		if visitor.get("tutorial", false):
			kind = "music_box"                           ## the guided piece: a real one, with the reference copy in the case to compare
		var fake_chance := 0.55 if visitor["id"] == "drifter" else (0.3 if visitor["id"] == "collector" else 0.18)
		if visitor.get("legit", false):
			fake_chance = 0.0
		item = Items.make(kind, rng, fake_chance)
		item["seller"] = visitor["id"]
		_tip(2)
		_place_item()
		var belief := float(info["belief"]) * (float(item["value"]) if not item["fake"] else float(Items.KINDS[kind]["base"]) * 1.3)
		ask = maxi(5, roundi(belief * 1.25 / 5.0) * 5)
		item["floor"] = maxi(3, roundi(belief * float(info["floor"])))
		patience = int(info["patience"])
		var hello: Array = info["hello"]
		_say(info["name"], "%s\n\"I'd want $%d for this %s.\"" % [hello[rng.randi() % hello.size()], ask, String(item["name"]).to_lower()])
		state = "talk"
		ui.show_seller_actions()
	else:
		_buyer_arrived(info)

func _place_item() -> void:
	if item_node != null:
		item_node.queue_free()
	pivot.basis = Basis(Vector3.UP, fx_rng.randf_range(-0.6, 0.6))
	rest_q = pivot.quaternion
	want_q = rest_q
	item_node = Models.build(item)
	pivot.add_child(item_node)
	pivot.position = Shop.MAT + Vector3(0, REST_H, 0)
	pivot.scale = Vector3.ONE * 0.01
	create_tween().tween_property(pivot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _leave(text: String, hurry: bool = false) -> void:
	if visitor.get("leaving", false):                    ## already on their way out: never send the same person off twice
		return
	visitor["leaving"] = true
	if visitor.get("tutorial", false):
		_tip(7)
		get_tree().create_timer(9.0).timeout.connect(func() -> void: skip_tutorial())
	var info: Dictionary = visitor["info"]
	_say(info["name"], text)
	ui.hide_actions()
	state = "walking"
	if item_node != null and visitor["type"] == "seller":
		var n := item_node
		item_node = null
		create_tween().tween_property(pivot, "scale", Vector3.ONE * 0.01, 0.25).finished.connect(n.queue_free)
	_shop_view()
	var f := figure
	var k := 0.5 if hurry else 1.0
	var tw := create_tween()
	tw.tween_interval(1.2 * k)
	tw.tween_callback(func() -> void:
		f.look_at(INSIDE + Vector3(0, 0, 0.001), Vector3.UP, true)
		People.play(f, "run" if hurry else "walk"))
	tw.tween_property(f, "position", INSIDE, 1.8 * k)
	tw.tween_callback(func() -> void: _door(true))
	tw.tween_interval(0.4 * k)
	tw.tween_callback(func() -> void: People.set_layers(f, 2))
	tw.tween_property(f, "position", PORCH, 0.9 * k)
	tw.tween_callback(func() -> void:
		_door(false)
		f.look_at(STREET + Vector3(0, 0, 0.001), Vector3.UP, true))
	tw.tween_property(f, "position", STREET, 2.2 * k)
	tw.tween_callback(func() -> void:
		f.queue_free()
		item = {}
		get_tree().create_timer(0.8).timeout.connect(_next_visitor))

## A fake is found out (by your loupe, or by a buyer who won't touch it): whoever brought it in is remembered for it, once per object.
func _caught_fake(it: Dictionary) -> void:
	if it.get("caught", false) or not it.has("seller"):
		return
	it["caught"] = true
	_remember(String(it["seller"]), "fakes")

# ---- robbers -----------------------------------------------------------------------------------------------------------------------

func _robbery(info: Dictionary) -> void:
	state = "robbery"
	var lines: Array = info["demand"]
	_say(info["name"], lines[rng.randi() % lines.size()])
	ui.show_robbery_actions()

## Give him what is in the till: he takes most of it and goes. Safe, and expensive.
func rob_pay() -> void:
	var take := mini(money, maxi(60, roundi(money * 0.45 / 5.0) * 5))
	money -= take
	ui.cash(-take)
	day_log["spent"] += take
	_remember(visitor["id"], "robbed")
	_leave("He stuffs $%d in his coat and is gone." % take, true)

## The alarm under the counter: usually he runs empty-handed, sometimes he grabs the best thing off a shelf first.
func rob_alarm() -> void:
	_remember(visitor["id"], "robbed")
	var info: Dictionary = visitor["info"]
	if rng.randf() < 0.6 or stock.is_empty():
		_leave(String(info["flee"]), true)
		return
	var best: Dictionary = stock[0]
	for st: Dictionary in stock:
		if int(st["item"]["value"]) > int(best["item"]["value"]):
			best = st
	if best["node"] != null and is_instance_valid(best["node"]):
		(best["node"] as Node3D).queue_free()
	stock.erase(best)
	_leave("%s (The %s.)" % [String(info["grab"]), String(best["item"]["name"]).to_lower()], true)

func _end_day() -> void:
	state = "day_end"
	var rent_line := ""
	if day == RENT_DAY:
		if money >= RENT:
			money -= RENT
			rent_line = "You paid the rent: $%d. You kept the shop!" % RENT
		else:
			state = "over"
			ui.show_summary("Closed down", "The rent was $%d and you had $%d. The landlord changed the locks." % [RENT, money], "Try again", _restart)
			return
	var profit: int = day_log["earned"] - day_log["spent"]
	var text := "Bought %d, sold %d.\nSpent $%d, earned $%d.\nMoney: $%d.   Stock on the shelves: %d pieces worth about $%d.\n%s" % [day_log["bought"], day_log["sold"], day_log["spent"], day_log["earned"], money, stock.size(), _stock_value(), rent_line]
	if day == RENT_DAY:
		ui.show_summary("The end of the first week", text + "\n\nThis is as far as the slice goes for now.", "Play again", _restart)
		return
	ui.show_summary("Closing time, day %d" % day, text + ("\nProfit today: $%d" % profit), "Open tomorrow", func() -> void:
		day += 1
		_start_day())

func _restart() -> void:
	get_tree().reload_current_scene()

func _stock_value() -> int:
	var v := 0
	for s: Dictionary in stock:
		v += int(s["item"]["value"])
	return v

# ---- inspecting --------------------------------------------------------------------------------------------------------------------

func start_inspect() -> void:
	if item.is_empty():
		return
	state = "inspect"
	zoom = 0.75
	_lift(HELD_H)
	ui.show_inspect(item)
	_tip(3)

func stop_inspect() -> void:
	state = "talk"
	want_q = rest_q
	_lift(REST_H)
	_shop_view()
	ui.show_seller_actions()

## Raises the object off the mat to look at it, or sets it back down.
func _lift(h: float) -> void:
	create_tween().tween_property(pivot, "position", Shop.MAT + Vector3(0, h, 0), 0.35).set_trans(Tween.TRANS_SINE)

## The turn buttons and keys: a quarter turn left or right (around the vertical), tip it toward or away from you, turn it over, or put it back as it was.
func turn_item(how: String) -> void:
	var right := cam.global_transform.basis.x
	match how:
		"left":
			want_q = Quaternion(Vector3.UP, -PI * 0.5) * want_q
		"right":
			want_q = Quaternion(Vector3.UP, PI * 0.5) * want_q
		"tip_up":
			want_q = Quaternion(right, -PI * 0.5) * want_q
		"tip_down":
			want_q = Quaternion(right, PI * 0.5) * want_q
		"flip":
			want_q = Quaternion(right, PI) * want_q
		"reset":
			want_q = rest_q
			zoom = 0.75
	want_q = want_q.normalized()

func _shop_view(instant: bool = false) -> void:
	var to := Transform3D(Basis.looking_at(Vector3(0, 1.3, -2.2) - Vector3(0, 1.62, 0.35)), Vector3(0, 1.62, 0.35))
	if instant:
		cam.transform = to
	else:
		create_tween().tween_property(cam, "transform", to, 0.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if state == "inspect" or state == "haggle":
		var dir := Vector3(0, 0.55, 0.85).normalized()
		var target := pivot.global_position
		var want := Transform3D(Basis.looking_at(-dir), target + dir * zoom)
		cam.transform = cam.transform.interpolate_with(want, clampf(delta * 8.0, 0.0, 1.0))
	if pivot != null:
		pivot.quaternion = pivot.quaternion.slerp(want_q, clampf(delta * 12.0, 0.0, 1.0))
	if state == "inspect":
		_loupe(delta)
	if figure != null and is_instance_valid(figure) and figure.has_meta("bob") and state in ["talk", "inspect", "haggle", "sell"]:
		figure.position.y = absf(sin(Time.get_ticks_msec() * 0.002)) * 0.01          ## a little breathing bob

## A customer's line in the speech panel; the figure gestures while saying it (when its model has a talking clip).
func _say(who: String, text: String) -> void:
	ui.say(who, text)
	if figure != null and is_instance_valid(figure) and state != "walking":
		People.play(figure, "talk")

## Where the loupe (the mouse) points on the object; resting on a hidden detail long enough reveals it.
func _loupe(delta: float) -> void:
	var mp := get_viewport().get_mouse_position()
	ui.loupe_at = mp
	ui.loupe_on = false
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or item_node == null:
		dwell = 0.0
		ui.loupe_progress = 0.0
		return
	ui.loupe_on = true
	var local: Vector3 = item_node.global_transform.affine_inverse() * (hit["position"] as Vector3)
	var best := ""
	for c: Dictionary in item["clues"]:
		if c["id"] in item["found"]:
			continue
		if local.distance_to(c["pos"]) < LOUPE_REACH:
			best = c["id"]
	if best == "" or zoom > ZOOM_READ:
		dwell = 0.0
		ui.loupe_progress = 0.0
		ui.loupe_hint = "Closer..." if best != "" else ""
		return
	ui.loupe_hint = ""
	if best != dwell_clue:
		dwell = 0.0
		dwell_clue = best
	dwell += delta
	ui.loupe_progress = dwell / LOUPE_DWELL
	if dwell >= LOUPE_DWELL:
		item["found"].append(best)
		dwell = 0.0
		ui.loupe_progress = 0.0
		for c2: Dictionary in item["clues"]:
			if c2["id"] == best:
				ui.found_clue(c2)
				_tip(4 if item["found"].size() < 2 else 5)
				if c2.get("fake", false):
					_caught_fake(item)
		ui.refresh_inspect(item)

func _unhandled_input(event: InputEvent) -> void:
	if state != "inspect" and state != "haggle":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_A, KEY_LEFT:
				turn_item("left")
			KEY_D, KEY_RIGHT:
				turn_item("right")
			KEY_W, KEY_UP:
				turn_item("tip_up")
			KEY_S, KEY_DOWN:
				turn_item("tip_down")
			KEY_F:
				turn_item("flip")
			KEY_R:
				turn_item("reset")
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom - 0.06, 0.28, 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom + 0.06, 0.28, 1.0)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		## left-right spins it like a turntable (around the true vertical, so it never rolls sideways); up-down tips it toward you
		var right := cam.global_transform.basis.x
		want_q = (Quaternion(Vector3.UP, mm.relative.x * 0.008) * Quaternion(right, mm.relative.y * 0.008) * want_q).normalized()

# ---- haggling ----------------------------------------------------------------------------------------------------------------------

func start_haggle() -> void:
	_tip(6)
	state = "haggle"
	ui.show_haggle(item, ask, patience)

## The player offers `offer` for the object on the mat. Returns what the seller says.
func make_offer(offer: int) -> void:
	var info: Dictionary = visitor["info"]
	var floor_p: int = item["floor"]
	if offer >= ask:
		_buy(ask)
		return
	if offer < floor_p * 0.6:
		patience -= 2
		if patience <= 0:
			_leave(info["leave"])
			return
		_say(info["name"], info["insult"])
	elif offer >= floor_p and offer >= ask * 0.85:
		_buy(offer)
		return
	else:
		patience -= 1
		if patience <= 0:
			_leave(info["leave"])
			return
		ask = maxi(floor_p, roundi(lerpf(ask, maxf(offer, floor_p), 0.45) / 5.0) * 5)
		if offer >= floor_p and patience <= 1:
			_buy(offer)
			return
		_say(info["name"], String(info["counter"]) % ("$%d" % ask))
	ui.show_haggle(item, ask, patience)

func accept_ask() -> void:
	_buy(ask)

func decline() -> void:
	var info: Dictionary = visitor["info"]
	_leave(info["leave"])

func _buy(price: int) -> void:
	if price > money:
		ui.toast("You don't have $%d." % price)
		return
	if _free_slot() == Vector3.INF:
		ui.toast("Your shelves are full. Sell something first.")
		return
	var info: Dictionary = visitor["info"]
	money -= price
	day_log["bought"] += 1
	day_log["spent"] += price
	ui.cash(-price)
	# the object goes onto a shelf
	var slot := _free_slot()
	var n := item_node
	item_node = null
	if slot != Vector3.INF and n != null:
		var g := n.global_transform
		n.get_parent().remove_child(n)
		add_child(n)
		n.global_transform = g
		create_tween().tween_property(n, "global_position", slot + Vector3(0, 0.12, 0), 0.6).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(n, "scale", Vector3.ONE * 0.9, 0.6)
	stock.append({"item": item, "paid": price, "node": n, "slot": slot})
	pivot.scale = Vector3.ONE
	_leave(info["accept"])

func _free_slot() -> Vector3:
	for s: Vector3 in shelf_slots:
		var used := false
		for st: Dictionary in stock:
			if st["slot"] == s:
				used = true
		if not used:
			return s
	return Vector3.INF

# ---- buyers ------------------------------------------------------------------------------------------------------------------------

func _buyer_arrived(info: Dictionary) -> void:
	state = "sell"
	var wanted: Array = info["want"]
	var choices: Array = []
	for st: Dictionary in stock:
		if st["item"]["cat"] in wanted:
			choices.append(st)
	if choices.is_empty():
		_say(info["name"], "%s\nHm. Nothing here for me today." % info["hello"])
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _leave("Maybe next time."))
		return
	_say(info["name"], "%s\nWhat have you got?" % info["hello"])
	ui.show_present_choices(choices)

## You choose which piece to show the buyer (they never pick by its hidden value). An expert sees through a copy every time;
## an amateur only sometimes. Otherwise they make an offer from what the piece really is.
func present(st: Dictionary) -> void:
	var info: Dictionary = visitor["info"]
	var it: Dictionary = st["item"]
	if it["fake"] and rng.randf() < float(info.get("eye", 1.0)):
		state = "refused"                                ## no sale can go through while they say so and leave
		_caught_fake(it)
		_say(info["name"], "That %s... %s" % [String(it["name"]).to_lower(), info["fake"]])
		get_tree().create_timer(3.5).timeout.connect(func() -> void: _leave("Good day."))
		return
	visitor["deal"] = st
	var worth := float(it["value"]) if not it["fake"] else float(it["base"])     ## a copy that fools them is priced as a plain example
	ask = maxi(5, roundi(worth * float(info["pays"]) * rng.randf_range(0.85, 1.05) / 5.0) * 5)
	patience = int(info["patience"])
	_say(info["name"], "\"I'll give you $%d for the %s.\" (You paid $%d.)" % [ask, String(it["name"]).to_lower(), st["paid"]])
	ui.show_buyer_actions(ask)

func sell_accept() -> void:
	var deal: Dictionary = visitor["deal"]
	money += ask
	day_log["sold"] += 1
	day_log["earned"] += ask
	ui.cash(ask)
	if deal["node"] != null and is_instance_valid(deal["node"]):
		(deal["node"] as Node3D).queue_free()
	stock.erase(deal)
	_leave("A pleasure doing business.")

func sell_push() -> void:
	var info: Dictionary = visitor["info"]
	patience -= 1
	if rng.randf() < 0.55 and patience > 0:
		ask = roundi(ask * 1.12 / 5.0) * 5
		_say(info["name"], "\"All right. $%d, and not a cent more.\"" % ask)
		ui.show_buyer_actions(ask)
	else:
		_leave("Then I'll look elsewhere.")
