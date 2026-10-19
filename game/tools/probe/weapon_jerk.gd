extends SceneTree
## Weapon swing evenness, for review: each Weapon_* clip's jerk (the cadence
## gate's metric, tests/test_clip_cadence.gd) and its snaps.
##
##   godot --headless --path game -s res://tools/probe/weapon_jerk.gd

const Cadence := preload("res://tests/test_clip_cadence.gd")


func _init() -> void:
	var scene := load("res://assets/animations/wrestling_clips.glb") as PackedScene
	var root := scene.instantiate()
	var player := root.find_children("", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var total := 0.0
	for clip in player.get_animation_list():
		if not String(clip).begins_with("Weapon_"):
			continue
		var s := Cadence.speeds(player.get_animation(clip))
		var j := Cadence.jerk(s)
		total += j
		var peak := 0.0
		for v in s:
			peak = maxf(peak, v)
		print("WEAPON_JERK %-28s jerk %6.1f peak %6.1f snaps %d" % [clip, j, peak, Cadence.snaps(s)])
	print("WEAPON_JERK total %.1f" % total)
	root.free()
	quit()
