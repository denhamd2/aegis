class_name EyeLids
extends Node3D
## Upper eyelids that blink (gauntlet/refs/aaa_gap.md item 12).
##
## Roman's model has no eyelid bones and no blend shapes, so he could never
## blink: in a face-off close-up he stared for seconds on end, which is the
## surest tell of a game face. These are lids built for him. Each is a thin
## spherical cap a shade larger than its eyeball, centred on it and measured
## off the eyeball mesh itself (RomanModel.build_eye_lids), skinned the colour
## of the skin round the eye.
##
## Open, the cap is rolled up and back, under the brow and inside the head,
## where the head mesh hides it. Blinking rolls it down over the front of the
## eye and back up. It hangs off the HEAD bone, not the eye bone, so the lids
## stay put while EyeAim turns the eyes.
##
## Presentation only: a seeded RNG for the timing, and nothing reads it.

## The cap's radius over the eye's (bone to the cornea's apex). INSIDE the
## apex, on purpose: the skin round his eye opening sits closer to the
## eyeball's centre than the cornea does, and a cap big enough to clear the
## cornea (1.06, tried first) stood proud of the skin and closed as a ball
## over the socket. So the cap stays inside the skin line and the eye ducks
## back into it while it is shut (EYE_TUCK), which is what a cornea under a
## real lid does anyway.
const RADIUS_OVER_BALL := 0.95
## How far the eyeball shrinks at full closure, so the cornea, iris and pupil
## sit under the cap. Scaled on the eye bone, which only EyeAim rotates and
## no clip writes.
const EYE_TUCK := 0.80
## Roll about the eye's lateral axis, in degrees from "dome straight up".
## The cap covers every direction within 90 degrees of its pole, so tilted
## forward by A its lower edge sits at elevation -A on the front of the eye.
## Open (-35) that edge is 35 degrees ABOVE the pupil, under the brow skin;
## closed (40) its margin clears the fitted opening's lower rim. The true
## hemisphere and head-space up vector keep the cap seated behind skin.
const OPEN_ANGLE := -35.0
const CLOSED_ANGLE := 40.0
## Where this man's lids rest open; OPEN_ANGLE unless his model says
## otherwise (RomanModel.LID_OPEN: 2K26's Roman has heavy, hooded lids).
var open_angle := OPEN_ANGLE
var draw_margin := false
## A blink: close fast, a hold, open a little slower (human blinks run
## 100-150 ms), every BLINK_GAP seconds, jittered.
const CLOSE_SECONDS := 0.06
const HOLD_SECONDS := 0.03
const OPEN_SECONDS := 0.09
const BLINK_GAP := Vector2(2.0, 6.0)

var _lids: Array[Node3D] = []
## The eye bones to tuck, and the skeleton they are on (set by the builder).
var skeleton: Skeleton3D
var eye_bones: PackedStringArray = []
var _rng := RandomNumberGenerator.new()
var _until_next := 0.0
var _t := -1.0       # seconds into the current blink, or -1 between blinks


## One lid per eye: [centre, radius, forward, lateral, optional up] in this
## node's space. Bone-local +Y is not necessarily the character's up axis.
func build(eyes: Array, material: Material, seed_value: int) -> void:
	_rng.seed = seed_value
	_until_next = _rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	for eye: Array in eyes:
		var pivot := Node3D.new()
		pivot.name = "Lid%d" % _lids.size()
		add_child(pivot)
		var centre: Vector3 = eye[0]
		var forward: Vector3 = (eye[2] as Vector3).normalized()
		var lateral: Vector3 = (eye[3] as Vector3).normalized()
		# A proper right-handed frame: z = forward, y = up (the lateral axis
		# crossed with forward, flipped to point up), x = y x z, the hinge.
		# (Assembled as (lateral, up, up x lateral) the first time, which is a
		# mirror, not a rotation -- the cap rendered inside out.)
		var up := lateral.cross(forward).normalized()
		var reference_up: Vector3 = eye[4] if eye.size() > 4 else Vector3.UP
		if up.dot(reference_up) < 0.0:
			up = -up
		var hinge := up.cross(forward).normalized()
		pivot.transform = Transform3D(Basis(hinge, up, forward), centre)
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var dome := SphereMesh.new()
		dome.radius = float(eye[1]) * RADIUS_OVER_BALL
		# Godot's hemisphere height is its full height, not a sphere diameter.
		# A true hemisphere reaches radius above its equator at y = 0.
		dome.height = dome.radius
		dome.is_hemisphere = true
		dome.radial_segments = 20
		dome.rings = 8
		cap.mesh = dome
		if material:
			cap.material_override = material
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(cap)
		if draw_margin and material:
			_add_margin(cap, dome.radius)
		_lids.append(pivot)
	_set_closure(0.0)


## A narrow upper-lid edge follows the cap. The source lash cards stay on
## the open socket; without a moving margin a closed lid reads as a blank plug.
func _add_margin(cap: MeshInstance3D, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a := TAU * i / 40.0
		var b := TAU * (i + 1) / 40.0
		var corners: Array[Vector3] = []
		for uv: Vector2 in [Vector2(a, 0), Vector2(b, 0), Vector2(b, .028), Vector2(a, .028)]:
			corners.append(Vector3(cos(uv.x) * cos(uv.y), sin(uv.y), sin(uv.x) * cos(uv.y)))
		for j in [0, 2, 1, 0, 3, 2]:
			st.set_normal(corners[j])
			st.add_vertex(corners[j] * (radius + .00004))
	var line := MeshInstance3D.new()
	line.name = "LidMargin"
	line.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.08, .045, .035)
	mat.roughness = .85
	mat.metallic_specular = .1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.add_child(line)


## How closed, 0-1, `t` seconds into a blink; -1 outside one.
static func closure_at(t: float) -> float:
	if t < 0.0:
		return 0.0
	if t < CLOSE_SECONDS:
		return smoothstep(0.0, 1.0, t / CLOSE_SECONDS)
	if t < CLOSE_SECONDS + HOLD_SECONDS:
		return 1.0
	var o := (t - CLOSE_SECONDS - HOLD_SECONDS) / OPEN_SECONDS
	return 1.0 - smoothstep(0.0, 1.0, clampf(o, 0.0, 1.0))


static func blink_length() -> float:
	return CLOSE_SECONDS + HOLD_SECONDS + OPEN_SECONDS


func _process(delta: float) -> void:
	if _t >= 0.0:
		_t += delta
		if _t >= blink_length():
			_t = -1.0
			_until_next = _rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	else:
		_until_next -= delta
		if _until_next <= 0.0:
			_t = 0.0
	_set_closure(closure_at(_t))


## Force a closure, for probes: 0 open, 1 shut.
func hold(closure: float) -> void:
	set_process(false)
	_set_closure(closure)


func _set_closure(c: float) -> void:
	var angle := deg_to_rad(lerpf(open_angle, CLOSED_ANGLE, c))
	for pivot in _lids:
		var cap := pivot.get_node("Cap") as Node3D
		cap.transform = Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO)
	if skeleton:
		var k := lerpf(1.0, EYE_TUCK, c)
		for bone_name in eye_bones:
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				skeleton.set_bone_pose_scale(bone, Vector3.ONE * k)
