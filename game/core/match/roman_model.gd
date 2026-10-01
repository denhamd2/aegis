class_name RomanModel
extends Node3D
## Adapts the user-supplied Roman model to the game's universal wrestler rig.
## The source has no animations, so the base rig's animation library is reused
## after its tracks are remapped to Roman's named body bones.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"

## The fingers are one bone further down Roman's chain than their names
## suggest: his J_*F0 bones are the METACARPALS, 3-4 cm out of the wrist inside
## the palm, and F1-F3 are the three phalanges -- where the mannequin's
## *_01-*_03 are. They were mapped 01 -> F0, so every finger curl bent the
## palm instead of the knuckle: curled fingers folded out of the hand into a
## claw and the pointing hand's thumb stuck out beside them. The thumbs number
## from F1 on both rigs (metacarpal first) and were always right.
const BONE_MAP := {
	"pelvis": "J_Hips",
	"spine_01": "J_Spine1",
	"spine_02": "J_Spine2",
	"spine_03": "J_Chest",
	"neck_01": "J_Neck",
	"Head": "J_Head",
	"clavicle_l": "J_Clavicle_L",
	"upperarm_l": "J_Shoulder_L",
	"lowerarm_l": "J_Elbow_L",
	"hand_l": "J_Wrist_L",
	"index_01_l": "J_IndexF1_L",
	"index_02_l": "J_IndexF2_L",
	"index_03_l": "J_IndexF3_L",
	"middle_01_l": "J_MiddleF1_L",
	"middle_02_l": "J_MiddleF2_L",
	"middle_03_l": "J_MiddleF3_L",
	"pinky_01_l": "J_PinkyF1_L",
	"pinky_02_l": "J_PinkyF2_L",
	"pinky_03_l": "J_PinkyF3_L",
	"ring_01_l": "J_RingF1_L",
	"ring_02_l": "J_RingF2_L",
	"ring_03_l": "J_RingF3_L",
	"thumb_01_l": "J_ThumbF1_L",
	"thumb_02_l": "J_ThumbF2_L",
	"thumb_03_l": "J_ThumbF3_L",
	"clavicle_r": "J_Clavicle_R",
	"upperarm_r": "J_Shoulder_R",
	"lowerarm_r": "J_Elbow_R",
	"hand_r": "J_Wrist_R",
	"index_01_r": "J_IndexF1_R",
	"index_02_r": "J_IndexF2_R",
	"index_03_r": "J_IndexF3_R",
	"middle_01_r": "J_MiddleF1_R",
	"middle_02_r": "J_MiddleF2_R",
	"middle_03_r": "J_MiddleF3_R",
	"pinky_01_r": "J_PinkyF1_R",
	"pinky_02_r": "J_PinkyF2_R",
	"pinky_03_r": "J_PinkyF3_R",
	"ring_01_r": "J_RingF1_R",
	"ring_02_r": "J_RingF2_R",
	"ring_03_r": "J_RingF3_R",
	"thumb_01_r": "J_ThumbF1_R",
	"thumb_02_r": "J_ThumbF2_R",
	"thumb_03_r": "J_ThumbF3_R",
	"thigh_l": "J_Leg_L",
	"calf_l": "J_Knee_L",
	"foot_l": "J_Foot_L",
	"ball_l": "J_Toe_L",
	"thigh_r": "J_Leg_R",
	"calf_r": "J_Knee_R",
	"foot_r": "J_Foot_R",
	"ball_r": "J_Toe_R",
}

## Materials the supplied .glb ships with no base colour at all, and the
## colour each should have.
##
## Seven of the model's sixteen materials carry only a normal map, so they
## render flat white -- including `Material.001`, which is the *face*. The
## missing albedo is not a lost file: the .glb embeds fourteen images, the
## repo carries the same fourteen as loose PNGs, and no material references a
## fifteenth. For the head the colour does exist and was simply not wired up
## (`body_color` already carries the head UVs -- `Material.009`, the eye
## caruncle, samples it), so that one is a reconnection. For the clothing and
## the wrist wear no colour texture exists anywhere in the asset, so those get
## a flat tint chosen to match Roman's actual ring gear rather than an
## invented texture. Both cases are called out per entry below.
const ALBEDO_FIXES := {
	# Face. body_color.png is a 4096x2048 atlas holding skin, the tribal
	# sleeve, the trunks and the mouth interior; the head UVs are in it.
	"Material.001": {"texture": "head_color", "color": Color.WHITE},
	# Ring gear. No colour texture for these exists in the asset -- only
	# tops_nrm/bottoms_nrm. Black matches the gear Roman actually wrestles in,
	# and the normal maps still carry the fabric detail.
	"Material.003": {"color": Color(0.055, 0.055, 0.062)}, # tops
	"Material.004": {"color": Color(0.045, 0.045, 0.052)}, # bottoms
	# Wrist tape and the arm accessory: same situation, only normal maps.
	"Material.006": {"color": Color(0.82, 0.80, 0.76)}, # l_wrist
	"Material.007": {"color": Color(0.82, 0.80, 0.76)}, # r_wrist
	"Material.012": {"color": Color(0.10, 0.10, 0.11)}, # r_a_acce
	# The eyes (Material.013) and lashes (Material.016) are not here: they
	# get whole materials of their own, textured (_fix_eyes).
}

## Hair and beard cards, and the mask texture each should use.
##
## The export wired these meshes' *packed data* maps in as base colour.
## hair_rai, hair_rai_4 and combinations_rai are not albedo: R and B carry
## identical data and the green channel is the strand opacity mask, so
## R=B high against low G renders as solid magenta -- which is exactly what
## the hair and beard looked like. tools/assets/build_roman_hair_alpha.py
## rebuilds each as white RGB plus that green channel as alpha; the colour
## then comes from the tint below, since the asset carries no hair colour.
const HAIR_FIXES := {
	"Material.017": "hair_4_alpha",
	"Material.018": "hair_alpha",
	"Material.019": "hair_4_alpha",
	"Material.020": "hair_alpha",
	"beard": "beard_alpha",
}

## Meshes hidden outright rather than materialled.
##
## The T-shirt goes because Roman wrestles bare-chested: the body mesh
## underneath is fully textured (body_color carries the torso, the tribal
## sleeve and the trunks), so removing the shirt reveals finished art rather
## than a hole. It also removes the worst of the clothing interpenetration --
## body and shirt are separate meshes with their own skin weights, and the
## torso was poking through the tee wherever the two disagreed.
##
## The model also ships a second, complete set of hair cards -- the source's
## "entrance" variants (M_Hair_Entrance and S_Hair_Entrance, which arrive as
## hair_ALPHA_skinned_002 and lambert1_skinned_001). Both sets were visible
## and occupy nearly the same space, so they z-fought: the two wrestlers use
## one model but resolved that fight differently, and one of them came out
## looking bald from the crown while the other had a full head of hair.
## Keeping one set of each pair fixes that and halves the hair overdraw.
##
## hair_ALPHA_skinned_001 was missed by that pass and is the reason the crown
## went bald ANYWAY, after it was declared fixed. It is a third hair card
## (1855 tris, material Material.012) and the probe that built this list only
## looked at the two obvious duplicate pairs. Material.012 carries NO albedo
## texture at all -- no strand mask, transparency disabled -- so the card
## cannot render as hair under any threshold: it draws as a solid untextured
## slab wherever its geometry sits, z-fighting the real hair above the ear.
## Whichever surface won the depth test decided whether that head read as a
## black helmet or as bare scalp, which is why it differed between the two
## wrestlers and between camera angles on the same wrestler.
##
## Hidden rather than repaired because there is nothing to repair it with:
## the other four hair materials each name a *_rai packed map that
## build_roman_hair_alpha.py can rebuild into a mask, and this one names
## nothing. The remaining set (hair_ALPHA_skinned + lambert1_skinned) is
## complete on its own -- see the QA head shots in the round write-up.
const HIDDEN_MESHES := [
	"tops_skinned",
	"eye_caruncle_skinned",
	"hair_ALPHA_skinned_001",
	"hair_ALPHA_skinned_002",
	"lambert1_skinned_001",
]

## Materials nudged outward along their normals to stop the body mesh poking
## through them. The body and the clothing are separate meshes with their own
## skin weights, so wherever the two disagree under animation the skin wins
## and erupts through the fabric -- which is what the tan blotches on the
## thighs and shins were. A fraction of a centimetre of grow is the cheap fix
## and is invisible at any camera distance the game uses; the alternative is
## re-weighting someone else's mesh.
##
## THE REAL CAUSE OF THOSE BLOTCHES was found later and is fixed elsewhere --
## see apply_physique_height(). The model splits across two skeletons and it
## splits BODY from EVERYTHING WORN:
##
##   471 bones  bottoms, beard, hair, wrist tape, shoes
##   114 bones  body, head, eyes, mouth, teeth
##
## Only the 114-bone one was being scaled, so a wrestler at physique_height
## 1.05 had a body inflated 5% inside trousers that stayed at 1.0. The skin
## erupting through the fabric was not a skinning disagreement at all; it was
## a body wearing clothes a size too small. One bug, three symptoms -- the
## blotched thighs, the bald crown, and a beard that would not sit on the
## face.
##
## This grow is kept anyway, and it is no longer load-bearing -- if it is ever
## revisited the thing to check first is that both skeletons are still being
## scaled together.
##
## It is NOT, however, sufficient. An earlier draft of this comment claimed
## 0.006 "still covers ordinary skinning disagreement in extreme poses";
## tools/probe/extreme_poses.gd disproved that on its first working run, with
## a clear hole at WrestlerB's hip in HIT_REACT and skin through it. 0.006 is
## roughly a 6mm shell and the hip separation in that pose is wider than that.
## Raised to 0.018 for the bottoms. That closed the hole in the same seeded
## frame (HIT_REACT, WrestlerB, frame 17) with no visible inflation at the
## waistband or the knee. It is NOT claimed to be the minimum -- 0.018 was
## tried first and worked, and the intermediate values were never rendered.
const GROW_FIXES := {
	"Material.004": 0.018, # bottoms
	"Material.005": 0.004, # shoes
}

## Skin roughness: the sweat sheen. Against the owner's reference of him
## walking out (a key-lit, glistening torso and face), the export's skin
## rendered matte, and a matte face under an arena's hard lights reads as
## plastic. 0.45 gives the forehead, cheekbones and shoulders a travelling
## highlight without turning the body into a mirror. The face (Material.001)
## and the body atlas (Material) are both skin.
## Raised from 0.45 against the owner's side-by-side (a close-up of him on
## the entrance card next to a broadcast still): at 0.45 the forehead, nose
## and neck carried hot white spots and he read as moulded plastic; his real
## skin is mostly matte with a thin sweat sheen.
const SKIN_ROUGHNESS := {"Material.001": 0.58, "Material": 0.58}
## Skin materials whose surface comes from a map instead: roughness in R,
## metallic in G, at material roughness and metallic of 1.0. The head's map
## (build_roman_hair_alpha.py, paint_scalp_cap) is SKIN_ROUGHNESS and no
## metal on the face, and rough and "metallic" under the painted scalp cap.
## Where the hairline cards thin the dark cap shows through, and at skin
## roughness and a dielectric's 4% reflectance it threw the cool key back as
## a grey-blue band across the top of the forehead; a metal reflects its own
## albedo, which there is near-black. test_roman_hair holds the map's skin
## value to SKIN_ROUGHNESS.
const SURFACE_MAPS := {"Material.001": "head_rm"}
## Pore tiles across one UV square (SkinLook.add_pores): the head's own
## texture spans about 0.4 m of face and scalp, the body's about 1.2 m, so a
## tile is ~2.5 cm on both.
const PORE_TILES := {"Material.001": 16.0, "Material": 48.0}
## And a tint on both, toward the reference's skin. Measured medians off the
## owner's reference (forehead, cheek, chest): (170,107,88), (182,105,91),
## (195,120,94); the textures' own tone is (168,108,75). Same red and green,
## far less blue -- which is the difference between tan and orange. The full
## correction (blue +16%) rendered pink under neutral light, so blue is
## lifted 8%, half way, and green trimmed 1%.
##
## Then darkened and pulled off orange toward olive, against the same
## side-by-side: under neutral light (clip_shot --face) the face read pale
## peach, where he is tanned olive-brown. The texture's own tone is
## (168,108,75); olive-brown is about (139,100,75), so red comes down most,
## green less, blue least -- (134,93,68), a shade darker than olive-khaki,
## which (0.83, 0.93, 1.0) rendered. (Lifting blue instead, tried first,
## turned the orange pink.)
const SKIN_TINT := Color(0.80, 0.86, 0.90)

const TEXTURE_DIR := "res://assets/characters/roman_reigns_%s.png"
## Roman's hair and beard are near-black; kept slightly warm so they don't
## read as a flat silhouette under the arena's key light.
##
## Cooled toward jet black: under the entrance's warm backlight the warm
## version rendered reddish-brown, which is not his hair in any light.
const HAIR_COLOR := Color(0.045, 0.042, 0.043)
## His hair is slicked and wet-looking; a low roughness gives it the long
## streaky highlight a matte card never has.
## 0.32 -> 0.42 (modelling plan, Roman's hair): at 0.32 the slicked crown
## read as one glossy helmet; his wet look is a narrow streak, not a gloss.
const HAIR_ROUGHNESS := 0.42
## The direction ACROSS the strands on his hair cards, in UV space
## (HairLook.apply). Checked on renders through tools/probe/hair_shot.tscn:
## along the tangent the shine breaks into fine streaks; turned 90 degrees it
## smears into pale patches down the hanging lengths.
const HAIR_FLOW := Vector2(1.0, 0.0)
## How much light the hair reflects at all (BaseMaterial3D.metallic_specular;
## 0.5 is the default, a 4% reflectance).
##
## Lowered for the 2K26 lighting round's rig: the cooler key and the rim
## raised 2.2 -> 5.0 turned his crown into pale blue-white streaks on
## hair_shot.tscn -- silver paint, not wet black hair. Roughness was not the
## lever: rougher spreads the same energy into a grey sheen. Less reflectance
## keeps the streak narrow (the anisotropy and 0.42 roughness still shape it)
## and dims it to a wet glint over jet black, the 2K26 look.
const HAIR_SPECULAR := 0.2
## The beard is darker brown than his hair is black: in the reference
## (gauntlet/refs/frames/roman_head_reference.jpg) it reads warm brown-black,
## and drawn in HAIR_COLOR under the cool key it rendered a flat blue-grey.
const BEARD_COLOR := Color(0.052, 0.038, 0.030)
const BEARD_ROUGHNESS := 0.8
const BEARD_SPECULAR := 0.25
## Alpha below this is cut away. Hair cards need a scissor rather than
## blending: sorted transparency on overlapping strands produces halos.
##
## Low, and that is the fix for the wrestler who kept going bald in wide
## shots. Every mip level averages a mostly-transparent mask further toward
## zero, so a threshold that looks right in close-up rejects the whole card a
## few metres out -- the near wrestler kept his hair and the far one lost it,
## from one model. Alpha-to-coverage is declared below and would normally
## soften exactly this, but it needs MSAA to do anything and this project
## renders without it, so the threshold has to carry it alone.
const HAIR_ALPHA_SCISSOR := 0.14
## The beard and brows are cut at their own, much lower threshold.
##
## They share one mesh and one mask (combinations_rai) whose strands are far
## sparser than the scalp's -- only 9.6% of its texels are opaque against the
## hair's 32%. At the scalp's 0.35 the sparse ends of the beard were cut away
## and it survived only where it was densest: a patch floating on the cheek
## with the jawline bare beneath it, and no eyebrows at all, because the brow
## cards live in the same sparse mask.
const BEARD_ALPHA_SCISSOR := 0.16
## Multiplier on the distance at which the hair meshes drop a LOD level.
## Large on purpose: a head of hair is a few thousand triangles on two
## characters, and losing it entirely is a far worse trade than drawing it.
const HAIR_LOD_BIAS := 16.0

## Scalp materials that blend rather than scissor, for the hairline.
##
## Same argument as the beard, and the mask supports it better. Fraction of
## hair_alpha's texels at or above a given alpha:
##
##   >=0.14 (HAIR_ALPHA_SCISSOR)   0.3538
##   > 0                           0.4094
##
## Five and a half percent of the texture is fine strand ends that a scissor
## throws away, and they are not spread evenly -- they are the soft edge of
## every card, which is concentrated at the HAIRLINE. Cutting them is why the
## forehead reads higher and barer than the source model's, where the hair
## comes down to a fringe.
##
## Only the two scalp materials. lambert1_skinned's side strands (Material.019)
## are left on the scissor: they are thin, isolated and seen edge-on, which is
## the case where blending shows its sorting seams worst and where there is no
## hairline to recover.
const SCALP_BLEND := ["Material.018", "Material.020"]

func _ready() -> void:
	var body: Skeleton3D = _find_body_skeleton()
	if not body:
		push_error("Roman model has no body Skeleton3D")
		return
	_fix_materials()
	_copy_base_animation_library()
	_fix_eyes()
	build_eye_lids()
	# His broad face and thick neck (RomanHeadShape), on every skeleton.
	for skeleton in _animation_skeletons():
		if not skeleton.has_node("RomanHeadShape"):
			var shape := RomanHeadShape.new()
			shape.name = "RomanHeadShape"
			skeleton.add_child(shape)
	if DisplayServer.get_name() != "headless":
		_normalize_mouth_materials()
	_trim_beard()
	_volumize_hair()
	_add_hair_springs()
	_add_ringlets()


# ---------------------------------------------------------------------------
# The hair's movement
# ---------------------------------------------------------------------------
#
# The supplied rig already carries his hair as bone chains: on the 471-bone
# skeleton, J_Hair -> J_Hair_b / J_Hair_c -> 18 + 17 chains (Hair_b00..b17,
# Hair_c00..c16), each 8-13 joints from the crown down the back of the head
# to the top of his back (rest y 1.74 -> 1.30). Nothing ever moved them, so
# the hair was a helmet: it turned with his head and nothing else.
#
# A SpringBoneSimulator3D on that skeleton drives them. His hair is slicked
# back wet on top, so each chain starts at the nape (the first joint below
# HAIR_SPRING_FROM_Y): what lies on the scalp stays glued to it, and only
# the lengths that hang free off the back of the head swing -- lagging a turn
# of the head, bouncing on a stride, settling after a bump. Heavy wet hair:
# stiff-ish and well damped, a little gravity so it keeps hanging when he
# bends. It collides with his head, neck, upper back and shoulders, so it
# drapes over them rather than through.
#
# Presentation only: a skeleton modifier, after the animation, read by
# nothing in the match.
const HAIR_SPRING_FROM_Y := 1.56
const HAIR_STIFFNESS := 1.6
const HAIR_DRAG := 0.55
const HAIR_GRAVITY := 0.35
const HAIR_RADIUS := 0.012
## [bone, radius, offset in that bone's frame, capsule height or 0]. This
## rig's spine and head bones point DOWN (their +Y is the world's -Y at
## rest), so "up the bone" is a negative y offset: the skull's centre sits
## 7 cm above J_Head, the upper back's capsule 2 cm above J_Chest and short
## enough to stay clear of the hair where it leaves the nape.
const HAIR_COLLIDERS := [
	["J_Head", 0.10, Vector3(0.0, -0.07, 0.0), 0.0],
	["J_Neck", 0.062, Vector3(0.0, -0.02, 0.0), 0.0],
	["J_Chest", 0.12, Vector3(0.0, 0.02, 0.0), 0.24],
	["J_Shoulder_L", 0.075, Vector3.ZERO, 0.0],
	["J_Shoulder_R", 0.075, Vector3.ZERO, 0.0],
]


func _add_hair_springs() -> void:
	var worn: Skeleton3D = null
	for skeleton in _animation_skeletons():
		if skeleton.find_bone("J_Hair_b") >= 0:
			worn = skeleton
	if worn == null or worn.has_node("HairSprings"):
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "HairSprings"
	worn.add_child(sim)
	var chains: Array = []
	for i in worn.get_bone_count():
		var parent := worn.get_bone_parent(i)
		if parent < 0:
			continue
		var parent_name := worn.get_bone_name(parent)
		if parent_name != "J_Hair_b" and parent_name != "J_Hair_c":
			continue
		# Down the chain to the nape, then to its end.
		var root := i
		while worn.get_bone_global_rest(root).origin.y > HAIR_SPRING_FROM_Y:
			var kids := worn.get_bone_children(root)
			if kids.is_empty():
				break
			root = kids[0]
		var end := root
		while not worn.get_bone_children(end).is_empty():
			end = worn.get_bone_children(end)[0]
		if end != root:
			chains.append([root, end])
	sim.set_setting_count(chains.size())
	for k in chains.size():
		sim.set_root_bone(k, chains[k][0])
		sim.set_end_bone(k, chains[k][1])
		sim.set_stiffness(k, HAIR_STIFFNESS)
		sim.set_drag(k, HAIR_DRAG)
		sim.set_gravity(k, HAIR_GRAVITY)
		sim.set_radius(k, HAIR_RADIUS)
		sim.set_enable_all_child_collisions(k, true)
	for spec: Array in HAIR_COLLIDERS:
		var bone := worn.find_bone(spec[0])
		if bone < 0:
			continue
		var shape: SpringBoneCollision3D
		if spec[3] > 0.0:
			var capsule := SpringBoneCollisionCapsule3D.new()
			capsule.radius = spec[1]
			capsule.height = spec[3]
			shape = capsule
		else:
			var sphere := SpringBoneCollisionSphere3D.new()
			sphere.radius = spec[1]
			shape = sphere
		shape.name = "Collide_" + String(spec[0])
		sim.add_child(shape)
		shape.set_bone(bone)
		shape.position_offset = spec[2]

# ---------------------------------------------------------------------------
# The beard's shape: trimmed, and faded at the sides
# ---------------------------------------------------------------------------
#
# Against the owner's reference photo the beard read as too bushy, with none
# of the fade his has along the sides: his is short and tight up the cheeks
# and sideburns, thinning toward the ears into the hair, and fullest on the
# jaw and chin. Measured off the .glb, the beard cards (M_Combinations, 5323
# vertices) stand off the skin by 7 mm median, 13 mm p90, 18 mm at most --
# the same depth up the sideburns as on the chin, which is the bush.
#
# So each card vertex is pulled toward the nearest skin vertex, keeping
# BEARD_KEEP of its standoff on the jaw and BEARD_KEEP_SIDES where the fade
# is, and its vertex-colour alpha goes from 1 to BEARD_ALPHA_SIDES across the
# same band. Runtime, because the supplied .glb is never edited; skin weights
# are left exactly as they are, so the trimmed cards still ride the head.
#
# The fade is by the angle round the face from straight ahead (beard_fade),
# 0 to BEARD_SIDE_DEG.x and full from .y. It used to run on height as well
# (up through y 1.625-1.695), and the moustache sits at 1.655-1.664: it was
# trimmed flat and drawn at half opacity, where his is full. And the sides at
# 0.22 alpha read as a grey smear rather than a thinning beard. Now the
# coverage up the cheeks and sideburns is PAINTED as hairs under a groomed
# cheek line (build_roman_hair_alpha.py, paint_beard_strands), the cards on
# the sides are short and at 0.5, and the moustache and chin keep their
# full cards. BEARD_SIDE_DEG and BEARD_SIDE_Y match the painter's.
const BEARD_KEEP := 0.70
const BEARD_KEEP_SIDES := 0.20
const BEARD_ALPHA_SIDES := 0.50
const BEARD_SIDE_DEG := Vector2(35.0, 62.0)
## And only above the jaw line: the jaw's corners under the ears carry the
## full beard in the reference; it is the sideburn above them that thins.
const BEARD_SIDE_Y := Vector2(1.615, 1.655)
const BEARD_CELL := 0.01

## 0 on the front of the face -- moustache, chin -- and along the jaw; 1 up
## the sideburn toward the ear.
static func beard_fade(p: Vector3) -> float:
	var angle := rad_to_deg(atan2(absf(p.x), p.z))
	return smoothstep(BEARD_SIDE_DEG.x, BEARD_SIDE_DEG.y, angle) \
			* smoothstep(BEARD_SIDE_Y.x, BEARD_SIDE_Y.y, p.y)


func _trim_beard() -> void:
	var beard: MeshInstance3D = null
	var beard_surface := -1
	var head: MeshInstance3D = null
	for node in find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null:
				continue
			if mat.resource_name == "beard":
				beard = mi
				beard_surface = s
			elif mat.resource_name == "Material.001":
				head = mi
	if beard == null or head == null or not (beard.mesh is ArrayMesh):
		push_warning("RomanModel: beard or head mesh not found; beard left as supplied")
		return
	var source := beard.mesh as ArrayMesh
	var arrays := source.surface_get_arrays(beard_surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# The skin, in the beard mesh's space, hashed into 1 cm cells.
	var to_beard := beard.global_transform.affine_inverse() * head.global_transform
	var grid := {}
	for s in head.mesh.get_surface_count():
		var head_verts: PackedVector3Array = head.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in head_verts:
			var p := to_beard * v
			var cell := Vector3i((p / BEARD_CELL).floor())
			# A plain Array: a PackedVector3Array held in a Dictionary is a
			# value, and appending to it through grid[cell] appends to a copy
			# -- which left every cell empty and the whole trim a no-op.
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(p)
	var colors := PackedColorArray()
	colors.resize(verts.size())
	var trimmed := PackedVector3Array(verts)
	for i in verts.size():
		var v := verts[i]
		var fade := beard_fade(v)
		colors[i] = Color(1, 1, 1, lerpf(1.0, BEARD_ALPHA_SIDES, fade))
		var skin := _nearest_in_grid(grid, v)
		if skin != Vector3.INF:
			trimmed[i] = skin + (v - skin) * lerpf(BEARD_KEEP, BEARD_KEEP_SIDES, fade)
	arrays[Mesh.ARRAY_VERTEX] = trimmed
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var fmt := source.surface_get_format(s)
		var flags := fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var surface_arrays: Array = arrays if s == beard_surface else source.surface_get_arrays(s)
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), surface_arrays,
				[], {}, flags)
		mesh.surface_set_material(s, source.surface_get_material(s))
		mesh.surface_set_name(s, source.surface_get_name(s))
	beard.mesh = mesh
	# The override material _fix_materials built reads the alpha from the
	# vertex colour too.
	var override := beard.get_surface_override_material(beard_surface) as BaseMaterial3D
	if override:
		override.vertex_color_use_as_albedo = true


# ---------------------------------------------------------------------------
# The hair's volume
# ---------------------------------------------------------------------------
#
# Against the same reference his hair read plastered to the scalp. Measured
# off the .glb, the scalp cards (M_Hair) sit 11 mm off the head on top
# (median, y > 1.74) and 20 mm off it where they hang -- a wet cap, where his
# is slicked back with lift on top and falls in thick waves past the
# shoulders. So each scalp-hair vertex is pushed OUT from the nearest skin,
# HAIR_LIFT_TOP times its standoff on the crown and HAIR_LIFT_HANG where it
# hangs, blended between -- and only HAIR_LIFT_FRONT at the front hairline,
# so no fringe falls forward over his forehead. Skin weights untouched.
#
# Taken back down (character_aaa_plan.md R1, the owner's photos of him, Oct
# 2026): wet and slicked, the crown lies flat on the scalp and the lengths
# hang as separate ringlets, not a mass -- at 1.3 / 1.6 the crown read domed
# and the back as one thick sheet. The supplied cards' own 11 mm on top is
# the slick; the hang keeps a little lift so it clears the neck.
#
# And tighter than supplied on top (0.75): the photos show the crown wet and
# flat to the skull, and the supplied cards' 11 mm still read as a cap of
# hair. The painted scalp cap under them keeps any gap dark.
const HAIR_LIFT_TOP := 0.75
const HAIR_LIFT_HANG := 1.15
const HAIR_LIFT_FRONT := 0.9
## Crown above this, hang below the next; blended between.
const HAIR_LIFT_Y := Vector2(1.62, 1.74)


## Root-to-tip (refs/aaa_gap.md item 7): the albedo at the scalp, as a share
## of HAIR_COLOR, rising to 1 by HAIR_TIP_STANDOFF off the skin. Black hair
## is two-tone too -- the lengths are a shade browner and lighter than the
## roots -- and without it the lifted crown read as one flat mass.
const HAIR_ROOT_SHADE := 0.55
const HAIR_TIP_STANDOFF := Vector2(0.006, 0.035)


static func hair_root_to_tip(standoff: float) -> float:
	return lerpf(HAIR_ROOT_SHADE, 1.0,
			smoothstep(HAIR_TIP_STANDOFF.x, HAIR_TIP_STANDOFF.y, standoff))


static func hair_lift(p: Vector3) -> float:
	var k := lerpf(HAIR_LIFT_HANG, HAIR_LIFT_TOP, smoothstep(HAIR_LIFT_Y.x, HAIR_LIFT_Y.y, p.y))
	# The hairline: in front of the ears, across the forehead.
	var front := smoothstep(0.05, 0.09, p.z) * smoothstep(1.70, 1.76, p.y)
	return lerpf(k, HAIR_LIFT_FRONT, front)


## The wave in the hanging lengths (character_aaa_plan.md R1). Two halves on
## one wave, so the bands of light sit on the bends:
##   * geometry: each hanging vertex is pushed sideways round the head by
##     HAIR_WAVE_GEO * sin(wave), so the sheets bend in an S down their length
##     and the silhouette waves;
##   * light: UV2 is written as (angle round the head, height), and the hair
##     materials carry a detail normal on UV2 (roman_reigns_hair_wave_nrm.png,
##     build_roman_hair_alpha.py build_wave_normal) that tilts the surface
##     along the strand on the same wave.
## Why UV2 and not the hair atlas: 30% of M_Hair's atlas is shared between
## crown and hanging cards, so a wave painted there would ripple the slicked
## crown. HAIR_WAVE_Y, HAIR_WAVE_LENGTH, HAIR_WAVE_HANG_Y and hair_wave_phase
## must match build_wave_normal's; test_roman_hair checks the map against them.
const HAIR_WAVE_Y := Vector2(1.08, 1.86)
const HAIR_WAVE_LENGTH := 0.052
const HAIR_WAVE_HANG_Y := Vector2(1.60, 1.68)
const HAIR_WAVE_GEO := 0.011
## How much of the final hair normal is the wave map (the detail albedo's
## alpha); the strand maps are authored at 1 / this of their slope, as is the
## wave map.
const HAIR_WAVE_MIX := 0.5
## Base normal map per hair material: strand ridges on its own atlas.
const HAIR_STRANDS := {
	"Material.017": "hair_4_strands_nrm",
	"Material.018": "hair_strands_nrm",
	"Material.019": "hair_4_strands_nrm",
	"Material.020": "hair_strands_nrm",
}


## Phase of the wave, in waves, at u2 round the head: a fixed sum of sines,
## so the map's generator computes the same thing.
static func hair_wave_phase(u2: float) -> float:
	var t := TAU * u2
	return 0.50 * sin(7.0 * t) + 0.30 * sin(13.0 * t + 1.3) + 0.20 * sin(23.0 * t + 2.1)


## UV2 for a hair vertex: the angle round the head (0.5 straight behind it,
## so the wrap is at the face) and the height down from HAIR_WAVE_Y.y.
static func hair_wave_uv2(p: Vector3) -> Vector2:
	return Vector2(atan2(p.x, -p.z) / TAU + 0.5,
			(HAIR_WAVE_Y.y - p.y) / (HAIR_WAVE_Y.y - HAIR_WAVE_Y.x))


## 1 where the hair hangs, 0 on the crown.
static func hair_wave_weight(y: float) -> float:
	return 1.0 - smoothstep(HAIR_WAVE_HANG_Y.x, HAIR_WAVE_HANG_Y.y, y)


## The hanging lengths are ringlets now (character_aaa_plan.md R1b): new
## geometry built by tools/blender/roman_ringlets.py and hung on his hair
## chains (_add_ringlets). The supplied cards hang as one layered sheet, and
## no edit of them -- lift, stretch, a wave, thinning one card in two --
## separated it into the wet ringlets of the owner's photos. So below
## RINGLET_SHEET_CUT, behind the ears, the supplied scalp and side cards are
## cut away; the ringlets start a little higher (y 1.64) under the slicked
## crown, so the two overlap and no edge shows.
const RINGLETS := "res://assets/characters/roman_ringlets.glb"
const RINGLET_TEXTURE := "ringlets_alpha"
const RINGLET_SHEET_CUT := 1.58
## Behind the ears only: in front of this the side strands frame the face.
const RINGLET_SHEET_CUT_Z := 0.02
## The supplied hair materials cut for the ringlets: scalp and side strands.
const RINGLET_SHEET_MATERIALS := ["Material.018", "Material.019"]


## Flyaways (character_aaa_plan.md R1): a third, sparse layer of cards at
## the nape, where wet hair separates out of the hanging mass into strays.
## Every FLYAWAY_EVERY-th scalp-card triangle there is copied,
## pushed FLYAWAY_LIFT further off the skin (varied per triangle, so they do
## not form a second shell), slid FLYAWAY_UV_SHIFT along its strip of the
## atlas so it carries different strands from the card under it, and drawn at
## FLYAWAY_ALPHA. Copies of the scalp's own triangles, so each keeps its
## card's skin weights and rides the same spring chains -- no new rig.
const FLYAWAY_EVERY := 3
const FLYAWAY_LIFT := Vector2(0.003, 0.008)
const FLYAWAY_UV_SHIFT := 0.013
const FLYAWAY_ALPHA := 0.45
## The material the flyaways are drawn from: M_Hair's scalp cards.
const FLYAWAY_MATERIAL := "Material.018"


## The nape and the backs of the hanging lengths, bind space. Not the
## temples: slicked wet, his are tight to the head (the owner's photos), and
## a fringe of strays there read as frizz.
static func flyaway_region(p: Vector3) -> bool:
	return p.z < -0.03 and p.y > 1.50 and p.y < 1.67


static func hair_wave(p: Vector3) -> Vector3:
	var w := hair_wave_weight(p.y)
	if w <= 0.0:
		return p
	var uv2 := hair_wave_uv2(p)
	var a := TAU * ((HAIR_WAVE_Y.y - p.y) / HAIR_WAVE_LENGTH + hair_wave_phase(uv2.x))
	var radial := Vector2(p.x, p.z)
	if radial.length() < 0.001:
		return p
	radial = radial.normalized()
	var side := Vector2(-radial.y, radial.x) * HAIR_WAVE_GEO * w * sin(a)
	return Vector3(p.x + side.x, p.y, p.z + side.y)


func _volumize_hair() -> void:
	var skin_meshes: Array[MeshInstance3D] = []
	var hair: Array = []
	for node in find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null:
				continue
			var key := mat.resource_name
			if key == "Material.001" or key == "Material":
				skin_meshes.append(mi)
			elif HAIR_FIXES.has(key) and key != "beard":
				hair.append([mi, s])
	if skin_meshes.is_empty() or hair.is_empty():
		push_warning("RomanModel: hair or skin not found; hair left as supplied")
		return
	for entry: Array in hair:
		var mi: MeshInstance3D = entry[0]
		var surface: int = entry[1]
		if not (mi.mesh is ArrayMesh):
			continue
		var grid := {}
		for skin_mi in skin_meshes:
			var to_hair := mi.global_transform.affine_inverse() * skin_mi.global_transform
			for s in skin_mi.mesh.get_surface_count():
				for v in skin_mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					var p := to_hair * v
					if p.y < 1.25:
						continue
					var cell := Vector3i((p / BEARD_CELL).floor())
					if not grid.has(cell):
						grid[cell] = []
					(grid[cell] as Array).append(p)
		var source := mi.mesh as ArrayMesh
		var arrays := source.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var lifted := PackedVector3Array(verts)
		# Root to tip: darkest where the card leaves the scalp, full colour
		# out at the ends (HAIR_ROOT_SHADE). Vertex colour, so the material's
		# albedo multiplies it.
		var shade := PackedColorArray()
		shade.resize(verts.size())
		var uv2 := PackedVector2Array()
		uv2.resize(verts.size())
		var skins := PackedVector3Array()
		skins.resize(verts.size())
		for i in verts.size():
			var skin := _nearest_in_grid(grid, verts[i])
			skins[i] = skin
			var k := 1.0
			if skin != Vector3.INF:
				lifted[i] = skin + (verts[i] - skin) * hair_lift(verts[i])
				k = hair_root_to_tip(lifted[i].distance_to(skin))
			uv2[i] = hair_wave_uv2(lifted[i])
			lifted[i] = hair_wave(lifted[i])
			shade[i] = Color(k, k, k, 1.0)
		arrays[Mesh.ARRAY_VERTEX] = lifted
		arrays[Mesh.ARRAY_COLOR] = shade
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		var material := mi.mesh.surface_get_material(surface)
		if material and material.resource_name in RINGLET_SHEET_MATERIALS:
			mi.set_meta("hair_cut", _cut_sheet(arrays))
		if material and material.resource_name == FLYAWAY_MATERIAL:
			mi.set_meta("hair_flyaways", _add_flyaways(arrays, verts, skins))
		mi.mesh = _rebuilt(source, surface, arrays)


## Drops the triangles that lie wholly below RINGLET_SHEET_CUT behind the
## ears, on the final vertex positions; the index only. Returns the count.
static func _cut_sheet(arrays: Array) -> int:
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var kept := PackedInt32Array()
	var removed := 0
	for t in range(0, index.size(), 3):
		var low := true
		for k in 3:
			var p := verts[index[t + k]]
			if p.y >= RINGLET_SHEET_CUT or p.z > RINGLET_SHEET_CUT_Z:
				low = false
		if low:
			removed += 1
			continue
		kept.append(index[t])
		kept.append(index[t + 1])
		kept.append(index[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	return removed


## Hangs the ringlets (RINGLETS) on his worn skeleton -- the one carrying the
## hair chains -- beside his own hair meshes, as they are: a child of that
## Skeleton3D, identity transform, skinned to it by bone name. Their bind
## poses are his hair's own (roman_ringlets.py exports the same armature),
## so the springs that swing his hair chains swing them. Drawn with his hair
## material and the ringlet strand texture.
func _add_ringlets() -> void:
	var worn: Skeleton3D = null
	for skeleton in _animation_skeletons():
		if skeleton.find_bone("J_Hair_b") >= 0:
			worn = skeleton
	if worn == null or worn.has_node("Ringlets") or not ResourceLoader.exists(RINGLETS):
		return
	var hair_material: BaseMaterial3D = null
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source and source.resource_name == FLYAWAY_MATERIAL:
				hair_material = mi.get_surface_override_material(s) as BaseMaterial3D
	var scene := (load(RINGLETS) as PackedScene).instantiate()
	var source_mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var ringlets := MeshInstance3D.new()
	ringlets.name = "Ringlets"
	ringlets.mesh = source_mi.mesh
	ringlets.skin = source_mi.skin
	scene.free()
	worn.add_child(ringlets)
	ringlets.skeleton = NodePath("..")
	ringlets.lod_bias = HAIR_LOD_BIAS
	var material := (hair_material.duplicate() if hair_material else StandardMaterial3D.new()) \
			as BaseMaterial3D
	material.albedo_texture = _texture(RINGLET_TEXTURE)
	material.albedo_color = HAIR_COLOR
	material.vertex_color_use_as_albedo = true
	# Thirty clumps crossing each other: a scissor, not a blend, so they
	# never sort against one another. Alpha-to-coverage keeps the edges soft.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = HAIR_ALPHA_SCISSOR
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	material.alpha_antialiasing_edge = HAIR_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No UV2 on the ringlets, so no wave detail -- the coil is geometry. The
	# strand ridges: 4 columns of ~16 mm cards, the side strands' 0.064 m/u.
	material.detail_enabled = false
	material.normal_enabled = true
	material.normal_texture = _texture("hair_4_strands_nrm")
	ringlets.set_surface_override_material(0, material)


## Appends the flyaway layer to a scalp surface's arrays (see FLYAWAY_EVERY).
## `bind` is the surface's vertices as supplied, which pick the regions;
## `skins` the nearest skin point to each, which sets "off the skin".
## Returns the triangles added.
static func _add_flyaways(arrays: Array, bind: PackedVector3Array,
		skins: PackedVector3Array) -> int:
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
	if index.is_empty():
		return 0
	for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		if arrays[c] != null:
			return 0
	var n := bind.size()
	var pick := PackedInt32Array()
	var lift := PackedFloat32Array()
	for t in range(0, index.size(), 3):
		if (t / 3) % FLYAWAY_EVERY != 0:
			continue
		if not (flyaway_region(bind[index[t]]) and flyaway_region(bind[index[t + 1]])
				and flyaway_region(bind[index[t + 2]])):
			continue
		# A per-triangle lift from a hash of its index: deterministic, varied.
		var h := fposmod(sin(float(t) * 12.9898) * 43758.5453, 1.0)
		for k in 3:
			pick.append(index[t + k])
			lift.append(lerpf(FLYAWAY_LIFT.x, FLYAWAY_LIFT.y, h))
	if pick.is_empty():
		return 0
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for j in pick.size():
		var i := pick[j]
		var out := normals[i]
		if skins[i] != Vector3.INF and verts[i].distance_to(skins[i]) > 0.0005:
			out = (verts[i] - skins[i]).normalized()
		verts.append(verts[i] + out * lift[j])
		normals.append(normals[i])
		index.append(n + j)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in pick:
			for k in 4:
				tangents.append(tangents[i * 4 + k])
		arrays[Mesh.ARRAY_TANGENT] = tangents
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in pick:
		var c := colors[i]
		colors.append(Color(c.r, c.g, c.b, c.a * FLYAWAY_ALPHA))
	arrays[Mesh.ARRAY_COLOR] = colors
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in pick:
		uv.append(uv[i] + Vector2(FLYAWAY_UV_SHIFT, 0.0))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	if arrays[Mesh.ARRAY_TEX_UV2] != null:
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i in pick:
			uv2.append(uv2[i])
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	if arrays[Mesh.ARRAY_BONES] != null:
		# Bones arrive as PackedInt32Array or PackedFloat32Array; 4 or 8 per
		# vertex, which the weights' length says.
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := weights.size() / n
		for i in pick:
			for k in per:
				bones.append(bones[i * per + k])
				weights.append(weights[i * per + k])
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	return pick.size() / 3


## A copy of `source` with one surface's arrays replaced, materials, names
## and skinning format kept.
static func _rebuilt(source: ArrayMesh, surface: int, arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var flags := source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var surface_arrays: Array = arrays if s == surface else source.surface_get_arrays(s)
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), surface_arrays,
				[], {}, flags)
		mesh.surface_set_material(s, source.surface_get_material(s))
		mesh.surface_set_name(s, source.surface_get_name(s))
	return mesh


static func _nearest_in_grid(grid: Dictionary, p: Vector3) -> Vector3:
	var base := Vector3i((p / BEARD_CELL).floor())
	var best := Vector3.INF
	var best_d := INF
	for reach in [1, 2, 4]:
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				for dz in range(-reach, reach + 1):
					var cell := base + Vector3i(dx, dy, dz)
					if not grid.has(cell):
						continue
					for q: Vector3 in grid[cell] as Array:
						var d := p.distance_squared_to(q)
						if d < best_d:
							best_d = d
							best = q
		if best != Vector3.INF:
			return best
	return best

## Repairs the materials the export left unusable. Applied as surface
## overrides rather than by editing the .glb: the source asset stays exactly
## as supplied, and every fix is visible here as code with its reason next to
## it. Safe to call once at _ready -- it only touches the materials it names.
func _fix_materials() -> void:
	var skin: Array[BaseMaterial3D] = []
	for node in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		# A UV2 on the skin surfaces for the pore layer (SkinLook.add_pores).
		var skin_surfaces := []
		for surface in mesh_instance.mesh.get_surface_count():
			var m := mesh_instance.mesh.surface_get_material(surface)
			if m and SKIN_ROUGHNESS.has(m.resource_name):
				skin_surfaces.append(surface)
		if not HIDDEN_MESHES.has(mesh_instance.name):
			SkinLook.with_detail_uv(mesh_instance, skin_surfaces)
		if HIDDEN_MESHES.has(mesh_instance.name):
			mesh_instance.visible = false
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var key := source.resource_name
			if not (ALBEDO_FIXES.has(key) or HAIR_FIXES.has(key)
					or GROW_FIXES.has(key) or SKIN_ROUGHNESS.has(key)):
				continue
			var material := source.duplicate() as BaseMaterial3D
			if material == null:
				continue
			if SKIN_ROUGHNESS.has(key):
				material.roughness = SKIN_ROUGHNESS[key]
				if SURFACE_MAPS.has(key):
					var surface_map := _texture(SURFACE_MAPS[key])
					material.roughness = 1.0
					material.roughness_texture = surface_map
					material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
					material.metallic = 1.0
					material.metallic_texture = surface_map
					material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				material.metallic_specular = 0.5
				SkinLook.apply(material)
				SkinLook.add_pores(material, PORE_TILES[key])
				skin.append(material)
			if GROW_FIXES.has(key):
				material.grow = true
				material.grow_amount = GROW_FIXES[key]
			if HAIR_FIXES.has(key):
				# Hold the hair at full detail well past its normal LOD range.
				# roman_reigns.glb is imported with generate_lods on, and a
				# decimated hair card is not a smaller hair card -- it is a
				# card whose alpha mask has been averaged toward transparent,
				# so the scissor takes the whole thing. That is why the two
				# wrestlers, one model, looked like different men: the near
				# one kept a full head of hair at LOD0 while the far one went
				# bald the moment it dropped a level. Alpha-to-coverage helps
				# the mip chain but cannot help a mesh that is no longer there.
				mesh_instance.lod_bias = HAIR_LOD_BIAS
				material.albedo_texture = _texture(HAIR_FIXES[key])
				material.albedo_color = BEARD_COLOR if key == "beard" else HAIR_COLOR
				# The scalp is wet and slicked; the beard is not, and glossy
				# it rendered as a black plastic chin.
				material.roughness = BEARD_ROUGHNESS if key == "beard" \
					else HAIR_ROUGHNESS
				material.metallic_specular = BEARD_SPECULAR if key == "beard" \
					else HAIR_SPECULAR
				if key != "beard":
					# The band of shine across the strands (HairLook), and the
					# root-to-tip shade _volumize_hair writes as vertex colour.
					HairLook.apply(material, HAIR_FLOW)
					material.vertex_color_use_as_albedo = true
					_add_hair_normals(material, key)
				var scissor: float = BEARD_ALPHA_SCISSOR if key == "beard" \
					else HAIR_ALPHA_SCISSOR
				if key == "beard" or key in SCALP_BLEND:
					# The beard and brows blend; the scalp still scissors.
					#
					# Lowering the beard threshold was the obvious move and it
					# does nothing, because the mask has almost no partial
					# coverage to recover. Fraction of beard_alpha's texels at
					# or above a given alpha:
					#
					#   >=0.16 (the old threshold)   0.1195
					#   >=0.10                       0.1211
					#   >=0.06                       0.1244
					#   > 0                          0.1577
					#
					# The whole range from 0.16 down to nothing is worth half a
					# percent of the texture. A scissor can only ever draw the
					# 12% it already draws, which is why the beard reads as
					# sparse bristle and the eyebrows -- same mesh, same mask,
					# and far sparser than the jaw -- barely register at all.
					#
					# Blending draws the remaining 4% at its true alpha instead
					# of discarding it, and softens the 3.9% that is fully
					# opaque into the 12% that is not. DEPTH_PRE_PASS rather
					# than plain ALPHA: the pre-pass writes depth first, so
					# overlapping strands no longer depend on draw order, which
					# is the halo problem that sent this to a scissor
					# originally.
					material.transparency = \
						BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				else:
					material.transparency = \
						BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					material.alpha_scissor_threshold = scissor
				# Hair cards are single-sided geometry seen from both faces.
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				# Alpha-to-coverage, because a plain scissor test loses hair
				# with distance: the mip chain averages a mostly-transparent
				# mask down toward zero, more of it falls under the threshold
				# every mip level, and the crown thins out until the wrestler
				# reads as bald from the broadcast camera while looking fine
				# in close-up. That is what made the two wrestlers -- one
				# model, two distances -- look like different men.
				material.alpha_antialiasing_mode = \
					BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
				material.alpha_antialiasing_edge = scissor
			elif ALBEDO_FIXES.has(key):
				var fix: Dictionary = ALBEDO_FIXES[key]
				if fix.has("texture"):
					material.albedo_texture = _texture(fix["texture"])
				material.albedo_color = fix["color"]
			if SKIN_ROUGHNESS.has(key):
				material.albedo_color *= SKIN_TINT
			mesh_instance.set_surface_override_material(surface, material)
	# For Sweat (WrestlerController attaches it).
	set_meta("skin_materials", skin)

## The strand ridges as the base normal map, and the wave as a detail
## normal on UV2 (see hair_wave).
func _add_hair_normals(material: BaseMaterial3D, key: String) -> void:
	if not HAIR_STRANDS.has(key):
		return
	material.normal_enabled = true
	material.normal_texture = _texture(HAIR_STRANDS[key])
	var mix := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	mix.set_pixel(0, 0, Color(1, 1, 1, HAIR_WAVE_MIX))
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	material.detail_albedo = ImageTexture.create_from_image(mix)
	material.detail_normal = _texture("hair_wave_nrm")


func _texture(suffix: String) -> Texture2D:
	return load(TEXTURE_DIR % suffix) as Texture2D

## Height, applied to EVERY skeleton this model is rigged on.
##
## The model has two: a 114-bone body-and-head skeleton and a 471-bone one
## carrying the hair and beard. WrestlerController used to scale only the one
## get_game_skeleton() hands back, which is the 114-bone body -- so a wrestler
## whose physique_height was not exactly 1.0 got a head resized inside hair
## that was not. At 1.05 the scalp came through the crown and the wrestler
## rendered bald; at 0.98 it did not, which is why the two wrestlers looked
## like different men from one model and why it changed with camera angle.
##
## Scaling both keeps the head and the hair the same size as each other at any
## height, which is the invariant that was actually broken.
func apply_physique_height(height: float) -> void:
	for skeleton in _animation_skeletons():
		skeleton.scale = Vector3.ONE * height


func get_game_skeleton() -> Skeleton3D:
	return _find_body_skeleton()

func game_bone_name(game_bone: String) -> String:
	return BONE_MAP.get(game_bone, game_bone)

func uses_universal_attire() -> bool:
	return false

## Face-material ground truth, measured off the shipped .glb (see
## assets/characters/CREDITS.md "Roman face findings"), not guessed:
## - M_Head carries ONLY wrinkles_normal; the face colour map ("Image",
##   brows/beard-stubble/lips/tattoo layout) is embedded but referenced by
##   nothing, so the head renders without its colour.
## - The "beard" material and all four hair materials point their albedo at
##   *_rai PACKED DATA textures, so the beard renders magenta and the hair
##   purple.
## - M_EYE has no texture and no vertex colours: flat glossy white.
## - M_Teeth/M_Tongue/M_MouthBag have NO material at all: default grey.
##
## The first three are repaired by _fix_materials() above, which is the
## single material authority for this model. Two of those repairs were
## reconciled against a second, independent pass at the same faults and the
## measurement decided each:
##
## - HEAD. Re-pointing M_Head at roman_reigns_Image.png directly renders a
##   blue-white face: that file's blue channel is pinned to 255 across 100%
##   of the image and its red is clipped at both ends across ~26%, so only
##   green survived the export. ALBEDO_FIXES reconstructs the face from that
##   green channel instead (build_roman_hair_alpha.py), tinted with the skin
##   tone measured off the undamaged body_color atlas.
## - HAIR AND BEARD. Unlinking the _rai maps for a flat colour loses the
##   strands: the green channel of those maps IS the opacity mask, so the
##   cards become solid lozenges rather than hair. HAIR_FIXES keeps the mask
##   as a rebuilt alpha channel and tints the RGB, which is what preserves
##   the hairline, the beard's jaw edge and the eyebrows.
##
## What remains here is the surface the material pass does not reach: the
## mouth parts, whose meshes carry no material at all to inspect and so must
## be found by node name, and the eyes, which need geometry rather than a
## texture. Determinism-safe: visuals only, no FSM/RNG/physics touched.
const TEETH_COLOR := Color(0.87, 0.85, 0.79)
const MOUTH_COLOR := Color(0.28, 0.09, 0.08)

## The eye bones' lines of sight, in each J_Eye bone's LOCAL space, converted
## once from the .glb bind pose: [iris plane, cornea apex]. They used to seat
## sphere irises on the eyeball; the eyes are painted now (_fix_eyes), and the
## lids (build_eye_lids) still measure the eye from the apex. If a re-export
## moves the bones, re-measure (M_EYE centroids vs J_Eye globals) -- do not
## hand-tune.
const EYE_TARGETS := {
	"J_Eye_L": [Vector3(-0.001077, -0.006686, -0.005771),
		Vector3(-0.001568, -0.009389, -0.007743)],
	"J_Eye_R": [Vector3(0.001110, -0.006769, -0.005661),
		Vector3(0.001613, -0.009503, -0.007587)],
}

## Supplies the materials the export omitted entirely. M_Teeth, M_Tongue and
## M_MouthBag carry no material on any surface, so they render default grey
## and there is nothing to duplicate and repair -- they are found by node
## name and painted outright. Everything else on the face is handled by
## _fix_materials(); see the note above for why this pass does not also
## touch the head, hair or beard.
func _normalize_mouth_materials() -> void:
	for mi in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var node_name := String(mesh_instance.name).to_lower()
		if node_name.contains("teeth"):
			_paint_all_surfaces(mesh_instance, TEETH_COLOR, 0.35, false)
		elif node_name.contains("tongue") or node_name.contains("mouthbag"):
			_paint_all_surfaces(mesh_instance, MOUTH_COLOR, 0.6, false)

func _paint_all_surfaces(mesh_instance: MeshInstance3D, color: Color,
		roughness: float, metal: bool) -> void:
	for surface in mesh_instance.mesh.get_surface_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = 1.0 if metal else 0.0
		mesh_instance.set_surface_override_material(surface, mat)

## His eyes and lashes (character_aaa_plan.md S1), from
## tools/assets/build_roman_eyes.py. M_EYE is two eyeballs on J_Eye_L/R
## with a flat front-projected UV, and shipped untextured: flat white, the
## iris faked by spheres stuck on the cornea, and the eyeball's outer band --
## nearly edge-on in the lid opening -- mirroring the cool key as two chrome
## strips above and below each eye. Now:
##   * a painted sclera, iris and pupil at real sizes;
##   * occlusion and roughness (EYE_ORM): the band where the lids meet the eye
##     shaded and rough, the cornea glass-smooth;
##   * the iris BEHIND the cornea, as parallax (EYE_PARALLAX) -- it shifts
##     against the cornea's highlight as the camera moves, as a real one does;
##   * a wet film (clearcoat) over it all;
##   * the lash cards given strands (their texture was missing: they drew as
##     a solid black bar along the upper lid).
## The eyes are skinned to the eye bones, so the painted iris turns with
## EyeAim; the spheres that used to stand in for it are gone.
const EYE_MATERIAL := "Material.013"
const LASH_MATERIAL := "Material.016"
## Godot's height-map scale (UV offset at grazing, x0.01). The iris plane sits
## ~2.5 mm behind the apex, which would ask for ~14; but Godot's single-step
## parallax smears at the angles the lids leave visible -- at 8 the pupil
## dragged a dark keyhole down the iris -- so it is held to a hint of depth.
const EYE_PARALLAX := 4.0
const EYE_CLEARCOAT_ROUGHNESS := 0.03
const LASH_COLOR := Color(0.030, 0.024, 0.021)
const LASH_SCISSOR := 0.3


func _fix_eyes() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source == null:
				continue
			if source.resource_name == EYE_MATERIAL:
				mi.set_surface_override_material(s, _eye_material())
			elif source.resource_name == LASH_MATERIAL:
				mi.set_surface_override_material(s, _lash_material())


func _eye_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "RomanEye"
	m.albedo_texture = _texture("eye_color")
	var orm := _texture("eye_orm")
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	# Lids shade direct light too, not just the ambient.
	m.ao_light_affect = 0.7
	m.roughness = 1.0
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.heightmap_enabled = true
	m.heightmap_texture = _texture("eye_height")
	m.heightmap_scale = EYE_PARALLAX
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = EYE_CLEARCOAT_ROUGHNESS
	return m


func _lash_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "RomanLashes"
	m.albedo_texture = _texture("lash_alpha")
	m.albedo_color = LASH_COLOR
	# Lashes barely reflect: at the default reflectance the thin cards
	# caught the cool key and read as a silver fringe on the lid.
	m.roughness = 0.85
	m.metallic_specular = 0.1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = LASH_SCISSOR
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	m.alpha_antialiasing_edge = LASH_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## His eyelids (EyeLids): the model has no lid bones and no blend shapes, so
## they are built, one per eye, centred on its J_Eye bone and hung on J_Head.
## LID_COLOR is the skin round his eyes, off the head texture under the arena
## key (checked on the broadcast_shot close-ups).
const LID_COLOR := Color(0.47, 0.32, 0.23)
const LID_SEED := 7
## The eyeball's centre, ahead of its bone along the line of sight. Zero:
## the pupil sphere sits 12.2 mm from the bone, which is a human eyeball's
## radius exactly, so the bone IS the centre. (6 mm, from the note on
## EYE_TARGETS, put the lids' centre in front of the cornea and they closed
## as a ball stuck on the front of the eye.)
const EYE_CENTRE_AHEAD := 0.0


func build_eye_lids() -> EyeLids:
	var body := _find_body_skeleton()
	if body == null:
		return null
	var existing := body.find_child("EyeLids", true, false) as EyeLids
	if existing:
		return existing
	var head := body.find_bone("J_Head")
	if head < 0:
		return null
	# Placed off the EYE BONES, not the eye mesh: converting the mesh's
	# vertices into skeleton space put the lids 6 cm above his eyes (the mesh
	# and the scaled, posed skeleton do not share a frame at load). The bones
	# are exact, and EYE_TARGETS already knows each eye's line of sight and,
	# by the pupil's distance, its radius.
	var head_rest := body.get_bone_global_rest(head)
	var to_head := head_rest.affine_inverse()
	# The radius to the cornea's apex: bone -> pupil. EyeLids adds its margin.
	var radius := (EYE_TARGETS["J_Eye_L"][1] as Vector3).length()
	var eyes := []
	for bone: String in EYE_TARGETS:
		var eye := body.find_bone(bone)
		if eye < 0:
			continue
		var rest := body.get_bone_global_rest(eye)
		var sight: Vector3 = (EYE_TARGETS[bone][1] as Vector3).normalized()
		var centre := rest * (sight * EYE_CENTRE_AHEAD)
		var forward := (rest.basis * sight).normalized()
		eyes.append([to_head * centre, radius,
				(head_rest.basis.inverse() * forward).normalized(),
				(head_rest.basis.inverse() * Vector3.RIGHT).normalized()])
	if eyes.size() != 2 or radius <= 0.0:
		push_warning("RomanModel: eyes not found; no eyelids")
		return null
	var attach := BoneAttachment3D.new()
	attach.name = "EyeLidMount"
	body.add_child(attach)
	attach.bone_name = "J_Head"
	var lids := EyeLids.new()
	lids.name = "EyeLids"
	attach.add_child(lids)
	var material: StandardMaterial3D = null
	if DisplayServer.get_name() != "headless":
		material = StandardMaterial3D.new()
		material.albedo_color = LID_COLOR
		material.roughness = 0.6
		SkinLook.apply(material)
	lids.skeleton = body
	lids.eye_bones = PackedStringArray(EYE_TARGETS.keys())
	lids.build(eyes, material, LID_SEED)
	return lids


## Point his eyes at whatever `look_target` returns (a world position, or
## Vector3.INF for straight ahead). See EyeAim. Idempotent.
func aim_eyes(look_target: Callable) -> void:
	var body := _find_body_skeleton()
	if body == null:
		return
	var aim := body.get_node_or_null("EyeAim") as EyeAim
	if aim == null:
		aim = EyeAim.new()
		aim.name = "EyeAim"
		body.add_child(aim)
		# The line of sight is bone -> pupil (EYE_TARGETS), not the skull's +Z.
		for bone: String in EYE_TARGETS:
			aim.sight_local[bone] = (EYE_TARGETS[bone][1] as Vector3).normalized()
	aim.look_target = look_target


func _find_body_skeleton() -> Skeleton3D:
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.get_bone_count() < 200 \
				and skeleton.find_bone("J_Hips") >= 0:
			return skeleton
	return null

func _animation_skeletons() -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.find_bone("J_Hips") >= 0:
			out.append(skeleton)
	return out

func _copy_base_animation_library() -> void:
	var packed: PackedScene = load(BASE_RIG)
	var source_root: Node = packed.instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var target_player := $AnimationPlayer as AnimationPlayer
	if not source_player or not target_player:
		push_error("Roman model could not load the base animation library")
		source_root.free()
		return
	target_player.add_animation_library("", adapt_animation_library(
			source_player.get_animation_library(""),
			_source_skeleton(source_root)))
	source_root.free()

## The base rig's own skeleton, needed for its bone rest poses -- see
## adapt_animation_library().
func _source_skeleton(source_root: Node) -> Skeleton3D:
	for candidate in source_root.find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.find_bone("pelvis") >= 0:
			return skeleton
	return null

## Retargets the base rig's animation library onto Roman's bones.
##
## `source_skeleton` is the base rig's own Skeleton3D, and it is what makes
## this a retarget rather than a rename. A bone track stores a rotation in the
## bone's *local* space, which is only meaningful relative to that skeleton's
## rest pose -- and these two rigs do not share one. Copying keys across
## verbatim (which this did) hands Roman's bones rotations authored against a
## different set of rest orientations, and the result was not subtly off: he
## played every animation upside down, head at 0.32m and feet at 1.73m, with
## the mesh torn apart. Measured by tools/probe/roman_diag.tscn; the model
## itself stands up correctly with nothing driving it
## (tools/probe/roman_bare.tscn), which is what localised the fault here.
##
## The fix is the standard rest-relative conversion: take the key's offset
## from the *source* rest orientation, and re-apply that offset to the
## *target* rest orientation.
##
##     delta  = src_rest^-1 * key
##     output = tgt_rest * delta
##
## A key that matches the source's rest pose then lands exactly on Roman's
## rest pose instead of somewhere 180 degrees away from it.
##
## `source_skeleton` defaults to the base rig's own skeleton, loaded on
## demand, because every library that reaches this method is authored against
## that rig -- the .glb's 43 clips, the generated paired poses and the
## imported strike clips alike.
##
## It used to default to null, and null meant "skip the conversion and copy
## verbatim", i.e. exactly the bug this function exists to fix. RomanModel
## passed a real skeleton so the base library came out upright, while
## WrestlerController._adapt_animation_library() called the same method with
## one argument for PAIRED_POSES and STRIKE_CLIPS -- so those two took the
## null path in silence and stayed inverted, which is why GRAPPLE_HOLD and
## the mocap strikes played head-down (J_Head 0.385 below J_Hips 0.964, a
## foot at 1.793) while LOCOMOTION and TIE_UP looked fine. A default that
## quietly does the broken thing is worse than a required argument, so the
## fallback now resolves the rig instead of abandoning the conversion.
func adapt_animation_library(source: AnimationLibrary,
		source_skeleton: Skeleton3D = null) -> AnimationLibrary:
	var target := AnimationLibrary.new()
	var skeletons := _animation_skeletons()
	# Owned only when we loaded it here, and freed before returning.
	var owned_source_root: Node = null
	if source_skeleton == null:
		owned_source_root = (load(BASE_RIG) as PackedScene).instantiate()
		source_skeleton = _source_skeleton(owned_source_root)
		if source_skeleton == null:
			push_error("RomanModel: base rig has no skeleton to retarget from")
	for name in source.get_animation_list():
		var source_animation: Animation = source.get_animation(name)
		var animation := Animation.new()
		animation.length = source_animation.length
		animation.loop_mode = source_animation.loop_mode
		animation.step = source_animation.step
		for track in source_animation.get_track_count():
			var path := source_animation.track_get_path(track)
			var bone := String(path.get_concatenated_subnames())
			if not BONE_MAP.has(bone):
				continue
			var track_type := source_animation.track_get_type(track)
			for skeleton in skeletons:
				var target_bone: String = BONE_MAP[bone]
				var output_track := animation.add_track(track_type)
				animation.track_set_path(output_track, NodePath("%s:%s" % [
						get_path_to(skeleton), target_bone]))
				animation.track_set_interpolation_type(output_track,
						source_animation.track_get_interpolation_type(track))
				var rest := _rest_pair(source_skeleton, bone, skeleton, target_bone)
				for key in source_animation.track_get_key_count(track):
					animation.track_insert_key(output_track,
							source_animation.track_get_key_time(track, key),
							_retarget_key(track_type,
									source_animation.track_get_key_value(track, key),
									rest),
							source_animation.track_get_key_transition(track, key))
		target.add_animation(name, animation)
	if owned_source_root:
		owned_source_root.free()
	return target

## The two rest transforms a key has to be converted between, or an empty
## dictionary when either bone is missing (then the key passes through).
func _rest_pair(source_skeleton: Skeleton3D, source_bone: String,
		target_skeleton: Skeleton3D, target_bone: String) -> Dictionary:
	if source_skeleton == null:
		return {}
	var source_index := source_skeleton.find_bone(source_bone)
	var target_index := target_skeleton.find_bone(target_bone)
	if source_index < 0 or target_index < 0:
		return {}
	# Parent global rest rotations, defaulting to identity at a root bone.
	# These are what let a key be rotated *into* the target's frame rather
	# than merely rebased onto its rest -- see _retarget_key().
	var source_parent := Quaternion.IDENTITY
	var source_parent_index := source_skeleton.get_bone_parent(source_index)
	if source_parent_index >= 0:
		source_parent = source_skeleton.get_bone_global_rest(
				source_parent_index).basis.get_rotation_quaternion()
	var target_parent := Quaternion.IDENTITY
	var target_parent_index := target_skeleton.get_bone_parent(target_index)
	if target_parent_index >= 0:
		target_parent = target_skeleton.get_bone_global_rest(
				target_parent_index).basis.get_rotation_quaternion()
	# --- rest-POSE alignment, on top of the rest-ORIENTATION conversion ----
	#
	# The conversion below preserves each key's offset from its own rig's rest.
	# That is right when the two rests are the same physical pose and differ
	# only in how the bones are named and rolled. These two are not: measured
	# off the skeletons, the base rig rests in a flat T (upperarm, lowerarm and
	# hand all at y=1.441) while Roman rests in an A (1.396 / 1.330 / 1.270,
	# the arm descending 0.126 m across its span, about 15 degrees).
	#
	# Preserving the offset therefore preserves that 15 degrees, and every
	# authored pose arrives on Roman with the guard dropped. Measured with
	# tools/probe/pose_compare.tscn on Idle_Ready: his hands sat 0.146 of a
	# body height below the mannequin's -- 22 cm -- and 6 cm closer to his own
	# centre line, while his head and pelvis tracked to within a centimetre.
	# Rendered, that is the "standing in a weird pose" report: arms folded low
	# across the chest instead of a guard up in front of it.
	#
	# The clips are authored as absolute hand positions in metres, solved
	# against the base rig's geometry (tools/blender/rig_pose.py), so what has
	# to survive the retarget is where the hand ENDS UP, not how far it moved
	# from a rest pose the author never saw. So each bone's rest is aligned
	# first: rotate Roman's rest bone direction onto the base rig's before the
	# offset is applied. The roll correction the conversion already does is
	# untouched -- this only removes the pose difference, which is a swing.
	var source_align := _rest_align(source_skeleton, source_bone,
			target_skeleton, target_bone)
	var parent_align := Quaternion.IDENTITY
	if source_parent_index >= 0 and target_parent_index >= 0:
		var source_parent_name := source_skeleton.get_bone_name(source_parent_index)
		if BONE_MAP.has(source_parent_name):
			parent_align = _rest_align(source_skeleton, source_parent_name,
					target_skeleton, BONE_MAP[source_parent_name])
	# Expressed back as a local rest, so _retarget_key()'s formula is unchanged.
	var target_parent_aligned := parent_align * target_parent
	var target_rest: Transform3D = target_skeleton.get_bone_rest(target_index)
	var target_basis_aligned := target_parent_aligned.inverse() \
			* source_align * target_parent \
			* target_rest.basis.get_rotation_quaternion()
	return {
		"source": source_skeleton.get_bone_rest(source_index),
		"target": target_rest,
		"target_aligned_basis": target_basis_aligned.normalized(),
		"source_parent": source_parent,
		"target_parent": target_parent,
		"target_parent_aligned": target_parent_aligned.normalized(),
	}


## Shortest-arc rotation taking Roman's rest direction for a bone onto the
## base rig's, both in world space.
##
## "Direction" is the vector from the bone's own rest position to its first
## MAPPED child's -- the segment the bone actually is, measured rather than
## read off a bone axis, because the two rigs do not agree about which local
## axis points down a bone and that disagreement is precisely what the
## conversion below already handles.
##
## A bone with no mapped child (a finger tip, a foot) inherits its parent's
## alignment: it has no direction of its own to measure, and leaving it at
## identity would un-rotate the hand at the end of an arm that was corrected.
func _rest_align(source_skeleton: Skeleton3D, source_bone: String,
		target_skeleton: Skeleton3D, target_bone: String) -> Quaternion:
	var source_index := source_skeleton.find_bone(source_bone)
	var target_index := target_skeleton.find_bone(target_bone)
	if source_index < 0 or target_index < 0:
		return Quaternion.IDENTITY
	var source_child := -1
	var target_child := -1
	for child in source_skeleton.get_bone_children(source_index):
		var child_name := source_skeleton.get_bone_name(child)
		if not BONE_MAP.has(child_name):
			continue
		var mapped := target_skeleton.find_bone(BONE_MAP[child_name])
		if mapped < 0:
			continue
		source_child = child
		target_child = mapped
		break
	if source_child < 0:
		var parent_index := source_skeleton.get_bone_parent(source_index)
		if parent_index < 0:
			return Quaternion.IDENTITY
		var parent_name := source_skeleton.get_bone_name(parent_index)
		if not BONE_MAP.has(parent_name):
			return Quaternion.IDENTITY
		return _rest_align(source_skeleton, parent_name,
				target_skeleton, BONE_MAP[parent_name])
	var source_dir: Vector3 = (
			source_skeleton.get_bone_global_rest(source_child).origin
			- source_skeleton.get_bone_global_rest(source_index).origin)
	var target_dir: Vector3 = (
			target_skeleton.get_bone_global_rest(target_child).origin
			- target_skeleton.get_bone_global_rest(target_index).origin)
	if source_dir.length() < 0.0001 or target_dir.length() < 0.0001:
		return Quaternion.IDENTITY
	return Quaternion(target_dir.normalized(), source_dir.normalized())


func _retarget_key(track_type: int, value: Variant, rest: Dictionary) -> Variant:
	if rest.is_empty():
		return value
	var source_rest: Transform3D = rest["source"]
	var target_rest: Transform3D = rest["target"]
	var source_parent: Quaternion = rest["source_parent"]
	var target_parent: Quaternion = rest["target_parent"]
	# The rotation branch works off the ALIGNED rest (see _rest_pair); the
	# position branch deliberately does not. Root translation was measured and
	# fixed against the unaligned frames -- see the note in that branch -- and
	# the alignment is a swing of the limb chains, which carry no position
	# tracks at all.
	var target_aligned_basis: Quaternion = rest.get("target_aligned_basis",
			target_rest.basis.get_rotation_quaternion())
	var target_parent_aligned: Quaternion = rest.get("target_parent_aligned",
			target_parent)
	match track_type:
		Animation.TYPE_ROTATION_3D:
			var source_basis := source_rest.basis.get_rotation_quaternion()
			var target_basis := target_rest.basis.get_rotation_quaternion()
			# Rebasing a key onto the target's rest -- target * source^-1 * key
			# -- fixes a difference in rest *orientation* but not one in bone
			# *roll*, because it never leaves local space: a rotation about
			# the source bone's own axis stays about that axis, whatever the
			# target's axis happens to be. That is why the gross inversion
			# went away while the arms stayed folded across the face.
			#
			# So take the key's offset from the source's rest, carry it out to
			# world space through the source parent's global rest, back into
			# the target's local space through the target parent's, and only
			# then apply it to the target's rest. Now a bend is a bend about
			# the same world axis on both rigs regardless of how either
			# skeleton names or rolls that bone.
			# The delta is taken in the *parent's* frame, not the bone's own.
			# A bone's global orientation is parent_global * local, so its
			# offset from rest in global terms is
			#     P * (key * rest^-1) * P^-1
			# -- key post-multiplied by the inverse rest, not pre-multiplied.
			# Pre-multiplying (rest^-1 * key) measures the offset in the
			# bone's own rotating frame, which conjugating by P then carries
			# to the wrong place: it straightened the legs, whose rest axes
			# happen to agree between the rigs, and left the arms folded up
			# over the head, whose do not.
			var delta := (value as Quaternion) * source_basis.inverse()
			var world := source_parent * delta * source_parent.inverse()
			var local := target_parent_aligned.inverse() * world * target_parent_aligned
			return (local * target_aligned_basis).normalized()
		Animation.TYPE_POSITION_3D:
			# Position tracks are the translation part of the same pose, so
			# they get the same treatment as the rotation above -- and for the
			# same reason, that treatment has to go through the PARENT frames.
			#
			# This used to rotate the offset by the two bones' own rest bases
			# (target_rest.basis * source_rest.basis^-1). That is the local
			# -space mistake the rotation branch documents, and on the hips it
			# is a 180-degree flip: the base rig's pelvis rests at
			# euler (104.5, 0, 0) and Roman's J_Hips at (-90, 0, 0), so the
			# product is (14.5, -180, 180). It inverted the vertical component
			# of every root translation.
			#
			# Measured, on Death01's pelvis key at 1.2s: the offset's vertical
			# component is -0.838, and flipping it put the retargeted hips at
			# +1.974 instead of +0.085 in rest space -- J_Hips at world y=2.04
			# with the feet at 2.37, a man lying flat two metres above the mat.
			# That is the "Roman floats when he is pinned" report, and it hit
			# every clip with real root motion (Death01, Roll) while leaving
			# the upright ones (Idle, the strikes) untouched, because those
			# barely translate the root at all.
			#
			# Carried through the parent global rests the offset arrives at
			# 0.085 against the 0.079 that the un-retargeted rig produces for
			# the same key -- the remainder is the height scale below, which is
			# real: Roman is the taller man.
			var offset := (value as Vector3) - source_rest.origin
			var world := source_parent * offset
			var local := target_parent.inverse() * world
			# Scaled by the two bones' rest lengths: without it a taller rig
			# inherits a shorter one's stride and the feet slide.
			var source_length := source_rest.origin.length()
			var scale := 1.0
			if source_length > 0.0001:
				scale = target_rest.origin.length() / source_length
			return target_rest.origin + local * scale
		_:
			return value