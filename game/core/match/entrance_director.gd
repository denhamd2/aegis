class_name EntranceDirector
extends Node
## Walks the two picked wrestlers from the portals to the ring, then hands the
## match the ring it expects.
##
## Inert unless `MatchSetup.play_entrances` is true, which only
## `TitleScreen.configure_entrances()` sets -- and pointedly not
## `configure_match()`, which nine probes call. Every probe, every test,
## `scenes/play.tscn` and `tools/capture/run_capture.sh` point at an
## un-configured `scenes/match.tscn` and so never see an entrance -- which is
## the whole reason the flag exists and defaults to false. See "Why this cannot
## move a measurement" below.
##
## ## What it is made of
##
## The set was already here. `arena_builder.gd` builds an 8m deck at
## STAGE_BACK -38 to STAGE_FRONT -30, two lit portals at |x| PORTAL_OFFSET_X,
## a ramp falling from the deck lip to the barricade line at
## -BARRICADE_RADIUS, black matting from the barrier in to the apron, and a
## curved LED wall. `ring_builder.gd` puts two flights of steel steps on
## diagonally opposite corners, each with its top tread level with the apron
## "so a wrestler climbing them steps straight over the top rope beside the
## turnbuckle". Nothing had ever walked on any of it.
##
## So every number in PATH below is DERIVED from those constants rather than
## typed: the ramp's grade comes from STAGE_DECK_Y and FLOOR_Y, the steps'
## approach from APRON_OUT, STEP_APRON_GAP, STEP_WIDTH and STEP_RUN. Move the
## stage and the walk moves with it.
##
## ## Why this cannot move a measurement
##
## `ARCHITECTURE.md` makes determinism a hard requirement and the README
## states the AI-vs-AI probes return byte-identical output. Four things keep
## that true:
##
## - **It draws no random numbers.** Nothing here touches `match_seed`, a
##   RandomNumberGenerator, or `randi()`. The tier draws and AI jitter that
##   consume the seeded streams have not started yet.
## - **It runs before the referee's first tick.** Both wrestlers and
##   `MatchReferee` are frozen with `set_physics_process(false)` -- the
##   mechanism `MatchSetup._on_match_won()` already uses, and whose comment
##   records that the AnimationTree keeps playing regardless, which is what
##   makes a frozen wrestler still able to walk. `ReplaySystem` is started by
##   `MatchSetup` after this finishes, so tick 0 of the recording is tick 0 of
##   the match.
## - **It restores the transforms it was given.** `_marks` is captured from
##   the wrestlers before anybody moves, and the handoff assigns it back --
##   not a recomputed position that ought to equal it. The match therefore
##   starts from the transform `match.tscn` ships, to the bit.
## - **It leaves the set as it found it.** The portal, lamp and video-wall
##   accents are all restored.
##
## `tests/test_entrance_is_off_by_default.gd` is the standing guard on the
## first of those.

signal entrances_finished

## Metres per second, every leg of the walk, including the climb.
##
## NOT a game constant and deliberately not MOVE_SPEED: the wrestler is moved
## by this file, not by `WrestlerController._process_free_movement()`, and
## nothing in the match is happening yet. It is the speed
## `Walk_Entrance` was AUTHORED for -- `tools/blender/wrestling_clips.py`
## generates that cycle's planted-foot curve against this number so the boot
## holds the ramp instead of skating on it, and
## `resources/animations/strike_recipes.gd` retimes it to the 0.933s that
## preserves the rate. Change this and the clip has to be regenerated, or the
## ramp slides under him for 24 metres, which is a long time to watch.
const WALK_SPEED := 1.45

## Every leg moves at WALK_SPEED, so the only thing a hold can do is stand.
## Holds travel the FSM to IDLE rather than staying in ENTRANCE: the entrance
## clip is a gait, and a stationary wrestler playing a gait is a man walking on
## the spot. IDLE's `idle_ready` is a standing clip, so a hold reads as a man
## stopped rather than as a man treadmilling.
const HOLD_PORTAL := 1.6
const HOLD_STAGE_LIP := 0.9
const HOLD_RING := 1.1
## Beat held on the empty ring between the two entrances, so they do not run
## together into one long walk.
const HOLD_BETWEEN := 0.7

## --- the walk, leg by leg ---------------------------------------------------
##
## Ramp geometry, straight out of the two files that build it.
## `tools/blender/entrance_set.py` lays the ramp as one wedge from
## (0, STAGE_DECK_Y, STAGE_FRONT) down to (0, FLOOR_Y + 0.04, -BARRICADE_RADIUS),
## with a half-metre nose carrying the last 4cm onto the matting.
const RAMP_FOOT_Z := -ArenaBuilder.BARRICADE_RADIUS
const RAMP_FOOT_Y := ArenaBuilder.FLOOR_Y + 0.04
## The matting's own surface, which is what he walks the last few metres on.
const MAT_SURFACE_Y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT

## The steel steps, from `ring_builder.gd` and `tools/blender/ring.py`. The
## flight he uses is the -X/-Z one -- the entrance comes from -Z, and the other
## set is diagonally opposite on +X/+Z.
##
## The flight's Z span is APRON_OUT back to APRON_OUT - STEP_WIDTH, negated;
## its inner face is APRON_OUT + STEP_APRON_GAP out from ring centre and it
## reaches STEP_RUN * STEP_TREADS further out than that at the bottom tread.
const STEPS_Z := -(RingBuilder.APRON_OUT
		+ (RingBuilder.APRON_OUT - RingBuilder.STEP_WIDTH)) * 0.5
const STEPS_INNER_X := RingBuilder.APRON_OUT + RingBuilder.STEP_APRON_GAP
const STEPS_OUTER_X := STEPS_INNER_X + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS
## Where he stands to start climbing: clear of the bottom tread, on the floor.
const STEPS_APPROACH_X := -(STEPS_OUTER_X + 0.40)
## Where he stands on the TOP tread, which is `tread_x(STEP_TREADS - 1)`. Kept
## as its own name because the ring-entry leg starts from it.
const STEPS_TOP_X := -(STEPS_INNER_X + RingBuilder.STEP_RUN * 0.5)
## The Ring node sits at y = -0.1, so every RingBuilder height is that much
## lower in world space. STEP_TOP_Y -0.14 is a top tread at world -0.24, and
## MAT_TOP_LOCAL 0.1 is a canvas at world 0.0 -- which is why the wrestlers'
## shipped transforms in match.tscn carry y = 0 and why a wrestler's origin is
## at his feet (his CapsuleShape3D is offset to y = 0.9, not his root).
const RING_Y_OFFSET := -0.1
const STEPS_TOP_Y := RingBuilder.STEP_TOP_Y + RING_Y_OFFSET
const MAT_Y := RingBuilder.MAT_TOP_LOCAL + RING_Y_OFFSET

## Inside the ropes, at the corner he climbed in on. Where he lands after
## stepping over, before walking to his mark.
const RING_ENTRY_X := -2.15
const RING_ENTRY_Z := -2.05

## The portal he comes out of, and how far back inside its recess he starts.
## PORTAL_FACE_Z is the face; the recess runs PORTAL_RECESS_DEPTH behind it, so
## he is genuinely in the tunnel and walks out of it rather than fading up on
## the deck.
const PORTAL_START_Z := ArenaBuilder.PORTAL_FACE_Z - 0.7
const PORTAL_OUT_Z := ArenaBuilder.PORTAL_FACE_Z + 1.5
## Where the deck walk turns onto the ramp centreline: the wedge's own top
## edge, exactly. Not a little short of it -- the ramp leg below is a straight
## lerp from here to the foot, and that lerp is the ramp's surface only if it
## starts where the ramp does. Half a metre back on the deck and he descends
## before he is on the slope.
const RAMP_HEAD_Z := ArenaBuilder.STAGE_FRONT

var wrestlers: Array[WrestlerController] = []
## Roster entries, parallel to `wrestlers`. Supplied by MatchSetup, which got
## them from TitleScreen -- so the plate and the accent name whoever was
## actually picked and this file names nobody.
var entries: Array = []
var camera: EntranceCamera = null
var nameplate: EntranceNameplate = null
var match_camera: Camera3D = null
var hud: CanvasLayer = null
var referee: Node = null
var arena: ArenaBuilder = null
var lighting: ArenaLighting = null

## Shipped transforms, captured before anybody moves and assigned back at the
## handoff. See the determinism note in the header.
var _marks: Array[Transform3D] = []
var _running := false
## Index into `wrestlers` of the man currently walking, or -1 between entrances.
##
## Public because "who is on the ramp" cannot be recovered from the FSM: he is
## in IDLE for every hold, which is most of the beats worth looking at, so a
## watcher keying off State.ENTRANCE misses the portal pose and the corner pose
## entirely. tools/probe/entrance_shots.gd reads this.
var walking_index := -1


func is_running() -> bool:
	return _running


## The whole sequence. Awaited by MatchSetup, which unfreezes nothing itself --
## everything this touches, it puts back.
func run() -> void:
	if wrestlers.size() != 2:
		push_error("EntranceDirector needs exactly two wrestlers, got %d"
				% wrestlers.size())
		entrances_finished.emit()
		return
	_running = true
	_marks.clear()
	for w: WrestlerController in wrestlers:
		_marks.append(w.global_transform)
		_freeze(w, false)
		# Out of sight until his own entrance. Both men are standing on their
		# marks from the moment match.tscn is built, so without this the second
		# one is in the ring through the whole of the first one's walk and then
		# teleports out to a portal in front of the camera.
		w.visible = false
	if referee:
		referee.set_physics_process(false)
	if hud:
		hud.visible = false
	if camera:
		camera.current = true
		if match_camera:
			match_camera.current = false

	for i: int in wrestlers.size():
		await _walk_one(i)
		if i == 0:
			await _hold(HOLD_BETWEEN, wrestlers[i])

	# Back on the marks, to the bit, and back in IDLE -- which is the state
	# match.tscn's wrestlers are already in, so nothing has to transition.
	for i: int in wrestlers.size():
		wrestlers[i].visible = true
		wrestlers[i].global_transform = _marks[i]
		if wrestlers[i].fsm.current_state != WrestlerFSM.State.IDLE:
			wrestlers[i].fsm.transition_to(WrestlerFSM.State.IDLE)

	if arena:
		arena.restore_entrance_accent()
	if lighting:
		lighting.restore_stage_accent()
	_set_wall_tint(Color.WHITE, true)
	if nameplate:
		nameplate.reveal = 0.0
		nameplate.entry = null
		nameplate.queue_redraw()
	if camera:
		camera.current = false
	if match_camera:
		match_camera.current = true
	if hud:
		hud.visible = true
	for w: WrestlerController in wrestlers:
		_freeze(w, true)
	if referee:
		referee.set_physics_process(true)
	_running = false
	entrances_finished.emit()


## One man's walk, portal to mark.
func _walk_one(index: int) -> void:
	var w: WrestlerController = wrestlers[index]
	var entry: Roster.Entry = entries[index] if index < entries.size() else null
	# Player 1 out of the west portal, his opponent out of the east, so the two
	# entrances do not start from the same hole in the same wall.
	walking_index = index
	var px: float = ArenaBuilder.PORTAL_OFFSET_X * (-1.0 if index == 0 else 1.0)
	var accent: Color = entry.attire_accent if entry else Color(0.8, 0.8, 0.85)

	if arena:
		arena.set_entrance_accent(accent)
	if lighting:
		lighting.set_stage_accent(accent)
	_set_wall_tint(accent, false)
	if nameplate:
		nameplate.entry = entry
		nameplate.reveal = 0.0

	# On the spot inside the recess, facing the ring, before the first frame
	# anybody sees him.
	_place(w, Vector3(px, ArenaBuilder.STAGE_DECK_Y, PORTAL_START_Z))
	_face(w, Vector3(px, 0.0, PORTAL_START_Z + 1.0))
	# Shown only now he is in the tunnel rather than on his mark, and he stays
	# shown for the rest of the run -- the first man is in the ring while the
	# second walks, which is what a ring looks like between entrances.
	w.visible = true
	if camera:
		camera.subject = w
		camera.cut_to(EntranceCamera.Shot.STAGE)

	# Out of the tunnel onto the deck, and stop -- which is what the plate is
	# under. Then across the deck to the ramp head.
	await _leg(w, Vector3(px, ArenaBuilder.STAGE_DECK_Y, PORTAL_OUT_Z))
	await _hold(HOLD_PORTAL, w, true)
	await _leg(w, Vector3(0.0, ArenaBuilder.STAGE_DECK_Y, RAMP_HEAD_Z))
	await _hold(HOLD_STAGE_LIP, w)

	# The ramp. One leg, 24 metres of it, on the long lens.
	if camera:
		camera.cut_to(EntranceCamera.Shot.RAMP)
	await _leg(w, Vector3(0.0, RAMP_FOOT_Y, RAMP_FOOT_Z))
	await _leg(w, Vector3(0.0, MAT_SURFACE_Y, RAMP_FOOT_Z + 1.0))

	# Round to the steps and up them, close and low.
	if camera:
		camera.cut_to(EntranceCamera.Shot.APRON)
	if nameplate:
		await _fade_plate(0.0)
	await _leg(w, Vector3(STEPS_APPROACH_X, MAT_SURFACE_Y, STEPS_Z))
	# UP THE TREADS, one leg each, rather than one leg to the top.
	#
	# A single leg from the floor to the top tread is a straight line, and the
	# flight is a staircase -- so that line passes THROUGH the treads and he
	# glides up the outside of the steps like a man on an escalator. It is the
	# only beat of the walk with a physical action in it, and it is the one the
	# apron camera is close enough to see, so it is the one that cannot cheat.
	for tread: int in RingBuilder.STEP_TREADS:
		await _leg(w, Vector3(tread_x(tread), tread_y(tread), STEPS_Z))
	# Over the top rope and onto the canvas.
	await _leg(w, Vector3(RING_ENTRY_X, MAT_Y, RING_ENTRY_Z))
	await _hold(HOLD_RING, w)
	# To his mark. Faces his opponent on arrival, which is where
	# _turn_toward_opponent() would have put him anyway.
	var mark: Vector3 = _marks[index].origin
	await _leg(w, mark)
	_face(w, _marks[1 - index].origin)
	walking_index = -1


## Stops or restarts a wrestler's whole tick: the controller, its FSM and its AI.
##
## The controller alone is not enough, and finding that out is what the probe
## diff is for. `WrestlerFSM._physics_process()` does nothing but increment
## `ticks_in_state`, so a wrestler frozen only at the controller walks out with a
## state clock reading several thousand ticks -- and the controller's timeouts,
## the referee's tie-up limit and the AI all read that clock. `ticks_in_state` is
## reset on the way back in so the match's first tick sees a wrestler who has
## been in IDLE for no time at all, which is what it sees without an entrance.
##
## The AI is stopped for the same reason and one more: it is the only thing here
## that draws on a seeded stream, and a single poll during the walk would move
## every decision in the match that follows it.
func _freeze(w: WrestlerController, running: bool) -> void:
	w.set_physics_process(running)
	if w.fsm:
		w.fsm.set_physics_process(running)
		if running:
			w.fsm.ticks_in_state = 0
	if w.ai:
		w.ai.set_physics_process(running)


## Moves `w` to `to` at exactly WALK_SPEED, in the ENTRANCE state, facing the
## way he is going. Awaits one physics frame per tick, so the leg takes the
## same number of 60Hz ticks whatever `--fixed-fps` the run renders at.
func _leg(w: WrestlerController, to: Vector3) -> void:
	var from := w.global_position
	var flat_distance := Vector2(to.x - from.x, to.z - from.z).length()
	if flat_distance < 0.001:
		return
	if w.fsm.current_state != WrestlerFSM.State.ENTRANCE:
		w.fsm.transition_to(WrestlerFSM.State.ENTRANCE)
	_face(w, to)
	var ticks := int(round(flat_distance / WALK_SPEED
			* Engine.physics_ticks_per_second))
	for tick: int in range(1, ticks + 1):
		var t := float(tick) / float(ticks)
		_place(w, from.lerp(to, t))
		_advance_plate()
		await get_tree().physics_frame


## Stands still for `seconds`, in IDLE. `reveal_plate` brings the nameplate on
## during the hold, which is the beat it is designed for.
func _hold(seconds: float, w: WrestlerController,
		reveal_plate: bool = false) -> void:
	if w.fsm.current_state != WrestlerFSM.State.IDLE:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	var ticks := int(round(seconds * Engine.physics_ticks_per_second))
	for _tick: int in ticks:
		if reveal_plate:
			_advance_plate(1.0)
		else:
			_advance_plate()
		await get_tree().physics_frame


## Runs the plate to `target` and waits for it to get there, so a cut does not
## land with the graphic still half on screen.
func _fade_plate(target: float) -> void:
	if nameplate == null:
		return
	var step := 1.0 / (EntranceNameplate.SLIDE_TIME
			* Engine.physics_ticks_per_second)
	while absf(nameplate.reveal - target) > step:
		nameplate.reveal = move_toward(nameplate.reveal, target, step)
		nameplate.queue_redraw()
		await get_tree().physics_frame
	nameplate.reveal = target
	nameplate.queue_redraw()


## One tick of the plate's slide, toward `target` (held where it is by default,
## so a walking leg does not undo the reveal a hold performed).
func _advance_plate(target: float = -1.0) -> void:
	if nameplate == null or target < 0.0:
		return
	var step := 1.0 / (EntranceNameplate.SLIDE_TIME
			* Engine.physics_ticks_per_second)
	nameplate.reveal = move_toward(nameplate.reveal, target, step)
	nameplate.queue_redraw()


## Puts him at `at`, with Y taken from the surface he is over unless the leg
## named one -- which the climb does, because the steps and the canvas are not
## functions of Z.
func _place(w: WrestlerController, at: Vector3) -> void:
	w.global_position = at
	w.velocity = Vector3.ZERO


## Squares him up on `target`, ignoring height. `look_at` points -Z at it,
## which is the forward axis `tests/test_wrestler_facing.gd` measures.
func _face(w: WrestlerController, target: Vector3) -> void:
	var flat := Vector3(target.x, w.global_position.y, target.z)
	if flat.distance_to(w.global_position) < 0.01:
		return
	w.look_at(flat, Vector3.UP)


## Where a foot lands on tread `i`, counting up from the floor.
##
## The flight is a TAPER, not a stack of equal boxes: tread `i` is
## `STEP_RUN * (STEP_TREADS - i)` deep, so each one up is one run shallower and
## the exposed band of tread `i` -- the part not buried under the tread above --
## is the single run between the two outer edges. He stands in the middle of
## that band. Getting this from the flight's own arithmetic rather than from
## three typed numbers is what keeps the climb on the steps if the steps change.
static func tread_x(i: int) -> float:
	return -(STEPS_INNER_X + RingBuilder.STEP_RUN
			* (RingBuilder.STEP_TREADS - i - 0.5))


## The top of tread `i` in WORLD space. RingBuilder's heights are ring-local and
## the Ring node sits at RING_Y_OFFSET.
static func tread_y(i: int) -> float:
	var rise: float = (RingBuilder.STEP_TOP_Y - RingBuilder.STEP_FLOOR_Y) \
			/ float(RingBuilder.STEP_TREADS)
	return RingBuilder.STEP_FLOOR_Y + rise * (i + 1) + RING_Y_OFFSET


## The walking surface at `z` on the ramp centreline: deck, then the ramp's
## grade, then the matting. Public so the suite can assert the walk is actually
## on the ramp rather than through it.
static func surface_y(z: float) -> float:
	if z <= ArenaBuilder.STAGE_FRONT:
		return ArenaBuilder.STAGE_DECK_Y
	if z >= RAMP_FOOT_Z:
		return MAT_SURFACE_Y
	var t := (z - ArenaBuilder.STAGE_FRONT) \
			/ (RAMP_FOOT_Z - ArenaBuilder.STAGE_FRONT)
	return lerpf(ArenaBuilder.STAGE_DECK_Y, RAMP_FOOT_Y, t)


func _set_wall_tint(color: Color, clear: bool) -> void:
	if arena == null:
		return
	var wall := arena.find_child("StageVideo", true, false) as StageVideo
	if wall == null:
		return
	if clear:
		wall.clear_tint()
	else:
		wall.set_tint(color)
