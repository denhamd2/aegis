extends RefCounted
class_name RoversArena
## Original Blender shell + spatially grouped instanced seats and crowd LODs.
const ROOT := "res://assets/environment/rovers_arena/"
static var _positions: Array = []
static var _layout: Dictionary = {}

static func layout() -> Dictionary:
 if _layout.is_empty(): _layout = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"seating_layout.json"))
 return _layout

static func build(parent: Node3D) -> void:
 var root := Node3D.new()
 root.name = "RoversArena"
 parent.add_child(root)
 var shell := (load(ROOT+"stadium_shell.glb") as PackedScene).instantiate()
 shell.name = "StadiumShell"
 root.add_child(shell)
 for node in shell.find_children("*","MeshInstance3D",true,false):
  # Exterior masonry has outward faces: cull it from pitch-level cameras.
  if node.name.begins_with("Exterior"):
   for surface in node.mesh.get_surface_count():
    var mat: Material = node.mesh.surface_get_material(surface)
    if mat is StandardMaterial3D:
     mat = mat.duplicate()
     mat.cull_mode = BaseMaterial3D.CULL_BACK
     node.set_surface_override_material(surface,mat)
  if "Glass" in node.name: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if node.name.begins_with("RoofStructure"): node.visibility_range_end = 230
 if _positions.is_empty(): _positions = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"seating.json"))
 var template := (load(ROOT+"arena_seat.glb") as PackedScene).instantiate()
 var seat_mesh: Mesh = template.find_children("*","MeshInstance3D",true,false)[0].mesh
 template.free()
 # The four-triangle folded silhouette keeps both pan and back at distance.
 var tool := SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for p in [Vector3(-.22,.44,-.23),Vector3(.22,.44,-.23),Vector3(-.22,.44,.19),Vector3(.22,.44,-.23),Vector3(.22,.44,.19),Vector3(-.22,.44,.19),Vector3(-.22,.44,.19),Vector3(.22,.44,.19),Vector3(-.20,.88,.25),Vector3(.22,.44,.19),Vector3(.20,.88,.25),Vector3(-.20,.88,.25)]: tool.add_vertex(p)
 tool.generate_normals()
 var far_seat := tool.commit()
 var blue := seat_mesh.surface_get_material(0).duplicate() as StandardMaterial3D
 blue.cull_mode = BaseMaterial3D.CULL_DISABLED
 far_seat.surface_set_material(0,blue)
 var fan_mesh := QuadMesh.new()
 fan_mesh.size = Vector2(.5,.89)
 fan_mesh.center_offset = Vector3(0,.78,0)
 var crowd := ShaderMaterial.new()
 crowd.shader = preload("res://shaders/arena_crowd.gdshader")
 fan_mesh.material = crowd
 var groups: Array[Array] = []
 var sections: Array = layout().sections
 for index in sections.size(): groups.append([])
 for entry in _positions: groups[int(entry[4])].append(entry)
 for section in groups.size():
  var entries: Array = groups[section]
  _instances(root,"SeatsNear%02d"%section,seat_mesh,entries,false,0,35,sections[section])
  _instances(root,"SeatsFar%02d"%section,far_seat,entries,false,35,290,sections[section])
  _instances(root,"Crowd%02d"%section,fan_mesh,entries,true,0,260,sections[section])
 root.set_meta("seat_count",_positions.size())
 root.set_meta("crowd_style","section-instanced seated crowd cards; no crowd skeletons")
 # Hero touchline spectators keep existing readable close-up characters.
 KilmoreDriveVenue._add_spectators(root,68.0)
 for x in [-52.5,52.5]:
  for z in [-34.0,34.0]: _flag(root,Vector3(x,0,z))

static func _instances(parent: Node3D, label: String, mesh: Mesh, entries: Array,
  crowd: bool, near: float, far: float, section: Dictionary = {}) -> void:
 var mm := MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.use_custom_data = crowd
 mm.mesh = mesh
 var chosen: Array = []
 for i in entries.size():
  var role: String = section.get("role","side")
  var occupancy := 70 if role == "home" else 15 if role == "away" else 40
  if not crowd or (i*37)%100 < occupancy: chosen.append(entries[i])
 mm.instance_count = chosen.size()
 var coats := [Color(.04,.07,.12),Color(.10,.20,.35),Color(.66,.68,.69),Color(.22,.23,.25),Color(.05,.12,.22)]
 var centre := Vector3.ZERO
 if section.has("centre"): centre = Vector3(section.centre[0],section.centre[1],section.centre[2])
 for i in chosen.size():
  var entry: Array = chosen[i]
  var pose := seat_transform(entry)
  pose.origin -= centre
  mm.set_instance_transform(i,pose)
  if crowd:
   var c: Color = coats[(i*7+label.hash())%coats.size()]
   c.a = float(i%97)/97
   mm.set_instance_custom_data(i,c)
 var node := MultiMeshInstance3D.new()
 node.name = label
 node.multimesh = mm
 node.position = centre
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.visibility_range_begin = near
 node.visibility_range_end = far
 # Overlap the complementary fades. Hysteresis on two independent ranges can
 # otherwise leave a whole block empty when a camera first starts near 35 m.
 if not crowd:
  node.visibility_range_begin = maxf(0,near-2)
  node.visibility_range_end = far+2
  node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  node.visibility_range_begin_margin = 2
  node.visibility_range_end_margin = 2
 parent.add_child(node)

static func seat_transform(entry: Array) -> Transform3D:
 # Shared by both chair LODs and crowds; imported data is already Godot Y-up.
 return Transform3D(Basis(Vector3.UP,float(entry[3])),Vector3(entry[0],entry[1],entry[2]))

static func _flag(parent: Node3D, at: Vector3) -> void:
 var pole := MeshInstance3D.new()
 pole.name = "CornerFlag_%d_%d" % [int(at.x),int(at.z)]
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = .017; cylinder.bottom_radius = .017; cylinder.height = 1.5
 cylinder.radial_segments = 8
 var white := StandardMaterial3D.new()
 white.albedo_color = Color(.9,.91,.86); white.roughness = .7
 cylinder.material = white
 pole.mesh = cylinder
 pole.position = at+Vector3.UP*.75
 parent.add_child(pole)
 var cloth := MeshInstance3D.new()
 var mesh := PlaneMesh.new()
 mesh.size = Vector2(.42,.29)
 mesh.subdivide_width = 5
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(.025,.15,.55)
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.roughness = .95
 mesh.material = material
 cloth.mesh = mesh
 cloth.rotation.x = PI/2
 cloth.position = at+Vector3(.21,1.34,0)
 pole.add_sibling(cloth)
