extends Node
## The pre-match, logged: from the second man in his corner to eight seconds
## after the bell -- every beat and shot as it starts, both men's positions,
## states, planar speeds (m/s over the last 10 ticks) and the gap between them
## every 10 ticks, and the referee's spot. For the owner's reviews of 12 Nov
## ("a weird glitch that they go from the corner, sprint in and go back"; "the
## sequence goes on too long") and 16 Nov ("a glitch where they run to and from
## the corner ... make that whole sequence shorter").
##
## PREMATCH_DONE prints the corner-to-bell length and, after the bell, the
## furthest the men got apart and the first tick either was in a tie-up: the
## "back off then re-engage" shows up as a gap that grows before it closes.
##
##   godot --headless --path game --fixed-fps 6000 tools/probe/prematch_log.tscn

const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var a := scene.get_node("WrestlerA") as WrestlerController
	var b := scene.get_node("WrestlerB") as WrestlerController
	var ref := scene.get_node_or_null("RefereeActor") as Node3D
	var rang := [false]
	var bell_tick := [-1]
	var tick := [0]
	director.bell.connect(func(): rang[0] = true; bell_tick[0] = tick[0])
	var last_beat := -1
	var logging := false
	var from_tick := -1
	var last_pos := {a: a.global_position, b: b.global_position}
	var max_gap_after := 0.0
	var tie_tick := -1
	var gap_at_bell := -1.0
	while tick[0] < 60 * 600:
		await get_tree().physics_frame
		tick[0] += 1
		var t: int = tick[0]
		if rang[0] and t > bell_tick[0] + 480:
			break
		if director._beat < director._beats.size() and director._beat != last_beat:
			var bt: Dictionary = director._beats[director._beat]
			var shot := String(bt.get("shot", ""))
			if not logging and bt["kind"] == "pair":
				logging = true
				from_tick = t
			if logging:
				print("BEAT t%d +%.1fs #%d %s shot=%s ticks=%s" % [t, (t - from_tick) / 60.0,
						director._beat, bt["kind"], shot, bt.get("ticks", "-")])
			last_beat = director._beat
		var gap := Vector3(a.global_position.x - b.global_position.x, 0.0,
				a.global_position.z - b.global_position.z).length()
		if rang[0]:
			if gap_at_bell < 0.0:
				gap_at_bell = gap
			max_gap_after = maxf(max_gap_after, gap)
			if tie_tick < 0 and (a.fsm.current_state == WrestlerFSM.State.TIE_UP \
					or b.fsm.current_state == WrestlerFSM.State.TIE_UP \
					or a.fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD):
				tie_tick = t - bell_tick[0]
		if logging and t % 10 == 0:
			var va := _flat(a.global_position - last_pos[a]).length() * 6.0
			var vb := _flat(b.global_position - last_pos[b]).length() * 6.0
			last_pos = {a: a.global_position, b: b.global_position}
			print("POS t%d +%.1fs A %s %s v%.2f  B %s %s v%.2f  gap %.2f  ref %s%s" % [t,
					(t - from_tick) / 60.0,
					WrestlerFSM.State.keys()[a.fsm.current_state], _v(a.global_position), va,
					WrestlerFSM.State.keys()[b.fsm.current_state], _v(b.global_position), vb,
					gap, _v(ref.global_position) if ref else "-", "  (bell)" if rang[0] else ""])
	print("PREMATCH_DONE from_corners_to_bell=%.2fs gap_at_bell=%.2f max_gap_after_bell=%.2f first_tie_up_after_bell_ticks=%d" % [
			(bell_tick[0] - from_tick) / 60.0, gap_at_bell, max_gap_after, tie_tick])
	get_tree().quit()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _v(p: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]
