extends RefCounted
class_name Shop
## The shop: a warm little room with plank walls and floor, the counter you stand behind with a velvet mat and a brass lamp on it, shelves of stock,
## a frosted window with snow falling outside, and the door with its bell. You stand at z = 0 looking toward -z; customers come in from the door and
## stop across the counter.

const COUNTER_Z := -0.62
const COUNTER_TOP := 1.0                   ## the glass counter's top, 2.4 m wide
const WING_X := 1.0                        ## the counter's side wings (a U round you): their middles, either side of you
const WING_Z := 0.22
const WING_LEN := 0.88
const MAT := Vector3(0.0, 1.025, -0.57)    ## the velvet mat, on the U counter's front section (z -0.72..-0.42)
const CUSTOMER_SPOT := Vector3(0.0, 0.0, -1.45)
const DOOR := Vector3(-2.2, 0.0, -3.9)
const DOOR_W := 0.92                       ## the opening in the kit's doorway wall, at 3 m wide and 2.95 m tall
const DOOR_H := 2.38

static func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

## A one-sided dark plane facing into the room (yaw 0 faces +z): it fills the chinks between logs seen from inside, and is invisible outside.
static func _backing(root: Node3D, pos: Vector3, size: Vector2, yaw: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)

static func _box(root: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)
	return mi

static func build(root: Node3D) -> Dictionary:
	var shop := Node3D.new()
	shop.name = "Shop"
	root.add_child(shop)
	var dark := _mat(Color(0.25, 0.17, 0.11))
	var trim := _mat(Color(0.3, 0.2, 0.13))
	# room: 6 m wide, 5 m deep, 2.9 m high, built from Timberline's house kit (assets/kit)
	for fx: float in [-1.5, 1.5]:                              ## plank floor
		for fz: float in [-2.75, -0.25]:
			_kit(shop, "HK_floor_finished", Vector3(fx, -0.06, fz), 0.0, Vector3(3.02, 0.06, 2.52))
	for fx: float in [-1.5, 1.5]:                              ## plank ceiling: the kit's floorboards, face down
		for fz: float in [-2.75, -0.25]:
			var c := _kit(shop, "HK_floor_finished", Vector3(fx, 2.96, fz), 0.0, Vector3(3.02, 0.06, 2.52))
			if c != null:
				c.rotation.x = PI
	_box(shop, Vector3(0, 3.0, -1.5), Vector3(6.4, 0.06, 5.4), dark)          ## the roof boards above it, so no sky shows between planks
	# behind every wall, a dark backing: the rounded logs and the joints between kit pieces never show daylight
	# (one-sided planes facing into the room: from outside they vanish and the logs' own outer face shows)
	var back := _mat(Color(0.16, 0.11, 0.08))
	_backing(shop, Vector3(-3.16, 1.45, -1.5), Vector2(5.4, 3.0), PI * 0.5, back)
	_backing(shop, Vector3(3.16, 1.45, -1.5), Vector2(5.4, 3.0), -PI * 0.5, back)
	_backing(shop, Vector3(0, 1.45, 1.16), Vector2(6.4, 3.0), PI, back)
	_backing(shop, Vector3(-0.72, 1.45, -4.16), Vector2(2.04, 3.0), 0.0, back)                  ## back wall, round the door and the window
	_backing(shop, Vector3(-2.91, 1.45, -4.16), Vector2(0.5, 3.0), 0.0, back)
	_backing(shop, Vector3(DOOR.x, 2.7, -4.16), Vector2(DOOR_W + 0.1, 0.6), 0.0, back)
	_backing(shop, Vector3(2.83, 1.45, -4.16), Vector2(0.66, 3.0), 0.0, back)
	_backing(shop, Vector3(1.4, 0.43, -4.16), Vector2(2.2, 0.86), 0.0, back)
	_backing(shop, Vector3(1.4, 2.62, -4.16), Vector2(2.2, 0.77), 0.0, back)
	# the back wall: the doorway wall round the door, and the shop-window wall round the big window (opening about x 0.3..2.5, y 0.87..2.23)
	_kit(shop, "HK_wall_door", Vector3(DOOR.x, -0.05, -4.0), 0.0, Vector3(3.0, 2.95, 0.2))
	_kit(shop, "HK_wall_shop", Vector3(1.4, -0.05, -4.02), 0.0, Vector3(3.86, 2.95, 0.2))
	# side walls and the wall behind you: log walls with plank wainscot
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.75, -0.25]:
			_kit(shop, "HK_wall_interior", Vector3(side * 3.0, -0.05, z), -side * PI * 0.5, Vector3(2.52, 2.95, 0.2))
	for x: float in [-1.5, 1.5]:
		_kit(shop, "HK_wall_interior", Vector3(x, -0.05, 1.0), PI, Vector3(3.02, 2.95, 0.2))
	# beams
	for z in [-3.0, -1.5, 0.0]:
		for x: float in [-2.0, 0.0, 2.0]:
			if _prop(shop, "shop/beam", Vector3(x, 2.7, z), 0.0, 0.0, 1, Vector3(2.02, 0.2, 0.22)) == null:
				_box(shop, Vector3(x, 2.8, z), Vector3(2.0, 0.16, 0.18), dark)
	# posts: over the joint in the back wall and in the four corners
	for p: Vector3 in [Vector3(-0.53, 0, -3.84), Vector3(-2.82, 0, -3.84), Vector3(2.82, 0, -3.84), Vector3(-2.82, 0, 0.82), Vector3(2.82, 0, 0.82)]:
		var wide := 0.46 if p.x == -0.53 else 0.3                ## the joint in the back wall is wider than a corner: cover it all
		if _prop(shop, "shop/post", p, 0.0, 0.0, 1, Vector3(wide, 2.95, 0.28)) == null:
			_box(shop, p + Vector3(0, 1.425, 0), Vector3(0.3, 2.95, 0.3), dark)
	# the counter: a pawn-shop glass case with security screens (Meshy), the shop's own collection inside, the velvet mat on top
	var case_spots := _glass_counter(shop)
	# the counter's two wings coming back toward you, a U round where you stand (Timberline's plain counter, the same height as the
	# glass case): the security monitor on the left wing, the restoration bench on the right
	## (the U counter's own arms are the wings now: see _glass_counter)
	_box(shop, Vector3(0, COUNTER_TOP + 0.006, MAT.z), Vector3(0.46, 0.01, 0.24), _mat(Color(0.32, 0.08, 0.1), 0.95))       ## the velvet mat
	# the warm light on the mat, from your right so nothing stands between you and the customer; a wall lantern by the window
	_prop(shop, "shop/HK_lantern", Vector3(0.05, 1.75, -3.72), 0.36, -PI * 0.5)       ## plate on the back wall beside the window
	for side: float in [-1.0, 1.0]:                                                     ## one on each side wall, by the counter
		_prop(shop, "shop/HK_lantern", Vector3(side * 2.7, 1.85, -0.55), 0.4, 0.0 if side < 0.0 else PI)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.3, COUNTER_TOP + 0.5, MAT.z + 0.05)
	lamp.rotation = Vector3(-PI * 0.5, 0, 0.45)
	lamp.spot_angle = 38.0
	lamp.spot_range = 2.0
	lamp.light_energy = 2.5
	lamp.light_color = Color(1.0, 0.94, 0.83)
	lamp.shadow_enabled = true
	shop.add_child(lamp)
	var room_light := OmniLight3D.new()
	room_light.position = Vector3(0, 2.5, -1.8)
	room_light.omni_range = 7.0
	room_light.light_energy = 0.85
	room_light.light_color = Color(1.0, 0.86, 0.70)
	shop.add_child(room_light)
	# strings of warm bulbs slung under the beams (Timberline's string lights), in place of a lantern hanging in mid-air
	for z: float in [-3.0, -1.5]:
		for x: float in [-2.0, 0.0, 2.0]:
			_prop(shop, "shop/HK_string_lights", Vector3(x, 2.4, z), 0.0, 0.0, 1, Vector3(1.9, 0.0, 0.0))
	# glass in the shop window: you see the town through it (Outside builds the view), cold light coming in
	var glass := _mat(Color(0.8, 0.88, 0.95, 0.05), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.8
	_box(shop, Vector3(1.4, 1.55, -4.05), Vector3(2.3, 1.45, 0.01), glass)
	var cold := OmniLight3D.new()
	cold.position = Vector3(1.4, 1.6, -3.3)
	cold.omni_range = 3.5
	cold.light_energy = 0.85
	cold.light_color = Color(0.65, 0.80, 1.0)
	shop.add_child(cold)
	# the electric door (Timberline's shop door): hinged on its left, swings in when you buzz someone through
	var hinge := Node3D.new()
	hinge.name = "Door"
	hinge.position = Vector3(DOOR.x - DOOR_W * 0.5, 0, -4.0)
	shop.add_child(hinge)
	if _kit(hinge, "HK_door_shop", Vector3(DOOR_W * 0.5, 0, 0), 0.0, Vector3(DOOR_W, DOOR_H, 0.08)) == null:
		_box(hinge, Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0), Vector3(DOOR_W, DOOR_H, 0.06), _mat(Color(0.33, 0.2, 0.12)))
	# the OPEN sign hanging in the door's window, facing the street (from inside you see its back); it lights up while the shop is open
	var sign := _prop(hinge, "shop/HK_open_sign", Vector3(DOOR_W * 0.5, 1.48, -0.055), 0.24, PI)
	if sign != null:
		for mi in sign.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var base := m.get_active_material(0) as StandardMaterial3D
			if base != null:
				m.material_override = base.duplicate()          ## its own copy, so switching it off dims only this sign
		var glow := OmniLight3D.new()                         ## the neon's red glow on the porch while the shop is open
		glow.name = "Glow"
		glow.light_color = Color(1.0, 0.25, 0.2)
		glow.omni_range = 1.4
		glow.light_energy = 0.7
		glow.light_cull_mask = 2
		glow.position = Vector3(0, 0.1, -0.3)
		sign.add_child(glow)
	var buzzer := _box(shop, Vector3(DOOR.x + DOOR_W * 0.5 + 0.2, 1.2, -3.88), Vector3(0.1, 0.16, 0.04), _mat(Color(0.2, 0.2, 0.22), 0.5, 0.5))   ## the lock box
	var lock_led := _box(buzzer, Vector3(0, 0.05, 0.025), Vector3(0.025, 0.025, 0.01), _mat(Color(0.9, 0.1, 0.08)))
	(lock_led.material_override as StandardMaterial3D).emission_enabled = true
	(lock_led.material_override as StandardMaterial3D).emission = Color(1.0, 0.1, 0.05)
	# a shelving unit on each side wall (Meshy), four shelves of stock each
	var shelves: Array = []
	for side: float in [-1.0, 1.0]:
		_prop(shop, "shop/shelves", Vector3(side * 2.6, 0, -2.1), 2.3, side * -PI * 0.5)
	for y: float in [0.81, 1.28, 1.73, 0.29]:                ## eye level first, then the top, then the bottom
		for dz: float in [0.0, -0.55, 0.55]:
			for side: float in [-1.0, 1.0]:                  ## left and right in turn
				shelves.append(Vector3(side * 2.58, y, -2.1 + dz))
	# a wood stove in the corner (Timberline's), glowing, a log pile by it
	if _prop(shop, "shop/FURN_stove", Vector3(-0.77, 0, -3.55), 1.0, STOVE_YAW) == null:
		_box(shop, Vector3(-0.77, 0.45, -3.55), Vector3(0.6, 0.9, 0.6), _mat(Color(0.1, 0.1, 0.11), 0.6, 0.4))
	_prop(shop, "shop/HK_log_pile", Vector3(-0.08, 0, -3.62), 0.42, 0.1)
	_prop(shop, "shop/bench", Vector3(1.4, 0, -3.66), 0.0, 0.0, 1, Vector3(1.6, 0.0, 0.0))        ## a low bench under the window
	var stove_light := OmniLight3D.new()
	stove_light.position = Vector3(-0.77, 0.6, -3.1)
	stove_light.omni_range = 2.6
	stove_light.light_color = Color(1.0, 0.55, 0.25)
	stove_light.light_energy = 0.9
	shop.add_child(stove_light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.48)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Outside.sky_env(env)
	Outside.build(root)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_dress(shop)
	var props := _furnish(shop)
	return {"node": shop, "shelves": shelves, "decor": case_spots, "lamp": lamp, "door": hinge, "lock_led": lock_led, "sign": sign,
		"desk_lamp": props["desk_lamp"], "clock_hands": props["clock_hands"]}

## A prop's bounding box in its parent's space (for placing things on its face: the clock's hands, the monitor's screen).
static func prop_box(holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var b := Models._rel(holder.get_parent(), mi as Node3D) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## The Meshy props made from the user's images: the banker's lamp and the ledger on the counter, the wall clock, the rug.
## Returns the lamp (its chain and light, for the pull cord) and the clock's hands (the game sets the time).
static func _furnish(shop: Node3D) -> Dictionary:
	# the rug where customers stand (the user's woven rug, a flat texture: no model needed)
	var rug := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.8, 1.8)
	rug.mesh = pm
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load("res://assets/shop/rug.png") as Texture2D
	rm.roughness = 1.0
	rug.material_override = rm
	rug.position = Vector3(0, 0.008, -2.3)
	shop.add_child(rug)
	# the ledger, open on the counter left of the mat
	_prop(shop, "shop/ledger", Vector3(-0.6, COUNTER_TOP, -0.57), 0.0, 0.12, 1, Vector3(0.24, 0.0, 0.0))
	# the banker's lamp right of the mat: its pull chain is a separate part (tools/split_props.py) so it can be pulled
	var lamp := _prop(shop, "shop/bankers_lamp_parts", Vector3(0.62, COUNTER_TOP, -0.55), 0.3, -0.45)
	var chain: Node3D = null
	if lamp != null:
		chain = lamp.find_child("Chain", true, false) as Node3D
	var bulb := OmniLight3D.new()                                ## the glow under the green shade
	bulb.light_color = Color(1.0, 0.9, 0.7)
	bulb.light_energy = 0.9
	bulb.omni_range = 1.1
	bulb.position = Vector3(0.58, COUNTER_TOP + 0.19, -0.52)
	shop.add_child(bulb)
	# the wall clock on the back wall, between the door and the stove; hands drawn on its blank dial
	var hands: Array = []
	var clock := _prop(shop, "shop/wall_clock", Vector3(-1.25, 1.42, -3.8), 0.78, 0.0)
	if clock != null:
		var box := prop_box(clock)
		var dial := Vector3(box.get_center().x, box.position.y + box.size.y * 0.635, box.end.z + 0.004)
		var ink := _mat(Color(0.12, 0.09, 0.07), 0.6)
		for spec: Array in [[0.05, 0.007], [0.072, 0.005]]:      ## hour hand, minute hand
			var pivot := Node3D.new()
			pivot.position = dial
			shop.add_child(pivot)
			var hand := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(spec[1], spec[0], 0.003)
			hand.mesh = bm
			hand.material_override = ink
			hand.position = Vector3(0, spec[0] * 0.4, 0)          ## turns about its tail end, near the dial's middle
			pivot.add_child(hand)
			hands.append(pivot)
	return {"desk_lamp": {"node": lamp, "chain": chain, "bulb": bulb, "on": true}, "clock_hands": hands}

## The clock's hands at `hours` (0..24).
static func set_clock(hands: Array, hours: float) -> void:
	if hands.size() < 2:
		return
	(hands[0] as Node3D).rotation.z = -fmod(hours, 12.0) / 12.0 * TAU
	(hands[1] as Node3D).rotation.z = -fmod(hours, 1.0) * TAU

## The OPEN sign's glow, 0 (switched off: a dull board) to 1 (lit).
static func set_sign(sign: Node3D, k: float) -> void:
	if sign == null:
		return
	for mi in sign.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.3, 0.3, 0.33).lerp(Color.WHITE, k)
	var glow := sign.get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_energy = 0.7 * k

## The lights inside the shop (on layer 1), turned down to `k` of their full strength: closing time.
static func set_room_lights(shop_node: Node3D, k: float) -> void:
	for l in shop_node.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if light.light_cull_mask & 1 == 0 or light.has_meta("outdoor"):
			continue                                         ## the porch lamp outside stays on
		if not light.has_meta("full"):
			light.set_meta("full", light.light_energy)
		light.light_energy = float(light.get_meta("full")) * k

## While the camera is outside (the day's opening and closing shots), the outdoor lights also light the shop's own walls.
static func light_front(shop_node: Node3D, on: bool) -> void:
	for l in shop_node.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if light.has_meta("outdoor") or (light.light_cull_mask & 2 != 0 and light.light_cull_mask != 0xFFFFF):
			light.set_meta("outdoor", true)
			light.light_cull_mask = (light.light_cull_mask | 1) if on else (light.light_cull_mask & ~1)

## Loads a model from assets/<file>.glb, scales it to `h` tall (or into `fit_box` when given), stands it on the floor at `pos`, turned `yaw`.
## The heights of the four shelves in the shelving unit when it stands 2.3 m tall (measured off the model).
const SHELF_Y := [0.29, 0.81, 1.28, 1.73]
const STOVE_YAW := 0.0                     ## the stove's door faces the room

## The Meshy glass counter, 2.4 m wide, its paned front toward the customer and its security screens on their side of the mat.
## Its glass is made see-through by a shader (shaders/glass_case.gdshader). Returns the spots inside the case for the shop's collection.
static func _glass_counter(shop: Node3D) -> Array:
	var spots: Array = []
	if ResourceLoader.exists("res://assets/shop/counter_u.glb"):
		return _u_counter(shop)
	var n := _prop(shop, "shop/counter_glass", Vector3(0, 0, COUNTER_Z), 0.0, PI, 1, Vector3(2.4, 0, 0))
	if n == null:
		_kit(shop, "HK_counter", Vector3(0, 0, COUNTER_Z), 0.0, Vector3(2.4, COUNTER_TOP, 0.8))
		return spots
	var sh := load("res://shaders/glass_case.gdshader") as Shader
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as BaseMaterial3D
			var g := ShaderMaterial.new()
			g.shader = sh
			if src != null:
				g.set_shader_parameter("tex", src.albedo_texture)
			m.set_surface_override_material(i, g)
	for x: float in [-0.95, -0.65, -0.35, 0.35, 0.65, 0.95]:
		spots.append(Vector3(x, 0.56, COUNTER_Z - 0.08))
	return spots

## The U-shaped counter (Meshy, from the user's image): the glass case in front of you, an arm either side coming back toward you
## (the monitor on the left arm, the restoration bench on the right). Its painted glass is made see-through and its security screens
## squashed below the eye line by the glass_case shader. Returns the spots inside the case for the shop's own collection.
const U_SIZE := Vector3(2.6, 1.541, 1.6)    ## fitted so its countertop is at COUNTER_TOP
const U_Z := 0.06
static func _u_counter(shop: Node3D) -> Array:
	var n := _prop(shop, "shop/counter_u", Vector3(0, 0, U_Z), 0.0, 0.0, 1, U_SIZE)
	var sh := load("res://shaders/glass_case.gdshader") as Shader
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as BaseMaterial3D
			var g := ShaderMaterial.new()
			g.shader = sh
			if src != null:
				g.set_shader_parameter("tex", src.albedo_texture)
			g.set_shader_parameter("top_y", Vector2(0.035, 0.085))            ## the front case's top is glass either side of the mat
			g.set_shader_parameter("top_rect", Vector4(-0.47, -0.49, 0.47, -0.27))
			g.set_shader_parameter("top_gap", 0.1)
			g.set_shader_parameter("staff_doors", true)                     ## from your side: wood and sliding doors
			g.set_shader_parameter("screen_base", 0.075)        ## just above its countertop (model space)
			m.set_surface_override_material(i, g)
	var spots: Array = []
	for x: float in [-0.85, -0.55, -0.25, 0.25, 0.55, 0.85]:     ## on the case's floor (measured at 0.49 m), under the glass top
		spots.append(Vector3(x, 0.49, -0.57))
	return spots

## A Timberline house-kit piece (assets/kit), stretched to `size` (x along it, y up, z through it), bottom at pos.y, centred on pos.
## A kit piece on a given render layer (the outside one for buildings in the town), toned like the shop's.
static func _kit_layer(root: Node3D, piece: String, pos: Vector3, yaw: float, size: Vector3, layer: int) -> Node3D:
	var n := _prop(root, "kit/" + piece, pos, 0.0, yaw, layer, size)
	_grade(n, KIT_GRADE)
	return n

static func _kit(root: Node3D, piece: String, pos: Vector3, yaw: float, size: Vector3) -> Node3D:
	var n := _prop(root, "kit/" + piece, pos, 0.0, yaw, 1, size)
	_grade(n, KIT_GRADE)
	return n

## The kit's logs and planks are a loud orange; inside the lamp-lit shop they are toned down to aged wood (a multiply on each material's colour).
const KIT_GRADE := Color(0.6, 0.57, 0.54)
static var _graded := {}

static func _grade(n: Node, tint: Color) -> void:
	if n == null:
		return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if not (mat is BaseMaterial3D):
				continue
			if not _graded.has(mat):                   ## one graded copy per kit material, shared by every piece that uses it
				var g := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				g.albedo_color = g.albedo_color * tint
				_graded[mat] = g
			m.set_surface_override_material(i, _graded[mat])

static func _prop(root: Node3D, file: String, pos: Vector3, h: float, yaw: float = 0.0, layer: int = 1, fit_box: Vector3 = Vector3.ZERO) -> Node3D:
	var path := "res://assets/%s.glb" % file
	if not ResourceLoader.exists(path):
		return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.layers = layer
		var b := Models._rel(m, inst) * inst.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	if fit_box != Vector3.ZERO:
		var k := Vector3(fit_box.x / maxf(box.size.x, 0.001), fit_box.y / maxf(box.size.y, 0.001), fit_box.z / maxf(box.size.z, 0.001))
		var keep := maxf(k.x, maxf(k.y, k.z))
		for a in 3:                                    ## an axis left at 0 keeps the proportion of the others
			if fit_box[a] <= 0.0:
				k[a] = keep
		holder.scale = k
	else:
		holder.scale = Vector3.ONE * h / maxf(box.size.y, 0.001)
	m.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	holder.add_child(m)
	root.add_child(holder)
	return holder

## Furnishes the shop with Timberline's own props: a barrel of odds and ends, an axe; outside, steps,
## a mailbox and a lantern by the door.
static func _dress(shop: Node3D) -> void:
	_prop(shop, "shop/HK_barrel_crate", Vector3(2.55, 0, -0.85), 0.8, 0.4)
	_prop(shop, "shop/TOOL_axe", Vector3(2.85, 0, -0.55), 0.85, 0.3)
	# a pitched roof like the town's cabins (Timberline's roof section and log gables), sitting on the walls; the plank ceiling hides it inside
	var span := 6.0
	var rise := span * 0.38
	_kit_layer(shop, "HK_roof_section", Vector3(0, 2.62, -1.5), PI * 0.5, Vector3(span, rise, 6.8), 2)
	for gs: float in [-1.0, 1.0]:
		_kit_layer(shop, "HK_gable", Vector3(gs * 3.02, 2.64, -1.5), gs * PI * 0.5, Vector3(span - 0.12, rise - 0.02, 0.4), 2)
	# outside the door
	_kit_layer(shop, "HK_porch", Vector3(DOOR.x, -0.2, -5.25), PI, Vector3(2.6, 2.75, 2.3), 2)      ## a covered porch at the door, its deck level with the floor
	_prop(shop, "shop/HK_mailbox", Vector3(DOOR.x - 1.0, 0, -4.7), 1.1, PI, 2)
	_prop(shop, "shop/HK_lantern", Vector3(DOOR.x + 0.75, 1.75, -4.12), 0.32, PI, 2)
	var porch := OmniLight3D.new()                                   ## the porch lamp: lights whoever is waiting outside (outside layer only)
	porch.position = Vector3(DOOR.x + 0.7, 1.9, -4.6)
	porch.omni_range = 3.5
	porch.light_energy = 1.2
	porch.light_color = Color(1.0, 0.82, 0.55)
	porch.light_cull_mask = 2
	shop.add_child(porch)
