extends GdUnitTestSuite
## The HUD always finds the two men and the referee. The Mac app came up with
## its node-path overrides unresolved (the owner, 19 Oct: "the HUDs are still
## missing on the Mac build"): no health plates for the whole match, in human
## and AI games alike. MatchHUD now defaults its paths and falls back to the
## match root's own children by name.

const MATCH_SCENE := preload("res://scenes/match.tscn")


func _hud(clear_paths: bool) -> MatchHUD:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	var hud := scene.get_node("MatchHUD/Draw") as MatchHUD
	if clear_paths:
		hud.wrestler_a_path = NodePath()
		hud.wrestler_b_path = NodePath()
		hud.referee_path = NodePath()
	add_child(scene)
	return hud


func test_the_hud_links_both_men_and_the_referee() -> void:
	var hud := _hud(false)
	assert_bool(hud.is_resolved()).is_true()
	assert_str(String(hud.wrestler_a.name)).is_equal("WrestlerA")
	assert_str(String(hud.wrestler_b.name)).is_equal("WrestlerB")


func test_it_finds_them_even_with_no_paths() -> void:
	var hud := _hud(true)
	assert_bool(hud.is_resolved()).is_true()
	assert_str(String(hud.wrestler_a.name)).is_equal("WrestlerA")
	assert_str(String(hud.referee.name)).is_equal("MatchReferee")
