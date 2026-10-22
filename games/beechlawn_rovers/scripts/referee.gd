extends CharacterBody3D
## Presentation official, separate from all selectable/ball-interaction actors.

@onready var ball: FootballBall = get_node("../Ball")
@onready var visual: FootballerVisual = $Visual
var _target := Vector3.ZERO
var _decision_left := 0.0
var _card_time := 0.0
var _card: MeshInstance3D

func _ready() -> void:
	collision_layer=8
	collision_mask=5
	platform_floor_layers=1
	var identity := preload("res://data/officials/referee.tres")
	visual.configure_appearance(identity)
	position = Vector3(-5.0, 0.0, 9.0)
	add_to_group("match_officials")

func _physics_process(delta: float) -> void:
	var match_scene := get_parent()
	_card_time=maxf(0,_card_time-delta)
	if _card!=null: _card.visible=_card_time>0
	var stopped: bool = bool(match_scene.get("_full_time")) or bool(match_scene.get("_kickoff_pending")) or float(match_scene.get("_goal_pause_timer")) > 0.0 or match_scene.restart.active() or _card_time>0
	_decision_left -= delta
	if _decision_left <= 0.0:
		_decision_left = 0.2
		_target = ball.global_position + Vector3(-6.5, 0.0, 8.0 if ball.global_position.z < 15.0 else -8.0)
		_target.x = clampf(_target.x, -44.0, 44.0)
		_target.z = clampf(_target.z, -27.0, 27.0)
	var direction := _target - global_position
	direction.y = 0.0
	var desired := direction.normalized() * minf(5.8, direction.length() * 1.5) if not stopped else Vector3.ZERO
	for node in ([] if stopped else get_tree().get_nodes_in_group("football_players")):
		var away := global_position - (node as Node3D).global_position
		away.y = 0.0
		if away.length_squared() < 2.25 and away.length_squared() > 0.001:
			desired += away.normalized() * (1.5 - away.length()) * 2.0
	velocity.x = move_toward(velocity.x, desired.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 12.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0-exp(-8.0*delta))
	visual.set_locomotion_speed(speed, false, false, false, delta)

func show_card(colour: String, offender: FootballPlayer) -> void:
	_card_time=1.8
	var facing := offender.global_position-global_position
	facing.y=0
	if facing.length_squared()>.01: rotation.y=atan2(-facing.x,-facing.z)
	visual._play_action(&"card",&"AN_Beechlawn_ShowCard",1.0,false,true)
	if _card == null:
		var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
		var attachment := BoneAttachment3D.new()
		attachment.bone_name="mixamorig_RightHand"
		skeleton.add_child(attachment)
		_card=MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size=Vector3(.075,.11,.005)
		_card.mesh=mesh
		attachment.add_child(_card)
		var hand_position := skeleton.get_bone_global_pose(skeleton.find_bone(attachment.bone_name)).origin
		var hand_world:=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(attachment.bone_name))
		_card.transform=hand_world.affine_inverse()*Transform3D(Basis.IDENTITY,skeleton.to_global(hand_position)+Vector3.UP*.04)
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(.92,.025,.015) if colour=="red" else Color(1,.83,.02)
	_card.material_override=material
	_card.show()
