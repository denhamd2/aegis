class_name RampFollowSpot
extends Node3D
## A follow spot on whoever fights up the ramp (the owner, 20 Oct: "When the
## wrestlers go up the ramp during the match it stays dark. There should be a
## spotlight following them"). Nothing in the arena rig lights the ramp --
## nothing in a match used to happen there -- so a man who took the fight to
## the stage did it in silhouette.
##
## One per man, the entrance's own long-throw spot (EntranceDirector
## FOLLOW_SPOT_AT, in the rafters at the far end) plus a soft key from the
## front truss above him, faded in as he goes past the ramp's foot and out as
## he comes back to ringside. Presentation only: it reads positions and
## writes lights, nothing the match or the replay sees.
##
## Off while the entrances run (the wrestlers' physics is frozen then): the
## director has its own.

## Past the ramp's foot (the barricade) by this much, he is on the ramp.
const ON_RAMP_PAST := 1.0
## The spot at match level: the entrance's is 32, with the house down. The
## house is up in a match, so less does it.
const SPOT_ENERGY := 22.0
## The soft key from the front truss: above him, toward the ring.
const KEY_ENERGY := 4.0
const KEY_UP := 4.5
const KEY_AHEAD := 3.0
const KEY_ANGLE := 30.0
const KEY_RANGE := 10.0
## Seconds to fade fully in or out.
const FADE := 0.5

var _men: Array[WrestlerController] = []
var _spots: Array[SpotLight3D] = []
var _keys: Array[SpotLight3D] = []
var _level: Array[float] = []


func watch(wrestlers: Array) -> void:
	for w: WrestlerController in wrestlers:
		_men.append(w)
		var spot := SpotLight3D.new()
		spot.name = "RampSpot%d" % _spots.size()
		spot.light_color = Color(1.0, 0.96, 0.90)
		spot.spot_angle = EntranceDirector.FOLLOW_SPOT_ANGLE
		spot.spot_angle_attenuation = 0.4
		spot.spot_range = 80.0
		spot.spot_attenuation = 0.5
		spot.light_volumetric_fog_energy = 1.2
		spot.shadow_enabled = false
		spot.visible = false
		add_child(spot)
		spot.position = EntranceDirector.FOLLOW_SPOT_AT
		_spots.append(spot)
		var key := SpotLight3D.new()
		key.name = "RampKey%d" % _keys.size()
		key.light_color = Color(1.0, 0.98, 0.95)
		key.spot_angle = KEY_ANGLE
		key.spot_angle_attenuation = 1.6
		key.spot_range = KEY_RANGE
		key.light_volumetric_fog_energy = 0.0
		key.shadow_enabled = false
		key.visible = false
		add_child(key)
		_keys.append(key)
		_level.append(0.0)


## Whether a man standing at `p` is up the ramp or on the stage.
static func on_ramp(p: Vector3) -> bool:
	return p.z < -(ArenaBuilder.BARRICADE_RADIUS + ON_RAMP_PAST)


func _physics_process(delta: float) -> void:
	for i in _men.size():
		var w := _men[i]
		var want := 1.0 if is_instance_valid(w) and w.visible and w.is_physics_processing() \
				and on_ramp(w.global_position) else 0.0
		_level[i] = move_toward(_level[i], want, delta / FADE)
		var on := _level[i] > 0.001
		_spots[i].visible = on
		_keys[i].visible = on
		if not on:
			continue
		var chest := w.global_position + Vector3.UP * 1.1
		_spots[i].light_energy = SPOT_ENERGY * _level[i]
		if _spots[i].global_position.distance_to(chest) > 0.1:
			_spots[i].look_at(chest, Vector3.UP)
		_keys[i].light_energy = KEY_ENERGY * _level[i]
		_keys[i].global_position = w.global_position + Vector3(0.0, KEY_UP, KEY_AHEAD)
		_keys[i].look_at(chest, Vector3.UP)
