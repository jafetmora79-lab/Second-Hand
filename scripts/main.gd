extends Node3D
## Second Hand: the day in the shop.
## Customers come in one at a time. A seller puts their object on the mat: inspect it (drag to turn, scroll to zoom, hold the loupe over details to find
## clues), then make an offer and haggle, or send them away. A buyer looks over your shelves and makes you an offer for what they like.
## Rent is due on day 7.

const START_MONEY := 500
const RENT := 600
const RENT_DAY := 7
const LOUPE_DWELL := 0.45                  ## seconds the loupe must rest on a detail to read it
const LOUPE_REACH := 0.032                 ## metres from a clue's spot that still counts
const ZOOM_READ := 0.62                    ## the camera must be at least this close to read a detail

var rng := RandomNumberGenerator.new()
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
var day_log := {"bought": 0, "sold": 0, "spent": 0, "earned": 0}
var shelf_slots: Array = []

func _ready() -> void:
	rng.seed = 2026
	shop = Shop.build(self)
	shelf_slots = shop["shelves"]
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

# ---- the day -----------------------------------------------------------------------------------------------------------------------

func _start_day() -> void:
	day_log = {"bought": 0, "sold": 0, "spent": 0, "earned": 0}
	queue.clear()
	var sellers := ["trapper", "widow", "kid", "collector", "drifter"]
	sellers.shuffle()
	for i in mini(2 + mini(day, 3), sellers.size()):
		queue.append({"type": "seller", "id": sellers[i]})
	if day >= 1:
		var b: String = ["collector_b", "decorator"][day % 2]
		queue.insert(mini(2, queue.size()), {"type": "buyer", "id": b})
		if day >= 3:
			queue.append({"type": "buyer", "id": ["collector_b", "decorator"][(day + 1) % 2]})
	ui.show_day_title("Day %d" % day, "Rent of $%d due on day %d" % [RENT, RENT_DAY] if day < RENT_DAY else "Rent is due tonight: $%d" % RENT)
	state = "idle"
	get_tree().create_timer(2.2).timeout.connect(_next_visitor)

func _next_visitor() -> void:
	if queue.is_empty():
		_end_day()
		return
	visitor = queue.pop_front()
	var info: Dictionary = People.FOLK[visitor["id"]] if visitor["type"] == "seller" else People.BUYERS[visitor["id"]]
	visitor["info"] = info
	figure = People.figure(info, visitor["id"])
	figure.position = Shop.DOOR + Vector3(0, 0, 0.3)
	add_child(figure)
	ui.bell()
	state = "walking"
	var tw := create_tween()
	tw.tween_property(figure, "position", Vector3(Shop.DOOR.x, 0, -2.6), 0.9)
	tw.tween_property(figure, "position", Shop.CUSTOMER_SPOT, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_arrived)

func _arrived() -> void:
	var info: Dictionary = visitor["info"]
	if visitor["type"] == "seller":
		var kinds := Items.KINDS.keys()
		var kind: String = kinds[rng.randi() % kinds.size()]
		var fake_chance := 0.45 if visitor["id"] == "drifter" else (0.25 if visitor["id"] == "collector" else 0.12)
		item = Items.make(kind, rng, fake_chance)
		item["seller"] = visitor["id"]
		_place_item()
		var belief := float(info["belief"]) * (float(item["value"]) if not item["fake"] else float(Items.KINDS[kind]["base"]) * 1.3)
		ask = maxi(5, roundi(belief * 1.25 / 5.0) * 5)
		item["floor"] = maxi(3, roundi(belief * float(info["floor"])))
		patience = int(info["patience"])
		var hello: Array = info["hello"]
		ui.say(info["name"], "%s\n\"I'd want $%d for this %s.\"" % [hello[rng.randi() % hello.size()], ask, String(item["name"]).to_lower()])
		state = "talk"
		ui.show_seller_actions()
	else:
		_buyer_arrived(info)

func _place_item() -> void:
	if item_node != null:
		item_node.queue_free()
	pivot.basis = Basis(Vector3.UP, rng.randf_range(-0.6, 0.6))
	item_node = Models.build(item)
	pivot.add_child(item_node)
	pivot.position = Shop.MAT + Vector3(0, 0.15, 0)
	pivot.scale = Vector3.ONE * 0.01
	create_tween().tween_property(pivot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _leave(text: String) -> void:
	var info: Dictionary = visitor["info"]
	ui.say(info["name"], text)
	ui.hide_actions()
	state = "walking"
	if item_node != null and visitor["type"] == "seller":
		var n := item_node
		item_node = null
		create_tween().tween_property(pivot, "scale", Vector3.ONE * 0.01, 0.25).finished.connect(n.queue_free)
	_shop_view()
	var f := figure
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(f, "position", Vector3(Shop.DOOR.x, 0, -2.6), 1.3)
	tw.tween_property(f, "position", Shop.DOOR + Vector3(0, 0, -0.2), 0.8)
	tw.tween_callback(func() -> void:
		f.queue_free()
		ui.bell()
		item = {}
		get_tree().create_timer(1.0).timeout.connect(_next_visitor))

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
	ui.show_inspect(item)

func stop_inspect() -> void:
	state = "talk"
	_shop_view()
	ui.show_seller_actions()

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
	if state == "inspect":
		_loupe(delta)
	if figure != null and is_instance_valid(figure) and state in ["talk", "inspect", "haggle", "sell"]:
		figure.position.y = absf(sin(Time.get_ticks_msec() * 0.002)) * 0.01          ## a little breathing bob

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
		ui.refresh_inspect(item)

func _unhandled_input(event: InputEvent) -> void:
	if state != "inspect" and state != "haggle":
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
		var up := cam.global_transform.basis.y
		var right := cam.global_transform.basis.x
		pivot.global_transform.basis = (Basis(up, mm.relative.x * 0.01) * Basis(right, mm.relative.y * 0.01) * pivot.global_transform.basis).orthonormalized()

# ---- haggling ----------------------------------------------------------------------------------------------------------------------

func start_haggle() -> void:
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
		ui.say(info["name"], info["insult"])
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
		ui.say(info["name"], String(info["counter"]) % ("$%d" % ask))
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
	var best: Dictionary = {}
	for st: Dictionary in stock:
		if st["item"]["cat"] in wanted and (best.is_empty() or int(st["item"]["value"]) > int(best["item"]["value"])):
			best = st
	if best.is_empty():
		ui.say(info["name"], "%s\nHm. Nothing here for me today." % info["hello"])
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _leave("Maybe next time."))
		return
	visitor["deal"] = best
	if best["item"]["fake"]:
		ui.say(info["name"], "%s\nThat %s... %s" % [info["hello"], String(best["item"]["name"]).to_lower(), info["fake"]])
		get_tree().create_timer(3.5).timeout.connect(func() -> void: _leave("Good day."))
		return
	ask = roundi(float(best["item"]["value"]) * float(info["pays"]) * rng.randf_range(0.85, 1.05) / 5.0) * 5
	patience = int(info["patience"])
	ui.say(info["name"], "%s\n\"I'll give you $%d for the %s.\" (You paid $%d.)" % [info["hello"], ask, String(best["item"]["name"]).to_lower(), best["paid"]])
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
		ui.say(info["name"], "\"All right. $%d, and not a cent more.\"" % ask)
		ui.show_buyer_actions(ask)
	else:
		_leave("Then I'll look elsewhere.")
