extends GdUnitTestSuite
## Holds the line on "stop motion" in the authored clips.
##
## Every clip in wrestling_clips.glb is sampled at its own 30 fps and, frame by
## frame, the whole body's angular speed is summed over every rotation track.
## Two things read as stop motion on screen and are counted here:
##
##   hold  a run of HOLD_FRAMES or more frames with the body essentially still
##         (under STILL degrees a frame, summed over every bone) in the middle
##         of a clip -- a pose frozen like a statue;
##   snap  one frame moving more than SNAP times the median of its neighbours
##         -- a jerk between two smooth stretches.
##
## Measured when this was written (auto handles plus overlap in
## tools/blender/wrestling_clips.py): 8 holds, nearly all of them near-still
## idles and stands that BodyLife breathes over in the match, and 24 snaps.
## Before that pass, 45 and 105. The budgets sit just above today's numbers so a pass
## that brings them back fails here; tighten them as clips are fixed.
const CLIPS := "res://assets/animations/wrestling_clips.glb"
const FPS := 30.0
const STILL := 1.5
const HOLD_FRAMES := 4
const SNAP := 3.5
const SNAP_WINDOW := 5
const HOLD_BUDGET := 9
const SNAP_BUDGET := 25


func _player() -> AnimationPlayer:
	var scene := load(CLIPS) as PackedScene
	var root := scene.instantiate()
	auto_free(root)
	return root.find_children("", "AnimationPlayer", true, false)[0] as AnimationPlayer


## Per-frame summed angular speed of one clip, degrees per frame.
static func speeds(anim: Animation) -> PackedFloat32Array:
	var tracks: Array[int] = []
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks.append(t)
	var frames := int(round(anim.length * FPS))
	var out := PackedFloat32Array()
	var prev: Array[Quaternion] = []
	for f in frames + 1:
		var time := minf(f / FPS, anim.length)
		var now: Array[Quaternion] = []
		for t in tracks:
			now.append(anim.rotation_track_interpolate(t, time))
		if not prev.is_empty():
			var s := 0.0
			for i in now.size():
				s += rad_to_deg(prev[i].angle_to(now[i]))
			out.append(s)
		prev = now
	return out


static func holds(speed: PackedFloat32Array) -> int:
	var n := 0
	var run := 0
	for f in speed.size():
		if speed[f] < STILL:
			run += 1
		else:
			if run >= HOLD_FRAMES and f - run > 0:
				n += 1
			run = 0
	return n


static func snaps(speed: PackedFloat32Array) -> int:
	var n := 0
	for f in range(1, speed.size() - 1):
		var near: Array[float] = []
		for g in range(maxi(0, f - SNAP_WINDOW), mini(speed.size(), f + SNAP_WINDOW + 1)):
			if g != f:
				near.append(speed[g])
		near.sort()
		var med := near[near.size() / 2]
		if med > 2.0 and speed[f] > SNAP * med:
			n += 1
	return n


## The moves seen most in a match, whose in-between keys are worked by hand
## (gauntlet/refs/next_steps.md, Fight Forever smoothness).
const HERO := [
	"Cross_Rhodes_Attacker", "Cross_Rhodes_Defender",
	"Pedigree_Attacker", "Pedigree_Defender",
	"FF_Tiger_Driver_98_Attacker", "FF_Tiger_Driver_98_Defender",
	"Cody_Cutter_Attacker", "Cody_Cutter_Defender",
	"Disaster_Kick_Attacker", "Disaster_Kick_Defender",
	"Vertical_Suplex_Attacker", "Vertical_Suplex_Defender",
	"Powerslam_Attacker", "Powerslam_Defender",
	"Alabama_Slam_Attacker", "Alabama_Slam_Defender",
	"Run_Spear_Attacker", "Run_Spear_Defender",
	"Superman_Punch_Attacker", "Superman_Punch_Defender",
]
## Ceiling on the hero clips' summed jerk, set at today's figure; lower it as
## the in-between passes land.
const HERO_JERK_BUDGET := 952.0


## Mean change in whole-body angular speed from one frame to the next,
## degrees per frame per frame: how unevenly a clip moves. Fight Forever's
## captured moves change speed a little every frame; a clip that coasts
## between sparse keys and lurches through them scores high.
static func jerk(speed: PackedFloat32Array) -> float:
	if speed.size() < 2:
		return 0.0
	var total := 0.0
	for f in range(1, speed.size()):
		total += absf(speed[f] - speed[f - 1])
	return total / float(speed.size() - 1)


func test_the_hero_moves_move_evenly() -> void:
	var player := _player()
	var total := 0.0
	var lines: Array[String] = []
	for clip: String in HERO:
		assert_bool(player.has_animation(clip)).override_failure_message(
			"no clip %s" % clip).is_true()
		if not player.has_animation(clip):
			continue
		var j := jerk(speeds(player.get_animation(clip)))
		total += j
		lines.append("%s %.1f" % [clip, j])
	print("CLIP_JERK total %.1f -- %s" % [total, ", ".join(lines)])
	assert_float(total).is_less_equal(HERO_JERK_BUDGET)


## The weapon swings (gauntlet/refs/nhb/weapon_review.md): their in-between
## pass in wrestling_clips.py (SWING_INBETWEENS) took the 17 from 1212 to
## 1118 (today's figure); the worst, the chair, from 88 to 56. A swing is fast by
## nature and scores above a slam, so this holds the line rather than asks
## for the hero moves' evenness.
const SWINGS := [
	"Weapon_Overhead", "Weapon_Chair_Overhead", "Weapon_Side", "Weapon_Bat",
	"Weapon_Slapshot", "Weapon_Kendo_Chop", "Weapon_Two_Hand_Slam",
	"Weapon_Shovel_Overhead", "Weapon_Crutch_Overhead", "Weapon_Bonk_Overhand",
	"Weapon_Flat_Face", "Weapon_Chain_Fist", "Weapon_Ladder_Overhead",
	"Weapon_Thrust", "Weapon_Whip", "Weapon_Chop", "Weapon_Throw",
]
const SWING_JERK_BUDGET := 1118.0


func test_the_weapon_swings_move_evenly() -> void:
	var player := _player()
	var total := 0.0
	for clip: String in SWINGS:
		assert_bool(player.has_animation(clip)).override_failure_message(
			"no clip %s" % clip).is_true()
		if player.has_animation(clip):
			total += jerk(speeds(player.get_animation(clip)))
	print("SWING_JERK total %.1f" % total)
	assert_float(total).is_less_equal(SWING_JERK_BUDGET)


func test_the_clips_neither_freeze_nor_jerk() -> void:
	var player := _player()
	var total_holds := 0
	var total_snaps := 0
	var worst := []
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for clip in lib.get_animation_list():
			var speed := speeds(lib.get_animation(clip))
			var h := holds(speed)
			var s := snaps(speed)
			total_holds += h
			total_snaps += s
			if h + s > 0:
				worst.append("%s (holds %d, snaps %d)" % [clip, h, s])
	print("CLIP_CADENCE holds %d snaps %d" % [total_holds, total_snaps])
	assert_int(total_holds) \
		.override_failure_message("%d dead holds (budget %d): %s" % [total_holds, HOLD_BUDGET, ", ".join(worst)]) \
		.is_less_equal(HOLD_BUDGET)
	assert_int(total_snaps) \
		.override_failure_message("%d snaps (budget %d): %s" % [total_snaps, SNAP_BUDGET, ", ".join(worst)]) \
		.is_less_equal(SNAP_BUDGET)
