extends SceneTree
## Bakes Roman as the game shows him, for the Unreal port.
##
## RomanModel corrects the user-supplied roman_reigns.glb at runtime -- his
## build (BodyBulk), his face (RomanFaceShape), the beard trim, the hair's
## volume and root-to-tip shade, the flyaways, the ringlets and the scalp
## roots -- none of which exists in the .glb Unreal imported. This runs that
## _ready() headless and writes the edited meshes, on their own skeletons and
## with their weights, as one glTF the port re-imports over the raw parts.
##
## Geometry only: Unreal keeps its own material instances (port_materials.py),
## so the materials are written as plain named slots.
##
## Unreal binds his parts to two skeletons -- the body's (J_Hips) and the
## clothes and hair's (ProxyTrueRootJoint; both have a J_Hips, so they are
## told apart by size: the body's 114 bones, the clothes' 471) -- and imports one skeleton per
## file, so the second argument picks which half to write:
##
##   godot --headless -s res://tools/unreal_export/roman_bake.gd -- <out.glb> body|clothes

const MODEL := "res://scenes/roman_model.tscn"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/roman_baked.glb"
	var half := args[1] if args.size() > 1 else "body"
	var model := (load(MODEL) as PackedScene).instantiate()
	root.add_child(model)
	# _ready has run. Strip what is not geometry: the eye-lid helper nodes are
	# meshes too and stay; animation players and modifiers do not export.
	for node in model.find_children("", "AnimationPlayer", true, false):
		node.queue_free()
	for node in model.find_children("", "AnimationTree", true, false):
		node.queue_free()
	await process_frame
	var report := {}
	for mi: MeshInstance3D in model.find_children("", "MeshInstance3D", true, false):
		# Bake each surface's override (the edited material) back as a plain
		# slot named after the source material, so Unreal can match it.
		if mi.mesh == null:
			continue
		var rig := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var body := rig != null and rig.get_bone_count() < 200
		if not mi.visible or rig == null or body != (half == "body"):
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		# Its own copy: PortraitRoots draws the head's very mesh, and naming
		# one's slots would rename the other's.
		mi.mesh = mi.mesh.duplicate()
		var names := []
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var slot := src.resource_name if src else ""
			if mi.material_override and mi.material_override.resource_name != "":
				slot = mi.material_override.resource_name
			if slot == "":
				slot = str(mi.name)
			var plain := StandardMaterial3D.new()
			plain.resource_name = slot
			mi.set_surface_override_material(s, plain)
			mi.mesh.surface_set_material(s, plain)
			names.append(slot)
		mi.material_override = null
		report[str(mi.name)] = {"verts": mi.mesh.get_faces().size(), "materials": names,
			"skeleton": str(mi.skeleton)}
	# Only this half's skeleton goes in the file: with both, the exporter
	# renames the second one's bones (J_Hips2...) to keep node names unique,
	# and Unreal would no longer match them to the skeleton it has. The rest
	# of the bones go back to their rest pose (the bind pose Unreal reads),
	# and the per-frame modifiers (RomanHeadShape) come off.
	for rig: Skeleton3D in model.find_children("", "Skeleton3D", true, false):
		if (rig.get_bone_count() < 200) != (half == "body"):
			rig.get_parent().remove_child(rig)
			rig.free()
			continue
		for child in rig.get_children():
			if child is SkeletonModifier3D:
				rig.remove_child(child)
				child.free()
		rig.reset_bone_poses()
		# apply_physique_height scales the rig's parent per match; Unreal's
		# skeletons were imported at 1 and size him their own way.
		var holder := rig.get_parent() as Node3D
		if holder:
			holder.scale = Vector3.ONE
	# The eye lids are a runtime rig (EyeLids, its own nodes under the
	# skeleton) that the port does not have: written out, its nodes become
	# bones Unreal's skeleton does not know. Last, as the rig rebuilds them.
	for mount in model.find_children("EyeLidMount", "", true, false):
		mount.get_parent().remove_child(mount)
		mount.free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(model, state)
	if err == OK:
		err = doc.write_to_filesystem(state, out)
	print(JSON.stringify(report, "  "))
	print("roman_bake: %s -> %s" % [error_string(err), out])
	quit(0 if err == OK else 1)
