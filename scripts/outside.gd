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
	# the snowfield, in Timberline's pixel snow
	var snow := StandardMaterial3D.new()
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
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.84, 0.9)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
