extends GdUnitTestSuite
## After the rating, the player chooses what next (owner request): rematch,
## change wrestlers, the title screen, and quit on desktop.


func after_test() -> void:
	TitleScreen.resume_select = false
	TitleScreen.last_picks = []


func test_the_menu_offers_rematch_change_title() -> void:
	var menu: PostMatchMenu = auto_free(PostMatchMenu.new())
	add_child(menu)
	assert_array(menu.options).contains([PostMatchMenu.REMATCH, PostMatchMenu.CHANGE, PostMatchMenu.TITLE])
	assert_str(menu.options[0]).is_equal(PostMatchMenu.REMATCH)


func test_no_rematch_without_a_launched_match() -> void:
	TitleScreen.last_picks = []
	assert_bool(TitleScreen.rematch(get_tree())).is_false()


func test_change_wrestlers_opens_the_title_on_the_select() -> void:
	TitleScreen.resume_select = true
	var title: Node = auto_free((load("res://scenes/title.tscn") as PackedScene).instantiate())
	add_child(title)
	var screen: TitleScreen = title.get_node("Draw")
	assert_int(screen.phase).is_equal(TitleScreen.Phase.SELECT)
	assert_bool(TitleScreen.resume_select).is_false()
