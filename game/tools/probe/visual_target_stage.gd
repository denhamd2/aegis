extends ArenaBuilder
## The shipped stage and truss for bounded material review on small render hosts.
## Capture metadata labels this scope; it is not a complete arena capture.


func _ready() -> void:
	_rng.seed = PLACEMENT_SEED
	_build_entrance_set()
	_build_overhead_rig()
