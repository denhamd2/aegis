extends SceneTree
## Run with --path game -s /absolute/path/to/this/script.gd.
func _init() -> void:
	call_deferred("sample")

func sample() -> void:
	CameraSettings.shake_scale()
	CameraSettings.coverage = CameraSettings.Coverage.FIGHT_FOREVER
	var script := load("res://core/camera/match_camera.gd") as Script
	if not script or not script.can_instantiate():
		push_error("Camera script did not compile")
		quit(1)
		return
	var result := {}
	for setting in [CameraSettings.Shake.OFF, CameraSettings.Shake.LOW, CameraSettings.Shake.HIGH]:
		CameraSettings.shake = setting
		var camera = script.new()
		camera.mode = script.Mode.RINGSIDE
		camera.add_trauma(script.TRAUMA_FINISHER)
		var rows := []
		var peak := 0.0
		for tick in 36:
			camera._shake(1.0/60)
			peak = maxf(peak, maxf(absf(camera.h_offset), absf(camera.v_offset)))
			rows.append({"tick": tick+1, "seconds": (tick+1)/60.0,
					"horizontal": camera.h_offset, "vertical": camera.v_offset,
					"remaining_trauma": camera._trauma})
		result[CameraSettings.Shake.keys()[setting]] = {"peak_offset": peak, "samples": rows}
		camera.free()
	var file := FileAccess.open("/tmp/aegis-shake-envelope.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("SHAKE_ENVELOPE /tmp/aegis-shake-envelope.json")
	quit()
