extends GdUnitTestSuite
## The walk to the ring: where it starts, what it walks on, and what it leaves
## behind for the match.
##
## Nothing here renders. How the entrance LOOKS is not assertable and is closed
## on pixels by tools/probe/entrance_shots.tscn, which is the split
## test_title_screen.gd already draws. What IS assertable is the geometry -- that
## the path is on the ramp rather than through it, inside the ramp's own
## corridor, and that the match gets back exactly the ring it was built with.
##
## The surface assertions go through `EntranceDirector.surface_y()`, which is
## public for this. It is the same arithmetic the walk uses, so this is a test of
## the PATH against the ARENA's constants, not of the function against itself:
## move the stage and both move together, and a leg that stopped agreeing with
## the ramp would show up as a deviation here.
##
## No character .glb is loaded. roman_reigns.glb alone is 52MB and this suite has
## no use for a mesh.

const MATCH_SCENE := preload("res://scenes/match.tscn")


func _director() -> EntranceDirector:
	return auto_free(EntranceDirector.new())


## --- Where the walk happens -------------------------------------------------

## The ramp is a wedge from the stage lip to the barricade line
## (tools/blender/entrance_set.py), and the two ends of surface_y() have to be
## those two points or the walk is not on the ramp at either end.
func test_the_surface_is_the_deck_at_the_stage_and_the_floor_at_the_barrier() -> void:
	assert_float(EntranceDirector.surface_y(ArenaBuilder.STAGE_FRONT)) \
			.is_equal_approx(ArenaBuilder.STAGE_DECK_Y, 0.001)
	assert_float(EntranceDirector.surface_y(EntranceDirector.RAMP_FOOT_Z)) \
			.is_equal_approx(EntranceDirector.MAT_SURFACE_Y, 0.001)


## Behind the stage lip he is on the deck, which is flat.
func test_the_deck_is_flat_behind_the_stage_lip() -> void:
	for z: float in [ArenaBuilder.STAGE_BACK, -34.0, ArenaBuilder.STAGE_FRONT]:
		assert_float(EntranceDirector.surface_y(z)) \
				.is_equal_approx(ArenaBuilder.STAGE_DECK_Y, 0.001)


## And in front of the barrier he is on the matting, which is also flat.
func test_the_matting_is_flat_in_front_of_the_barrier() -> void:
	for z: float in [EntranceDirector.RAMP_FOOT_Z, -4.0, -2.0]:
		assert_float(EntranceDirector.surface_y(z)) \
				.is_equal_approx(EntranceDirector.MAT_SURFACE_Y, 0.001)


## The ramp descends the whole way, monotonically, and never rises. A
## non-monotonic ramp is a step, and a wrestler walking down one pops.
func test_the_ramp_falls_the_whole_way_and_never_climbs() -> void:
	var previous := EntranceDirector.surface_y(ArenaBuilder.STAGE_FRONT)
	var z := ArenaBuilder.STAGE_FRONT
	while z < EntranceDirector.RAMP_FOOT_Z:
		z += 0.25
		var here := EntranceDirector.surface_y(z)
		assert_float(here).is_less_equal(previous + 0.0001)
		previous = here
	# And it is a RAMP, not a cliff: the whole fall is the deck height above
	# the floor, over the length the stage's own constants give it.
	var fall: float = ArenaBuilder.STAGE_DECK_Y - EntranceDirector.MAT_SURFACE_Y
	var run: float = EntranceDirector.RAMP_FOOT_Z - ArenaBuilder.STAGE_FRONT
	assert_float(fall / run).is_less(0.10)


## --- What the geometry has to agree with ------------------------------------

## The steps he climbs are the -X/-Z flight, and he has to stand ON them rather
## than inside them. Derived from RingBuilder, so a moved flight moves the walk.
func test_the_step_approach_is_clear_of_the_flight_and_the_top_is_on_it() -> void:
	# The bottom tread reaches this far out from ring centre.
	var flight_outer: float = RingBuilder.APRON_OUT + RingBuilder.STEP_APRON_GAP \
			+ RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS
	assert_float(absf(EntranceDirector.STEPS_APPROACH_X)) \
			.is_greater(flight_outer)
	# The top tread is only one run deep, and he stands within it.
	assert_float(absf(EntranceDirector.STEPS_TOP_X)) \
			.is_greater(RingBuilder.APRON_OUT + RingBuilder.STEP_APRON_GAP)
	assert_float(absf(EntranceDirector.STEPS_TOP_X)).is_less(
			RingBuilder.APRON_OUT + RingBuilder.STEP_APRON_GAP
			+ RingBuilder.STEP_RUN)


## The flight's Z span is APRON_OUT back to APRON_OUT - STEP_WIDTH, negated. He
## climbs up its middle.
func test_the_climb_is_up_the_middle_of_the_flight() -> void:
	var near: float = -(RingBuilder.APRON_OUT - RingBuilder.STEP_WIDTH)
	var far: float = -RingBuilder.APRON_OUT
	assert_float(EntranceDirector.STEPS_Z).is_between(far, near)


## The top tread is level with the apron so a wrestler "steps straight over the
## top rope beside the turnbuckle" (ring_builder.gd). The climb must therefore
## end BELOW the canvas, and the ring entry ON it.
func test_the_top_tread_is_below_the_canvas_and_the_entry_is_on_it() -> void:
	assert_float(EntranceDirector.STEPS_TOP_Y) \
			.is_less(EntranceDirector.MAT_Y)
	assert_float(EntranceDirector.MAT_Y).is_equal_approx(0.0, 0.001)
	# And he lands inside the ropes, not on the apron outside them.
	assert_float(absf(EntranceDirector.RING_ENTRY_X)) \
			.is_less(RingBuilder.ROPE_SPAN)
	assert_float(absf(EntranceDirector.RING_ENTRY_Z)) \
			.is_less(RingBuilder.ROPE_SPAN)


## He comes out of a portal, from inside its recess, not off the front of the
## deck.
func test_he_starts_inside_the_portal_recess_and_walks_out_of_it() -> void:
	assert_float(EntranceDirector.PORTAL_START_Z) \
			.is_less(ArenaBuilder.PORTAL_FACE_Z)
	assert_float(EntranceDirector.PORTAL_OUT_Z) \
			.is_greater(ArenaBuilder.PORTAL_FACE_Z)
	# Both still behind the stage lip, i.e. on the deck.
	assert_float(EntranceDirector.PORTAL_OUT_Z) \
			.is_less(ArenaBuilder.STAGE_FRONT)


## The ramp leg starts exactly on the wedge's top edge. Start it short of that
## and the straight lerp down the ramp begins while he is still on the flat
## deck, so he descends through it.
func test_the_ramp_leg_starts_on_the_ramps_own_lip() -> void:
	assert_float(EntranceDirector.RAMP_HEAD_Z) \
			.is_equal_approx(ArenaBuilder.STAGE_FRONT, 0.0001)


## --- The clip and the speed have to agree -----------------------------------

## WALK_SPEED is not free: Walk_Entrance's planted-foot curve is generated
## against it (tools/blender/wrestling_clips.py) and walk_entrance's recipe
## retimes to the duration that preserves the rate. If this number moves without
## the clip being regenerated, the ramp slides under him for 24 metres.
func test_the_walk_speed_is_the_speed_the_clip_was_authored_for() -> void:
	assert_float(EntranceDirector.WALK_SPEED).is_equal_approx(1.45, 0.0001)


func test_the_entrance_state_has_a_clip_the_rig_actually_has() -> void:
	var clip: String = WrestlerController.clip_for_state(
			WrestlerFSM.State.ENTRANCE, false)
	assert_str(clip).is_equal("strikes/walk_entrance")
	var library: AnimationLibrary = load(
			"res://resources/animations/strike_clips.tres")
	assert_bool(library.has_animation("walk_entrance")).is_true()


## A gait that does not loop plays once and freezes, and the walk is 24 metres
## long. strike_recipes.gd's own comment makes this a requirement for the three
## clips a wrestler sits in; this is the fourth.
func test_the_entrance_walk_loops() -> void:
	var library: AnimationLibrary = load(
			"res://resources/animations/strike_clips.tres")
	var walk: Animation = library.get_animation("walk_entrance")
	assert_int(walk.loop_mode).is_not_equal(Animation.LOOP_NONE)


## --- What the match gets back -----------------------------------------------

## The director is handed nodes rather than looking them up, so it can be run
## against a fixture with no arena, no camera and no HUD in it. That is what
## makes this assertion cheap, and it is also what the accent setters being
## optional is for.
func test_it_refuses_a_pair_that_is_not_a_pair() -> void:
	var director := _director()
	add_child(director)
	director.wrestlers = []
	var emitted := [false]
	director.entrances_finished.connect(func() -> void: emitted[0] = true)
	await director.run()
	# It gives up rather than walking nobody, and still releases the match --
	# a director that returns without emitting would hang MatchSetup._ready()
	# forever, and with it the whole game.
	assert_bool(emitted[0]).is_true()
	assert_bool(director.is_running()).is_false()
