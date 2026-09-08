extends GdUnitTestSuite
## The landing screen: the roster it offers, the phase machine a player walks,
## and the wiring it hands to a match.
##
## What it looks like is not assertable and was checked by rendering all five
## phases with tools/probe/title_shots.tscn. What is assertable is that the
## screen is reachable, that the two men it offers actually exist, and that a
## pick becomes the right model, colourway, name and control on the wrestler
## the match builds.
##
## Nothing here loads a character .glb. TitleScreen.configure_match() is
## exercised against stub roster entries pointing at an empty scene, and the
## real entries are checked with ResourceLoader.exists() -- roman_reigns.glb
## alone is 52MB, which is the same reason scenes/play.tscn exists instead of
## the models being set on match.tscn.

const MATCH_SCENE := preload("res://scenes/match.tscn")
const TITLE_SCENE := preload("res://scenes/title.tscn")
## An empty Node3D scene, stood in for a character model.
const STUB_MODEL := "res://scenes/main.tscn"

func _screen() -> TitleScreen:
	var root: CanvasLayer = auto_free(TITLE_SCENE.instantiate())
	add_child(root)
	return root.get_node("Draw")

func _stub_entry(id: String) -> Roster.Entry:
	return Roster.Entry.new(id, "STUB", id.to_upper(), "TAGLINE", STUB_MODEL,
			Color(0.1, 0.2, 0.3), Color(0.4, 0.5, 0.6), 0.5, 0.5, 0.5)

## The screen is only the landing screen if the game actually boots into it.
func test_the_title_screen_is_the_main_scene() -> void:
	assert_str(ProjectSettings.get_setting("application/run/main_scene")) \
			.is_equal("res://scenes/title.tscn")

func test_the_screen_covers_the_whole_viewport() -> void:
	var screen := _screen()
	assert_float(screen.anchor_right).is_equal(1.0)
	assert_float(screen.anchor_bottom).is_equal(1.0)

## Two wrestlers, because two character models exist. A third entry here with
## no model behind it would be a menu option that crashes on launch.
func test_every_roster_entry_has_a_model_scene_that_exists() -> void:
	var entries := Roster.entries()
	assert_int(entries.size()).is_equal(2)
	for entry: Roster.Entry in entries:
		assert_bool(ResourceLoader.exists(entry.model_scene)) \
				.override_failure_message(
					"roster entry %s points at a missing scene: %s"
						% [entry.id, entry.model_scene]).is_true()
		assert_str(entry.display_name()).is_not_empty()

func test_the_roster_is_roman_and_cody() -> void:
	var ids: Array = []
	for entry: Roster.Entry in Roster.entries():
		ids.append(entry.id)
	assert_array(ids).contains(["roman", "cody"])
	assert_str(Roster.by_id("roman").display_name()).is_equal("ROMAN REIGNS")
	assert_str(Roster.by_id("cody").display_name()).is_equal("CODY RHODES")

## FIGHT is the first row, so the screen opens on the option that starts a
## match rather than on a submenu.
func test_fight_opens_the_wrestler_select() -> void:
	var screen := _screen()
	assert_int(screen.phase).is_equal(TitleScreen.Phase.TITLE)
	screen._accept()
	assert_int(screen.phase).is_equal(TitleScreen.Phase.SELECT)
	assert_array(screen.picks).is_empty()

func test_two_picks_fill_both_slots_and_start_the_walk_in() -> void:
	var screen := _screen()
	screen._accept()
	screen.cursor = 0
	screen._accept()
	assert_int(screen.picks.size()).is_equal(1)
	# The cursor moves off the man player 1 took, so a second Enter is a real
	# match rather than a mirror by accident.
	assert_int(screen.cursor).is_equal(1)
	screen._accept()
	assert_int(screen.picks.size()).is_equal(2)
	assert_int(screen.phase).is_equal(TitleScreen.Phase.VERSUS)
	assert_str((screen.picks[0] as Roster.Entry).id).is_equal("roman")
	assert_str((screen.picks[1] as Roster.Entry).id).is_equal("cody")

## A mirror match is legal -- the cursor is parked elsewhere, not blocked.
func test_the_same_wrestler_can_be_picked_twice() -> void:
	var screen := _screen()
	screen._accept()
	screen.cursor = 1
	screen._accept()
	screen.cursor = 1
	screen._accept()
	assert_str((screen.picks[0] as Roster.Entry).id).is_equal("cody")
	assert_str((screen.picks[1] as Roster.Entry).id).is_equal("cody")

## Backing out unpicks one wrestler at a time and then leaves the select --
## a player who mis-picks player 1 must not be stuck with him.
func test_back_undoes_one_pick_then_leaves_select() -> void:
	var screen := _screen()
	screen._accept()
	screen._accept()
	assert_int(screen.picks.size()).is_equal(1)
	screen._back()
	assert_int(screen.picks.size()).is_equal(0)
	assert_int(screen.phase).is_equal(TitleScreen.Phase.SELECT)
	screen._back()
	assert_int(screen.phase).is_equal(TitleScreen.Phase.TITLE)

func test_controls_opens_and_closes() -> void:
	var screen := _screen()
	screen.menu_index = 1
	screen._accept()
	assert_int(screen.phase).is_equal(TitleScreen.Phase.CONTROLS)
	screen._back()
	assert_int(screen.phase).is_equal(TitleScreen.Phase.TITLE)

## The controls card reads the InputMap rather than a copy of it, so a rebind
## in project.godot cannot leave the card lying.
func test_the_controls_card_reads_the_live_input_map() -> void:
	var screen := _screen()
	assert_str(screen._binding_labels(["strike"])).is_equal("J")
	assert_str(screen._binding_labels(["move_up", "move_left", "move_down",
			"move_right"])).is_equal("W A S D")
	# A modifier-only binding must not render as a chord prefix ("CTRL+").
	assert_str(screen._binding_labels(["run"])).not_contains("+")

## The wiring the whole screen exists to produce.
func test_configure_match_puts_the_picks_into_the_match() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	var player := _stub_entry("player")
	var opponent := _stub_entry("opponent")
	TitleScreen.configure_match(scene, player, opponent, 4242)

	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	# Player 1 drives WrestlerA; the man he picked to face is on the AI.
	assert_bool(a.is_ai).is_false()
	assert_bool(b.is_ai).is_true()
	assert_str(a.display_name).is_equal("STUB PLAYER")
	assert_str(b.display_name).is_equal("STUB OPPONENT")
	assert_object(a.character_model_scene).is_equal(load(STUB_MODEL))
	assert_object(b.character_model_scene).is_equal(load(STUB_MODEL))
	assert_that(a.attire_accent).is_equal(player.attire_accent)
	assert_int(scene.match_seed).is_equal(4242)

## The HUD plate is the only place a player is told who he is fighting, and
## the node names ("WrestlerA") are not that.
##
## Asserted on the wrestlers the HUD holds rather than by rendering it: what
## _draw() puts on the plate is the same string, and a drawn frame is not
## something a suite can read back.
func test_the_hud_plate_reads_the_picked_name() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	TitleScreen.configure_match(scene, _stub_entry("player"),
			_stub_entry("opponent"), 1)
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	hud.wrestler_a = hud.get_node(hud.wrestler_a_path)
	assert_str(hud.wrestler_a.display_name).is_equal("STUB PLAYER")

## An unconfigured match -- every other suite's fixture, and the probes'
## scene -- keeps falling back to the node name.
func test_a_plain_match_has_no_display_name() -> void:
	var plain: Node = auto_free(MATCH_SCENE.instantiate())
	assert_str((plain.get_node("WrestlerA") as WrestlerController).display_name) \
			.is_empty()
