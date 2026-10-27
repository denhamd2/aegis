extends RefCounted
class_name FootballSupporterAssets
## Football-owned outputs of the pinned MIT Rocketbox source. Shared GPU assets.
const ROOT:="res://assets/characters/supporters/"
const STATES:=["Seated","Attention","Rise","Clap","Cheer","Disappoint","Flag","Sit","Stand"]
static var _lods:Dictionary={}
static var _heroes:Dictionary={}
static var _audits:Dictionary={}
static func audit(avatar:int) -> Dictionary:
	if not _audits.has(avatar):_audits[avatar]=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"fan_%02d_audit.json"%avatar))
	return _audits[avatar]
static func lod(avatar:int,level:int) -> Dictionary:
	var key:=avatar*3+level
	if _lods.has(key):return _lods[key]
	var prefix:=ROOT+"fan_%02d_lod%d"%[avatar,level]
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+".json"))
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var colours:=PackedColorArray()
	for i in int(data.vertex_count):
		vertices.append(Vector3(data.vertices[i*3],data.vertices[i*3+1],data.vertices[i*3+2]))
		normals.append(Vector3(data.normals[i*3],data.normals[i*3+1],data.normals[i*3+2]))
		uv.append(Vector2(data.uv[i*2],1.0-float(data.uv[i*2+1])));uv2.append(Vector2(i,data.shirt[i]))
		colours.append(Color(data.colour[i*4],data.colour[i*4+1],data.colour[i*4+2]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(data.indices)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var minimum:=Vector3(data.aabb_min[0],data.aabb_min[1],data.aabb_min[2]);var maximum:=Vector3(data.aabb_max[0],data.aabb_max[1],data.aabb_max[2])
	mesh.custom_aabb=AABB(minimum-Vector3.ONE*.08,maximum-minimum+Vector3.ONE*.16)
	data["mesh"]=mesh
	# Signed positions/normals must stay RGBA half-float; RGBE loses negatives.
	data["positions"]=load(prefix+"_positions.exr")
	data["normal_texture"]=load(prefix+"_normals.exr") if level==0 else null
	_lods[key]=data
	return data
static func material(avatar:int,level:int) -> ShaderMaterial:
	var data:=lod(avatar,level)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/supporter_vat.gdshader") if level==0 else preload("res://shaders/supporter_vat_far.gdshader")
	mat.set_shader_parameter("positions",data.positions);mat.set_shader_parameter("normals",data.normal_texture)
	mat.set_meta("avatar",avatar);mat.set_meta("level",level)
	mat.set_shader_parameter("vertex_count",int(data.vertex_count));mat.set_shader_parameter("texture_width",int(data.width));mat.set_shader_parameter("texture_height",int(data.height))
	mat.set_shader_parameter("photo",load(ROOT+"fan_%02d.png"%avatar));mat.set_shader_parameter("photographic",level==0)
	return mat
static func hero(avatar:int,park:=false) -> Node3D:
	if not _heroes.has(avatar):_heroes[avatar]=load(ROOT+"fan_%02d.glb"%avatar)
	var instance:Node3D=(_heroes[avatar] as PackedScene).instantiate()
	var photo:Material
	if park:
		var casual:=StandardMaterial3D.new();casual.albedo_texture=load(ROOT+"fan_%02d.png"%avatar);casual.roughness=.86;casual.cull_mode=BaseMaterial3D.CULL_DISABLED
		photo=casual
	else:
		var garment:=ShaderMaterial.new();garment.shader=preload("res://shaders/supporter_hero.gdshader");garment.set_shader_parameter("photo",load(ROOT+"fan_%02d.png"%avatar))
		photo=garment
	for mesh:MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):mesh.material_override=photo;mesh.layers=4
	return instance
static func animation(player:AnimationPlayer,state:String) -> StringName:
	for clip in player.get_animation_list():
		if String(clip).ends_with("Fan_"+state):return clip
	return &""
static func hand(avatar:int,state:String,seconds:float) -> Vector3:
	var data:=audit(avatar);var samples:Array=data.hands[state]
	var duration:float=data.clips[state]
	var at:=clampf(seconds/duration,0,1) if state in ["Rise","Sit"] else fposmod(seconds,duration)/duration
	var frame:=at*(samples.size()-1);var i:=mini(int(frame),samples.size()-1);var j:=mini(i+1,samples.size()-1)
	return Vector3(samples[i][0],samples[i][1],samples[i][2]).lerp(Vector3(samples[j][0],samples[j][1],samples[j][2]),frame-i)
