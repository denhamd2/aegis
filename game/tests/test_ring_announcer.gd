extends GdUnitTestSuite
## The ring announcer (core/audio/ring_announcer.gd): Justin Roberts' intro
## at the start of the first entrance, and each man's call with his name said
## on the moment his card comes up.

const MATCH := "res://scenes/match.tscn"


func _match(style_a: String, style_b: String) -> Node:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = style_a
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = style_b
	add_child(scene)
	return auto_free(scene)


## Absolute tick of `tick` into beat `index`.
func _abs_tick(director: EntranceDirector, index: int, tick: int) -> int:
	var at := 0
	for i in index:
		at += director.beat_ticks(director._beats[i])
	return at + tick


func test_the_calls_ship_and_each_name_is_inside_its_call() -> void:
	for style in ["intro", "roman", "cody", "kenny"]:
		assert_bool(RingAnnouncer.has_call(style)).override_failure_message(
				"no %s call" % style).is_true()
	for style in ["roman", "cody", "kenny"]:
		assert_float(RingAnnouncer.name_at(style)).is_greater(0.0)
		assert_float(RingAnnouncer.name_at(style)) \
				.is_less(RingAnnouncer.length_of(style) - 1.0)


## Justin begins the match-format call on the first beat of the first man's
## entrance. It must not fire in the broadcast opening or pre-entrance holds.
func test_justins_intro_starts_with_the_first_entrance() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"]]:
		var scene := _match(styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		var first_man: WrestlerController = scene.get_node("WrestlerB")
		var entrance_index := -1
		var intro_events: Array[Array] = []
		for i in director._beats.size():
			var beat: Dictionary = director._beats[i]
			if entrance_index < 0 and beat.get("who") == first_man:
				entrance_index = i
			for event: Array in beat.get("events", []):
				if event[1] == "announce_intro":
					intro_events.append([i, int(event[0])])
		assert_int(entrance_index).is_greater_equal(0)
		assert_int(intro_events.size()).is_equal(1)
		assert_int(intro_events[0][0]).override_failure_message(
				"Justin's match call is not on the first man's entrance beat").is_equal(entrance_index)
		assert_int(intro_events[0][1]).is_equal(1)


## Each man's call starts so that his name lands on his card's moment, to
## the tick: Cody's on the low WHOA's arms going wide, Roman's and Kenny's
## half way down the ramp.
func test_each_name_is_said_on_his_card() -> void:
	for styles: Array in [["roman", "cody"], ["cody", "roman"], ["kenny", "cody"],
			["roman", "kenny"]]:
		var scene := _match(styles[0], styles[1])
		var director: EntranceDirector = scene.get_node("EntranceDirector")
		for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
			var starts: Array = []
			for i in director._beats.size():
				var beat: Dictionary = director._beats[i]
				for cue: Array in beat.get("events", []):
					if cue[1] == "announce" and beat.get("who") == w:
						starts.append(_abs_tick(director, i, int(cue[0])))
			assert_int(starts.size()).override_failure_message(
					"%s is announced %d times" % [w.entrance_style, starts.size()]).is_equal(1)
			var moment := director._name_moment(w, 0)
			var name_tick := _abs_tick(director, int(moment[0]), int(moment[1]))
			var said := int(starts[0]) + int(round(RingAnnouncer.name_at(w.entrance_style)
					* EntranceDirector.TPS))
			# Kenny's own entrance (27 Oct) is long enough that his 18.9 s to
			# the name lands on his ramp card like anyone's; on the old plain
			# walk it came after his card and the ramp put the card up instead.
			assert_int(absi(said - name_tick)).override_failure_message(
					"%s's name is said %d ticks off his card" % [w.entrance_style, said - name_tick]
			).is_less_equal(1)


## The card goes up on the call, and only on it: the half-way-down-the-ramp
## trigger stands down for a man who is announced.
func test_the_card_goes_up_when_the_name_is_called() -> void:
	var scene := _match("roman", "cody")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	director._tick_ramp_card(cody)
	assert_bool(director._card.is_showing()).is_false()
	# Said before his entrance has started, the name puts nothing up.
	director.voice_announcer().name_called.emit("cody")
	assert_bool(director._card.is_showing()).is_false()
	for i in director._beats.size():
		if director._beats[i].get("who") == cody:
			director._beat = i
			break
	director.voice_announcer().name_called.emit("cody")
	assert_bool(director._card.is_showing()).is_true()
	assert_int(director._name_card_ticks).is_equal(EntranceDirector.NAME_CARD_TICKS)


## The crowd beds sit under the voice (the entrance music is routed the same
## way, StageVideo._play_music).
func test_the_crowd_goes_under_the_voice() -> void:
	var scene := _match("roman", "cody")
	var audio := scene.get_node("MatchAudio")
	var beds := 0
	for p in audio.find_children("Loop_crowd_*", "AudioStreamPlayer", true, false):
		beds += 1
		assert_str((p as AudioStreamPlayer).bus).is_equal(RingAnnouncer.UNDER_BUS)
	assert_int(beds).is_greater_equal(6)
	assert_int(AudioServer.get_bus_index(RingAnnouncer.UNDER_BUS)).is_greater(0)


## The owner: the music went too low under Justin. The music keeps its level
## (not on the ducked bus); he is lifted over it on his own limited bus.
func test_justin_is_lifted_over_the_music_not_the_music_ducked() -> void:
	var scene := _match("roman", "cody")
	var voice := scene.find_child("Voice", true, false) as AudioStreamPlayer
	assert_object(voice).is_not_null()
	assert_str(voice.bus).is_equal(RingAnnouncer.VOICE_BUS)
	var i := AudioServer.get_bus_index(RingAnnouncer.VOICE_BUS)
	var lift := AudioServer.get_bus_effect(i, 0) as AudioEffectHardLimiter
	assert_object(lift).is_not_null()
	assert_float(lift.pre_gain_db).is_greater_equal(6.0)
	assert_float(RingAnnouncer.DUCK_DB).is_greater_equal(-4.0)
	var video := scene.find_children("*", "StageVideo", true, false)
	assert_array(video).is_not_empty()
	var sv: StageVideo = video[0]
	sv._play_music({"music": RingAnnouncer.CLIPS["intro"]})
	var music := sv.get_node("EntranceMusic") as AudioStreamPlayer
	assert_str(music.bus).is_not_equal(RingAnnouncer.UNDER_BUS)
	music.stop()


func test_justin_and_commentary_share_one_serial_voice_lane() -> void:
	var announcer: RingAnnouncer = auto_free(RingAnnouncer.new())
	add_child(announcer)
	var commentary := load(MatchAudio.COMMENTARY_CLIPS["gunshot"][0]) as AudioStream
	assert_bool(announcer.play("intro")).is_true()
	assert_bool(announcer.play_commentary(commentary)).is_true()
	assert_bool(announcer.play("roman")).is_true()
	assert_bool(announcer._player.playing).is_true()
	assert_str(announcer._style).is_equal("intro")
	assert_int(announcer._voice_queue.size()).is_equal(2)
	assert_str(String(announcer._voice_queue[0]["style"])).is_empty()
	assert_str(String(announcer._voice_queue[1]["style"])).is_equal("roman")
	announcer._player.stop()
	announcer._on_finished()
	assert_object(announcer._player.stream).is_same(commentary)
	assert_bool(announcer._player.playing).is_true()
	assert_bool(announcer.speaking_style().is_empty()).is_true()
	announcer._player.stop()
	announcer._on_finished()
	assert_object(announcer._player.stream).is_same(load(RingAnnouncer.CLIPS["roman"]))
	assert_bool(announcer._player.playing).is_true()
	assert_str(announcer._style).is_equal("roman")


## Tony answers Justin's call for Kenny: the director names whose call it was,
## and Tony's line waits in the voice lane until Justin has finished.
func test_tony_follows_justins_call_for_kenny() -> void:
	var scene := _match("cody", "kenny")
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var kenny: WrestlerController = scene.get_node("WrestlerB")
	var cues: Array[String] = []
	director.cue.connect(func(what: String) -> void: cues.append(what))
	director._event(kenny, "announce")
	assert_array(cues).is_equal(["announce", "called_kenny"])
	assert_str(MatchAudio.commentary_event_for_cue("called_kenny")).is_equal("tony_kenny_focus")
	assert_str(MatchAudio.commentator_for_event("tony_kenny_focus")).is_equal("tony")
	assert_bool(director.voice_announcer().has_voice()).is_true()
