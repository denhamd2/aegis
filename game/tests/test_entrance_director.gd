extends GdUnitTestSuite
## The ring entrances (core/match/entrance_director.gd).
##
## The contract that matters most is the first test: OFF unless asked for.
## Every other suite, probe and capture builds match.tscn expecting two men in
## the ring on tick 1.

const MATCH := "res://scenes/match.tscn"


func _match(entrances: bool, style_a := "") -> Node:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = entrances
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = style_a
	add_child(scene)
	return auto_free(scene)


func test_entrances_are_off_unless_asked_for() -> void:
	var scene := _match(false)
	assert_object(scene.get_node_or_null("EntranceDirector")).is_null()
	var a: WrestlerController = scene.get_node("WrestlerA")
	assert_bool(a.is_physics_processing()).is_true()


## Everything that plays the match waits for the bell, and so does the replay.
func test_the_match_is_frozen_until_the_bell() -> void:
	var scene := _match(true)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	assert_object(director).is_not_null()
	for path in ["WrestlerA", "WrestlerB", "MatchReferee", "GrappleRig"]:
		assert_bool(scene.get_node(path).is_physics_processing()) \
				.override_failure_message("%s runs during the entrance" % path) \
				.is_false()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.mode).is_equal(MatchCamera.Mode.ENTRANCE)


func test_skipping_rings_the_bell_with_both_men_on_their_marks() -> void:
	var scene := _match(true)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var mark_a := a.global_transform
	var mark_b := b.global_transform
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	for _i in 30:
		director._physics_process(1.0 / 60.0)
	director.skip()
	assert_bool(rang[0]).is_true()
	assert_vector(a.global_position).is_equal_approx(mark_a.origin, Vector3.ONE * 0.001)
	assert_vector(b.global_position).is_equal_approx(mark_b.origin, Vector3.ONE * 0.001)
	assert_bool(a.visible and b.visible).is_true()
	assert_bool(a.is_physics_processing()).is_true()
	assert_bool(scene.get_node("MatchReferee").is_physics_processing()).is_true()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)


## The whole entrance, stepped: nobody jumps except at the broadcast cut (and
## on appearing), and it ends with the bell and both men on their marks.
func test_the_walk_is_continuous_and_ends_on_the_marks() -> void:
	_assert_continuous(_match(true))


## Roman's own routine holds to the same contract, and his props and pyro are
## gone by the bell.
func test_romans_entrance_is_continuous_and_cleans_up() -> void:
	var scene := _match(true, "roman")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var fired := [false, false]
	director.bell.connect(func():
		fired[0] = director._pyro == null and director._props.is_empty())
	var a: WrestlerController = scene.get_node("WrestlerA")
	var saw := {}
	director.bell.connect(func(): fired[1] = true)
	_assert_continuous(scene, func():
		var props: EntranceProps = director._props.get(a)
		if props:
			saw[props._title_state] = true
		if director._pyro:
			saw["pyro"] = true)
	assert_bool(fired[1]).is_true()
	assert_bool(fired[0]).override_failure_message("props or pyro outlived the bell").is_true()
	for k in ["worn", "held", "", "pyro"]:
		assert_bool(saw.has(k)).override_failure_message("never saw %s" % k).is_true()


func _assert_continuous(scene: Node, each_tick := Callable()) -> void:
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var mark_a := a.global_position
	var mark_b := b.global_position
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	var last := {a: a.global_position, b: b.global_position}
	var worst := 0.0
	var ticks := 0
	while not rang[0] and ticks < 20000:
		var beat_before := director._beat
		director._physics_process(1.0 / 60.0)
		ticks += 1
		if each_tick.is_valid():
			each_tick.call()
		for w: WrestlerController in [a, b]:
			var moved: float = (w.global_position - (last[w] as Vector3)).length()
			last[w] = w.global_position
			# A beat that starts with a cut or an appearance may place him
			# anywhere; everything else is walking pace or a clip's root line.
			var started: Dictionary = director._beats[mini(beat_before,
					director._beats.size() - 1)]
			var jump_ok: bool = director._beat != beat_before \
					and director._beat < director._beats.size() \
					and ((director._beats[director._beat] as Dictionary).get("cut", false)
						or (director._beats[director._beat] as Dictionary).get("appear", false))
			if not jump_ok and w.visible:
				worst = maxf(worst, moved)
	assert_bool(rang[0]).override_failure_message("no bell after %d ticks" % ticks).is_true()
	assert_float(worst).override_failure_message(
			"a wrestler jumped %.3f m in one tick" % worst).is_less(0.1)
	assert_vector(a.global_position).is_equal_approx(mark_a, Vector3.ONE * 0.001)
	assert_vector(b.global_position).is_equal_approx(mark_b, Vector3.ONE * 0.001)


func test_the_surface_follows_the_deck_the_ramp_and_the_floor() -> void:
	assert_float(EntranceDirector.surface_y(Vector3(0.0, 0.0, -34.0))) \
			.is_equal_approx(ArenaBuilder.STAGE_DECK_Y, 0.001)
	var mid := EntranceDirector.surface_y(Vector3(0.0, 0.0, -18.0))
	assert_float(mid).is_less(ArenaBuilder.STAGE_DECK_Y)
	assert_float(mid).is_greater(ArenaBuilder.FLOOR_Y)
	assert_float(EntranceDirector.surface_y(Vector3(-4.8, 0.0, -3.0))) \
			.is_equal_approx(ArenaBuilder.FLOOR_Y, 0.01)


## The roster rule for the lower third: a champion's title, otherwise his
## nickname.
func test_the_subtitle_is_the_title_or_the_nickname() -> void:
	var roman := Roster.by_id("roman")
	var cody := Roster.by_id("cody")
	assert_str(roman.entrance_subtitle()).is_equal("AEW CHAMPION")
	assert_str(cody.entrance_subtitle()).is_equal(cody.tagline)


## The house goes down for Roman and comes back exactly; he is not on the
## stage until his music hits.
func test_roman_waits_for_his_music_under_dimmed_lights() -> void:
	var scene := _match(true, "roman")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var rig := scene.get_node("LightRig")
	var light: Light3D = null
	for child in rig.get_children():
		if child is Light3D and not String(child.name).begins_with("Accent"):
			light = child
			break
	var before := light.light_energy
	# Step into his hold: past the opening and Cody's whole entrance.
	var ticks := 0
	while ticks < 20000 and not ((director._beats[director._beat] as Dictionary).get("kind") == "hold"):
		director._physics_process(1.0 / 60.0)
		ticks += 1
	for _i in 120:
		director._physics_process(1.0 / 60.0)
	assert_bool(a.visible).override_failure_message("out before his music hit").is_false()
	assert_float(light.light_energy).is_equal_approx(before * EntranceDirector.ROMAN_HOUSE_DIM, 0.001)
	director.skip()
	assert_float(light.light_energy).is_equal_approx(before, 0.0001)
