extends Node
class_name FootballMatchPresentation
## Paused-football broadcast sequences. Replays animate collision-free ghosts.
enum Phase { IDLE, GOAL, REPLAY, FULL_TIME, RESULTS }
var game: Node3D
var buffer := FootballReplayBuffer.new()
var phase := Phase.IDLE
var elapsed := 0.0
var _pending_goal := ""
var _pending_full_time := false
var _pending_incident: StringName = &""
var _incident_delay := 0.0
var _incident_ready := false
var _incident_entry: Dictionary = {}
var _after_replay: StringName = &""
var _goal_team := ""
var _focus: Node3D
var _celebrators: Array[FootballPlayer] = []
var _pairs: Array[Dictionary] = []
var director := FootballShotDirector.new()
var _replay_duration := 0.0
var _wide_duration := 0.0
var _replay_start := 0.0
var _detail_start := 0.0
var _playhead := 0.0
var camera: Camera3D
var layer: CanvasLayer
var panel: Panel
var caption: Label
var hint: Label
var results: Control
var ghosts: Array[Node3D] = []
var ghost_skeletons: Array[Skeleton3D] = []
var ghost_ball: Node3D
var ghost_world: Node3D
var _entry: Dictionary = {}
var _saved: Dictionary = {}
var _hud_visibility: Dictionary = {}
var _actor_states: Array[Dictionary] = []
var _detector_states: Array[Dictionary] = []
func setup(match_scene: Node3D) -> void:
	game=match_scene;buffer.setup(game)
	game.events.occurred.connect(_on_event)
	camera=Camera3D.new();camera.name="IncidentCamera";camera.fov=52;camera.near=.04
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.add_child(camera)
	layer=CanvasLayer.new();layer.layer=12;add_child(layer)
	var banner := FootballLowerThird.new()
	panel=banner;layer.add_child(panel)
	caption=banner.title
	hint=banner.subtitle;hint.text="SPACE / ENTER  Skip"
	panel.hide()
func active() -> bool: return phase != Phase.IDLE
func replaying() -> bool: return phase == Phase.REPLAY
func _on_event(event: FootballMatchEvent) -> void:
	if active(): return
	if event.kind in [FootballMatchEvent.Kind.GOAL, FootballMatchEvent.Kind.CARD, FootballMatchEvent.Kind.POST] or event.action in [&"goalkeeper_save", &"goalkeeper_catch"]:
		buffer.mark_incident(event)
	match event.kind:
		FootballMatchEvent.Kind.GOAL:
			_pending_goal=String(event.action)
		FootballMatchEvent.Kind.FULL_TIME:
			_pending_full_time=true
		FootballMatchEvent.Kind.CARD:
			if event.action == &"red" or int(event.actor.get_meta("yellow_cards",0))>=1:
				_queue_incident(&"card")
		FootballMatchEvent.Kind.POST:
			_pending_incident=&"post";_incident_delay=.45
		FootballMatchEvent.Kind.BALL_CONTACT:
			if event.action in [&"goalkeeper_save",&"goalkeeper_catch"]:
				_pending_incident=&"save";_incident_delay=.45
		FootballMatchEvent.Kind.RESTART:
			if _pending_incident != &"": _queue_incident(_pending_incident);_pending_incident=&""
			buffer.clear_history()
func update(delta: float) -> bool:
	if phase == Phase.RESULTS: return true
	if phase == Phase.REPLAY:
		elapsed+=delta
		_playhead = _replay_start + elapsed if elapsed < _wide_duration else _detail_start + (elapsed - _wide_duration) * .5
		buffer.apply_frame(_entry,_playhead,ghosts,ghost_ball,ghost_skeletons)
		_track_replay(delta)
		if elapsed>=_replay_duration: _finish_replay()
		return true
	if not _pending_goal.is_empty():
		_start_goal(_pending_goal);_pending_goal=""
	if _pending_full_time:
		_start_full_time();_pending_full_time=false
	if phase == Phase.GOAL:
		elapsed+=delta
		buffer.sample(delta,elapsed<.9)
		_animate_celebration(delta)
		if elapsed>=6:
			var entry := buffer.bookmark(&"goal")
			if entry.is_empty(): _finish_goal()
			else: start_replay(entry,&"goal")
		return true
	if phase == Phase.FULL_TIME:
		elapsed+=delta
		_animate_full_time(delta)
		if elapsed>=12: _show_results()
		return true
	buffer.sample(delta,not game._kickoff_pending and game._goal_pause_timer<=0 and not game.ball.freeze)
	if _pending_incident != &"":
		_incident_delay-=delta
		if _incident_delay<=0:
			_queue_incident(_pending_incident);_pending_incident=&""
	if _incident_ready and game.restart.active() and not game.restart.released and not _incident_entry.is_empty():
		_incident_ready=false
		var entry: Dictionary=_incident_entry.duplicate()
		entry.frames=entry.frames.slice(maxi(0,entry.frames.size()-180))
		entry.duration=float(entry.frames[-1].time)-float(entry.frames[0].time)
		start_replay(entry,&"incident")
		return true
	return false
func _queue_incident(kind: StringName) -> void:
	_incident_entry=buffer.bookmark(kind)
	_incident_ready=not _incident_entry.is_empty()

func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or event.keycode not in [KEY_SPACE,KEY_ENTER]: return false
	if phase==Phase.GOAL: _finish_goal();return true
	if phase==Phase.REPLAY: _finish_replay();return true
	if phase==Phase.FULL_TIME: _show_results();return true
	return false
func cancel_for_restart() -> void:
	if replaying(): _restore_replay()
	if active():
		for actor in buffer.actors: actor.get_node("Visual").end_presentation()
		game.camera_rig.presentation_override=false;game.camera_rig.camera.make_current()
		FootballCameraOptics.for_camera(camera).clear();camera.current=false;panel.hide()
		_restore_match_prompts()
	phase=Phase.IDLE;game._presentation_active=false
	_pending_goal="";_pending_incident=&"";_incident_ready=false;_incident_entry={}
	buffer.clear_history()

func _hide_match_prompts() -> void:
	if not _hud_visibility.is_empty(): return
	for name in ["Message","Controls","TacticalRadar","Power"]:
		var node:=game.get_node_or_null("HUD/"+name) as CanvasItem
		if node!=null: _hud_visibility[name]=node.visible;node.hide()
func _restore_match_prompts() -> void:
	for name in _hud_visibility:
		var node:=game.get_node_or_null("HUD/"+str(name)) as CanvasItem
		if node!=null:node.visible=_hud_visibility[name]
	_hud_visibility.clear()

func _set_caption(text: String) -> void:
	_hide_match_prompts()
	caption.text=text;panel.show();panel.modulate.a=0
func _camera_on(target: Vector3, delta: float, offset := Vector3(3.5,1.7,4.0)) -> void:
	var subject := _focus
	var id: StringName = &"celebration_wide"
	var look := target + Vector3.UP
	var station := target + Vector3(-6, 3.0, 8)
	var lens := 48.0
	if phase == Phase.GOAL:
		if elapsed >= 4:
			id = &"scorer_close"; lens = 28
			look = target + Vector3.UP * 1.56
			station = target + subject.global_basis * Vector3(.35, 1.65, -2.5)
		elif elapsed >= 2:
			id = &"scorer_medium"; lens = 40
			station = target + subject.global_basis * Vector3(2.6, 1.8, -4.2)
	else:
		id = &"full_time_wide"
		if elapsed >= 7 and not _pairs.is_empty():
			id = &"handshake_close"; lens = 38
			var pair: Dictionary = _pairs[0]
			look = (pair.home.position + pair.away.position) * .5 + Vector3.UP * 1.25
			station = look + pair.line.cross(Vector3.UP) * 3.2 + Vector3.UP * .35
		elif elapsed >= 3:
			id = &"full_time_medium"; lens = 40
			station = target + offset
	director.frame(camera, id, look, station, lens, delta, game, subject)
	if phase == Phase.GOAL and game.grass_detail != null:
		game.grass_detail.prepare(target + subject.global_basis * (Vector3(2.6, 1.8, -4.2) if elapsed < 2 else Vector3(.35, 1.65, -2.5)))
	(panel as FootballLowerThird).reveal(elapsed)
func _start_goal(team: String) -> void:
	director.reset()
	phase=Phase.GOAL;elapsed=0;_goal_team=team;game._presentation_active=true
	game._goal_pause_timer=6
	game._set_players_physics_enabled(false)
	var players: Array=game._home_players if team=="Beechlawn Rovers" else game._away_players
	_focus=game.ball.last_touch_player if is_instance_valid(game.ball.last_touch_player) and game.ball.last_touch_player.team_name==StringName(team) else null
	if _focus==null: _focus=game._nearest_outfielder(players,Vector2(game.ball.position.x,game.ball.position.z))
	_celebrators.clear()
	for actor: FootballPlayer in players:
		if actor.profile.role=="goalkeeper" and actor!=_focus:continue
		if actor==_focus or actor.position.distance_to(_focus.position)<12:
			_celebrators.append(actor)
			actor.get_node("Visual").play_presentation(&"AN_Beechlawn_Celebrate")
	for actor in buffer.actors:
		var marker:=actor.get_node_or_null("ControlMarker")
		if marker!=null:marker.hide()
	game.camera_rig.presentation_override=true;camera.position=game.camera_rig.camera.global_position;camera.make_current()
	_set_caption("GOAL · "+team.to_upper())
func _animate_celebration(delta: float) -> void:
	if not is_instance_valid(_focus):return
	for actor in _celebrators:
		if actor==_focus:continue
		var offset:=_focus.position-actor.position;offset.y=0
		if offset.length()>1.6 and elapsed<2.5:
			_walk(actor,_focus.position-offset.normalized()*1.4,delta)
		elif actor.get_node("Visual").animation_player.current_animation!=&"AN_Beechlawn_Celebrate":
			actor.get_node("Visual").play_presentation(&"AN_Beechlawn_Celebrate")
	_camera_on(_focus.position,delta)
func _walk(actor: FootballPlayer,target: Vector3,delta: float) -> bool:
	var offset:=target-actor.position;offset.y=0
	if offset.length()<.015:return true
	actor.position+=offset.normalized()*minf(offset.length(),delta*1.35)
	actor.position.y=PitchSurface.height_at(actor.position.x,actor.position.z) if game.terrain_enabled else 0
	actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-offset.x,-offset.z),1-exp(-delta*8))
	var visual:=actor.get_node("Visual") as FootballerVisual
	if visual.animation_player.current_animation!=&"AN_Beechlawn_WalkOn":visual.play_presentation(&"AN_Beechlawn_WalkOn")
	return false
func _finish_goal() -> void:
	if phase==Phase.REPLAY: _restore_replay()
	for actor in buffer.actors:
		actor.get_node("Visual").end_presentation()
	phase=Phase.IDLE;game._presentation_active=false;game._goal_pause_timer=0
	_pending_goal="";_pending_incident=&"";_incident_ready=false
	panel.hide();_restore_match_prompts();FootballCameraOptics.for_camera(camera).clear();camera.current=false;game.camera_rig.presentation_override=false
	game.camera_rig.camera.make_current();game._prepare_kickoff(game._kickoff_team)
	game.camera_rig.reset_tracking()
	for actor in game._home_players+game._away_players: game._set_marker_visibility(actor,not game._spectator_mode and actor==game.player)
	buffer.clear_history()
func _start_full_time() -> void:
	if phase==Phase.REPLAY:_restore_replay()
	director.reset()
	phase=Phase.FULL_TIME;elapsed=0;game._presentation_active=true
	game._set_players_physics_enabled(false)
	var winner: StringName=&"none"
	if game._home_score>game._away_score:winner=&"Beechlawn Rovers"
	elif game._away_score>game._home_score:winner=&"Boardeaux"
	for actor in buffer.actors:
		var marker:=actor.get_node_or_null("ControlMarker")
		if marker!=null:marker.hide()
		var visual:=actor.get_node("Visual") as FootballerVisual
		if actor is FootballPlayer and actor.team_name==winner:visual.play_presentation(&"AN_Beechlawn_Celebrate")
		else:visual.play_presentation(&"AN_Beechlawn_Idle")
	_build_handshakes()
	_focus=game._home_players[0] if winner!=&"Boardeaux" else game._away_players[0]
	game.camera_rig.presentation_override=true;camera.position=game.camera_rig.camera.global_position;camera.make_current()
	_set_caption("FULL TIME · "+("DRAW" if winner==&"none" else String(winner).to_upper()+" WIN"))
func _build_handshakes() -> void:
	_pairs.clear()
	var used:=[]
	for home: FootballPlayer in game._home_players:
		var best: FootballPlayer;var gap:=9.0
		for away: FootballPlayer in game._away_players:
			if used.has(away):continue
			var distance:=home.position.distance_to(away.position)
			if distance<gap:gap=distance;best=away
		if best==null:continue
		used.append(best)
		var line: Vector3=best.position-home.position;line.y=0
		line=line.normalized() if line.length()>.1 else Vector3.RIGHT
		var middle: Vector3=(home.position+best.position)*.5
		_pairs.append({"home":home,"away":best,"home_target":middle-line*.42,"away_target":middle+line*.42,"line":line})
func _animate_full_time(delta: float) -> void:
	if elapsed>=3.5:
		if not _pairs.is_empty(): _focus=_pairs[0].home
		for pair in _pairs:
			var a: FootballPlayer=pair.home;var b: FootballPlayer=pair.away
			var reached_a:=_walk(a,pair.home_target,delta)
			var reached_b:=_walk(b,pair.away_target,delta)
			if reached_a and reached_b:
				a.rotation.y=atan2(-pair.line.x,-pair.line.z);b.rotation.y=atan2(pair.line.x,pair.line.z)
				for actor in [a,b]:
					if actor.get_node("Visual").animation_player.current_animation!=&"AN_Beechlawn_Handshake":actor.get_node("Visual").play_presentation(&"AN_Beechlawn_Handshake")
	if is_instance_valid(_focus):_camera_on(_focus.position,delta)
func _show_results() -> void:
	phase=Phase.RESULTS;panel.hide()
	FootballCameraOptics.for_camera(camera).clear()
	results=ColorRect.new();results.name="MatchResults";(results as ColorRect).color=Color(0.015,.025,.055,.90)
	layer.add_child(results);results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box:=VBoxContainer.new();results.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left=-430;box.offset_right=430;box.offset_top=-190;box.offset_bottom=190
	box.add_theme_constant_override("separation",22)
	for text in ["FULL TIME","BEECHLAWN ROVERS  %d — %d  BOARDEAUX"%[game._home_score,game._away_score]]:
		var label:=Label.new();label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",36 if text=="FULL TIME" else 28)
		preload("res://scripts/ui/broadcast_style.gd").label(label);box.add_child(label)
	for text in ["REMATCH","TITLE SCREEN"]:
		var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(500,64);button.add_theme_font_size_override("font_size",26);box.add_child(button)
		if text=="REMATCH":
			button.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/match_11v11.tscn"))
			button.grab_focus()
		else:button.pressed.connect(func():get_node("/root/MatchSession").return_to_title())
func start_replay(entry: Dictionary, after: StringName = &"incident") -> bool:
	if entry.is_empty() or phase not in [Phase.IDLE,Phase.GOAL]:return false
	_entry=entry;_after_replay=after
	director.reset()
	_plan_replay()
	_save_replay_state()
	phase=Phase.REPLAY;elapsed=0;game._presentation_active=true
	ghost_world=Node3D.new();ghost_world.name="ReplayGhosts";game.add_child(ghost_world)
	ghosts.clear();ghost_skeletons.clear()
	for actor in buffer.actors:
		var ghost:=Node3D.new();ghost_world.add_child(ghost);ghosts.append(ghost)
		var visual:=actor.get_node("Visual").duplicate(0) as Node3D
		# Copy the runtime mesh/material tree, without reconstructing its packed
		# proxy scene or rerunning FootballerVisual appearance initialization.
		visual.process_mode=Node.PROCESS_MODE_DISABLED
		ghost.add_child(visual)
		var face := visual.find_child("Skin_Head",true,false) as MeshInstance3D
		if face != null: ghost.set_meta("replay_head",face)
		var tree:=visual.get_node_or_null("AnimationTree") as AnimationTree
		if tree!=null:tree.active=false
		var player:=visual.get_node_or_null("Rig/AnimationPlayer") as AnimationPlayer
		if player!=null:player.stop()
		var found:=visual.find_children("*","Skeleton3D",true,false)
		ghost_skeletons.append(found[0] as Skeleton3D if not found.is_empty() else null)
	ghost_ball=Node3D.new();ghost_world.add_child(ghost_ball)
	ghost_ball.add_child(game.ball.get_node("BallVisual").duplicate())
	buffer.apply_frame(_entry,_replay_start,ghosts,ghost_ball,ghost_skeletons)
	game.camera_rig.presentation_override=true;camera.position=ghost_ball.position+Vector3(-8,4.2,12);camera.look_at(ghost_ball.position);camera.make_current()
	_set_caption("REPLAY · "+String(entry.kind).replace("_"," ").to_upper())
	return true
func _save_replay_state() -> void:
	_saved={"ball_transform":game.ball.global_transform,"ball_velocity":game.ball.linear_velocity,"ball_spin":game.ball.angular_velocity,
		"ball_freeze":game.ball.freeze,"ball_visible":game.ball.visible,"ball_physics":game.ball.is_physics_processing(),
		"camera_transform":game.camera_rig.camera.global_transform,"camera_override":game.camera_rig.presentation_override,"nets":{}}
	for side in game._net_impacts:
		var impact: Dictionary=game._net_impacts[side]
		_saved.nets[side]={"age":impact.age,"point":buffer.vector_parameter(impact.material,&"impact_point"),"force":buffer.vector_parameter(impact.material,&"impact_vector")}
	_actor_states.clear()
	for actor in buffer.actors:
		var visual:=actor.get_node("Visual") as Node3D
		_actor_states.append({"actor":actor,"visible":actor.visible,"physics":actor.is_physics_processing(),"visual_mode":visual.process_mode})
		actor.hide();actor.set_physics_process(false);visual.process_mode=Node.PROCESS_MODE_DISABLED
	_detector_states.clear()
	for detector in game.get_node("Goals").find_children("GoalDetector","Node3D",true,false):
		_detector_states.append({"node":detector,"physics":detector.is_physics_processing()});detector.set_physics_process(false)
	game.ball.freeze=true;game.ball.hide();game.ball.set_physics_process(false)
func _plan_replay() -> void:
	var duration := float(_entry.duration)
	var incident: Dictionary = _entry.get("incident", {})
	var impact := clampf(float(incident.get("time", float(_entry.frames[-1].time) - .4)) - float(_entry.frames[0].time), 0, duration)
	var end := minf(duration, impact + .5)
	_wide_duration = minf(6 if _after_replay == &"goal" else 4, end)
	_replay_start = maxf(0, end - _wide_duration)
	_detail_start = maxf(0, end - 1.5)
	_replay_duration = _wide_duration + (end - _detail_start) * 2
	_playhead = _replay_start

func _track_replay(delta: float) -> void:
	var target := ghost_ball.position
	var incident: Dictionary = _entry.get("incident", {})
	var team := _goal_team if _after_replay == &"goal" else String(incident.get("team", _goal_team))
	var direction := -1.0 if team == "Boardeaux" else 1.0
	var station := target + Vector3(-8 * direction, 4.2, 12)
	var lens := 48.0
	var id: StringName = &"replay_sideline"
	if elapsed >= _wide_duration:
		id = &"replay_goal_detail"; lens = 38
		station = Vector3(direction * 56, 1.5, 5.6)
		if _entry.kind == &"save":
			id = &"replay_keeper_detail"
			# The keeper's team attacks away from the goal they are defending.
			station.x = -direction * 55
		elif _entry.kind == &"card":
			id = &"replay_referee_detail"; lens = 30
			var actor_index := buffer.official_index if buffer.official_index >= 0 else int(incident.get("actor_index", -1))
			if actor_index >= 0 and actor_index < ghosts.size():
				target = ghosts[actor_index].position + Vector3.UP * 1.35
			station = target + Vector3(2, .4, 3)
		elif _entry.kind == &"post": id = &"replay_post_detail"
		# A short source recording away from goal still gets a useful contact view.
		if absf(target.x) < 30 and _entry.kind != &"card": station = target + Vector3(-3 * direction, 1.3, 4)
	director.frame(camera, id, target, station, lens, delta, game)
	(panel as FootballLowerThird).reveal(elapsed)
func _restore_replay() -> void:
	if _saved.is_empty(): return
	if is_instance_valid(ghost_world):ghost_world.free()
	ghosts.clear();ghost_skeletons.clear()
	for state in _actor_states:
		var actor: Node3D=state.actor
		actor.visible=state.visible;actor.set_physics_process(state.physics)
		actor.get_node("Visual").process_mode=state.visual_mode
	for state in _detector_states: state.node.set_physics_process(state.physics)
	game.ball.global_transform=_saved.ball_transform;game.ball.linear_velocity=_saved.ball_velocity;game.ball.angular_velocity=_saved.ball_spin
	game.ball.freeze=_saved.ball_freeze;game.ball.visible=_saved.ball_visible;game.ball.set_physics_process(_saved.ball_physics)
	game.ball.reset_physics_interpolation()
	for side in _saved.nets:
		var saved: Dictionary=_saved.nets[side];var impact: Dictionary=game._net_impacts[side]
		impact.age=saved.age;impact.material.set_shader_parameter("impact_age",saved.age)
		impact.material.set_shader_parameter("impact_point",saved.point);impact.material.set_shader_parameter("impact_vector",saved.force)
	game.camera_rig.presentation_override=_saved.camera_override
	FootballCameraOptics.for_camera(camera).clear()
	game.camera_rig.camera.global_transform=_saved.camera_transform;game.camera_rig.camera.make_current()
	game.restart._ignore_buttons=true
	_entry={};_saved={};_actor_states.clear();_detector_states.clear()
func _finish_replay() -> void:
	_restore_replay()
	phase=Phase.IDLE
	if _after_replay==&"goal": _finish_goal()
	else:
		phase=Phase.IDLE;game._presentation_active=false;panel.hide();_restore_match_prompts();FootballCameraOptics.for_camera(camera).clear();camera.current=false
