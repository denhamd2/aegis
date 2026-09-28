extends Node
## Fits PairedFit.OFFSETS (resources/animations/paired_fit.gd): runs every
## paired move with GrappleRig's runtime separation on, records how far each
## role's model had to move -- in the pair frame, against the paired clip's
## own clock -- and adds that, at each trajectory key, to the stored fit.
##
##   godot4 --headless --path game tools/anim/fit_paired.tscn
##   godot4 --headless --import --path game
##   godot4 --headless --path game -s res://tools/anim/build_paired_moves.gd
##
## Run it, rebake, and run it again: the second pass fits what is left. The
## file it writes is the whole fit, not a delta.

const OUT := "res://resources/animations/paired_fit.gd"
## Keys closer together than this share a sample window.
const WINDOW := 0.05


func _ready() -> void:
	var fit: Dictionary = PairedFit.OFFSETS.duplicate(true)
	for move_id in PairClearance.paired_move_ids():
		var move: MoveDef = load("res://resources/moves/%s.tres" % move_id)
		var spec: Dictionary = PairedRecipes.TRAJECTORIES.get(String(move.animation_pair_id), {})
		if spec.is_empty():
			continue
		var samples: Array = await _record(move_id)
		var entry: Dictionary = fit.get(move_id, {})
		for role: String in ["attacker", "defender"]:
			var keys: Array = spec[role]["pos"]
			var old: Array = entry.get(role, [])
			var out := []
			for i in keys.size():
				var t: float = keys[i][0]
				var add := _separation_at(samples, t, role)
				var prev := Vector3.ZERO
				if i < old.size():
					prev = Vector3(old[i][0], old[i][1], old[i][2])
				var v := prev + add
				out.append([snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)])
			entry[role] = out
		fit[move_id] = entry
		print("FIT %-36s D max %.3f  A max %.3f" % [move_id, _peak(samples, "defender"),
				_peak(samples, "attacker")])
	_write(fit)
	print("FIT_DONE wrote %s" % OUT)
	get_tree().quit()


## [[clip_time, attacker_sep_pair, defender_sep_pair], ...] over the move.
func _record(move_id: String) -> Array:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var d: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	d.is_ai = false
	var move: MoveDef = load("res://resources/moves/%s.tres" % move_id)
	d.global_position = a.global_position - a.global_transform.basis.z * 0.9
	a.look_at(d.global_position, Vector3.UP)
	d.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	var rig: GrappleRig = scene.get_node("GrappleRig")
	rig.begin(a, d, move)
	var samples := []
	var guard := 0
	while rig.is_active() and guard < 2000:
		await get_tree().physics_frame
		guard += 1
		var player := rig.animation_player
		if player == null or not player.is_playing():
			continue
		var to_pair := rig._pair_transform.basis.inverse()
		samples.append([player.current_animation_position,
				to_pair * a.paired_separation, to_pair * d.paired_separation])
	scene.queue_free()
	await get_tree().process_frame
	return samples


## The role's separation near clip time `t`: the sample with the largest
## magnitude within WINDOW of it (the key must clear the worst of its span),
## or the nearest sample.
func _separation_at(samples: Array, t: float, role: String) -> Vector3:
	var index := 1 if role == "attacker" else 2
	var best := Vector3.ZERO
	var nearest := INF
	var nearest_v := Vector3.ZERO
	for s: Array in samples:
		var dt := absf(float(s[0]) - t)
		var v: Vector3 = s[index]
		if dt < nearest:
			nearest = dt
			nearest_v = v
		if dt <= WINDOW and v.length() > best.length():
			best = v
	return best if best != Vector3.ZERO else nearest_v


func _peak(samples: Array, role: String) -> float:
	var index := 1 if role == "attacker" else 2
	var m := 0.0
	for s: Array in samples:
		m = maxf(m, (s[index] as Vector3).length())
	return m


func _write(fit: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(OUT)
	var head := text.substr(0, text.find("const OFFSETS"))
	var body := "const OFFSETS := {\n"
	var ids := fit.keys()
	ids.sort()
	for id in ids:
		body += "\t\"%s\": {\n" % id
		for role in ["attacker", "defender"]:
			var rows := []
			for v: Array in fit[id].get(role, []):
				rows.append("[%.3f, %.3f, %.3f]" % [v[0], v[1], v[2]])
			body += "\t\t\"%s\": [%s],\n" % [role, ", ".join(rows)]
		body += "\t},\n"
	body += "}\n"
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(head + body)
