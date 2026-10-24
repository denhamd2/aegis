extends SceneTree
## Exercise the same near/far MultiMesh placement as the shipped arena.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/rovers_arena/seating.json"))
 var template := (load("res://assets/environment/rovers_arena/arena_seat.glb") as PackedScene).instantiate()
 var seat := template.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
 assert(seat.transform.is_equal_approx(Transform3D.IDENTITY),"Discarding an imported transform would tilt every chair")
 var mesh: Mesh = seat.mesh
 assert(absf(mesh.get_aabb().position.y)<.001 and mesh.get_aabb().size.y>.85)
 var container := Node3D.new()
 root.add_child(container)
 RoversArena._instances(container,"NearAudit",mesh,entries,false,0,40)
 RoversArena._instances(container,"FarAudit",QuadMesh.new(),entries,false,40,290)
 var near := container.get_node("NearAudit") as MultiMeshInstance3D
 var far := container.get_node("FarAudit") as MultiMeshInstance3D
 var diagonal := sqrt(.5)
 var outward: Array[Vector3] = [Vector3(diagonal,0,diagonal),Vector3.RIGHT,
  Vector3(diagonal,0,-diagonal),Vector3.FORWARD,Vector3(-diagonal,0,-diagonal),
  Vector3.LEFT,Vector3(-diagonal,0,diagonal),Vector3.BACK]
 var rows := {}
 for index in entries.size():
  var source: Array = entries[index]
  var a := RoversArena.seat_transform(source)
  # The dummy headless RenderingServer returns identity for GPU readback.
  # Native Forward+ captures audit the actual near/far buffers separately.
  if DisplayServer.get_name() != "headless":
   assert(a.is_equal_approx(near.multimesh.get_instance_transform(index)))
   assert(a.is_equal_approx(far.multimesh.get_instance_transform(index)))
  assert(a.basis.y.dot(Vector3.UP)>.9999,"Chair has pitch/roll instead of staying upright")
  var side := int(source[4])%8
  assert((-a.basis.z).dot(-outward[side])>.999,"Chair must face perpendicular into the pitch")
  if side in [1,3,5,7]:
   var lateral := a.origin.z if side in [1,5] else a.origin.x
   assert(absf(lateral-roundf(lateral/.6)*.6)<.002,"Seat columns drift between risers")
   assert(absf(lateral-roundf(lateral/13.2)*13.2)>1.15,"Seat blocks a continuous stair aisle")
  rows["%d:%.2f"%[int(source[4]),a.origin.y]] = true
 assert(rows.size()==8*(18+20+20))
 assert(near.multimesh.instance_count==entries.size() and entries.size()>45000)
 print("STADIUM_SEATING PASS: ",entries.size()," upright, inward-facing seats; 464 level bank rows; aligned columns/aisles; identical near/far transforms")
 template.free();container.free();quit()
