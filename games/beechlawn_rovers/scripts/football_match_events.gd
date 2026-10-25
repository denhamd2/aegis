extends Node
class_name FootballMatchEvents
signal occurred(event: FootballMatchEvent)
var game: Node3D
var serial := 0
func setup(match_scene: Node3D) -> void:
	game = match_scene
	game.ball.touched.connect(_ball_contact)
	game.ball.net_contact.connect(func(_body: Node3D, point: Vector3, velocity: Vector3):
		emit_event(FootballMatchEvent.Kind.NET,&"net",game.ball.last_touch_player,point,velocity.length()))
	game.ball.post_contact.connect(func(point: Vector3, velocity: Vector3):
		emit_event(FootballMatchEvent.Kind.POST,&"post",game.ball.last_touch_player,point,velocity.length()))
func _ball_contact(action: StringName, speed: float) -> void:
	emit_event(FootballMatchEvent.Kind.BALL_CONTACT,action,game.ball.last_touch_player,game.ball.position,speed)
func emit_event(kind: FootballMatchEvent.Kind, action: StringName, actor: Node3D = null,
		position := Vector3.ZERO, speed := 0.0) -> FootballMatchEvent:
	serial += 1
	var event := FootballMatchEvent.new()
	event.kind = kind; event.action = action; event.actor = actor
	event.team = StringName(actor.get("team_name")) if is_instance_valid(actor) and actor.get("team_name") != null else &"none"
	event.position = position; event.speed = speed; event.serial = serial
	event.match_seconds = game.short_match_seconds - game._remaining_time
	event.score = Vector2i(game._home_score,game._away_score)
	occurred.emit(event)
	return event
