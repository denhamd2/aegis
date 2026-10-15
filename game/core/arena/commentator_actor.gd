class_name CommentatorActor
extends Node3D
## A seated member of the Dynamite broadcast desk. Art is modeled in
## tools/blender/commentators.py from the production character sheets; the
## light head, shoulder and forearm motion below keeps the booth alive without
## putting a crowd-sized skeletal-animation cost on two background actors.

const MODEL_BY_ROLE := {
	"tony": "res://assets/environment/commentator_tony.glb",
	"excalibur": "res://assets/environment/commentator_excalibur.glb",
}

var role := ""
var _head: Node3D
var _spine: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _time := 0.0
var _speaking_for := 0.0
var _talk_phase := 0.0


func setup(who: String, seat_position: Vector3) -> bool:
	role = who.to_lower()
	if not MODEL_BY_ROLE.has(role):
		push_error("CommentatorActor: unknown broadcast role '%s'." % who)
		return false
	var packed := load(MODEL_BY_ROLE[role]) as PackedScene
	if packed == null:
		push_error("CommentatorActor: failed to load %s." % MODEL_BY_ROLE[role])
		return false
	var model := packed.instantiate() as Node3D
	add_child(model)
	_head = model.find_child("HeadPivot", true, false) as Node3D
	_spine = model.find_child("SpinePivot", true, false) as Node3D
	_left_arm = model.find_child("ArmLeftPivot", true, false) as Node3D
	_right_arm = model.find_child("ArmRightPivot", true, false) as Node3D
	position = seat_position
	# The GLB's face points along Godot's -Z convention, the same direction
	# the commentary desk's ring-facing chairs use.
	rotation.y = 0.0
	add_to_group("commentators")
	return _head != null and _left_arm != null and _right_arm != null


## MatchAudio calls this exactly when a recorded line starts. The speaker
## settles back into the quiet listening pose when its line duration ends.
func commentary_started(speaker: String, duration: float) -> void:
	if speaker != role:
		return
	_speaking_for = maxf(_speaking_for, duration)
	_talk_phase = 0.0


func _process(delta: float) -> void:
	_time += delta
	_speaking_for = maxf(0.0, _speaking_for - delta)
	var speaking := _speaking_for > 0.0
	var breathe := sin(_time * 1.25 + (0.6 if role == "tony" else 0.0))
	if _spine:
		_spine.rotation.z = breathe * 0.004
	if _head:
		var listen_yaw := sin(_time * 0.42 + (1.3 if role == "excalibur" else 0.0)) * 0.035
		var listen_nod := sin(_time * 0.8) * 0.008
		if speaking:
			_talk_phase += delta * 5.5
			_head.rotation.y = listen_yaw + sin(_talk_phase * 0.7) * 0.014
			_head.rotation.x = listen_nod - absf(sin(_talk_phase)) * 0.025
		else:
			_head.rotation.y = listen_yaw
			_head.rotation.x = listen_nod
	if _left_arm:
		_left_arm.rotation.z = sin(_time * 0.55) * 0.008
	if _right_arm:
		# Tony punctuates color commentary with a restrained desk-level hand
		# gesture; Excalibur keeps the lead-call posture near his notes.
		var gesture := sin(_talk_phase) if speaking else sin(_time * 0.35)
		_right_arm.rotation.z = gesture * (0.035 if speaking and role == "tony" else 0.012)
