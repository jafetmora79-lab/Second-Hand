extends RefCounted
class_name Shop
## The shop: a warm little room with plank walls and floor, the counter you stand behind with a velvet mat and a brass lamp on it, shelves of stock,
## a frosted window with snow falling outside, and the door with its bell. You stand at z = 0 looking toward -z; customers come in from the door and
## stop across the counter.

const COUNTER_Z := -0.62
const COUNTER_TOP := 0.96
const MAT := Vector3(0.0, 0.985, -0.5)
const CUSTOMER_SPOT := Vector3(0.0, 0.0, -1.45)
const DOOR := Vector3(-2.2, 0.0, -3.9)

static func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

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
	var plank := _mat(Color(0.42, 0.29, 0.19))
	var dark := _mat(Color(0.25, 0.17, 0.11))
	var wall := _mat(Color(0.55, 0.42, 0.3))
	var trim := _mat(Color(0.3, 0.2, 0.13))
	# room: 6 m wide, 5 m deep, 2.9 m high
	_box(shop, Vector3(0, -0.05, -1.5), Vector3(6.0, 0.1, 5.0), plank)
	_box(shop, Vector3(0, 2.95, -1.5), Vector3(6.0, 0.1, 5.0), dark)
	# the back wall, built round the window opening (x 0.3..2.5, y 0.9..2.4) so you can see out
	_box(shop, Vector3(-1.35, 1.45, -4.0), Vector3(3.3, 2.9, 0.1), wall)
	_box(shop, Vector3(2.75, 1.45, -4.0), Vector3(0.5, 2.9, 0.1), wall)
	_box(shop, Vector3(1.4, 0.45, -4.0), Vector3(2.2, 0.9, 0.1), wall)
	_box(shop, Vector3(1.4, 2.65, -4.0), Vector3(2.2, 0.5, 0.1), wall)
	_box(shop, Vector3(-3.0, 1.45, -1.5), Vector3(0.1, 2.9, 5.0), wall)
	_box(shop, Vector3(3.0, 1.45, -1.5), Vector3(0.1, 2.9, 5.0), wall)
	_box(shop, Vector3(0, 1.45, 1.0), Vector3(6.0, 2.9, 0.1), wall)
	for x in range(-5, 6):                                    ## floor board seams
		_box(shop, Vector3(x * 0.55, 0.002, -1.5), Vector3(0.02, 0.004, 5.0), dark)
	for y in [0.5, 1.0, 1.5, 2.0, 2.5]:                       ## wall plank seams (stopping at the window)
		if y > 0.85 and y < 2.45:
			_box(shop, Vector3(-1.35, y, -3.94), Vector3(3.3, 0.02, 0.01), trim)
			_box(shop, Vector3(2.75, y, -3.94), Vector3(0.5, 0.02, 0.01), trim)
		else:
			_box(shop, Vector3(0, y, -3.94), Vector3(6.0, 0.02, 0.01), trim)
	_box(shop, Vector3(0, 2.85, -3.93), Vector3(6.0, 0.12, 0.06), trim)
	# beams
	for z in [-3.0, -1.5, 0.0]:
		_box(shop, Vector3(0, 2.8, z), Vector3(6.0, 0.16, 0.18), dark)
	# the counter
	_box(shop, Vector3(0, COUNTER_TOP * 0.5, COUNTER_Z), Vector3(2.6, COUNTER_TOP, 0.6), trim)
	_box(shop, Vector3(0, COUNTER_TOP + 0.02, COUNTER_Z), Vector3(2.7, 0.04, 0.68), _mat(Color(0.5, 0.33, 0.2), 0.55))
	_box(shop, Vector3(0, COUNTER_TOP + 0.045, MAT.z), Vector3(0.62, 0.01, 0.42), _mat(Color(0.32, 0.08, 0.1), 0.95))       ## the velvet mat
	# the cash register and a ledger
	_box(shop, Vector3(0.95, COUNTER_TOP + 0.14, COUNTER_Z + 0.05), Vector3(0.36, 0.24, 0.3), _mat(Color(0.55, 0.42, 0.2), 0.35, 0.7))
	_box(shop, Vector3(-0.9, COUNTER_TOP + 0.05, COUNTER_Z + 0.1), Vector3(0.32, 0.04, 0.24), _mat(Color(0.35, 0.12, 0.1)))
	# the lamp over the mat: a brass arm and a green shade, and the light it throws
	# (beside the mat on your right, low, so it never stands between you and the customer)
	_box(shop, Vector3(0.62, COUNTER_TOP + 0.2, MAT.z + 0.05), Vector3(0.03, 0.4, 0.03), _mat(Color(0.75, 0.58, 0.28), 0.35, 0.8))
	_box(shop, Vector3(0.5, COUNTER_TOP + 0.39, MAT.z + 0.05), Vector3(0.26, 0.03, 0.03), _mat(Color(0.75, 0.58, 0.28), 0.35, 0.8))
	var shade := _box(shop, Vector3(0.38, COUNTER_TOP + 0.36, MAT.z + 0.05), Vector3(0.16, 0.07, 0.13), _mat(Color(0.15, 0.35, 0.22), 0.5))
	shade.rotation.z = -0.35
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.3, COUNTER_TOP + 0.5, MAT.z + 0.05)
	lamp.rotation = Vector3(-PI * 0.5, 0, 0.45)
	lamp.spot_angle = 38.0
	lamp.spot_range = 2.0
	lamp.light_energy = 2.2
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.shadow_enabled = true
	shop.add_child(lamp)
	var room_light := OmniLight3D.new()
	room_light.position = Vector3(0, 2.5, -1.8)
	room_light.omni_range = 7.0
	room_light.light_energy = 1.0
	room_light.light_color = Color(1.0, 0.82, 0.6)
	shop.add_child(room_light)
	var bulb_m := _mat(Color(1.0, 0.85, 0.6))
	bulb_m.emission_enabled = true
	bulb_m.emission = Color(1.0, 0.8, 0.55)
	bulb_m.emission_energy_multiplier = 1.5
	_box(shop, Vector3(0, 2.62, -1.8), Vector3(0.3, 0.2, 0.3), bulb_m)
	# the window on the back wall: old glass you can see the town through (Outside builds the view), cold light coming in
	var glass := _mat(Color(0.8, 0.88, 0.95, 0.05), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.8
	_box(shop, Vector3(1.4, 1.65, -3.97), Vector3(2.2, 1.5, 0.01), glass)
	var wm := _mat(Color(0.7, 0.8, 0.95), 0.2)                ## the door's frosted pane
	wm.emission_enabled = true
	wm.emission = Color(0.55, 0.66, 0.85)
	wm.emission_energy_multiplier = 0.9
	# frost creeping in from the corners of the glass
	var frost := _mat(Color(0.92, 0.95, 1.0, 0.55), 0.6)
	frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for c: Vector2 in [Vector2(0.42, 0.95), Vector2(2.38, 0.95), Vector2(1.4, 0.93)]:
		_box(shop, Vector3(c.x, c.y, -3.955), Vector3(0.24 if c.x != 1.4 else 2.2, 0.07, 0.005), frost)
	for k in 3:
		_box(shop, Vector3(1.4 + (k - 1) * 0.73, 1.65, -3.94), Vector3(0.05, 1.5, 0.04), trim)
	_box(shop, Vector3(1.4, 1.65, -3.94), Vector3(2.2, 0.05, 0.04), trim)
	_box(shop, Vector3(1.4, 0.88, -3.9), Vector3(2.3, 0.06, 0.16), trim)
	for x in [0.3, 2.5]:                                       ## the frame round the opening
		_box(shop, Vector3(x, 1.65, -3.94), Vector3(0.08, 1.58, 0.08), trim)
	_box(shop, Vector3(1.4, 2.42, -3.94), Vector3(2.28, 0.08, 0.08), trim)
	var cold := OmniLight3D.new()
	cold.position = Vector3(1.4, 1.6, -3.3)
	cold.omni_range = 3.5
	cold.light_energy = 0.6
	cold.light_color = Color(0.6, 0.72, 1.0)
	shop.add_child(cold)
	# the door with its bell
	_box(shop, Vector3(DOOR.x, 1.05, -3.94), Vector3(1.0, 2.1, 0.06), _mat(Color(0.33, 0.2, 0.12)))
	_box(shop, Vector3(DOOR.x, 1.5, -3.9), Vector3(0.5, 0.6, 0.02), wm)
	_box(shop, Vector3(DOOR.x + 0.38, 1.0, -3.89), Vector3(0.05, 0.05, 0.05), _mat(Color(0.75, 0.58, 0.28), 0.35, 0.8))
	# shelves along the side walls, with stock
	var shelves: Array = []
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var y := 0.55 + k * 0.5
			_box(shop, Vector3(side * 2.78, y, -2.1), Vector3(0.4, 0.04, 2.4), trim)
			for s in 4:
				shelves.append(Vector3(side * 2.75, y + 0.03, -3.0 + s * 0.6))
		_box(shop, Vector3(side * 2.78, 1.3, -0.88), Vector3(0.42, 2.2, 0.06), trim)
		_box(shop, Vector3(side * 2.78, 1.3, -3.32), Vector3(0.42, 2.2, 0.06), trim)
	# a stove in the corner, glowing
	_box(shop, Vector3(-2.4, 0.45, 0.4), Vector3(0.6, 0.9, 0.6), _mat(Color(0.1, 0.1, 0.11), 0.6, 0.4))
	var fire := _box(shop, Vector3(-2.4, 0.4, 0.1), Vector3(0.3, 0.22, 0.02), _mat(Color(1.0, 0.5, 0.2)))
	(fire.material_override as StandardMaterial3D).emission_enabled = true
	(fire.material_override as StandardMaterial3D).emission = Color(1.0, 0.45, 0.15)
	(fire.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0
	var stove_light := OmniLight3D.new()
	stove_light.position = Vector3(-2.3, 0.6, -0.1)
	stove_light.omni_range = 2.5
	stove_light.light_color = Color(1.0, 0.55, 0.25)
	stove_light.light_energy = 0.8
	shop.add_child(stove_light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.48)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Outside.sky_env(env)
	Outside.build(root)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	return {"node": shop, "shelves": shelves, "lamp": lamp, "fire": fire}
