extends RefCounted
## Deterministic contact classification and match-local discipline.
var game: Node3D
var yellows: Dictionary = {}
var dismissed: Dictionary = {}
var restart_taker: FootballPlayer
var restart_kind := ""
var _released_serial := -1
var _last_challenge_tick := -1000

func setup(match_scene: Node3D) -> void:
	game=match_scene
	game.ball.actor_touched.connect(_on_touch,CONNECT_DEFERRED)

static func classify_challenge(event: Dictionary) -> String:
	if not event.get("opponent_contact",false): return "clean"
	var speed := float(event.get("relative_speed",0))
	var slide: bool = event.get("sliding",false)
	var behind: bool = event.get("from_behind",false)
	if speed >= 11.0 and slide: return "red"
	if event.get("ball_first",false): return "clean"
	if speed >= 6.0 or (behind and slide): return "yellow"
	return "foul"

func adjudicate(tackler: FootballPlayer, victim: FootballPlayer, event: Dictionary) -> String:
	if game._full_time or game._kickoff_pending or game._goal_pause_timer > 0 or game.restart.active() or dismissed.has(tackler.get_instance_id()): return "ignored"
	var tick := Engine.get_physics_frames()
	if tick-_last_challenge_tick < 20: return "ignored"
	var decision := classify_challenge(event)
	if decision == "clean": return decision
	_last_challenge_tick=tick
	var position: Vector3 = event.get("position",victim.global_position)
	var is_penalty := position.x*tackler.attack_sign <= -36.0 and position.x*tackler.attack_sign >= -52.5 and absf(position.z) <= 20.16
	if decision in ["yellow","red"]: issue_card(tackler,decision)
	if game._full_time: return decision
	game.restart.begin("PENALTY" if is_penalty else "FREE KICK",victim.team_name,position)
	var name_text := tackler.profile.display_name
	game._set_message(("PENALTY" if is_penalty else "FREE KICK")+" · "+name_text+" · "+decision.to_upper())
	game._message_time=2.5
	return decision

func issue_card(actor: FootballPlayer, colour: String) -> void:
	var id := actor.get_instance_id()
	if dismissed.has(id): return
	var second := false
	if colour == "yellow":
		yellows[id]=int(yellows.get(id,0))+1
		second=int(yellows[id])>=2
	actor.set_meta("yellow_cards",int(yellows.get(id,0)))
	var red := colour == "red" or second
	var official := game.get_node_or_null("Referee")
	if official != null: official.show_card("red" if red else "yellow",actor)
	game._set_message(("SECOND YELLOW · RED" if second else ("RED CARD" if red else "YELLOW CARD"))+" · "+actor.profile.display_name)
	if red:
		dismissed[id]=true
		_dismiss(actor)

func _dismiss(actor: FootballPlayer) -> void:
	var team: Array = game._home_players if actor.team_name == &"Beechlawn Rovers" else game._away_players
	var was_keeper := actor.profile.role == "goalkeeper"
	team.erase(actor)
	actor.reset_for_stoppage()
	actor.set_physics_process(false)
	actor.collision_layer=0; actor.collision_mask=0
	actor.remove_from_group("football_players")
	actor.hide()
	actor.set_meta("sent_off",true)
	if team.size()<7:
		game._finish_match()
		game._set_message("MATCH ABANDONED · "+String(actor.team_name)+" has fewer than seven players")
		return
	if was_keeper:
		var replacement: FootballPlayer = team[0]
		for candidate in team:
			var rating: int = candidate.profile.attributes.goalkeeper_handling+candidate.profile.attributes.goalkeeper_reflexes+candidate.profile.attributes.goalkeeper_positioning
			var current: int = replacement.profile.attributes.goalkeeper_handling+replacement.profile.attributes.goalkeeper_reflexes+replacement.profile.attributes.goalkeeper_positioning
			if rating>current: replacement=candidate
		replacement.profile=replacement.profile.duplicate()
		replacement.profile.role="goalkeeper"; replacement.profile.tactical_role="goalkeeper"
		replacement.profile.starting_slot="keeper"
		replacement.profile.starting_position=Vector2(-49,0)
		replacement.profile.appearance=replacement.profile.appearance.duplicate()
		replacement.profile.appearance.kit="beechlawn_keeper" if replacement.team_name==&"Beechlawn Rovers" else "bordeaux_keeper"
		(replacement.get_node("Visual") as FootballerVisual).configure_appearance(replacement.profile)
		replacement._goalkeeper_controller=GoalkeeperController.new()
		replacement._goalkeeper_controller.configure(replacement,game.ball)
		replacement.global_position=Vector3(-replacement.attack_sign*49.0,0,0)
	# Compress each remaining tactical lane while protecting the central channel.
	for teammate in team:
		teammate.profile=teammate.profile.duplicate()
		teammate.profile.starting_position.y*=.92
	if actor == game.player and not game._spectator_mode:
		game._set_controlled_player(game._nearest_outfielder(game._home_players,Vector2(game.ball.position.x,game.ball.position.z)))

func restart_released(actor: FootballPlayer, kind: String) -> void:
	restart_taker=actor; restart_kind=kind
	_released_serial=game.ball.action_serial

func _on_touch(actor: Node3D, serial: int) -> void:
	if restart_taker == null or serial<=_released_serial: return
	if actor != restart_taker:
		restart_taker=null; restart_kind=""
		return
	if serial > _released_serial:
		var opposing: StringName = &"Boardeaux" if restart_taker.team_name == &"Beechlawn Rovers" else &"Beechlawn Rovers"
		var position: Vector3 = actor.global_position
		game.restart.cancel()
		game.restart.begin("INDIRECT FREE KICK",opposing,position)
		restart_taker=null; restart_kind=""

func direct_throw_goal(side: int) -> bool:
	if restart_taker == null or restart_kind not in ["THROW-IN","INDIRECT FREE KICK"]: return false
	var attacking_goal := restart_taker.attack_sign == float(side)
	var own_team: StringName=restart_taker.team_name
	game.restart.cancel()
	var awarded: StringName = (&"Boardeaux" if own_team == &"Beechlawn Rovers" else &"Beechlawn Rovers")
	if attacking_goal:
		game.restart.begin("GOAL KICK",awarded,Vector3(float(side)*47.0,0,0))
	else:
		game.restart.begin("CORNER RESTART",awarded,Vector3(float(side)*51.9,0,33.6))
	restart_taker=null; restart_kind=""
	return true
