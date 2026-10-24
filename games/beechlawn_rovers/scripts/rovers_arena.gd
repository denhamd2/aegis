extends RefCounted
class_name RoversArena
## Original Blender shell + spatially grouped instanced seats and crowd LODs.
const ROOT := "res://assets/environment/rovers_arena/"
static var _positions: Array = []

static func build(parent: Node3D) -> void:
 var root := Node3D.new()
 root.name = "RoversArena"
 parent.add_child(root)
 var shell := (load(ROOT+"stadium_shell.glb") as PackedScene).instantiate()
 shell.name = "StadiumShell"
 root.add_child(shell)
 if _positions.is_empty(): _positions = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"seating.json"))
 var template := (load(ROOT+"arena_seat.glb") as PackedScene).instantiate()
 var seat_mesh: Mesh = template.find_children("*","MeshInstance3D",true,false)[0].mesh
 template.free()
 var far_seat := QuadMesh.new()
 far_seat.size = Vector2(.43,.5)
 far_seat.center_offset = Vector3(0,.54,0)
 var blue := StandardMaterial3D.new()
 blue.albedo_color = Color(.035,.16,.34)
 blue.roughness = .55
 blue.cull_mode = BaseMaterial3D.CULL_DISABLED
 far_seat.material = blue
 var fan_mesh := QuadMesh.new()
 fan_mesh.size = Vector2(.5,.89)
 fan_mesh.center_offset = Vector3(0,.78,0)
 var crowd := ShaderMaterial.new()
 crowd.shader = preload("res://shaders/arena_crowd.gdshader")
 fan_mesh.material = crowd
 var groups: Array[Array] = []
 for index in 24: groups.append([])
 for entry in _positions: groups[int(entry[4])].append(entry)
 for section in groups.size():
  var entries: Array = groups[section]
  _instances(root,"SeatsNear%02d"%section,seat_mesh,entries,false,0,40)
  _instances(root,"SeatsFar%02d"%section,far_seat,entries,false,40,290)
  _instances(root,"Crowd%02d"%section,fan_mesh,entries,true,0,260)
 root.set_meta("seat_count",_positions.size())
 root.set_meta("crowd_style","section-instanced seated crowd cards; no crowd skeletons")
 # Hero touchline spectators keep existing readable close-up characters.
 KilmoreDriveVenue._add_spectators(root,68.0)
 for x in [-52.5,52.5]:
  for z in [-34.0,34.0]: _flag(root,Vector3(x,0,z))

static func _instances(parent: Node3D, label: String, mesh: Mesh, entries: Array,
  crowd: bool, near: float, far: float) -> void:
 var mm := MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.use_custom_data = crowd
 mm.mesh = mesh
 var chosen: Array = []
 for i in entries.size():
  var side := int(entries[i][4])%8
  var occupancy := 70 if side == 3 else 15 if side == 7 else 40
  if not crowd or (i*37)%100 < occupancy: chosen.append(entries[i])
 mm.instance_count = chosen.size()
 var coats := [Color(.04,.07,.12),Color(.10,.20,.35),Color(.66,.68,.69),Color(.22,.23,.25),Color(.05,.12,.22)]
 for i in chosen.size():
  var entry: Array = chosen[i]
  mm.set_instance_transform(i,seat_transform(entry))
  if crowd:
   var c: Color = coats[(i*7+label.hash())%coats.size()]
   c.a = float(i%97)/97
   mm.set_instance_custom_data(i,c)
 var node := MultiMeshInstance3D.new()
 node.name = label
 node.multimesh = mm
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.visibility_range_begin = near
 node.visibility_range_end = far
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
 material.albedo_color = Color(.9,.78,.08)
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.roughness = .95
 mesh.material = material
 cloth.mesh = mesh
 cloth.rotation.x = PI/2
 cloth.position = at+Vector3(.21,1.34,0)
 pole.add_sibling(cloth)
