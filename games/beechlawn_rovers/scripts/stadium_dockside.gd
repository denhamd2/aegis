extends RefCounted
class_name FootballStadiumDockside
static func build(parent: Node3D) -> void:
	var root:Node3D=(load("res://assets/environment/rovers_arena/stadium_docks.glb") as PackedScene).instantiate()
	root.name="Dockside";parent.add_child(root)
	for node in root.find_children("*","MeshInstance3D",true,false):
		if String(node.name).begins_with("Distant") or String(node.name).begins_with("Warehouse") or String(node.name).begins_with("Storage"):
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not "Land" in node.name:node.visibility_range_end=1000
	var info:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/rovers_arena/dockside_manifest.json"))
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/dock_water.gdshader")
	for rectangle:Array in info.water_rectangles:
		var water:=MeshInstance3D.new();water.name="DockWater"
		var plane:=PlaneMesh.new();plane.size=Vector2(float(rectangle[2])-float(rectangle[0]),float(rectangle[3])-float(rectangle[1]));plane.material=material
		water.layers=2;water.mesh=plane;water.position=Vector3((float(rectangle[0])+float(rectangle[2]))*.5,float(info.water_height),(float(rectangle[1])+float(rectangle[3]))*.5)
		water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(water)
	var probe:=ReflectionProbe.new();probe.name="DocksideReflection";probe.position=Vector3(0,0,-135);probe.size=Vector3(330,5,280);probe.cull_mask=1;probe.max_distance=500;probe.update_mode=ReflectionProbe.UPDATE_ONCE
	root.add_child(probe)
