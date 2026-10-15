class_name CrowdChants
extends Node
## Match clock retained for commentary timing. Generated crowd chants and
## count shouts were removed; match events still call these no-op hooks so
## crowd responses can be replaced later with suitable recorded audio.

var clock := 0.0
var _bell_at := -1.0


func tick(delta: float, _excitement: float) -> void:
	clock += delta


func bell() -> void:
	_bell_at = clock


func match_time() -> float:
	return clock - _bell_at if _bell_at >= 0.0 else -1.0


func moved(_favor: float, _pop: float) -> void:
	pass


func fired_up(_favor: float) -> void:
	pass


func kicked_out(_count: int) -> void:
	pass


func table_set_up() -> void:
	pass


func count(_number: int, _sfx: SfxPool) -> void:
	pass


func match_over(_winner_favor: float) -> void:
	pass


func entrance(_style: String) -> void:
	pass
