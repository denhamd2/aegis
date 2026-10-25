extends Node
class_name FootballCameraOptics
## Camera-local cinematic optics. Wide/gameplay views retain deep focus.
var camera: Camera3D
var blur: FootballMotionBlur
var focus := CameraAttributesPractical.new()
var _original_attributes: CameraAttributes
var _original_compositor: Compositor
var _cinematic_compositor: Compositor
var _shot: StringName = &""
var _cut_frame := -1
var _distance := 1.0
var _cinematic := false

static func for_camera(target: Camera3D) -> FootballCameraOptics:
	var existing := target.get_node_or_null("FootballOptics") as FootballCameraOptics
	if existing != null: return existing
	var optics := FootballCameraOptics.new()
	optics.name = "FootballOptics"; optics.camera = target
	target.add_child(optics)
	optics._original_attributes = target.attributes
	optics._original_compositor = target.compositor
	if FootballMotionBlur.supported(RenderingServer.get_current_rendering_method()) and RenderingServer.get_rendering_device() != null:
		optics.blur = FootballMotionBlur.new()
		optics._cinematic_compositor = Compositor.new()
		if target.compositor != null:
			optics._cinematic_compositor.compositor_effects = target.compositor.compositor_effects.duplicate()
		optics._cinematic_compositor.compositor_effects.append(optics.blur)
	return optics

func shot(id: StringName, target: Vector3, lens: float, delta: float) -> void:
	_cinematic = true
	var preferences := camera.get_node("/root/MatchSession")
	var distance := maxf(.1, camera.global_position.distance_to(target))
	if id != _shot:
		_shot = id; _cut_frame = Engine.get_process_frames(); _distance = distance
	else:
		_distance = lerpf(_distance, distance, 1-exp(-delta*8))
	if bool(preferences.get("cinematic_depth_of_field")) and lens <= 40:
		focus.dof_blur_far_enabled = true
		focus.dof_blur_near_enabled = false
		focus.dof_blur_far_distance = _distance + maxf(.12, _distance*.12)
		focus.dof_blur_far_transition = maxf(1.0, _distance*.8)
		focus.dof_blur_amount = lerpf(.025,.055,clampf((40-lens)/18,0,1))
		camera.attributes = focus
	else:
		camera.attributes = _original_attributes
	if _cinematic_compositor != null:
		camera.compositor = _cinematic_compositor if bool(preferences.get("cinematic_motion_blur")) else _original_compositor

func clear() -> void:
	_cinematic = false; _shot = &""
	if blur != null: blur.intensity = 0
	camera.attributes = _original_attributes
	camera.compositor = _original_compositor

static func shutter_fraction(delta: float) -> float:
	# A short shutter preserves broadcast clarity across rendering rates.
	return clampf(.0033/maxf(delta,1.0/240),0,.35)

func _process(delta: float) -> void:
	if blur != null:
		var preferences := camera.get_node("/root/MatchSession")
		blur.intensity = shutter_fraction(delta) if _cinematic and camera.current and bool(preferences.get("cinematic_motion_blur")) and Engine.get_process_frames()-_cut_frame>1 else 0.0
