extends Resource
class_name KilmoreSiteLayout
## Authored layout derived from archived imagery; not surveyed coordinates.
@export var outline := PackedVector2Array()
@export var west_road := PackedVector2Array()
@export_multiline var reference_note := ""

func road_z_at(x: float) -> float:
	for i in range(west_road.size() - 1):
		var a := west_road[i]
		var b := west_road[i + 1]
		if x <= a.x and x >= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return west_road[0].y if x > west_road[0].x else west_road[-1].y
