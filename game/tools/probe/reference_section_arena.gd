extends ArenaBuilder
## A bounded material-review section for render hosts that cannot fit the hall.
## Uses the real ringside model, materials, placement seed and crowd loader.
## It is labelled in capture metadata and is not a complete arena screenshot.


func _ready() -> void:
	_rng.seed = PLACEMENT_SEED
	_build_ringside()
	var seats: Array[Transform3D] = []
	for row in 2:
		for column in 12:
			seats.append(Transform3D(Basis(Vector3.UP, -PI * 0.5),
					Vector3(7.2 + row * 0.9, FLOOR_Y, (column - 5.5) * 0.65)))
	add_child(_build_chairs("FloorChairs", _chair_mesh(), seats))
	_build_floor_crowd(seats, [])
