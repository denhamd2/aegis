extends GdUnitTestSuite
## The hard camera cuts to a set-piece landing whether it breaks (table) or
## stays in place (tacks and barbed wire), then returns to its master shot.



var _coverage_before: int
var _cuts_before: bool


func before_test() -> void:
	_coverage_before = CameraSettings.coverage
	_cuts_before = CameraSettings.cuts


func after_test() -> void:
	CameraSettings.coverage = _coverage_before
	CameraSettings.cuts = _cuts_before


func test_nonbreaking_set_piece_landing_gets_the_broadcast_cut() -> void:
	CameraSettings.coverage = CameraSettings.Coverage.BROADCAST
	CameraSettings.cuts = true
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	add_child(scene)
	auto_free(scene)
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var who: WrestlerController = scene.get_node("WrestlerA")
	var piece := WeaponActor.make(WeaponCatalog.by_id(&"thumbtacks"))
	add_child(piece)
	camera.mode = MatchCamera.Mode.HARD_CAM
	camera._held = MatchCamera.MIN_SHOT
	camera._on_set_piece_landed(who, piece, false)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.EVENT_CUT)
	assert_int(camera._cut).is_equal(MatchCamera.Cut.TABLE)
	assert_object(camera._cut_subject).is_same(who)
	var chair := WeaponActor.make(WeaponCatalog.by_id(&"steel_chair"))
	add_child(chair)
	camera.mode = MatchCamera.Mode.HARD_CAM
	camera._held = MatchCamera.MIN_SHOT
	camera._on_set_piece_landed(who, chair, false)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)
