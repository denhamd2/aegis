extends SceneTree
## Morph independence/binds, authoritative pose isolation, optics lifecycle,
## saved graphics settings and field-wide bounded turf on the real match.
func _initialize() -> void: call_deferred("_run")

func _part(node: Node, name: String) -> MeshInstance3D:
	return node.find_child(name,true,false) as MeshInstance3D

func _neutral_bounds(mesh: Mesh) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in mesh.get_surface_count():
		var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in points:
			if first: bounds=AABB(point,Vector3.ZERO); first=false
			else: bounds=bounds.expand(point)
	return bounds

func _run() -> void:
	var session := root.get_node("MatchSession")
	session.show_intro = false
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false); game._set_players_physics_enabled(false)
	var john: FootballPlayer
	var des: FootballPlayer = game._away_players[0]
	var other: FootballPlayer
	for actor: FootballPlayer in game._home_players:
		if actor.profile.player_id == &"john_orourke": john=actor
		elif actor.profile.role == "outfield": other=actor
	assert(john != null and other != null)
	# Every Boardeaux alias uses the corrected player groom, independently of
	# the referee, and its fuller neck/jaw has matching hair deformation.
	var player_roots := _part(des,"Hair_Shane_ShortCropRoots")
	assert(player_roots.mesh.get_faces().size()>300, "Player Des lost his side/back hair band")
	for away: FootballPlayer in game._away_players:
		assert(_part(away,"Hair_Shane_ShortCropRoots").mesh==player_roots.mesh)
		var hair := _part(away,"Hair_Shane_ShortCropCards")
		var hair_fullness := hair.find_blend_shape_by_name("Fullness")
		assert(hair_fullness>=0 and is_equal_approx(hair.get_blend_shape_value(hair_fullness),.58))
	var body_package := (load("res://assets/characters/shared/body_shapes.glb") as PackedScene).instantiate()
	var original := (load("res://assets/characters/shared/footballer_base.glb") as PackedScene).instantiate()
	var count := 0
	for node in body_package.find_children("*","MeshInstance3D",true,false):
		var live := _part(john,node.name)
		var shared := _part(other,node.name)
		assert(live != null and shared != null, "Missing body morph part: "+node.name)
		assert(live.mesh == shared.mesh, "Body geometry should be shared")
		var shape := live.find_blend_shape_by_name("Fullness")
		assert(shape >= 0 and is_equal_approx(live.get_blend_shape_value(shape),.42))
		assert(is_zero_approx(shared.get_blend_shape_value(shape)), "A teammate inherited John's shape")
		var athletic := live.find_blend_shape_by_name("AthleticForm")
		assert(athletic >= 0 and is_equal_approx(live.get_blend_shape_value(athletic),1.0))
		assert(is_equal_approx(shared.get_blend_shape_value(athletic),1.0), "Shared athletic corrective lost")
		assert(live.skin.get_bind_count() == node.skin.get_bind_count())
		for bind in live.skin.get_bind_count():
			assert(live.skin.get_bind_name(bind)==node.skin.get_bind_name(bind), "Morph joint order changed")
			assert(live.skin.get_bind_pose(bind).is_equal_approx(node.skin.get_bind_pose(bind)))
		# Mesh AABBs include every morph's extrema; inspect neutral vertices.
		assert(_neutral_bounds(node.mesh).is_equal_approx(_neutral_bounds(_part(original,node.name).mesh)), "Neutral shape changed: "+node.name)
		count += 1
	assert(count>=6)
	assert(is_equal_approx(_part(des,"YBot_Surface").get_blend_shape_value(0),.58))
	assert(_part(john,"Kit_Boots").mesh == _part(other,"Kit_Boots").mesh)
	assert(john.get_node("Visual/Rig").scale.is_equal_approx(other.get_node("Visual/Rig").scale))
	# Temporary rendering output cannot change boot contact or replay samples.
	var visual := john.get_node("Visual") as FootballerVisual
	var pose := visual.pose_presentation
	assert(pose != null and pose.tick_positions.size()==65)
	visual.animation_tree.active=false
	visual.animation_player.play(&"AN_Beechlawn_Sprint")
	visual.animation_player.seek(.12,true)
	pose.previous_positions=pose.tick_positions.duplicate()
	pose.previous_rotations=pose.tick_rotations.duplicate()
	pose.previous_scales=pose.tick_scales.duplicate()
	visual.animation_player.seek(.20,true)
	# Seek is a snap by design; retain .12 as the interpolation predecessor.
	var previous := pose.tick_positions.duplicate()
	visual.animation_player.seek(.26,true)
	pose.previous_positions=previous
	var contact := john._receive_contact_position()
	pose.draw_between(.25)
	assert(john._receive_contact_position().is_equal_approx(contact), "Render pose leaked into contact")
	for bone in 65:
		assert(pose.skeleton.get_bone_pose_position(bone).is_equal_approx(previous[bone].lerp(pose.tick_positions[bone],.25)))
	game.presentation.buffer.sample(1.0/30,true)
	var recorded: PackedFloat32Array=game.presentation.buffer.history[-1].pose
	var actor_index: int=game.presentation.buffer.actors.find(john)
	var offset := 21
	for index in actor_index:
		offset+=8+65*7+game.presentation.buffer.morph_counts[index]
	offset+=8
	for bone in 65:
		assert(Vector3(recorded[offset],recorded[offset+1],recorded[offset+2]).is_equal_approx(pose.tick_positions[bone]), "Replay sampled render interpolation")
		offset+=7
	pose.snap(); pose._capture()
	assert(pose.previous_positions==pose.tick_positions, "Placed actor must not streak")
	# Tight lenses soften only the background; wide shots and exit restore.
	var camera := game.camera_rig.camera as Camera3D
	# LOD material selection must retain individual albedo/tint overrides.
	var temporary := other.profile.duplicate() as FootballerProfile
	temporary.appearance=other.profile.appearance.duplicate()
	temporary.appearance.skin_tint=Color(.97,.93,.91)
	var other_visual := other.get_node("Visual") as FootballerVisual
	other_visual.configure_appearance(temporary)
	var camera_before := camera.global_transform
	for separation in [2.0,20.0,2.0]:
		camera.global_position=other.global_position+Vector3(0,1.6,separation)
		other_visual._update_detail_level()
		assert((_part(other,"Skin_Head").get_active_material(0) as StandardMaterial3D).albedo_color==temporary.appearance.skin_tint,"LOD discarded player skin material override")
	other_visual.configure_appearance(other.profile)
	camera.global_transform=camera_before
	var original_attributes := camera.attributes
	var original_compositor := camera.compositor
	var optics := FootballCameraOptics.for_camera(camera)
	session.cinematic_depth_of_field=true
	optics.shot(&"close",camera.global_position-camera.global_basis.z*3,28,1.0/60)
	assert(camera.attributes==optics.focus and optics.focus.dof_blur_far_distance>3)
	optics.shot(&"wide",Vector3.ZERO,52,1.0/60)
	assert(camera.attributes==original_attributes)
	optics.clear()
	assert(camera.attributes==original_attributes and camera.compositor==original_compositor)
	assert(FootballCameraOptics.shutter_fraction(1.0/60)<.25)
	session.cinematic_depth_of_field=false;session.cinematic_motion_blur=false;session.temporal_aa=true
	assert(session.save_preferences("user://realism_smoke.cfg")==OK)
	session.cinematic_depth_of_field=true;session.cinematic_motion_blur=true;session.temporal_aa=false
	session.load_preferences("user://realism_smoke.cfg")
	assert(not session.cinematic_depth_of_field and not session.cinematic_motion_blur and session.temporal_aa)
	DirAccess.remove_absolute("user://realism_smoke.cfg")
	session.temporal_aa=false;session.cinematic_depth_of_field=true;session.cinematic_motion_blur=true
	# Grass is available on either half, stays bounded and excludes water.
	var grass: PitchGrassDetail=game.grass_detail
	for location in [Vector3(-24,0,-12),Vector3(24,0,12)]:
		grass._queue_cells(location)
		while not grass._pending.is_empty(): grass._build_cell(grass._pending.pop_front())
		grass._queue_mid(location)
		assert(grass.tuft_count()>1000 and grass.draw_triangle_count()<=grass.triangle_budget)
		for chunk in grass.chunks.values():
			for index in range(0,chunk.multimesh.visible_instance_count,91):
				var point: Vector3=chunk.multimesh.get_instance_transform(index).origin
				assert(absf(point.y-PitchSurface.height_at(point.x,point.z))<.003)
				assert(grass.surface.sample_at(point).y<=.15)
	camera.position=Vector3(0,18,-28);camera.look_at(Vector3.ZERO)
	camera.fov=70
	var wide_count := grass._mid_keys(camera.global_position,camera).size()
	camera.fov=20
	assert(grass._mid_keys(camera.global_position,camera).size()>wide_count,"Grass detail must follow projected size, not a fixed 4m camera-height cutoff")
	body_package.free();original.free();game.free()
	print("REALISM_SYSTEMS PASS: shared physique/binds, render/contact/replay isolation, optics restoration, graphics preferences and field-wide bounded turf")
	quit()
