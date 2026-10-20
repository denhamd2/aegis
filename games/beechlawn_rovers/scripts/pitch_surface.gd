extends RefCounted
class_name PitchSurface
## Broad, shallow authored relief. Images establish wear, not surveyed heights.
const LENGTH := 105.0
const WIDTH := 68.0

static func height_at(x: float, z: float) -> float:
	var edge := smoothstep(0.0, 5.0, 52.5-absf(x)) * smoothstep(0.0, 5.0, 34.0-absf(z))
	return (0.045*sin(x*0.095)*cos(z*0.11) + 0.012*sin(x*0.41+z*0.19))*edge

static func make_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(68):
		for x in range(105):
			# Godot uses clockwise front faces when viewed from above.
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var point: Vector2 = Vector2(float(x),float(z))+corner
				tool.set_uv(Vector2(point.x/LENGTH,point.y/WIDTH))
				tool.add_vertex(Vector3(point.x-52.5,height_at(point.x-52.5,point.y-34.0),point.y-34.0))
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	return tool.commit()

static func make_collision() -> HeightMapShape3D:
	var heights := PackedFloat32Array()
	for z in range(89):
		for x in range(126):heights.append(height_at(float(x)-62.5,float(z)-44.0))
	var shape := HeightMapShape3D.new()
	shape.map_width = 126
	shape.map_depth = 89
	shape.map_data = heights
	return shape
