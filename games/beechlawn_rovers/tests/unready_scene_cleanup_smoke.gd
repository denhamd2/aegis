extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var packed:=load("res://scenes/training_ground.tscn") as PackedScene
	var before:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for index in 4:
		var fixture:=packed.instantiate()
		fixture.free()
	var after:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("UNREADY_SCENE_ORPHANS before=",before," after=",after)
	assert(after==before,"An asset-review source must not leak an unparented restart controller")
	quit()
