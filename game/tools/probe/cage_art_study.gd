extends "res://tools/probe/weapon_shot.gd"
## Isolated Blender-authored shipping cage/cell visual and moving-parts review.

func _ready() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	var cell := "--cell" in OS.get_cmdline_user_args()
	_out = "/tmp/aegis-caged-art/cell" if cell else "/tmp/aegis-caged-art/cage"
	_settle = 8
	DirAccess.make_dir_recursive_absolute(_out)
	_set_stage()
	var cage := CageBuilder.build(self, CageBuilder.Spec.hell_in_a_cell() if cell \
			else CageBuilder.Spec.steel_cage())
	cage.position.y = -cage.spec.base_y
	if cell:
		cage.set_padlock(true)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.fov = 45
	var half := cage.spec.half
	var h := cage.spec.top_y - cage.spec.base_y
	cam.look_at_from_position(Vector3(half * 2.15, h * 1.45, half * 2.15), Vector3(0, h * .45, 0))
	await _grab(_out.path_join("overall.png"))
	if "--quick" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	cage.set_padlock(false)
	cage.set_door_open(.5)
	var axis := cage.spec.door_axis
	var focus := cage.door_centre() + Vector3.UP * (-cage.spec.base_y + cage.spec.door_height * .5)
	cam.look_at_from_position(focus + axis * 3.8 + Vector3.UP * .6 \
			+ CageBuilder.lateral_of(axis) * 1.5, focus)
	await _grab(_out.path_join("door_half.png"))
	cage.set_door_open(1.0)
	await _grab(_out.path_join("door_open.png"))
	var records := {"blender_model": cage.get_meta("blender_visuals", ""),
		"triangles": _triangles(cage), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "native_performance": false}
	FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	get_tree().quit()
