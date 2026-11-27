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
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = ShopUi.new()
	ui.game = self
	layer.add_child(ui)
	cine_cam = Camera3D.new()
	cine_cam.fov = 50.0
	add_child(cine_cam)
	if cinematics:
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
	if day >= 2 and rng.randf() < 0.4:                 ## from day 2, trouble: a masked man, or the stranger turned bad
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
	ui.say("", "You leave the door locked. After a moment they turn and trudge off up the lane.")
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
const DESK := Vector3(-1.78, 0.0, -0.72)
var monitor_screen := Vector3.ZERO           ## the middle of the screen, world space
var screen_mat: ShaderMaterial
func _build_monitor() -> void:
	var node: Node3D = shop["node"]
	Shop._kit(node, "HK_workbench", DESK, PI * 0.5, Vector3(1.15, 0.78, 0.62))
	var mon := Node3D.new()
	mon.name = "Monitor"
	var top := DESK + Vector3(0, 0.79, 0)
	mon.position = top
	var to_eye := SHOP_EYE - top
	mon.rotation.y = atan2(to_eye.x, to_eye.z)             ## its screen faces you behind the counter
	node.add_child(mon)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.58, 0.5, 0.38)
	shell.roughness = 0.55
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.08)
	dark.roughness = 0.4
	Shop._box(mon, Vector3(0, 0.16, -0.02), Vector3(0.36, 0.3, 0.3), shell)          ## the cabinet
	Shop._box(mon, Vector3(0, 0.17, 0.132), Vector3(0.3, 0.23, 0.012), dark)         ## the bezel
	Shop._box(mon, Vector3(0.13, 0.04, 0.135), Vector3(0.05, 0.025, 0.01), dark)     ## a knob strip
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.195)
	screen.mesh = q
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/crt_screen.gdshader") as Shader
	screen_mat.set_shader_parameter("feed", feed.get_texture())
	screen_mat.set_shader_parameter("on", 0.0)
	screen.material_override = screen_mat
	screen.position = Vector3(0, 0.17, 0.14)
	mon.add_child(screen)
	monitor_screen = mon.position + mon.basis * screen.position

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
	var take := mini(money, clampi(roundi(money * 0.3 / 5.0) * 5, 60, 150))      ## a bad day, not the end of the shop
	money -= take
	ui.cash(-take)
	day_log["spent"] += take
	day_log["robbed"] += take
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
		eye = SHOP_EYE + to_mon * 0.85
		want = Basis.looking_at(monitor_screen - Vector3(0, 0.045, 0) - eye)    ## a little low, so the screen sits above the speech box
		fov = 21.0
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
	if not "lowball" in visitor.get("standing", []):
		_standing(2, "fair")
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
