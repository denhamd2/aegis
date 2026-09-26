class_name EntranceDirector
extends Node
## The ring entrances: both men walk out from the stage, down the ramp, up the
## ring steps and through the ropes to their marks, before the bell.
##
## Presentation only, and built so the match cannot tell it happened.
##
## * Everything that plays the match is frozen for the duration -- both
##   wrestlers, their AI, the referee, the grapple rig -- with the same
##   set_physics_process(false) the match end already uses. The referee is the
##   only thing that advances ReplaySystem's tick, and match_setup does not
##   start recording until `bell`, so tick 0 is the bell either way.
## * The wrestlers are moved kinematically. There is no collision anywhere
##   outside the ring -- the stage, ramp and floor are visual only, and
##   keep_inside_the_ring() would snap a man on the ramp back onto the mat --
##   so with their physics frozen the director places the root on each
##   surface's own height, read from ArenaBuilder's constants.
## * Every placement is a pure function of the tick count, so the whole
##   entrance is deterministic and the same every time.
##
## match_setup builds this only when its `entrances` flag is on, which only
## the title screen does. Tests, probes, captures and art shots never see it.
##
## Enter, Space or a pad's A (ui_accept) skips to the bell.

signal bell

# --- Pace and the travelling clips (tools/blender/wrestling_clips.py) --------
## The speed Entrance_Walk's planted foot travels at. Must match the clip.
const WALK_SPEED := 1.6
## Climb_Steps: 1.2 s, the root travelling (fwd 1.26, up 0.86) -- three
## treads of the ring steps, bottom-of-flight floor to top-tread centre.
const CLIMB_SECONDS := 1.2
const CLIMB_TO := Vector2(1.26, 0.86)
## Rope_Step_Through: 1.6 s, (fwd 0.90, up 0.24) -- top tread onto the mat.
const ROPE_SECONDS := 1.6
const ROPE_TO := Vector2(0.90, 0.24)
## How fast a turn on the spot goes, radians per second.
const TURN_RATE := 5.0

# --- Where things are ---------------------------------------------------------
## The -X flight of ring steps (ring.py build_steps): it spans z -3.2..-1.75
## on the entrance side, so the climb runs along +X at its middle.
const STEPS_Z := -2.475
## The floor spot in front of the bottom tread that Climb_Steps starts from.
const CLIMB_FROM_X := -4.70
## Where the ramp's cut lands him: a few metres short of the ramp foot, in the
## ringside shot. The full 24 m ramp at walking pace would be fifteen seconds
## of one shot; a broadcast cuts it, and so does this.
const CUT_TO_Z := -9.0
## How much of the ramp the tracking shot follows before the cut, in seconds.
const RAMP_SHOWN_SECONDS := 6.0

# --- Timing (ticks at 60 Hz) --------------------------------------------------
const TPS := 60
const OPENING_TICKS := 150
## The stage pose: Win_Celebrate (1.3 s) and a beat after it.
const POSE_TICKS := 114
## Held at his mark, turned to face the ring, before the next man.
const SETTLE_TICKS := 40
## The two men squared up before the bell.
const FACEOFF_TICKS := 70

# --- Camera shots (project values; refs/camera.md measures none of these) ---
const OPENING_AT := Vector3(0.0, 8.0, 13.0)
const OPENING_LOOK := Vector3(0.0, 3.0, -30.0)
const OPENING_FOV := 52.0
## The stage: from down the ramp, on a long lens, so the set fills the frame
## behind him.
const STAGE_AT := Vector3(0.0, 1.9, -23.5)
const STAGE_FOV := 40.0
## Walking backwards down the ramp ahead of him.
const TRACK_OFFSET := Vector3(1.3, 1.6, 5.2)
const TRACK_FOV := 44.0
## At ringside on the ring's -X side, inside the barricade, at a cameraman's
## shoulder: the walk in from the ramp foot comes toward it, the steps are
## side-on three metres away, and the ropes are in frame. The first version
## stood outside the barricade at (-7.2, -0.25, -7.8) and rendered the whole
## climb behind the barricade panels and the ringside chairs.
const RINGSIDE_AT := Vector3(-5.6, 0.9, 0.6)
const RINGSIDE_FOV := 42.0

## The follow spot, in the rafters at the far end of the hall, throwing the
## length of the building onto whoever is walking. Without it he walked the
## ramp in silhouette: nothing in the rig lights the ramp, because nothing in
## a match happens there.
const FOLLOW_SPOT_AT := Vector3(0.0, 17.0, 22.0)
const FOLLOW_SPOT_ENERGY := 40.0
const FOLLOW_SPOT_ANGLE := 3.5

var _match: Node
var _a: WrestlerController
var _b: WrestlerController
var _camera: MatchCamera
var _hud: Node
var _card: EntranceLowerThird
var _lights: Node
var _follow: SpotLight3D
## Every node frozen for the entrance, with whether it was processing, so the
## bell puts back exactly what was there.
var _frozen: Array = []
## Where each man stands at the bell: his spawn in match.tscn.
var _mark := {}

## The timeline: one entry per beat, built once in begin().
var _beats: Array = []
var _beat := 0
var _tick := 0
var _done := false


func begin(match_root: Node) -> void:
	_match = match_root
	_a = match_root.get_node("WrestlerA")
	_b = match_root.get_node("WrestlerB")
	_camera = match_root.get_node_or_null("MatchCamera") as MatchCamera
	_hud = match_root.get_node_or_null("MatchHUD")
	_lights = match_root.get_node_or_null("LightRig")
	_mark[_a] = _a.global_transform
	_mark[_b] = _b.global_transform

	for w: WrestlerController in [_a, _b]:
		_freeze(w)
		if w.ai:
			_freeze(w.ai)
		w.velocity = Vector3.ZERO
		w.visible = false
	for path in ["MatchReferee", "GrappleRig"]:
		var node := match_root.get_node_or_null(path)
		if node:
			_freeze(node)
	if _hud and "visible" in _hud:
		_hud.visible = false

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_card = EntranceLowerThird.new()
	layer.add_child(_card)

	_follow = SpotLight3D.new()
	_follow.name = "FollowSpot"
	_follow.light_color = Color(1.0, 0.96, 0.90)
	_follow.light_energy = FOLLOW_SPOT_ENERGY
	_follow.spot_angle = FOLLOW_SPOT_ANGLE
	_follow.spot_angle_attenuation = 0.4
	_follow.spot_range = 80.0
	_follow.spot_attenuation = 0.5
	_follow.light_volumetric_fog_energy = 1.2
	_follow.shadow_enabled = false
	_follow.visible = false
	add_child(_follow)
	_follow.global_position = FOLLOW_SPOT_AT

	# The camera is the director's from the first rendered frame, not the
	# first tick -- otherwise frame one is the match camera's hard-cam shot of
	# an empty ring.
	if _camera:
		_camera.set_entrance_shot(OPENING_AT, OPENING_LOOK, OPENING_FOV, true)

	_build_timeline()
	_start_beat()


func _freeze(node: Node) -> void:
	_frozen.append([node, node.is_physics_processing()])
	node.set_physics_process(false)


# ---------------------------------------------------------------------------
# The timeline
# ---------------------------------------------------------------------------

## Each beat is {kind, who, ticks, ...}. Walks carry a polyline; clips carry a
## root line; every beat names its camera shot and whether the card is up.
func _build_timeline() -> void:
	_beats.append({"kind": "opening", "ticks": OPENING_TICKS})
	# The opponent enters first and waits in the ring; the player's man last.
	_add_entrance(_b, ArenaBuilder.PORTAL_OFFSET_X, "E")
	_add_entrance(_a, -ArenaBuilder.PORTAL_OFFSET_X, "W")
	_beats.append({"kind": "faceoff", "ticks": FACEOFF_TICKS})


func _add_entrance(w: WrestlerController, portal_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 1.2)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	_beats.append({"kind": "walk", "who": w, "path": [emerge, lip],
			"shot": "stage", "card": true, "lights": side, "appear": true})
	_beats.append({"kind": "pose", "who": w, "ticks": POSE_TICKS,
			"clip": "strikes/win_celebrate", "facing": Vector3.BACK,
			"shot": "stage", "card": true, "lights": side})
	var ramp_end := lip + Vector3.BACK * (WALK_SPEED * RAMP_SHOWN_SECONDS)
	_beats.append({"kind": "walk", "who": w, "path": [lip, ramp_end],
			"shot": "track", "card": true})
	# The cut: a few metres short of the ramp foot, then round to the steps
	# -- the ramp foot, out wide of the ring's corner, and in along the flight.
	var cut := Vector3(0.0, 0.0, CUT_TO_Z)
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS + 0.4)
	var wide := Vector3(-4.9, 0.0, -4.0)
	var climb_from := Vector3(CLIMB_FROM_X, 0.0, STEPS_Z)
	_beats.append({"kind": "walk", "who": w, "path": [cut, foot, wide, climb_from],
			"shot": "ringside", "cut": true})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.RIGHT,
			"shot": "ringside"})
	var top := climb_from + Vector3(CLIMB_TO.x, 0.0, 0.0)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/climb_steps",
			"ticks": int(round(CLIMB_SECONDS * TPS)),
			"from": Vector3(climb_from.x, ArenaBuilder.FLOOR_Y, STEPS_Z),
			"to": Vector3(top.x, ArenaBuilder.FLOOR_Y + CLIMB_TO.y, STEPS_Z),
			"facing": Vector3.RIGHT, "shot": "ringside"})
	var inside := top + Vector3(ROPE_TO.x, 0.0, 0.0)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/rope_step_through",
			"ticks": int(round(ROPE_SECONDS * TPS)),
			"from": Vector3(top.x, ArenaBuilder.FLOOR_Y + CLIMB_TO.y, STEPS_Z),
			"to": Vector3(inside.x, 0.0, STEPS_Z),
			"facing": Vector3.RIGHT, "shot": "ringside"})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w,
			"path": [Vector3(inside.x, 0.0, STEPS_Z), mark.origin],
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true})


func _start_beat() -> void:
	_tick = 0
	if _beat >= _beats.size():
		_ring_bell()
		return
	var beat: Dictionary = _beats[_beat]
	var w: WrestlerController = beat.get("who")
	if beat.get("appear", false) and w:
		# Placed in the same step he is shown, or the frame in between renders
		# him standing at his in-ring spawn for a sixtieth of a second.
		_place(w, beat["path"][0], _heading(beat["path"]), true)
		w.visible = true
	if beat.has("lights"):
		_portal_lights(beat["lights"], true)
	else:
		_portal_lights("", false)
	if beat.get("card", false) and w:
		if not _card.is_showing():
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
	else:
		_card.hide_card()
	match beat["kind"]:
		"walk":
			var path: Array = beat["path"]
			var length := 0.0
			for i in path.size() - 1:
				length += _flat(path[i]).distance_to(_flat(path[i + 1]))
			beat["length"] = length
			beat["ticks"] = maxi(1, int(ceil(length / WALK_SPEED * TPS)))
			if beat.get("cut", false):
				_place(w, path[0], _heading(path), true)
			w.play_presentation_clip("strikes/entrance_walk")
		"pose", "clip":
			w.play_presentation_clip(beat["clip"])
		"turn":
			beat["ticks"] = SETTLE_TICKS if beat.get("settle", false) else 18
			w.play_presentation_clip("strikes/idle_ready")
		"faceoff":
			for m: WrestlerController in [_a, _b]:
				m.play_presentation_clip("strikes/idle_ready")


func _physics_process(delta: float) -> void:
	if _done or _beat >= _beats.size():
		return
	if Input.is_action_just_pressed("ui_accept"):
		skip()
		return
	var beat: Dictionary = _beats[_beat]
	_tick += 1
	var t := clampf(float(_tick) / float(beat["ticks"]), 0.0, 1.0)
	var w: WrestlerController = beat.get("who")
	match beat["kind"]:
		"walk":
			var at := _along(beat["path"], t * float(beat["length"]))
			_place(w, at[0], at[1], false, delta)
		"pose":
			_place(w, w.global_position, beat["facing"], false, delta)
		"turn":
			_place(w, w.global_position, beat["facing"], false, delta)
		"clip":
			var from: Vector3 = beat["from"]
			var to: Vector3 = beat["to"]
			w.global_position = from.lerp(to, t)
			w.global_transform.basis = _facing_basis(beat["facing"])
	_frame_shot(beat, delta)
	_aim_follow_spot(w)
	if _tick >= int(beat["ticks"]):
		_beat += 1
		_start_beat()


## Skip straight to the bell, both men on their marks.
func skip() -> void:
	_beat = _beats.size()
	_ring_bell()


func _ring_bell() -> void:
	if _done:
		return
	_done = true
	_card.hide_card()
	_portal_lights("", false)
	if _follow:
		_follow.visible = false
	for w: WrestlerController in [_a, _b]:
		w.global_transform = _mark[w]
		w.velocity = Vector3.ZERO
		w.visible = true
		w.end_presentation()
	for entry: Array in _frozen:
		(entry[0] as Node).set_physics_process(entry[1])
	if _hud and "visible" in _hud:
		_hud.visible = true
	if _camera:
		_camera.resume_master()
	bell.emit()


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

## The surface height at a point: stage deck, ramp, or the floor.
static func surface_y(p: Vector3) -> float:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var foot_z := -ArenaBuilder.BARRICADE_RADIUS
	var floor_y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT
	if p.z <= ArenaBuilder.STAGE_FRONT:
		return deck
	if p.z < foot_z and absf(p.x) <= ArenaBuilder.RAMP_HALF_WIDTH + 0.2:
		# entrance_set.py's wedge: the deck at the stage lip down to 0.04 over
		# the floor at the ramp foot, straight.
		var u := (p.z - ArenaBuilder.STAGE_FRONT) / (foot_z - ArenaBuilder.STAGE_FRONT)
		return lerpf(deck, ArenaBuilder.FLOOR_Y + 0.04, u)
	return floor_y


## A point and a heading `distance` metres along a polyline, on the surface.
func _along(path: Array, distance: float) -> Array:
	var left := distance
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var seg := _flat(a).distance_to(_flat(b))
		if left <= seg or i == path.size() - 2:
			var p := a.lerp(b, clampf(left / maxf(seg, 0.0001), 0.0, 1.0))
			return [p, b - a]
		left -= seg
	return [path[-1], Vector3.BACK]


func _heading(path: Array) -> Vector3:
	return (path[1] as Vector3) - (path[0] as Vector3)


## Puts a man at `at` (dropped onto the surface under it, or the mat), easing
## his facing toward `heading` -- a walker turns into a corner, he does not
## snap to it.
func _place(w: WrestlerController, at: Vector3, heading: Vector3, snap: bool,
		delta: float = 1.0 / 60.0) -> void:
	var p := at
	p.y = surface_y(at) if absf(at.x) > 3.2 or absf(at.z) > 3.2 else 0.0
	w.global_position = p
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length() < 0.001:
		return
	var want := atan2(-flat.x, -flat.z)
	if snap:
		w.rotation.y = want
	else:
		w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)


static func _facing_basis(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------------------
# Camera and lights
# ---------------------------------------------------------------------------

func _frame_shot(beat: Dictionary, delta: float) -> void:
	if not _camera:
		return
	var w: WrestlerController = beat.get("who")
	var first := _tick == 1
	match beat.get("shot", beat["kind"]):
		"opening":
			_camera.set_entrance_shot(OPENING_AT, OPENING_LOOK, OPENING_FOV, true)
		"stage":
			_camera.set_entrance_shot(STAGE_AT, w.global_position + Vector3.UP * 1.3,
					STAGE_FOV, first and not _was_shot("stage"))
		"track":
			_camera.set_entrance_shot(w.global_position + TRACK_OFFSET,
					w.global_position + Vector3.UP * 1.35, TRACK_FOV, first, delta)
		"ringside":
			_camera.set_entrance_shot(RINGSIDE_AT, w.global_position + Vector3.UP * 1.0,
					RINGSIDE_FOV, true)
		"faceoff":
			# The hard camera's own seat and lens, so the bell does not cut.
			_camera.set_entrance_shot(_camera.hard_cam_position,
					(_a.global_position + _b.global_position) * 0.5
					+ Vector3.UP * _camera.hard_cam_aim, _camera.hard_cam_fov, true)


## Keeps the follow spot on whoever is walking; off when nobody is.
func _aim_follow_spot(w: WrestlerController) -> void:
	if not _follow:
		return
	if w == null or not w.visible:
		_follow.visible = false
		return
	_follow.visible = true
	var target := w.global_position + Vector3.UP * 1.1
	if _follow.global_position.distance_to(target) > 0.1:
		_follow.look_at(target, Vector3.UP)


## Whether the previous beat was on the same shot, so a shot carried across
## two beats (the stage walk into the pose) does not re-cut.
func _was_shot(shot: String) -> bool:
	return _beat > 0 and (_beats[_beat - 1] as Dictionary).get("shot", "") == shot


## His portal's accent fixtures come up while he is on the stage.
func _portal_lights(side: String, on: bool) -> void:
	if not _lights:
		return
	for child in _lights.get_children():
		if not (child is SpotLight3D) or not String(child.name).begins_with("Accent"):
			continue
		var light := child as SpotLight3D
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		var base: float = light.get_meta("base_energy")
		var mine := on and String(light.name).begins_with("Accent" + side)
		light.light_energy = base * (2.4 if mine else 1.0)
