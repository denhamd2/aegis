extends Node
## Hour-one asset audit for a supplied character .glb. Prints the facts that
## every wrestler-import bug so far turned out to be knowable from, before a
## line of adapter code exists.
##
## It answers, in one run:
##   * how many skeletons is this rigged on, and which meshes ride which one
##   * which materials have no albedo, or point albedo at a packed data map
##   * where the model's origin sits (feet or pelvis) and how tall it is
##   * which axis its own locomotion clips call forward
##
## Usage, from the repo root:
##   godot4 --headless --path game tools/probe/audit_model.tscn \
##       -- --glb res://assets/characters/<name>.glb
##
## Optionally --base res://assets/characters/<other>.glb to print a different
## source rig's bone list; the default is the base rig a BONE_MAP maps onto.
##
## Read the output top to bottom. Anything printed with a leading "!!" is a
## finding that will produce a visible defect if left alone.

const DEFAULT_BASE := "res://assets/characters/wrestler_base.glb"

## A material whose albedo is a packed data map renders as a flat saturated
## colour. R and B carrying near-identical data with a different G is the
## signature: that is a mask packed into green, not a colour texture.
const PACKED_R_B_TOLERANCE := 8.0

var _glb := ""
var _base := DEFAULT_BASE
var _skeleton_of_mesh := {}
var _missing_albedo: Array[String] = []
var _packed_albedo: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--glb" and i + 1 < args.size():
			_glb = args[i + 1]
		elif args[i] == "--base" and i + 1 < args.size():
			_base = args[i + 1]
	if _glb == "":
		push_error("audit_model: pass --glb res://path/to/model.glb")
		get_tree().quit(1)
		return

	var packed := load(_glb) as PackedScene
	if packed == null:
		push_error("audit_model: %s did not load as a PackedScene" % _glb)
		get_tree().quit(1)
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame

	print("\n================ AUDIT: %s ================" % _glb)
	_report_skeletons(root)
	_report_meshes(root)
	_report_extents(root)
	_report_animations(root)
	_report_base_rig()
	print("\n================ END AUDIT ================")
	get_tree().quit(0)


# --- skeletons -------------------------------------------------------------

## The single most important section. A model rigged on more than one skeleton
## needs apply_physique_height() to scale ALL of them; scaling one resizes part
## of the character inside the rest of it, which is what produced a bald crown,
## skin through the trousers and a displaced beard from one line of code.
func _report_skeletons(root: Node) -> void:
	print("\n--- SKELETONS ---")
	var skeletons := root.find_children("", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("!! no Skeleton3D at all -- this is not a rigged model")
		return
	for node in skeletons:
		var skeleton := node as Skeleton3D
		var roots: Array[String] = []
		for bone in skeleton.get_bone_count():
			if skeleton.get_bone_parent(bone) == -1:
				roots.append(skeleton.get_bone_name(bone))
		print("  %s" % root.get_path_to(skeleton))
		print("    bones=%d  roots=%s" % [skeleton.get_bone_count(), roots])
		print("    first 12 bones: %s" % [_first_bones(skeleton, 12)])
	if skeletons.size() > 1:
		print("!! rigged on %d skeletons. apply_physique_height() must scale"
				% skeletons.size())
		print("!! every one of them, and the mesh table below says which parts")
		print("!! ride which -- expect the split to be BODY vs EVERYTHING WORN,")
		print("!! not head vs body.")


func _first_bones(skeleton: Skeleton3D, count: int) -> Array[String]:
	var out: Array[String] = []
	for bone in mini(count, skeleton.get_bone_count()):
		out.append(skeleton.get_bone_name(bone))
	return out


# --- meshes and materials --------------------------------------------------

## Mesh -> skeleton -> material -> texture, in one table. Every material fault
## found so far is visible here: a card with no albedo (renders as an opaque
## slab and z-fights the real geometry), an albedo pointing at a *_rai / _orm /
## packed map (renders magenta), a duplicate "entrance" set overlapping the
## normal one, or a mesh riding the skeleton nobody thought to scale.
func _report_meshes(root: Node) -> void:
	print("\n--- MESHES, MATERIALS, TEXTURES ---")
	var by_skeleton := {}
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var skeleton_name := "(unskinned)"
		if not mesh_instance.skeleton.is_empty():
			var target := mesh_instance.get_node_or_null(mesh_instance.skeleton)
			if target is Skeleton3D:
				skeleton_name = "%s[%d bones]" % [
						target.name, (target as Skeleton3D).get_bone_count()]
		_skeleton_of_mesh[mesh_instance.name] = skeleton_name
		by_skeleton[skeleton_name] = int(by_skeleton.get(skeleton_name, 0)) + 1

		print("\n  %s   skeleton=%s   visible=%s   surfaces=%d" % [
				mesh_instance.name, skeleton_name, mesh_instance.visible,
				mesh_instance.mesh.get_surface_count()])
		for surface in mesh_instance.mesh.get_surface_count():
			_report_surface(mesh_instance, surface)

	print("\n  meshes per skeleton:")
	for key in by_skeleton:
		print("    %-28s %d meshes" % [key, by_skeleton[key]])
	if by_skeleton.size() > 1:
		print("!! confirm which of these groups physique_height reaches.")

	print("\n  SUMMARY")
	print("    materials with no base colour (%d): %s" % [
			_missing_albedo.size(), ", ".join(_missing_albedo)])
	print("      -> each needs an ALBEDO_FIXES entry, a reconnected texture, or")
	print("         hiding. Before inventing a colour, check whether the asset")
	print("         ships an unreferenced map that belongs here: count the")
	print("         images the .glb embeds against the ones materials name.")
	print("    albedo slots holding packed data maps (%d): %s" % [
			_packed_albedo.size(), ", ".join(_packed_albedo)])
	print("      -> confirm each with inspect_textures.py, then rebuild as")
	print("         white RGB + mask-as-alpha and tint at runtime.")


func _report_surface(mesh_instance: MeshInstance3D, surface: int) -> void:
	var material := mesh_instance.mesh.surface_get_material(surface)
	if material == null:
		print("    surface %d: NO MATERIAL AT ALL -- renders default grey" % surface)
		print("!!    %s surface %d has no material to inspect; it has to be"
				% [mesh_instance.name, surface])
		print("!!    found by node name if it needs a colour (mouth, teeth).")
		return
	var base := material as BaseMaterial3D
	var name := material.resource_name if material.resource_name != "" \
			else "(unnamed)"
	if base == null:
		print("    surface %d: %s (not a BaseMaterial3D)" % [surface, name])
		return

	var albedo := base.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
	var albedo_file := albedo.resource_path.get_file() if albedo else ""
	print("    surface %d: %-18s albedo=%-32s transparency=%s cull=%s" % [
			surface, name,
			albedo_file if albedo_file != "" else "<NONE>",
			_transparency_name(base.transparency),
			_cull_name(base.cull_mode)])
	for slot: Array in [
			["normal", BaseMaterial3D.TEXTURE_NORMAL],
			["orm", BaseMaterial3D.TEXTURE_ORM],
			["roughness", BaseMaterial3D.TEXTURE_ROUGHNESS],
			["metallic", BaseMaterial3D.TEXTURE_METALLIC]]:
		var tex := base.get_texture(slot[1])
		if tex:
			print("               %-9s %s" % [slot[0], tex.resource_path.get_file()])

	if albedo == null:
		_missing_albedo.append("%s (%s)" % [name, mesh_instance.name])
		print("!!    %s has NO base colour -- it renders flat white." % name)
		var is_card := mesh_instance.name.to_lower().contains("alpha")
		if is_card and base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			print("!!    This mesh is named as an ALPHA CARD and yet transparency")
			print("!!    is DISABLED with no mask to sample, so it cannot render as")
			print("!!    hair or cloth under any threshold -- it draws as an opaque")
			print("!!    slab and z-fights the real card next to it. Whichever")
			print("!!    surface wins the depth test then decides how the head")
			print("!!    reads, which is why such a fault looks like a per-wrestler")
			print("!!    or per-camera-angle bug rather than a material bug.")
			print("!!    Hide it unless a mask exists for it somewhere in the asset.")
	elif _looks_like_packed_map(albedo):
		_packed_albedo.append("%s (%s)" % [name, albedo_file])
		print("!!    %s points albedo at what looks like a PACKED DATA MAP" % name)
		print("!!    (%s). R and B carry near-identical data; the mask is" % albedo_file)
		print("!!    almost certainly in GREEN. Fed in as colour this renders")
		print("!!    magenta. Rebuild as white RGB + green-as-alpha and tint")
		print("!!    at runtime -- see scripts/inspect_textures.py.")


## Cheap heuristic on a downscaled copy: identical R and B against a different
## G is what a packed mask looks like and what no skin or fabric albedo looks
## like. Confirm with inspect_textures.py before acting.
func _looks_like_packed_map(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null:
		return false
	image = image.duplicate()
	image.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	if image.is_compressed():
		image.decompress()
	var totals := Vector3.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			totals += Vector3(c.r, c.g, c.b)
	totals /= float(image.get_width() * image.get_height())
	totals *= 255.0
	return absf(totals.x - totals.z) < PACKED_R_B_TOLERANCE \
			and absf(totals.x - totals.y) > PACKED_R_B_TOLERANCE * 2.0


func _transparency_name(mode: int) -> String:
	match mode:
		BaseMaterial3D.TRANSPARENCY_DISABLED: return "DISABLED"
		BaseMaterial3D.TRANSPARENCY_ALPHA: return "ALPHA"
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "SCISSOR"
		BaseMaterial3D.TRANSPARENCY_ALPHA_HASH: return "HASH"
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: return "DEPTH_PRE_PASS"
	return str(mode)


func _cull_name(mode: int) -> String:
	match mode:
		BaseMaterial3D.CULL_BACK: return "BACK"
		BaseMaterial3D.CULL_FRONT: return "FRONT"
		BaseMaterial3D.CULL_DISABLED: return "DISABLED"
	return str(mode)


# --- extents ---------------------------------------------------------------

## Where the origin sits decides what a 90-degree pitch does to a thrown body.
## A model whose origin is at its FEET, laid flat at root y=0, hangs its entire
## length below the mat -- the "he sinks into the ring" report.
func _report_extents(root: Node) -> void:
	print("\n--- EXTENTS ---")
	var aabb := _world_aabb(root)
	print("  AABB position=%.3v size=%.3v centre=%.3v" % [
			aabb.position, aabb.size, aabb.get_center()])
	print("  height=%.3f m  width=%.3f m  depth=%.3f m" % [
			aabb.size.y, aabb.size.x, aabb.size.z])
	var bottom := aabb.position.y
	if absf(bottom) < 0.05:
		print("  origin is at the FEET (AABB bottom y=%.3f)" % bottom)
		print("!! a body pitched flat at root y=0 hangs its whole length below")
		print("!! the mat. Guard it with an upright-on-landing invariant test.")
	else:
		print("  origin is NOT at the feet (AABB bottom y=%.3f)" % bottom)
	if aabb.size.y < 1.2 or aabb.size.y > 2.6:
		print("!! height %.2f m is outside a plausible human range -- the export"
				% aabb.size.y)
		print("!! scale is probably wrong (cm vs m). Fix it at import, not with")
		print("!! a scale on the scene node.")


func _world_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for visual in _visuals(node):
		var world := visual.global_transform * visual.get_aabb()
		if first:
			out = world
			first = false
		else:
			out = out.merge(world)
	return out


func _visuals(node: Node) -> Array[VisualInstance3D]:
	var found: Array[VisualInstance3D] = []
	if node is VisualInstance3D and (node as VisualInstance3D).visible:
		found.append(node)
	for child in node.get_children():
		found.append_array(_visuals(child))
	return found


# --- animations and forward axis -------------------------------------------

## Godot treats -Z as forward, and every look_at() and -basis.z in this project
## assumes it. A rig whose own walk cycle translates along +Z needs a 180-degree
## yaw on the CharacterModel node, or every wrestler renders facing away from
## the man he is aimed at -- which a transform-space assertion will happily
## report as correct.
func _report_animations(root: Node) -> void:
	print("\n--- ANIMATIONS ---")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		print("  none. Clips will have to be retargeted in from the base rig;")
		print("  see references/wiring.md for adapt_animation_library().")
		return
	var names := player.get_animation_list()
	print("  %d clips: %s" % [names.size(), ", ".join(names)])
	print("\n  root translation per clip (dX, dZ) -- forward axis evidence:")
	for name in names:
		var animation := player.get_animation(name)
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var count := animation.track_get_key_count(track)
			if count < 2:
				continue
			var first: Vector3 = animation.track_get_key_value(track, 0)
			var last: Vector3 = animation.track_get_key_value(track, count - 1)
			var delta := last - first
			if delta.length() < 0.5:
				continue
			print("    %-24s %-22s dX=%+.2f dZ=%+.2f" % [
					name, animation.track_get_path(track), delta.x, delta.z])
	print("  If forward clips move along +Z, the rig's forward is +Z and Godot's")
	print("  is -Z: yaw the model node 180 degrees and pin it with a test.")


# --- base rig --------------------------------------------------------------

## The bone list a BONE_MAP is written against. Print both sides once rather
## than guessing names one missing bone at a time.
func _report_base_rig() -> void:
	var packed := load(_base) as PackedScene
	if packed == null:
		print("\n--- BASE RIG --- (%s not loadable, skipped)" % _base)
		return
	var root: Node = packed.instantiate()
	var skeleton: Skeleton3D = null
	for node in root.find_children("", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	if skeleton == null:
		root.free()
		return
	print("\n--- BASE RIG BONES (%s, %d) ---" % [_base.get_file(),
			skeleton.get_bone_count()])
	var names: Array[String] = []
	for bone in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(bone))
	print("  %s" % ", ".join(names))
	print("  Every one of these that a game system names must appear in the new")
	print("  model's BONE_MAP, or the retarget silently drops that track.")
	root.free()
