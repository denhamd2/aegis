class_name ImpactSell
extends SkeletonModifier3D
## Short additive selling layered over the authored paired move and its down
## pose. GrappleRig still owns the move through contact; this modifier starts
## only after it hands the bodies back, and never writes game state.

const PROFILE_LIMIT := 4
const DURATIONS := {
	&"suplex": 28.0,
	&"cross_rhodes": 42.0,
	&"table_rebound": 18.0,
	&"wire_guard": 52.0,
	&"tack_guard": 52.0,
	&"ladder_crash": 36.0,
	&"ladder_aerial": 30.0,
}

var bones := {
	"pelvis": "pelvis", "spine_01": "spine_01", "spine_02": "spine_02",
	"spine_03": "spine_03", "neck_01": "neck_01", "Head": "Head",
	"upperarm_l": "upperarm_l", "lowerarm_l": "lowerarm_l",
	"upperarm_r": "upperarm_r", "lowerarm_r": "lowerarm_r",
	"thigh_l": "thigh_l", "calf_l": "calf_l",
	"thigh_r": "thigh_r", "calf_r": "calf_r",
}
var wrestler: WrestlerController
var _ids := {}
var _reactions: Array[Dictionary] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## Resolve the move's follow-through profile by its paired trajectory ID.
static func move_profile(move: MoveDef) -> StringName:
	if move == null:
		return &""
	match move.animation_pair_id:
		&"grapple_vertical_suplex":
			return &"suplex"
		&"finisher_cross_rhodes":
			return &"cross_rhodes"
		&"ladder_aerial":
			return &"ladder_aerial"
	return &""


## A table's collapsing rebound is additive to the move sell. Barbed wire and
## tacks get a sharp first flinch followed by a protective, localized curl.
static func surface_profile(weapon_id: StringName, broke: bool) -> StringName:
	if weapon_id == &"table" and broke:
		return &"table_rebound"
	if weapon_id == &"barbed_wire_board":
		return &"wire_guard"
	if weapon_id in [&"thumbtacks", &"bed_of_nails"]:
		return &"tack_guard"
	if weapon_id == &"ladder":
		return &"ladder_crash"
	return &""


func react_to_move(move: MoveDef) -> void:
	# A set-piece reaction recorded during the paired move is already the more
	# specific follow-through for that landing.
	if &"ladder_crash" in active_profiles() and move_profile(move) == &"suplex":
		return
	play(move_profile(move), &"upper_body")


func react_to_surface(weapon_id: StringName, broke: bool) -> void:
	play(surface_profile(weapon_id, broke), &"back")


func play(profile: StringName, part: StringName = &"upper_body") -> void:
	if wrestler == null or not DURATIONS.has(profile):
		return
	_reactions.append({"profile": profile, "part": part,
			"start": Engine.get_physics_frames()})
	while _reactions.size() > PROFILE_LIMIT:
		_reactions.pop_front()


func active_profiles() -> Array[StringName]:
	var result: Array[StringName] = []
	for reaction: Dictionary in _reactions:
		result.append(reaction["profile"])
	return result


## Fast impact response, followed by each profile's distinct settling motion.
## The phase curves are deterministic and presentation-only.
static func impact_envelope(age: float, attack := 1.0, decay := 7.0,
		frequency := 0.9) -> float:
	if age < 0.0:
		return 0.0
	if age < attack:
		return smoothstep(0.0, attack, age)
	var t := age - attack
	return exp(-t / decay) * (0.82 + 0.18 * cos(t * frequency))


static func guard_envelope(age: float, hold := 30.0, fade := 18.0) -> float:
	if age < 1.0:
		return 0.0
	if age <= hold:
		return 1.0
	return 1.0 - smoothstep(hold, hold + fade, age)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null or _reactions.is_empty():
		return
	# These are downed sells. When the match timer or player input starts the
	# get-up, hand the pose back immediately so the authored recovery animation
	# and its existing controls remain in charge.
	if wrestler.fsm == null or wrestler.fsm.current_state != WrestlerFSM.State.DOWN:
		_reactions.clear()
		return
	var now := float(Engine.get_physics_frames()) + Engine.get_physics_interpolation_fraction()
	var to_skel := sk.global_basis.inverse()
	var turns := {}
	var finished: Array[Dictionary] = []
	for reaction: Dictionary in _reactions:
		var age := now - float(reaction["start"])
		var profile: StringName = reaction["profile"]
		if age > float(DURATIONS[profile]):
			finished.append(reaction)
			continue
		_apply_profile(turns, profile, StringName(reaction["part"]), age, to_skel)
	for reaction: Dictionary in finished:
		_reactions.erase(reaction)
	for key: String in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
			"upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r",
			"thigh_l", "calf_l", "thigh_r", "calf_r"]:
		var value: Vector3 = turns.get(key, Vector3.ZERO)
		var id := int(_ids.get(key, -1))
		if id < 0 or value.length_squared() < 1e-8:
			continue
		var pose := sk.get_bone_global_pose(id)
		pose.basis = Basis(value.normalized(), value.length()) * pose.basis
		sk.set_bone_global_pose(id, pose)


func _apply_profile(turns: Dictionary, profile: StringName, part: StringName,
		age: float, to_skel: Basis) -> void:
	var x := (to_skel * wrestler.global_basis.x).normalized()
	var y := (to_skel * Vector3.UP).normalized()
	var z := (to_skel * -wrestler.global_basis.z).normalized()
	match profile:
		&"suplex":
			# The hips take the canvas first; the chest, shoulders and head lag
			# by progressively more, then recoil into the existing supine pose.
			var hips := impact_envelope(age, 0.6, 5.8, 0.95)
			var chest := impact_envelope(age - 0.35, 0.75, 6.2, 0.95)
			var shoulders := impact_envelope(age - 0.65, 0.8, 6.4, 0.95)
			var head := impact_envelope(age - 1.0, 0.9, 6.8, 0.95)
			_add(turns, "pelvis", x, -5.0 * hips)
			_add(turns, "spine_01", x, 7.0 * chest)
			_add(turns, "spine_02", x, 13.0 * chest)
			_add(turns, "spine_03", x, 16.0 * shoulders)
			_add(turns, "neck_01", x, -8.0 * head)
			_add(turns, "Head", x, -12.0 * head)
			_add(turns, "upperarm_l", z, -8.0 * shoulders)
			_add(turns, "upperarm_r", z, -8.0 * shoulders)
		&"cross_rhodes":
			# A sharp upper-body finish, followed by a guarded shoulder roll:
			# twist through the chest and hips as both forearms draw over the head.
			var impact := impact_envelope(age, 0.8, 4.0, 1.1)
			var roll := guard_envelope(age, 22.0, 17.0)
			_add(turns, "spine_01", x, 12.0 * impact)
			_add(turns, "spine_02", x, 24.0 * impact)
			_add(turns, "spine_03", x, 18.0 * impact)
			_add(turns, "Head", x, -15.0 * impact)
			_add(turns, "pelvis", z, 13.0 * roll)
			_add(turns, "spine_02", z, 16.0 * roll)
			_add(turns, "spine_03", z, 20.0 * roll)
			_add(turns, "upperarm_l", x, -40.0 * roll)
			_add(turns, "lowerarm_l", x, -34.0 * roll)
			_add(turns, "upperarm_r", x, -32.0 * roll)
			_add(turns, "lowerarm_r", x, -26.0 * roll)
			_add(turns, "thigh_l", z, 13.0 * roll)
			_add(turns, "thigh_r", z, -13.0 * roll)
		&"table_rebound":
			# A short arch and recoil as the tabletop gives way, layered over the
			# suplex or slam already landing on it.
			var e := impact_envelope(age, 0.7, 4.8, 1.15)
			_add(turns, "pelvis", x, -7.0 * e)
			_add(turns, "spine_02", x, -12.0 * e)
			_add(turns, "spine_03", x, -15.0 * e)
			_add(turns, "Head", x, 8.0 * e)
			_add(turns, "upperarm_l", z, 12.0 * e)
			_add(turns, "upperarm_r", z, -12.0 * e)
			_add(turns, "calf_l", x, 8.0 * e)
			_add(turns, "calf_r", x, 8.0 * e)
		&"wire_guard", &"tack_guard":
			# First pull sharply away, then protect the injured back with a
			# curled torso and forearms across the chest while the pain subsides.
			var e := impact_envelope(age, 0.65, 3.4, 1.35)
			var guard := guard_envelope(age, 29.0, 20.0)
			var amount := 1.0 if profile == &"tack_guard" else 0.82
			_add(turns, "spine_02", x, 14.0 * e + 12.0 * guard * amount)
			_add(turns, "spine_03", x, 19.0 * e + 17.0 * guard * amount)
			_add(turns, "Head", x, -11.0 * e - 8.0 * guard)
			_add(turns, "pelvis", z, 12.0 * guard)
			_add(turns, "upperarm_l", x, -32.0 * guard)
			_add(turns, "lowerarm_l", x, -42.0 * guard)
			_add(turns, "upperarm_r", x, -26.0 * guard)
			_add(turns, "lowerarm_r", x, -38.0 * guard)
			_add(turns, "thigh_l", z, 10.0 * guard)
			_add(turns, "thigh_r", z, -10.0 * guard)
			if part == &"back":
				_add(turns, "spine_01", y, 6.0 * e)
		&"ladder_crash":
			# The rung strike arrests the fall through the shoulders and ribs.
			# A short recoil gives way to a guarded side curl with the arms drawn
			# over the impact zone; keep it separate from the puncture sells.
			var e := impact_envelope(age, 0.55, 4.2, 1.05)
			var guard := guard_envelope(age, 19.0, 15.0)
			_add(turns, "spine_02", x, 18.0 * e + 10.0 * guard)
			_add(turns, "spine_03", x, 16.0 * e + 14.0 * guard)
			_add(turns, "Head", x, -12.0 * e)
			_add(turns, "pelvis", z, 10.0 * guard)
			_add(turns, "upperarm_l", x, -34.0 * guard)
			_add(turns, "lowerarm_l", x, -38.0 * guard)
			_add(turns, "upperarm_r", x, -28.0 * guard)
			_add(turns, "lowerarm_r", x, -34.0 * guard)
		&"ladder_aerial":
			# The diving forearm compresses the chest on contact, then the downed
			# wrestler folds an arm across the ribs while the impact settles.
			var e := impact_envelope(age, 0.6, 3.8, 1.2)
			var guard := guard_envelope(age, 16.0, 14.0)
			_add(turns, "spine_02", x, 18.0 * e + 8.0 * guard)
			_add(turns, "spine_03", x, 14.0 * e + 10.0 * guard)
			_add(turns, "Head", x, -10.0 * e)
			_add(turns, "pelvis", z, 9.0 * guard)
			_add(turns, "upperarm_l", x, -30.0 * guard)
			_add(turns, "lowerarm_l", x, -36.0 * guard)
			_add(turns, "upperarm_r", x, -24.0 * guard)
			_add(turns, "lowerarm_r", x, -32.0 * guard)


static func _add(turns: Dictionary, bone: String, axis: Vector3, degrees: float) -> void:
	if absf(degrees) < 0.001:
		return
	turns[bone] = (turns.get(bone, Vector3.ZERO) as Vector3) \
			+ axis * deg_to_rad(degrees)
