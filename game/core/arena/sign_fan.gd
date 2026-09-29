class_name SignFan
extends Node3D
## One ringside spectator with a sign (tools/blender/sign_fan.py): sat with the
## board face-down on his knees, and on raise() up on his feet holding it over
## his head, pumping it, until he sits back down. SignFans decides when.
##
## Presentation only (ARCHITECTURE.md): he reads nothing in the match and
## nothing reads him.

const MODEL := "res://assets/environment/sign_fan.glb"
const SEATED := "Fan_Seated"
const RISE := "Fan_Rise"
const HOLD := "Fan_Hold"
const LOWER := "Fan_Lower"
## Cross-fade between his clips, seconds. Each clip starts where the last one
## ends, so this only has to hide a key's worth of difference.
const BLEND := 0.12
## The picture on the board is paper under arena light, not a screen: taken
## down so it sits with the crowd rather than glowing out of it.
const SIGN_TINT := Color(0.78, 0.78, 0.78)
const SKIN := Color(0.46, 0.34, 0.27)
const DARK := Color(0.05, 0.05, 0.06)

enum Stage { SEATED, RISING, HOLDING, LOWERING }

var stage := Stage.SEATED
var _player: AnimationPlayer
var _hold_left := 0.0


## Builds him in his chair, in `shirt`, with `picture` on the board. `phase`
## (0-1) staggers his seated sway against anyone else's.
func setup(picture: Texture2D, shirt: Color, phase: float) -> void:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("SignFan: %s failed to load. Run tools/blender/sign_fan.py." % MODEL)
		return
	var model := packed.instantiate()
	add_child(model)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name.begins_with("FanSign"):
			mesh.set_surface_override_material(0, _board(picture))
			mesh.set_surface_override_material(1, _flat(Color(0.62, 0.58, 0.51)))
		else:
			mesh.set_surface_override_material(0, _flat(shirt))
			mesh.set_surface_override_material(1, _flat(SKIN))
			mesh.set_surface_override_material(2, _flat(DARK))
	if _player == null:
		return
	for loop: String in [SEATED, HOLD]:
		var anim := _player.get_animation(loop)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_finished)
	_player.play(SEATED)
	_player.seek(phase * _player.current_animation_length, true)


## Up on his feet with the sign for `seconds` of holding it, then back down.
## A fan already up just holds it longer.
func raise(seconds: float) -> void:
	if _player == null:
		return
	_hold_left = maxf(_hold_left, seconds)
	if stage == Stage.SEATED:
		stage = Stage.RISING
		_player.play(RISE, BLEND)


## Back into his seat as soon as he can.
func sit() -> void:
	_hold_left = 0.0


func _process(delta: float) -> void:
	if stage != Stage.HOLDING:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		stage = Stage.LOWERING
		_player.play(LOWER, BLEND)


func _on_finished(anim: StringName) -> void:
	match String(anim):
		RISE:
			stage = Stage.HOLDING
			_player.play(HOLD, BLEND)
		LOWER:
			stage = Stage.SEATED
			_player.play(SEATED, BLEND)


func _board(picture: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = picture
	m.albedo_color = SIGN_TINT
	m.roughness = 0.85
	return m


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m
