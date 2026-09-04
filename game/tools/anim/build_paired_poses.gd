extends SceneTree
## Bakes PairedRecipes into resources/animations/paired_poses.tres.
##
## Run from the Godot project root:
##   godot4 --headless -s res://tools/anim/build_paired_poses.gd
##
## For every recipe sample it evaluates each of the source clip's 55 bone
## rotation tracks (and the one pelvis position track) at the sampled time,
## applies the recipe's per-bone offsets, and writes the result as one key
## per bone in the output clip. The output is therefore a genuine full-body
## pose sequence, interpolated by Godot between the sampled beats, rather
## than a sparse set of keyed bones with the rest snapped to rest pose.
##
## Deterministic by construction: track order comes from a reference clip's
## own track order, sample order from the recipe array, and bone offsets from
## a Dictionary (insertion-ordered in GDScript). Running it twice produces a
## byte-identical file, which tests/test_paired_poses.gd asserts.

const RIG_SCENE := "res://assets/characters/wrestler_base.glb"
const PAIRED_MOVES := "res://resources/animations/paired_moves.tres"
const OUTPUT := "res://resources/animations/paired_poses.tres"

## Sampled to fix the output's track list and track paths. Any clip would do
## -- all 43 on this rig carry the same 55 rotation tracks plus a pelvis
## position track -- but taking them from a real clip rather than a hardcoded
## list means a re-import that renames bones or moves the Skeleton3D breaks
## loudly here instead of producing silently dead tracks.
const TEMPLATE_CLIP := "PickUp_Table"

## preload rather than the class_name: a `-s` script runs before the global
## class cache is necessarily populated in a fresh checkout.
const PairedRecipes := preload("res://resources/animations/paired_recipes.gd")

func _init() -> void:
	var status := _build()
	quit(status)

func _build() -> int:
	var rig: PackedScene = load(RIG_SCENE)
	if not rig:
		push_error("Cannot load rig: %s" % RIG_SCENE)
		return 1
	var model: Node = rig.instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if not player:
		push_error("Rig has no AnimationPlayer")
		model.free()
		return 1

	var lengths := _root_track_lengths()
	if lengths.is_empty():
		model.free()
		return 1

	var template: Animation = player.get_animation(TEMPLATE_CLIP)
	var tracks := _describe_tracks(template)

	var out := AnimationLibrary.new()
	var built := 0
	for move_id in PairedRecipes.RECIPES:
		if not lengths.has(move_id):
			push_error("Recipe '%s' has no matching animation in %s"
					% [move_id, PAIRED_MOVES])
			model.free()
			return 1
		var length: float = lengths[move_id]
		for role in ["attacker", "defender"]:
			var samples: Array = PairedRecipes.RECIPES[move_id][role]
			var anim := _bake(player, tracks, samples, length,
					"%s/%s" % [move_id, role], role == "defender")
			if not anim:
				model.free()
				return 1
			var suffix: String = PairedRecipes.ATTACKER_SUFFIX if role == "attacker" \
					else PairedRecipes.DEFENDER_SUFFIX
			out.add_animation(StringName(move_id + suffix), anim)
			built += 1

	model.free()
	var err := ResourceSaver.save(out, OUTPUT)
	if err != OK:
		push_error("Saving %s failed: %d" % [OUTPUT, err])
		return 1
	print("Wrote %s -- %d clips from %d recipes"
			% [OUTPUT, built, PairedRecipes.RECIPES.size()])
	return 0

## Output clips must be exactly as long as the root-transform half of the
## same move, because the two are started on the same physics tick and kept
## in sync by nothing else.
func _root_track_lengths() -> Dictionary:
	var library: AnimationLibrary = load(PAIRED_MOVES)
	if not library:
		push_error("Cannot load %s" % PAIRED_MOVES)
		return {}
	var lengths := {}
	for name in library.get_animation_list():
		lengths[String(name)] = library.get_animation(name).length
	return lengths

## [{type, path, bone}] for every bone track on the template, in its order.
func _describe_tracks(template: Animation) -> Array[Dictionary]:
	var tracks: Array[Dictionary] = []
	for i in template.get_track_count():
		var type := template.track_get_type(i)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := template.track_get_path(i)
		tracks.append({
			"type": type,
			"path": path,
			"bone": String(path.get_concatenated_subnames()),
		})
	return tracks

static func _key(entry: Dictionary) -> String:
	return "%d:%s" % [entry["type"], entry["path"]]

func _bake(player: AnimationPlayer, tracks: Array[Dictionary], samples: Array,
		length: float, label: String, strip_pelvis_rotation: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE

	# One output track per template track, in template order.
	var track_index := {}
	for entry in tracks:
		var idx := anim.add_track(entry["type"])
		anim.track_set_path(idx, entry["path"])
		# CUBIC, matching the hand-authored root tracks in paired_moves.tres:
		# these poses are sampled at 5-7 beats across a one-second throw, and
		# linear interpolation between them reads as a series of snaps.
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
		# Keyed by path *and* type: pelvis carries both a rotation and a
		# position track at the same path, and keying on path alone silently
		# overwrote the position track's index with the rotation track's.
		track_index[_key(entry)] = idx

	for sample: Dictionary in samples:
		var clip_name: String = sample["clip"]
		if not player.has_animation(clip_name):
			push_error("%s: sample names clip '%s', which the rig doesn't have"
					% [label, clip_name])
			return null
		var source: Animation = player.get_animation(clip_name)
		var at: float = sample["at"]
		if at < 0.0 or at > source.length:
			push_error("%s: sample time %.3f is outside '%s' (0..%.3f)"
					% [label, at, clip_name, source.length])
			return null
		var t: float = sample["t"]
		if t < 0.0 or t > length:
			push_error("%s: output time %.3f is outside the clip (0..%.3f)"
					% [label, t, length])
			return null
		var offsets: Dictionary = sample.get("bones", {})
		var pelvis_offset: Vector3 = sample.get("pelvis", Vector3.ZERO)

		for entry in tracks:
			var src := source.find_track(entry["path"], entry["type"])
			if src < 0:
				push_error("%s: clip '%s' has no %s track for %s"
						% [label, clip_name, entry["type"], entry["bone"]])
				return null
			var out_track: int = track_index[_key(entry)]
			if entry["type"] == Animation.TYPE_ROTATION_3D:
				var rot: Quaternion = Quaternion.IDENTITY if strip_pelvis_rotation \
						and entry["bone"] == "pelvis" else \
						source.rotation_track_interpolate(src, at)
				if offsets.has(entry["bone"]):
					var deg: Vector3 = offsets[entry["bone"]]
					rot = rot * Quaternion(Basis.from_euler(Vector3(
							deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))))
				anim.rotation_track_insert_key(out_track, t, rot.normalized())
			else:
				var pos: Vector3 = source.position_track_interpolate(src, at)
				anim.position_track_insert_key(out_track, t, pos + pelvis_offset)

	return anim
