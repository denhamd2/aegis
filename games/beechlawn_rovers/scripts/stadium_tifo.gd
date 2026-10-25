extends Node3D
class_name FootballStadiumTifo
var profile:FootballTifoProfile
var material:ShaderMaterial
var reveal:=0.0
var cloth_clock:=0.0
var suspension:Array[MeshInstance3D]=[]
func setup(value:FootballTifoProfile) -> void:
	profile=value;name="HomeEndTifo";position=profile.position;rotation.y=profile.yaw
	var model:Node3D=(load(profile.model_path) as PackedScene).instantiate();add_child(model)
	material=ShaderMaterial.new();material.shader=preload("res://shaders/stadium_tifo.gdshader");material.set_shader_parameter("print_texture",load(profile.texture_path));material.set_shader_parameter("cloth_height",profile.height)
	for node:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):node.material_override=material
	var wire_material:=StandardMaterial3D.new();wire_material.albedo_color=Color(.24,.26,.27);wire_material.metallic=.75;wire_material.roughness=.6
	for x in [-2.0,2.0]:
		var cable:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.012;cylinder.bottom_radius=.012;cylinder.radial_segments=5;cylinder.material=wire_material
		cable.mesh=cylinder;cable.position.x=x;add_child(cable);suspension.append(cable)
	set_reveal(0);hide()
func set_reveal(value:float) -> void:
	reveal=clampf(value,0,1);material.set_shader_parameter("reveal",reveal)
	var drop:=.6/profile.height
	var attach:=profile.height-minf(drop,reveal)*profile.height-maxf(0,drop-reveal)*.25
	for cable in suspension:
		(cable.mesh as CylinderMesh).height=32.5-attach;cable.position.y=(32.5+attach)*.5
func _process(delta:float) -> void:
	if not visible:return
	cloth_clock+=delta;material.set_shader_parameter("cloth_time",cloth_clock)
