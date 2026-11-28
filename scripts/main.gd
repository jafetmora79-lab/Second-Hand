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
const PORCH := Vector3(-2.2, 0, -6.0)      ## where callers wait, outside the door
const STREET := Vector3(12.0, 0, -7.6)     ## where they come from and go back to: up the lane, out of sight to the right
const LANE := Vector3(-2.2, 0, -7.6)       ## the lane in front of the door; callers walk along it past the window
const WALK_SPEED := 1.4                    ## metres a second along the lane
const INSIDE := Vector3(-2.2, 0, -3.3)     ## just inside the door
## The way through the shop between the door and the counter: from just inside the door, along the aisle, then straight up to the
## counter (and the same in reverse), so nobody slides sideways across the room.
const ROUTE_IN := [Vector3(-1.6, 0, -3.0), Vector3(-0.3, 0, -2.35), Vector3(0.0, 0, -1.95)]
const ROUTE_OUT := [Vector3(-0.3, 0, -2.35), Vector3(-1.6, 0, -3.0)]
const TURN_TIME := 0.3                     ## seconds to turn toward the next leg of a walk

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
# the view from behind the counter: look around by moving the mouse to an edge of the screen (or the arrow keys / WASD); while a customer talks, the camera turns to
# frame their face and narrows a little, as The Veil's conversation camera does (world.gd talk camera: FOV x0.9, ~0.4 s to settle)
const SHOP_EYE := Vector3(0, 1.62, 0.35)
const SHOP_LOOK := Vector3(0, 1.3, -2.2)
const SHOP_FOV := 60.0
const TALK_FOV_SCALE := 0.86               ## the zoom on a speaker: a touch tighter than The Veil's 0.9, the shop is small
const TALK_EASE := 7.0                     ## ~0.4 s to settle on the speaker
const LOOK_EASE := 10.0
var look_yaw := 0.0                        ## the player's own look-around, relative to the counter view
var look_pitch := 0.0
const EDGE := 0.07                         ## the band round the screen's edge, as a share of its size, where the mouse turns the view
const EDGE_SPEED := 1.2                    ## radians a second with the mouse right at the edge
var talk_focus := false                    ## a customer is talking: frame them (until the player looks away)
const VIEW_STATES := ["idle", "walking", "at_door", "talk", "sell", "robbery", "refused"]
const MONITOR_SNAP := 0.26                 ## look within this angle (radians) of the monitor and the view zooms in to it
var want_q := Quaternion.IDENTITY          ## where the held object is turning to (drags and the turn buttons set it; it eases there)
var rest_q := Quaternion.IDENTITY          ## how it lay on the mat, for "Reset"
const REST_H := 0.15                       ## the object's centre above the mat while it lies there
const HELD_H := 0.3                        ## ...and while you hold it up to look: clear of the mat however you turn it
var day_log := {"bought": 0, "sold": 0, "spent": 0, "earned": 0, "profit": 0, "robbed": 0}
var week_profit := 0                       ## realised profit all week: what sold pieces fetched, less what you paid for them
## The town's opinion of the shop, 0..100 (starts at 50). Each kind of thing counts once per encounter: a fair purchase +2,
## a lowball -4, turning away someone with a clean record -2, knowingly offering a copy as genuine -8. Buyers pay a little more
## or less for it; a good name at the end of the week is the best ending.
const STANDING_START := 50
const STANDING_GOOD := 70                  ## rent paid and at least this: "A Place in Town"
var standing := STANDING_START
const RENT_DAY_PIECES := 4                 ## how many pieces each rent-day buyer will take
var ending := ""                           ## set on rent day: "A Place in Town", "Open for Business" or "The Last Customer"
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
	var grade := CanvasLayer.new()                       ## the Winter Amber vignette and grain, under the HUD
	grade.layer = 0
	add_child(grade)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amber = ShaderMaterial.new()
	amber.shader = load("res://shaders/winter_amber.gdshader") as Shader
	amber.set_shader_parameter("inspection", 0.0)
	veil.material = amber
	grade.add_child(veil)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = ShopUi.new()
	ui.game = self
	layer.add_child(ui)
	cine_cam = Camera3D.new()
	cine_cam.fov = 50.0
	add_child(cine_cam)
	if cinematics and has_save():
		ui.veil_to(1.0, 0.0)
		ui.show_menu(saved_day(), func() -> void:
			load_game()
			_open_day(), func() -> void:
			delete_save()
			_open_day())
	elif cinematics:
		_open_day()
	else:
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
	day_log = {"bought": 0, "sold": 0, "spent": 0, "earned": 0, "profit": 0, "robbed": 0}
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
		if day >= 2 and day < RENT_DAY:
			queue.append({"type": "buyer", "id": ["collector_b", "decorator"][(day + 1) % 2]})
		if day == RENT_DAY:                               ## rent day: both buyers, last, each willing to take several pieces
			queue.append({"type": "buyer", "id": "collector_b", "many": true})
			queue.append({"type": "buyer", "id": "decorator", "many": true})
	if day >= 2 and rng.randf() < 0.25:                ## from day 2, trouble: a masked man, now and then
		queue.insert(rng.randi_range(1, queue.size()), {"type": "robber", "id": "robber"})
	if day >= 2:                                      ## the stranger: desperate men rob, men with work and a friend in town don't
		for v: Dictionary in queue:
			if v["type"] == "seller" and v["id"] == "drifter" and not v.get("legit", false) and rng.randf() < _drifter_risk():
				v["type"] = "robber"
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
	if visitor["type"] == "buyer" and not visitor.get("many", false) and not _wants_any(visitor["id"]):
		var other := "decorator" if visitor["id"] == "collector_b" else "collector_b"
		if _wants_any(other):
			visitor["id"] = other
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
	figure.look_at(LANE + Vector3(0, 0, 0.001), Vector3.UP, true)
	People.play(figure, "walk")
	var tw := create_tween()
	var f0 := figure
	tw.tween_property(figure, "position", LANE, STREET.distance_to(LANE) / WALK_SPEED)       ## along the lane, past the window
	tw.tween_callback(func() -> void: f0.look_at(PORCH + Vector3(0, 0, 0.001), Vector3.UP, true))
	tw.tween_property(figure, "position", PORCH, LANE.distance_to(PORCH) / WALK_SPEED)
	tw.tween_callback(_at_door)

## Adds to `tw` a walk for `f` from `from` through `pts` at `speed`, turning to face each leg as it starts. Returns the last point.
func _walk(tw: Tween, f: Node3D, from: Vector3, pts: Array, speed: float) -> Vector3:
	var at := from
	for p: Vector3 in pts:
		var d := p - at
		if d.length() < 0.01:
			continue
		var yaw := atan2(d.x, d.z)                       ## the figures face +Z
		tw.tween_callback(func() -> void: _turn(f, yaw))
		tw.tween_property(f, "position", p, d.length() / speed)
		at = p
	return at

## Turns a figure to `yaw` over TURN_TIME, the short way round.
func _turn(f: Node3D, yaw: float) -> void:
	if not is_instance_valid(f):
		return
	var y0 := f.rotation.y
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(f):
			f.rotation = Vector3(0, lerp_angle(y0, yaw, t), 0), 0.0, 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE)

# ---- the restoration bench: something to do between customers ---------------------------------------------------------------------
## On your right behind the counter. Look at it while nobody needs you and you can bring a piece down off the shelves and scrub the
## grime off it (hold the mouse button and rub back and forth over it). A genuine piece, cleaned, is worth more (RESTORE_GAIN); a copy,
## cleaned, gives itself away: its tell shows through. If someone rings, the piece goes back on its shelf, keeping its progress.
const BENCH := Vector3(1.0, 0.0, 0.22)       ## the counter's right wing, beside you
const BENCH_SPOT := Vector3(0.98, 1.17, 0.24)  ## where a piece sits on the bench to be cleaned
const BENCH_SNAP := 0.3                    ## look within this angle (radians) of the bench and the view leans over it
const RESTORE_GAIN := 1.12                 ## a cleaned genuine piece's value
const SCRUB_RATE := 0.0011                 ## grime taken off per pixel of scrubbing
var restoring := false
var restore_st: Dictionary = {}            ## the shelf entry on the bench
var _scrubbing := false
var _bench_shown := false                  ## the bench's choices are on screen

## Grime on a piece: a dark, blotchy film over all of it, `amount` 0 (clean) .. 1 (fresh from the attic).
var _grime_tex: NoiseTexture2D
func _grime(node: Node3D, amount: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var mat: StandardMaterial3D = node.get_meta("grime_mat") if node.has_meta("grime_mat") else null
	if mat == null:
		if _grime_tex == null:
			_grime_tex = NoiseTexture2D.new()
			_grime_tex.width = 128
			_grime_tex.height = 128
			_grime_tex.seamless = true
			var n := FastNoiseLite.new()
			n.frequency = 0.06
			_grime_tex.noise = n
		mat = StandardMaterial3D.new()
		mat.albedo_texture = _grime_tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 18.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		node.set_meta("grime_mat", mat)
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			if not (mi as MeshInstance3D).has_meta("clue"):
				(mi as MeshInstance3D).material_overlay = mat
	mat.albedo_color = Color(0.22, 0.16, 0.1, 0.62 * clampf(amount, 0.0, 1.0))

## The bench's choices, while you look at it and nobody needs you.
func _bench_offer() -> void:
	var looking := (not talk_focus or state in ["idle", "walking"]) and (-cam.global_transform.basis.z).angle_to((BENCH_SPOT - cam.global_position).normalized()) < 0.35
	var free := state in ["idle", "walking"] and not restoring
	if looking and free and not _bench_shown:
		_bench_shown = true
		var dirty: Array = []
		for st: Dictionary in stock:
			if float(st["item"].get("grime", 0.0)) > 0.0:
				dirty.append(st)
		ui.show_bench_choices(dirty)
	elif _bench_shown and (not looking or not free):
		_bench_shown = false
		if not restoring:
			ui.hide_actions()

## Brings a piece from its shelf to the bench.
func start_restore(st: Dictionary) -> void:
	if restoring or not st in stock:
		return
	restoring = true
	restore_st = st
	ui.hide_actions()
	var n: Node3D = st["node"]
	var tw := create_tween()
	tw.tween_property(n, "global_position", BENCH_SPOT, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 1.5, 0.6)
	ui.show_restore_actions()
	ui.toast("Hold the mouse button and scrub the grime off the %s." % String(st["item"]["name"]).to_lower())

## Puts the piece back on its shelf (progress kept).
func stop_restore() -> void:
	if not restoring:
		return
	restoring = false
	_scrubbing = false
	ui.bench_progress = -1.0
	ui.hide_actions()
	_bench_shown = false
	var st := restore_st
	restore_st = {}
	var n: Node3D = st["node"]
	if n != null and is_instance_valid(n):
		var tw := create_tween()
		tw.tween_property(n, "global_transform", _seat(n, st["slot"]), 0.6).set_trans(Tween.TRANS_SINE)

## Scrubbing: each stroke over the piece takes some grime off.
func _scrub(motion: Vector2, at: Vector2) -> void:
	var n: Node3D = restore_st["node"]
	if cam.is_position_behind(n.global_position) or cam.unproject_position(n.global_position).distance_to(at) > 220.0:
		return
	var it: Dictionary = restore_st["item"]
	var g := maxf(0.0, float(it.get("grime", 1.0)) - motion.length() * SCRUB_RATE)
	it["grime"] = g
	_grime(n, g)
	if g <= 0.0:
		_restored(restore_st)

## Clean. A genuine piece is worth more; a copy shows what it is.
func _restored(st: Dictionary) -> void:
	var it: Dictionary = st["item"]
	var rec: Dictionary = st.get("record", {})
	if it["fake"]:
		var tell := ""
		for c: Dictionary in it["clues"]:
			if c.get("fake", false):
				tell = String(c["text"])
				if not c["id"] in it["found"]:
					it["found"].append(c["id"])
		_caught_fake(it)
		if rec.has("findings") and tell != "" and not tell in rec["findings"]:
			(rec["findings"] as Array).append(tell)
		ui.toast("Under the grime: %s" % tell)
	else:
		var before := int(it["value"])
		it["value"] = roundi(before * RESTORE_GAIN)
		if rec.has("findings"):
			(rec["findings"] as Array).append("Cleaned and polished on the bench.")
		ui.toast("Clean as the day it was made. The %s should fetch more now." % String(it["name"]).to_lower())
	stop_restore()

# ---- talking ------------------------------------------------------------------------------------------------------------------------

## At the door: "What do you want?" Once per caller. A robber's answer is the tell (no outfit settles it on its own).
func ask_door() -> void:
	if state != "at_door" or visitor.get("asked", false):
		return
	visitor["asked"] = true
	var id: String = visitor["id"]
	var line: String
	if visitor["type"] == "robber":
		line = Dialogue.DOOR["robber"] if id == "robber" else Dialogue.DOOR["robbing_drifter"]
	elif visitor["type"] == "buyer":
		line = Dialogue.DOOR[id]
	else:
		var r := _rec(id).duplicate()
		r["visits"] = int(r["visits"]) + 1
		line = "\"%s\"" % Dialogue.greeting(id, r, town)
	var r2: Dictionary = rep.get(id, {})
	var who := String(visitor["info"]["name"]) if int(r2.get("visits", 0)) > 0 else "Someone at the door"
	ui.say(who, line + "\n" + _memory(id))
	ui.show_door_actions(false)

## True while you can still say something to the seller this visit.
func can_talk() -> bool:
	return state == "talk" and visitor["type"] == "seller" and not visitor.get("talked", false) and Dialogue.SELLERS.has(visitor["id"])

## True once you've found the evidence that the piece on the mat is a copy (and haven't said so yet).
func can_confront() -> bool:
	return state == "talk" and visitor["type"] == "seller" and not visitor.get("confronted", false) and Items.known_fake(item)

## One of the three things you can say to a seller, once a visit.
func talk(kind: String) -> void:
	if not can_talk():
		return
	visitor["talked"] = true
	var id: String = visitor["id"]
	var d: Dictionary = Dialogue.SELLERS[id]
	var info: Dictionary = visitor["info"]
	var line: String
	match kind:
		"friendly":                                      ## warmth: a little more patience, a little more trust
			patience += 1
			_trust(id, 3)
			line = "\"%s\"" % d["friendly"]
		"firm":                                          ## business: they come down a little, and like you a little less
			ask = maxi(int(item["floor"]), roundi(ask * 0.92 / 5.0) * 5)
			_trust(id, -1)
			line = "\"%s %s, then.\"" % [d["firm"], "$%d" % ask]
		_:                                               ## where it came from: a rumour if they trust you, a bristle if not
			var r := _rec(id)
			if int(r["trust"]) >= 55 or int(r["fair_deals"]) >= 1:
				r["rumor_heard"] = true
				line = "\"%s\"" % d["rumor"]
				_note(id, d["rumor"])
			else:
				_trust(id, -2)
				line = "\"%s\"" % d["suspicious"]
	if kind != "firm":
		line += "\nStill asking $%d." % ask                ## the price stays on screen
	_say(info["name"], line)
	ui.show_seller_actions()

## You show the seller what gives the piece away. They take it back and go (whoever fooled them, it wasn't you).
func confront() -> void:
	if not can_confront():
		return
	visitor["confronted"] = true
	var id: String = visitor["id"]
	var info: Dictionary = visitor["info"]
	_caught_fake(item)
	_remember(id, "fake_exposed")
	town["fakes_exposed"] += 1
	_standing(2, "honest_eye")
	_note(id, "Brought in a copy of a %s; you showed them the tell." % String(item["name"]).to_lower())
	_say(info["name"], "\"%s\"" % Dialogue.SELLERS[id]["fake"])
	ui.hide_actions()
	state = "refused"
	get_tree().create_timer(2.8).timeout.connect(func() -> void: _leave(String(info["leave"])))

# ---- the ledger: only what you've found out --------------------------------------------------------------------------------------

## Everyone who has come in: name, how they feel about you, what they've told you.
func ledger_customers() -> Array:
	var out: Array = []
	for id: String in rep.keys():
		var r := _rec(id)
		if int(r["visits"]) == 0:
			continue
		var name: String
		if People.FOLK.has(id):
			name = People.FOLK[id]["name"]
		elif People.BUYERS.has(id):
			name = People.BUYERS[id]["name"]
		else:
			name = People.ROBBERS[id]["name"]
		var facts: Array = ["%d visit%s" % [r["visits"], "" if int(r["visits"]) == 1 else "s"]]
		if People.FOLK.has(id):
			facts.append(Dialogue.trust_word(int(r["trust"])))
			if int(r["fair_deals"]) > 0:
				facts.append("%d fair deal%s" % [r["fair_deals"], "" if int(r["fair_deals"]) == 1 else "s"])
			if int(r["fakes"]) > 0:
				facts.append("brought %d fake%s" % [r["fakes"], "" if int(r["fakes"]) == 1 else "s"])
		if int(r["robbed"]) > 0:
			facts.append("ROBBED THE SHOP")
		if id == "drifter" and r["employed"]:
			facts.append("works at the lodge")
		out.append({"name": name, "facts": ", ".join(facts), "notes": (r["notes"] as Array).duplicate()})
	return out

## Every piece you've bought, what you found on it, and where it went.
func ledger_antiques() -> Array:
	var out: Array = []
	for b: Dictionary in purchases:
		var fate := "on the shelf"
		match String(b["status"]):
			"sold":
				fate = "sold to %s for $%d (%s$%d)" % [b["to"], b["sold_for"], "+" if int(b["sold_for"]) >= int(b["paid"]) else "-", absi(int(b["sold_for"]) - int(b["paid"]))]
			"stolen":
				fate = "stolen"
		out.append({"name": "%s, from %s, day %d: paid $%d" % [b["name"], b["from"], b["day"], b["paid"]], "fate": fate, "findings": b["findings"], "kind": b.get("kind", "")})
	return out

## Each day's books, and today's so far.
func ledger_accounts() -> Array:
	var out: Array = accounts.duplicate()
	if state != "day_end" and state != "over":
		out.append({"day": day, "spent": day_log["spent"], "earned": day_log["earned"], "profit": day_log["profit"], "robbed": day_log["robbed"],
			"bought": day_log["bought"], "sold": day_log["sold"], "money": money, "today": true})
	return out

## How likely the stranger is to come with a gun instead of something to sell: by how far he trusts you, nothing once he has work.
func _drifter_risk() -> float:
	var r := _rec("drifter")
	if r["employed"]:
		return 0.0
	var t := int(r["trust"])
	if t < 30:
		return 0.65
	if t < 45:
		return 0.4
	if t < 60:
		return 0.15
	if t < 75:
		return 0.05
	return 0.0

## True if the buyer `id` collects anything on the shelves right now.
func _wants_any(id: String) -> bool:
	var wanted: Array = People.BUYERS[id]["want"]
	for st: Dictionary in stock:
		if st["item"]["cat"] in wanted:
			return true
	return false

## The town's opinion moves, once per encounter for each kind of reason (`why`).
func _standing(delta: int, why: String) -> void:
	var done: Array = visitor.get("standing", [])
	if why in done:
		return
	done.append(why)
	visitor["standing"] = done
	standing = clampi(standing + delta, 0, 100)

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
	if restoring:
		stop_restore()
	figure.look_at(PORCH + Vector3(0, 0, 1.0), Vector3.UP, true)
	if not People.play(figure, "idle"):
		People.stop(figure)
	ui.bell()
	state = "at_door"
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen_mat.set_shader_parameter("on", 1.0)
	talk_focus = false
	_aim_at(monitor_screen)                                ## turn to the monitor to see who it is
	var id: String = visitor["id"]
	var r: Dictionary = rep.get(id, {})
	var title := String(visitor["info"]["name"]) if int(r.get("visits", 0)) > 0 else "Someone at the door"
	ui.show_door(title, "*Bzzz.*  " + String(People.DOOR_LOOK.get(id, "")), _memory(id), feed.get_texture())
	_tip(1)

## What the shop remembers about a caller, for the camera.
func _memory(id: String) -> String:
	var r: Dictionary = rep.get(id, {})
	if r.is_empty() or int(r.get("visits", 0)) == 0:
		return "Never been in before."
	var lines: Array = ["Been in %d time%s." % [r["visits"], "" if r["visits"] == 1 else "s"]]
	if r["fakes"] > 0:
		lines.append("Brought you %d fake%s." % [r["fakes"], "" if r["fakes"] == 1 else "s"])
	if r["robbed"] > 0:
		lines.append("ROBBED THE SHOP.")
	return "  ".join(lines)

## Everything the shop remembers about one caller. Older records get the new fields filled in (saves, later, merge the same way).
const REC_DEFAULT := {"visits": 0, "fakes": 0, "robbed": 0, "trust": 50, "rejected": 0, "fair_deals": 0, "lowballs": 0,
	"fake_exposed": 0, "last_day": 0, "rumor_heard": false, "paid_total": 0, "employed": false, "notes": []}
var town := {"fakes_exposed": 0, "pell_sales": 0, "jo_sales": 0}    ## the week's story so far, for who says what
var purchases: Array = []                  ## every piece you bought: {"name", "from", "day", "paid", "status", "sold_for", "to", "findings"}
var accounts: Array = []                   ## each closed day's books

func _rec(id: String) -> Dictionary:
	if not rep.has(id):
		rep[id] = REC_DEFAULT.duplicate(true)
	else:
		(rep[id] as Dictionary).merge(REC_DEFAULT.duplicate(true), false)
	return rep[id]

func _remember(id: String, what: String) -> void:
	_rec(id)[what] += 1

func _trust(id: String, d: int) -> void:
	var r := _rec(id)
	r["trust"] = clampi(int(r["trust"]) + d, 0, 100)

## Something a caller told you, kept for the ledger (once).
func _note(id: String, text: String) -> void:
	var notes: Array = _rec(id)["notes"]
	if not text in notes:
		notes.append(text)

func buzz_in() -> void:
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen_mat.set_shader_parameter("on", 0.0)
	_aim_at(Vector3.ZERO)
	ui.hide_feed()
	_remember(visitor["id"], "visits")
	state = "walking"
	_door(true)
	var f := figure
	People.play(f, "walk")
	f.look_at(INSIDE + Vector3(0, 0, 0.001), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(f, "position", Vector3(PORCH.x, 0, -4.0), 1.2)
	tw.tween_callback(func() -> void: People.set_layers(f, 1))
	tw.tween_property(f, "position", INSIDE, 0.6)
	tw.tween_callback(func() -> void: _door(false))
	_walk(tw, f, INSIDE, ROUTE_IN + [Shop.CUSTOMER_SPOT], WALK_SPEED)      ## along the aisle, then straight up to the counter
	tw.tween_callback(_arrived)

func turn_away() -> void:
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen_mat.set_shader_parameter("on", 0.0)
	_aim_at(Vector3.ZERO)
	ui.hide_feed()
	var vid: String = visitor["id"]
	var reject := "You leave the door locked. After a moment they turn and trudge off up the lane."
	if visitor["type"] == "robber":
		reject = "\"Fine. Your loss.\" He trudges off up the lane." if vid == "robber" else "\"All right. I'm going.\" He trudges off up the lane."
	elif Dialogue.SELLERS.has(vid):
		reject = "\"%s\" They trudge off up the lane." % Dialogue.SELLERS[vid]["door_reject"]
		if int(_rec(vid)["robbed"]) == 0:
			_remember(vid, "rejected")
			_trust(vid, -6)
	ui.say(String(visitor["info"]["name"]) if int(_rec(vid)["visits"]) > 0 else "", reject)
	ui.fade_speech(3.5)
	var r: Dictionary = rep.get(String(visitor["id"]), {})
	if visitor["type"] != "robber" and int(r.get("robbed", 0)) == 0 and int(r.get("fakes", 0)) == 0:
		_standing(-2, "refused")
	state = "walking"
	var f := figure
	People.play(f, "walk")
	f.look_at(LANE + Vector3(0, 0, 0.001), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(f, "position", LANE, LANE.distance_to(PORCH) / WALK_SPEED)
	tw.tween_callback(func() -> void: f.look_at(STREET + Vector3(0, 0, 0.001), Vector3.UP, true))
	tw.tween_property(f, "position", STREET, STREET.distance_to(LANE) / WALK_SPEED)
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
	c.fov = 56.0
	var eye := Vector3(PORCH.x + 0.5, 1.85, -4.35)          ## just under the porch roof's beam, beside the door
	c.transform = Transform3D(Basis.looking_at(PORCH + Vector3(0.0, 1.05, 0) - eye), eye)
	feed.add_child(c)
	c.current = true
	_build_monitor()

## The desk on your left behind the counter (Timberline's workbench) with the security monitor on it, its screen showing the porch
## camera. Look at it and the view zooms in to the screen; when someone rings, the view turns to it by itself.
## The monitor is a simple boxy CRT until its Meshy model arrives.
const DESK := Vector3(-1.0, 0.0, 0.24)      ## the monitor's spot on the counter's left wing
const SCREEN_W := 0.655                     ## the porch camera's picture on the Meshy monitor's glass, as shares of the cabinet's size
const SCREEN_H := 0.47
const SCREEN_X := 0.018
const SCREEN_Y := 0.612
var monitor_screen := Vector3.ZERO           ## the middle of the screen, world space
var screen_mat: ShaderMaterial
func _build_monitor() -> void:
	var node: Node3D = shop["node"]
	## (the monitor and the bench sit on the counter's wings now: Shop builds them)
	var mon := Node3D.new()
	mon.name = "Monitor"
	var top := DESK + Vector3(0, Shop.COUNTER_TOP, 0)
	mon.position = top
	var to_eye := SHOP_EYE - top
	mon.rotation.y = atan2(to_eye.x, to_eye.z)             ## its screen faces you behind the counter
	node.add_child(mon)
	var tv := Shop._prop(mon, "shop/monitor", Vector3.ZERO, 0.0, 0.0, 1, Vector3(0.4, 0.0, 0.0))    ## the walnut CRT (Meshy)
	var box := Shop.prop_box(tv) if tv != null else AABB(Vector3(-0.2, 0, -0.15), Vector3(0.4, 0.42, 0.3))
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(box.size.x * SCREEN_W, box.size.y * SCREEN_H)
	q.subdivide_width = 24                                 ## fine enough for the shader to bow the glass into a dome
	q.subdivide_depth = 18
	screen.mesh = q
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/crt_screen.gdshader") as Shader
	screen_mat.set_shader_parameter("feed", feed.get_texture())
	screen_mat.set_shader_parameter("on", 0.0)
	screen.material_override = screen_mat
	screen.position = Vector3(box.get_center().x + box.size.x * SCREEN_X, box.position.y + box.size.y * SCREEN_Y, box.end.z + 0.003)
	mon.add_child(screen)
	monitor_screen = mon.position + mon.basis * screen.position

## The shop's own collection in the glass counter, not for sale: one of each kind of object, the real thing.
var case_decor := {}                       ## the shop's own pieces in the glass case, by spot (a pricey purchase takes their place)
func _decorate() -> void:
	var kinds := Items.KINDS.keys()
	var spots: Array = shop["decor"]
	for i in spots.size():
		var n := Models.build({"kind": kinds[i % kinds.size()], "clues": []})
		var spot: Vector3 = spots[i]
		add_child(n)
		n.global_transform = _seat(n, spot)
		case_decor[spot] = n

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
		var id: String = visitor["id"]
		var r := _rec(id)
		r["last_day"] = day
		var hello := Dialogue.greeting(id, r, town)
		_note(id, hello)
		if id == "drifter" and hello == Dialogue.SELLERS["drifter"]["visits"][3]:
			r["employed"] = true                         ## he has work at the lodge now: no more desperate nights
		_say(info["name"], "%s\n\"I'd want $%d for this %s.\"" % [hello, ask, String(item["name"]).to_lower()])
		state = "talk"
		ui.show_seller_actions()
		if _free_slot() == Vector3.INF:                  ## say so before any haggling: nothing can be bought until a piece sells
			ui.toast("Your shelves are full: you can't buy until something sells.")
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
	_windup()
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
	tw.tween_callback(func() -> void: People.play(f, "run" if hurry else "walk"))
	_walk(tw, f, f.position, ROUTE_OUT, WALK_SPEED / k)                       ## back from the counter and along the aisle
	tw.tween_callback(func() -> void: _door(true))
	_walk(tw, f, ROUTE_OUT[-1], [INSIDE], WALK_SPEED / k)
	tw.tween_interval(0.4 * k)
	tw.tween_callback(func() -> void: People.set_layers(f, 2))
	_walk(tw, f, INSIDE, [PORCH], WALK_SPEED * 1.5 / k)
	tw.tween_callback(func() -> void:
		_door(false)
		ui.fade_speech(2.0))
	_walk(tw, f, PORCH, [LANE, STREET], WALK_SPEED / k)
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
	_rec(visitor["id"])["trust"] = 0
	var take := mini(money, clampi(roundi(money * 0.3 / 5.0) * 5, 60, 150))      ## a bad day, not the end of the shop
	money -= take
	ui.cash(-take)
	day_log["spent"] += take
	day_log["robbed"] += take
	_remember(visitor["id"], "robbed")
	_leave("He stuffs $%d in his coat and is gone." % take, true)

## The alarm under the counter: usually he runs empty-handed, sometimes he grabs the best thing off a shelf first.
func rob_alarm() -> void:
	_rec(visitor["id"])["trust"] = 0
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
	var lost: Dictionary = best.get("record", {})
	lost["status"] = "stolen"
	_leave("%s (The %s.)" % [String(info["grab"]), String(best["item"]["name"]).to_lower()], true)

func _end_day() -> void:
	state = "day_end"
	accounts.append({"day": day, "spent": day_log["spent"], "earned": day_log["earned"], "profit": day_log["profit"], "robbed": day_log["robbed"],
		"bought": day_log["bought"], "sold": day_log["sold"], "money": money})
	if cinematics:
		await _close_shot()
	var books := "Bought %d, sold %d.\nCash out $%d, cash in $%d%s.\nProfit on what you sold: $%d.\nIn the till at closing: $%d.   On the shelves: %d piece%s worth about $%d." % [
		day_log["bought"], day_log["sold"], day_log["spent"], day_log["earned"],
		(" (robbed of $%d)" % day_log["robbed"]) if day_log["robbed"] > 0 else "", day_log["profit"],
		money, stock.size(), "" if stock.size() == 1 else "s", _stock_value()]
	if day == RENT_DAY:
		_ending(books)
		return
	ui.show_summary("Closing time, day %d" % day, books + "\nThe town's opinion of you: %s." % _standing_word(), "Open tomorrow", func() -> void:
		day += 1
		save_game()
		if cinematics:
			ui.veil_to(1.0, 0.5).finished.connect(_open_day)
		else:
			_start_day())

# ---- the day's opening and closing shots ---------------------------------------------------------------------------------------------
## Closing time: from the lane, the camera pulls slowly back from the shop front, the lights inside go down, the OPEN sign flickers
## off, and the picture fades to black. Opening time is the same in reverse at dawn: out of the dark, the sign comes on, the lights
## come up, and the camera moves in toward the door before you're back behind the counter.
var cinematics := true                     ## tests switch the shots off
var cine_cam: Camera3D
var amber: ShaderMaterial                  ## the Winter Amber overlay: eases off while you inspect
const SHOT_NEAR := [Vector3(-1.6, 1.6, -7.4), Vector3(-0.8, 1.5, -4.0)]      ## [eye, looking at]: close in on the door and window
const SHOT_FAR := [Vector3(-2.8, 2.5, -14.5), Vector3(-0.9, 1.8, -4.0)]      ## back across the lane: the shop, pines, the peaks behind

func _shot_pose(a: Array, b: Array, t: float) -> void:
	var eye: Vector3 = (a[0] as Vector3).lerp(b[0], t)
	var at: Vector3 = (a[1] as Vector3).lerp(b[1], t)
	cine_cam.transform = Transform3D(Basis.looking_at(at - eye), eye)

func _shot_begin() -> void:
	ui.set_cinema(true)
	Outside.light_front(true)
	Shop.light_front(shop["node"], true)
	cine_cam.current = true

func _shot_end() -> void:
	cam.current = true
	Outside.light_front(false)
	Shop.light_front(shop["node"], false)
	ui.set_cinema(false)

## The sign flickers, then settles at `k` (0 off, 1 on).
func _sign_flicker(tw: Tween, k: float) -> void:
	var sign: Node3D = shop.get("sign")
	for v: float in [0.5, 0.05, 0.8, 0.1, k]:
		tw.tween_callback(func() -> void: Shop.set_sign(sign, v))
		tw.tween_interval(0.07)

func _close_shot() -> void:
	_shot_begin()
	_shot_pose(SHOT_NEAR, SHOT_FAR, 0.0)
	var move := create_tween()
	move.tween_method(func(t: float) -> void: _shot_pose(SHOT_NEAR, SHOT_FAR, t), 0.0, 1.0, 5.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var beats := create_tween()
	beats.tween_interval(1.6)
	beats.tween_method(func(k: float) -> void: Shop.set_room_lights(shop["node"], k), 1.0, 0.15, 1.1)   ## the lights go down inside
	_sign_flicker(beats, 0.0)
	beats.tween_interval(0.5)
	beats.tween_callback(func() -> void: ui.veil_to(1.0, 1.8))
	await move.finished
	_shot_end()
	ui.veil_to(0.88, 0.3)                                   ## the summary reads over the dark

func _open_day() -> void:
	ui.veil_to(1.0, 0.0)
	day_time = 0.0
	Outside.set_time(0.0)
	Shop.set_sign(shop.get("sign"), 0.0)
	Shop.set_room_lights(shop["node"], 0.15)
	_shot_begin()
	_shot_pose(SHOT_FAR, SHOT_NEAR, 0.0)
	var move := create_tween()
	move.tween_method(func(t: float) -> void: _shot_pose(SHOT_FAR, SHOT_NEAR, t), 0.0, 1.0, 4.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ui.veil_to(0.0, 1.4)
	var beats := create_tween()
	beats.tween_interval(1.5)
	_sign_flicker(beats, 1.0)
	beats.tween_method(func(k: float) -> void: Shop.set_room_lights(shop["node"], k), 0.15, 1.0, 0.8)
	beats.tween_interval(0.5)
	beats.tween_callback(func() -> void: ui.veil_to(1.0, 0.6))
	await move.finished
	_shot_end()
	ui.veil_to(0.0, 0.6)
	_start_day()

# ---- saving: the week is kept between days (user://, the browser's own storage on the web) ---------------------------------------

const SAVE_PATH := "user://week.save"
const SAVE_VERSION := 1
## What a save holds, with the values a new week starts from: an older save missing a field gets it from here.
const SAVE_DEFAULTS := {"version": 1, "day": 1, "money": START_MONEY, "standing": STANDING_START, "week_profit": 0, "rep": {}, "town": {},
	"purchases": [], "accounts": [], "tutorial": -1, "seed": DEFAULT_SEED, "rng_state": 0, "stock": []}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## The day a saved week would continue from (0 if none or unreadable).
func saved_day() -> int:
	var d := _read_save()
	return int(d.get("day", 0))

func delete_save() -> void:
	if has_save():
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(SAVE_PATH.get_file())

## Keeps the week as it stands between days: the money and the town, every caller's memory, the ledger, the shelves, and the dice
## (so tomorrow's callers are the same ones they'd have been). Only in real play: tests and the simulation never touch it.
func save_game() -> void:
	if not cinematics:
		return
	var shelf: Array = []
	for st: Dictionary in stock:
		shelf.append({"item": st["item"], "paid": st["paid"], "record": purchases.find(st.get("record", {}))})
	var data := {"version": SAVE_VERSION, "day": day, "money": money, "standing": standing, "week_profit": week_profit, "rep": rep,
		"town": town, "purchases": purchases, "accounts": accounts, "tutorial": tutorial, "seed": game_seed, "rng_state": rng.state,
		"stock": shelf}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("couldn't save the week: %s" % FileAccess.get_open_error())
		return
	f.store_var(data)
	f.close()

func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	return d if d is Dictionary else {}

## Fills in what an older save didn't have (and refuses one from a newer game than this).
static func migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version", 0)) > SAVE_VERSION:
		return {}
	var out := d.duplicate(true)
	out.merge(SAVE_DEFAULTS.duplicate(true), false)
	for b: Dictionary in out["purchases"]:
		b.merge({"kind": "", "findings": [], "status": "shelf"}, false)
	return out

## Continues a saved week from the start of its next day.
func load_game() -> bool:
	var d := migrate(_read_save())
	if d.is_empty():
		return false
	day = int(d["day"])
	money = int(d["money"])
	standing = int(d["standing"])
	week_profit = int(d["week_profit"])
	rep = d["rep"]
	for id: String in rep.keys():
		_rec(id)                                              ## each caller's record gets any fields it was saved without
	town = d["town"]
	town.merge({"fakes_exposed": 0, "pell_sales": 0, "jo_sales": 0}, false)
	purchases = d["purchases"]
	accounts = d["accounts"]
	tutorial = int(d["tutorial"])
	game_seed = int(d["seed"])
	rng.seed = game_seed
	rng.state = int(d["rng_state"])
	_shown_stock_reset()
	for e: Dictionary in d["stock"]:
		var slot := _free_slot(int(e["paid"]))
		if slot == Vector3.INF:
			break
		var node := Models.build(e["item"])
		add_child(node)
		node.global_transform = _seat(node, slot)
		var ri := int(e.get("record", -1))
		stock.append({"item": e["item"], "paid": int(e["paid"]), "node": node, "slot": slot, "record": purchases[ri] if ri >= 0 and ri < purchases.size() else {}})
		_grime(node, float((e["item"] as Dictionary).get("grime", 0.0)))
	return true

## Clears the shelves (before a saved week's pieces go back on them).
func _shown_stock_reset() -> void:
	for st: Dictionary in stock:
		if st["node"] != null and is_instance_valid(st["node"]):
			(st["node"] as Node3D).queue_free()
	stock.clear()

## How the town speaks of the shop.
func _standing_word() -> String:
	if standing >= 80:
		return "trusted"
	if standing >= STANDING_GOOD:
		return "well liked"
	if standing >= 45:
		return "fair"
	if standing >= 30:
		return "doubtful"
	return "a crook"

## Rent day's close: one of three endings.
func _ending(books: String) -> void:
	state = "over"
	delete_save()
	var week := "\n\nThis week: profit on sales $%d. The town's opinion of you: %s." % [week_profit, _standing_word()]
	if money < RENT:
		ending = "The Last Customer"
		ui.show_summary("The Last Customer", "The rent was $%d and you had $%d. In the morning the landlord changes the locks, and the bell over the door rings for the last time.\n\n" % [RENT, money] + books + week, "Try again", _restart)
		return
	money -= RENT
	if standing >= STANDING_GOOD:
		ending = "A Place in Town"
		ui.show_summary("A Place in Town", "You paid the rent: $%d, and $%d is left in the till. People stop you in the street to ask what you've found this week. Second Hand belongs to Pinecrest now.\n\n" % [RENT, money] + books + week, "Play again", _restart)
	else:
		ending = "Open for Business"
		ui.show_summary("Open for Business", "You paid the rent: $%d, and $%d is left in the till. The shop stays open, for now. The town hasn't made up its mind about you.\n\n" % [RENT, money] + books + week, "Play again", _restart)

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

## Back to the view from behind the counter. The camera eases there by itself (_view, every frame); `instant` puts it there at once.
func _shop_view(instant: bool = false) -> void:
	if instant:
		cam.transform = Transform3D(Basis.looking_at(SHOP_LOOK - SHOP_EYE), SHOP_EYE)
		cam.fov = SHOP_FOV

## The view from behind the counter, each frame: the counter view turned by the player's look-around, or, while a customer is talking,
## turned to their face with a little zoom.
func _view(delta: float) -> void:
	var base := Basis.looking_at(SHOP_LOOK - SHOP_EYE)
	var want := Basis(Vector3.UP, look_yaw) * base * Basis(Vector3.RIGHT, look_pitch)
	var fov := SHOP_FOV
	var rate := LOOK_EASE
	var eye := SHOP_EYE
	var to_mon := (monitor_screen - SHOP_EYE).normalized()
	if not talk_focus and monitor_screen != Vector3.ZERO and (-want.z).angle_to(to_mon) < MONITOR_SNAP:
		# looking at the monitor: lean in and zoom until its screen fills the middle of the view
		eye = SHOP_EYE + to_mon * maxf(0.0, SHOP_EYE.distance_to(monitor_screen) - 0.9)    ## near enough to read, the whole set in view
		want = Basis.looking_at(monitor_screen - Vector3(0, 0.045, 0) - eye)    ## a little low, so the screen sits above the speech box
		fov = 30.0
		rate = TALK_EASE
	elif (not talk_focus or state in ["idle", "walking"]) and (restoring or (-want.z).angle_to((BENCH_SPOT - SHOP_EYE).normalized()) < BENCH_SNAP):
		# looking at the restoration bench: lean over it
		var to_bench := (BENCH_SPOT - SHOP_EYE).normalized()
		eye = SHOP_EYE + to_bench * 0.4
		want = Basis.looking_at(BENCH_SPOT + Vector3(0, -0.02, 0) - eye)
		fov = 42.0
		rate = TALK_EASE
	elif talk_focus and figure != null and is_instance_valid(figure) and figure.global_position.z > -3.9:
		var info: Dictionary = visitor.get("info", {})
		var face := figure.global_position + Vector3(0, float(info.get("height", 1.7)) * 0.9 - 0.08, 0)
		want = Basis.looking_at(face - SHOP_EYE)
		fov = SHOP_FOV * TALK_FOV_SCALE
		rate = TALK_EASE
	var k := 1.0 - exp(-rate * delta)
	cam.transform = Transform3D(cam.transform.basis.slerp(want.orthonormalized(), k).orthonormalized(), cam.position.lerp(eye, k))
	cam.fov = lerpf(cam.fov, fov, k)

func _process(delta: float) -> void:
	Shop.set_clock(shop.get("clock_hands", []), 8.0 + day_time * 12.0)   ## opening at eight, dark by eight
	if amber != null:
		var k: float = amber.get_shader_parameter("inspection")
		amber.set_shader_parameter("inspection", move_toward(k, 1.0 if state in ["inspect", "haggle"] else 0.0, delta * 2.5))
	if state == "inspect" or state == "haggle":
		var dir := Vector3(0, 0.55, 0.85).normalized()
		var target := pivot.global_position
		var want := Transform3D(Basis.looking_at(-dir), target + dir * zoom)
		cam.transform = cam.transform.interpolate_with(want, clampf(delta * 8.0, 0.0, 1.0))
		cam.fov = lerpf(cam.fov, SHOP_FOV, clampf(delta * 8.0, 0.0, 1.0))
	elif state in VIEW_STATES:
		var keys := Vector2(float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)))
		if keys != Vector2.ZERO:
			_look(-keys.x * 1.4 * delta, keys.y * 1.0 * delta)
		else:
			var edge := _edge_look()
			if edge != Vector2.ZERO:
				_look(-edge.x * EDGE_SPEED * delta, -edge.y * EDGE_SPEED * 0.7 * delta)
		_view(delta)
		_bench_offer()
	if restoring:
		ui.bench_progress = 1.0 - float(restore_st["item"].get("grime", 0.0))
	if pivot != null:
		pivot.quaternion = pivot.quaternion.slerp(want_q, clampf(delta * 12.0, 0.0, 1.0))
	if state == "inspect":
		_loupe(delta)
	if figure != null and is_instance_valid(figure) and figure.has_meta("bob") and state in ["talk", "inspect", "haggle", "sell"]:
		figure.position.y = absf(sin(Time.get_ticks_msec() * 0.002)) * 0.01          ## a little breathing bob

## A customer's line in the speech panel; the figure gestures while saying it (when its model has a talking clip).
func _say(who: String, text: String) -> void:
	ui.say(who, text)
	talk_focus = true                                     ## turn to them while they speak (the player can look away again)
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
		if c["id"] in item["found"] or c.get("ear_only", false):    ## (a broken spring is heard, not seen)
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

## How far into the edge band the mouse is, -1..1 on each axis (0 in the middle of the screen, over a button or panel, or outside
## the window), so moving the mouse to the side of the screen turns the view that way, faster the nearer the edge.
func _edge_look() -> Vector2:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	if m.x < 0.0 or m.y < 0.0 or m.x > size.x or m.y > size.y:
		return Vector2.ZERO
	if vp.gui_get_hovered_control() != null:
		return Vector2.ZERO
	var n := m / size
	var e := Vector2.ZERO
	if n.x < EDGE:
		e.x = -(1.0 - n.x / EDGE)
	elif n.x > 1.0 - EDGE:
		e.x = 1.0 - (1.0 - n.x) / EDGE
	if n.y < EDGE:
		e.y = -(1.0 - n.y / EDGE)
	elif n.y > 1.0 - EDGE:
		e.y = 1.0 - (1.0 - n.y) / EDGE
	return e

## Points the look-around at a spot (the monitor), or back to the counter view with Vector3.ZERO.
func _aim_at(p: Vector3) -> void:
	if p == Vector3.ZERO:
		look_yaw = 0.0
		look_pitch = 0.0
		return
	var base := Basis.looking_at(SHOP_LOOK - SHOP_EYE)
	var f := (p - SHOP_EYE).normalized()
	var bf := -base.z
	look_yaw = atan2(-f.x, -f.z) - atan2(-bf.x, -bf.z)
	look_pitch = asin(clampf(f.y, -1.0, 1.0)) - asin(clampf(bf.y, -1.0, 1.0))

## Looking around from behind the counter: turn the view, within what a person turning their head and shoulders could see.
func _look(dyaw: float, dpitch: float) -> void:
	talk_focus = false
	if absf(look_yaw) < 0.001 and absf(look_pitch) < 0.001:
		# starting from the talk framing: continue from where the camera actually points, not jump back to the counter view
		var base := Basis.looking_at(SHOP_LOOK - SHOP_EYE)
		var f := -cam.transform.basis.z
		var bf := -base.z
		look_yaw = atan2(-f.x, -f.z) - atan2(-bf.x, -bf.z)
		look_pitch = asin(clampf(f.y, -1.0, 1.0)) - asin(clampf(bf.y, -1.0, 1.0))
	look_yaw = clampf(wrapf(look_yaw + dyaw, -PI, PI), -1.35, 1.35)
	look_pitch = clampf(look_pitch + dpitch, -0.55, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_E and not state in ["inspect", "haggle"]:
		pull_lamp()
		return
	if restoring:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_scrubbing = (event as InputEventMouseButton).pressed
		elif event is InputEventMouseMotion and _scrubbing:
			_scrub((event as InputEventMouseMotion).relative, (event as InputEventMouseMotion).position)
		return
	if state in VIEW_STATES and event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and _clicked_lamp((event as InputEventMouseButton).position):
		pull_lamp()
		return
	if state in VIEW_STATES:
		return                                            ## looking around is the mouse at the screen's edge (or the keys), not dragging
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
			KEY_E:
				var lv := _living()
				if lv != null:
					lv.toggle()                              ## open or shut every lid and cover
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
			if mb.pressed:
				_press_at = mb.position
			elif mb.position.distance_to(_press_at) < 6.0:
				_click_part(mb.position)                     ## a click, not a drag: open or shut the lid under the mouse
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom - 0.06, 0.28, 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom + 0.06, 0.28, 1.0)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		## left-right spins it like a turntable (around the true vertical, so it never rolls sideways); up-down tips it toward you
		var right := cam.global_transform.basis.x
		want_q = (Quaternion(Vector3.UP, mm.relative.x * 0.008) * Quaternion(right, mm.relative.y * 0.008) * want_q).normalized()

var _press_at := Vector2.ZERO

## The banker's lamp: pull its chain (E, or click the lamp). The chain dips, then springs back with a bounce and a little sway,
## and the lamp clicks on or off: its glow, and the light on the mat.
func pull_lamp() -> void:
	var dl: Dictionary = shop.get("desk_lamp", {})
	var chain: Node3D = dl.get("chain")
	if chain == null or not is_instance_valid(chain) or dl.get("pulling", false):
		return
	dl["pulling"] = true
	if not chain.has_meta("rest"):
		chain.set_meta("rest", chain.position)
	var rest: Vector3 = chain.get_meta("rest")
	var tw := create_tween()
	tw.tween_property(chain, "position", rest + Vector3(0, -0.06, 0), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		dl["on"] = not dl["on"]
		var on: bool = dl["on"]
		(dl["bulb"] as OmniLight3D).light_energy = 0.9 if on else 0.0
		(shop["lamp"] as SpotLight3D).light_energy = 2.5 if on else 0.35)
	tw.tween_property(chain, "position", rest, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: dl["pulling"] = false)
	var sway := create_tween()                                ## and it swings a little as it springs back
	for k in 5:
		var a := 0.35 * pow(0.55, k) * (1.0 if k % 2 == 0 else -1.0)
		sway.tween_property(chain, "rotation:z", a, 0.14).set_trans(Tween.TRANS_SINE)
	sway.tween_property(chain, "rotation:z", 0.0, 0.14).set_trans(Tween.TRANS_SINE)

## True if the mouse is on the banker's lamp (within a hand's width of it on screen).
func _clicked_lamp(mp: Vector2) -> bool:
	var dl: Dictionary = shop.get("desk_lamp", {})
	var lamp: Node3D = dl.get("node")
	if lamp == null or not is_instance_valid(lamp):
		return false
	var at := lamp.global_position + Vector3(0, 0.2, 0)
	if cam.is_position_behind(at):
		return false
	return cam.unproject_position(at).distance_to(mp) < 70.0

const SOUNDS := "res://assets/audio/"

## A wind-up piece on the mat (the music box, the toy car): what winding it sounds like, and what it plays or does. A comb with teeth
## missing drops two notes of the tune; a cheap tin movement plays it thin and buzzy; a broken spring lets the key turn and turn and
## nothing happens. Hearing it is finding it: winding the key finds those clues as surely as the loupe.
func _windup() -> void:
	var lv := _living()
	if lv == null or not lv.has_key():
		return
	var ids: Array = []
	for c: Dictionary in item["clues"]:
		ids.append(String(c["id"]))
		if c.get("part", "") == "tin":
			ids.append("tin")
	lv.works = not "spring" in ids
	lv.wind_sound = load(SOUNDS + ("wind.wav" if lv.works else "wind_slip.wav"))
	var run := "car_run.wav"
	var tail := 0.2
	if item["kind"] == "music_box":
		run = "tune_tin.wav" if "tin" in ids else ("tune_gap.wav" if "comb" in ids else "tune.wav")
		tail = 2.3                                                    ## the last notes ring on after the drum stops
	lv.run_sound = load(SOUNDS + run)
	lv.run_len = maxf(1.0, (lv.run_sound as AudioStream).get_length() - tail)
	lv.wound.connect(func(_runs: bool) -> void: _heard())

## Clues you find by listening (winding the piece on the mat).
func _heard() -> void:
	if item.is_empty() or item_node == null:
		return
	var any := false
	for c: Dictionary in item["clues"]:
		if c.get("heard", false) and not c["id"] in item["found"]:
			item["found"].append(c["id"])
			ui.found_clue(c)
			any = true
			if c.get("fake", false):
				_caught_fake(item)
	if any:
		ui.refresh_inspect(item)

## The piece's moving parts, if it has any.
func _living() -> Living:
	if item_node == null or not is_instance_valid(item_node):
		return null
	return item_node.get_node_or_null("Living") as Living

## Opens or shuts the lid (or the watch's cover) the mouse is on.
func _click_part(mp: Vector2) -> void:
	var lv := _living()
	if lv == null:
		return
	var from := cam.project_ray_origin(mp)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(mp) * 3.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var body := hit["collider"] as CollisionObject3D
	var owner_id := body.shape_find_owner(int(hit["shape"]))
	var pname := Living.part_of(body.shape_owner_get_owner(owner_id) as Node)
	if pname != "":
		lv.toggle(pname)

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
		if not "lowball" in visitor.get("standing", []):
			_remember(visitor["id"], "lowballs")
			_trust(visitor["id"], -5)
		_standing(-4, "lowball")
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
		if ask <= floor_p and Dialogue.SELLERS.has(visitor["id"]):
			_say(info["name"], "\"" + String(Dialogue.SELLERS[visitor["id"]]["final"]) % ("$%d" % ask) + "\"")
		else:
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
	if _free_slot(price) == Vector3.INF:
		ui.toast("Your shelves are full. Sell something first.")
		return
	var info: Dictionary = visitor["info"]
	money -= price
	if not "lowball" in visitor.get("standing", []):
		_standing(2, "fair")
		_remember(visitor["id"], "fair_deals")
		_trust(visitor["id"], 4)
	_rec(visitor["id"])["paid_total"] += price
	var found: Array = []
	for c: Dictionary in item["clues"]:
		if c["id"] in item["found"]:
			found.append(String(c["text"]))
	var bought := {"name": String(item["name"]), "kind": String(item["kind"]), "from": String(info["name"]), "day": day, "paid": price, "status": "shelf", "findings": found}
	purchases.append(bought)
	day_log["bought"] += 1
	day_log["spent"] += price
	ui.cash(-price)
	# the object goes onto a shelf
	var slot := _free_slot(price)
	var n := item_node
	item_node = null
	if slot != Vector3.INF and n != null:
		var g := n.global_transform
		n.get_parent().remove_child(n)
		add_child(n)
		n.global_transform = g
		create_tween().tween_property(n, "global_transform", _seat(n, slot), 0.6).set_trans(Tween.TRANS_SINE)
	if not item.has("grime"):
		item["grime"] = 1.0                                  ## straight out of an attic: it wants a clean
	stock.append({"item": item, "paid": price, "node": n, "slot": slot, "record": bought})
	_grime(n, float(item["grime"]))
	pivot.scale = Vector3.ONE
	_leave(info["accept"])

const PRICEY := 150                        ## pay this much or more and the piece goes in the glass case, not on a shelf

## Where a bought piece goes: a pricey one into the glass case (taking the place of one of the shop's own pieces there) while there's
## room, everything else on the shelves.
func _free_slot(price: int = 0) -> Vector3:
	if price >= PRICEY:
		for spot: Vector3 in shop["decor"]:
			var taken := false
			for st: Dictionary in stock:
				if st["slot"] == spot:
					taken = true
			if not taken:
				var d: Node3D = case_decor.get(spot)
				if d != null and is_instance_valid(d):
					d.queue_free()                            ## the shop's own piece makes way
				case_decor.erase(spot)
				return spot
	return _free_shelf()

## How a piece sits at `slot`: upright, facing into the room (from a side wall's shelves) or out to the customers (in the case),
## its base resting on the surface, slightly smaller than in the hand.
func _seat(n: Node3D, slot: Vector3) -> Transform3D:
	var yaw := PI                                         ## in the case: facing the customers
	if slot.x < -2.0:
		yaw = PI * 0.5                                    ## left wall's shelves: facing into the room
	elif slot.x > 2.0:
		yaw = -PI * 0.5
	var sc := 0.78 if slot in shop["decor"] else 0.9
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).has_meta("clue"):
			continue
		var b := Models._rel(n, mi as Node3D) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sc)
	var centre := basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return Transform3D(basis, slot + Vector3(0, 0.004, 0) - centre)

func _free_shelf() -> Vector3:
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
	var hello := Dialogue.greeting(visitor["id"], _rec(visitor["id"]), town)
	_note(visitor["id"], hello)
	if choices.is_empty():
		_say(info["name"], "%s\n%s" % [hello, Dialogue.BUYERS[visitor["id"]]["empty"]])
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _leave("Maybe next time."))
		return
	_say(info["name"], "%s\nWhat have you got?" % hello)
	ui.show_present_choices(choices)

## You choose which piece to show the buyer (they never pick by its hidden value). An expert sees through a copy every time;
## an amateur only sometimes. Otherwise they make an offer from what the piece really is.
func present(st: Dictionary) -> void:
	var info: Dictionary = visitor["info"]
	var it: Dictionary = st["item"]
	if it["fake"] and rng.randf() < float(info.get("eye", 1.0)):
		state = "refused"                                ## no sale can go through while they say so and leave
		if Items.known_fake(it):
			_standing(-8, "fraud")                       ## you had found its tell, and offered it anyway
		_caught_fake(it)
		_say(info["name"], "That %s... %s" % [String(it["name"]).to_lower(), info["fake"]])
		var seen: Array = visitor.get("seen", [])
		seen.append(st)
		visitor["seen"] = seen
		if visitor.get("many", false) and not _rent_choices().is_empty():
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _offer_more("\"Show me something else.\""))
			return                                       ## rent day: they turn that one down, not the whole shop
		get_tree().create_timer(3.5).timeout.connect(func() -> void: _leave("Good day."))
		return
	visitor["deal"] = st
	var worth := float(it["value"]) if not it["fake"] else float(it["base"])     ## a copy that fools them is priced as a plain example
	var good_name := 1.0 + float(standing - STANDING_START) / 500.0
	if visitor.get("many", false):
		good_name *= 0.9                                 ## rent day: they know you need the money
	ask = maxi(5, roundi(worth * float(info["pays"]) * good_name * rng.randf_range(0.85, 1.05) / 5.0) * 5)
	patience = int(info["patience"])
	_say(info["name"], "\"I'll give you $%d for the %s.\" (You paid $%d.)" % [ask, String(it["name"]).to_lower(), st["paid"]])
	ui.show_buyer_actions(ask)

func sell_accept() -> void:
	var deal: Dictionary = visitor["deal"]
	money += ask
	day_log["sold"] += 1
	day_log["earned"] += ask
	day_log["profit"] += ask - int(deal["paid"])
	var sold: Dictionary = deal.get("record", {})
	sold["status"] = "sold"
	sold["sold_for"] = ask
	sold["to"] = String(visitor["info"]["name"])
	town["pell_sales" if visitor["id"] == "collector_b" else "jo_sales"] += 1
	week_profit += ask - int(deal["paid"])
	ui.cash(ask)
	if deal["node"] != null and is_instance_valid(deal["node"]):
		(deal["node"] as Node3D).queue_free()
	stock.erase(deal)
	visitor.erase("deal")
	visitor["bought"] = int(visitor.get("bought", 0)) + 1
	if visitor.get("many", false) and int(visitor.get("bought", 0)) < RENT_DAY_PIECES and not _rent_choices().is_empty():
		_offer_more("\"Good. What else have you got?\"")
		return
	_leave("A pleasure doing business.")

## Rent day: the buyer would look at something else, if you have it.
func _offer_more(line: String) -> void:
	var info: Dictionary = visitor["info"]
	state = "sell"
	visitor["round"] = int(visitor.get("round", 0)) + 1
	_say(info["name"], line)
	ui.show_present_choices(_rent_choices())

## What a rent-day buyer would still look at: pieces they collect that they haven't already turned down.
func _rent_choices() -> Array:
	var info: Dictionary = visitor["info"]
	var seen: Array = visitor.get("seen", [])
	var out: Array = []
	for st: Dictionary in stock:
		if st["item"]["cat"] in info["want"] and not st in seen:
			out.append(st)
	return out

func sell_push() -> void:
	var info: Dictionary = visitor["info"]
	patience -= 1
	if rng.randf() < 0.55 and patience > 0:
		ask = roundi(ask * 1.12 / 5.0) * 5
		_say(info["name"], "\"All right. $%d, and not a cent more.\"" % ask)
		ui.show_buyer_actions(ask)
	else:
		_leave("Then I'll look elsewhere.")
