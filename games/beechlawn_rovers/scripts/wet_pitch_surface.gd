extends Resource
class_name WetPitchSurface
## One authored mask supplies visible mud/water and authoritative rolling drag.
@export var masks: Texture2D
@export_range(0.0, 8.0) var puddle_drag := 2.6
@export_range(0.0, 2.0) var mud_drag := 0.22
var _pixels: Image

func sample_at(position: Vector3) -> Vector2:
	if absf(position.x) > 52.5 or absf(position.z) > 34.0 or masks == null:
		return Vector2.ZERO
	if _pixels == null:
		_pixels = masks.get_image()
	# Match GPU linear sampling: UVs address pixel centres, not pixel corners.
	var p := Vector2((position.x/105.0+0.5)*_pixels.get_width()-0.5,
		(position.z/68.0+0.5)*_pixels.get_height()-0.5)
	var x := floori(p.x)
	var y := floori(p.y)
	var a := _pixel(x,y).lerp(_pixel(x+1,y),p.x-x)
	var b := _pixel(x,y+1).lerp(_pixel(x+1,y+1),p.x-x)
	return a.lerp(b,p.y-y)

func _pixel(x: int, y: int) -> Vector2:
	var c := _pixels.get_pixel(clampi(x,0,_pixels.get_width()-1),clampi(y,0,_pixels.get_height()-1))
	return Vector2(c.r,c.g)

func resistance(position: Vector3, wetness: float) -> float:
	var surface := sample_at(position)
	return clampf(wetness,0.0,1.0)*(surface.x*mud_drag+surface.y*puddle_drag)

func drag_force(position: Vector3, velocity: Vector3, ball_mass: float,
		wetness: float, delta: float) -> Vector3:
	# Exponential damping gives a stable per-second coefficient at 60/120 Hz.
	var v := Vector3(velocity.x,0.0,velocity.z)
	return -v*ball_mass*(1.0-exp(-resistance(position,wetness)*delta))/maxf(delta,0.0001)
