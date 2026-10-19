extends RefCounted
class_name KilmoreDriveVenue
## Reusable Kilmore Drive park dressing, shared by the full match and fixtures.
## Gameplay dimensions and collision remain owned by TrainingGround.

# Reference-led approximation, not surveyed site dimensions. The satellite
# captures show a broad open lawn between the pitch and the residential street.
const ROAD_FACING_GRASS_BUFFER := 35.0
const ROAD_CONTEXT_SHIFT := ROAD_FACING_GRASS_BUFFER - 5.75

const HOUSE_MODULE: PackedScene = preload("res://assets/environment/kilmore/kilmore_house_a.glb")
const HOUSE_MODULE_B: PackedScene = preload("res://assets/environment/kilmore/kilmore_house_b.glb")
const TREE_MODULE: PackedScene = preload("res://assets/environment/kilmore/kilmore_tree_a.glb")
const TREE_MODULE_B: PackedScene = preload("res://assets/environment/kilmore/kilmore_tree_b.glb")
const CAR_MODULES: Array[PackedScene] = [
	preload("res://assets/environment/kilmore/kilmore_hatchback_a.glb"),
	preload("res://assets/environment/kilmore/kilmore_hatchback_b.glb"),
	preload("res://assets/environment/kilmore/kilmore_hatchback_c.glb"),
	preload("res://assets/environment/kilmore/kilmore_hatchback_d.glb"),
]

static func build(parent: Node3D, field_length: float, field_width: float, detailed := false) -> void:
	var root := Node3D.new()
	root.name = "KilmoreDriveParkDressing"
	parent.add_child(root)
	var grass := _material(Color(0.21, 0.30, 0.16), 0.98)
	var grass_worn := _material(Color(0.29, 0.34, 0.19), 0.98)
	var asphalt := _material(Color(0.19, 0.205, 0.19), 0.94)
	var concrete := _material(Color(0.37, 0.39, 0.36), 0.93)
	var wall_light := _material(Color(0.47, 0.48, 0.43), 0.92)
	var wall_dark := _material(Color(0.38, 0.40, 0.37), 0.95)
	var hedge := _material(Color(0.12, 0.23, 0.13), 0.98)
	var trim := _material(Color(0.78, 0.76, 0.68), 0.88)
	var lamp_metal := _material(Color(0.17, 0.19, 0.18), 0.72)
	var curb := _material(Color(0.48, 0.49, 0.45), 0.94)
	var pole_metal := _material(Color(0.21, 0.23, 0.21), 0.82)
	var park_grass_shader := load("res://shaders/kilmore_park_grass.gdshader") as Shader
	var park_grass_material := ShaderMaterial.new()
	park_grass_material.shader = park_grass_shader
	park_grass_material.set_shader_parameter("playing_size",Vector2(field_length,field_width))
	park_grass_material.set_shader_parameter("grass_albedo",
		load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	var asphalt_shader := load("res://shaders/kilmore_asphalt.gdshader") as Shader
	var road_material := ShaderMaterial.new()
	road_material.shader = asphalt_shader
	road_material.set_shader_parameter("asphalt_albedo",
		load("res://assets/environment/surfaces/ambientcg/Asphalt033/Asphalt033_1K-JPG_Color.jpg"))
	var far_side_sign := -1.0

	# Park ground extends beyond play so the camera sees grass rather than a hard edge.
	var park_turf := _box(root, "ParkTurf", Vector3(field_length + 42.0, 0.22, field_width + 72.0 + ROAD_CONTEXT_SHIFT),
		Vector3(0.0, -0.11, -ROAD_CONTEXT_SHIFT * 0.5), grass)
	park_turf.material_override = park_grass_material
	# The apron meets the field at grade. A hole beneath the playing area
	# prevents this flat park surface from hiding the authored pitch relief.
	park_turf.position = Vector3.ZERO
	park_turf.mesh = _park_apron_mesh(field_length, field_width)
	# Keep a substantial open lawn before the pavement/road cluster.
	_box(root, "Footpath", Vector3(field_length + 34.0, 0.16, 2.5),
		Vector3(0.0, -0.04, far_side_sign * (field_width * 0.5 + 7.0 + ROAD_CONTEXT_SHIFT)), concrete)
	var road := _box(root, "Road", Vector3(field_length + 44.0, 0.12, 7.0),
		Vector3(0.0, -0.04, far_side_sign * (field_width * 0.5 + 12.0 + ROAD_CONTEXT_SHIFT)), asphalt)
	road.material_override = road_material
	_box(root, "FootpathOuter", Vector3(field_length + 34.0, 0.14, 1.7),
		Vector3(0.0, -0.04, far_side_sign * (field_width * 0.5 + 17.1 + ROAD_CONTEXT_SHIFT)), concrete)
	_box(root, "RoadsideCurb", Vector3(field_length + 34.0, 0.22, 0.24),
		Vector3(0.0, 0.02, far_side_sign * (field_width * 0.5 + 8.5 + ROAD_CONTEXT_SHIFT)), curb)
	var grass_verge := _box(root, "GrassVerge", Vector3(field_length + 34.0, 0.035, 1.25),
		Vector3(0.0, -0.04, far_side_sign * (field_width * 0.5 + 18.5 + ROAD_CONTEXT_SHIFT)), grass_worn)
	grass_verge.material_override = park_grass_material

	# Kilmore Drive's long, weathered wall and hedge form the far boundary layer.
	for end_sign in [-1.0, 1.0]:
		if detailed and end_sign < 0.0:
			continue
		_box(root, "EndWall_%s" % end_sign, Vector3(0.28, 1.55, field_width + 12.0 + ROAD_FACING_GRASS_BUFFER),
			Vector3(end_sign * (field_length * 0.5 + 10.0), 0.77, (12.0 - ROAD_FACING_GRASS_BUFFER) * 0.5), wall_light)
		for joint in range(18):
			var z := -field_width * 0.5 - ROAD_FACING_GRASS_BUFFER + 1.0 + float(joint) * (field_width + ROAD_FACING_GRASS_BUFFER + 10.0) / 17.0
			_box(root, "WallJoint", Vector3(0.31, 1.62, 0.06),
				Vector3(end_sign * (field_length * 0.5 + 9.84), 0.79, z), wall_dark)
	var boundary_sign := 1.0
	_box(root, "FarBoundaryWall", Vector3(field_length + 20.0, 1.65, 0.32),
		Vector3(0.0, 0.825, boundary_sign*(field_width * 0.5 + 10.0)), wall_light)
	_box(root, "FarBoundaryHedge", Vector3(field_length + 20.0, 1.8, 1.1),
		Vector3(0.0, 1.7, boundary_sign*(field_width * 0.5 + 11.1)), hedge)

	# Houses sit beyond the road/path on the residential edge. Alternate two
	# facades, vary their scale/setback, and leave broad gaps for mature trees so
	# the broadcast skyline reads as a real street rather than a repeated wall.
	for side in [-1.0, 1.0]:
		if detailed and side > 0.0:
			continue
		for index in 9:
			var x := -field_length * 0.5 - 12.0 + float(index) * (field_length + 24.0) / 8.0
			var depth := field_width * 0.5 + 24.0 + float((index * 7 + int(side)) % 4) * 2.2
			if side < 0.0:
				depth += ROAD_CONTEXT_SHIFT
			var module := HOUSE_MODULE_B if (index + int(side)) % 3 == 0 else HOUSE_MODULE
			var house := _add_module(root, "ResidentialHouse_%02d_%s" % [index, side], module,
				Vector3(x, 0.0, side * depth), Vector3(0.0, PI if side > 0.0 else 0.0, 0.0))
			var house_scale := 0.88 + float((index * 13 + int(side) * 3) % 11) * 0.025
			house.scale = Vector3(house_scale, house_scale, house_scale)

	# Existing trees and a few roadside specimens create irregular skyline breaks.
	for row in range(3):
		for index in range(10):
			# Skip alternating sites in different rows to preserve open views of
			# houses and the irregular park-edge rhythm visible in the location refs.
			if (index + row * 2) % 7 == 0 or (row == 1 and index not in [0, 1, 3]):
				continue
			var x := -field_length * 0.5 - 15.0 + float(index) * (field_length + 30.0) / 9.0
			var side := -1.0 if row < 2 else 1.0
			var variation := float((index * 7 + row * 3) % 5)
			var z := side * (field_width * 0.5 + 13.0 + variation * 1.2)
			if row == 0:
				# Trunks sit on the grass just inside the distant footpath.
				z = -(field_width * 0.5 + ROAD_FACING_GRASS_BUFFER - 4.0 + variation * 0.65)
			elif row == 1:
				# Sparse western park specimens, leaving the central apron open.
				z = -(field_width * 0.5 + 16.0 + variation * 1.5)
			var tree_module := TREE_MODULE_B if (index + row) % 4 == 0 else TREE_MODULE
			var tree := _add_module(root, "ParkTree_%02d_%02d" % [row, index], tree_module,
				Vector3(x, 0.0, z), Vector3.ZERO)
			var scale_factor := 0.82 + float((index * 17 + row * 11) % 29) / 100.0
			tree.scale = Vector3.ONE * scale_factor

	# Park-road cues at a distance: restrained lamp posts and parked cars.
	for index in range(5):
		var x := -field_length * 0.42 + float(index) * field_length * 0.21
		_add_lamp(root, Vector3(x, 0.0, far_side_sign * (field_width * 0.5 + 8.3 + ROAD_CONTEXT_SHIFT)), lamp_metal, trim)
		if index % 2 == 0:
			_add_utility_pole(root, Vector3(x - 5.5, 0.0, far_side_sign * (field_width * 0.5 + 20.5 + ROAD_CONTEXT_SHIFT)), pole_metal)
	# Three quiet overhead service cables establish the suburban road edge. They
	# are simple static beams, with no physics or per-frame updates.
	for line_index in range(3):
		var z := far_side_sign * (field_width * 0.5 + 19.2 + ROAD_CONTEXT_SHIFT + float(line_index) * 0.24)
		_box(root, "OverheadCable_%d" % line_index, Vector3(field_length + 27.0, 0.035, 0.035),
			Vector3(0.0, 6.15 - float(line_index) * 0.18, z), pole_metal)
	for index in 6:
		var x := -field_length * 0.43 + float(index) * field_length * 0.17
		var car := _add_module(root, "ParkedCar_%02d" % index, CAR_MODULES[index % CAR_MODULES.size()],
			Vector3(x, 0.0, far_side_sign * (field_width * 0.5 + 9.5 + ROAD_CONTEXT_SHIFT)), Vector3.ZERO)
		car.scale = Vector3.ONE * (0.94 + float(index % 3) * 0.035)
		car.rotation.y = PI if index % 2 == 1 else 0.0
	if detailed:
		_add_spectators(root,field_width)
		var wall_shader := load("res://shaders/park_wall.gdshader") as Shader
		var wall_material := ShaderMaterial.new()
		wall_material.shader = wall_shader
		for wall in root.find_children("*Wall*", "MeshInstance3D", true, false):
			(wall as MeshInstance3D).material_override = wall_material

static func _add_spectators(parent: Node3D, width: float) -> void:
	var scene := load("res://scenes/footballer_visual.tscn") as PackedScene
	for index in 8:
		var visual := scene.instantiate() as FootballerVisual
		visual.name = "Spectator_%02d" % index
		parent.add_child(visual)
		var profile := FootballerProfile.new()
		profile.appearance = FootballAppearance.new()
		profile.appearance.kit = "spectator"
		profile.appearance.height_scale = 0.96 + float(index%3)*0.025
		profile.appearance.build_scale = 0.94 + float(index%4)*0.035
		visual.configure_appearance(profile)
		visual.position = Vector3(-28.0+float(index)*8.0,0.0,-width*0.5-2.0-float(index%2)*0.7)
		visual.rotation.y = PI
		visual.animation_tree.active = false
		visual.animation_player.play(&"AN_Beechlawn_Idle")
		visual.animation_player.seek(float(index%4)*0.18,true)
		visual.animation_player.pause()

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

static func _add_module(parent: Node3D, node_name: String, module: PackedScene,
		at: Vector3, rotation: Vector3) -> Node3D:
	var instance := module.instantiate() as Node3D
	instance.name = node_name
	instance.position = at
	instance.rotation = rotation
	parent.add_child(instance)
	return instance

static func _add_lamp(parent: Node3D, at: Vector3, metal: Material, lamp: Material) -> void:
	var root := Node3D.new()
	root.name = "RoadsideLamp_%d" % roundi(at.x)
	root.position = at
	parent.add_child(root)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.09
	pole.height = 7.0
	var post := MeshInstance3D.new()
	post.mesh = pole
	post.position.y = 3.5
	post.material_override = metal
	root.add_child(post)
	_box(root, "LampHead", Vector3(0.46, 0.18, 0.26), Vector3(0.0, 7.0, 0.0), lamp)

static func _add_utility_pole(parent: Node3D, at: Vector3, material: Material) -> void:
	var root := Node3D.new()
	root.name = "UtilityPole_%d" % roundi(at.x)
	root.position = at
	parent.add_child(root)
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.09
	shaft_mesh.bottom_radius = 0.17
	shaft_mesh.height = 7.1
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.position.y = 3.55
	shaft.material_override = material
	root.add_child(shaft)
	_box(root, "CrossArm", Vector3(1.15, 0.11, 0.14), Vector3(0.0, 6.45, 0.0), material)
	for x in [-0.42, 0.0, 0.42]:
		_box(root, "Insulator", Vector3(0.08, 0.25, 0.08), Vector3(x, 6.62, 0.0), material)


static func _park_apron_mesh(length: float, width: float) -> ArrayMesh:
	var hx := length * 0.5
	var hz := width * 0.5
	var x0 := -hx - 21.0
	var x1 := hx + 21.0
	var z0 := -hz - 36.0 - ROAD_CONTEXT_SHIFT
	var z1 := hz + 36.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect in [Rect2(x0,z0,x1-x0,-hz-z0), Rect2(x0,hz,x1-x0,z1-hz),
			Rect2(x0,-hz,-hx-x0,width), Rect2(hx,-hz,x1-hx,width)]:
		var a := Vector3(rect.position.x,0,rect.position.y)
		var b := Vector3(rect.end.x,0,rect.position.y)
		var c := Vector3(rect.end.x,0,rect.end.y)
		var d := Vector3(rect.position.x,0,rect.end.y)
		for point in [a,b,c,a,c,d]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(point.x,point.z)/8.0)
			tool.add_vertex(point)
	return tool.commit()
