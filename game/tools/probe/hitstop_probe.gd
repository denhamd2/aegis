extends Node
## Does the impact hold actually hold, and for how long?
##
## `move_def.gd` argues hitstop is "the cheapest weight in the game" because
## "two or three ticks of hold reads as contact". That shipped verified on
## numbers that never looked at a pose: tests/test_hit_reactions.gd checks
## only that no move asks for NEGATIVE hitstop.
##
## Rendered frames cannot answer it either, and that is worth stating because
## it is the obvious thing to try. exchange_shot.gd grabs every tick, but the
## hold is animation-only by design -- the bodies keep moving, and its camera
## tracks the midpoint between them -- so the knockback pans the whole frame
## and swamps a three-tick freeze. Measured: the frame-to-frame delta at the
## heavy kick's contact tick is 18,650 changed pixels against 373,087 on the
## tick after, and that 20x is the camera, not the pose.
##
## So this measures the SKELETON, which no camera can confuse: a hash of every
## bone's local pose, once per physics tick. A held pose repeats its hash. It
## also prints the two things that could break the hold independently --
##
##   mixer   whether the AnimationTree is in MANUAL (the freeze) or PHYSICS
##   grip    _grip_blend, which _update_grip_ik() steps EVERY tick from
##           _physics_process regardless of hitstop, and whose SkeletonIK3D
##           chains run AFTER the mixer (SkeletonModifier3D), so they can keep
##           solving while the mixer is frozen
##
## -- because "the body is held" and "every bone is held" are different
## claims, and the arms are where they come apart.
##
## Usage:
##   godot4 --headless --path game --fixed-fps 60 \
##       tools/probe/hitstop_probe.tscn -- --moves strike_kick_heavy,strike_cross
##
## --fixed-fps 60 is not optional. Without it the main loop runs several
## physics ticks per iteration (measured: 8 under llvmpipe), and a 3-tick hold
## disappears between two samples.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVE_DIR := "res://resources/moves/"

var _moves: Array = ["strike_kick_heavy", "strike_cross"]
var _tail := 12


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--moves" and i + 1 < args.size():
			_moves = Array(args[i + 1].split(","))
		elif args[i] == "--tail" and i + 1 < args.size():
			_tail = int(args[i + 1])

	var scene: Node = load(MATCH_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	attacker.is_ai = false
	defender.is_ai = false

	for move_id: String in _moves:
		await _throw(attacker, defender, move_id)
	get_tree().quit()


## A hash of every bone's local pose. Local rather than global on purpose:
## a global pose moves when the wrestler's root moves, and the root IS meant
## to keep moving during hitstop (knockback is not frozen). Local pose is the
## animation's own output and nothing else.
func _pose_hash(w: WrestlerController) -> int:
	if not w.skeleton:
		return 0
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for i in w.skeleton.get_bone_count():
		var t := w.skeleton.get_bone_pose(i)
		ctx.update(var_to_bytes(t))
	return ctx.finish().decode_u32(0)


func _mixer_mode(w: WrestlerController) -> String:
	if not w.anim_tree:
		return "none"
	return "MANUAL" if w.anim_tree.callback_mode_process \
			== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL else "phys"


func _throw(attacker: WrestlerController, defender: WrestlerController,
		move_id: String) -> void:
	var path := "%s%s.tres" % [MOVE_DIR, move_id]
	if not ResourceLoader.exists(path):
		print("!! no move %s" % path)
		return
	var move: MoveDef = load(path)

	var half := WrestlerController.strike_reach(move) * 0.85 * 0.5
	_reset(attacker, Vector3(-half, 0.0, 0.0))
	_reset(defender, Vector3(half, 0.0, 0.0))
	attacker.look_at(defender.global_position, Vector3.UP)
	defender.look_at(attacker.global_position, Vector3.UP)
	await get_tree().physics_frame

	attacker._play_strike_clip(move)
	attacker._start_move(WrestlerFSM.State.STRIKE, move)

	print("\n=== %s  hitstop_frames=%d  startup=%d ==="
			% [move_id, move.hitstop_frames, move.startup_frames])
	print("  tick  atk_pose held mixer  hs grip state      | def_pose held mixer  hs grip state")
	var prev := {"a": 0, "b": 0}
	var held := {"a": 0, "b": 0}
	for tick in move.total_frames() + _tail:
		var row := "  t=%02d" % tick
		for who in [["a", attacker], ["b", defender]]:
			var key: String = who[0]
			var w: WrestlerController = who[1]
			var h := _pose_hash(w)
			var same: bool = h == prev[key]
			if same:
				held[key] += 1
			prev[key] = h
			row += "  %08x %-4s %-6s %d %.2f %-10s" % [
					h, "HELD" if same else "-", _mixer_mode(w),
					w._hitstop_ticks, w._grip_blend,
					WrestlerFSM.State.keys()[w.fsm.current_state]]
		print(row)
		await get_tree().physics_frame
	print("  held ticks: attacker %d, defender %d  (asked for %d each)"
			% [held["a"], held["b"], move.hitstop_frames])


func _reset(w: WrestlerController, where: Vector3) -> void:
	w._active_move = null
	w._move_ticks_remaining = 0
	w._active_move_hit_applied = false
	w._pending_hits.clear()
	w._pending_hit_reaction = null
	w._hitstop_ticks = 0
	w.velocity = Vector3.ZERO
	w.global_position = where
	if w.fsm.current_state != WrestlerFSM.State.IDLE:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
