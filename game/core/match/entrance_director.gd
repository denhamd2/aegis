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

# --- Roman Reigns (gauntlet/refs/entrances.md, "Roman: beat sheet") ---------
## Slow and methodical: Walk_Title_Look / Walk_Slow_Look travel 0.5 m/s,
## half the generic entrance's pace, and turn his head over the crowd as he
## goes (wrestling_clips.py _methodical_walk).
const ROMAN_WALK_SPEED := 0.5
const ROMAN_WALK_CLIP := "strikes/walk_title_look"
const ROMAN_WALK_FREE_CLIP := "strikes/walk_slow_look"
## He does not come out until the main part of his music hits. Measured off
## the audio of assets/environment/video/roman_entrance.ogv: the intro runs
## to a near-silent break at 43.5-45.0 s and the full track lands at 45.2 s
## (RMS 0.01 -> 0.28 inside 200 ms). The video goes up on the wall at the top
## of the music; he appears on the hit.
const ROMAN_MUSIC_HIT := 45.2
## Until then the broadcast shows the building and his video: six shots, each
## a slow move eased in and out (blender-cameras: push-ins, a truck, a wide
## establishing lens), in seconds. [from, to, look_from, look_to, fov_from,
## fov_to, seconds]. Lenses as vertical FOV: 53 ~ 24 mm, 38 ~ 35 mm,
## 27 ~ 50 mm, 16 ~ 85 mm.
const ROMAN_INTRO_SHOTS := [
	# His video on the wall, from low on the ramp, pushing in.
	[Vector3(0.0, 2.6, -18.0), Vector3(0.0, 3.2, -22.0),
		Vector3(0.0, 9.2, -36.5), Vector3(0.0, 9.3, -36.5), 32.0, 26.0, 8.0],
	# The building: high in the far end, a 24 mm wide, trucking across.
	[Vector3(9.0, 9.5, 19.0), Vector3(3.0, 9.8, 20.0),
		Vector3(0.0, 3.0, -18.0), Vector3(0.0, 3.2, -20.0), 53.0, 50.0, 8.0],
	# The crowd on the hard-camera side, panning along the rows.
	[Vector3(3.8, 1.6, 2.0), Vector3(3.8, 1.7, 0.0),
		Vector3(16.0, 4.5, -8.0), Vector3(16.0, 4.5, 8.0), 38.0, 38.0, 7.0],
	# Over the ring from the rig, the stage and the wall beyond.
	[Vector3(0.0, 14.0, 7.0), Vector3(0.0, 12.5, 3.5),
		Vector3(0.0, 0.0, -8.0), Vector3(0.0, 1.0, -14.0), 50.0, 46.0, 7.0],
	# Reverse, from the stage lip back over the ramp to the ring.
	[Vector3(4.5, 2.2, -30.8), Vector3(-4.5, 2.2, -30.8),
		Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.2, 0.0), 42.0, 42.0, 7.0],
	# The curtain, long lens, low on the ramp, creeping in until he appears.
	[Vector3(0.0, 1.0, -23.0), Vector3(0.0, 1.0, -25.5),
		Vector3(0.0, 2.4, -36.5), Vector3(0.0, 2.3, -36.5), 30.0, 24.0, 8.2],
]
## The house lights dim for him (blender-lighting's low-key look: fewer,
## harder sources, the key on the subject). The rig drops to this fraction and
## the ambient to AMBIENT_DIM; the follow spot, his portal accents and the
## pyro flashes are left alone, so he is what is lit.
const ROMAN_HOUSE_DIM := 0.5
const ROMAN_AMBIENT_DIM := 0.65
## The close-ups: an 85 mm on his face walking toward the lens, and one held
## on the stage lip.
const FACE_FOV := 16.0
const FACE_DISTANCE := 3.4
## Beside him as he walks the floor from the ramp foot to the steps.
const FLOOR_TRACK_FOV := 30.0
## Cues inside his clips, in ticks from the clip's start (clip frame x 2):
## Title_Raise has the belt in the hand from frame 10 to 54, Finger_Raise's arm
## arrives on frame 14 -- the pyro hit -- and Ula_Fala_Off has it over his
## head by frame 20.
const TITLE_HELD_AT := 20
const TITLE_DRAPED_AT := 108
const FINGER_PYRO_AT := 28
const ULA_FALA_LIFT_AT := 40
## His portal accents go gold for him, not the side's own colour.
const ROMAN_GOLD := Color(1.0, 0.78, 0.36)
## His shots. The push-in on the mark: from the ramp, a slow dolly in and a
## lens tightening on him. The hero shot: low at his feet looking up, for the
## title. The wide: the whole set, for the pyro. The ring low: from the mat
## under the ropes, for the finger in the ring.
const PUSH_FROM := Vector3(0.0, 1.8, -24.5)
const PUSH_TO := Vector3(0.0, 1.7, -27.4)
const PUSH_FOV := Vector2(34.0, 28.0)
const HERO_OFFSET := Vector3(0.9, 0.45, 3.0)
const HERO_FOV := 40.0
const STAGE_WIDE_AT := Vector3(0.0, 3.2, -15.0)
const STAGE_WIDE_LOOK := Vector3(0.0, 4.0, -33.0)
const STAGE_WIDE_FOV := 58.0
const RING_LOW_OFFSET := Vector3(-2.2, 0.35, 1.4)
const RING_LOW_FOV := 46.0

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
## Roman's belt and ula fala, per man, and the pyro -- built when needed.
var _props := {}
var _pyro: EntrancePyro
## The stage wall, for his own titantron.
var _wall: StageVideo
## Light energies saved while the house is dimmed, to put back exactly.
var _dimmed := {}
var _env: Environment

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
	_wall = match_root.find_child("StageVideo", true, false) as StageVideo
	var world: WorldEnvironment = null
	for node in match_root.find_children("*", "WorldEnvironment", true, false):
		world = node as WorldEnvironment
	if world:
		_env = world.environment
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
	for pair: Array in [[_b, ArenaBuilder.PORTAL_OFFSET_X, "E"],
			[_a, -ArenaBuilder.PORTAL_OFFSET_X, "W"]]:
		var w: WrestlerController = pair[0]
		if w.entrance_style == "roman":
			_add_roman_entrance(w, pair[1], pair[2])
		else:
			_add_entrance(w, pair[1], pair[2])
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
	if beat.get("props", false) and w and not _props.has(w):
		_props[w] = EntranceProps.dress(w)
	if beat.has("lights"):
		_portal_lights(beat["lights"], true, beat.get("light_color", Color.TRANSPARENT))
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
			var speed: float = beat.get("speed", WALK_SPEED)
			beat["ticks"] = maxi(1, int(ceil(length / speed * TPS)))
			if beat.get("cut", false):
				_place(w, path[0], _heading(path), true)
			w.play_presentation_clip(beat.get("walk_clip", "strikes/entrance_walk"))
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
	for cue: Array in beat.get("events", []):
		if int(cue[0]) == _tick:
			_event(w, cue[1])
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
	for props: EntranceProps in _props.values():
		props.queue_free()
	_props.clear()
	if _pyro:
		_pyro.queue_free()
		_pyro = null
	if _wall:
		_wall.end_entrance()
	_dim_house(false)
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


## Roman Reigns: the champion's walk. Everything slower and more still than
## the generic entrance -- he walks at 1.0 m/s with the title on his shoulder
## and the ula fala on, stops on the stage lip and makes them wait, raises the
## title, then the finger with the pyro on it. In the ring the finger again
## with the post pyro, the title and the ula fala come off, and he goes to his
## mark. (gauntlet/refs/entrances.md: every beat here is one on the sheet.)
func _add_roman_entrance(w: WrestlerController, portal_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 1.2)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var gold := {"lights": side, "light_color": ROMAN_GOLD}
	# His music and his video, the house down, and nobody on the stage until
	# the hit.
	_beats.append({"kind": "hold", "who": w,
			"ticks": int(round(ROMAN_MUSIC_HIT * TPS)), "shot": "intro",
			"events": [[1, "tron_on"], [1, "dim_on"]]})
	# Out on the hit, and a long walk to the lip: the first half wide from
	# the ramp, the second on his face as he comes toward the lens.
	var half := emerge.lerp(lip, 0.5)
	_beats.append(_with(gold, {"kind": "walk", "who": w, "path": [emerge, half],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "stage", "appear": true, "props": true}))
	_beats.append(_with(gold, {"kind": "walk", "who": w, "path": [half, lip],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "face_walk"}))
	# The mark: he stops, and the card comes up while he stands there.
	_beats.append(_with(gold, {"kind": "pose", "who": w, "ticks": 150,
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "stage_push", "card": true}))
	_beats.append(_with(gold, {"kind": "pose", "who": w, "ticks": 120,
			"clip": "strikes/title_raise", "facing": Vector3.BACK,
			"shot": "hero_low", "card": true,
			"events": [[TITLE_HELD_AT, "title_held"], [TITLE_DRAPED_AT, "title_draped"]]}))
	_beats.append(_with(gold, {"kind": "pose", "who": w, "ticks": 120,
			"clip": "strikes/finger_raise", "facing": Vector3.BACK,
			"shot": "stage_wide", "card": true,
			"events": [[FINGER_PYRO_AT, "pyro_stage"]]}))
	var ramp_end := lip + Vector3.BACK * (ROMAN_WALK_SPEED * RAMP_SHOWN_SECONDS)
	_beats.append({"kind": "walk", "who": w, "path": [lip, ramp_end],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "track"})
	var cut := Vector3(0.0, 0.0, -7.0)
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS + 0.4)
	var wide := Vector3(-4.6, 0.0, -4.1)
	var climb_from := Vector3(CLIMB_FROM_X, 0.0, STEPS_Z)
	_beats.append({"kind": "walk", "who": w, "path": [cut, foot, wide],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "floor_track", "cut": true})
	_beats.append({"kind": "walk", "who": w, "path": [wide, climb_from],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside"})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.RIGHT,
			"shot": "ringside"})
	var top := climb_from + Vector3(CLIMB_TO.x, 0.0, 0.0)
	var top_at := Vector3(top.x, ArenaBuilder.FLOOR_Y + CLIMB_TO.y, STEPS_Z)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/climb_steps",
			"ticks": int(round(CLIMB_SECONDS * TPS)),
			"from": Vector3(climb_from.x, ArenaBuilder.FLOOR_Y, STEPS_Z),
			"to": top_at, "facing": Vector3.RIGHT, "shot": "ringside"})
	# On the apron he stops and looks the ring over before he gets in.
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/roman_stand",
			"ticks": 60, "from": top_at, "to": top_at,
			"facing": Vector3.RIGHT, "shot": "ringside"})
	var inside := top + Vector3(ROPE_TO.x, 0.0, 0.0)
	var in_at := Vector3(inside.x, 0.0, STEPS_Z)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/rope_step_through",
			"ticks": int(round(ROPE_SECONDS * TPS)),
			"from": top_at, "to": in_at, "facing": Vector3.RIGHT, "shot": "ringside"})
	# To the middle of the ring, and the finger again facing the hard camera
	# side with the post pyro on it.
	var centre := Vector3(-0.4, 0.0, -0.6)
	_beats.append({"kind": "walk", "who": w, "path": [in_at, centre],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.BACK,
			"shot": "ring_low"})
	_beats.append({"kind": "pose", "who": w, "ticks": 120,
			"clip": "strikes/finger_raise", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[FINGER_PYRO_AT, "pyro_posts"]]})
	# The title goes to the timekeeper and the ula fala comes off.
	_beats.append({"kind": "pose", "who": w, "ticks": 90,
			"clip": "strikes/ula_fala_off", "facing": Vector3.BACK,
			"shot": "ring_low",
			"events": [[1, "title_down"], [ULA_FALA_LIFT_AT, "fala_off"]]})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [centre, mark.origin],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_FREE_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true,
			"events": [[SETTLE_TICKS, "tron_off"], [SETTLE_TICKS, "dim_off"]]})


static func _with(base: Dictionary, beat: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(beat, true)
	return out


## A cue inside a beat.
func _event(w: WrestlerController, what: String) -> void:
	var props: EntranceProps = _props.get(w)
	match what:
		"title_held":
			if props:
				props.set_title("held")
		"title_draped":
			if props:
				props.set_title("draped")
		"title_down":
			if props:
				props.set_title("")
		"fala_off":
			if props:
				props.set_fala_visible(false)
		"tron_on":
			if _wall:
				_wall.play_entrance(w.entrance_style)
		"tron_off":
			if _wall:
				_wall.end_entrance()
		"dim_on":
			_dim_house(true)
		"dim_off":
			_dim_house(false)
		"pyro_stage", "pyro_posts":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))


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
		"intro":
			_intro_shot()
		"face_walk":
			var head := _head_of(w)
			var fwd := -w.global_transform.basis.z
			var right := w.global_transform.basis.x
			_camera.set_entrance_shot(head + fwd * FACE_DISTANCE + right * 0.35
					+ Vector3.UP * 0.05, head, FACE_FOV, first, delta)
		"floor_track":
			var fwd2 := -w.global_transform.basis.z
			var right2 := w.global_transform.basis.x
			_camera.set_entrance_shot(w.global_position + fwd2 * 4.2 - right2 * 1.6
					+ Vector3.UP * 1.5, w.global_position + Vector3.UP * 1.45,
					FLOOR_TRACK_FOV, first, delta)
		"stage_push":
			var t := clampf(float(_tick) / float(beat["ticks"]), 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			_camera.set_entrance_shot(PUSH_FROM.lerp(PUSH_TO, e),
					w.global_position + Vector3.UP * 1.45,
					lerpf(PUSH_FOV.x, PUSH_FOV.y, e), true)
		"hero_low":
			_camera.set_entrance_shot(w.global_position + HERO_OFFSET,
					w.global_position + Vector3.UP * 1.6, HERO_FOV, true)
		"stage_wide":
			_camera.set_entrance_shot(STAGE_WIDE_AT, STAGE_WIDE_LOOK, STAGE_WIDE_FOV, true)
		"ring_low":
			_camera.set_entrance_shot(w.global_position + RING_LOW_OFFSET,
					w.global_position + Vector3.UP * 1.5, RING_LOW_FOV, true)
		"ringside":
			_camera.set_entrance_shot(RINGSIDE_AT, w.global_position + Vector3.UP * 1.0,
					RINGSIDE_FOV, true)
		"faceoff":
			# The hard camera's own seat and lens, so the bell does not cut.
			_camera.set_entrance_shot(_camera.hard_cam_position,
					(_a.global_position + _b.global_position) * 0.5
					+ Vector3.UP * _camera.hard_cam_aim, _camera.hard_cam_fov, true)


## The pre-entrance montage: which of ROMAN_INTRO_SHOTS the hold is in, and
## how far through its move, eased (smoothstep) so every move starts and
## settles gently. A new shot is a cut.
func _intro_shot() -> void:
	var at := float(_tick) / TPS
	var start := 0.0
	for shot: Array in ROMAN_INTRO_SHOTS:
		var length: float = shot[6]
		if at <= start + length or shot == ROMAN_INTRO_SHOTS[-1]:
			var t := clampf((at - start) / length, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			_camera.set_entrance_shot((shot[0] as Vector3).lerp(shot[1], e),
					(shot[2] as Vector3).lerp(shot[3], e),
					lerpf(shot[4], shot[5], e), true)
			return
		start += length


## His head, for the close-ups: the head bone if the rig has one, else a
## fixed height over his root.
func _head_of(w: WrestlerController) -> Vector3:
	var sk := w.skeleton
	if sk:
		var i := sk.find_bone(w._skeleton_bone_name("Head"))
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin \
					+ Vector3.UP * 0.08
	return w.global_position + Vector3.UP * 1.75


## Dims the house for his entrance, or puts it back. Every rig light except
## the portal accents (the entrance's own cue) goes to ROMAN_HOUSE_DIM of
## itself, and the ambient to ROMAN_AMBIENT_DIM; the originals are kept and
## restored exactly.
func _dim_house(on: bool) -> void:
	if on == not _dimmed.is_empty():
		return
	if on:
		if _lights:
			for child in _lights.get_children():
				if child is Light3D and not String(child.name).begins_with("Accent"):
					_dimmed[child] = (child as Light3D).light_energy
					(child as Light3D).light_energy *= ROMAN_HOUSE_DIM
		if _env:
			_dimmed[_env] = _env.ambient_light_energy
			_env.ambient_light_energy *= ROMAN_AMBIENT_DIM
		return
	for key in _dimmed:
		if key is Light3D and is_instance_valid(key):
			(key as Light3D).light_energy = _dimmed[key]
		elif key == _env:
			_env.ambient_light_energy = _dimmed[key]
	_dimmed.clear()


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
func _portal_lights(side: String, on: bool, tint: Color = Color.TRANSPARENT) -> void:
	if not _lights:
		return
	for child in _lights.get_children():
		if not (child is SpotLight3D) or not String(child.name).begins_with("Accent"):
			continue
		var light := child as SpotLight3D
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		if not light.has_meta("base_color"):
			light.set_meta("base_color", light.light_color)
		var base: float = light.get_meta("base_energy")
		var mine := on and String(light.name).begins_with("Accent" + side)
		light.light_energy = base * (2.4 if mine else 1.0)
		light.light_color = tint if mine and tint.a > 0.0 else light.get_meta("base_color")
