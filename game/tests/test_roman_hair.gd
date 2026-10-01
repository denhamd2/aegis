extends GdUnitTestSuite
## Roman's hair moves (RomanModel._add_hair_springs): the rig's own hair
## chains are driven by a SpringBoneSimulator3D, so the lengths off the back
## of his head swing a few centimetres with a walk and never through his back.

var _model: Node3D
var _worn: Skeleton3D


func before_test() -> void:
	_model = (load("res://scenes/roman_model.tscn") as PackedScene).instantiate()
	add_child(_model)
	for sk: Skeleton3D in _model.find_children("", "Skeleton3D", true, false):
		if sk.find_bone("J_Hair_b") >= 0:
			_worn = sk


func after_test() -> void:
	_model.queue_free()


func test_every_hair_chain_is_simulated_from_the_nape() -> void:
	var sim := _worn.get_node("HairSprings") as SpringBoneSimulator3D
	assert_int(sim.get_setting_count()).is_equal(35)
	for k in sim.get_setting_count():
		var root := sim.get_root_bone(k)
		# The slicked top stays on the scalp: nothing above the nape swings.
		assert_float(_worn.get_bone_global_rest(root).origin.y).is_less(RomanModel.HAIR_SPRING_FROM_Y)
		assert_int(sim.get_joint_count(k)).is_greater(2)


func test_the_hair_swings_with_a_walk_and_stays_off_his_back() -> void:
	var player := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play("Walk")
	var head := _worn.find_bone("J_Head")
	var tip := _worn.find_bone("Hair_b00_10")
	var rest := _worn.get_bone_global_rest(head).affine_inverse() * _worn.get_bone_global_rest(tip).origin
	var sim := _worn.get_node("HairSprings") as SpringBoneSimulator3D
	var swing := [0.0, 1.0, 0]   # the largest swing; the deepest the tip went into a collider
	_worn.skeleton_updated.connect(func():
		# Past the first updates, before the clip and the springs have run.
		swing[2] += 1
		if swing[2] < 10:
			return
		var rel := _worn.get_bone_global_pose(head).affine_inverse() * _worn.get_bone_global_pose(tip).origin
		swing[0] = maxf(swing[0], rel.distance_to(rest))
		var p := _worn.global_transform * _worn.get_bone_global_pose(tip).origin
		for c in sim.get_children():
			swing[1] = minf(swing[1], _clearance(c, p)))
	for i in 150:
		await get_tree().process_frame
	# It moves -- not a helmet -- and not wildly.
	assert_float(swing[0]).is_between(0.015, 0.2)
	# The tip lies on his back, never through him (a centimetre of give).
	assert_float(swing[1]).is_greater(-0.01)


## How far p is outside collider c (negative: inside it).
static func _clearance(c: Node3D, p: Vector3) -> float:
	var scale := c.global_transform.basis.get_scale().x
	var local := c.global_transform.affine_inverse() * p
	if c is SpringBoneCollisionCapsule3D:
		var cap := c as SpringBoneCollisionCapsule3D
		var half := maxf(cap.height * 0.5 - cap.radius, 0.0)
		local.y = local.y - clampf(local.y, -half, half)
		return (local.length() - cap.radius) * scale
	if c is SpringBoneCollisionSphere3D:
		return (local.length() - (c as SpringBoneCollisionSphere3D).radius) * scale
	return 1.0
