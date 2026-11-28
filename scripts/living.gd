extends Node
class_name Living
## The moving parts of a piece on the mat (from tools/split_items.py: <kind>_parts.glb and .json):
## - hinges (the music box's lid, the compass's lid, the pocket watch's cover) open and close when you click them or press E;
## - a chain (the watch's) hangs from its top link and swings as you turn the piece: it lags behind the turn, then settles back
##   toward hanging straight down, never swinging further than a real chain could from where it lies.
## Each part's collision shape follows it, so the loupe and clicks always meet the part where you see it.

const HINGE_TIME := 0.55                   ## seconds to swing a lid fully open or shut
const CHAIN_PULL := 18.0                   ## how strongly the chain falls back toward hanging down
const CHAIN_DAMP := 2.0                    ## how quickly its swing dies away
const CHAIN_LAG := 0.82                    ## how much of the piece's turn the chain resists, each frame (1 = it stays put in the world)
const CHAIN_REACH := 1.15                  ## the furthest (radians) it may swing from where it lay in the model

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
		if d["type"] == "hinge":
			var ax: Array = d["axis"]
			p["axis"] = Vector3(ax[0], ax[1], ax[2]).normalized()
			p["closed"] = float(d["closed"])
			var off: Array = d.get("offset", [0.0, 0.0, 0.0])
			p["offset"] = Vector3(off[0], off[1], off[2])       ## the small shift that seats it exactly once shut
			p["rest_pos"] = node.position
			p["t"] = 0.0
			p["target"] = 0.0
		else:
			var h: Array = d["hang"]
			p["hang"] = Vector3(h[0], h[1], h[2]).normalized()
			p["d"] = p["hang"]
			p["w"] = Vector3.ZERO
		parts.append(p)
		node.set_meta("living_part", pname)

## True if the piece has anything that opens.
func has_hinges() -> bool:
	for p: Dictionary in parts:
		if p["type"] == "hinge":
			return true
	return false

## Opens or shuts one part by name (or every hinge with "").
func toggle(pname: String = "") -> void:
	for p: Dictionary in parts:
		if p["type"] == "hinge" and (pname == "" or p["name"] == pname):
			p["target"] = 0.0 if float(p["target"]) > 0.5 else 1.0

## The part a collision shape belongs to ("" if none, or it is the body).
static func part_of(shape: Node) -> String:
	return String(shape.get_meta("living_part", "")) if shape != null else ""

func _process(delta: float) -> void:
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return
	for p: Dictionary in parts:
		var node: Node3D = p["node"]
		if p["type"] == "hinge":
			var t: float = p["t"]
			var target: float = p["target"]
			if t == target:
				continue
			t = move_toward(t, target, delta / HINGE_TIME)
			p["t"] = t
			var eased := t * t * (3.0 - 2.0 * t)
			node.transform.basis = Basis(p["axis"], float(p["closed"]) * eased) * (p["rest"] as Basis)
			node.position = (p["rest_pos"] as Vector3) + (p["offset"] as Vector3) * eased
		else:
			_swing(p, delta)
		_follow(p)

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
	w += d.cross(target) * CHAIN_PULL * delta
	w *= exp(-CHAIN_DAMP * delta)
	if w.length() > 0.0001:
		d = (Quaternion(w.normalized(), w.length() * delta) * d).normalized()
	# a chain lies on the case and the mat: it can't swing all the way round
	var off := d.angle_to(hang0)
	if off > CHAIN_REACH:
		d = hang0.slerp(d, CHAIN_REACH / off).normalized()
		w *= 0.4
	p["d"] = d
	p["w"] = w
	var q := Quaternion(hang0, d) if hang0.dot(d) > -0.999 else Quaternion.IDENTITY
	node.transform.basis = Basis(q) * (p["rest"] as Basis)

## A part's collision shape goes where the part is now.
func _follow(p: Dictionary) -> void:
	var cs: CollisionShape3D = p["shape"]
	if cs != null and is_instance_valid(cs):
		cs.transform = Models._rel(root, p["node"])
