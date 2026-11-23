extends SceneTree
## Export the venue pieces Godot builds in code, for the Unreal port.
##
## The ring, ringside and bowl reach Unreal as Blender-built .glb files. These
## do not: the entrance set's dressing, the barricade LED faces and corner
## logos, and the overhead rig are placed and materialled at runtime by
## core/arena/arena_builder.gd and core/lighting/arena_lighting.gd, and the
## ribbon boards' LED look is a runtime material on a .glb mesh. So this builds
## the real match scene, lets the builders run, and writes what they made:
##
##   <out>.glb   every selected mesh, its world transform baked into its
##               vertices (so every mesh shares the scene origin, which is the
##               ring centre on the mat), one material slot per mesh named
##               "VM_<node name>" and carrying no data
##   <out>.json  per slot, the StandardMaterial3D settings Unreal needs to
##               rebuild it: colours, texture res:// paths, roughness,
##               metallic, normal scale, uv1 scale/offset, emission (colour,
##               texture, energy, operator), transparency, cull
##
## Materials travel as JSON rather than inside the .glb because the textures
## are not reliably readable headless, and because Unreal rebuilds them on its
## own masters anyway (tools/unreal/port_materials.py).
##
## Run from the repo root:
##   godot --headless --path game --script "$PWD/tools/unreal/export_venue.gd" \
##       -- tools/unreal/venue/venue_generated

const SCENE := "res://scenes/match.tscn"
## Node-path prefixes (relative to the match root) whose meshes are exported.
const EXPORT := ["Arena/EntranceSet/", "Arena/OverheadRig/", "LightRig/BarricadeLed",
	"LightRig/BarricadeCorner", "LightRig/BarricadeBlank"]
## Meshes already in Unreal whose runtime material is still wanted.
const MATERIAL_ONLY := ["Arena/BowlModel/RibbonBoards", "Arena/BowlModel/StairNosing"]
const SETTLE_FRAMES := 20


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "venue_generated"
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join("..").path_join(out).simplify_path()
	var match_root: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(match_root)
	for i in SETTLE_FRAMES:
		await process_frame

	var export_root := Node3D.new()
	export_root.name = "VenueGenerated"
	var materials := {}
	var meshes := []
	for n in match_root.find_children("", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var path := str(match_root.get_path_to(mi))
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var wanted := false
		for p: String in EXPORT:
			wanted = wanted or path.begins_with(p)
		var mat_only := path in MATERIAL_ONLY
		if not wanted and not mat_only:
			continue
		var slot := "VM_" + str(mi.name)
		materials[slot] = _describe(_material_of(mi), path)
		if mat_only:
			continue
		meshes.append(path)
		var baked := MeshInstance3D.new()
		baked.name = str(mi.name)
		baked.mesh = _baked(mi.mesh, mi.global_transform, slot)
		export_root.add_child(baked)
	root.add_child(export_root)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(export_root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, out + ".glb")
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"meshes": meshes, "materials": materials}, "  ", true))
	f.close()
	print("export_venue: %d meshes, %d materials -> %s (%s)" % [meshes.size(), materials.size(), out, error_string(err)])
	quit(0 if err == OK else 1)


func _material_of(mi: MeshInstance3D) -> Material:
	if mi.material_override:
		return mi.material_override
	if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0):
		return mi.get_surface_override_material(0)
	return mi.mesh.surface_get_material(0)


## The mesh with `xf` applied to its vertices and normals, every surface on one
## material named `slot`. Surfaces past the first keep their own data but
## share the slot: every exported piece here is single-material.
func _baked(mesh: Mesh, xf: Transform3D, slot: String) -> ArrayMesh:
	var out := ArrayMesh.new()
	var named := StandardMaterial3D.new()
	named.resource_name = slot
	var basis := xf.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = xf * v[i]
		arrays[Mesh.ARRAY_VERTEX] = v
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in nrm.size():
				nrm[i] = (basis * nrm[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_TANGENT] = null
		# A PrimitiveMesh (the barricade faces are QuadMeshes) is always
		# triangles and has no surface_get_primitive_type.
		var prim := (mesh as ArrayMesh).surface_get_primitive_type(s) if mesh is ArrayMesh \
				else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(prim, arrays)
		out.surface_set_material(s, named)
	return out


func _tex(t: Texture2D) -> String:
	if t == null:
		return ""
	return t.resource_path if t.resource_path != "" else "<generated>"


func _col(c: Color) -> Array:
	return [snappedf(c.r, 0.0001), snappedf(c.g, 0.0001), snappedf(c.b, 0.0001), snappedf(c.a, 0.0001)]


func _describe(mat: Material, path: String) -> Dictionary:
	var d := {"node": path}
	if mat is ShaderMaterial:
		d["kind"] = "shader"
		d["shader"] = (mat as ShaderMaterial).shader.resource_path
		return d
	var s := mat as BaseMaterial3D
	if s == null:
		d["kind"] = "none"
		return d
	d["kind"] = "standard"
	d["albedo"] = _col(s.albedo_color)
	d["albedo_texture"] = _tex(s.albedo_texture)
	d["roughness"] = snappedf(s.roughness, 0.0001)
	d["roughness_texture"] = _tex(s.roughness_texture)
	d["metallic"] = snappedf(s.metallic, 0.0001)
	d["specular"] = snappedf(s.metallic_specular, 0.0001)
	d["normal_texture"] = _tex(s.normal_texture) if s.normal_enabled else ""
	d["normal_scale"] = snappedf(s.normal_scale, 0.0001)
	d["ao_texture"] = _tex(s.ao_texture) if s.ao_enabled else ""
	d["uv1_scale"] = [snappedf(s.uv1_scale.x, 0.0001), snappedf(s.uv1_scale.y, 0.0001)]
	d["uv1_offset"] = [snappedf(s.uv1_offset.x, 0.0001), snappedf(s.uv1_offset.y, 0.0001)]
	d["emission_enabled"] = s.emission_enabled
	d["emission"] = _col(s.emission)
	d["emission_texture"] = _tex(s.emission_texture) if s.emission_enabled else ""
	d["emission_energy"] = snappedf(s.emission_energy_multiplier, 0.0001)
	d["emission_operator"] = "multiply" if s.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY else "add"
	d["unshaded"] = s.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	d["transparent"] = s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	d["two_sided"] = s.cull_mode == BaseMaterial3D.CULL_DISABLED
	return d
