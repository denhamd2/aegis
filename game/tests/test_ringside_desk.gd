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


## IT HAS ITS OWN AREA: a clear lane of floor between it and the apron (it
## first stood 0.84 m off the apron, in the way of anyone working outside),
## and the bay's barricade behind its chairs, not through them.
func test_the_desk_stands_back_in_its_bay() -> void:
	var root := _model()
	var box := _aabb(root, "CommentaryDesk")
	assert_float(box.position.z - RingBuilder.APRON_OUT) \
		.override_failure_message(
			"the desk's near face is %.2f m off the apron; it needs a clear lane"
			% (box.position.z - RingBuilder.APRON_OUT)) \
		.is_greater(3.5)
	assert_float(box.position.x).is_greater(-ArenaBuilder.DESK_BAY_BACK)
	assert_float(box.end.x).is_less(ArenaBuilder.DESK_BAY_BACK)
	# Chairs and all, inside the bay's barricade.
	var kit := _aabb(root, "CommentaryKit")
	assert_float(kit.end.z).is_less(ArenaBuilder.DESK_BAY_Z - 0.07)
	assert_float(kit.position.z).is_greater(RingBuilder.APRON_OUT + 3.0)
	root.free()


## AND ON THE SIDE THE HARD CAMERA SEES IT FROM.
##
## The master is anchored on -X and looks up +X, so its screen-right is +Z --
## the same solve that turned the mat's artwork the right way up. +Z is where
## `aew_grand_slam_broadcast.png` puts the desk: beside the ring at frame
## right, and the owner's AEW arena still puts it centred on the side
## opposite the stage, against the barricade.
func test_the_desk_is_on_the_hard_cameras_right() -> void:
	var root := _model()
	var box := _aabb(root, "CommentaryDesk")
	var centre_z: float = (box.position.z + box.end.z) * 0.5
	assert_float(centre_z).is_greater(0.0)
	assert_float((box.position.x + box.end.x) * 0.5) \
		.is_equal_approx(ArenaBuilder.DESK_X, 0.1)
	root.free()


## The bay's barricade is in the model: the barricades now reach back to it.
func test_the_barricade_steps_back_round_the_bay() -> void:
	var root := _model()
	var box := _aabb(root, "Barricades")
	assert_float(box.end.z).is_greater(ArenaBuilder.DESK_BAY_Z)
	assert_float(box.position.z).is_less(-ArenaBuilder.BARRICADE_RADIUS + 0.1)
	root.free()


## No ringside chair stands in the bay or its walkway.
func test_no_floor_seat_in_the_desk_bay() -> void:
	var arena: ArenaBuilder = auto_free(ArenaBuilder.new())
	add_child(arena)
	var chairs := arena.find_child("FloorChairs", true, false) as MultiMeshInstance3D
	assert_object(chairs).is_not_null()
	for i in chairs.multimesh.instance_count:
		var at := chairs.multimesh.get_instance_transform(i).origin
		assert_bool(ArenaBuilder.in_desk_bay(at)) \
			.override_failure_message("a chair at %s is in the desk's bay" % at) \
			.is_false()


## The barricade's faces follow the same panels the model is built from: an
## LED face on every long-side panel, the logo on the four corners.
func test_barricade_faces_follow_the_panels() -> void:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	var leds := 0
	var corners := 0
	for child in rig.get_children():
		if String(child.name).begins_with("BarricadeLed"):
			leds += 1
		elif String(child.name).begins_with("BarricadeCorner"):
			corners += 1
	var want := 0
	for panel: Array in ArenaBuilder.barricade_panels():
		if ArenaLighting.barricade_face(panel) == "led":
			want += 1
	assert_int(leds).is_equal(want)
	assert_int(want).is_equal(8)
	assert_int(corners).is_equal(4)
