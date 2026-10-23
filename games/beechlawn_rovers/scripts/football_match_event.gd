extends RefCounted
class_name FootballMatchEvent
## Typed presentation boundary. Listeners must not mutate football outcomes.
enum Kind { BALL_CONTACT, GOAL, RESTART, FOUL, CARD, FULL_TIME, POST, NET }
var kind: Kind
var action: StringName
var actor: Node3D
var team: StringName
var position := Vector3.ZERO
var speed := 0.0
var match_seconds := 0.0
var score := Vector2i.ZERO
var serial := 0
