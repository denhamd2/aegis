class_name ShutIn
extends Node
## The Casket and Ambulance matches' finish (gauntlet/refs/casket_match.md,
## ambulance_match.md): a man whipped into the open casket or the back of the
## ambulance goes over its side into it and lies there; the man who sent him
## shuts the lid (the doors) on him, and that is the match.
##
## Before the story's finish (MatchFlow.finish_allowed, flow.winner) it is a
## near-miss: as the lid comes down he gets a hand to it, shoves it back and
## climbs out. A tumble in, a hold, the closing, and -- only on a near-miss --
## the climb out: each a scripted path in ticks, so it replays the same.
##
## `container` is a CasketProp or an AmbulanceProp: mouth(), lip(), bed(),
## set_shut(t), method().

signal shut(winner: WrestlerController, method: String)

const GROUP := &"shut_in"
## Thrown in: from his feet at the mouth, up over the lip and down into it.
const TUMBLE_TICKS := 34
## Lying there while the other man comes to the lid.
const LIE_TICKS := 30
## The lid (the doors) coming down.
const CLOSE_TICKS := 42
## On a near-miss, the lid stops this far down and he shoves it back.
const NEAR_MISS_AT := 0.72
const SHOVE_TICKS := 18
## And back out over the side to his feet at the mouth.
const CLIMB_OUT_TICKS := 50
## Within this of the mouth (flat), a whip aimed at it goes in.
const MOUTH_REACH := 1.0

enum Phase { NONE, TUMBLE, LIE, CLOSE, SHOVE, CLIMB_OUT, SHUT }

var container: Node3D
var phase := Phase.NONE
var victim: WrestlerController
var closer: WrestlerController
var _t := 0
var _from := Vector3.ZERO
var _holds := false
var attempts := 0


static func of(node: Node) -> ShutIn:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as ShutIn


func _ready() -> void:
	add_to_group(GROUP)


func busy() -> bool:
	return phase != Phase.NONE


## Whether a man at `p`, sent at the container, is close enough to go in.
func at_mouth(p: Vector3) -> bool:
	if container == null:
		return false
	var m: Vector3 = container.mouth()
	return Vector2(p.x - m.x, p.z - m.z).length() <= MOUTH_REACH


## `v` goes in; `by` shuts it on him.
func begin(v: WrestlerController, by: WrestlerController) -> bool:
	if busy() or container == null or v == null or by == null:
		return false
	victim = v
	closer = by
	attempts += 1
	_holds = _story_lets_it_hold(by)
	_from = v.global_position
	_t = 0
	phase = Phase.TUMBLE
	v.velocity = Vector3.ZERO
	v.begin_shut_in(self)
	return true


func _story_lets_it_hold(by: WrestlerController) -> bool:
	var flow := by.flow
	if flow == null:
		return true
	return flow.finish_allowed() and flow.winner == by


func tick(v: WrestlerController) -> void:
	if v != victim:
		return
	_t += 1
	var bed: Transform3D = container.bed()
	var lip: Vector3 = container.lip()
	match phase:
		Phase.TUMBLE:
			var s := clampf(float(_t) / TUMBLE_TICKS, 0.0, 1.0)
			# Up to the lip by halfway, then down into the bed: a bump over
			# the side, not a slide.
			var p: Vector3
			if s < 0.5:
				p = _from.lerp(lip, smoothstep(0.0, 1.0, s * 2.0))
				p.y += sin(s * PI) * 0.25
			else:
				p = lip.lerp(bed.origin, smoothstep(0.0, 1.0, (s - 0.5) * 2.0))
			v.global_position = p
			v.rotation.y = lerp_angle(v.rotation.y, bed.basis.get_euler().y, 0.25)
			if _t == TUMBLE_TICKS / 2:
				v.lie_in_shut_in()
			if _t >= TUMBLE_TICKS:
				v.global_position = bed.origin
				v.rotation.y = bed.basis.get_euler().y
				_next(Phase.LIE)
		Phase.LIE:
			v.global_position = bed.origin
			if _t >= LIE_TICKS:
				_next(Phase.CLOSE)
				if is_instance_valid(closer):
					closer.begin_closing(container)
		Phase.CLOSE:
			v.global_position = bed.origin
			var s := float(_t) / CLOSE_TICKS
			if not _holds and s >= NEAR_MISS_AT:
				_next(Phase.SHOVE)
				v.shove_out_of_shut_in()
				return
			container.set_shut(smoothstep(0.0, 1.0, s))
			if _t >= CLOSE_TICKS:
				container.set_shut(1.0)
				_next(Phase.SHUT)
				shut.emit(closer, container.method())
		Phase.SHOVE:
			v.global_position = bed.origin
			var s := float(_t) / SHOVE_TICKS
			container.set_shut(lerpf(NEAR_MISS_AT, 0.0, smoothstep(0.0, 1.0, s)))
			if is_instance_valid(closer) and _t == 2:
				closer.knocked_back_by_lid()
			if _t >= SHOVE_TICKS:
				_from = bed.origin
				_next(Phase.CLIMB_OUT)
				v.climb_out_of_shut_in()
		Phase.CLIMB_OUT:
			var s := clampf(float(_t) / CLIMB_OUT_TICKS, 0.0, 1.0)
			var out: Vector3 = container.mouth()
			var p: Vector3
			if s < 0.5:
				p = _from.lerp(lip, smoothstep(0.0, 1.0, s * 2.0))
			else:
				p = lip.lerp(out, smoothstep(0.0, 1.0, (s - 0.5) * 2.0))
			v.global_position = p
			var face := Vector3(out.x - lip.x, 0.0, out.z - lip.z)
			if face.length() > 0.05:
				v.rotation.y = lerp_angle(v.rotation.y, atan2(-face.x, -face.z), 0.2)
			if _t >= CLIMB_OUT_TICKS:
				_next(Phase.NONE)
				v.end_shut_in()
				victim = null
		Phase.SHUT:
			v.global_position = bed.origin


func _next(p: Phase) -> void:
	phase = p
	_t = 0
