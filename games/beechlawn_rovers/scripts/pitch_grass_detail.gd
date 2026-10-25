extends Node3D
class_name PitchGrassDetail
## Field-wide deterministic turf, drawn by projected size and visible chunks.
## A curved near crown and cheap intermediate fins share the distant surface.
const CELL := .6
const TUFTS_PER_CELL := 2400
const MAX_CELLS := 8
const MAX_TUFTS := TUFTS_PER_CELL * MAX_CELLS
const MID_CELL := 4.0
const MID_PER_CELL := 512
const MAX_MID_CELLS := 16
const NEAR_TRIANGLES := 9
const MID_TRIANGLES := 4
@export var triangle_budget := 240000
var game: Node3D
var chunks: Dictionary = {}
var mid_chunks: Dictionary = {}
var material: ShaderMaterial
var mid_material: ShaderMaterial
var tuft: ArrayMesh
var mid_tuft: ArrayMesh
var _pending: Array[Vector2i] = []
var prepared: Dictionary = {}
var prepared_mid: Dictionary = {}
var _preparing: Array[Vector2i] = []
var _prepared_cell := Vector2i(9999,9999)
var _signature := ""
var surface: WetPitchSurface
var settings: FootballTurfDetailSettings

func setup(match_scene: Node3D) -> void:
	game = match_scene
	settings = load("res://data/presentation/turf_detail.tres")
	triangle_budget = mini(triangle_budget, settings.triangle_budget)
	surface = load("res://data/presentation/kilmore_surface.tres" if game.venue.worn_surface else "res://data/presentation/arena_surface.tres")
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/grass_blades.gdshader")
	material.set_shader_parameter("stadium_mowing",not game.venue.worn_surface)
	material.set_shader_parameter("grass_albedo",load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	mid_material = ShaderMaterial.new()
	mid_material.shader = load("res://shaders/grass_fins.gdshader")
	mid_material.set_shader_parameter("stadium_mowing",not game.venue.worn_surface)
	mid_material.set_shader_parameter("grass_albedo",material.get_shader_parameter("grass_albedo"))
	tuft = _make_turf_ribbon()
	mid_tuft = _make_mid_fin()
	_process(0)

func _make_turf_ribbon() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 3:
		var angle := float(blade)*2.4
		var across := Vector3(cos(angle),0,sin(angle))*.0011
		var lean := Vector3(sin(angle),0,cos(angle))
		var height := .012+blade*.0025
		var base := lean*.001
		var middle := base+Vector3.UP*height*.62+lean*.0017
		var tip := base+Vector3.UP*height+lean*.005
		var points := [base-across,base+across,middle-across*.56,base+across,middle+across*.56,middle-across*.56,middle-across*.56,middle+across*.56,tip]
		for index in points.size():
			tool.set_normal((Vector3.UP+lean*.45).normalized())
			tool.set_uv(Vector2(float(index%2),clampf(points[index].y/height,0,1)))
			tool.add_vertex(points[index])
	return tool.commit()

func _make_mid_fin() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI*.5]:
		var across := Vector3(cos(angle),0,sin(angle))*.08
		var up := Vector3.UP*.020+Vector3(-sin(angle),0,cos(angle))*.004
		for index in [0,1,2,1,3,2]:
			var u: int = index%2
			var v: int = index/2
			tool.set_uv(Vector2(u,v))
			tool.set_normal((Vector3.UP+Vector3(-sin(angle),0,cos(angle))*.45).normalized())
			tool.add_vertex(across*(-1 if u==0 else 1)+up*v)
	return tool.commit()

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or DisplayServer.get_name()=="headless": return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for index in mini(2,_preparing.size()): _build_cell(_preparing.pop_front(),true)
	var location := camera.global_position
	var signature := "%s:%s:%s:%s" % [Vector3i((location/.4).floor()),Vector3i((camera.global_rotation*45).floor()),int(camera.fov),get_viewport().get_visible_rect().size]
	if signature != _signature:
		_signature = signature
		_queue_cells(location,camera)
		_queue_mid(location,camera)
	for index in mini(2,_pending.size()): _build_cell(_pending.pop_front())
	visible = not chunks.is_empty() or not mid_chunks.is_empty()

func _keys_for(location: Vector3, camera: Camera3D = null) -> Array[Vector2i]:
	var centre := Vector2i(floori(location.x/CELL),floori(location.z/CELL))
	var desired: Array[Vector2i] = []
	for z in range(-3,4):
		for x in range(-3,4):
			var key := centre+Vector2i(x,z)
			var point := Vector3((key.x+.5)*CELL,0,(key.y+.5)*CELL)
			point.y = game.surface_height(point.x,point.z)
			if absf(point.x)>52.5 or absf(point.z)>34: continue
			if camera != null and (_pixels(camera,location,point)<settings.near_pixels or not _in_view(camera,location,point,.6)): continue
			desired.append(key)
	desired.sort_custom(func(a,b): return Vector2(a).distance_squared_to(Vector2(location.x/CELL,location.z/CELL))<Vector2(b).distance_squared_to(Vector2(location.x/CELL,location.z/CELL)))
	desired.resize(mini(desired.size(),mini(MAX_CELLS,triangle_budget/(TUFTS_PER_CELL*NEAR_TRIANGLES))))
	return desired

func _queue_cells(location: Vector3, camera: Camera3D = null) -> void:
	var desired := _keys_for(location,camera)
	for key in chunks.keys():
		if not desired.has(key): chunks[key].free(); chunks.erase(key)
	_pending.clear()
	for key in desired:
		if chunks.has(key): continue
		if prepared.has(key):
			chunks[key]=prepared[key]; chunks[key].show(); prepared.erase(key)
		else: _pending.append(key)

func _mid_keys(location: Vector3, camera: Camera3D = null) -> Array[Vector2i]:
	var desired: Array[Vector2i] = []
	for z in range(-9,9):
		for x in range(-14,14):
			var point := Vector3((x+.5)*MID_CELL,0,(z+.5)*MID_CELL)
			point.y=game.surface_height(point.x,point.z)
			if absf(point.x)>52.5 or absf(point.z)>34: continue
			if camera != null and (_pixels(camera,location,point)<settings.intermediate_pixels or not _in_view(camera,location,point,2.9)): continue
			desired.append(Vector2i(x,z))
	desired.sort_custom(func(a,b): return Vector2(a).distance_squared_to(Vector2(location.x/MID_CELL,location.z/MID_CELL))<Vector2(b).distance_squared_to(Vector2(location.x/MID_CELL,location.z/MID_CELL)))
	var available := maxi(0,triangle_budget-MAX_TUFTS*NEAR_TRIANGLES)/(MID_PER_CELL*MID_TRIANGLES)
	desired.resize(mini(desired.size(),mini(MAX_MID_CELLS,available)))
	return desired

func _pixels(camera: Camera3D, location: Vector3, point: Vector3) -> float:
	var pixels := maxf(540,get_viewport().get_visible_rect().size.y)
	if camera.projection==Camera3D.PROJECTION_ORTHOGONAL: return .022*pixels/maxf(1,camera.size)
	return .022*pixels/(2*tan(deg_to_rad(camera.fov)*.5)*maxf(.1,location.distance_to(point)))

func _in_view(camera: Camera3D, location: Vector3, point: Vector3, radius: float) -> bool:
	var local := camera.global_basis.inverse()*(point-location)
	var depth := -local.z
	if depth+radius<camera.near: return false
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x/maxf(1,size.y)
	var half_height := camera.size*.5 if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else maxf(.01,depth)*tan(deg_to_rad(camera.fov)*.5)
	return absf(local.y)<half_height+radius and absf(local.x)<half_height*aspect+radius

func _queue_mid(location: Vector3, camera: Camera3D = null) -> void:
	var desired := _mid_keys(location,camera)
	for key in mid_chunks.keys():
		if not desired.has(key): mid_chunks[key].free(); mid_chunks.erase(key)
	for key in desired:
		if mid_chunks.has(key): continue
		if prepared_mid.has(key):
			mid_chunks[key]=prepared_mid[key]; mid_chunks[key].show(); prepared_mid.erase(key)
		else: _build_cell(key,false,true)
	_update_mid_edges()

func prepare(location: Vector3) -> void:
	if DisplayServer.get_name()=="headless": return
	var centre := Vector2i(floori(location.x/CELL),floori(location.z/CELL))
	if centre==_prepared_cell: return
	_prepared_cell=centre
	for instance in prepared.values(): instance.free()
	for instance in prepared_mid.values(): instance.free()
	prepared.clear(); prepared_mid.clear(); _preparing.clear()
	for key in _keys_for(location):
		if not chunks.has(key): _preparing.append(key)
	# Prepare the intermediate footprint too. Orientation is resolved at cut.
	for key in _mid_keys(location):
		if not mid_chunks.has(key): _build_cell(key,true,true)

func prewarm(location: Vector3) -> void:
	if DisplayServer.get_name()=="headless": return
	visible=true
	var camera := get_viewport().get_camera_3d()
	_queue_cells(location,camera)
	while not _pending.is_empty(): _build_cell(_pending.pop_front())
	_queue_mid(location,camera)
	_signature=""

func _build_cell(key: Vector2i, staging := false, mid := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true; mm.use_custom_data=true; mm.mesh=mid_tuft if mid else tuft
	var amount := MID_PER_CELL if mid else TUFTS_PER_CELL
	var cell := MID_CELL if mid else CELL
	mm.instance_count=amount
	var random := RandomNumberGenerator.new()
	random.seed=absi(key.x*73856093 ^ key.y*19349663)+(327 if mid else 27)
	var count := 0
	for index in amount:
		var x := (key.x+random.randf())*cell; var z := (key.y+random.randf())*cell
		if absf(x)>52.5 or absf(z)>34: continue
		var wet := surface.sample_at(Vector3(x,0,z))
		if wet.y>.15 or random.randf()<wet.x*.9: continue
		var height: float = game.surface_height(x,z)
		var normal := Vector3((height-game.surface_height(x+.05,z))/.05,1,(height-game.surface_height(x,z+.05))/.05).normalized()
		var angle := random.randf()*TAU
		if not game.venue.worn_surface:
			angle = (PI if floori((x+52.5)/7.5)%2 else 0.0)+random.randf_range(-.45,.45)
		var basis := Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,angle)
		basis=basis.scaled(Vector3(1,random.randf_range(.85,1.15),1))
		mm.set_instance_transform(count,Transform3D(basis,Vector3(x,height-.001,z)))
		mm.set_instance_color(count,Color(random.randf_range(.92,1.02),random.randf_range(.90,1.02),random.randf_range(.88,1.02),1))
		mm.set_instance_custom_data(count,Color(1.0 if _painted(Vector2(x,z)) else 0.0,random.randf(),0,0))
		count+=1
	mm.visible_instance_count=count
	var instance := MultiMeshInstance3D.new()
	instance.name="Grass_%s_%s_%s"%["Mid" if mid else "Near",key.x,key.y]
	instance.multimesh=mm; instance.material_override=mid_material if mid else material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	if staging:
		instance.hide()
		if mid: prepared_mid[key]=instance
		else: prepared[key]=instance
	elif mid: mid_chunks[key]=instance
	else: chunks[key]=instance

func _update_mid_edges() -> void:
	for key: Vector2i in mid_chunks:
		mid_chunks[key].set_instance_shader_parameter("exposed_edges",Vector4(
			0.0 if mid_chunks.has(key+Vector2i.LEFT) else 1.0,
			0.0 if mid_chunks.has(key+Vector2i.RIGHT) else 1.0,
			0.0 if mid_chunks.has(key+Vector2i.UP) else 1.0,
			0.0 if mid_chunks.has(key+Vector2i.DOWN) else 1.0))

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

func draw_triangle_count() -> int:
	var count := tuft_count()*NEAR_TRIANGLES
	for instance in mid_chunks.values(): count+=instance.multimesh.visible_instance_count*MID_TRIANGLES
	return count
