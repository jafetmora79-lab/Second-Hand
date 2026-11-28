extends Node
class_name Living
## The moving parts of a piece on the mat (from tools/split_items.py: <kind>_parts.glb and .json):
## - hinges (the music box's lid, the compass's lid, the pocket watch's cover) open and close when you click them or press E;
##   The same blend moves parts with no hinge: the coffee grinder's drawer slides, the kettle's lid lifts and tips, and the spyglass's
##   cap comes off its chain and fits over the lens (it turns, shrinks to the lens and swings over in a small arc on the way);
## - a chain (the watch's) hangs from its top link and swings as you turn the piece: it lags behind the turn, then settles back
##   toward hanging straight down, never swinging further than a real chain could from where it lies.
## Each part's collision shape follows it, so the loupe and clicks always meet the part where you see it.

const HINGE_TIME := 0.55                   ## seconds to swing a lid fully open or shut
const CHAIN_PULL := 18.0                   ## how strongly the chain falls back toward hanging down
const CHAIN_DAMP := 2.0                    ## how quickly its swing dies away
const CHAIN_LAG := 0.82                    ## how much of the piece's turn the chain resists, each frame (1 = it stays put in the world)
const CHAIN_REACH := 1.15                  ## the furthest (radians) it may swing from where it lay in the model
const WIND_TIME := 1.4                     ## seconds to wind a key
const WIND_TURNS := 2.5                    ## how far round it goes
const DRUM_SPEED := 1.6                    ## a music box's brass drum, radians a second while it plays
const WHEEL_SPEED := 22.0                  ## a toy car's wheels, radians a second while it runs

## Wind-up pieces (the music box, the toy car): click the key (or press E on a piece with nothing to open) and it winds; then, if the
## spring and the works are sound, the piece runs: the drum turns and the tune plays, or the wheels spin and the car buzzes, slowing as
## the spring runs down while the key turns back. If the spring is broken the key turns, but nothing happens.
signal wound(runs: bool)                   ## the key is wound: `runs` if the piece then plays or runs
var wind_sound: AudioStream                ## set by the game: winding (a ratchet against the spring, or loose on a broken one)
var run_sound: AudioStream                 ## ...and the tune, or the clockwork's whirr
var _sfx: AudioStreamPlayer
var _run: AudioStreamPlayer
var works := true                          ## set by the game: false if the spring is broken
var run_len := 6.0                         ## seconds it runs once wound (the game sets it to the sound's length)
var winding := 0.0                         ## seconds of winding left
var running := 0.0                         ## seconds of running left
var _shake_base := Vector3.INF             ## the model's place, for the car's buzz

var root: Node3D                           ## the item
var parts: Array = []                      ## {"name", "node", "type", "rest" (Basis), "shape", and for hinges "axis", "closed", "t", "target";
                                           ##  for chains "hang", "q", "w"}
var _prev_q := Quaternion.IDENTITY         ## the chain's parent's rotation last frame

## Reads the parts from `data` (the json) and finds their nodes under `model`.
func setup(item_root: Node3D, model: Node3D, data: Dictionary) -> void:
	root = item_root
	for pname: String in data.keys():
		var node := model.find_child(pname, true, false) as Node3D
		if node == null:
			continue
		var d: Dictionary = data[pname]
		var p := {"name": pname, "node": node, "type": d["type"], "rest": node.transform.basis, "shape": null}
		if d["type"] == "spin":
			var sa: Array = d["axis"]
			p["axis"] = Vector3(sa[0], sa[1], sa[2]).normalized()
			p["role"] = String(d["role"])                       ## key, drum or wheel
			p["a"] = 0.0
		elif d["type"] == "hinge":
			var ax: Array = d["axis"]
			p["axis"] = Vector3(ax[0], ax[1], ax[2]).normalized()
			p["closed"] = float(d["closed"])
			var off: Array = d.get("offset", [0.0, 0.0, 0.0])
			p["offset"] = Vector3(off[0], off[1], off[2])       ## the small shift that seats it exactly once shut
			p["rest_pos"] = node.position
			p["scale"] = float(d.get("scale", 1.0))              ## the spyglass's cap, sized to the lens
			p["arc"] = float(d.get("arc", 0.0))                  ## lifted this high on the way, so it clears what it passes
			p["t"] = float(d.get("start", 0.0))                  ## the drawer starts shut
			p["target"] = p["t"]
			_pose(p)
		else:
			p["parent"] = String(d.get("parent", ""))           ## the spyglass cap's chain hangs from the cap and goes where it goes
			var an: Array = d.get("anchor", [])
			if an.size() == 3:
				p["anchor"] = Vector3(an[0], an[1], an[2])          ## ...and, with the cap on, runs back to its lug on the tube
				p["model"] = node.get_parent()
			var h: Array = d["hang"]
			p["hang"] = Vector3(h[0], h[1], h[2]).normalized()
			p["d"] = p["hang"]
			p["w"] = Vector3.ZERO
		parts.append(p)
		node.set_meta("living_part", pname)
	for p: Dictionary in parts:
		if p["type"] == "chain" and p["parent"] != "":
			for q: Dictionary in parts:
				if q["name"] == p["parent"]:
					var ch: Node3D = p["node"]
					var cap: Node3D = q["node"]
					var tf := cap.transform.affine_inverse() * ch.transform     ## (siblings: the same place, now relative to the cap)
					ch.owner = null
					ch.get_parent().remove_child(ch)
					cap.add_child(ch)
					ch.transform = tf
					p["rest"] = (p["node"] as Node3D).transform.basis
					p["owner"] = q

## True if the piece has anything that opens.
func has_hinges() -> bool:
	for p: Dictionary in parts:
		if p["type"] == "hinge":
			return true
	return false

## True if the piece has a key to wind.
func has_key() -> bool:
	for p: Dictionary in parts:
		if p["type"] == "spin" and p["role"] == "key":
			return true
	return false

## Opens or shuts one part by name (or every hinge with ""); clicking the key winds it, and E winds a piece with nothing to open.
func toggle(pname: String = "") -> void:
	for p: Dictionary in parts:
		if p["type"] == "spin" and p["role"] == "key" and (p["name"] == pname or (pname == "" and not has_hinges())):
			wind()
			return
	for p: Dictionary in parts:
		if p["type"] == "hinge" and (pname == "" or p["name"] == pname):
			p["target"] = 0.0 if float(p["target"]) > 0.5 else 1.0

## Winds the key (not while it is already winding or running).
func wind() -> bool:
	if winding > 0.0 or running > 0.0 or not has_key():
		return false
	winding = WIND_TIME
	_play("_sfx", wind_sound)
	return true

func _play(which: String, stream: AudioStream) -> void:
	if stream == null:
		return
	var pl: AudioStreamPlayer = get(which)
	if pl == null:
		pl = AudioStreamPlayer.new()
		pl.volume_db = -4.0
		add_child(pl)
		set(which, pl)
	pl.stream = stream
	pl.play()

## The part a collision shape belongs to ("" if none, or it is the body).
static func part_of(shape: Node) -> String:
	return String(shape.get_meta("living_part", "")) if shape != null else ""

func _process(delta: float) -> void:
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return
	var was_winding := winding > 0.0
	winding = maxf(0.0, winding - delta)
	if was_winding and winding == 0.0:
		running = run_len if works else 0.0
		if works:
			_play("_run", run_sound)
		wound.emit(works)
	var was_running := running > 0.0
	running = maxf(0.0, running - delta)
	for p: Dictionary in parts:
		var node: Node3D = p["node"]
		if p["type"] == "spin":
			_spin(p, delta, was_winding)
		elif p["type"] == "hinge":
			var t: float = p["t"]
			var target: float = p["target"]
			if t == target:
				continue
			t = move_toward(t, target, delta / HINGE_TIME)
			p["t"] = t
			_pose(p)
		else:
			_swing(p, delta)
		_follow(p)

## A key, drum or wheel: the key turns forward as it is wound and slowly back as the piece runs; the drum and wheels turn while it
## runs, slowing as the spring runs down.
func _spin(p: Dictionary, delta: float, was_winding: bool) -> void:
	var speed := 0.0
	var left := running / maxf(run_len, 0.01)                  ## 1 just wound .. 0 run down
	var ease_out := sqrt(left)
	match p["role"]:
		"key":
			if was_winding:
				speed = TAU * WIND_TURNS / WIND_TIME
			elif running > 0.0:
				speed = -TAU * WIND_TURNS / run_len
		"drum":
			speed = DRUM_SPEED * ease_out if running > 0.0 else 0.0
		"wheel":
			speed = WHEEL_SPEED * ease_out if running > 0.0 else 0.0
	if speed == 0.0:
		if p["role"] == "wheel" and _shake_base != Vector3.INF:     ## run down: the car settles where it was
			((p["node"] as Node3D).get_parent() as Node3D).position = _shake_base
		return
	p["a"] = float(p["a"]) + speed * delta
	(p["node"] as Node3D).transform.basis = Basis(p["axis"], float(p["a"])) * (p["rest"] as Basis)
	if p["role"] == "wheel":                                     ## the clockwork's buzz shakes the little car
		var model := (p["node"] as Node3D).get_parent() as Node3D
		if _shake_base == Vector3.INF:
			_shake_base = model.position
		var buzz := 0.0015 * ease_out if running > 0.0 else 0.0
		model.position = _shake_base + Vector3(sin(running * 71.0), absf(sin(running * 53.0)), cos(running * 67.0)) * buzz

## A hinged (or sliding, lifting, placed) part at its blend `t`.
func _pose(p: Dictionary) -> void:
	var node: Node3D = p["node"]
	var t: float = p["t"]
	var eased := t * t * (3.0 - 2.0 * t)
	var sc := lerpf(1.0, float(p["scale"]), eased)
	node.transform.basis = Basis(p["axis"], float(p["closed"]) * eased) * (p["rest"] as Basis).scaled(Vector3.ONE * sc)
	node.position = (p["rest_pos"] as Vector3) + (p["offset"] as Vector3) * eased + Vector3.UP * float(p["arc"]) * sin(PI * eased)

## The chain: a damped pendulum about its top link, in its parent's space. Its state is the way it hangs (`d`), with no twist about
## itself, so it always stays on the bow; at rest, with the piece upright, it hangs just as it was modelled.
func _swing(p: Dictionary, delta: float) -> void:
	var node: Node3D = p["node"]
	var parent := node.get_parent() as Node3D
	var pq := parent.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var hang0: Vector3 = p["hang"]
	var d: Vector3 = p.get("d", hang0)
	var w: Vector3 = p["w"]
	# the piece turned: the chain, hanging in the world, mostly keeps its place, so in the piece's own space it swings the other way
	var turn := (pq.inverse() * _prev_q).normalized()
	_prev_q = pq
	if turn.get_angle() < 0.5:                                 ## (not on the first frame, or a jump)
		d = (Quaternion.IDENTITY.slerp(turn, CHAIN_LAG) * d).normalized()
	# gravity pulls it back toward hanging down: with the piece upright, that's the modelled way it hangs
	var g := (pq.inverse() * Vector3.DOWN).normalized()
	var target := hang0
	if g.dot(Vector3.DOWN) > -0.98:
		target = (Quaternion(Vector3.DOWN, g) * hang0).normalized()
	var own: Dictionary = p.get("owner", {})
	var lift := 0.0                                            ## how far its cap has gone toward the lens: off the table, it just hangs
	var unscale := 1.0
	if not own.is_empty():
		var ot: float = own["t"]
		lift = ot * ot * (3.0 - 2.0 * ot)
		var to := g
		if p.has("anchor"):
			var lug: Vector3 = (p["model"] as Node3D).global_transform * (p["anchor"] as Vector3)
			to = (pq.inverse() * (lug - node.global_position)).normalized()
		target = target.slerp(to, lift).normalized()
		unscale = 1.0 / lerpf(1.0, float(own["scale"]), lift)   ## the cap grows to fit the lens; its chain stays its own size
	w += d.cross(target) * CHAIN_PULL * delta
	w *= exp(-CHAIN_DAMP * delta)
	if w.length() > 0.0001:
		d = (Quaternion(w.normalized(), w.length() * delta) * d).normalized()
	# a chain lies on the case and the mat: it can't swing all the way round
	var off := d.angle_to(hang0)
	if off > CHAIN_REACH and lift < 0.5:
		d = hang0.slerp(d, CHAIN_REACH / off).normalized()
		w *= 0.4
	p["d"] = d
	p["w"] = w
	var q := Quaternion(hang0, d) if hang0.dot(d) > -0.999 else Quaternion.IDENTITY
	node.transform.basis = (Basis(q) * (p["rest"] as Basis)).scaled(Vector3.ONE * unscale)

## A part's collision shape goes where the part is now.
func _follow(p: Dictionary) -> void:
	var cs: CollisionShape3D = p["shape"]
	if cs != null and is_instance_valid(cs):
		cs.transform = Models._rel(root, p["node"])
