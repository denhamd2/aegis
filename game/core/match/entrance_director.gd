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
## Each beat as it starts, with the shot it is on (SignFans stands up for the
## stare-down's).
signal beat_started(shot: String)

# --- Pace and the travelling clips (tools/blender/wrestling_clips.py) --------
## The speed Entrance_Walk's planted foot travels at. Must match the clip.
const WALK_SPEED := 1.6
## Climb_Steps: 1.2 s, the root travelling (fwd 1.26, up 0.86) -- three
## treads of the ring steps, bottom-of-flight floor to top-tread centre.
const CLIMB_SECONDS := 1.2
const CLIMB_TO := Vector2(1.26, 0.86)
## How fast a turn on the spot goes, radians per second.
const TURN_RATE := 5.0

## Apron_Step: 1.0 s, off the top tread and up onto the apron beside the
## post, (fwd 1.0, up 0.24). Rope_Step_Through_Apron: 1.33 s, from the apron
## edge through the ropes onto the mat, (fwd 0.62, up 0).
const APRON_STEP_SECONDS := 1.0
const APRON_ROPE_SECONDS := 1.333
const APRON_ROPE_TO := Vector2(0.62, 0.0)

# --- Where things are ---------------------------------------------------------
## The flight every entrance climbs: the one on the corner diagonal at the
## hard camera's top left, (+3, -3), on the entrance side (ring_builder.gd
## "Steel steps"). He walks in along the diagonal, climbs toward the post,
## steps up onto the apron beside it, and goes through the ropes a pace along
## the -Z side from the post -- never through the post itself.
const ENTRY_CORNER := Vector2(1.0, -1.0)
## Where on the apron he goes through the ropes: this far along the side
## from the post, and on the apron's standing strip (3.0 .. 3.2).
const APRON_ALONG_M := 0.55
const APRON_STAND := 3.12
## Straight out along the diagonal from the climb's start, so he arrives
## square to the flight rather than cutting its corner.
const APPROACH_M := 0.8
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
## The face-off before the bell (the owner: "just have them walk up to each
## other to do a face off, then the bell rings"). Both walk in off their
## marks until they are FACEOFF_GAP apart, centre to centre -- chest to chest
## less a hand, as a stare-down is -- hold it, then turn and walk back to
## their marks and turn round, where the bell finds them. The match starts on
## the marks, exactly as it did, so nothing downstream moves.
const FACEOFF_GAP := 0.75
const FACEOFF_WALK_SPEED := 0.9
const FACEOFF_STARE_TICKS := 210
## Back to the marks: the turn away, and the turn back at the end.
const FACEOFF_TURN_TICKS := 30
## A beat on the marks, facing, before the bell.
const FACEOFF_SET_TICKS := 30

# --- Camera shots (project values; refs/camera.md measures none of these) ---
## The face-off two-shot: from the hard camera's side of the pair, square to
## them, a little under head height, close enough for both heads and chests.
const FACEOFF_CAM_DISTANCE := 3.4
const FACEOFF_CAM_HEIGHT := 1.5
const FACEOFF_CAM_FOV := 34.0
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
## At ringside on the ring's +X side, inside the barricade, at a cameraman's
## shoulder: the walk in from the ramp foot comes toward it, the diagonal
## steps at the (+3, -3) corner are three-quarter on four metres away, and the
## ropes are in frame. The first version
## stood outside the barricade at (-7.2, -0.25, -7.8) and rendered the whole
## climb behind the barricade panels and the ringside chairs.
const RINGSIDE_AT := Vector3(5.5, 1.0, 0.4)
const RINGSIDE_FOV := 42.0

## The follow spot, in the rafters at the far end of the hall, throwing the
## length of the building onto whoever is walking. Without it he walked the
## ramp in silhouette: nothing in the rig lights the ramp, because nothing in
## a match happens there.
const FOLLOW_SPOT_AT := Vector3(0.0, 17.0, 22.0)
const FOLLOW_SPOT_ENERGY := 40.0
const FOLLOW_SPOT_ANGLE := 3.5

# --- Roman Reigns (gauntlet/refs/entrances.md, "Roman: beat sheet") ---------
## Slow and methodical: Walk_Slow_Look travels 0.5 m/s,
## half the generic entrance's pace, and turn his head over the crowd as he
## goes (wrestling_clips.py _methodical_walk).
const ROMAN_WALK_SPEED := 0.5
const ROMAN_WALK_CLIP := "strikes/walk_slow_look"
## He does not come out until the main part of his music hits. Measured off
## the audio of assets/environment/video/roman_entrance.ogv, 0.1 s windows:
## near silence 42.5-44.9 s (RMS 0.011) and the full track slams back at
## 45.0 s (0.132). The broadcast puts the FINGER on that slam, with the pyro
## (R-41: finger 40 s, pyro and cut 42 s) -- so he is out long before it.
const ROMAN_MUSIC_HIT := 45.0
## On the lip before the finger: the slow push-in while he looks the building
## over, then the close-up (R-41 30-40 s, 1:04).
const ROMAN_LIP_PUSH := 4.0
const ROMAN_LIP_FACE := 3.0
## After the slam: the very wide of the pyro, then the finger held under the
## low wide from the ramp until this music time (R-41: 40 s to 58 s).
const ROMAN_PYRO_WIDE := 2.5
const ROMAN_FINGER_DOWN := 58.0
## The room goes red for the pyro and back to blue, in ticks.
const ROMAN_RED_TICKS := 90
## Head bowed at ringside (R-41 2:42-3:04 is twenty seconds; held here four).
const ROMAN_BOW_TICKS := 240
## The walk, cut the way R-41 cuts it: the low ultra-wide steadicam backing
## ahead of him, a very wide from high every six to eight seconds, and once
## over his shoulder down the ramp (R-CJ). [shot, seconds], cycled.
const ROMAN_WALK_SHOTS := [["steadicam_low", 6.0], ["arena_high", 3.0],
		["steadicam_low", 7.0], ["over_shoulder", 4.0], ["steadicam_low", 6.0],
		["arena_high", 3.0]]
## Until then the broadcast shows the building and his video: six shots, each
## a slow move eased in and out (blender-cameras: push-ins, a truck, a wide
## establishing lens), in seconds. [from, to, look_from, look_to, fov_from,
## fov_to, seconds]. Lenses as vertical FOV: 53 ~ 24 mm, 38 ~ 35 mm,
## 27 ~ 50 mm, 16 ~ 85 mm.
const ROMAN_INTRO_SHOTS := [
	# The building, the stage empty under his light: high in the far end, a
	# 24 mm wide, trucking across (R-41 0-10 s).
	[Vector3(9.0, 9.5, 19.0), Vector3(3.0, 9.8, 20.0),
		Vector3(0.0, 3.0, -18.0), Vector3(0.0, 3.2, -20.0), 53.0, 50.0, 8.0],
	# His video on the wall, from low on the ramp, pushing in.
	[Vector3(0.0, 2.6, -18.0), Vector3(0.0, 3.2, -22.0),
		Vector3(0.0, 9.2, -36.5), Vector3(0.0, 9.3, -36.5), 32.0, 26.0, 7.0],
	# Head on into the portals, long lens, creeping in until he appears
	# (R-41 12-18 s).
	[Vector3(0.0, 1.0, -23.0), Vector3(0.0, 1.0, -25.5),
		Vector3(0.0, 2.4, -36.5), Vector3(0.0, 2.3, -36.5), 30.0, 24.0, 12.0],
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

# --- Cody Rhodes (gauntlet/refs/entrances.md, "Cody: cut to his music") -----
## Every time below is MUSIC time in his video's own audio (cody_entrance.ogv,
## 80 s), measured: the intro's three swells (0.8, 3.6, 6.3 s), the band in at
## 7.9 s, and the sung chant from 22.5 s -- vocal onsets at 22.5, 24.0, 26.0,
## 29.0, 36.5 and the chorus's big held WHOAAA at 43.5 s. Seven WWE.com
## entrance clips were aligned to this track by cross-correlating their audio
## (every one starts on the music, +0.2 s), which put what the broadcast shows
## on it: nobody on camera until the smoke (MITB 22.3 s), out of it on the
## first sung WHOA, the WHOA pose, the pyro 2.5 s into it and the fists 5 s
## into it (C-39), the kneel at the lip (C-MITB), the low WHOA mid-aisle on the
## held WHOAAA (C-SNME). He used to be out on the third intro swell, 16 s early.
const CODY_WHOA_1 := 0.8
const CODY_WHOA_2 := 3.6
const CODY_WHOA_3 := 6.3
const CODY_BAND := 7.9
const CODY_SMOKE := 20.3
## The first sung WHOA: he steps out of the smoke.
const CODY_EMERGE := 22.5
## Arms thrown wide on the chant.
const CODY_WHOA := 24.0
const CODY_PYRO := 26.0
## Both fists driven down.
const CODY_PUNCH := 29.0
## His knee on the mat at the lip.
const CODY_KNEEL := 36.5
## The low WHOA down the ramp, on the held WHOAAA.
const CODY_WHOA_LOW := 43.5
## Where in each clip its accent lands, in ticks: Whoa_Arms' arms are wide on
## frame 11, Kneel's knee down on 22, Whoa_Low's arms wide on 10.
const WHOA_WIDE_AT := 22
const KNEEL_DOWN_AT := 44
const WHOA_LOW_WIDE_AT := 20
## He walks with purpose and works the crowd: Walk_Crowd travels 1.2 m/s.
const CODY_WALK_SPEED := 1.2
const CODY_WALK_CLIP := "strikes/walk_crowd"
## Air_Punch's fist arrives on frame 10: the second pyro.
const CODY_PUNCH_AT := 20
## Kneel: 5.0 s at the top of the ramp (C-MITB 40-44 s).
const CODY_KNEEL_TICKS := 300
## Whoa_Low, played through.
const CODY_WHOA_LOW_TICKS := 200
## His walk, cut as C-39 and C-SS cut it: the low steadicam ahead of him and a
## wide of the building. [shot, seconds], cycled.
const CODY_WALK_SHOTS := [["steadicam_low", 4.0], ["arena_high", 2.5],
		["steadicam_low", 3.0]]
## Corner_Pose has the arms fully wide by frame 12: the post sparks.
const CODY_CORNER_PYRO_AT := 24
## Coat_Off has his arms behind him, the coat sliding off, on frame 36.
const COAT_OFF_AT := 72
## Where he stands to climb the corner: this far from the post along the
## diagonal, facing out over it (wrestling_clips.py CORNER_FOOT_*).
const CORNER_ROOT_M := 0.62
## The blackout: the rig to 3% and the ambient to 10%, portal accents off.
## His light in the dark is one cold backlight behind him in his portal, so
## on the WHOAs the camera sees him as a silhouette in the haze.
const CODY_BLACKOUT := 0.03
const CODY_BLACKOUT_AMBIENT := 0.10
const BACKLIGHT_ENERGY := 30.0
const BACKLIGHT_COLOR := Color(0.82, 0.88, 1.0)
const CODY_RED := Color(1.0, 0.12, 0.10)
const CODY_BLUE := Color(0.18, 0.32, 1.0)
## His shots. The dark wide from high behind the hard camera; the long lens
## on his portal from down the ramp (85 mm, pushing in); a steadicam backing
## ahead of him; and the low angle inside the ring up past him in the corner.
const CODY_DARK_AT := Vector3(0.0, 9.0, 16.0)
const CODY_DARK_LOOK := Vector3(0.0, 3.0, -30.0)
const CODY_DARK_FOV := 50.0
const PORTAL_LONG_FOV := Vector2(19.0, 14.0)
const STEADICAM_FOV := 32.0
const CORNER_LOW_AT := Vector3(1.2, 0.35, -1.2)
const CORNER_LOW_FOV := 50.0
## Cues inside his clips, in ticks from the clip's start (clip frame x 2):
## Title_Unbuckle opens the belt on frame 20 and it moves from his waist to
## his left hand on frame 22; Finger_Raise's arm arrives on frame 14 -- the
## pyro hit -- and Ula_Fala_Off has it over his head by frame 20.
const TITLE_UNBUCKLED_AT := 44
const FINGER_PYRO_AT := 28
const ULA_FALA_LIFT_AT := 40
## The OTC look is blue (R-41, R-CJ, and his own wall video): his portal
## accents go blue, and red only for the pyro (R-41 42 s).
const ROMAN_BLUE := Color(0.22, 0.52, 1.0)
const ROMAN_PYRO_RED := Color(1.0, 0.10, 0.16)
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

# --- The broadcast's shots (refs/entrances.md "Measured off broadcast") ---
## The signature walk shot, both men: an ultra-wide steadicam backing ahead
## of him with the lens at his hips, tilted up past his chest to the roof.
const STEADICAM_LOW_AHEAD := 1.3
const STEADICAM_LOW_HEIGHT := 0.55
const STEADICAM_LOW_FOV := 68.0
## The very wide from high at the far end, over the ring, on him.
const ARENA_HIGH_AT := Vector3(7.5, 11.0, 13.0)
const ARENA_HIGH_FOV := 50.0
## Behind him, over his shoulder, down the ramp at the crowd (R-CJ).
const OVER_SHOULDER_FOV := 50.0
## Low on the ramp looking up at him small under the set (R-41 50-58 s).
const RAMP_LOW_WIDE_AT := Vector3(0.0, 0.9, ArenaBuilder.STAGE_FRONT + 8.5)
const RAMP_LOW_WIDE_FOV := 46.0
## A long lens from down the ramp on him at the lip (C-MITB, the kneel).
const RAMP_LONG_BACK := 9.0
const RAMP_LONG_FOV := 22.0
## Inside the ring, low, behind him as he comes through the ropes (C-SNME).
const RING_BEHIND_FOV := 70.0
## The hard-camera side crowd, for the WHOAs in the dark (C-MITB 12-20 s).
const CROWD_WIDE_AT := Vector3(3.8, 1.6, 1.0)
const CROWD_WIDE_LOOK := Vector3(16.0, 4.5, 0.0)
const CROWD_WIDE_FOV := 40.0
## Roman's bowed head at the steps, close, from his right.
const BOW_SIDE := 1.9
const BOW_AHEAD := 0.7
const BOW_FOV := 26.0
## The smoke he walks out of: a bank of it on the deck, knee deep, in his
## portal mouth (C-MITB 22-26 s) -- a full-height box lit from behind went
## white and hid him.
const SMOKE_SIZE := Vector3(5.0, 1.1, 4.0)
const SMOKE_DENSITY := 0.5

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
## Cody's entrance coat, per man.
var _coats := {}
var _pyro: EntrancePyro
## The stage wall, for his own titantron.
var _wall: StageVideo
## Light energies saved while the house is dimmed, to put back exactly.
var _dimmed := {}
var _env: Environment
## Cody's backlight, built on his first WHOA.
var _backlight: SpotLight3D
## Cody's smoke in his portal, while he walks out of it.
var _smoke: FogVolume
## Beats marked no_follow keep the follow spot off (Cody's silhouettes).
var _follow_off := false

## The timeline: one entry per beat, built once in begin().
var _beats: Array = []
var _beat := 0
var _tick := 0
var _done := false


## The crowd's reaction to a pyro hit (CrowdReaction).
const CROWD_PYRO_POP := 0.8
var _crowd: CrowdReaction


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
	# Phones out for the entrances (CrowdReaction; refs/aaa_gap.md item 11).
	_crowd = get_tree().get_first_node_in_group("crowd_reaction") as CrowdReaction
	if _crowd:
		_crowd.set_flashes(CrowdReaction.ENTRANCE_FLASH_RATE)
		_crowd.pop(0.4)
	# Their marks, squared up to each other. The scene's spawn transforms
	# face OUTWARD (a wrestler faces his node's -Z, and WrestlerA stands at
	# z -1.5 with an identity basis), which the match never showed because
	# WrestlerController turns a man to his opponent from the first tick.
	# The entrance ends on these marks, frozen, so the owner saw both men
	# finish their entrances with their backs to each other.
	for pair: Array in [[_a, _b], [_b, _a]]:
		var me: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		var mark := me.global_transform
		var to_other := _flat(other.global_position - me.global_position)
		if to_other.length() > 0.01:
			mark.basis = _facing_basis(to_other)
		_mark[me] = mark

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
		elif w.entrance_style == "cody":
			_add_cody_entrance(w, pair[1], pair[2])
		else:
			_add_entrance(w, pair[1], pair[2])
	_add_faceoff()


## Walk up, stare down, back to the marks (FACEOFF_GAP's note). Each beat is a
## "pair" beat: both men move at once, each on his own line.
func _add_faceoff() -> void:
	var a: Transform3D = _mark[_a]
	var b: Transform3D = _mark[_b]
	var mid := (a.origin + b.origin) * 0.5
	var a_in := mid + _flat(a.origin - mid).normalized() * (FACEOFF_GAP * 0.5)
	var b_in := mid + _flat(b.origin - mid).normalized() * (FACEOFF_GAP * 0.5)
	var walk := maxi(1, int(ceil(_flat(a.origin).distance_to(_flat(a_in))
			/ FACEOFF_WALK_SPEED * TPS)))
	var face_a := _flat(b.origin - a.origin)
	var face_b := -face_a
	_beats.append({"kind": "pair", "ticks": walk, "shot": "faceoff_side", "moves": [
			[_a, a.origin, a_in, face_a, "strikes/entrance_walk"],
			[_b, b.origin, b_in, face_b, "strikes/entrance_walk"]]})
	_beats.append({"kind": "pair", "ticks": FACEOFF_STARE_TICKS, "shot": "faceoff_side",
			"moves": [[_a, a_in, a_in, face_a, "strikes/face_off"],
					[_b, b_in, b_in, face_b, "strikes/face_off"]]})
	# Back to their marks: turned away, walked, turned round.
	_beats.append({"kind": "pair", "ticks": FACEOFF_TURN_TICKS, "shot": "faceoff",
			"moves": [[_a, a_in, a_in, face_b, "strikes/face_off"],
					[_b, b_in, b_in, face_a, "strikes/face_off"]]})
	_beats.append({"kind": "pair", "ticks": walk, "shot": "faceoff", "moves": [
			[_a, a_in, a.origin, face_b, "strikes/entrance_walk"],
			[_b, b_in, b.origin, face_a, "strikes/entrance_walk"]]})
	_beats.append({"kind": "pair", "ticks": FACEOFF_TURN_TICKS + FACEOFF_SET_TICKS,
			"shot": "faceoff", "moves": [
			[_a, a.origin, a.origin, face_a, _wait_clip(_a)],
			[_b, b.origin, b.origin, face_b, _wait_clip(_b)]]})


## What a man does standing in the ring waiting -- never the grapple crouch
## (Idle_Ready), which is a match stance: his own entrance stand if he has
## one, else the face-off's square stance.
static func _wait_clip(w: WrestlerController) -> String:
	match w.entrance_style:
		"roman":
			return "strikes/roman_stand"
		"cody":
			return "strikes/cody_stand"
	return "strikes/face_off"


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
	# The cut: a few metres short of the ramp foot, then round to the steps.
	var inside := _add_route_in(w, Vector3(0.0, 0.0, CUT_TO_Z), WALK_SPEED,
			"strikes/entrance_walk", false)
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w,
			"path": [inside, mark.origin],
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true})


func _start_beat() -> void:
	_tick = 0
	if _beat >= _beats.size():
		_ring_bell()
		return
	var beat: Dictionary = _beats[_beat]
	beat_started.emit(String(beat.get("shot", "")))
	var w: WrestlerController = beat.get("who")
	if beat.get("appear", false) and w:
		# Placed in the same step he is shown, or the frame in between renders
		# him standing at his in-ring spawn for a sixtieth of a second.
		_place(w, beat["path"][0], _heading(beat["path"]), true)
		w.visible = true
	_follow_off = beat.get("no_follow", false)
	if beat.get("coat", false) and w and not _coats.has(w):
		_coats[w] = EntranceCoat.dress(w)
	if beat.get("props", false) and w and not _props.has(w):
		# The OTC carries no title (refs/entrances.md): the ula fala only.
		_props[w] = EntranceProps.dress(w, w.entrance_style != "roman")
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
			w.play_presentation_clip(_wait_clip(w))
		"pair":
			for move: Array in beat["moves"]:
				(move[0] as WrestlerController).play_presentation_clip(move[4])


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
		"pair":
			for move: Array in beat["moves"]:
				var m: WrestlerController = move[0]
				_place(m, (move[1] as Vector3).lerp(move[2], t), move[3], false, delta)
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
	for coat: EntranceCoat in _coats.values():
		coat.queue_free()
	_coats.clear()
	if _pyro:
		_pyro.queue_free()
		_pyro = null
	if _wall:
		_wall.end_entrance()
	_dim_house(false)
	if _backlight:
		_backlight.queue_free()
		_backlight = null
	_smoke_off()
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
	if _crowd:
		_crowd.set_flashes(0.0)
		_crowd.pop(0.7)
	bell.emit()


## Roman Reigns, the OTC, as the broadcast does it (gauntlet/refs/entrances.md
## "Measured off broadcast footage", R-41 and R-CJ). The set blue, the stage
## empty while his music builds; he is found deep in his portal walking at a
## long lens, stops on the lip and looks the building over, a close-up, and
## the finger goes up so that it is in the air when the music slams (45.0 s)
## and the pyro and the red flash go with it. He HOLDS it -- eighteen seconds
## in the footage, under a low wide from the ramp -- then walks the whole way
## down on the low ultra-wide steadicam, cut with very wides from high and a
## look over his shoulder. At ringside, head bowed, eyes shut; up the steps
## and in; the finger to the hard camera, hands on hips, the ula fala off.
## No title: the OTC era.
func _add_roman_entrance(w: WrestlerController, portal_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 1.2)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var blue := {"lights": side, "light_color": ROMAN_BLUE}
	# Backward from the slam: the finger's arm arrives FINGER_PYRO_AT ticks
	# into Finger_Hold, so it starts that much before the slam; before it he
	# stands on the lip (the push-in, then the close-up); before that, the walk
	# out from the portal at his pace. What is left of the music is the empty
	# stage.
	var finger_start := ROMAN_MUSIC_HIT - float(FINGER_PYRO_AT) / TPS
	var stand_start := finger_start - ROMAN_LIP_PUSH - ROMAN_LIP_FACE
	var walk_s := _flat(emerge).distance_to(_flat(lip)) / ROMAN_WALK_SPEED
	var appear := stand_start - walk_s
	_beats.append({"kind": "hold", "who": w,
			"ticks": _secs(0.0, appear), "shot": "intro",
			"events": [[1, "tron_on"], [1, "dim_on"]]})
	var half := emerge.lerp(lip, 0.5)
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [emerge, half],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "stage", "appear": true, "props": true}))
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [half, lip],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "face_walk"}))
	# On the lip: the building looked over, then the close-up.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(0.0, ROMAN_LIP_PUSH),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "stage_push", "card": true}))
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(0.0, ROMAN_LIP_FACE),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "face_walk", "card": true}))
	# The finger, and on the slam the pyro and the room red, on a very wide.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(finger_start, ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "stage_wide",
			"events": [[FINGER_PYRO_AT, "pyro_roman"], [FINGER_PYRO_AT, "accent_red"],
					[FINGER_PYRO_AT + ROMAN_RED_TICKS, "accent_back"]]}))
	# Held, under the low wide from the ramp.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE, ROMAN_FINGER_DOWN),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ramp_low_wide"}))
	# The walk: all of it, cut the way the broadcast cuts it.
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS - 0.2)
	_add_walk_cut(w, lip, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, ROMAN_WALK_SHOTS)
	# Ringside, the head bowed, then up the steps and through the ropes.
	var in_at := _add_route_in(w, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, true, "",
			"strikes/head_bow", ROMAN_BOW_TICKS)
	var centre := Vector3(-0.4, 0.0, -0.6)
	_beats.append({"kind": "walk", "who": w, "path": [in_at, centre],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.BACK,
			"shot": "ring_low"})
	# The finger to the hard camera, then hands on hips, staring, close.
	_beats.append({"kind": "pose", "who": w, "ticks": 240,
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ring_low"})
	_beats.append({"kind": "pose", "who": w, "ticks": 300,
			"clip": "strikes/hands_hips", "facing": Vector3.BACK,
			"shot": "face_walk"})
	_beats.append({"kind": "pose", "who": w, "ticks": 90,
			"clip": "strikes/ula_fala_off", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[ULA_FALA_LIFT_AT, "fala_off"]]})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [centre, mark.origin],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true,
			"events": [[SETTLE_TICKS, "tron_off"], [SETTLE_TICKS, "dim_off"]]})


## A long walk from `from` to `to` as the broadcast cuts it: consecutive
## walk beats, each on the next of `shots` ([shot, seconds], cycled), so he
## never stops and the cut is only the camera's.
func _add_walk_cut(w: WrestlerController, from: Vector3, to: Vector3, speed: float,
		clip: String, shots: Array) -> void:
	var total := _flat(from).distance_to(_flat(to))
	var done := 0.0
	var i := 0
	while done < total - 0.01:
		var shot: Array = shots[i % shots.size()]
		var step := minf(float(shot[1]) * speed, total - done)
		var a := from.lerp(to, done / total)
		var b := from.lerp(to, (done + step) / total)
		_beats.append({"kind": "walk", "who": w, "path": [a, b], "speed": speed,
				"walk_clip": clip, "shot": shot[0]})
		done += step
		i += 1


## Cody Rhodes, as the broadcast does it (gauntlet/refs/entrances.md
## "Measured off broadcast footage", C-39, C-MITB, C-SS, C-SNME). Black, and
## through the WHOAs the cameras are on the BUILDING -- the crowd, the dark
## wide -- not on him. On the last WHOA he walks out of the smoke in his
## portal, backlit, at a long lens; on the hit, the WHOA pose -- arms straight
## out, palms forward, head back -- and the pyro on a very wide; then both
## fists driven down, and the second burst. To the lip on the low steadicam,
## and there the kneel: down on the right knee, head bowed, then up at the
## crowd. Down the ramp working both sides, the WHOA again low in the aisle,
## round to the steps and in over the ropes with the camera low behind him in
## the ring. Every beat to the hit is on the measured music (CODY_*).
func _add_cody_entrance(w: WrestlerController, portal_x: float, _side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var mouth := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 0.5)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var foot_of_ramp := Vector3(0.0, 0.0, CUT_TO_Z)
	# He walks out of the smoke at his own pace: far enough back in it that
	# Walk_Crowd's planted foot keeps the mat from sliding under the boot.
	var emerge_s := CODY_WHOA - float(WHOA_WIDE_AT) / TPS - CODY_EMERGE
	var smoke := mouth - Vector3(0.0, 0.0, CODY_WALK_SPEED * emerge_s)
	var dark := {"lights": "OFF", "no_follow": true}
	# The intro and the band: black, the wall, and the building -- the crowd
	# and the dark wide, a strobe on each swell -- never the man.
	_beats.append({"kind": "hold", "who": w, "ticks": _secs(0.0, CODY_WHOA_1),
			"shot": "cody_dark", "lights": "OFF",
			"events": [[1, "tron_on"], [1, "blackout_on"]]})
	for cut: Array in [[CODY_WHOA_1, CODY_WHOA_2, "crowd_wide", true],
			[CODY_WHOA_2, CODY_WHOA_3, "cody_dark", true],
			[CODY_WHOA_3, CODY_BAND, "crowd_wide", true],
			[CODY_BAND, 12.0, "cody_dark", false],
			[12.0, 16.0, "crowd_wide", false],
			[16.0, CODY_SMOKE, "cody_dark", false]]:
		_beats.append(_with(dark, {"kind": "hold", "who": w,
				"ticks": _secs(cut[0], cut[1]), "shot": cut[2],
				"events": [[1, "strobe"]] if cut[3] else []}))
	# The smoke builds in his portal, lit from behind, the long lens creeping.
	_beats.append(_with(dark, {"kind": "hold", "who": w,
			"ticks": _secs(CODY_SMOKE, CODY_EMERGE), "shot": "portal_long",
			"portal": mouth, "push_from": 0, "push_over": _secs(CODY_SMOKE, CODY_WHOA),
			"fog_at": smoke, "lights": "RB_LOW",
			"events": [[1, "fog_on"], [1, "backlight_on"]]}))
	# Out of it on the first sung WHOA, at the lens.
	_beats.append({"kind": "walk", "who": w, "appear": true, "coat": true,
			"no_follow": true, "lights": "RB_LOW", "path": [smoke, mouth],
			# A hair over the exact speed, so the tick count rounds to the
			# measured gap and the WHOA lands on its frame.
			"speed": _flat(smoke).distance_to(_flat(mouth))
					/ (float(_secs(CODY_EMERGE, CODY_WHOA - float(WHOA_WIDE_AT) / TPS))
					/ TPS) * 1.000001,
			"walk_clip": CODY_WALK_CLIP, "shot": "portal_long", "portal": mouth,
			"push_from": _secs(CODY_SMOKE, CODY_EMERGE),
			"push_over": _secs(CODY_SMOKE, CODY_WHOA)})
	# THE WHOA: the wind-up, then the arms wide on the chant and the building
	# lit with it; held on the long lens from down the ramp (C-39 21-23 s),
	# the very wide for the pyro (C-39 23.5 s).
	var whoa_from := CODY_WHOA - float(WHOA_WIDE_AT) / TPS
	_beats.append({"kind": "pose", "who": w, "lights": "RB_LOW",
			"ticks": WHOA_WIDE_AT, "clip": "strikes/whoa_arms",
			"facing": Vector3.BACK, "shot": "ramp_long"})
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(whoa_from, CODY_PYRO) - WHOA_WIDE_AT,
			"clip": "strikes/whoa_arms", "facing": Vector3.BACK, "shot": "ramp_long",
			"events": [[1, "dim_off"], [1, "backlight_off"], [1, "fog_off"]]})
	var punch_from := CODY_PUNCH - float(CODY_PUNCH_AT) / TPS
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(CODY_PYRO, punch_from), "clip": "strikes/whoa_arms",
			"facing": Vector3.BACK, "shot": "stage_wide",
			"events": [[1, "pyro_cody_hit"]]})
	# The fists, the second burst, the card.
	var fists_end := punch_from + 1.0 + 1.0 / 3.0
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(punch_from, fists_end), "clip": "strikes/fists_down",
			"facing": Vector3.BACK, "shot": "hero_low", "card": true,
			"events": [[CODY_PUNCH_AT, "pyro_cody_punch"]]})
	# To the lip on the low steadicam, the card up until he stops; working
	# the crowd there for whatever is left, so the knee lands on its phrase.
	var kneel_from := CODY_KNEEL - float(KNEEL_DOWN_AT) / TPS
	# A short gap goes into his pace, not a stand: a presentation clip held
	# for less than its cross-fade never finishes blending in, and the clip
	# after it was lost with it -- rendered, he stood through the whole kneel
	# behind a 0.33 s stand. Only a gap long enough to blend gets one.
	var to_lip := _flat(mouth).distance_to(_flat(lip))
	var lip_speed := to_lip / (kneel_from - fists_end)
	if lip_speed < CODY_WALK_SPEED * 0.8:
		lip_speed = CODY_WALK_SPEED
	lip_speed = minf(lip_speed, CODY_WALK_SPEED * 1.4)
	_beats.append({"kind": "walk", "who": w, "path": [mouth, lip], "lights": "RB",
			"speed": lip_speed, "walk_clip": CODY_WALK_CLIP,
			"shot": "steadicam_low", "card": true})
	var at_lip := fists_end + to_lip / lip_speed
	if kneel_from - at_lip > 0.6:
		_beats.append({"kind": "pose", "who": w, "lights": "RB",
				"ticks": _secs(at_lip, kneel_from), "clip": "strikes/cody_stand",
				"facing": Vector3.BACK, "shot": "steadicam_low"})
	# The kneel at the top of the ramp, on a long lens from down it.
	_beats.append({"kind": "pose", "who": w, "lights": "RB", "ticks": CODY_KNEEL_TICKS,
			"clip": "strikes/kneel", "facing": Vector3.BACK, "shot": "ramp_long"})
	# Down the ramp exactly as far as his pace takes him before the held
	# WHOAAA, and the low WHOA there.
	var kneel_end := kneel_from + float(CODY_KNEEL_TICKS) / TPS
	var low_from := CODY_WHOA_LOW - float(WHOA_LOW_WIDE_AT) / TPS
	var down := CODY_WALK_SPEED * (low_from - kneel_end)
	var mid := lip.lerp(foot_of_ramp, clampf(down / _flat(lip).distance_to(_flat(foot_of_ramp)),
			0.0, 1.0))
	_beats.append({"kind": "walk", "who": w, "path": [lip, mid], "lights": "RB",
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "steadicam_low"})
	_beats.append({"kind": "pose", "who": w, "ticks": CODY_WHOA_LOW_TICKS,
			"clip": "strikes/whoa_low", "facing": Vector3.BACK, "shot": "hero_low"})
	var foot := foot_of_ramp
	_add_walk_cut(w, mid, foot, CODY_WALK_SPEED, CODY_WALK_CLIP, CODY_WALK_SHOTS)
	var in_at := _add_route_in(w, foot, CODY_WALK_SPEED, CODY_WALK_CLIP, false,
			"", "", 0, "ring_behind_low")
	# The corner by the steps: up on the middle rope, facing out over them.
	# (Sourced [S], not in any of the measured clips.)
	# Measured from the turnbuckle pads, which are where the man stands on
	# the ropes -- not the post, which now stands out at the deck corner
	# beyond the turnbuckle hardware (RingBuilder.POST_XZ).
	var post := Vector3(ENTRY_CORNER.x * RingBuilder.TURNBUCKLE_PAD_XZ, 0.0,
			ENTRY_CORNER.y * RingBuilder.TURNBUCKLE_PAD_XZ)
	var out_dir := RingBuilder.step_out_dir(ENTRY_CORNER)
	var stand := post - out_dir * CORNER_ROOT_M
	_beats.append({"kind": "walk", "who": w, "path": [in_at, stand],
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "ring_behind_low", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": out_dir, "shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_climb",
			"ticks": 72, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_pose",
			"ticks": 180, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low", "events": [[CODY_CORNER_PYRO_AT, "pyro_posts"]]})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_down",
			"ticks": 60, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low"})
	# Down off the rope, and the coat comes off to the crew at ringside.
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/coat_off",
			"ticks": 120, "from": stand, "to": stand, "facing": out_dir,
			"shot": "ringside", "events": [[COAT_OFF_AT, "coat_off"]]})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [stand, mark.origin],
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true, "events": [[SETTLE_TICKS, "tron_off"]]})


## The way into the ring every entrance shares, from the ramp's cut to the
## mat, over the diagonal steps (ring_builder.gd "Steel steps"): across the
## floor to the foot of the flight, in along its diagonal, up it toward the
## post, up onto the apron beside the post, and through the ropes a pace along
## the side. Appends the beats; returns where he lands on the mat.
##
## `split_floor` gives the floor walk its own tracking shot up to the
## approach (Roman's); `survey_clip`, if set, is played standing on the apron
## before he goes in; `floor_clip`, if set, is played for `floor_ticks` at the
## foot of the steps, facing them, on a close shot (Roman's bowed head);
## `entry_shot` frames the step through the ropes (Cody's is from inside the
## ring, low, behind him).
func _add_route_in(w: WrestlerController, cut: Vector3, speed: float,
		walk_clip: String, split_floor: bool, survey_clip := "",
		floor_clip := "", floor_ticks := 0, entry_shot := "ringside") -> Vector3:
	var out := RingBuilder.step_out_dir(ENTRY_CORNER)
	var top := RingBuilder.step_top_centre(ENTRY_CORNER)
	var climb_from := top + out * CLIMB_TO.x
	var approach := climb_from + out * APPROACH_M
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS + 0.4)
	if split_floor:
		_beats.append({"kind": "walk", "who": w, "path": [cut, foot, approach],
				"speed": speed, "walk_clip": walk_clip, "shot": "floor_track", "cut": true})
		_beats.append({"kind": "walk", "who": w, "path": [approach, climb_from],
				"speed": speed, "walk_clip": walk_clip, "shot": "ringside"})
	else:
		_beats.append({"kind": "walk", "who": w, "path": [cut, foot, approach, climb_from],
				"speed": speed, "walk_clip": walk_clip, "shot": "ringside", "cut": true})
	_beats.append({"kind": "turn", "who": w, "facing": -out, "shot": "ringside"})
	if floor_clip != "":
		_beats.append({"kind": "pose", "who": w, "ticks": floor_ticks,
				"clip": floor_clip, "facing": -out, "shot": "bow_close"})
	var top_at := Vector3(top.x, ArenaBuilder.FLOOR_Y + CLIMB_TO.y, top.z)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/climb_steps",
			"ticks": int(round(CLIMB_SECONDS * TPS)),
			"from": Vector3(climb_from.x, ArenaBuilder.FLOOR_Y, climb_from.z),
			"to": top_at, "facing": -out, "shot": "ringside"})
	# Onto the apron, a pace along the side from the post.
	var apron := Vector3(ENTRY_CORNER.x * (RingBuilder.TURNBUCKLE_PAD_XZ - APRON_ALONG_M), 0.0,
			ENTRY_CORNER.y * APRON_STAND)
	var across := _flat(apron - top_at)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/apron_step",
			"ticks": int(round(APRON_STEP_SECONDS * TPS)),
			"from": top_at, "to": apron, "facing": across, "shot": "ringside"})
	# Square to the ropes: facing into the ring across the -Z side.
	var into := Vector3(0.0, 0.0, -ENTRY_CORNER.y)
	_beats.append({"kind": "turn", "who": w, "facing": into, "shot": "ringside"})
	if survey_clip != "":
		_beats.append({"kind": "clip", "who": w, "clip": survey_clip,
				"ticks": 60, "from": apron, "to": apron, "facing": into, "shot": "ringside"})
	var inside := apron + into * APRON_ROPE_TO.x
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/rope_step_through_apron",
			"ticks": int(round(APRON_ROPE_SECONDS * TPS)),
			"from": apron, "to": inside, "facing": into, "shot": entry_shot})
	return inside


## Ticks between two music times.
static func _secs(from: float, to: float) -> int:
	return int(round((to - from) * TPS))


## Cody's backlight: one cold spot in his portal behind him, aimed down the
## ramp at the camera, so he is a shape against light in the haze.
func _set_backlight(w: WrestlerController, what: String) -> void:
	if _backlight == null:
		_backlight = SpotLight3D.new()
		_backlight.name = "Backlight"
		_backlight.light_color = BACKLIGHT_COLOR
		_backlight.spot_angle = 28.0
		_backlight.spot_range = 40.0
		_backlight.light_volumetric_fog_energy = 3.0
		_backlight.shadow_enabled = true
		add_child(_backlight)
		_backlight.global_position = w.global_position + Vector3(0.0, 3.4, -2.6)
		_backlight.look_at(w.global_position + Vector3(0.0, 1.2, 6.0), Vector3.UP)
	match what:
		"backlight_on":
			_backlight.light_energy = BACKLIGHT_ENERGY
			_backlight.visible = true
		"backlight_dim":
			_backlight.light_energy = BACKLIGHT_ENERGY * 0.3
		"backlight_off":
			_backlight.visible = false


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
		"title_down":
			if props:
				props.set_title("")
		"coat_off":
			var coat: EntranceCoat = _coats.get(w)
			if coat:
				coat.set_worn(false)
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
		"blackout_on":
			_dim_house(true, CODY_BLACKOUT, CODY_BLACKOUT_AMBIENT)
		"backlight_on", "backlight_dim", "backlight_off":
			_set_backlight(w, what)
		"strobe", "pyro_cody_hit", "pyro_cody_punch":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			if _crowd:
				_crowd.pop(CROWD_PYRO_POP)
		"dim_off":
			_dim_house(false)
		"accent_red":
			_accents_to(ROMAN_PYRO_RED, 3.0)
		"accent_back":
			var now: Dictionary = _beats[mini(_beat, _beats.size() - 1)]
			_portal_lights(now.get("lights", ""), now.has("lights"),
					now.get("light_color", Color.TRANSPARENT))
		"fog_on":
			_smoke_on(w)
		"fog_off":
			_smoke_off()
		"pyro_stage", "pyro_posts", "pyro_roman":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			if _crowd:
				_crowd.pop(CROWD_PYRO_POP)


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
		"cody_dark":
			_camera.set_entrance_shot(CODY_DARK_AT, CODY_DARK_LOOK, CODY_DARK_FOV, true)
		"portal_long":
			# From down the ramp, dead on his portal, the lens creeping in
			# across the three WHOAs.
			var portal: Vector3 = beat.get("portal", w.global_position)
			var e := clampf(float(_tick + int(beat.get("push_from", 0)))
					/ float(beat.get("push_over", 400)), 0.0, 1.0)
			_camera.set_entrance_shot(Vector3(portal.x * 0.55, 1.6, -21.0),
					portal + Vector3.UP * 1.5,
					lerpf(PORTAL_LONG_FOV.x, PORTAL_LONG_FOV.y, e), true)
		"steadicam":
			var fwd3 := -w.global_transform.basis.z
			_camera.set_entrance_shot(w.global_position + fwd3 * 3.2 + Vector3.UP * 1.55,
					w.global_position + Vector3.UP * 1.5, STEADICAM_FOV, first, delta)
		"corner_low":
			_camera.set_entrance_shot(CORNER_LOW_AT, _head_of(w), CORNER_LOW_FOV, true)
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
		"steadicam_low":
			# Backing ahead of him, lens at his hips, tilted up past his chest.
			var f4 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position + f4 * STEADICAM_LOW_AHEAD
					+ Vector3.UP * STEADICAM_LOW_HEIGHT,
					w.global_position + Vector3.UP * 1.55, STEADICAM_LOW_FOV, first, delta)
		"arena_high":
			_camera.set_entrance_shot(ARENA_HIGH_AT, w.global_position + Vector3.UP * 1.0,
					ARENA_HIGH_FOV, true)
		"over_shoulder":
			var f5 := _flat(-w.global_transform.basis.z).normalized()
			var r5 := w.global_transform.basis.x
			_camera.set_entrance_shot(w.global_position - f5 * 1.8 + r5 * 0.45
					+ Vector3.UP * 1.8, w.global_position + f5 * 12.0 + Vector3.UP * 0.8,
					OVER_SHOULDER_FOV, first, delta)
		"ramp_low_wide":
			_camera.set_entrance_shot(RAMP_LOW_WIDE_AT, w.global_position + Vector3.UP * 2.2,
					RAMP_LOW_WIDE_FOV, true)
		"ramp_long":
			_camera.set_entrance_shot(Vector3(w.global_position.x * 0.5, 0.9,
					w.global_position.z + RAMP_LONG_BACK), w.global_position + Vector3.UP * 1.0,
					RAMP_LONG_FOV, true)
		"ring_behind_low":
			var f6 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position - f6 * 1.6 + Vector3.UP * 0.5,
					w.global_position + f6 * 3.0 + Vector3.UP * 1.4, RING_BEHIND_FOV,
					first, delta)
		"bow_close":
			# From his right and a little in front: straight ahead of him at the
			# steps is the ring post, which the lens would shoot through.
			var hb := _head_of(w)
			var fb := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(hb + w.global_transform.basis.x * BOW_SIDE
					+ fb * BOW_AHEAD, hb + Vector3.DOWN * 0.12, BOW_FOV, true)
		"crowd_wide":
			_camera.set_entrance_shot(CROWD_WIDE_AT, CROWD_WIDE_LOOK, CROWD_WIDE_FOV, true)
		"faceoff_side":
			# Square to the line between them, at eye height, both profiles
			# filling the frame: the stare-down shot every broadcast takes.
			var mid := (_a.global_position + _b.global_position) * 0.5
			var across := _flat(_b.global_position - _a.global_position).normalized()
			var side := Vector3.UP.cross(across).normalized()
			if side.dot(_camera.hard_cam_position - mid) < 0.0:
				side = -side
			_camera.set_entrance_shot(mid + side * FACEOFF_CAM_DISTANCE
					+ Vector3.UP * FACEOFF_CAM_HEIGHT, mid + Vector3.UP * 1.45,
					FACEOFF_CAM_FOV, first and not _was_shot("faceoff_side"), delta)
		"faceoff":
			# The hard camera's own seat and lens, so the bell does not cut.
			_camera.set_entrance_shot(_camera.hard_cam_position,
					(_a.global_position + _b.global_position) * 0.5
					+ Vector3.UP * _camera.hard_cam_aim, _camera.hard_cam_fov,
					not _was_shot("faceoff"), delta)


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


## Every portal accent to one colour and a multiple of its own energy: the
## room going red on Roman's pyro.
func _accents_to(color: Color, gain: float) -> void:
	if not _lights:
		return
	for child in _lights.get_children():
		if child is SpotLight3D and String(child.name).begins_with("Accent"):
			var light := child as SpotLight3D
			if not light.has_meta("base_energy"):
				light.set_meta("base_energy", light.light_energy)
			if not light.has_meta("base_color"):
				light.set_meta("base_color", light.light_color)
			light.light_color = color
			light.light_energy = float(light.get_meta("base_energy")) * gain


## Cody walks out of smoke (C-MITB 22-26 s, C-SNME 20-24 s): a dense fog
## volume filling his portal mouth, lit by his backlight behind it. Freed on
## the hit.
func _smoke_on(w: WrestlerController) -> void:
	if _smoke:
		return
	var at: Vector3 = (_beats[mini(_beat, _beats.size() - 1)] as Dictionary).get(
			"fog_at", w.global_position)
	_smoke = FogVolume.new()
	_smoke.name = "PortalSmoke"
	_smoke.size = SMOKE_SIZE
	var mat := FogMaterial.new()
	mat.density = SMOKE_DENSITY
	mat.albedo = Color(0.9, 0.92, 1.0)
	mat.edge_fade = 0.6
	_smoke.material = mat
	add_child(_smoke)
	_smoke.global_position = at + Vector3(0.0, SMOKE_SIZE.y * 0.5, 0.0)


func _smoke_off() -> void:
	if _smoke:
		_smoke.queue_free()
		_smoke = null


## Dims the house for his entrance, or puts it back. Every rig light except
## the portal accents (the entrance's own cue) goes to ROMAN_HOUSE_DIM of
## itself, and the ambient to ROMAN_AMBIENT_DIM; the originals are kept and
## restored exactly.
func _dim_house(on: bool, rig: float = ROMAN_HOUSE_DIM,
		ambient: float = ROMAN_AMBIENT_DIM) -> void:
	if on == not _dimmed.is_empty():
		return
	if on:
		if _lights:
			for child in _lights.get_children():
				if child is Light3D and not String(child.name).begins_with("Accent"):
					_dimmed[child] = (child as Light3D).light_energy
					(child as Light3D).light_energy *= rig
		if _env:
			_dimmed[_env] = _env.ambient_light_energy
			_env.ambient_light_energy *= ambient
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
	if w == null or not w.visible or _follow_off:
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
		var name := String(light.name)
		if on and side == "OFF":
			light.light_energy = 0.0
			continue
		if on and side.begins_with("RB"):
			# Cody's: red on the east portal, blue on the west, both hot.
			light.light_energy = base * (2.4 if side == "RB" else 0.7)
			light.light_color = CODY_RED if name.begins_with("AccentE") else CODY_BLUE
			continue
		var mine := on and name.begins_with("Accent" + side)
		light.light_energy = base * (2.4 if mine else 1.0)
		light.light_color = tint if mine and tint.a > 0.0 else light.get_meta("base_color")
