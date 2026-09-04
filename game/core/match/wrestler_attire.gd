class_name WrestlerAttire
extends RefCounted
## Builds a wrestler's gear as geometry attached to his skeleton: trunks and
## belt, boots and cuffs, kneepads, elbow pads, wristbands.
##
## This exists because of a measurement, not a wish for detail. VISUAL_BAR.md
## reads the reference's wrestlers at 0.24-0.31 in relative luminance *below*
## the mat, and its two men within 0.07 of *each other* -- they separate from
## the mat by value and from each other by hue. Ours could not sit in that
## band: the CC0 mannequin is a single skinned mesh with one colour over the
## whole body, so a wrestler's average luminance was just his attire colour,
## and a saturated attire colour dark enough to clear the mat by 0.24 puts the
## two men far more than 0.07 apart the moment their hues differ. Measured on
## the spawn standoff, blue read 0.023 and red 0.139 -- 0.116 apart, where the
## reference allows 0.07.
##
## A real wrestler is mostly *skin*, which is a mid value, with saturated gear
## over part of it. That is what puts both men at a similar luminance while
## letting their colours differ, and it is the mechanism the reference is
## describing. So the mannequin's body becomes skin and the colourway moves
## onto gear that is actually there.
##
## Geometry rather than a texture because the rig's UV layout is unknown and
## painting trunks into a texture would mean guessing at it; bone attachments
## need no UVs and follow the pose correctly through every paired move.
##
## Every bone on this rig runs +Y toward its child -- verified off the .glb
## (thigh->calf, calf->foot, upperarm->lowerarm, lowerarm->hand and the spine
## chain all measure the child at +Y in the parent bone's local space) -- so a
## piece is placed by naming its bone and how far along it sits.
##
## Purely cosmetic: no CollisionObject3D, no physics layer, nothing gameplay
## reads. The capsule in wrestler.tscn remains the only collider.

## One piece of gear. `along` is metres up the bone's +Y from its origin;
## `radius`/`height` size a cylinder; `accent` picks the colourway's second
## colour instead of its first.
class Piece:
	var bone: String
	var along: float
	var radius: float
	var height: float
	var accent: bool

	func _init(p_bone: String, p_along: float, p_radius: float,
			p_height: float, p_accent: bool) -> void:
		bone = p_bone
		along = p_along
		radius = p_radius
		height = p_height
		accent = p_accent

## Sized against this rig's own proportions (a ~1.8m humanoid whose calf runs
## 0.43m and forearm 0.27m), not against any reference measurement --
## `gauntlet/refs/` measures nothing about gear proportions, so these are
## engineering values and are not defended as how it should look.
static func pieces() -> Array:
	var out: Array = []
	# Trunks and belt.
	out.append(Piece.new("pelvis", 0.02, 0.185, 0.28, false))
	out.append(Piece.new("pelvis", 0.16, 0.192, 0.055, true))
	for side: String in ["l", "r"]:
		# The boot over the foot itself. The foot bone runs +Y toward the toes
		# like every other bone here, so a cylinder along it lies flat rather
		# than standing up. Without this the calf boot stopped at the ankle
		# and the wrestler fought barefoot.
		out.append(Piece.new("foot_" + side, 0.055, 0.072, 0.20, false))
		# Boot, and its cuff at the top.
		out.append(Piece.new("calf_" + side, 0.30, 0.098, 0.27, false))
		out.append(Piece.new("calf_" + side, 0.175, 0.107, 0.055, true))
		# Kneepad, sitting on the knee end of the calf bone.
		out.append(Piece.new("calf_" + side, 0.035, 0.105, 0.13, true))
		# Elbow pad and wristband.
		out.append(Piece.new("lowerarm_" + side, 0.025, 0.068, 0.10, true))
		out.append(Piece.new("lowerarm_" + side, 0.225, 0.062, 0.06, true))
	return out


## Name prefix on every attachment. BoneAttachment3D resolves its bone from
## its *parent*, so each one has to be a direct child of the Skeleton3D --
## grouping them under a tidy "Attire" node left every piece sitting at the
## skeleton's origin instead of on its bone, which rendered as a pile of
## cylinders around the wrestler's feet. The prefix is what replaces that
## grouping node for finding and counting the gear.
const PREFIX := "Attire_"

## How many pieces a fully dressed wrestler carries. Named so a test can
## assert the gear is actually there rather than counting by hand.
static func piece_count() -> int:
	return pieces().size()

## Head pieces per body variant. The CC0 mannequin has no face, so at
## match-camera distance two men read as the same blank head twice. These are
## rotationally symmetric cylinders on the Head bone (no facing math, no UVs):
## variant 0 gets hair + headband, variant 1 gets a luchador-style mask + eye
## band. First-pass engineering values, tunable in a gauntlet round once a
## capture shows them.
static func head_pieces(variant: int) -> Array:
	var out: Array = []
	if variant == 1:
		# Mask hood over the whole head, body colour; dark eye band as accent.
		out.append(Piece.new("Head", 0.06, 0.135, 0.24, false))
		out.append(Piece.new("Head", 0.10, 0.142, 0.06, true))
	else:
		# Hair cap in body colour (reads as dyed-to-kit) with a sweat
		# headband in accent at the brow line.
		out.append(Piece.new("Head", 0.14, 0.125, 0.12, false))
		out.append(Piece.new("Head", 0.05, 0.132, 0.045, true))
	return out

## Full outfit size for a variant: body gear plus that variant's head set.
static func total_piece_count(variant: int = 0) -> int:
	return pieces().size() + head_pieces(variant).size()

static func build(skeleton: Skeleton3D, body: Color, accent: Color,
		bulk: float = 1.0, variant: int = 0) -> int:
	if skeleton == null:
		return 0
	for child in skeleton.get_children():
		if String(child.name).begins_with(PREFIX):
			return 0 # already dressed
	var built := 0

	# Same reason wrestler_controller.gd's _apply_colorway() skips headless: a
	# freshly constructed material has no RID under the dummy renderer CI runs
	# tests on, and assigning one logs `Parameter "material" is null` per
	# surface. The geometry is still built there so tests can assert the gear
	# exists and where it sits; only the colours are skipped, and they are
	# asserted separately from the colourway itself.
	var headless := DisplayServer.get_name() == "headless"
	var body_material: StandardMaterial3D = null if headless else _material(body)
	var accent_material: StandardMaterial3D = null if headless else _material(accent)

	# Body gear plus this variant's head set. Head pieces reuse the colourway
	# (hair/mask in body colour, band in accent) so each man still reads in
	# his own hue without adding new colours for the critic to chase.
	var all_pieces: Array = pieces() + head_pieces(variant)
	for piece: Piece in all_pieces:
		var bone_index := skeleton.find_bone(piece.bone)
		if bone_index < 0:
			push_warning("WrestlerAttire: rig has no bone '%s'" % piece.bone)
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "%s%s_%d" % [PREFIX, piece.bone, built]
		skeleton.add_child(attachment)
		attachment.bone_name = piece.bone
		attachment.bone_idx = bone_index

		var mesh := CylinderMesh.new()
		# `bulk` widens a wrestler without lengthening him, so two men built
		# from one mannequin differ in build rather than only in colour.
		mesh.top_radius = piece.radius * bulk
		mesh.bottom_radius = piece.radius * bulk
		mesh.height = piece.height
		mesh.radial_segments = 12
		mesh.rings = 1

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		if not headless:
			instance.material_override = \
					accent_material if piece.accent else body_material
		# The bone's +Y runs toward its child and CylinderMesh is Y-up, so the
		# piece needs no rotation -- only a slide along the bone.
		instance.position = Vector3(0.0, piece.along, 0.0)
		attachment.add_child(instance)
		built += 1
	return built


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Matching the body's response so gear and skin read as one lit subject
	# rather than as separately-lit props (VISUAL_BAR.md priority 2).
	mat.roughness = 0.72
	mat.metallic = 0.0
	return mat
