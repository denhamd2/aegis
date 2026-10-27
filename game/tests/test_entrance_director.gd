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


func test_the_prematch_crowd_exchange_finishes_before_the_entrances() -> void:
	var excalibur_stream := load(MatchAudio.COMMENTARY_CLIPS["excalibur_crowd"][0]) as AudioStream
	var tony_stream := load(MatchAudio.COMMENTARY_CLIPS["tony_crowd_up"][0]) as AudioStream
	var excalibur := excalibur_stream.get_length()
	var tony := tony_stream.get_length()
	var needed := excalibur + tony + MatchAudio.COMMENTARY_EVENT_DELAY * 2.0
	var available := float(EntranceDirector.EXCALIBUR_CROWD_CALL_TICKS) / EntranceDirector.TPS
	assert_float(available).is_greater_equal(needed)


## Everything that plays the match waits for the bell, and so does the replay.
func test_the_match_is_frozen_until_the_bell() -> void:
	var scene := _match(true)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	assert_object(director).is_not_null()
	for path in ["WrestlerA", "WrestlerB", "MatchReferee", "GrappleRig", "MatchFlow"]:
		assert_bool(scene.get_node(path).is_physics_processing()) \
				.override_failure_message("%s runs during the entrance" % path) \
				.is_false()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.mode).is_equal(MatchCamera.Mode.ENTRANCE)


## The match's story starts at the bell, not when the scene is built. Its
## clock used to run through the entrances (~5 minutes from the menu), so a
## menu-launched match rang the bell already in the comeback and lasted under
## four minutes, while every probe -- which skips the entrances -- measured
## eight.
func test_the_story_clock_starts_at_the_bell() -> void:
	var scene := _match(true)
	var flow: MatchFlow = scene.get_node("MatchFlow")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	for _i in 30:
		await get_tree().physics_frame
	assert_int(flow.tick).is_equal(0)
	director.skip()
	assert_bool(flow.is_physics_processing()).is_true()
	for _i in 3:
		await get_tree().physics_frame
	assert_int(flow.tick).is_greater(0)
	assert_str(String(flow.phase()["name"])).is_equal("feeling_out")


func test_skipping_rings_the_bell_with_both_men_on_their_marks() -> void:
	var scene := _match(true)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var hud: CanvasLayer = scene.get_node("MatchHUD")
	assert_bool(hud.visible).is_false()
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
	assert_bool(hud.visible).override_failure_message(
			"The match HUD must return when the entrance rings the bell").is_true()
	assert_bool(a.is_physics_processing()).is_true()
	assert_bool(scene.get_node("MatchReferee").is_physics_processing()).is_true()
	assert_bool(scene.get_node("MatchFlow").is_physics_processing()).is_true()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)


## Both men meet the bell squared up to each other. The scene's spawns face
## outward, and the entrance used to end on them: the owner saw both men
## finish with their backs to each other.
func test_the_bell_finds_them_facing_each_other() -> void:
	var scene := _match(true, "roman", "cody")
	_assert_continuous(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
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


## Check the last rendered entrance pose as well as the post-bell match state.
## The bell is the handoff from the presentation timeline to gameplay, so a
## final transform correction must not conceal a missed face-off turn.
func test_roman_faces_cody_on_the_last_pre_bell_frame() -> void:
	var scene := _match(true, "roman", "cody")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var final_beat := director._beats.size() - 1
	while director._beat < final_beat:
		director._physics_process(1.0 / 60.0)
		_step_actors(scene)
	var ticks: int = (director._beats[final_beat] as Dictionary)["ticks"]
	for _i in ticks - 1:
		director._physics_process(1.0 / 60.0)
		_step_actors(scene)
	for pair: Array in [[a, b], [b, a]]:
		var me: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		var facing := -me.global_transform.basis.z
		var to_other := other.global_position - me.global_position
		facing.y = 0.0
		to_other.y = 0.0
		assert_float(facing.normalized().dot(to_other.normalized())) \
				.override_failure_message("%s is turned away on the final pre-bell frame" \
				% me.name).is_greater(0.99)
	# The next tick rings the bell and reasserts the match marks' headings.
	director._physics_process(1.0 / 60.0)
	for pair: Array in [[a, b], [b, a]]:
		var me: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		var facing := -me.global_transform.basis.z
		var to_other := other.global_position - me.global_position
		facing.y = 0.0
		to_other.y = 0.0
		assert_float(facing.normalized().dot(to_other.normalized())) \
				.override_failure_message("%s is turned away at the bell" % me.name) \
				.is_greater(0.99)


func test_the_match_intro_and_faceoff_are_kept_brief() -> void:
	assert_int(EntranceDirector.INTRO_CARD_TICKS).is_less_equal(180)
	assert_int(EntranceDirector.INTRO_CHECK_TICKS).is_less_equal(120)
	assert_int(EntranceDirector.INTRO_CLOSE_TICKS).is_less_equal(150)
	assert_int(EntranceDirector.FACEOFF_STARE_TICKS).is_less_equal(360)
	assert_str(EntranceDirector.faceoff_shot_at(1.9)).is_equal("profile")
	assert_str(EntranceDirector.faceoff_shot_at(2.0)).is_equal("ots")


func test_broadcast_open_uses_stage_facing_pyro_angles_and_the_sign_cutaway() -> void:
	var opening := EntranceDirector.opening_shot_at(0.0)
	var stage_side := EntranceDirector.opening_shot_at(5.0)
	var sign_fan := EntranceDirector.opening_shot_at(9.0)
	var sign_fan_alt := EntranceDirector.opening_shot_at(10.0)
	var final_stage := EntranceDirector.opening_shot_at(34.0)
	assert_int(opening[0]).is_equal(0)
	assert_int(stage_side[0]).is_equal(1)
	assert_int(sign_fan[0]).is_equal(EntranceDirector.OPENING_SIGN_SHOT_INDEX)
	assert_int(sign_fan_alt[0]).is_equal(EntranceDirector.OPENING_SIGN_ALT_SHOT_INDEX)
	assert_int(final_stage[0]).is_equal(4)
	assert_float(opening[1].x).is_not_equal(stage_side[1].x)
	assert_float(stage_side[2].z).is_less(-30.0)
	assert_float(sign_fan[2].x).is_equal_approx(SignFans.FANS[0][1].x, 0.01)
	assert_float(sign_fan_alt[2].x).is_equal_approx(SignFans.FANS[0][1].x, 0.01)
	var scene := _match(true)
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var events: Array = director._beats[0].get("events", [])
	assert_bool(events.any(func(e: Array) -> bool: return e[1] == "broadcast_open")).is_true()
	assert_bool(events.any(func(e: Array) -> bool: return e[1] == "pyro_opening")).is_true()
	var rockets := EntrancePyro.opening_rocket_plan()
	assert_int(rockets.size()).is_equal(5)
	for rocket: Array in rockets:
		var from: Vector3 = rocket[0]
		var to: Vector3 = rocket[1]
		assert_float(to.y).is_greater(from.y)
		assert_float(to.y - from.y).is_equal_approx(EntrancePyro.OPENING_ROCKET_RISE, 0.001)
	var opening_hold: Dictionary = director._beats[1]
	assert_bool(opening_hold.get("events", []).any(
			func(e: Array) -> bool: return e[1] == EntranceDirector.OPENING_SIGN_CUE)) \
			.override_failure_message("the Enda-sign fan is not raised for the opening cutaway") \
			.is_true()


func test_roman_waits_with_his_arms_at_his_sides_before_the_faceoff() -> void:
	var roman := WrestlerController.new()
	roman.entrance_style = "roman"
	assert_str(EntranceDirector._wait_clip(roman)).is_equal("strikes/roman_stand")
	roman.free()


func test_cody_return_commentary_cue_lands_when_he_emerges() -> void:
	var scene := _match(true, "roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var found := false
	for beat: Dictionary in director._beats:
		if beat.get("who") != cody or not beat.get("appear", false):
			continue
		for event: Array in beat.get("events", []):
			found = found or event[1] == "cody_appear"
	assert_bool(found).override_failure_message("Cody's emergence has no return-call cue").is_true()


func test_tension_commentary_cue_lands_at_the_faceoff_stare() -> void:
	var scene := _match(true, "roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var found := false
	for beat: Dictionary in director._beats:
		if beat.get("shot", "") != "faceoff_seq":
			continue
		for event: Array in beat.get("events", []):
			found = found or event[1] == "faceoff_tension"
	assert_bool(found).override_failure_message(
			"Tony's tension call is not cued during the faceoff stare").is_true()


## The whole entrance, stepped: nobody jumps except at the broadcast cut (and
## on appearing), and it ends with the bell and both men on their marks.
func test_the_walk_is_continuous_and_ends_on_the_marks() -> void:
	_assert_continuous(_match(true))


## Both entrance routines start their climb on the actual outer stair edge,
## then land on the top platform and apron heights. Starting halfway up the
## collision footprint at floor height caused the visible ringside float.
func test_both_entrances_climb_from_the_stair_foot_to_the_apron() -> void:
	var scene := _match(true, "roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var out := RingBuilder.step_out_dir(EntranceDirector.ENTRY_CORNER)
	var apron_corner := Vector3(EntranceDirector.ENTRY_CORNER.x * RingBuilder.APRON_OUT,
			0.0, EntranceDirector.ENTRY_CORNER.y * RingBuilder.APRON_OUT)
	var stair_foot := apron_corner + out * (RingBuilder.STEP_APRON_GAP
			+ RingBuilder.STEP_PLATFORM + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS)
	var climbs := 0
	var apron_steps := 0
	var rope_steps := 0
	for beat: Dictionary in director._beats:
		if beat.get("clip") == "strikes/climb_steps":
			climbs += 1
			var from: Vector3 = beat["from"]
			var to: Vector3 = beat["to"]
			assert_vector(Vector3(from.x, 0.0, from.z)).is_equal_approx(stair_foot,
					Vector3.ONE * 0.001)
			# On the ringside mat, where the walk before it put him.
			assert_float(from.y).is_equal_approx(
					ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT, 0.001)
			assert_float(to.y).is_equal_approx(RingBuilder.STEP_TOP_Y, 0.001)
		# Each travelling clip moves the root exactly as far as its boots
		# were keyed for (wrestling_clips.py reads the same numbers): the
		# float up the steps was a route 0.28 m longer than the clip.
		var travel: Dictionary = {
			"strikes/climb_steps": Vector2(EntranceDirector.CLIMB_FWD, EntranceDirector.CLIMB_UP),
			"strikes/apron_step": Vector2(EntranceDirector.APRON_STEP_FWD,
					EntranceDirector.APRON_STEP_UP),
			"strikes/rope_step_through_apron": Vector2(EntranceDirector.APRON_ROPE_FWD,
					EntranceDirector.APRON_ROPE_UP),
		}
		if travel.has(beat.get("clip", "")):
			var want: Vector2 = travel[beat["clip"]]
			var a: Vector3 = beat["from"]
			var b: Vector3 = beat["to"]
			assert_float(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))) \
					.override_failure_message("%s travels along" % beat["clip"]) \
					.is_equal_approx(want.x, 0.02)
			assert_float(b.y - a.y).override_failure_message("%s travels up" % beat["clip"]) \
					.is_equal_approx(want.y, 0.02)
		if beat.get("clip") == "strikes/apron_step":
			apron_steps += 1
			assert_float((beat["from"] as Vector3).y).is_equal_approx(
					RingBuilder.STEP_TOP_Y, 0.001)
			assert_float((beat["to"] as Vector3).y).is_equal_approx(
					RingBuilder.APRON_TOP, 0.001)
		if beat.get("clip") == "strikes/rope_step_through_apron":
			rope_steps += 1
			assert_float((beat["from"] as Vector3).y).is_equal_approx(
					RingBuilder.APRON_TOP, 0.001)
			assert_float((beat["to"] as Vector3).y).is_equal_approx(0.0, 0.001)
	assert_int(climbs).is_equal(2)
	assert_int(apron_steps).is_equal(2)
	assert_int(rope_steps).is_equal(2)


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
	# The owner's call: no belt on the walk (it waits on the timekeeper's
	# table for the winner, TitlePresentation). His pyro and the fala remain.
	for k in ["pyro"]:
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
	var worst_detail := ""
	var ticks := 0
	# Entrance runtimes are authored as beats and can legitimately exceed five
	# minutes when both full entrances, music holds, and the Dynamite open run.
	# Bound this probe by the actual timeline plus room for prop handoff instead
	# of silently timing out halfway through a valid sequence.
	var max_ticks := 1
	for beat: Dictionary in director._beats:
		var kind: String = beat.get("kind", "")
		var beat_ticks := int(beat.get("ticks", 1))
		if kind == "walk":
			var path: Array = beat.get("path", [])
			var distance := 0.0
			for i in path.size() - 1:
				var from: Vector3 = path[i]
				var to: Vector3 = path[i + 1]
				distance += Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
			beat_ticks = maxi(1, int(ceil(distance / float(beat.get("speed",
					EntranceDirector.WALK_SPEED)) * EntranceDirector.TPS)))
		elif kind == "turn":
			beat_ticks = EntranceDirector.SETTLE_TICKS if beat.get("settle", false) else 18
		max_ticks += beat_ticks
		if beat.get("wait_idle", false):
			max_ticks += EntranceDirector.HANDOFF_MAX_WAIT
	while not rang[0] and ticks < max_ticks:
		var beat_before := director._beat
		director._physics_process(1.0 / 60.0)
		_step_actors(scene)
		ticks += 1
		if each_tick.is_valid():
			each_tick.call()
		for w: WrestlerController in [a, b]:
			var previous: Vector3 = last[w]
			var moved: float = (w.global_position - previous).length()
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
				if moved > worst:
					worst = moved
					worst_detail = "%s at tick %d after %s/%s: %s -> %s" % [w.name,
							ticks, started.get("kind", ""), started.get("clip", ""),
							previous, w.global_position]
	var handoff := scene.get_node_or_null("PropHandoff") as PropHandoff
	var final_beat: Dictionary = director._beats[mini(director._beat,
			director._beats.size() - 1)] if not director._beats.is_empty() else {}
	var end_state := "no bell after %d ticks at beat %d/%d tick %d (%s), handoff step %d jobs %d" % [
			ticks, director._beat, director._beats.size(), director._tick,
			final_beat.get("kind", "none"), handoff.step if handoff else -1,
			handoff._jobs.size() if handoff else -1]
	assert_bool(rang[0]).override_failure_message(end_state).is_true()
	assert_float(worst).override_failure_message(
			"a wrestler jumped %.3f m in one tick (%s)" % [worst, worst_detail]).is_less(0.1)
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
	assert_int(rig.look).is_equal(ArenaLighting.Look.MATCH)
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
	assert_int(rig.look).is_equal(ArenaLighting.Look.ENTRANCE)
	var entrance_energy: float = rig.key_energy if String(light.name).begins_with("Key") else rig.top_energy
	assert_float(light.light_energy).is_equal_approx(entrance_energy
			* ArenaLighting.ENTRANCE_RING_SHARE * EntranceDirector.ROMAN_HOUSE_DIM, 0.001)
	director.skip()
	assert_float(light.light_energy).is_equal_approx(_after_bell(rig, light, before), 0.0001)


## What a rig light reads once the bell has rung: the house dim undone, and
## the ring keys and top fill on the match look (ArenaLighting.set_look).
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
			if coat._root.visible and saw.has("coat_off"):
				saw["coat_back"] = true
			saw["coat_on" if coat._root.visible else "coat_off"] = true)
	assert_bool(saw.has("backlight")).override_failure_message("no silhouette backlight").is_true()
	assert_bool(saw.has("blackout")).override_failure_message("the house never went dark").is_true()
	assert_bool(saw.has("coat_on")).override_failure_message("he never wore the coat").is_true()
	assert_bool(saw.has("coat_off")).override_failure_message("the coat never came off").is_true()
	assert_bool(director._coats.is_empty()).is_true()
	# Taken off, not left on him: once it is off it never shows on his body
	# again, and the folded one is in the hand-off, on the table.
	assert_bool(saw.has("coat_back")).override_failure_message("the worn coat came back").is_false()
	var handoff: PropHandoff = scene.get_node("PropHandoff")
	assert_bool(handoff.delivered.has("coat")).is_true()
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
			# His music starts on his own first beat -- not the announcer's
			# intro before it, which is a hold with nobody in it.
			if b.get("kind") == "hold" and b.get("who") != null and start < 0:
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


func test_cody_settles_out_of_his_tunnel_walk_before_the_whoa_pose() -> void:
	var scene := _match(true, "", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var emerge := -1
	for i in director._beats.size():
		var beat: Dictionary = director._beats[i]
		if beat.get("who") == cody and beat.get("appear", false):
			emerge = i
			break
	assert_int(emerge).is_greater_equal(0)
	director._beat = emerge
	director._start_beat()
	var beat: Dictionary = director._beats[emerge]
	var settle_ticks := int(beat["settle_ticks"])
	var settle_at := int(beat["ticks"]) - settle_ticks
	assert_str(String(beat["settle_clip"])).is_equal("strikes/cody_stand")
	assert_str(cody._presentation_clip).is_equal(EntranceDirector.CODY_WALK_CLIP)
	for _i in settle_at - 1:
		director._physics_process(1.0 / 60.0)
	assert_str(cody._presentation_clip).is_equal(EntranceDirector.CODY_WALK_CLIP)
	# The gait-to-stand blend begins before the walk ends; the timeline and the
	# following music-synced WHOA beat keep their original tick positions.
	director._physics_process(1.0 / 60.0)
	assert_str(cody._presentation_clip).is_equal("strikes/cody_stand")
	assert_int(director._beat).is_equal(emerge)
	var progress: Array[float] = []
	for tick in int(beat["ticks"]) + 1:
		progress.append(EntranceDirector._walk_distance_fraction(
				beat, float(tick) / float(beat["ticks"])))
	assert_float(progress[0]).is_equal_approx(0.0, 0.0001)
	assert_float(progress[-1]).is_equal_approx(1.0, 0.0001)
	for i in progress.size() - 1:
		assert_float(progress[i + 1]).is_greater_equal(progress[i])
	assert_float(progress[-1] - progress[-2]).is_less(progress[1] - progress[0])


## Roman's finger is in the air on the slam of his music, and the pyro with
## it (refs/entrances.md, R-41 and the measured track).
func test_romans_finger_lands_on_the_slam() -> void:
	var scene := _match(true, "", "roman")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var start := -1
	var ticks := 0
	var cues: Array = []
	var clock := [0]
	director.cue.connect(func(what: String) -> void: cues.append([what, clock[0]]))
	while ticks < 20000 and director._beat < director._beats.size():
		var b: Dictionary = director._beats[director._beat]
		if b.get("kind") == "hold" and b.get("who") != null and start < 0:
			start = ticks
		director._physics_process(1.0 / 60.0)
		ticks += 1
		clock[0] = ticks
		if start >= 0 and cues.any(func(c: Array) -> bool: return c[0] == "pyro_roman"):
			break
	var slam_at := -1
	var first_pyro_at := -1
	for c: Array in cues:
		if c[0] == "pyro_stage" and first_pyro_at < 0:
			first_pyro_at = c[1] - start
		if c[0] == "pyro_roman" and slam_at < 0:
			slam_at = c[1] - start
	assert_int(slam_at).override_failure_message("slam pyro at %d" % slam_at) \
			.is_between(int(round(EntranceDirector.ROMAN_MUSIC_HIT * 60)) - 2,
				int(round(EntranceDirector.ROMAN_MUSIC_HIT * 60)) + 2)
	# He walks out on the first pyro, well before the slam.
	assert_int(first_pyro_at).is_greater(0)
	assert_int(first_pyro_at).is_less(slam_at)


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


## The bottom-right SKIP ENTRANCE button skips only the entrance that is
## running: the first man's skip lands on the handover with him on his mark,
## the second's on the introductions -- neither rings the bell.
func test_skip_entrance_skips_one_man_at_a_time() -> void:
	var scene := _match(true, "roman", "cody")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var mark_a := a.global_transform
	var mark_b := b.global_transform
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	for _i in 30:
		director._physics_process(1.0 / 60.0)
	var button := director.find_child("SkipEntrance", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.visible).is_true()
	# First up is the opponent (WrestlerB).
	assert_object(director.entrance_owner()).is_same(b)
	director.skip_entrance()
	assert_bool(rang[0]).is_false()
	assert_vector(b.global_position).is_equal_approx(mark_b.origin, Vector3.ONE * 0.001)
	assert_bool(b.visible).is_true()
	# Through the handover into the second man's entrance.
	var guard := 0
	while director.entrance_owner() != a and guard < 2000:
		director._physics_process(1.0 / 60.0)
		guard += 1
	assert_object(director.entrance_owner()).is_same(a)
	director.skip_entrance()
	assert_bool(rang[0]).is_false()
	assert_vector(a.global_position).is_equal_approx(mark_a.origin, Vector3.ONE * 0.001)
	assert_object(director.entrance_owner()).is_null()
	director._physics_process(1.0 / 60.0)
	assert_bool(button.visible).is_false()
	# And the intro still runs to the bell.
	guard = 0
	while not rang[0] and guard < 20000:
		director._physics_process(1.0 / 60.0)
		guard += 1
	assert_bool(rang[0]).is_true()


## Smooth motion (roman_entrance_aaa_plan.md step 1): during the entrances the
## pose is evaluated every drawn frame and the wrestlers and camera are
## interpolated between ticks; at the bell the pose goes back to the tick.
## tools/probe/motion_cadence.tscn measures the result: 0 held frames of 240 at
## 120 fps, against 119 with this off.
func test_entrances_animate_at_render_rate_and_the_match_at_tick_rate() -> void:
	assert_bool(ProjectSettings.get_setting("physics/common/physics_interpolation")).is_true()
	var scene := _match(true, "roman", "cody")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	await await_millis(20)
	assert_int(a.anim_tree.callback_mode_process).is_equal(
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)
	assert_int(a.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_ON)
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_ON)
	assert_int(scene.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	director.skip()
	assert_int(a.anim_tree.callback_mode_process).is_equal(
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS)


## Kenny walks his own entrance (EntranceDirector._add_kenny_entrance; best
## knowledge, unverified): his walk down the ramp with a hand slapped on each
## side, the stage pose with the stage pyro, his arms spread on the second
## rope with the ring pyro, and his own stand on his mark.
func test_kenny_walks_his_own_entrance() -> void:
	var scene := _match(true, "", "kenny")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var kenny: WrestlerController = scene.get_node("WrestlerB")
	var clips := {}
	var walks := {}
	var gestures: Array = []
	var events := {}
	for beat: Dictionary in director._beats:
		if beat.get("who") != kenny:
			continue
		clips[beat.get("clip", "")] = true
		if beat["kind"] == "walk":
			walks[beat.get("walk_clip", "strikes/entrance_walk")] = true
		if beat.has("gesture"):
			gestures.append(beat["gesture"])
		for e: Array in beat.get("events", []):
			events[e[1]] = true
	for clip in ["strikes/kenny_stage_pose", "strikes/kenny_stand",
			"strikes/corner_climb", "strikes/kenny_corner_wings", "strikes/corner_down"]:
		assert_bool(clips.has(clip)).override_failure_message("no %s" % clip).is_true()
	assert_array(walks.keys()).contains_exactly([EntranceDirector.KENNY_WALK_CLIP])
	assert_array(gestures).contains_exactly(EntranceDirector.KENNY_WALK_GESTURES)
	for e in ["tron_on", "dim_on", "pyro_stage", "pyro_over_ring", "tron_off", "dim_off"]:
		assert_bool(events.has(e)).override_failure_message("no %s" % e).is_true()
	assert_str(EntranceDirector._wait_clip(kenny)).is_equal("strikes/kenny_stand")
	# Every clip he plays is in the game.
	for clip: String in clips.keys() + walks.keys() + gestures:
		if clip != "":
			assert_bool(kenny.anim_player.has_animation(clip)) \
				.override_failure_message("%s is not built" % clip).is_true()


## He walks out on the onset at 20.8 s and his arms go wide -- the stage pyro
## with them -- on the lift at 37 s, measured in his music.
func test_kennys_beats_land_on_the_music() -> void:
	var scene := _match(true, "", "kenny")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var kenny: WrestlerController = scene.get_node("WrestlerB")
	var start := -1
	var ticks := 0
	var starts := {}
	var last := -1
	var seen_at := -1
	# A lambda captures locals by value: the pyro's tick goes in an array.
	var pyro_ticks: Array[int] = []
	var clock: Array[int] = [0]
	director.cue.connect(func(what: String) -> void:
		if what == "pyro_stage":
			pyro_ticks.append(clock[0]))
	while ticks < 20000 and director._beat < director._beats.size():
		var b: Dictionary = director._beats[director._beat]
		if director._beat != last:
			last = director._beat
			if b.get("kind") == "hold" and b.get("who") != null and start < 0:
				start = ticks
			var clip: String = b.get("clip", "")
			if start >= 0 and not starts.has(clip):
				starts[clip] = ticks - start
		clock[0] = ticks + 1
		director._physics_process(1.0 / 60.0)
		ticks += 1
		if start >= 0 and seen_at < 0 and kenny.visible:
			seen_at = ticks - start
		if not pyro_ticks.is_empty():
			break
	var on := func(what: String, at: int, music: float) -> void:
		assert_int(at).override_failure_message("%s at tick %d, music %.2f s" % [
				what, at, music]).is_between(int(round(music * 60)) - 2,
				int(round(music * 60)) + 2)
	on.call("appears", seen_at, EntranceDirector.KENNY_OUT)
	on.call("arms wide", starts.get("strikes/kenny_stage_pose", -999)
			+ EntranceDirector.KENNY_PYRO_AT, EntranceDirector.KENNY_LIFT)
	on.call("stage pyro", (pyro_ticks[0] - start) if not pyro_ticks.is_empty() else -999,
			EntranceDirector.KENNY_LIFT)


## His music runs the whole of his entrance and outlasts it, walking first or
## second, and the house comes back up when he is done.
func test_kennys_music_outlasts_his_entrance() -> void:
	for styles: Array in [["cody", "kenny"], ["kenny", "cody"]]:
		var scene := _match(true, styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		var wall: StageVideo = scene.find_child("StageVideo", true, false)
		var kenny: WrestlerController = scene.get_node(
				"WrestlerA" if styles[0] == "kenny" else "WrestlerB")
		# Lambdas capture by value: the clock and the marks live in arrays.
		var ticks: Array[int] = [0]
		var marks := {}
		var silent := 0
		director.cue.connect(func(what: String) -> void:
			var w: WrestlerController = (director._beats[mini(director._beat,
					director._beats.size() - 1)] as Dictionary).get("who")
			if w == kenny and (what == "tron_on" or what == "tron_off") and not marks.has(what):
				marks[what] = ticks[0])
		while ticks[0] < 30000 and not director._done:
			director._physics_process(1.0 / 60.0)
			ticks[0] += 1
			if marks.has("tron_on") and not marks.has("tron_off") and not wall.is_music_playing():
				silent += 1
		var length := -1.0
		if marks.has("tron_on") and marks.has("tron_off"):
			length = (marks["tron_off"] - marks["tron_on"]) / 60.0
		var stream := load(StageVideo.ENTRANCES["kenny"]["music"]) as AudioStreamOggVorbis
		assert_float(length).override_failure_message("%s: no tron_off for Kenny" % [styles]) \
			.is_greater(0.0)
		assert_float(length).is_less(stream.get_length() - 20.0)
		assert_int(silent).override_failure_message("%s: %d silent ticks" % [styles, silent]) \
			.is_equal(0)
