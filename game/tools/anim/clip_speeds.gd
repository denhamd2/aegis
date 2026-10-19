extends SceneTree
## Per-frame whole-body angular speed of named clips, with the frames
## test_clip_cadence.gd counts as snaps marked -- for finding where a clip
## lurches before adding in-between keys (wrestling_clips.py).
##
##   godot --headless --path game -s res://tools/anim/clip_speeds.gd -- Clip_A Clip_B

const Cadence := preload("res://tests/test_clip_cadence.gd")


func _init() -> void:
	var root: Node = (load(Cadence.CLIPS) as PackedScene).instantiate()
	var player := root.find_children("", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in OS.get_cmdline_user_args():
		if not player.has_animation(clip):
			print("%s: no such clip" % clip)
			continue
		var speed := Cadence.speeds(player.get_animation(clip))
		var cells: Array[String] = []
		for f in speed.size():
			var near: Array[float] = []
			for g in range(maxi(0, f - Cadence.SNAP_WINDOW),
					mini(speed.size(), f + Cadence.SNAP_WINDOW + 1)):
				if g != f:
					near.append(speed[g])
			near.sort()
			var med: float = near[near.size() / 2] if not near.is_empty() else 0.0
			var snap := f > 0 and f < speed.size() - 1 and med > 2.0 \
					and speed[f] > Cadence.SNAP * med
			cells.append("%d:%.0f%s" % [f + 1, speed[f], "!" if snap else ""])
		print("%s  jerk %.1f  snaps %d\n  %s" % [clip, Cadence.jerk(speed),
				Cadence.snaps(speed), "  ".join(cells)])
	root.free()
	quit()
