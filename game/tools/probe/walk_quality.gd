extends SceneTree
## Measures every walk the game plays (WalkMetrics.WALKS) and prints the
## numbers tests/test_walks_look_natural.gd gates on.
##
##   godot4 --headless --path game -s res://tools/probe/walk_quality.gd
##   ... -- --clips walk_stalk,run_jog   only those
##   ... -- --lib res://resources/animations/strike_clips.tres
##   ... -- --glb /tmp/walks.glb   a glb straight out of wrestling_clips.py
##       (AEGIS_ONLY_CLIPS=Walk_Stalk,... AEGIS_CLIP_OUTPUT=/tmp/walks.glb),
##       read at runtime by its authored clip names, so a walk can be tuned
##       without the import and the strike bake. The bake only renames and
##       re-wraps these clips (their recipes keep the authored length).
##
## One block per clip, then one table: the entrance walk each man makes his
## way to the ring on, and the gameplay walk, jog and run. All three men play
## the same base-rig clips for the gameplay gaits; their entrance walks are
## their own (Roman walk_slow_look, Cody walk_crowd, Kenny kenny_walk) over the
## generic entrance_walk the face-off walk-in uses.

const WalkMetrics := preload("res://tools/anim/walk_metrics.gd")
const RIG := "res://assets/characters/wrestler_base.glb"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var lib_path := "res://resources/animations/strike_clips.tres"
	var glb_path := ""
	var only: PackedStringArray = []
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--lib" and i + 1 < args.size():
			lib_path = args[i + 1]
		elif args[i] == "--clips" and i + 1 < args.size():
			only = args[i + 1].split(",")
		elif args[i] == "--glb" and i + 1 < args.size():
			glb_path = args[i + 1]
	var model: Node = (load(RIG) as PackedScene).instantiate()
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = load(lib_path) if glb_path.is_empty() else _from_glb(glb_path)
	var results := {}
	for clip: String in WalkMetrics.WALKS:
		if not only.is_empty() and not (clip in only):
			continue
		var w: Dictionary = WalkMetrics.WALKS[clip]
		results[clip] = WalkMetrics.analyze(skeleton, lib.get_animation(clip), w["speed"], w["cycles"])
		_print(clip, w, results[clip])
		var verdict := WalkMetrics.judge(clip, results[clip])
		var failed: PackedStringArray = []
		for g: String in verdict:
			if not verdict[g][0]:
				failed.append("%s %.3f (%s..%s)" % [g, verdict[g][1], str(verdict[g][2]), str(verdict[g][3])])
		print("  VERDICT      %s" % ("PASS, all %d gates" % verdict.size() if failed.is_empty()
				else "FAILS %d of %d: %s" % [failed.size(), verdict.size(), "; ".join(failed)]))
	print("")
	print("%-15s %-17s %5s %6s %6s %6s %6s %6s %5s %5s %5s %6s %s" % ["clip", "men", "skate",
			"hand m", "hands", "hips", "shldrs", "twist", "dip", "sway", "head", "stride", "gates failed"])
	for clip: String in results:
		var r: Dictionary = results[clip]
		var run := float(WalkMetrics.WALKS[clip]["speed"]) >= WalkMetrics.RUN_FROM
		var verdict := WalkMetrics.judge(clip, r)
		var failed := verdict.keys().filter(func(g: String) -> bool: return not verdict[g][0])
		print("%-15s %-17s %5.2f %6.2f %+6.2f %+6.2f %+6.2f %6.1f %5.1f %5.1f %5.1f %6.2f %d/%d %s" % [clip,
				",".join(WalkMetrics.WALKS[clip]["men"]), r["skate_ratio_min"], r["arm_swing_m_min"],
				r["hands_vs_feet"], r["hips_vs_feet"], r["shoulders_vs_feet"], r["torso_twist_stride_pp"],
				r["pelvis_dip_m"] * 100.0, r["pelvis_sway_m"] * 100.0, r["head_wobble_deg"],
				r["cadence_vs_run"] if run else r["stride_vs_natural"], failed.size(), verdict.size(),
				",".join(failed)])
	print("  hands/hips/shldrs: phase against the feet' lead, -1/+1/-1 natural. stride: x Alexander's"
			+ " natural stride for a walk, x a runner's cadence for a run.")
	model.free()
	quit(0)

## The glb's clips under the strike library's names (Walk_Stalk -> walk_stalk).
func _from_glb(path: String) -> AnimationLibrary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.bake_fps = 60.0
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return AnimationLibrary.new()
	var scene := doc.generate_scene(state, 60.0)
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var lib := AnimationLibrary.new()
	for name in player.get_animation_list():
		var anim: Animation = player.get_animation(name).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(StringName(String(name).to_lower()), anim)
	scene.free()
	return lib


func _print(clip: String, w: Dictionary, r: Dictionary) -> void:
	print("\n=== %s  (%s: %s)  %.3fs  %d cycle(s)  %.1f m/s  keys %.0f/s" % [clip, ",".join(w["men"]), w["where"],
			r["clip_seconds"], r["cycles"], r["speed"], r["keys_per_second"]])
	print("  skate        sole of the foot delivers %.2f-%.2f x the engine speed (rms error %.2f m/s, sideways %.2f); ankle %.2f-%.2f (gait_audit's reading)"
			% [r["skate_ratio_min"], r["skate_ratio_max"], r["skate_rms"], r["skate_side_rms"],
			r["skate_ankle_ratio_min"], r["skate_ankle_ratio_max"]])
	print("  seam         pose pop %.4f m; motion kink %.2f deg/frame (%s), %.2f x the worst elsewhere in the loop"
			% [r["seam_pop_m"], r["seam_kink_deg"], r["seam_kink_bone"], r["seam_kink_vs_loop"]])
	print("  arms         swing %.1f / %.1f deg (hand travel %.2f / %.2f m); opposes the legs at %.0f deg of phase (cos %.2f; corr %.2f / %.2f, zero lag %.2f); left vs right %.2f"
			% [r["arm_swing_deg_l"], r["arm_swing_deg_r"], r["arm_swing_m_l"], r["arm_swing_m_r"],
			r["arm_leg_phase_deg"], r["arm_leg_phase_cos"], r["arm_opposition_l"],
			r["arm_opposition_r"], r["arm_opposition_zero_lag"], r["arm_vs_arm"]])
	print("  torso        at the stride: pelvis yaw %.1f, chest yaw %.1f, twist between %.1f deg (pp); chest turns with the pelvis %.2f (-1 = against), %.2f of its size; chest pitch %.1f roll %.1f"
			% [r["pelvis_yaw_stride_pp"], r["chest_yaw_stride_pp"], r["torso_twist_stride_pp"],
			r["chest_vs_pelvis_phase"], r["chest_vs_pelvis_ratio"], r["chest_pitch_pp"], r["chest_roll_pp"]])
	print("  lines        against the feet' lead (%.2f m pp): hips %+.2f (+1 natural, %.3f m), shoulders %+.2f (-1 natural, %.3f m), hands %+.2f (-1 natural, +1 a pace, %.3f m)"
			% [r["feet_lead_pp_m"], r["hips_vs_feet"], r["hips_lead_pp_m"], r["shoulders_vs_feet"],
			r["shoulders_lead_pp_m"], r["hands_vs_feet"], r["hands_lead_pp_m"]])
	print("  pelvis       dip %.1f cm (harmonic %d, share of h2 %.2f), sway %.1f cm (harmonic %d), roll %.1f deg"
			% [r["pelvis_dip_m"] * 100.0, r["pelvis_dip_harmonic"], r["pelvis_dip_h2_share"],
			r["pelvis_sway_m"] * 100.0, r["pelvis_sway_harmonic"], r["pelvis_roll_pp"]])
	print("  head         wobble %.1f deg (yaw at the stride %.1f, pitch %.1f, roll %.1f; yaw overall %.1f); bob %.1f cm = %.2f of the pelvis's; sway %.1f cm"
			% [r["head_wobble_deg"], r["head_yaw_stride_pp"], r["head_pitch_residual_pp"],
			r["head_roll_residual_pp"], r["head_yaw_pp"], r["head_bob_m"] * 100.0, r["head_bob_vs_pelvis"],
			r["head_sway_m"] * 100.0])
	print("  stride       step %.2f m (%.2f of a leg), %.0f steps/min, Froude %.2f, stride %.2f x the natural %.2f m, cadence %.2f x a runner's %.0f; legs reach %.3f of full; duty %.2f, double support %.2f, flight %.2f"
			% [r["step_length_m"], r["step_per_leg"], r["cadence_spm"], r["froude"],
			r["stride_vs_natural"], r["natural_stride_m"], r["cadence_vs_run"], r["run_cadence_natural_spm"], r["leg_reach_max"], r["duty_factor"],
			r["double_support"], r["flight"]])
	print("  robotic      knee flex %.0f-%.0f deg, elbow %.0f-%.0f deg, foot pitch %.0f deg; frozen limbs %d (least %.1f deg); spine %.1f deg total (least %.1f); longest hold %d frames"
			% [r["knee_flex_min_deg"], r["knee_flex_max_deg"], r["elbow_flex_min_deg"],
			r["elbow_flex_max_deg"], r["foot_pitch_pp"], r["frozen_limbs"], r["min_limb_range_deg"],
			r["spine_range_sum_deg"], r["min_spine_range_deg"], r["longest_hold_frames"]])
