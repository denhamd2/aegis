extends GdUnitTestSuite
## The commentary desk, asserted off the shipped ringside model.
##
## The desk is here because the hard camera is: it is the one piece of
## ringside furniture that appears in every broadcast master ever cut, and it
## was missing from a build whose arena, stage, ring and lighting are all
## measured against AEW references. `gauntlet/refs/lighting/`'s
## `aew_low_angle_led_wall.jpg` shows it from the floor and
## `aew_grand_slam_broadcast.png` shows where it sits relative to the ring.
##
## Measured without a renderer, like every other venue suite: the .glb is
## loaded and its parts' bounding boxes are checked against the arithmetic in
## `arena_builder.gd`.

const MODEL := "res://assets/environment/ringside.glb"


func _model() -> Node3D:
	var packed: PackedScene = load(MODEL)
	assert_object(packed).override_failure_message(
		"%s failed to load. Run tools/blender/build_venue.sh ringside." % MODEL
	).is_not_null()
	return packed.instantiate()


func _aabb(root: Node3D, name: String) -> AABB:
	var node := root.find_child(name, true, false) as MeshInstance3D
	assert_object(node).override_failure_message(
		"%s has no '%s' object" % [MODEL, name]).is_not_null()
	return node.get_aabb()


## THE DESK EXISTS, under both the names ArenaBuilder dresses it by. A part
## that goes missing does not crash anything -- it renders in its Blender
## placeholder colour in the middle of a frame every other surface of which is
## solved against a measured target.
func test_the_model_ships_a_commentary_desk() -> void:
	var root := _model()
	for part: String in ["CommentaryDesk", "CommentaryDeskTop"]:
		assert_bool(root.find_child(part, true, false) is MeshInstance3D) \
			.override_failure_message(
				"%s has no '%s'" % [MODEL, part]).is_true()
	root.free()


## IT STANDS BETWEEN THE APRON AND THE BARRICADE, which is the only strip of
## floor it can stand on: inside the barricade because the team works inside
## it, outside the apron because the ring is there.
func test_the_desk_stands_in_the_ringside_walkway() -> void:
	var root := _model()
	var box := _aabb(root, "CommentaryDesk")
	assert_float(box.position.z) \
		.override_failure_message(
			"the desk's near face is at z=%.2f, inside the apron at %.2f"
			% [box.position.z, RingBuilder.APRON_OUT]) \
		.is_greater(RingBuilder.APRON_OUT)
	assert_float(box.end.z) \
		.override_failure_message(
			"the desk's far face is at z=%.2f, past the barricade at %.2f"
			% [box.end.z, ArenaBuilder.BARRICADE_RADIUS]) \
		.is_less(ArenaBuilder.BARRICADE_RADIUS)
	root.free()


## AND ON THE SIDE THE HARD CAMERA SEES IT FROM.
##
## The master is anchored on -X and looks up +X, so its screen-right is +Z --
## the same solve that turned the mat's artwork the right way up. +Z is where
## `aew_grand_slam_broadcast.png` puts the desk: beside the ring at frame
## right, with the entrance stage on -Z at frame left. On -Z it would be in
## the entrance walkway; on -X it would be between the master and the ring.
func test_the_desk_is_on_the_hard_cameras_right() -> void:
	var root := _model()
	var box := _aabb(root, "CommentaryDesk")
	var centre_z: float = (box.position.z + box.end.z) * 0.5
	assert_float(centre_z).is_greater(0.0)
	assert_float(absf((box.position.x + box.end.x) * 0.5)) \
		.override_failure_message(
			"the desk is not centred on the ring's +Z side") \
		.is_less(0.5)
	root.free()


## THE WORKTOP STANDS PROUD OF THE FASCIA. A desk reads as a desk from the
## shadow line under an overhanging top; flush, it is a crate. Same failure
## mode as the turnbuckle connector plate that had to be deleted -- geometry
## that is present and says nothing.
func test_the_worktop_overhangs_the_fascia() -> void:
	var root := _model()
	var fascia := _aabb(root, "CommentaryDesk")
	var top := _aabb(root, "CommentaryDeskTop")
	assert_float(top.size.x) \
		.override_failure_message(
			"the worktop is %.3f across against a %.3f fascia: flush, so it "
			% [top.size.x, fascia.size.x] + "has no lip to cast a line")\
		.is_greater(fascia.size.x)
	assert_float(top.size.z).is_greater(fascia.size.z)
	# And it is a desk, not a table: the top sits at working height and the
	# fascia runs to the floor under it.
	assert_float(fascia.position.y) \
		.is_equal_approx(ArenaBuilder.FLOOR_Y, 0.05)
	root.free()
