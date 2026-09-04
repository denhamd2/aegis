extends GdUnitTestSuite
## VISUAL_BAR.md's first priority, in the parts of it a headless test can
## honestly check.
##
## A correction first, because the previous version of this suite was
## measuring the wrong thing and passing. It asserted that a wrestler's
## *albedo* sat 0.24-0.31 in relative luminance from the mat's albedo -- but
## 0.24-0.31 is a number read off *rendered pixels* of a reference still.
## Albedo and rendered luminance are not the same space, and the gap between
## them here was not small: the shipped build passed this suite at 0.379 in
## albedo while its actual frames measured 0.161. A gate that reads a
## different quantity from the one it names is not a gate.
##
## So the luminance band moved to where it can be measured properly.
## `tools/refs/measure_silhouette.py`, fed by the capture harness's
## `--silhouette-shot` mode, renders the standoff plus a segmentation mask and
## reports the same three pairings VISUAL_BAR.md tabulates, off our own
## pixels. That needs a renderer, so it cannot live in this suite.
##
## What remains here is renderer-independent and still load-bearing: the
## *mechanisms* the reference describes, which are what make the rendered
## numbers come out right.
##
##   * The reference's two men sit within 0.07 of each other in value and
##     separate by hue. Both of ours are skin-dominant, so it is their skin
##     that has to agree in value -- asserted below -- while the gear carries
##     the hue difference.
##   * A wrestler has to be darker than the mat. Asserted here in albedo, at
##     an albedo threshold, explicitly *not* the reference's rendered 0.24.
##   * The colourway only reaches the frame if the gear it lives on exists,
##     and if nothing writes to the mesh both wrestlers share.

const MATCH_SCENE := preload("res://scenes/match.tscn")

## Rec. 709 relative luminance on linearised sRGB — the same function
## tools/refs/measure_frame.py applies to a frame, so a number here and a
## number taken off a capture mean the same thing.
func _luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	var linear: Array[float] = []
	for c: float in channels:
		linear.append(c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

## An albedo-space floor, and deliberately not the reference's 0.24: that
## number is rendered luminance and belongs to measure_silhouette.py. This
## asserts the weaker, renderer-independent thing it still makes sense to
## assert here -- that a wrestler's dominant surface is meaningfully darker
## than the surface he is seen against, so no colourway change can quietly
## put a man at the mat's value. The rendered band is checked separately and
## recorded in VISUAL_BAR.md.
const MIN_SKIN_MAT_ALBEDO_GAP := 0.15

## The reference's two wrestlers are 0.07 apart in luminance, so value is
## explicitly *not* how they separate from each other. Skin is the dominant
## surface on both, so skin is what has to hold that together.
const MAX_SKIN_VALUE_GAP := 0.07

const MIN_HUE_SEPARATION := 0.15

func _wrestlers() -> Array:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	return [scene.get_node("WrestlerA"), scene.get_node("WrestlerB"), scene]

## The mat is the surface both wrestlers are seen against for the whole match.
func _mat_albedo(scene: Node) -> Color:
	var mesh_instance: MeshInstance3D = scene.get_node("Ring/Floor/MeshInstance3D")
	var material: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
	return material.albedo_color

func test_each_wrestlers_skin_is_darker_than_the_mat() -> void:
	var parts := _wrestlers()
	var mat := _luminance(_mat_albedo(parts[2]))
	for wrestler: WrestlerController in [parts[0], parts[1]]:
		var skin := _luminance(wrestler.skin_tone)
		assert_float(mat - skin).override_failure_message(
			"%s's skin is %.3f in relative luminance and the mat is %.3f. "
			% [wrestler.name, skin, mat]
			+ "Skin is most of what a wrestler renders as, so a wrestler at or "
			+ "above the mat's value has no silhouette. This is an albedo "
			+ "check; the rendered band lives in measure_silhouette.py."
		).is_greater_equal(MIN_SKIN_MAT_ALBEDO_GAP)

## The mechanism behind the reference's "within 0.07 of each other": both men
## are skin-dominant, so two very different complexions would split their
## values no matter what the gear does.
func test_the_two_wrestlers_read_at_the_same_value() -> void:
	var parts := _wrestlers()
	var a := _luminance((parts[0] as WrestlerController).skin_tone)
	var b := _luminance((parts[1] as WrestlerController).skin_tone)
	assert_float(absf(a - b)).override_failure_message(
		"The two complexions are %.3f and %.3f in relative luminance, %.3f apart. "
		% [a, b, absf(a - b)]
		+ "The reference's two wrestlers are within 0.07; they separate by hue, "
		+ "not brightness, and skin is what carries that."
	).is_less_equal(MAX_SKIN_VALUE_GAP)

## Value is how the reference separates a wrestler from the mat; hue is how
## it separates the two wrestlers. Asserting value here would contradict the
## measurement (its two wrestlers are 0.07 apart).
func test_the_two_wrestlers_separate_from_each_other_by_hue() -> void:
	var parts := _wrestlers()
	var a: WrestlerController = parts[0]
	var b: WrestlerController = parts[1]
	var gap: float = absf(a.attire_body.h - b.attire_body.h)
	gap = minf(gap, 1.0 - gap) # hue is a circle
	assert_float(gap).override_failure_message(
		"Both wrestlers wear hue %.3f/%.3f. They were literally the same material "
		% [a.attire_body.h, b.attire_body.h]
		+ "before this, which is what made a paired move read as one blob."
	).is_greater_equal(MIN_HUE_SEPARATION)

## The accent is what ties a man in the ring to his plate in the corner, so
## the two must not be able to drift apart -- MatchHUD reads it off the
## wrestler rather than keeping its own copy.
func test_the_hud_draws_each_plate_in_that_wrestlers_own_accent() -> void:
	var parts := _wrestlers()
	var hud: MatchHUD = (parts[2] as Node).get_node("MatchHUD/Draw")
	assert_object(hud.wrestler_a).is_same(parts[0])
	assert_object(hud.wrestler_b).is_same(parts[1])
	for wrestler: WrestlerController in [parts[0], parts[1]]:
		assert_bool(wrestler.attire_accent != wrestler.attire_body) \
			.override_failure_message(
				"%s's accent is his body colour, so the plate flash is invisible"
				% wrestler.name
			).is_true()

## Both wrestlers instance the same .glb, so its Mesh — and every material
## hanging off it — is one shared resource. Colouring a surface material
## directly would colour both men, the same shared-resource trap that once
## made a single MoveDef's "applied" flag leak between wrestlers, so
## _apply_colorway() duplicates before it writes and the shared materials
## must still hold the .glb's own values afterwards.
const GLB_BODY_ALBEDO := Color(0.9059, 0.6667, 0.2275)

func test_no_wrestler_writes_to_the_shared_mesh_material() -> void:
	var parts := _wrestlers()
	var a: MeshInstance3D = (parts[0] as Node).find_child("Mannequin", true, false)
	var b: MeshInstance3D = (parts[1] as Node).find_child("Mannequin", true, false)
	assert_object(a.mesh).override_failure_message(
		"The two wrestlers no longer share a mesh; this test guards the case "
		+ "where they do, and should be revisited rather than deleted."
	).is_same(b.mesh)
	var shared: StandardMaterial3D = a.mesh.surface_get_material(0)
	# Channel-wise rather than Color.is_equal_approx(): that compares on
	# CMP_EPSILON (1e-5) and the .glb's own albedo does not round-trip that
	# tightly through the constant above. A tenth of a percent per channel is
	# far tighter than any recolouring would be.
	var drift := maxf(maxf(
			absf(shared.albedo_color.r - GLB_BODY_ALBEDO.r),
			absf(shared.albedo_color.g - GLB_BODY_ALBEDO.g)),
			absf(shared.albedo_color.b - GLB_BODY_ALBEDO.b))
	assert_float(drift).override_failure_message(
		"The shared .glb body material is now %s, not the %s it ships with — "
		% [shared.albedo_color, GLB_BODY_ALBEDO]
		+ "something coloured the resource itself, which colours both wrestlers."
	).is_less(0.001)


## The colourway only reaches the frame if the gear it lives on is actually
## built. Both wrestlers' bodies are skin now, so a silent failure in
## WrestlerAttire would leave two identical nude mannequins -- which is
## exactly what the slice's gap line described before this round.
func test_each_wrestler_wears_the_gear_that_carries_his_colourway() -> void:
	var parts := _wrestlers()
	for wrestler: WrestlerController in [parts[0], parts[1]]:
		var skeleton: Skeleton3D = wrestler.find_child("Skeleton3D", true, false)
		assert_object(skeleton).is_not_null()
		var worn := 0
		for child in skeleton.get_children():
			if String(child.name).begins_with(WrestlerAttire.PREFIX):
				worn += 1
		var expected := WrestlerAttire.total_piece_count(wrestler.body_variant)
		assert_int(worn).override_failure_message(
			"%s is wearing %d of %d gear pieces. BoneAttachment3D resolves its "
			% [wrestler.name, worn, expected]
			+ "bone from its parent, so every piece must be a direct child of "
			+ "the Skeleton3D -- grouping them under a tidy node once left the "
			+ "whole outfit piled at the wrestler's feet."
		).is_equal(expected)

## One mannequin at two tints read as the same body twice, which is half of
## what the slice was marked down for. Colour is not build.
func test_the_two_wrestlers_are_built_differently() -> void:
	var parts := _wrestlers()
	var a: WrestlerController = parts[0]
	var b: WrestlerController = parts[1]
	assert_float(absf(a.physique_bulk - b.physique_bulk)).override_failure_message(
		"Both wrestlers are built at bulk %.2f/%.2f. They share one CC0 "
		% [a.physique_bulk, b.physique_bulk]
		+ "mannequin, so if their gear is the same width too there is nothing "
		+ "separating their silhouettes but colour."
	).is_greater_equal(0.1)
	assert_float(absf(a.physique_height - b.physique_height)).override_failure_message(
		"Both wrestlers stand at height %.2f/%.2f. Bulk widens the gear; "
		% [a.physique_height, b.physique_height]
		+ "without a height difference two men still share one outline."
	).is_greater_equal(0.05)

## Blank heads read as the same head twice at match-camera distance. The two
## men must wear different head identities, and each head set must actually
## be built on the skeleton.
func test_the_two_wrestlers_wear_different_heads() -> void:
	var parts := _wrestlers()
	var a: WrestlerController = parts[0]
	var b: WrestlerController = parts[1]
	assert_int(a.body_variant).override_failure_message(
		"WrestlerA and WrestlerB share body_variant %d -- one head twice."
		% a.body_variant
	).is_not_equal(b.body_variant)
	for wrestler: WrestlerController in [parts[0], parts[1]]:
		var skeleton: Skeleton3D = wrestler.find_child("Skeleton3D", true, false)
		assert_object(skeleton).is_not_null()
		var head_worn := 0
		for child in skeleton.get_children():
			var n := String(child.name)
			if n.begins_with(WrestlerAttire.PREFIX) and n.contains("Head"):
				head_worn += 1
		assert_int(head_worn).override_failure_message(
			"%s wears %d of %d head pieces -- a blank mannequin head."
			% [wrestler.name, head_worn,
				WrestlerAttire.head_pieces(wrestler.body_variant).size()]
		).is_equal(WrestlerAttire.head_pieces(wrestler.body_variant).size())

## Variant 2 is specified statically (no renderer needed): denim shorts on
## both thighs instead of trunks, a single pelvis waistband, and a steel
## chain collar. If the spec drifts, the scene silently wears something else
## and only a capture would catch it.
func test_variant_two_specs_denim_shorts_and_steel_chain() -> void:
	var thigh_fixed := 0
	var pelvis := 0
	var steel_collars := 0
	for piece in WrestlerAttire.all_pieces(2):
		if String(piece.bone).begins_with("thigh") and piece.fixed.a > 0.0:
			thigh_fixed += 1
		if piece.bone == "pelvis":
			pelvis += 1
		if piece.bone == "neck_01" and piece.metal:
			steel_collars += 1
	assert_int(thigh_fixed).override_failure_message(
		"Variant 2 should wear fixed-colour denim on both thighs, found %d."
		% thigh_fixed
	).is_equal(2)
	assert_int(pelvis).override_failure_message(
		"Variant 2 should wear one waistband and no trunks, found %d pelvis pieces."
		% pelvis
	).is_equal(1)
	assert_int(steel_collars).override_failure_message(
		"Variant 2 should wear one steel chain collar, found %d."
		% steel_collars
	).is_equal(1)

## WrestlerB is the brawler: variant 2 with a green accent for the bands.
func test_wrestler_b_wears_the_brawler_identity() -> void:
	var parts := _wrestlers()
	var b: WrestlerController = parts[1]
	assert_int(b.body_variant).override_failure_message(
		"WrestlerB should wear body_variant 2, found %d." % b.body_variant
	).is_equal(2)
	assert_float(absf(b.attire_accent.h - 0.33)).override_failure_message(
		"WrestlerB's bands should read green (hue ~0.33), found hue %.3f."
		% b.attire_accent.h
	).is_less_equal(0.05)
