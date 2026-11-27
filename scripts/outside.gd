extends RefCounted
class_name Outside
## What you see through the shop window: the snowed-in mountain town of Timberline. A snowfield, a cottage across the lane, pines,
## the big Meshy peaks far off in the haze, a winter sky and snow falling past the glass. Models come from Timberline (assets/outside).
## Everything out here is on render layer 2, lit by its own cold sun that never reaches inside the shop.
##
## From behind the counter (eye at 0, 1.62, 0.35) the window (x 0.3..2.5, y 0.9..2.4, z -4) looks out toward +x, -z,
## about one metre right for every three metres out, so the view is built along that line.

const LAYER := 2
const DIR := "res://assets/outside/%s.glb"

## Loads a model, scales it so it is `h` tall, stands it on the ground at `pos`, turned `yaw`, on the outside layer.
static func _place(root: Node3D, file: String, pos: Vector3, h: float, yaw: float = 0.0, stretch: Vector3 = Vector3.ONE) -> Node3D:
	var path := DIR % file
	if not ResourceLoader.exists(path):
		return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.layers = LAYER
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var b := inst.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := h / maxf(box.size.y, 0.001)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = stretch * s
	m.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	holder.add_child(m)
	root.add_child(holder)
	return holder

static func _mesh(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

static func build(root: Node3D) -> Node3D:
	var out := Node3D.new()
	out.name = "Outside"
	root.add_child(out)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	# the cold sun, only for the outside layer
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, 0.9, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(0.92, 0.95, 1.0)
	sun.light_cull_mask = LAYER
	sun.shadow_enabled = false
	out.add_child(sun)
	_sun = sun
	# the snowfield, in Timberline's pixel snow
	var snow := StandardMaterial3D.new()
	_snow = snow
	snow.albedo_color = Color(0.93, 0.95, 1.0)
	snow.roughness = 0.95
	var tex := load("res://assets/outside/T_snow_pixel.png") as Texture2D
	if tex != null:
		snow.albedo_texture = tex
		snow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		snow.uv1_triplanar = true
		snow.uv1_world_triplanar = true
		snow.uv1_scale = Vector3.ONE * 0.25
	var ground := PlaneMesh.new()
	ground.size = Vector2(900, 700)
	_mesh(out, ground, Vector3(120, 0, -354.2), snow)
	# the lane past the shop: trodden snow, a little greyer
	var lane_m := snow.duplicate() as StandardMaterial3D
	_lane = lane_m
	lane_m.albedo_color = Color(0.78, 0.8, 0.86)
	var lane := PlaneMesh.new()
	lane.size = Vector2(120, 3.2)
	_mesh(out, lane, Vector3(10, 0.01, -7.6), lane_m)
	# across the lane: a cottage, and a fence along it
	_place(out, "HOUSE_cottage", Vector3(5.0, 0, -44.0), 6.2, -0.6)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.21, 0.15)
	var post := BoxMesh.new()
	post.size = Vector3(0.1, 0.9, 0.1)
	var rail := BoxMesh.new()
	rail.size = Vector3(2.0, 0.07, 0.05)
	for k in 9:
		var x := -1.0 + k * 2.0
		_mesh(out, post, Vector3(x, 0.45, -9.6), wood)
		if k < 8:
			_mesh(out, rail, Vector3(x + 1.0, 0.7, -9.6), wood)
			_mesh(out, rail, Vector3(x + 1.0, 0.35, -9.6), wood)
	# pines: a few close ones by the lane, then the forest getting thicker toward the hills
	for p: Vector3 in [Vector3(1.2, 0, -11.5), Vector3(11.5, 0, -12.5), Vector3(-1.5, 0, -18.0), Vector3(14.0, 0, -20.0)]:
		_place(out, "TREE_meshy_pine", p, rng.randf_range(6.5, 9.0), rng.randf() * TAU)
	for i in 80:                                               ## either side of the line of sight, leaving a clear way to the peaks
		var z := -rng.randf_range(28.0, 140.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := absf(z) * (0.33 + side * rng.randf_range(0.1, 0.55))
		_place(out, "TREE_meshy_pine", Vector3(x, 0, z), rng.randf_range(7.0, 13.0), rng.randf() * TAU)
	for i in 7:
		_place(out, "PL_snowbush", Vector3(rng.randf_range(-2.0, 16.0), 0, -rng.randf_range(10.5, 22.0)), rng.randf_range(0.4, 0.8), rng.randf() * TAU)
	# the mountains, far off: Timberline's Meshy peaks, wide and tall enough to fill the top of the window
	## low enough that their tops sit inside the window (from the counter it shows up to ~0.18 rad above eye level), wide like a range
	var peaks := [
		["MTN_peak_1", Vector3(95, -2, -300), 30.0, 0.4, Vector3(3.2, 1, 2.4)],
		["MTN_peak_0", Vector3(150, -2, -390), 38.0, 2.1, Vector3(3.4, 1, 2.6)],
		["MTN_peak_2", Vector3(40, -2, -350), 26.0, 4.0, Vector3(3.4, 1, 2.6)],
		["MTN_peak_3", Vector3(215, -2, -330), 28.0, 1.0, Vector3(3.2, 1, 2.6)],
		["MTN_peak_0", Vector3(-30, -2, -420), 34.0, 5.3, Vector3(3.4, 1, 2.6)],
	]
	for p: Array in peaks:
		_place(out, p[0], p[1], p[2], p[3], p[4])
	# snow falling past the window
	var flakes := CPUParticles3D.new()
	flakes.amount = 420
	flakes.lifetime = 6.0
	flakes.preprocess = 6.0
	flakes.position = Vector3(3.5, 6.0, -10.5)
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(7.0, 0.5, 5.0)          ## z -15.5..-5.5: never drifts in through the wall
	flakes.direction = Vector3(0.25, -1, 0)
	flakes.spread = 12.0
	flakes.gravity = Vector3(0, -0.4, 0)
	flakes.initial_velocity_min = 0.7
	flakes.initial_velocity_max = 1.2
	flakes.local_coords = false
	var flake := QuadMesh.new()
	flake.size = Vector2(0.035, 0.035)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1, 1, 1, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = fm
	flakes.mesh = flake
	flakes.layers = LAYER
	out.add_child(flakes)
	return out

## The winter sky behind it all, with haze that swallows the far peaks a little. Applied to the shop's environment
## (inside, the walls hide the sky and the fog is too thin over a few metres to notice).
static func sky_env(env: Environment) -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.5, 0.6, 0.75)
	sm.sky_horizon_color = Color(0.82, 0.85, 0.9)
	sm.ground_horizon_color = Color(0.82, 0.85, 0.9)
	sm.ground_bottom_color = Color(0.7, 0.72, 0.78)
	sm.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sm
	_sky = sm
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.84, 0.9)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0

# ---- time of day --------------------------------------------------------------------------------------------------------------------

static var _sun: DirectionalLight3D
static var _sky: ProceduralSkyMaterial
static var _env: Environment
static var _snow: StandardMaterial3D
static var _lane: StandardMaterial3D

## The look of the sky at four times of day: morning, midday, sunset, night. Each: sky top, horizon, sun colour, sun energy, sun height (radians
## below level: the light's x rotation), sun bearing, snow brightness, ambient energy. set_time() blends between neighbours.
const TIMES := [
	{"name": "Morning", "top": Color(0.48, 0.6, 0.82), "horizon": Color(0.98, 0.82, 0.72), "sun": Color(1.0, 0.82, 0.66), "energy": 0.85, "pitch": -0.22, "yaw": 2.3, "snow": 0.95, "ambient": 0.35},
	{"name": "Midday", "top": Color(0.36, 0.56, 0.88), "horizon": Color(0.84, 0.9, 0.96), "sun": Color(1.0, 0.98, 0.94), "energy": 1.25, "pitch": -0.95, "yaw": 0.9, "snow": 1.0, "ambient": 0.38},
	{"name": "Sunset", "top": Color(0.3, 0.3, 0.55), "horizon": Color(1.0, 0.52, 0.3), "sun": Color(1.0, 0.5, 0.28), "energy": 0.75, "pitch": -0.1, "yaw": -0.5, "snow": 0.8, "ambient": 0.3},
	{"name": "Night", "top": Color(0.015, 0.02, 0.06), "horizon": Color(0.06, 0.08, 0.16), "sun": Color(0.55, 0.65, 0.95), "energy": 0.28, "pitch": -0.85, "yaw": 1.4, "snow": 0.38, "ambient": 0.22},
]

## t from 0 (morning) to 1 (night), in thirds: 0 morning, 1/3 midday, 2/3 sunset, 1 night.
static func set_time(t: float) -> void:
	if _sky == null:
		return
	t = clampf(t, 0.0, 1.0) * 3.0
	var i := mini(int(t), 2)
	var f := t - float(i)
	var a: Dictionary = TIMES[i]
	var b: Dictionary = TIMES[i + 1]
	_sky.sky_top_color = (a["top"] as Color).lerp(b["top"], f)
	_sky.sky_horizon_color = (a["horizon"] as Color).lerp(b["horizon"], f)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = _sky.sky_horizon_color.darkened(0.2)
	_env.fog_light_color = _sky.sky_horizon_color
	_env.ambient_light_energy = lerpf(a["ambient"], b["ambient"], f)
	_sun.light_color = (a["sun"] as Color).lerp(b["sun"], f)
	_sun.light_energy = lerpf(a["energy"], b["energy"], f)
	_sun.rotation = Vector3(lerpf(a["pitch"], b["pitch"], f), lerp_angle(a["yaw"], b["yaw"], f), 0)
	var k := lerpf(a["snow"], b["snow"], f)
	_snow.albedo_color = Color(0.93, 0.95, 1.0) * k
	_lane.albedo_color = Color(0.78, 0.8, 0.86) * k

static func time_name(t: float) -> String:
	return String(TIMES[clampi(roundi(clampf(t, 0.0, 1.0) * 3.0), 0, 3)]["name"])

# ---- animals ------------------------------------------------------------------------------------------------------------------------

## Who might wander past the window: model, height, speed (m/s), and whether it flies.
const ANIMALS := [
	["ANI_rabbit", 0.35, 2.2, false],
	["ANI_rabbit", 0.3, 1.8, false],
	["wolf_standing", 0.85, 1.6, false],
	["polar_bear_animated", 1.3, 1.1, false],
	["ANI_raven", 0.35, 4.5, true],
]

## Sends one animal across the view from the window, from one side to the other, then removes it. Out at 9..22 m, along the line of sight.
static func spawn_animal(root: Node3D, rng: RandomNumberGenerator) -> void:
	var a: Array = ANIMALS[rng.randi() % ANIMALS.size()]
	var z := -rng.randf_range(9.0, 22.0)
	var mid := absf(z) * 0.32                                  ## the middle of the window's view at that distance
	var half := absf(z) * 0.3 + 3.0
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var y := rng.randf_range(2.5, 5.0) if a[3] else 0.0
	var from := Vector3(mid - dir * half, y, z)
	var to := Vector3(mid + dir * half, y, z + rng.randf_range(-3.0, 3.0))
	var n := _place(root, String(a[0]), from, float(a[1]))
	if n == null:
		return
	n.look_at(to + Vector3(0, 0, 0.001), Vector3.UP, true)
	People.play(n, "walk" if not a[3] else "fly")
	var secs := from.distance_to(to) / float(a[2])
	var tw := n.create_tween()
	tw.tween_property(n, "position:x", to.x, secs)
	tw.parallel().tween_property(n, "position:z", to.z, secs)
	tw.tween_callback(n.queue_free)
	if a[3]:                                                  ## a raven flaps: a gentle rise and fall
		var bob := n.create_tween().set_loops(int(secs / 0.6) + 1)
		bob.tween_property(n, "position:y", 0.25, 0.3).as_relative().set_trans(Tween.TRANS_SINE)
		bob.tween_property(n, "position:y", -0.25, 0.3).as_relative().set_trans(Tween.TRANS_SINE)
