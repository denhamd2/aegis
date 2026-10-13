extends Node
## A weapon on the bare floor, beside a mannequin for scale, from five sides:
## the review shot for every No Holds Barred weapon (gauntlet/refs/
## weapons_nhb.md). The same plain set as paired_shot --bare -- grey floor
## gridded every 0.5 m, studio light -- through the game's own renderer, so
## its materials are judged as the game will draw them.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/weapon_shot.tscn -- \
##       --glb res://assets/weapons/steel_chair.glb --out /tmp/chair
##
## --node NAME shows only that root node of the .glb (one state of it: the
## folded chair, the broken table); without it every root node is shown,
## spread out along X so the states sit side by side.
## --yaw DEG turns it about Y first. --lift M raises the weapon M metres (a hand-held one reads better at hip
## height than lying on the floor); default 0.
## Writes <out>/<name>_front.png, _three_quarter.png, _side.png, _top.png,
## _close.png, and prints each node's bounds and triangle count.

const MANNEQUIN := "res://assets/characters/wrestler_base.glb"

var _glb := ""
var _out := "/tmp/weapon"
var _node := ""
var _lift := 0.0
## --yaw DEG turns every shown state about Y (to see a sign's face, say).
var _yaw := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--glb":
				_glb = args[i + 1]
			"--out":
				_out = args[i + 1]
			"--node":
				_node = args[i + 1]
			"--lift":
				_lift = float(args[i + 1])
			"--yaw":
				_yaw = deg_to_rad(float(args[i + 1]))
	DirAccess.make_dir_recursive_absolute(_out)
	var packed := load(_glb) as PackedScene
	if packed == null:
		push_error("weapon_shot: cannot load %s" % _glb)
		get_tree().quit(1)
		return
	_set_stage()
	var weapon: Node3D = packed.instantiate()
	add_child(weapon)
	var shown: Array[Node3D] = []
	for child in weapon.get_children():
		if child is Node3D:
			var n := child as Node3D
			n.visible = _node == "" or String(n.name) == _node
			if n.visible:
				shown.append(n)
	# Side by side along X when several states are shown.
	var x := 0.0
	for n in shown:
		n.position = Vector3(x, n.position.y + _lift, n.position.z)
		n.rotation.y += _yaw
		var b := _bounds(n)
		x += b.size.x + 0.4
	var all := AABB()
	var first := true
	for n in shown:
		var b := _bounds(n)
		print("WEAPON %s size %s tris %d" % [n.name, b.size, _triangles(n)])
		all = b if first else all.merge(b)
		first = false
	var mannequin: Node3D = (load(MANNEQUIN) as PackedScene).instantiate()
	add_child(mannequin)
	mannequin.position = Vector3(all.position.x - 0.7, 0.0, 0.0)
	var centre := all.get_center()
	var reach := maxf(all.size.length(), 1.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 35.0
	var views := {
		"front": Vector3(0.0, 0.35, 1.0),
		"three_quarter": Vector3(0.75, 0.45, 0.75),
		"side": Vector3(1.0, 0.25, 0.0),
		"top": Vector3(0.0, 1.0, 0.001),
	}
	for view: String in views:
		var dir: Vector3 = (views[view] as Vector3).normalized()
		cam.global_position = centre + dir * reach * 2.1
		cam.look_at(centre, Vector3.UP)
		await _grab("%s/%s_%s.png" % [_out, _label(), view])
	# Close on the striking end, or the middle when there is none.
	var strike := weapon.find_child("strike", true, false) as Node3D
	var at := strike.global_position if strike else centre
	cam.global_position = at + Vector3(0.45, 0.25, 0.45) * maxf(reach * 0.35, 0.6)
	cam.look_at(at, Vector3.UP)
	await _grab("%s/%s_close.png" % [_out, _label()])
	get_tree().quit()


func _label() -> String:
	var base := _glb.get_file().get_basename()
	return base if _node == "" else "%s_%s" % [base, _node]


func _grab(path: String) -> void:
	# The settle the capture harness uses: TAA and SSIL need frames to converge.
	for i in 24:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("WROTE %s" % path)


func _set_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.64, 0.67)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	# A neutral studio sky for metals to reflect. With nothing to reflect,
	# every metallic surface rendered black here -- chrome, aluminium, steel
	# -- which is a probe artefact: the arena gives them a hall to reflect.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.78, 0.80, 0.83)
	sky_mat.sky_horizon_color = Color(0.70, 0.71, 0.73)
	sky_mat.ground_horizon_color = Color(0.55, 0.55, 0.56)
	sky_mat.ground_bottom_color = Color(0.30, 0.30, 0.31)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	floor.mesh = plane
	var grid := ShaderMaterial.new()
	grid.shader = Shader.new()
	grid.shader.code = """shader_type spatial;
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = abs(fract(w.xz * 2.0 + 0.5) - 0.5) / fwidth(w.xz * 2.0);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	ALBEDO = mix(vec3(0.42), vec3(0.2), line);
	ROUGHNESS = 0.9;
}"""
	floor.material_override = grid
	add_child(floor)
	for spec in [[Vector3(-50, 35, 0), 1.0, true], [Vector3(-25, -140, 0), 0.45, false]]:
		var light := DirectionalLight3D.new()
		add_child(light)
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.shadow_enabled = spec[2]


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false) \
			+ ([n] if n is MeshInstance3D else []):
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _triangles(n: Node3D) -> int:
	var tris := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false) \
			+ ([n] if n is MeshInstance3D else []):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris
