extends Node3D
class_name PitchGrassDetail
## Camera-local opaque geometry; no physics blades or full-field draw cost.
const CELL := .75
const TUFTS_PER_CELL := 2500
const MAX_CELLS := 16
const MAX_TUFTS := TUFTS_PER_CELL * MAX_CELLS
var game: Node3D
var chunks: Dictionary = {}
var material: ShaderMaterial
var tuft: ArrayMesh
var _cell := Vector2i(9999,9999)
var _pending: Array[Vector2i] = []
var prepared: Dictionary = {}
var _preparing: Array[Vector2i] = []
var _prepared_cell := Vector2i(9999,9999)
var surface: WetPitchSurface
func setup(match_scene: Node3D) -> void:
	game=match_scene
	surface=load("res://data/presentation/kilmore_surface.tres")
	material=ShaderMaterial.new()
	material.shader=load("res://shaders/grass_blades.gdshader")
	material.set_shader_parameter("grass_albedo",load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	tuft=_make_turf_ribbon()
	_process(0)
func _make_turf_ribbon() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three tapered ribbon leaves per crown, two triangles each. More cover
	# than isolated pointed stalks at the same six-triangle instance budget.
	for blade in 3:
		var angle := float(blade)*2.4
		var across := Vector3(cos(angle),0,sin(angle))*.0014
		var lean := Vector3(sin(angle),0,cos(angle))*.006
		var base := lean*.35
		var tip := base+Vector3.UP*(.018+blade*.003)+lean
		var points := [base-across,base+across,tip-across*.16,base+across,tip+across*.16,tip-across*.16]
		for index in points.size():
			tool.set_normal((Vector3.UP*.9+Vector3(sin(angle),0,cos(angle))).normalized())
			tool.set_uv(Vector2(float(index%2),clampf(points[index].y/(.018+blade*.003),0,1)))
			tool.add_vertex(points[index])
	return tool.commit()
func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	# Rendering-only geometry has no work to do on a headless physics server.
	if DisplayServer.get_name() == "headless": return
	for index in mini(2, _preparing.size()): _build_cell(_preparing.pop_front(), true)
	var location := camera.global_position
	if location.y - PitchSurface.height_at(location.x, location.z) > 4.0:
		visible = false
		return
	visible = true
	_queue_cells(location)
	for index in mini(2, _pending.size()): _build_cell(_pending.pop_front())

func _queue_cells(location: Vector3) -> void:
	var next := Vector2i(floori(location.x/CELL), floori(location.z/CELL))
	if next == _cell: return
	_cell = next
	var desired := _keys_for(location)
	for key in chunks.keys():
		if not desired.has(key): chunks[key].free(); chunks.erase(key)
	_pending.clear()
	for key in desired:
		if chunks.has(key): continue
		if prepared.has(key):
			chunks[key] = prepared[key]
			chunks[key].show()
			prepared.erase(key)
		else: _pending.append(key)

func _keys_for(location: Vector3) -> Array[Vector2i]:
	var centre := Vector2i(floori(location.x/CELL), floori(location.z/CELL))
	var desired: Array[Vector2i] = []
	for z in range(-2, 3):
		for x in range(-2, 3): desired.append(centre + Vector2i(x, z))
	var point := Vector2(location.x / CELL, location.z / CELL)
	desired.sort_custom(func(a, b): return (Vector2(a)+Vector2(.5,.5)).distance_squared_to(point) < (Vector2(b)+Vector2(.5,.5)).distance_squared_to(point))
	desired.resize(MAX_CELLS)
	return desired

func prepare(location: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	if location.y - PitchSurface.height_at(location.x, location.z) > 4.0: return
	var centre := Vector2i(floori(location.x/CELL), floori(location.z/CELL))
	if centre == _prepared_cell: return
	_prepared_cell = centre
	for instance in prepared.values(): instance.free()
	prepared.clear(); _preparing.clear()
	for key in _keys_for(location):
		if not chunks.has(key): _preparing.append(key)

func prewarm(location: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	if location.y - PitchSurface.height_at(location.x, location.z) > 4.0: return
	visible = true
	_queue_cells(location)
	while not _pending.is_empty(): _build_cell(_pending.pop_front())

func _build_cell(key: Vector2i, staging := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true;mm.use_custom_data=true;mm.mesh=tuft
	mm.instance_count=TUFTS_PER_CELL
	var random := RandomNumberGenerator.new()
	random.seed=absi(key.x*73856093 ^ key.y*19349663)+27
	var count := 0
	for index in TUFTS_PER_CELL:
		var x := (key.x+random.randf())*CELL
		var z := (key.y+random.randf())*CELL
		if absf(x)>52.5 or absf(z)>34: continue
		var wet := surface.sample_at(Vector3(x,0,z))
		if wet.y>.15 or random.randf()<wet.x*.9: continue
		var height := PitchSurface.height_at(x,z)
		var normal := Vector3((height-PitchSurface.height_at(x+.05,z))/.05,1,(height-PitchSurface.height_at(x,z+.05))/.05).normalized()
		var basis := Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,random.randf()*TAU)
		basis=basis.scaled(Vector3(1,random.randf_range(.85,1.2),1))
		mm.set_instance_transform(count,Transform3D(basis,Vector3(x,height-.001,z)))
		mm.set_instance_color(count,Color(1,random.randf_range(.85,1.05),random.randf_range(.8,1),1))
		mm.set_instance_custom_data(count,Color(1.0 if _painted(Vector2(x,z)) else 0.0,random.randf(),0,0))
		count+=1
	mm.visible_instance_count=count
	var instance := MultiMeshInstance3D.new()
	instance.name="Grass_%s_%s"%[key.x,key.y]
	instance.multimesh=mm;instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end=7
	add_child(instance)
	if staging:
		instance.hide();prepared[key]=instance
	else: chunks[key]=instance
static func _painted(p: Vector2) -> bool:
	var x := absf(p.x);var z := absf(p.y)
	if x>52.38 or z>33.88 or x<.065 or absf(p.length()-9.15)<.07: return true
	for box in [Vector2(36,20.16),Vector2(47,9.16)]:
		if (absf(x-box.x)<.065 and z<box.y) or (x>box.x and absf(z-box.y)<.065): return true
	if x<36 and absf(Vector2(x-41.5,z).length()-9.15)<.065: return true
	return p.length()<.16 or Vector2(x-41.5,z).length()<.16
func tuft_count() -> int:
	var count := 0
	for instance in chunks.values(): count+=instance.multimesh.visible_instance_count
	return count
