extends GdUnitTestSuite
## VISUAL_BAR.md's first priority, as a number.
##
## "Silhouette readability at match-camera distance (both wrestlers legible
## mid-grapple, not just in idle poses)" was a phrase a critic had to judge
## by eye. Both wrestlers instanced the same .glb with the same CC0
## placeholder materials, so there was nothing to judge: the paired-move
## apex frame of a real capture held one orange blob, and measured against
## the mat the attire sat 0.014 apart in relative luminance where the
## reference still measures 0.24-0.31.
##
## The reference relationship (see VISUAL_BAR.md "Silhouette separation",
## measured with tools/refs/measure_frame.py) has two halves, and they are
## different mechanisms:
##   * wrestler vs. mat -- separated by *value*, 0.24-0.31 apart.
##   * wrestler vs. wrestler -- only 0.07 apart in value, so they separate
##     from each other by *hue*, not by brightness.
## Both are asserted here against the shipped match scene, on albedo, which
## is renderer-independent: ARCHITECTURE.md forbids judging a visual slice
## on a software render, and this needs no renderer at all.

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

## The floor the reference sets for a wrestler against the mat. Measured at
## 0.24-0.31 there; this asserts the lower end rather than the mean, so the
## gate is the reference's own worst case and not an average of it.
const MIN_MAT_SEPARATION := 0.24
## The reference's two wrestlers are 0.07 apart in luminance, so value is
## explicitly *not* how they separate from each other. Requiring a hue gap
## instead is what that measurement says to do.
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

func test_each_wrestler_reads_against_the_mat_by_value() -> void:
	var parts := _wrestlers()
	var mat := _luminance(_mat_albedo(parts[2]))
	for wrestler: WrestlerController in [parts[0], parts[1]]:
		var attire := _luminance(wrestler.attire_body)
		assert_float(absf(mat - attire)).override_failure_message(
			"%s's attire is %.3f in relative luminance and the mat is %.3f — %.3f apart. "
			% [wrestler.name, attire, mat, absf(mat - attire)]
			+ "The reference still measures 0.24-0.31, and a wrestler this close to "
			+ "the mat has no silhouette at match-camera distance."
		).is_greater_equal(MIN_MAT_SEPARATION)

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
