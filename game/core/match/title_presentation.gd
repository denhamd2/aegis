class_name TitlePresentation
extends Node
## The AEW title on the timekeeper's table, and handed to the winner after the
## match (the owner, 19 Oct: Roman wore it to the ring and it looked clunky;
## it sits on the table from the start and Aubrey presents it at the end).
##
## The entrance's prop pass, run backwards (PropHandoff, on the same clips and
## contact frames): the timekeeper stands behind his table and lifts it
## (Ref_Place), walks it to the ropes and holds it up (Timekeeper_Take) as
## Aubrey reaches down through them for it (Ref_Hand_Over); she walks it to
## the winner, who has turned to her, and hands it over (Ref_Hand_Over
## against his Ref_Reach); he raises it (Title_Raise).
##
## The belt is one prop on one pivot throughout, eased hand to hand over
## PropHandoff.BLEND on each contact frame -- never hidden, never popped.
## Presentation only: the match is over when it starts.

signal presented

const GROUP := &"title_presentation"

enum Step { ON_TABLE, LIFT, TO_ROPES, PASS, TO_WINNER, GIVE, RAISE, DONE }

## When the winner's reach starts after Aubrey's hand-over, so the two
## contact frames coincide (Ref_Hand_Over 28 f against Ref_Reach 24 f).
const REACH_DELAY := PropHandoff.OVER_CONTACT - PropHandoff.REACH_CONTACT
## The hand-over at the winner: she stands this far round from where he
## faces, toward the hard camera's side, so neither hides the other.
const GIVE_FACE := Vector3(0.0, 0.0, 1.0)
## Longest the whole thing may take before it settles where it was going.
const MAX_SECONDS := 40.0

var step := Step.ON_TABLE
var belt: Node3D
var _carried: PropHandoff.Carried
var _ref: RefereeActor
var _keeper: Timekeeper
var _winner: WrestlerController
var _clock := 0.0
var _total := 0.0
var _stage := 0
var _arrived := {}


## The timekeeper (built if no entrance has) and the belt on his table.
static func set_on_table(match_root: Node) -> TitlePresentation:
	var keeper := match_root.get_node_or_null("Timekeeper") as Timekeeper
	if keeper == null:
		keeper = Timekeeper.new()
		keeper.name = "Timekeeper"
		match_root.add_child(keeper)
		keeper.setup(PropHandoff.KEEPER_POST, Vector3(-1, 0, 0), PropHandoff.TABLE_AT)
	var t := TitlePresentation.new()
	t.name = "TitlePresentation"
	t.add_to_group(GROUP)
	match_root.add_child(t)
	t._keeper = keeper
	t._lay_belt()
	return t


static func of(node: Node) -> TitlePresentation:
	return node.get_tree().get_first_node_in_group(GROUP) as TitlePresentation


func _lay_belt() -> void:
	var packed := load(EntranceProps.TITLE) as PackedScene
	if packed == null:
		return
	var model: Node3D = packed.instantiate()
	var mats := EntranceProps._materials()
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the hand-held belt, as it lies on the table and is carried
		mi.visible = key.begins_with("Held")
	_carried = PropHandoff.Carried.new()
	_carried.kind = "title"
	_carried.pivot = Node3D.new()
	_carried.pivot.name = "Pivot_title"
	_carried.pivot.top_level = true
	add_child(_carried.pivot)
	_carried.pivot.add_child(model)
	belt = model
	_carried.holder = PropHandoff._table_holder("title")
	_carried.blend = 1.0
	_carried.pivot.global_transform = PropHandoff._holder_transform(_carried.holder)


func on_table() -> bool:
	return _carried != null and _carried.on_table()


## Who holds it now: "table", "keeper", "referee" or "winner".
func holder() -> String:
	if _carried == null or _carried.holder.is_empty():
		return ""
	if _carried.on_table():
		return "table"
	var actor: Node = _carried.holder.get("actor")
	if actor == _keeper:
		return "keeper"
	if actor == _ref:
		return "referee"
	return "winner"


## After the match: the belt from the table to `winner`, by way of Aubrey.
func present(winner: WrestlerController, referee: RefereeActor) -> void:
	if _carried == null or winner == null or referee == null or step != Step.ON_TABLE:
		_finish()
		return
	_winner = winner
	_ref = referee
	_ref.errand_arrived.connect(_on_arrived.bind("ref"))
	_keeper.arrived.connect(_on_arrived.bind("keeper"))
	_ref.begin_errand(true)
	# Aubrey to the ropes on the timekeeper's side; he goes behind his table.
	var keeper_at := Vector3(PropHandoff.KEEPER_PASS_X, PropHandoff.FLOOR_Y, PropHandoff.PASS_Z)
	var face := Vector3(1, 0, 0)
	var ref_at := PropHandoff.stand_for(keeper_at, -face, PropHandoff.KEEPER_TAKE,
			PropHandoff.REF_GIVE)
	_ref.errand_go(Vector3(PropHandoff.REF_PASS_X, 0.0, ref_at.z), face)
	_keeper.go(PropHandoff.KEEPER_PLACE, Vector3(-1, 0, 0))
	_go(Step.LIFT)


func is_done() -> bool:
	return step == Step.DONE


func _go(next: Step) -> void:
	step = next
	_stage = 0
	_clock = 0.0


func _on_arrived(who: String) -> void:
	_arrived[who] = true
	match step:
		Step.LIFT:
			if who == "keeper" and _stage == 0:
				_stage = 1
				_clock = 0.0
				_keeper.play("strikes/ref_place")
		Step.TO_ROPES:
			if _arrived.has("ref") and _arrived.has("keeper_ropes"):
				_start_pass()
		Step.TO_WINNER:
			if who == "ref":
				_start_give()


func _process(delta: float) -> void:
	if _carried != null:
		_carried.drive(delta)
	if step == Step.ON_TABLE or step == Step.DONE:
		return
	_clock += delta
	_total += delta
	if _total > MAX_SECONDS:
		_finish()
		return
	match step:
		Step.LIFT:
			if _stage == 1 and _clock >= PropHandoff.PLACE_CONTACT:
				# off the table into his hand
				_carried.swap(PropHandoff._bone_holder(_keeper.skeleton(), "hand_r", _keeper,
						Vector3.ZERO))
				_stage = 2
			elif _stage == 2 and _clock >= _keeper.clip_length("strikes/ref_place"):
				_go(Step.TO_ROPES)
				_arrived.erase("keeper_ropes")
				_keeper.arrived.connect(func() -> void: _on_arrived("keeper_ropes"),
						CONNECT_ONE_SHOT)
				_keeper.go(Vector3(PropHandoff.KEEPER_PASS_X, PropHandoff.FLOOR_Y,
						PropHandoff.PASS_Z), Vector3(-1, 0, 0))
		Step.PASS:
			if _stage == 0 and _clock >= PropHandoff.OVER_CONTACT:
				# up through the ropes into her hand
				_carried.swap(PropHandoff._bone_holder(_ref.skeleton(), "hand_r", _ref, Vector3.ZERO))
				_stage = 1
			elif _stage == 1 and _clock >= PropHandoff.TAKE_SHOULDER:
				_keeper.go_to_chair()
				_go(Step.TO_WINNER)
				_arrived.erase("ref")
				var face := _winner_face()
				var spot := PropHandoff.stand_for(_winner.global_position, face,
						PropHandoff.HAND_R, PropHandoff.REF_GIVE)
				_ref.errand_go(spot, -face)
		Step.TO_WINNER:
			_turn_winner(delta)
		Step.GIVE:
			_turn_winner(delta)
			if _stage == 0 and _clock >= REACH_DELAY:
				_winner.play_victory_clip("strikes/ref_reach")
				_stage = 1
			elif _stage == 1 and _clock >= PropHandoff.OVER_CONTACT:
				_carried.swap(PropHandoff._bone_holder(_winner.skeleton,
						_winner._skeleton_bone_name("hand_r"), _winner, Vector3.ZERO))
				_stage = 2
			elif _stage == 2 and _clock >= PropHandoff.OVER_CONTACT + 0.6:
				_ref.end_errand()
				_go(Step.RAISE)
				_winner.play_victory_clip("strikes/title_raise")
		Step.RAISE:
			if _clock >= 0.4:
				# up over his head in both hands: carried off the left hand,
				# as the entrance's raise held it
				if _stage == 0:
					_carried.swap(PropHandoff._bone_holder(_winner.skeleton,
							_winner._skeleton_bone_name("hand_l"), _winner, Vector3.ZERO))
					_stage = 1
			if _clock >= _winner_clip_length("strikes/title_raise"):
				_go(Step.DONE)
				presented.emit()


func _start_pass() -> void:
	_go(Step.PASS)
	_ref.errand_play("strikes/ref_hand_over")
	_keeper.play("strikes/timekeeper_take")


func _start_give() -> void:
	_go(Step.GIVE)
	_ref.errand_play("strikes/ref_hand_over")


## He turns to her side to take it (+Z: Aubrey comes from the timekeeper's
## corner of the ring).
func _winner_face() -> Vector3:
	return GIVE_FACE


func _turn_winner(delta: float) -> void:
	# a wrestler faces his node's -Z: facing +Z is a half turn
	_winner.rotation.y = lerp_angle(_winner.rotation.y, PI, 1.0 - exp(-delta * 5.0))


func _winner_clip_length(clip: String) -> float:
	var player := _winner.anim_player
	return player.get_animation(clip).length if player and player.has_animation(clip) else 2.0


## Out of time, or nothing to do it with: the belt goes where it was going.
func _finish() -> void:
	if _carried != null and _winner != null and _winner.skeleton != null:
		_carried.swap(PropHandoff._bone_holder(_winner.skeleton,
				_winner._skeleton_bone_name("hand_l"), _winner, Vector3.ZERO))
		_carried.blend = 1.0
	if _ref:
		_ref.end_errand()
	if _keeper:
		_keeper.go_to_chair()
	step = Step.DONE
	presented.emit()
