extends Node
## Times the hand-off from the VS card into the match, frame by frame: how long
## the select-to-entrance screen holds, which frames stall, and where the menu
## music is while it does (the owner, 19 Oct: the black match-up card "stays on
## the screen for a while and the music stops").
##
## Usage:
##   xvfb-run -a godot --path game --resolution 1280x720 \
##       tools/probe/launch_timing.tscn

const TITLE_SCENE := "res://scenes/title.tscn"


func _ready() -> void:
	var title: CanvasLayer = load(TITLE_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	get_tree().current_scene = title
	await get_tree().process_frame
	var screen: TitleScreen = title.get_node("Draw")
	screen._accept()
	screen._accept()
	screen._accept()
	var start := Time.get_ticks_msec()
	var last := start
	var waited := 0.0
	var revealed_at := -1
	while waited < 150.0:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		var stinger: Node = null
		for c in get_tree().root.get_children():
			if c is MatchStinger:
				stinger = c
		var music := get_tree().root.find_child("MenuMusic", true, false) as AudioStreamPlayer
		var stage := "-" if stinger == null else "%d bar %.2f" % [(stinger as MatchStinger)._stage, (stinger as MatchStinger)._shown]
		var vol := "gone" if music == null else "%.0f dB %s" % [music.volume_db,
				"playing" if music.playing else "stopped"]
		if now - last > 50:
			print("STALL %5d ms at %6.2f s  stinger=%s music=%s" % [now - last,
					(now - start) / 1000.0, stage, vol])
		if stinger != null and (stinger as MatchStinger)._stage == MatchStinger.Stage.OUT \
				and revealed_at < 0:
			revealed_at = now
			print("REVEAL at %.2f s  music=%s" % [(now - start) / 1000.0, vol])
		if revealed_at > 0 and now - revealed_at > 3000:
			break
		last = now
		waited = (now - start) / 1000.0
	print("LAUNCH_TIMING done")
	get_tree().quit()
