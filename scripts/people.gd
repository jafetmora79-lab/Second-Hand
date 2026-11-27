extends RefCounted
class_name People
## The townsfolk who come through the door. Each has a look, a temperament that drives how they haggle, and their own lines.
## - belief: how much they think their things are worth, against the truth (under 1: they undervalue it, over 1: they think it is treasure).
## - floor: the lowest share of their own belief they will take.  - patience: how many counter-offers they sit through.
## Meshy characters replace the stand-ins when assets/people/<id>.glb exists.

const FOLK := {
	"trapper": {"name": "Old Amos", "coat": Color(0.38, 0.27, 0.18), "hat": Color(0.45, 0.36, 0.25), "skin": Color(0.86, 0.68, 0.55), "height": 1.72,
		"belief": 0.8, "floor": 0.7, "patience": 4,
		"hello": ["Morning. Found this in my brother's shed. He won't be needing it now.", "Cleared out the old cabin. Thought you might want this.", "This one's been in the family. Times are lean, though."],
		"accept": "Deal. Buy yourself something warm with the change.", "counter": "Can't go that low. How about %s?", "leave": "Forget it. I'll keep it.", "insult": "Ha! That's an insult, and you know it."},
	"collector": {"name": "Miss Vale", "coat": Color(0.66, 0.52, 0.36), "hat": Color(0.62, 0.12, 0.12), "skin": Color(0.9, 0.74, 0.62), "height": 1.68,
		"belief": 1.35, "floor": 0.88, "patience": 2,
		"hello": ["I know exactly what this is worth, so let's not waste each other's time.", "A rare piece. I'm only selling to make room for better ones."],
		"accept": "Fine. You drive a hard bargain.", "counter": "Please. %s, and that's generous.", "leave": "I'll take it to the city.", "insult": "You must be joking."},
	"widow": {"name": "Mrs. Holt", "coat": Color(0.3, 0.32, 0.4), "hat": Color(0.2, 0.2, 0.25), "skin": Color(0.88, 0.72, 0.62), "height": 1.6,
		"belief": 0.7, "floor": 0.6, "patience": 5,
		"hello": ["My husband kept this on his desk for forty years. I don't know what it's worth, dear.", "The house is too big now. I'm letting things go."],
		"accept": "Thank you, dear. He'd be glad it went somewhere it's wanted.", "counter": "Oh... could you do %s?", "leave": "I think I'll hold on to it a while longer.", "insult": "Oh. I see."},
	"kid": {"name": "Toby", "coat": Color(0.2, 0.42, 0.55), "hat": Color(0.85, 0.55, 0.15), "skin": Color(0.92, 0.76, 0.64), "height": 1.4,
		"belief": 1.1, "floor": 0.5, "patience": 3,
		"hello": ["My grandpa said this is worth a fortune! Is it?", "Found it in the attic. Mom says I can sell it."],
		"accept": "Yes! Wait till I tell everyone!", "counter": "Hmm... %s?", "leave": "Aw. Never mind.", "insult": "That's not even enough for a sled!"},
	"drifter": {"name": "A stranger", "coat": Color(0.18, 0.18, 0.2), "hat": Color(0.12, 0.12, 0.14), "skin": Color(0.8, 0.64, 0.52), "height": 1.82,
		"belief": 1.25, "floor": 0.45, "patience": 2,
		"hello": ["Got something. No questions, all right? Cash.", "Genuine article. Real old. You want it or not?"],
		"accept": "Pleasure.", "counter": "%s. Last offer.", "leave": "Your loss.", "insult": "Funny guy."},
}

const BUYERS := {
	"collector_b": {"name": "Mr. Pell, a collector", "coat": Color(0.25, 0.3, 0.26), "hat": Color(0.3, 0.22, 0.15), "skin": Color(0.84, 0.7, 0.6), "height": 1.75,
		"want": ["instruments", "watches"], "pays": 1.35, "patience": 3,
		"hello": "Good day. I collect fine instruments and timepieces. Anything on your shelves?", "fake": "This is a reproduction. I'm surprised at you."},
	"decorator": {"name": "Jo, from the lodge", "coat": Color(0.55, 0.25, 0.28), "hat": Color(0.9, 0.86, 0.78), "skin": Color(0.9, 0.75, 0.64), "height": 1.66,
		"want": ["household", "curios", "folk art"], "pays": 1.25, "patience": 3,
		"hello": "We're doing up the lodge for the season. Something with character?", "fake": "Hm, this looks newer than you said. No thanks."},
}

static func figure(info: Dictionary, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Customer"
	var path := "res://assets/people/%s.glb" % id
	if ResourceLoader.exists(path):
		var m := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(m)
		var box := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b := (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		var s := float(info["height"]) / maxf(box.size.y, 0.01)
		m.scale = Vector3.ONE * s
		m.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
		return root
	var h := float(info["height"])
	var coat := StandardMaterial3D.new()
	coat.albedo_color = info["coat"]
	coat.roughness = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = info["skin"]
	var hat := StandardMaterial3D.new()
	hat.albedo_color = info["hat"]
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = h * 0.78
	body.mesh = cap
	body.material_override = coat
	body.position = Vector3(0, h * 0.39, 0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.28
	head.mesh = sm
	head.material_override = skin
	head.position = Vector3(0, h * 0.86, 0)
	root.add_child(head)
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.15
	cm.height = 0.12
	top.mesh = cm
	top.material_override = hat
	top.position = Vector3(0, h * 0.86 + 0.12, 0)
	root.add_child(top)
	for ex: float in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.016
		em.height = 0.032
		eye.mesh = em
		var ek := StandardMaterial3D.new()
		ek.albedo_color = Color(0.08, 0.07, 0.07)
		eye.material_override = ek
		eye.position = Vector3(ex, h * 0.875, 0.115)
		root.add_child(eye)
	return root

## Plays the figure's own animation whose name contains `what` ("walk", "idle", "talk", "wave"...), looping, if its model has one
## (Meshy rigged and animated models carry an AnimationPlayer). Returns false when there is none, so the stand-in bob is used.
const GESTURE := 4.0

static func play(figure: Node, what: String) -> bool:
	if figure == null or not is_instance_valid(figure):
		return false
	for ap in figure.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		for anim_name in player.get_animation_list():
			if String(anim_name).to_lower().contains(what):
				var a := player.get_animation(anim_name)
				a.loop_mode = Animation.LOOP_LINEAR if what in ["walk", "idle", "run"] else Animation.LOOP_NONE
				player.play(anim_name, 0.25)
				if a.loop_mode == Animation.LOOP_NONE and player.is_inside_tree():
					## a gesture: after at most GESTURE seconds (Amos's angry talk runs 21 s) ease back to its first frame, a neutral stance,
					## unless something else has started playing since
					var n := StringName(anim_name)
					var turn := player.get_meta("gesture", 0) as int + 1
					player.set_meta("gesture", turn)
					player.get_tree().create_timer(minf(a.length, GESTURE)).timeout.connect(func() -> void:
						if is_instance_valid(player) and player.get_meta("gesture", 0) == turn and player.assigned_animation == n:
							player.play(n, 0.5)
							player.seek(0.0, true)
							player.pause())
				return true
	return false

## Stops whatever the figure is playing (a walk would otherwise keep looping on the spot).
static func stop(figure: Node) -> void:
	if figure == null or not is_instance_valid(figure):
		return
	for ap in figure.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
