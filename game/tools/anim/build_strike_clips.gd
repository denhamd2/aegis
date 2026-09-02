extends SceneTree
## Bakes StrikeRecipes into resources/animations/strike_clips.tres.
##
## Run from the Godot project root:
##   godot4 --headless -s res://tools/anim/build_strike_clips.gd
##
## Three kinds of output, all deterministic and all derived from the rig's
## own clips: a trim (keys past a cutoff dropped, every remaining frame
## still where it was), a retime (all key times scaled), and a stitch (a
## pose sequence sampled out of other clips, the same technique
## build_paired_poses.gd uses for the grapples).
##
## Running it twice produces a byte-identical file, which
## tests/test_strike_clips.gd asserts.

const RIG_SCENE := "res://assets/characters/wrestler_base.glb"
const OUTPUT := "res://resources/animations/strike_clips.tres"

## preload rather than the class_name: a `-s` script runs before the global
## class cache is necessarily populated in a fresh checkout.
const StrikeRecipes := preload("res://resources/animations/strike_recipes.gd")

func _init() -> void:
	quit(_build())

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

	var out := AnimationLibrary.new()
	for name in StrikeRecipes.RECIPES:
		var recipe: Dictionary = StrikeRecipes.RECIPES[name]
		var anim: Animation = null
		match recipe.get("kind", ""):
			"trim":
				anim = _trim(player, recipe, String(name))
			"retime":
				anim = _retime(player, recipe, String(name))
			"stitch":
				anim = _stitch(player, recipe, String(name))
			_:
				push_error("%s: unknown recipe kind '%s'" % [name, recipe.get("kind", "")])
		if not anim:
			model.free()
			return 1
		out.add_animation(StringName(name), anim)

	model.free()
	var err := ResourceSaver.save(out, OUTPUT)
	if err != OK:
		push_error("Saving %s failed: %d" % [OUTPUT, err])
		return 1
	print("Wrote %s -- %d clips" % [OUTPUT, StrikeRecipes.RECIPES.size()])
	return 0

func _source(player: AnimationPlayer, recipe: Dictionary, label: String) -> Animation:
	var name: String = recipe.get("source", "")
	if not player.has_animation(name):
		push_error("%s: source clip '%s' is not on the rig" % [label, name])
		return null
	return player.get_animation(name)

## Copies every track, keeping keys at or before the cutoff and adding one
## interpolated key exactly at it, so the clip ends mid-motion rather than
## snapping to whatever the last surviving key happened to be.
func _trim(player: AnimationPlayer, recipe: Dictionary, label: String) -> Animation:
	var source := _source(player, recipe, label)
	if not source:
		return null
	var cutoff: float = recipe["seconds"]
	if cutoff <= 0.0 or cutoff > source.length:
		push_error("%s: trim to %.3fs is outside the source (0..%.3f)"
				% [label, cutoff, source.length])
		return null
	var anim := _empty_like(source, cutoff)
	for track in source.get_track_count():
		var out_track := _copy_track_header(anim, source, track)
		for key in source.track_get_key_count(track):
			var t := source.track_get_key_time(track, key)
			if t > cutoff:
				break
			_insert(anim, out_track, source, track, t, t)
		_insert(anim, out_track, source, track, cutoff, cutoff)
	return anim

## Scales every key time by target/source, so the whole motion plays in the
## requested duration.
func _retime(player: AnimationPlayer, recipe: Dictionary, label: String) -> Animation:
	var source := _source(player, recipe, label)
	if not source:
		return null
	var target: float = recipe["seconds"]
	if target <= 0.0:
		push_error("%s: retime to %.3fs is not a duration" % [label, target])
		return null
	var scale := target / source.length
	var anim := _empty_like(source, target)
	for track in source.get_track_count():
		var out_track := _copy_track_header(anim, source, track)
		for key in source.track_get_key_count(track):
			var t := source.track_get_key_time(track, key)
			_insert(anim, out_track, source, track, t * scale, t)
	return anim

## A pose sequence sampled out of other clips, for a motion the rig does not
## contain at all.
func _stitch(player: AnimationPlayer, recipe: Dictionary, label: String) -> Animation:
	var samples: Array = recipe.get("samples", [])
	if samples.is_empty():
		push_error("%s: stitch recipe has no samples" % label)
		return null
	var length: float = recipe["seconds"]
	# Track list and paths come from a real clip rather than a hardcoded
	# list, so a re-import that renames bones breaks loudly here.
	var template: Animation = player.get_animation(String(samples[0]["clip"]))
	var anim := _empty_like(template, length)
	var index := {}
	for track in template.get_track_count():
		var out_track := _copy_track_header(anim, template, track)
		index["%d:%s" % [template.track_get_type(track), template.track_get_path(track)]] = out_track

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
		for track in template.get_track_count():
			var type := template.track_get_type(track)
			var path := template.track_get_path(track)
			var src := source.find_track(path, type)
			if src < 0:
				push_error("%s: clip '%s' has no track for %s" % [label, clip_name, path])
				return null
			# Keyed by type as well as path: the pelvis carries both a
			# rotation and a position track at the same path.
			var out_track: int = index["%d:%s" % [type, path]]
			if type == Animation.TYPE_ROTATION_3D:
				var rot := source.rotation_track_interpolate(src, at)
				var bone := String(path.get_concatenated_subnames())
				if offsets.has(bone):
					var deg: Vector3 = offsets[bone]
					rot = rot * Quaternion(Basis.from_euler(Vector3(
							deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))))
				anim.rotation_track_insert_key(out_track, t, rot.normalized())
			elif type == Animation.TYPE_POSITION_3D:
				anim.position_track_insert_key(out_track, t,
						source.position_track_interpolate(src, at))
	return anim

func _empty_like(source: Animation, length: float) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE
	return anim

func _copy_track_header(anim: Animation, source: Animation, track: int) -> int:
	var out_track := anim.add_track(source.track_get_type(track))
	anim.track_set_path(out_track, source.track_get_path(track))
	anim.track_set_interpolation_type(out_track, source.track_get_interpolation_type(track))
	return out_track

func _insert(anim: Animation, out_track: int, source: Animation, src_track: int,
		at: float, sample_at: float) -> void:
	match source.track_get_type(src_track):
		Animation.TYPE_ROTATION_3D:
			anim.rotation_track_insert_key(out_track, at,
					source.rotation_track_interpolate(src_track, sample_at).normalized())
		Animation.TYPE_POSITION_3D:
			anim.position_track_insert_key(out_track, at,
					source.position_track_interpolate(src_track, sample_at))
		Animation.TYPE_SCALE_3D:
			anim.scale_track_insert_key(out_track, at,
					source.scale_track_interpolate(src_track, sample_at))
