extends SceneTree
## Native production preview; no generated promotional substitutions.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var output:="/tmp/supporter-review";var index:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--index="):index=int(arg.trim_prefix("--index="))
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();world.add_child(env)
	env.environment=load("res://data/presentation/kilmore_daylight.tres").duplicate(true)
	var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=.8;sun.shadow_enabled=true
	var floor:=MeshInstance3D.new();world.add_child(floor);var plane:=PlaneMesh.new();plane.size=Vector2(8,8);floor.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.12,.18,.13);floor.material_override=mat
	var model:Node3D=(load("res://assets/characters/supporters/fan_%02d.glb"%index) as PackedScene).instantiate();world.add_child(model)
	var photo:=StandardMaterial3D.new();photo.albedo_texture=load("res://assets/characters/supporters/fan_%02d.png"%index);photo.roughness=.86;photo.cull_mode=BaseMaterial3D.CULL_DISABLED
	for m in model.find_children("*","MeshInstance3D",true,false):m.material_override=photo
	var chair:Node3D=(load("res://assets/environment/rovers_arena/arena_seat.glb") as PackedScene).instantiate();world.add_child(chair);chair.rotation.y=PI
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2.5,1.3,3.0);camera.look_at(Vector3(0,.9,0));camera.fov=33;camera.make_current()
	var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	DirAccess.make_dir_recursive_absolute(output)
	for kind in ["Seated","Rise","Cheer","Clap","Sit","Stand"]:
		var clip:String="Fan_"+kind
		if not player.has_animation(clip):
			for n in player.get_animation_list():
				if String(n).ends_with(clip):clip=n
		player.play(clip);player.seek(player.get_animation(clip).length*.5,true);player.pause()
		for frame in 2:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(kind+".png"))==OK)
		print("SUPPORTER_REVIEW ",kind)
	print("SUPPORTER_REVIEW_COMPLETE ",player.get_animation_list())
	world.queue_free()
	await process_frame
	quit()
