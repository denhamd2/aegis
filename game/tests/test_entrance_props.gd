extends GdUnitTestSuite
## The props that are worn for Roman's entrance and carried to the timekeeper.

const MATCH := "res://scenes/match.tscn"


func test_roman_title_fits_snugly_when_worn_and_returns_to_full_size_held() -> void:
	var scene: Node = load(MATCH).instantiate()
	var pair := Roster.pair_from_spec("roman,cody")
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = false
	add_child(scene)
	auto_free(scene)
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var props := EntranceProps.dress(roman, true)
	await get_tree().process_frame
	props._follow()
	var worn_basis := props._title.global_basis
	props._title_state = "held"
	props._follow()
	var held_basis := props._title.global_basis
	# Determinant measures volume scale independent of the pelvis rotation and
	# avoids decomposition artifacts from the Roman model's nonuniform scale.
	assert_float(worn_basis.determinant() / held_basis.determinant()) \
			.is_equal_approx(EntranceProps.WORN_TITLE_SCALE.x \
			* EntranceProps.WORN_TITLE_SCALE.z, 0.001)
