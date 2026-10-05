class_name Timekeeper
extends Node3D
## The timekeeper at ringside: waits by the apron at his table, takes what the
## referee hands down through the ropes (the title, the ula fala) and sets it
## on the table, where it stays. Presentation only -- nothing in a match reads
## him, and he never leaves the ringside floor.
##
## He is an AubreyModel in a plain dark polo (her kit is the only official's
## body the project has), on the same clips: PropHandoff tells him where to
## walk and which clip to play, and moves the prop through his hands.

const MODEL := "res://scenes/aubrey_model.tscn"
const WALK_SPEED := 1.4
const TURN_RATE := 7.0
const ARRIVED := 0.08
const WALK_CLIP := "Walk"
const WALK_CLIP_SPEED := 1.3
const IDLE_CLIP := "strikes/ref_stand"
## A black polo, not the referee's stripes.
const POLO := Color(0.05, 0.06, 0.09)

## The table: long side along Z, its ring-side face toward the ring.
const TABLE_SIZE := Vector3(0.75, 0.95, 1.2)
const FRONT_ART := "res://assets/environment/materials/ribbon_board.png"
const FRONT_ART_ASPECT := 7.7236

signal arrived

var model: Node3D
var table: Node3D
var _player: AnimationPlayer
var _target := Vector3.INF
var _face := Vector3.ZERO
var _yaw := 0.0
var _clip := ""
var _faced := false


## Where he stands: `post` on the ringside floor, the table at `table_at`
## (its centre, on the floor), his face toward `post_face`.
func setup(post: Vector3, post_face: Vector3, table_at: Vector3) -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	_player = model.get_node("AnimationPlayer") as AnimationPlayer
	_dress_as_timekeeper()
	global_position = post
	_yaw = _yaw_towards(post_face)
	rotation.y = _yaw
	_play(IDLE_CLIP)
	table = _build_table()
	table.name = "TimekeeperTable"
	table.top_level = true
	add_child(table)
	table.global_position = table_at


## Walk to `target` (flattened, y kept), then turn to `face_dir`. `arrived`
## fires once he is there and squared up.
func go(target: Vector3, face_dir: Vector3) -> void:
	_target = Vector3(target.x, global_position.y, target.z)
	_face = Vector3(face_dir.x, 0.0, face_dir.z)
	_faced = false


## A one-shot clip, from its first frame.
func play(clip: String) -> void:
	_target = Vector3.INF
	_play(clip, 0.2, true)


func idle() -> void:
	_play(IDLE_CLIP, 0.25)


func clip_length(clip: String) -> float:
	return _player.get_animation(clip).length if _player and _player.has_animation(clip) else 0.0


func skeleton() -> Skeleton3D:
	return (model as AubreyModel).get_game_skeleton() if model else null


func _process(delta: float) -> void:
	if _target == Vector3.INF:
		return
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var flat_target := Vector3(_target.x, 0.0, _target.z)
	var to := flat_target - here
	if to.length() > ARRIVED:
		var step := to.normalized() * minf(WALK_SPEED * delta, to.length())
		global_position += step
		_turn(_yaw_towards(to), delta)
		_play(WALK_CLIP, 0.25, false, WALK_SPEED / WALK_CLIP_SPEED)
		return
	_play(IDLE_CLIP, 0.25)
	var want := _yaw_towards(_face) if _face.length() > 0.01 else _yaw
	_turn(want, delta)
	if absf(angle_difference(_yaw, want)) < 0.05 and not _faced:
		_faced = true
		_target = Vector3.INF
		arrived.emit()


func _turn(yaw: float, delta: float) -> void:
	_yaw = lerp_angle(_yaw, yaw, clampf(TURN_RATE * delta, 0.0, 1.0))
	rotation.y = _yaw


func _play(clip: String, blend := 0.2, restart := false, speed := 1.0) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	if restart or clip != _clip:
		_player.play(clip, blend, 1.0)
		if restart:
			_player.seek(0.0, true)
		_clip = clip
	_player.speed_scale = clampf(speed, 0.3, 1.6)


## The model faces its node's +Z, like Aubrey's.
static func _yaw_towards(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


## The referee's stripes become a plain dark polo.
func _dress_as_timekeeper() -> void:
	for mi: MeshInstance3D in model.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "M_RefStripes":
				continue
			var cloth := source.duplicate() as BaseMaterial3D
			cloth.albedo_texture = null
			cloth.albedo_color = POLO
			mi.set_surface_override_material(surface, cloth)


## A draped table with a bell on it.
static func _build_table() -> Node3D:
	var root := Node3D.new()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.03, 0.035, 0.05)
	cloth.roughness = 0.9
	var body := MeshInstance3D.new()
	body.name = "Body"
	var box := BoxMesh.new()
	box.size = TABLE_SIZE - Vector3(0.0, 0.05, 0.0)
	body.mesh = box
	body.material_override = cloth
	body.position = Vector3(0.0, (TABLE_SIZE.y - 0.05) * 0.5, 0.0)
	root.add_child(body)
	var top := MeshInstance3D.new()
	top.name = "Top"
	var slab := BoxMesh.new()
	slab.size = Vector3(TABLE_SIZE.x + 0.06, 0.05, TABLE_SIZE.z + 0.06)
	top.mesh = slab
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.10, 0.08, 0.07)
	wood.roughness = 0.5
	top.material_override = wood
	top.position = Vector3(0.0, TABLE_SIZE.y - 0.025, 0.0)
	root.add_child(top)
	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	var dome := SphereMesh.new()
	dome.radius = 0.07
	dome.height = 0.09
	bell.mesh = dome
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.2)
	brass.metallic = 0.9
	brass.roughness = 0.3
	bell.material_override = brass
	# The back corner, clear of the props laid on the top (PropHandoff.*_SLOT).
	bell.position = Vector3(TABLE_SIZE.x * 0.3, TABLE_SIZE.y + 0.04, TABLE_SIZE.z * 0.4)
	root.add_child(bell)
	# The ring-side face carries printed art, like the announce desk's front.
	var art := load(FRONT_ART) as Texture2D
	if art:
		var front := MeshInstance3D.new()
		front.name = "Front"
		var quad := QuadMesh.new()
		var width := TABLE_SIZE.z * 0.92
		quad.size = Vector2(width, width / FRONT_ART_ASPECT)
		front.mesh = quad
		var print := StandardMaterial3D.new()
		print.albedo_texture = art
		print.roughness = 0.5
		front.material_override = print
		# A quad faces +Z; turn it to face the ring (-X) and hold it just off the cloth.
		front.rotation.y = -PI * 0.5
		front.position = Vector3(-TABLE_SIZE.x * 0.5 - 0.004, TABLE_SIZE.y * 0.5, 0.0)
		root.add_child(front)
	return root
