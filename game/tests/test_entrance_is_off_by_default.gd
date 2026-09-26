extends GdUnitTestSuite
## The guard on the entrance staying off everywhere a measurement is taken.
##
## This suite exists because of a real leak, not as a precaution. The first
## version of the entrance set `MatchSetup.play_entrances` inside
## `TitleScreen.configure_match()`, on the belief that the title screen was its
## only caller. It is not: NINE probes call it -- ladder_probe, pin_probe,
## feel_probe, reachability_probe, floating_probe, arena_shot, exchange_shot and
## both title probes -- because it is the single description of "what a picked
## wrestler means" and they all want that. So every one of them walked its
## wrestlers down the ramp before fighting, and `ladder_probe --seeds 1,2,3` came
## back with seed 1 at 5119 ticks against its recorded 914, ENTRANCE in both
## state histograms, and a different number of strikes landed.
##
## `ARCHITECTURE.md` makes determinism a hard requirement and the README's
## measurements are all stated as byte-identical run to run, so that leak
## invalidated every number in the file at once. It was caught by diffing the
## probe's own output against a baseline, which is the only instrument that could
## have caught it -- nothing about the match was broken, it was just no longer
## the same match.
##
## Hence the split the tests below pin: `configure_match()` is what a MATCH
## needs, `configure_entrances()` is what the FRONT END adds, and only
## `TitleScreen._launch()` calls the second one.
##
## No character .glb is loaded here, for the reason test_title_screen.gd gives:
## roman_reigns.glb alone is 52MB.

const MATCH_SCENE := preload("res://scenes/match.tscn")
## An empty Node3D scene, stood in for a character model.
const STUB_MODEL := "res://scenes/main.tscn"

func _stub_entry(id: String) -> Roster.Entry:
	return Roster.Entry.new(id, "STUB", id.to_upper(), "TAGLINE", STUB_MODEL,
			Color(0.1, 0.2, 0.3), Color(0.4, 0.5, 0.6), 0.5, 0.5, 0.5)

## Not added to the tree: _ready() is what would start the walk, and this suite
## is about the flag's value before anything runs.
func _unentered_match() -> Node:
	return auto_free(MATCH_SCENE.instantiate())


func test_a_bare_match_scene_plays_no_entrance() -> void:
	assert_bool(_unentered_match().play_entrances).is_false()


## The heart of it. configure_match() is the call nine probes make, and it must
## leave the flag alone.
func test_configure_match_does_not_turn_entrances_on() -> void:
	var scene := _unentered_match()
	TitleScreen.configure_match(scene, _stub_entry("a"), _stub_entry("b"), 7)
	assert_bool(scene.play_entrances).is_false()
	assert_array(scene.entrance_entries).is_empty()


func test_configure_entrances_turns_them_on_and_names_the_pair() -> void:
	var scene := _unentered_match()
	var player := _stub_entry("a")
	var opponent := _stub_entry("b")
	TitleScreen.configure_entrances(scene, player, opponent)
	assert_bool(scene.play_entrances).is_true()
	# Player first, because the walk order and the plate both read this.
	assert_array(scene.entrance_entries).is_equal([player, opponent])


## scenes/play.tscn is what every probe and tools/capture/run_capture.sh point
## at. If an entrance ever appears there, the capture pipeline is recording a
## walk it thinks is a match.
func test_the_probe_and_capture_scene_plays_no_entrance() -> void:
	var play: Node = auto_free(load("res://scenes/play.tscn").instantiate())
	var setup: Node = play if "play_entrances" in play \
			else play.find_child("Match", true, false)
	assert_object(setup).is_not_null()
	assert_bool(setup.play_entrances).is_false()


## The director is a node on the scene whatever the flag says; what it must not
## do is act on its own. Nothing in its _ready() starts a walk -- MatchSetup
## calls run() -- so an un-configured scene has an idle director on it.
func test_the_director_does_not_start_itself() -> void:
	var scene := _unentered_match()
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	assert_object(director).is_not_null()
	assert_bool(director.is_running()).is_false()


## The entrance camera must never take the frame from MatchCamera on a path that
## measures something. It is `current = false` in its own _ready().
func test_the_entrance_camera_is_not_current_on_a_bare_scene() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var entrance_camera: Camera3D = scene.get_node("EntranceCamera")
	var match_camera: Camera3D = scene.get_node("MatchCamera")
	assert_bool(entrance_camera.current).is_false()
	assert_bool(match_camera.current).is_true()
