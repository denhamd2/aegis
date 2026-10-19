extends GdUnitTestSuite
## A man is heard when he is hurt (WrestlerVoice; the owner, 19 Oct): a grunt
## on a blow, a yell for the worst of it, a groan on the mat, and a burning man
## screams until he is put out.

const MATCH_SCENE := "res://scenes/match.tscn"


func _move(id: String) -> MoveDef:
	return load("res://resources/moves/%s.tres" % id) as MoveDef


func _match() -> Node:
	var scene: Node = auto_free(load(MATCH_SCENE).instantiate())
	add_child(scene)
	return scene


func _voice(w: WrestlerController) -> WrestlerVoice:
	return w.find_child("PainVoice", false, false) as WrestlerVoice


func test_the_hit_decides_what_he_says() -> void:
	var S := WrestlerController.Sell
	var jab := _move("strike_jab")
	assert_str(WrestlerVoice.family_for(S.LIGHT, jab)).is_equal("grunt_light")
	assert_str(WrestlerVoice.family_for(S.HEAVY, jab)).is_equal("grunt_heavy")
	assert_str(WrestlerVoice.family_for(S.DOWN, jab)).is_equal("groan")
	# a signature or a finisher, a blade, a wipeout: a yell
	assert_str(WrestlerVoice.family_for(S.MEDIUM, _move("signature_superman_punch"))).is_equal("yell")
	assert_str(WrestlerVoice.family_for(S.KNEE,
			WeaponCatalog.swing_move(WeaponCatalog.by_id(&"knife")))).is_equal("yell")
	assert_str(WrestlerVoice.family_for(S.DOWN,
			WeaponCatalog.swing_move(WeaponCatalog.by_id(&"sledgehammer")))).is_equal("yell")
	# a chair or a kendo stick: a hard grunt
	assert_str(WrestlerVoice.family_for(S.DOWN,
			WeaponCatalog.swing_move(WeaponCatalog.by_id(&"steel_chair")))).is_equal("grunt_heavy")
	assert_str(WrestlerVoice.family_for(S.HEAVY,
			WeaponCatalog.swing_move(WeaponCatalog.by_id(&"kendo_stick")))).is_equal("grunt_heavy")


func test_a_heavy_hit_is_always_heard_and_a_light_one_only_sometimes() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var v := _voice(a)
	var said := []
	v.said.connect(func(f: String, _s: String) -> void: said.append(f))
	a.hurt.emit(WrestlerController.Sell.HEAVY, _move("strike_cross"))
	assert_array(said).contains_exactly(["grunt_heavy"])
	var light := 0
	for i in 40:
		v._since = INF
		said.clear()
		a.hurt.emit(WrestlerController.Sell.LIGHT, _move("strike_jab"))
		light += said.size()
	assert_int(light).is_between(8, 32)


func test_he_does_not_stammer_or_repeat_himself() -> void:
	var scene := _match()
	await get_tree().process_frame
	var v := _voice(scene.get_node("WrestlerA"))
	assert_bool(v.say("grunt_heavy")).is_true()
	assert_bool(v.say("grunt_heavy")).is_false()          # inside MIN_GAP
	var takes := []
	v.said.connect(func(_f: String, s: String) -> void: takes.append(s))
	for i in 24:
		v._since = INF
		v.say("grunt_light")
	for i in range(1, takes.size()):
		assert_str(takes[i]).override_failure_message("the same take twice running").is_not_equal(takes[i - 1])


func test_a_knockdown_ends_on_a_groan_as_he_lands() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var v := _voice(a)
	v.set_process(false)            # driven by hand: headless frames are not real time
	var said := []
	v.said.connect(func(f: String, _s: String) -> void: said.append(f))
	a.knocked_down.emit(a)
	v._process(WrestlerVoice.DOWN_GROAN_DELAY * 0.5)
	assert_array(said).is_empty()                          # not yet: he is still falling
	v._process(WrestlerVoice.DOWN_GROAN_DELAY)
	assert_array(said).contains_exactly(["groan"])


func test_a_burning_man_screams_until_he_is_put_out() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var v := _voice(a)
	v.set_process(false)
	var fire := a.find_child("ManFire", false, false) as ManFire
	var said := []
	v.said.connect(func(f: String, _s: String) -> void: said.append(f))
	fire.ignite()
	assert_bool(v.screaming).is_true()
	assert_array(said).contains_exactly(["burn_scream"])
	# a blow does not cut across the scream
	assert_bool(v.say("grunt_heavy")).is_false()
	# take after take, a breath between: the take ends, he breathes, he screams
	for i in 3:
		v._scream.stop()
		v._process(WrestlerVoice.BURN_BREATH * 0.5)
		v._process(WrestlerVoice.BURN_BREATH)
	assert_int(said.count("burn_scream")).is_equal(4)
	fire.extinguish()
	assert_bool(v.screaming).is_false()
	v._process(WrestlerVoice.BURN_FADE * 0.5)
	assert_float(v._scream.volume_db).is_less(float(WrestlerVoice.LEVEL_DB["burn_scream"]) - 3.0)
	v._process(WrestlerVoice.BURN_FADE)
	assert_bool(v._scream.playing).is_false()
	assert_str(said.back()).is_equal("groan")
	# and no more screams once he is out
	v._process(1.0)
	assert_int(said.count("burn_scream")).is_equal(4)


func test_two_men_do_not_sound_alike_and_a_replay_says_the_same() -> void:
	var picks := [[], []]
	for n in 2:
		var scene := _match()
		await get_tree().process_frame
		var a: WrestlerController = scene.get_node("WrestlerA")
		a.match_seed = 4242
		var v := _voice(a)
		v._seeded = false
		v.said.connect(func(_f: String, s: String) -> void: picks[n].append(s))
		for i in 10:
			v._since = INF
			v.say("grunt_light")
		scene.queue_free()
		await get_tree().process_frame
	assert_array(picks[0]).is_equal(picks[1])
	var roman: WrestlerController = auto_free(WrestlerController.new())
	roman.entrance_style = "roman"
	var cody: WrestlerController = auto_free(WrestlerController.new())
	cody.entrance_style = "cody"
	var rv: WrestlerVoice = auto_free(WrestlerVoice.new())
	rv.wrestler = roman
	var cv: WrestlerVoice = auto_free(WrestlerVoice.new())
	cv.wrestler = cody
	assert_float(rv._pitch()).is_less(cv._pitch())
