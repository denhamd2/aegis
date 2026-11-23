extends SceneTree
## Samples every paired move's root trajectory, exactly as Godot plays it, for
## the Unreal port's GrappleRig.
##
## Source: resources/animations/paired_moves.tres -- the two root tracks per
## move ("WrestlerA" = attacker, "WrestlerB" = defender), baked from
## PairedRecipes.TRAJECTORIES with PairedFit's corrections by
## tools/anim/build_paired_moves.gd. Sampling the baked clip with Godot's own
## interpolation (cubic position, slerped rotation) means the port plays the
## same arc, fit and all, without re-implementing either.
##
## Output (JSON, sorted, rounded -- byte-identical for the same input):
##   tick_hz      60
##   moves        {move_id: animation_pair_id} for every MoveDef with a pair id
##   trajectories {pair_id: {length, ticks, attacker, defender}}
##       attacker/defender: one [x, y, z, yaw] per tick from 0 to length, in
##       the pair frame: metres, +X from the defender toward the attacker
##       (attacker starts at +0.40), +Y up off the mat (the model origin is
##       at the feet), +Z to the attacker's left as he faces the defender;
##       yaw in degrees (Basis.get_euler() YXZ), where +90 faces -X.
##
## Run headless from the repo root:
##   godot --headless --path game --script "$PWD/tools/unreal/export_paired_trajectories.gd" \
##       -- tools/unreal/paired_trajectories.json

const LIBRARY := "res://resources/animations/paired_moves.tres"
const MOVES_DIR := "res://resources/moves"
const HZ := 60
const MoveResource := preload("res://resources/move_def.gd")
const Recipes := preload("res://resources/animations/paired_recipes.gd")
const MOVE_FIELDS := [
	"startup_frames", "active_frames", "recovery_frames",
	"reversal_window_start", "reversal_window_end", "damage_head", "damage_torso",
	"damage_arms", "damage_legs", "momentum_cost", "momentum_gain",
	"leaves_defender_down", "defender_lands_head_away", "down_face_first",
	"required_opponent_state", "weight_class_min", "weight_class_max",
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "paired_trajectories.json"
	var lib := load(LIBRARY) as AnimationLibrary
	if lib == null:
		push_error("cannot load " + LIBRARY)
		quit(1)
		return

	var trajectories := {}
	var names: Array = lib.get_animation_list()
	names.sort()
	for anim_name: StringName in names:
		var anim := lib.get_animation(anim_name)
		var roles := {"attacker": _tracks(anim, "WrestlerA"), "defender": _tracks(anim, "WrestlerB")}
		if roles["attacker"].is_empty() or roles["defender"].is_empty():
			continue
		var ticks := int(ceil(anim.length * HZ - 0.0001))
		var entry := {"length": snappedf(anim.length, 0.0001), "ticks": ticks}
		for role: String in ["attacker", "defender"]:
			var pos_track: int = roles[role]["pos"]
			var rot_track: int = roles[role]["rot"]
			var keys := []
			for k in ticks + 1:
				var t := minf(float(k) / HZ, anim.length)
				var p: Vector3 = anim.position_track_interpolate(pos_track, t)
				var q: Quaternion = anim.rotation_track_interpolate(rot_track, t)
				var yaw := rad_to_deg(Basis(q).get_euler().y)
				keys.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001), snappedf(yaw, 0.01)])
			entry[role] = keys
		trajectories[String(anim_name)] = entry

	var moves := {}
	var definitions := {}
	for directory: String in [MOVES_DIR, MOVES_DIR + "/ff"]:
		for filename: String in DirAccess.get_files_at(directory):
			if not filename.ends_with(".tres"):
				continue
			var def := load(directory.path_join(filename)) as MoveResource
			var id := filename.get_basename()
			if def == null or definitions.has(id):
				push_error("Missing or duplicate move definition: " + directory.path_join(filename))
				quit(1)
				return
			var pair := String(def.animation_pair_id)
			var row := {"animation_pair_id": pair, "total_frames": def.total_frames(),
					"group": String(def.get_meta("ff_family", ""))}
			for field: String in MOVE_FIELDS:
				row[field] = def.get(field)
			definitions[id] = row
			if trajectories.has(pair):
				moves[id] = pair

	var doc := {"tick_hz": HZ, "moves": moves, "trajectories": trajectories}
	if not _write(out_path, doc):
		quit(1)
		return
	if args.size() > 1 and not _write(args[1], {"move_defs": definitions, "paired_rules": _paired_rules()}):
		quit(1)
		return
	print("paired trajectories: %d clips, %d moves -> %s" % [trajectories.size(), moves.size(), out_path])
	quit(0)


func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Cannot write " + path)
		return false
	file.store_string(JSON.stringify(data, "", true) + "\n")
	return file.get_error() == OK


func _paired_rules() -> Dictionary:
	var rules := {}
	for id: String in Recipes.RECIPES:
		var recipe: Dictionary = Recipes.RECIPES[id]
		var row := {}
		for field: String in ["opening_alignment", "camera_impact_at", "attacker_grips_from",
				"attacker_grips_until", "defender_grips_until"]:
			if recipe.has(field):
				row[field] = recipe[field]
		if not row.is_empty():
			rules[id] = row
	return rules


func _tracks(anim: Animation, role_node: String) -> Dictionary:
	var out := {}
	for i in anim.get_track_count():
		if not String(anim.track_get_path(i)).ends_with(role_node):
			continue
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D:
				out["pos"] = i
			Animation.TYPE_ROTATION_3D:
				out["rot"] = i
	return out if out.size() == 2 else {}
