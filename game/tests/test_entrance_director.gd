extends GdUnitTestSuite
## The ring entrances (core/match/entrance_director.gd).
##
## The contract that matters most is the first test: OFF unless asked for.
## Every other suite, probe and capture builds match.tscn expecting two men in
## the ring on tick 1.

const MATCH := "res://scenes/match.tscn"


func _match(entrances: bool, style_a := "", style_b := "") -> Node:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = entrances
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = style_a
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = style_b
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


## Both men meet the bell squared up to each other. The scene's spawns face
## outward, and the entrance used to end on them: the owner saw both men
## finish with their backs to each other.
func test_the_bell_finds_them_facing_each_other() -> void:
	var scene := _match(true, "roman", "cody")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	director.skip()
	for pair: Array in [[a, b], [b, a]]:
		var me: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		var facing := -me.global_transform.basis.z
		var to_other := other.global_position - me.global_position
		facing.y = 0.0
		to_other.y = 0.0
		assert_float(facing.normalized().dot(to_other.normalized())) \
				.override_failure_message("%s ends his entrance facing away" % me.name) \
				.is_greater(0.99)


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
	# The owner's call: he walks out with the AEW title round his waist,
	# raises it in the ring and hands it off -- worn, held, then carried away
	# (PropHandoff), never just gone.
	for k in ["worn", "held", "carried", "pyro"]:
		assert_bool(saw.has(k)).override_failure_message("never saw %s" % k).is_true()


## The things that run on frames in a game and so need stepping by hand here:
## Aubrey, the timekeeper, and the props' way to his table.
func _step_actors(scene: Node) -> void:
	var ref := scene.get_node_or_null("RefereeActor") as RefereeActor
	var keeper := scene.get_node_or_null("Timekeeper") as Timekeeper
	var handoff := scene.get_node_or_null("PropHandoff") as PropHandoff
	if ref:
		ref._process(1.0 / 60.0)
		if ref._player:
			ref._player.advance(1.0 / 60.0)
	if keeper:
		keeper._process(1.0 / 60.0)
		if keeper._player:
			keeper._player.advance(1.0 / 60.0)
	if handoff:
		handoff._process(1.0 / 60.0)


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
		_step_actors(scene)
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
	# Step into his hold: past the opening, the first entrance and the
	# handover after it.
	var ticks := 0
	while ticks < 20000 and not ((director._beats[director._beat] as Dictionary).get("kind") == "hold"
			and (director._beats[director._beat] as Dictionary).get("who") == a):
		director._physics_process(1.0 / 60.0)
		ticks += 1
	for _i in 120:
		director._physics_process(1.0 / 60.0)
	assert_bool(a.visible).override_failure_message("out before his music hit").is_false()
	assert_float(light.light_energy).is_equal_approx(before * EntranceDirector.ROMAN_HOUSE_DIM, 0.001)
	director.skip()
	assert_float(light.light_energy).is_equal_approx(_after_bell(rig, light, before), 0.0001)


## What a rig light reads once the bell has rung: the house dim undone, and
## the ring keys and top fill on the match look (ArenaLighting.set_look),
## which is brighter than the entrance look they started the show on.
static func _after_bell(rig: Node, light: Light3D, before: float) -> float:
	var n := String(light.name)
	if n.begins_with("Key"):
		return rig.key_energy
	if n.begins_with("Top"):
		return rig.top_energy
	return before



## Cody's routine (and Roman's after it) holds the same contract: continuous
## outside the cuts, both on their marks at the bell, and the backlight,
## pyro and blackout all gone.
func test_codys_entrance_is_continuous_and_cleans_up() -> void:
	var scene := _match(true, "roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rig := scene.get_node("LightRig")
	var light: Light3D = null
	for child in rig.get_children():
		if child is Light3D and not String(child.name).begins_with("Accent"):
			light = child
			break
	var before := light.light_energy
	var saw := {}
	_assert_continuous(scene, func():
		if director._backlight and director._backlight.visible:
			saw["backlight"] = true
		if light.light_energy < before * 0.05:
			saw["blackout"] = true
		var coat: EntranceCoat = director._coats.get(scene.get_node("WrestlerB"))
		if coat and coat._root:
			saw["coat_on" if coat._root.visible else "coat_off"] = true)
	assert_bool(saw.has("backlight")).override_failure_message("no silhouette backlight").is_true()
	assert_bool(saw.has("blackout")).override_failure_message("the house never went dark").is_true()
	assert_bool(saw.has("coat_on")).override_failure_message("he never wore the coat").is_true()
	assert_bool(saw.has("coat_off")).override_failure_message("the coat never came off").is_true()
	assert_bool(director._coats.is_empty()).is_true()
	assert_object(director._backlight).is_null()
	assert_float(light.light_energy).is_equal_approx(_after_bell(rig, light, before), 0.0001)


## The WHOAs land on the music: in the dark the building is on camera, he
## walks out of the smoke on the third WHOA, the WHOA pose on the hit, the
## fists driven down on the punch (refs/entrances.md, measured).
func test_codys_beats_land_on_the_music() -> void:
	var scene := _match(true, "", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var b_man: WrestlerController = scene.get_node("WrestlerB")
	var start := -1
	var ticks := 0
	var starts := {}
	var last := -1
	var seen_at := -1
	while ticks < 20000 and director._beat < director._beats.size():
		var b: Dictionary = director._beats[director._beat]
		if director._beat != last:
			last = director._beat
			if b.get("kind") == "hold" and start < 0:
				start = ticks
			var clip: String = b.get("clip", "")
			if start >= 0 and not starts.has(clip):
				starts[clip] = ticks - start
		director._physics_process(1.0 / 60.0)
		ticks += 1
		if start >= 0 and seen_at < 0 and b_man.visible:
			seen_at = ticks - start
		if starts.has("strikes/whoa_low"):
			break
	# Measured in his music (EntranceDirector's CODY_* notes): nobody on
	# camera until the first sung WHOA -- he used to walk out 16 s early, on
	# an intro swell -- and each pose's accent on its phrase, within two ticks.
	var on := func(what: String, at: int, music: float) -> void:
		assert_int(at).override_failure_message("%s at tick %d, music %.2f s" % [
				what, at, music]).is_between(int(round(music * 60)) - 2,
				int(round(music * 60)) + 2)
	on.call("appears", seen_at, EntranceDirector.CODY_EMERGE)
	on.call("WHOA arms wide", starts.get("strikes/whoa_arms", -999)
			+ EntranceDirector.WHOA_WIDE_AT, EntranceDirector.CODY_WHOA)
	on.call("fists down", starts.get("strikes/fists_down", -999)
			+ EntranceDirector.CODY_PUNCH_AT, EntranceDirector.CODY_PUNCH)
	on.call("knee down", starts.get("strikes/kneel", -999)
			+ EntranceDirector.KNEEL_DOWN_AT, EntranceDirector.CODY_KNEEL)
	on.call("low WHOA wide", starts.get("strikes/whoa_low", -999)
			+ EntranceDirector.WHOA_LOW_WIDE_AT, EntranceDirector.CODY_WHOA_LOW)


## Roman's finger is in the air on the slam of his music, and the pyro with
## it (refs/entrances.md, R-41 and the measured track).
func test_romans_finger_lands_on_the_slam() -> void:
	var scene := _match(true, "", "roman")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var start := -1
	var ticks := 0
	var pyro_at := -1
	while ticks < 20000 and director._beat < director._beats.size():
		var b: Dictionary = director._beats[director._beat]
		if b.get("kind") == "hold" and start < 0:
			start = ticks
		director._physics_process(1.0 / 60.0)
		ticks += 1
		if start >= 0 and director._pyro and pyro_at < 0:
			pyro_at = ticks - start
			break
	assert_int(pyro_at).override_failure_message("pyro at %d" % pyro_at) \
			.is_between(int(round(EntranceDirector.ROMAN_MUSIC_HIT * 60)) - 2,
				int(round(EntranceDirector.ROMAN_MUSIC_HIT * 60)) + 2)


## The owner: no grapple stance before the bell -- they walk up to each
## other, face off, and the bell rings. Stepped through the face-off: at the
## stare they stand FACEOFF_GAP apart, square to each other, and no beat of
## the whole entrance plays the grapple crouch.
func test_they_walk_up_and_face_off_before_the_bell() -> void:
	var scene := _match(true, "roman", "cody")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	for beat: Dictionary in director._beats:
		for move: Array in beat.get("moves", []):
			assert_str(move[4]).is_not_equal("strikes/idle_ready")
	var stare := -1
	for i in director._beats.size():
		var beat: Dictionary = director._beats[i]
		if beat["kind"] == "pair" and (beat["moves"][0] as Array)[4] == "strikes/face_off" \
				and (beat["moves"][0] as Array)[1] == (beat["moves"][0] as Array)[2]:
			stare = i
			break
	assert_int(stare).is_greater(0)
	for w: WrestlerController in [a, b]:
		w.global_transform = director._mark[w]
	director._beat = stare - 1
	director._start_beat()
	for _i in 400:
		director._physics_process(1.0 / 60.0)
		if director._beat > stare:
			break
		if director._beat == stare and director._tick > 60:
			break
	assert_float(a.global_position.distance_to(b.global_position)) \
			.is_equal_approx(EntranceDirector.FACEOFF_GAP, 0.02)
	for pair: Array in [[a, b], [b, a]]:
		var me: WrestlerController = pair[0]
		var facing := -me.global_transform.basis.z
		var to_other: Vector3 = (pair[1] as WrestlerController).global_position - me.global_position
		facing.y = 0.0
		to_other.y = 0.0
		assert_float(facing.normalized().dot(to_other.normalized())).is_greater(0.99)
	assert_str(a._presentation_clip).is_equal("strikes/face_off")


## Item 11's tron rim hangs between him and the video wall and above him, so
## it lights his head and shoulders from behind, wherever he is on the walk.
func test_tron_rim_hangs_between_him_and_the_wall() -> void:
	for at: Vector3 in [Vector3(0.0, 0.35, -30.0), Vector3(1.0, 0.2, -14.0), Vector3(0.0, 0.0, -6.0)]:
		var rim := EntranceDirector.tron_rim_at(at)
		assert_float(rim.y - at.y).is_equal_approx(EntranceDirector.TRON_RIM_UP, 0.001)
		assert_float(rim.z).is_less(at.z)
		var flat := Vector3(rim.x - at.x, 0.0, rim.z - at.z)
		assert_float(flat.length()).is_equal_approx(EntranceDirector.TRON_RIM_BACK, 0.001)


## The owner: the music stopped too soon. Each man's music plays from his
## first beat to the end of his entrance -- through every pose and until his
## props are handed off and he is settled on his mark -- and only then
## fades; the next man's starts after it, never on top of it.
func test_the_music_plays_until_he_is_done() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"]]:
		var scene := _match(true, styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		var wall: StageVideo = scene.find_child("StageVideo", true, false)
		var log: Array = []
		director.cue.connect(func(what: String) -> void:
			log.append([what, wall.is_music_playing()]))
		var ticks := 0
		var silent_ticks := 0
		var on := false
		while ticks < 30000 and not director._done:
			director._physics_process(1.0 / 60.0)
			ticks += 1
			if log.size() > 0 and log[-1][0] == "tron_on":
				on = true
			if log.size() > 0 and log[-1][0] == "tron_off":
				on = false
			if on and not wall.is_music_playing():
				silent_ticks += 1
		assert_int(silent_ticks).override_failure_message("%s: %d silent ticks mid-entrance" % [
				styles, silent_ticks]).is_equal(0)
		# Every prop handed off before the music goes, and the music up for it.
		var order: Array = log.map(func(e: Array) -> String: return e[0])
		for prop: String in ["coat_off", "fala_off"]:
			var at := order.find(prop)
			assert_int(at).is_greater_equal(0)
			assert_bool(log[at][1]).override_failure_message("%s without music" % prop).is_true()
			assert_int(order.find("tron_off", at)).is_greater(at)
		# Two entrances, two tracks, one after the other.
		assert_int(order.count("tron_on")).is_equal(2)
		assert_int(order.find("tron_on", order.find("tron_off"))).is_greater(order.find("tron_off"))


## The owner: the songs stopped too soon. Each is the whole song, longer
## than the entrance it plays under -- measured on the built timeline, from
## his first beat to his music fading -- with room to spare, so it never
## runs out and never has to loop.
func test_each_song_outlasts_its_entrance() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"]]:
		var scene := _match(true, styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		var on := {}
		var lengths := {}
		var ticks := [0]
		var who := [""]
		director.beat_started.connect(func(_s: String) -> void:
			var w: WrestlerController = (director._beats[director._beat] as Dictionary).get("who")
			if w:
				who[0] = w.entrance_style)
		director.cue.connect(func(what: String) -> void:
			if what == "tron_on":
				on[who[0]] = ticks[0]
			elif what == "tron_off" and on.has(who[0]):
				lengths[who[0]] = (ticks[0] - on[who[0]]) / 60.0)
		while ticks[0] < 30000 and not director._done:
			director._physics_process(1.0 / 60.0)
			ticks[0] += 1
		for style: String in ["roman", "cody"]:
			var stream := load(StageVideo.ENTRANCES[style]["music"]) as AudioStreamOggVorbis
			assert_float(float(lengths.get(style, 9999.0))).override_failure_message(
					"%s: entrance %.1f s, song %.1f s" % [style, lengths.get(style, -1.0),
					stream.get_length()]).is_less(stream.get_length() - 20.0)
			assert_bool(stream.loop).is_false()
