extends GdUnitTestSuite
## Real role-path rewriting and shared-resource isolation with tiny clips.

func make_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 10.0
	for role in ["WrestlerA", "WrestlerB"]:
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, NodePath(role))
		anim.position_track_insert_key(pos_track, 0.0, Vector3(.4 if role == "WrestlerA" else -.4, .2 if role == "WrestlerA" else 1.0, 0))
		var rot_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, NodePath(role))
		anim.rotation_track_insert_key(rot_track, 0.0, Quaternion.from_euler(Vector3(.3 if role == "WrestlerA" else .8, .5, .2)))
	return anim

func make_pair(label: String, library: AnimationLibrary) -> Dictionary:
	var container := Node3D.new()
	container.name = label
	add_child(container)
	var a := CharacterBody3D.new()
	a.name = "WrestlerA"
	container.add_child(a)
	var b := CharacterBody3D.new()
	b.name = "WrestlerB"
	container.add_child(b)
	var rig := GrappleRig.new()
	rig.name = "GrappleRig"
	container.add_child(rig)
	var player := AnimationPlayer.new()
	rig.add_child(player)
	player.root_node = NodePath("../..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("", library)
	rig.animation_player = player
	return {"container": container, "a": a, "b": b, "rig": rig, "player": player}

func test_authored_roles_survive_slot_swap_height_and_rotated_frames() -> void:
	var index := 0
	for yaw: float in [0.0, .85]:
		for lift: float in [1.0, 1.12, 1.5]:
			for swapped: bool in [false, true]:
				var library := AnimationLibrary.new()
				var source := make_anim()
				library.add_animation("probe", source)
				var p := make_pair("Pair%d" % index, library)
				index += 1
				var frame := Transform3D(Basis(Vector3.UP,yaw),Vector3(1.7,.1,-.8))
				p.rig._pair_transform = frame
				p.rig._lift_scale = lift
				p.rig._play_retargeted("probe",p.b if swapped else p.a,p.a if swapped else p.b)
				var baked: Animation = p.player.get_animation("probe")
				var physical_attacker: Node3D = p.b if swapped else p.a
				var physical_defender: Node3D = p.a if swapped else p.b
				for track in [0, 1]:
					assert_object(p.container.get_node(baked.track_get_path(track))).is_same(physical_attacker)
				for track in [2, 3]:
					assert_object(p.container.get_node(baked.track_get_path(track))).is_same(physical_defender)
				assert_vector(baked.track_get_key_value(0,0)).is_equal_approx(frame*Vector3(.4,.2,0),Vector3.ONE*.00001)
				assert_vector(baked.track_get_key_value(2,0)).is_equal_approx(frame*Vector3(-.4,lift,0),Vector3.ONE*.00001)
				var arot: Quaternion = baked.track_get_key_value(1,0)
				var drot: Quaternion = baked.track_get_key_value(3,0)
				assert_float(arot.angle_to(Quaternion(frame.basis)*Quaternion.from_euler(Vector3(.3,.5,.2)))).is_less(.001)
				assert_float(drot.angle_to(Quaternion(frame.basis)*GrappleRig.defender_root_yaw(Quaternion.from_euler(Vector3(.8,.5,.2))))).is_less(.001)
				assert_object(library.get_animation("probe")).is_same(source)
				p.rig._restore_original_animation()
				p.container.free()

func test_overlapping_rigs_cannot_retarget_each_others_source_or_restore_it_wrongly() -> void:
	var library := AnimationLibrary.new()
	var source := make_anim()
	library.add_animation("probe",source)
	var a := make_pair("First",library)
	var b := make_pair("Second",library)
	a.rig._pair_transform=Transform3D(Basis(),Vector3(3,0,0))
	b.rig._pair_transform=Transform3D(Basis(),Vector3(-3,0,0))
	a.rig._play_retargeted("probe",a.a,a.b)
	b.rig._play_retargeted("probe",b.a,b.b)
	var first: Animation=a.player.get_animation("probe")
	var second: Animation=b.player.get_animation("probe")
	assert_vector(first.track_get_key_value(0,0)).is_equal_approx(Vector3(3.4,.2,0),Vector3.ONE*.00001)
	assert_vector(second.track_get_key_value(0,0)).is_equal_approx(Vector3(-2.6,.2,0),Vector3.ONE*.00001)
	a.rig._restore_original_animation()
	assert_object(a.player.get_animation("probe")).is_same(source)
	assert_object(b.player.get_animation("probe")).is_same(second)
	b.rig._restore_original_animation()
	assert_object(b.player.get_animation("probe")).is_same(source)
	assert_object(library.get_animation("probe")).is_same(source)
	assert_vector(source.track_get_key_value(0,0)).is_equal_approx(Vector3(.4,.2,0),Vector3.ONE*.00001)
	a.container.free()
	b.container.free()

func test_ladder_entry_height_belongs_to_the_attacker_in_either_slot() -> void:
	for swapped: bool in [false, true]:
		var library := AnimationLibrary.new()
		library.add_animation("probe",make_anim())
		var p := make_pair("Ladder",library)
		p.rig._lift_scale = 1.12
		p.rig._attacker_start_height_offset = .7
		p.rig._play_retargeted("probe",p.b if swapped else p.a,p.a if swapped else p.b)
		var baked: Animation = p.player.get_animation("probe")
		assert_vector(baked.track_get_key_value(0,0)).is_equal_approx(Vector3(.4,.2+.7*GrappleRig.ladder_dive_lift(0),0),Vector3.ONE*.00001)
		assert_vector(baked.track_get_key_value(2,0)).is_equal_approx(Vector3(-.4,1.12,0),Vector3.ONE*.00001)
		p.container.free()
