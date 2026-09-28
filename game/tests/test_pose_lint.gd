extends GdUnitTestSuite
## PoseLint over every authored clip (gauntlet/refs/animation_gap.md,
## Phase 1): the gate that would have failed on each backbend the owner had to
## find by eye. See tools/anim/pose_lint.gd for what each check means.

const AUTHORED_GLB := "res://assets/animations/wrestling_clips.glb"
const BASE_RIG := "res://assets/characters/wrestler_base.glb"


func _rig() -> Dictionary:
	var model: Node3D = auto_free((load(BASE_RIG) as PackedScene).instantiate())
	add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var clips: Node = (load(AUTHORED_GLB) as PackedScene).instantiate()
	var clip_player: AnimationPlayer = clips.find_child("AnimationPlayer", true, false)
	var library: AnimationLibrary = clip_player.get_animation_library(
			clip_player.get_animation_library_list()[0]).duplicate(true)
	clips.free()
	player.add_animation_library(&"authored", library)
	return {"player": player, "skeleton": skeleton, "library": library}


func _pose(rig: Dictionary, clip: String, fraction: float) -> void:
	var player: AnimationPlayer = rig["player"]
	var key := "authored/%s" % clip
	player.play(key)
	player.pause()
	player.seek(player.get_animation(key).length * fraction, true)


func test_no_authored_clip_breaks_a_body() -> void:
	var rig := _rig()
	var library: AnimationLibrary = rig["library"]
	var failures: Array[String] = []
	for clip in library.get_animation_list():
		if ClipIntent.EXEMPT.has(String(clip)):
			continue
		for step in PoseLint.SAMPLES:
			var f := float(step) / (PoseLint.SAMPLES - 1)
			_pose(rig, clip, f)
			for defect in PoseLint.check_pose(rig["skeleton"]):
				if defect.begins_with("below_mat") and (ClipIntent.OFF_MAT.has(String(clip))
						or ClipIntent.is_paired(String(clip))):
					continue
				failures.append("%s @%.1f: %s" % [clip, f, defect])
	assert_array(failures).override_failure_message(
			"PoseLint found %d defects:\n  %s" % [failures.size(), "\n  ".join(failures)]
			).is_empty()


func test_every_tagged_clip_leans_the_way_it_means_to() -> void:
	var rig := _rig()
	var failures: Array[String] = []
	for clip: String in ClipIntent.LEAN:
		var spec: Array = ClipIntent.LEAN[clip]
		_pose(rig, clip, spec[0])
		var lean := PoseLint.lean_deg(rig["skeleton"])
		var ok: bool = lean >= PoseLint.LEAN_MIN_DEG if spec[1] == "forward" \
				else lean <= -PoseLint.LEAN_MIN_DEG
		if not ok:
			failures.append("%s @%.2f leans %.1f deg, meant %s" % [clip, spec[0], lean, spec[1]])
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## The gate has to catch the defect it exists for: a backbend reads as one.
func test_lint_reads_a_backbend_as_a_backbend() -> void:
	var rig := _rig()
	_pose(rig, "Idle_Ready", 0.0)
	var sk: Skeleton3D = rig["skeleton"]
	var forward := PoseLint.lean_deg(sk)
	var spine := sk.find_bone("spine_01")
	# Tip the spine 30 degrees back about the hip line.
	var across := (PoseLint.at(sk, "thigh_r") - PoseLint.at(sk, "thigh_l")).normalized()
	var parent_basis := sk.get_bone_global_pose(sk.get_bone_parent(spine)).basis
	var axis_local := (parent_basis.inverse() * across).normalized()
	sk.set_bone_pose_rotation(spine, Quaternion(axis_local, deg_to_rad(30.0))
			* sk.get_bone_pose_rotation(spine))
	var tipped := PoseLint.lean_deg(sk)
	assert_float(absf(tipped - forward)).is_greater(20.0)
