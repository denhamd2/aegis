extends GdUnitTestSuite
## Escape pauses a match and offers resume, restart and the title screen; the
## menu after a match offers a rematch and the title screen.

var _scene: Node


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(_scene, Roster.by_id("roman"), Roster.by_id("cody"), 3)
	_scene.entrances = false
	add_child(_scene)


func after_test() -> void:
	get_tree().paused = false
	_scene.queue_free()


func test_escape_pauses_the_match_with_restart_and_title() -> void:
	await get_tree().process_frame
	var press := InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	_scene._unhandled_input(press)
	var menu := _scene.get_node_or_null("PauseMenu") as PostMatchMenu
	assert_object(menu).is_not_null()
	assert_bool(get_tree().paused).is_true()
	assert_array(menu.options).contains([PostMatchMenu.RESUME, PostMatchMenu.RESTART,
			PostMatchMenu.TITLE])
	# A second Escape while it is up does not stack another.
	_scene._unhandled_input(press)
	assert_int(_scene.get_children().filter(func(n: Node) -> bool:
		return n is PostMatchMenu).size()).is_equal(1)
	menu.choose(PostMatchMenu.RESUME)
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	assert_object(_scene.get_node_or_null("PauseMenu")).is_null()


func test_the_menu_after_a_match_offers_a_rematch_and_the_title() -> void:
	var menu := PostMatchMenu.new()
	add_child(menu)
	assert_array(menu.options).contains([PostMatchMenu.REMATCH, PostMatchMenu.TITLE])
	assert_bool(get_tree().paused).is_false()
	menu.free()
