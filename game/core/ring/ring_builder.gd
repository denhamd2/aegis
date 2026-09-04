extends Node3D
class_name RingBuilder
## Generates every cosmetic surface of the ring: the canvas, the ropes, the
## turnbuckles, the posts, the apron detail and the steel steps.
##
## Why generated rather than authored in scenes/ring.tscn, following the same
## reasoning as core/arena/arena_builder.gd: a sagging rope is 24 segments of
## swept tube per span and there are twelve spans, a turnbuckle is a pad plus
## three straps plus three buckles per corner, and a canvas is a texture. None
## of that is hand-typeable as transforms, and expressed as a .tscn it would be
## exactly the transform soup nobody can review. Expressed as the constants
## below it is reviewable.
##
## EVERYTHING HERE IS COSMETIC. This file creates no CollisionObject3D, joins
## no physics layer, and is read by no gameplay system. The ring's colliders --
## Floor/CollisionShape3D and the four RopeCollision* bodies in the group
## "ring_ropes" -- stay in scenes/ring.tscn untouched, at their original
## extents, which is why rope *sag* is a displacement of the rendered mesh only
## and the bodies wrestler_controller.gd bounces off have not moved.
##
## DIMENSIONS THAT MAY NOT CHANGE (the measurement chain hangs off them):
##   * the mat is 6m square and its surface is y = 0. refs/camera.md's 41-deg
##     lens, test_camera_framing.gd's MAX_SEPARATION 8.49 and
##     grapple_rig.gd's RING_HALF_EXTENT 2.0 are all derived from it.
##   * the ropes' span sits at +/-3.1 on the perpendicular axis, at heights
##     0.5 / 0.85 / 1.2. camera.md derives the lens from the 3.1m figure.
## Both are asserted below rather than merely commented, so a later edit that
## drifts them fails loudly instead of silently invalidating the camera.

# --- The frozen numbers ------------------------------------------------------
const MAT_HALF := 3.0
const MAT_TOP_LOCAL := 0.1  ## Floor box is 0.2 thick, Ring sits at y = -0.1.
const ROPE_SPAN := 3.1
const ROPE_HEIGHTS := [0.5, 0.85, 1.2]
const POST_XZ := 3.0

# --- Ropes -------------------------------------------------------------------
## Rope radius. The reference's ropes read as thin bright lines
## (gauntlet/refs/frames/wide_standoff_broadcast_angle.jpg); the outgoing
## BoxMesh was 0.05 square, which at match-camera distance is a plank. A real
## ring rope is a steel cable inside a tape wrap, roughly 4-5cm over the wrap.
## COVERAGE DECISION -- gauntlet/refs/ measures no rope diameter.
const ROPE_RADIUS := 0.024
const ROPE_RINGS := 8
const ROPE_SEGMENTS := 28
## Sag at midspan, per rope, top to bottom. Ropes are tensioned turnbuckle to
## turnbuckle and the lower ones are slacker. COVERAGE DECISION -- the
## reference frames show sag but gauntlet/refs/ measures no depth for it.
## These are ~0.5-0.8% of the 6.1m span, which is what reads as tension rather
## than as washing line.
const ROPE_SAG := {1.2: 0.030, 0.85: 0.040, 0.5: 0.048}
## How far past the post centre a rope runs before the turnbuckle pad swallows
## its end. The pad is 0.30 deep on the diagonal, so 0.075 puts the cut face
## inside it.
const ROPE_OVERRUN := 0.060

# --- Turnbuckles -------------------------------------------------------------
## The corner pad wraps the post, rotated 45 degrees to face ring centre, and
## is deep enough on the diagonal to swallow both rope ends (which pass the
## post centre 0.1m to the outside). COVERAGE DECISION -- proportions.
const PAD_WIDTH := 0.37
const PAD_DEPTH := 0.24
const PAD_BOTTOM := 0.33
const PAD_TOP := 1.46
## Straps: two flat bands per rope height, wrapping the pad.
const STRAP_HEIGHT := 0.035
const STRAP_GAP := 0.055
const BUCKLE := Vector3(0.075, 0.065, 0.05)

# --- Posts -------------------------------------------------------------------
const POST_RADIUS := 0.085
const POST_BOTTOM := -0.10
const POST_TOP := 1.60
const CAP_HEIGHT := 0.07
const CAP_RADIUS := 0.115

# --- Apron -------------------------------------------------------------------
const APRON_OUT := 3.20
const APRON_TOP := -0.10
const APRON_BOTTOM := -1.00
## Vertical folds per side. A hanging skirt is not a flat board; the ribs are
## what stop it reading as one. COVERAGE DECISION.
const APRON_FOLDS := 9

# --- Steel steps -------------------------------------------------------------
const STEP_TREADS := 3
const STEP_WIDTH := 1.45
const STEP_RUN := 0.36
const STEP_TOP_Y := -0.14
const STEP_FLOOR_Y := -1.00

# --- Texture generation ------------------------------------------------------
const CANVAS_SIZE := 1024
## Canvas panels are sewn in strips. Five seams across 6m is a 1.2m panel,
## which is the width canvas is milled at. COVERAGE DECISION.
const CANVAS_PANEL := 1.2
const CANVAS_SEED := 20260903
## The mat's palette, as effective albedo (albedo_color is CANVAS_WHITE, so a
## texel is very nearly the surface's albedo outright).
const CANVAS_WHITE := Color(0.97, 0.98, 1.0)
const CANVAS_FIELD := Color(0.50, 0.69, 0.94)
const CANVAS_DISC := Color(0.30, 0.44, 0.70)
const CANVAS_DISC_RIM := Color(0.24, 0.34, 0.56)
const CANVAS_MARK := Color(0.99, 0.99, 1.0)

## Generated once per process. match.tscn is instantiated by several test
## suites and by every capture; regenerating a 512-square canvas each time is
## pure waste.
static var _canvas_texture: ImageTexture
static var _canvas_normal_texture: ImageTexture
## The canvas height field, kept so the normal map is derived from the same
## weave the albedo was drawn from rather than from a second, disagreeing one.
static var _canvas_height: PackedFloat32Array
static var _rope_texture: ImageTexture
static var _apron_texture: ImageTexture
static var _pad_texture: ImageTexture

var _ring: Node3D


func _ready() -> void:
	_ring = get_parent() as Node3D
	if _ring == null:
		push_error("RingBuilder must be a child of the Ring node.")
		return
	_assert_frozen_dimensions()
	_build_canvas()
	_build_ropes()
	_build_turnbuckles_and_posts()
	_build_apron_detail()
	_build_steps()


## The measurement chain in camera.md / test_camera_framing.gd / grapple_rig.gd
## is derived from these two numbers. If a later edit moves them, this says so
## instead of letting every downstream number quietly become wrong.
func _assert_frozen_dimensions() -> void:
	var shape: CollisionShape3D = _ring.get_node_or_null("Floor/CollisionShape3D")
	if shape and shape.shape is BoxShape3D:
		var size: Vector3 = (shape.shape as BoxShape3D).size
		assert(is_equal_approx(size.x, 6.0) and is_equal_approx(size.z, 6.0),
			"The mat must stay 6m square -- camera.md and test_camera_framing.gd derive from it.")
	assert(is_equal_approx(_ring.position.y + MAT_TOP_LOCAL, 0.0),
		"The mat surface must stay at y = 0.")
	assert(is_equal_approx(ROPE_SPAN, 3.1), "camera.md derives the 41-degree lens from ropes at 3.1m.")


# =============================================================== materials ===
## EVERY material this file uses is resolved here and nowhere else, so the
## swap between the two sources below is a single edit.
##
## The source of record is core/materials/material_library.gd (A2's), reached
## through MATERIAL_LIBRARY by path rather than by class_name. That indirection
## is deliberate and not cargo cult: the library is authored on a sibling
## branch and is merged in underneath this one, so a direct
## `MaterialLibrary.resolve(...)` call would be a parse error in this worktree
## and the ring would not build at all. Resolved by path, this file runs
## correctly on its own and picks the library up the moment the merge lands,
## with no edit at integration.
##
## The fallbacks below are what this file uses until then. They are plain
## StandardMaterial3D with no PBR maps behind them, which is exactly what the
## library exists to fix -- it sizes texel density in world metres, so a 1K map
## over a 6m mat carries detail instead of stretching into nothing.
const MATERIAL_LIBRARY := "res://core/materials/material_library.gd"

static var _library: Object
static var _library_checked := false


## Resolves `key` from the material library, falling back to `fallback`.
## `overrides` is passed through: the library takes a spec-field dictionary, so
## the per-corner turnbuckle tint is an override rather than a new key.
func _resolve(key: String, fallback: StandardMaterial3D,
		overrides: Dictionary = {}) -> StandardMaterial3D:
	if not _library_checked:
		_library_checked = true
		if ResourceLoader.exists(MATERIAL_LIBRARY):
			_library = load(MATERIAL_LIBRARY)
	if _library == null:
		return fallback
	var resolved: Variant = _library.call("resolve", key, overrides)
	if resolved is StandardMaterial3D:
		# Duplicated because the library may hand back a shared instance and
		# two call sites here go on to set albedo on what they get. Mutating a
		# shared material would reach every other consumer of the key.
		return (resolved as StandardMaterial3D).duplicate() as StandardMaterial3D
	push_warning("RingBuilder: material key '%s' did not resolve; using the "
		% key + "local fallback.")
	return fallback


func _mat(albedo: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	# metallic is 0 or 1, never between: a surface is a conductor or it is not.
	# The outgoing post material sat at 0.3, which describes no real material.
	m.metallic = metallic
	return m


## Steel, as a DIELECTRIC, and this is a coverage decision with a reason rather
## than a slip. metallic is 0 or 1 and never between -- which is why the
## outgoing post material's 0.3 was wrong by construction -- but a conductor
## renders as nothing except what it reflects, and the hall around this ring
## has no reflection probe and no sky. Set metallic 1.0 and the posts, caps and
## steps come out black. The library agrees: its `ring_post` is metallic 0.0
## painted steel, and it flags `ring_post_chrome` as unusable for this exact
## reason. Revisit the day the arena gets a radiance map.
func _steel() -> StandardMaterial3D:
	return _resolve("ring_steel", _mat(Color(0.60, 0.61, 0.65), 0.28))


## The canvas -- the one material that cannot come wholesale from the library,
## and the reason is the mark on it. `ring_canvas` is a tinted fabric with no
## logo, and a StandardMaterial3D has exactly one albedo slot, so a library
## albedo and a mat logo cannot both occupy it. What the library still supplies
## here is everything else it is good for: the fabric's normal and roughness
## maps at its world-metre texel density. Only albedo is overridden.
##
## Why the blue is entirely in the texture and albedo_color is near-white: a
## texture cannot brighten past albedo_color, so albedo_color has to be the
## LIGHTEST value on the mat, and on the reference mat that is the mark, not
## the field. Round 1 set albedo_color to the field's own blue instead, and the
## arithmetic consequence was measurable: the mark's strokes could only reach
## relative luminance 0.573 against a 0.430 field, a ratio of 1.33, where the
## reference's white-on-blue mark is roughly 4. Cropping the wide frame in half
## found the ring half at coarse detail 0.114 against the reference's 0.438 --
## so a low-contrast mark on the frame's largest surface was most of that gap,
## and this is the fix for it. The field's effective albedo is unchanged
## (0.52,0.70,0.93), relative luminance 0.430 against the outgoing flat mat's
## 0.434; only the mark moved, to 0.96.
##
## test_wrestler_colorway.gd's albedo check still passes and still means
## something -- it asserts the mat is far above either wrestler's skin, and
## near-white is further above, not less. The mat's RENDERED value is an
## exposure anchor being re-solved in lighting and is deliberately not chased
## here.
func _canvas_material() -> StandardMaterial3D:
	var m := _resolve("ring_canvas", _mat(CANVAS_WHITE, 0.86))
	m.albedo_color = CANVAS_WHITE
	m.albedo_texture = _canvas()
	if m.roughness_texture == null:
		# The weave drives roughness as well as albedo. A canvas is not
		# uniformly glossy -- the thread crowns catch the ring rig and the
		# valleys do not -- and that specular breakup is detail the albedo
		# alone cannot produce, because it survives at grazing angles where
		# the albedo variation is already washed out by the light. The library
		# brings its own roughness map when it is present; this stands in.
		m.roughness = 0.86
		m.roughness_texture = _canvas()
	if m.normal_texture == null:
		m.normal_enabled = true
		m.normal_texture = _canvas_normal()
		m.normal_scale = 1.0
	m.uv1_scale = Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Rope. Bright and slightly glossy: in the reference these are the strongest
## lines in the frame and the brightest surface in it, and the outgoing
## material (0.93 albedo at roughness 0.6) rendered at the mat's own value, so
## the ropes read as grey scaffolding. Value alone is not the fix -- a diffuse
## white at this exposure lands where the mat lands. Dropping roughness gives
## them a specular return the flat mat does not have, which is the mechanism
## that separates them. The tape wrap is generated here because the library has
## no helical wrap and a rope without one is a white pipe.
func _rope_material() -> StandardMaterial3D:
	var m := _resolve("ring_rope", _mat(Color(0.97, 0.97, 0.94), 0.36))
	m.albedo_color = Color(0.97, 0.97, 0.94)
	m.roughness = 0.36
	m.albedo_texture = _rope_tape()
	m.uv1_scale = Vector3.ONE
	return m


# =================================================================== canvas ===

func _build_canvas() -> void:
	var floor_mesh: MeshInstance3D = _ring.get_node_or_null("Floor/MeshInstance3D")
	if floor_mesh == null:
		push_error("RingBuilder: Ring/Floor/MeshInstance3D is missing -- "
			+ "capture_harness.gd keys the silhouette mask off that exact path.")
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Surface 0 is the mat's top face alone, with a full 0..1 UV over the 6m
	# square so the canvas texture and its centre mark land where they are
	# drawn. BoxMesh atlases its six faces into one UV square, which is why
	# the outgoing mat could not carry a mark at all.
	_quad(st,
		Vector3(-MAT_HALF, MAT_TOP_LOCAL, MAT_HALF),
		Vector3(MAT_HALF, MAT_TOP_LOCAL, MAT_HALF),
		Vector3(MAT_HALF, MAT_TOP_LOCAL, -MAT_HALF),
		Vector3(-MAT_HALF, MAT_TOP_LOCAL, -MAT_HALF),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	st.generate_tangents()
	var mesh := st.commit()

	# Surface 1: the canvas rolling over the edge onto the ring frame.
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var basis_dir: Vector3 = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][side]
		var tangent := Vector3(basis_dir.z, 0, -basis_dir.x)
		var a: Vector3 = basis_dir * MAT_HALF + tangent * MAT_HALF + Vector3(0, MAT_TOP_LOCAL, 0)
		var b: Vector3 = basis_dir * MAT_HALF - tangent * MAT_HALF + Vector3(0, MAT_TOP_LOCAL, 0)
		_quad(edge, a, b, b - Vector3(0, 0.2, 0), a - Vector3(0, 0.2, 0),
			Vector2(0, 0), Vector2(4, 0), Vector2(4, 1), Vector2(0, 1))
	edge.generate_tangents()
	edge.commit(mesh)

	floor_mesh.mesh = mesh
	floor_mesh.set_surface_override_material(0, _canvas_material())
	floor_mesh.set_surface_override_material(1, _resolve("ring_apron",
		_mat(Color(0.40, 0.52, 0.72), 0.85), {"tint": Color(0.40, 0.52, 0.72)}))


## The canvas texture: weave, panel seams, wear, a border, and an original
## centre mark. Multiplies into _canvas_material()'s albedo_color.
##
## The mark is drawn from primitives here and is this project's own: a ringed
## triple chevron over a bar. ARCHITECTURE.md's IP guardrail bars a real
## promotion's trade dress, and a logo is the single most trade-dress-shaped
## thing on a mat, so nothing about it is traced to any reference frame beyond
## "the reference mat carries a large centre mark". Its geometry is a COVERAGE
## DECISION.
static func _canvas() -> ImageTexture:
	if _canvas_texture != null:
		return _canvas_texture
	var noise := FastNoiseLite.new()
	noise.seed = CANVAS_SEED
	noise.frequency = 0.45
	var fine := FastNoiseLite.new()
	fine.seed = CANVAS_SEED + 7
	fine.frequency = 3.2

	var n := CANVAS_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 3)
	_canvas_height = PackedFloat32Array()
	_canvas_height.resize(n * n)
	var metres := 6.0 / float(n)
	for py: int in range(n):
		var z := (float(py) + 0.5) * metres - MAT_HALF
		for px: int in range(n):
			var x := (float(px) + 0.5) * metres - MAT_HALF
			var v := 1.0
			var col_border := 0

			# Weave. Two interleaved thread directions, near the resolution
			# floor on purpose -- at match distance this is grain, not pattern.
			v += 0.044 * float((px % 4) - 1.5) * 0.667 \
				+ 0.044 * float((py % 4) - 1.5) * 0.667
			# Wear: a low octave for the trodden centre, a higher one for scuff.
			v += 0.045 * noise.get_noise_2d(x * 4.0, z * 4.0)
			v += 0.026 * fine.get_noise_2d(x * 4.0, z * 4.0)
			v += 0.030 * fine.get_noise_2d(x * 19.0, z * 19.0)

			# Panel seams. A sewn seam is a dark valley with a raised lip.
			var seam := absf(fposmod(z + CANVAS_PANEL * 0.5, CANVAS_PANEL) - CANVAS_PANEL * 0.5)
			if seam < 0.012:
				v -= 0.14
			elif seam < 0.030:
				v += 0.035
				if fposmod(x, 0.05) < 0.022:   # the stitch itself
					v -= 0.07

			# Painted border inside the mat edge: a heavy line and a hairline,
			# which is what gives the mat a readable boundary from the wide
			# camera instead of ending wherever the canvas happens to stop.
			var edge_d := maxf(absf(x), absf(z))
			if edge_d > 2.66 and edge_d < 2.80:
				col_border = 1
			elif edge_d > 2.84 and edge_d < 2.88:
				col_border = 2

			var col := CANVAS_FIELD * v

			if col_border == 1:
				col = CANVAS_MARK * v          # the heavy painted boundary line
			elif col_border == 2:
				col = CANVAS_DISC_RIM * v      # and its hairline shadow

			# --- centre mark -------------------------------------------------
			var r := sqrt(x * x + z * z)
			if r < 1.72:
				if r > 1.60:
					col = CANVAS_MARK * v                     # outer ring
				elif r > 1.54:
					col = CANVAS_DISC_RIM * v                 # ring shadow
				else:
					col = CANVAS_DISC * v                     # seated disc
					var chev := z - 0.42 * absf(x)
					for offset: float in [-0.34, -0.02, 0.30]:
						if absf(chev - offset) < 0.085 and absf(x) < 1.34:
							col = CANVAS_MARK * v
					if absf(z - 0.72) < 0.06 and absf(x) < 1.05:
						col = CANVAS_MARK * v

			# Two secondary marks on the near and far thirds. Real mats carry
			# more than the centre logo, and from the wide camera these are
			# large-scale incident on the frame's biggest surface -- which is
			# the coarse-detail lever the ring actually owns. COVERAGE
			# DECISION: their placement and size trace to nothing measured.
			for mark_z: float in [-2.05, 2.05]:
				var mx := x
				var mz := (z - mark_z) * (1.0 if mark_z > 0.0 else -1.0)
				var mr := sqrt(mx * mx + mz * mz)
				if mr < 0.62:
					col = CANVAS_DISC * v
					var mchev := mz - 0.42 * absf(mx)
					for offset: float in [-0.16, 0.06]:
						if absf(mchev - offset) < 0.055 and absf(mx) < 0.50:
							col = CANVAS_MARK * v
				elif mr < 0.68:
					col = CANVAS_MARK * v

			_canvas_height[py * n + px] = v
			var i := (py * n + px) * 3
			data[i] = _byte(col.r)
			data[i + 1] = _byte(col.g)
			data[i + 2] = _byte(col.b)

	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_canvas_texture = ImageTexture.create_from_image(img)
	return _canvas_texture


## Rope tape. Diagonal stripes in a tiling square become a helical wrap once
## the tube's UV runs u around the circumference and v along the span, which is
## how a taped rope actually looks and is where the ropes' fine detail comes
## from at this distance.
static func _rope_tape() -> ImageTexture:
	if _rope_texture != null:
		return _rope_texture
	var n := 64
	var data := PackedByteArray()
	data.resize(n * n * 3)
	for py: int in range(n):
		for px: int in range(n):
			var band := fposmod(float(px + py), 16.0) / 16.0
			var v := 0.94 + 0.06 * cos(band * TAU)
			if band < 0.06:
				v -= 0.10                      # the seam where the tape laps
			var i := (py * n + px) * 3
			data[i] = _byte(v)
			data[i + 1] = _byte(v)
			data[i + 2] = _byte(v * 0.99)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_rope_texture = ImageTexture.create_from_image(img)
	return _rope_texture


## The turnbuckle pad's vinyl: quilt seams, stitching, grain and the mark.
##
## Every camera in the shotlist that is not looking straight down sees a
## corner, and ring_corner sees nothing else -- so an untextured slab here is
## the most-looked-at flat surface in the game after the mat. The palette works
## the same way the canvas's does and for the same arithmetic reason: the near
## white lives in albedo_color and the blue in the texture, because a texture
## cannot brighten past its albedo and a mark that cannot go brighter than its
## field is not a mark.
const PAD_FIELD := Color(0.13, 0.20, 0.64)
const PAD_STITCH := Color(0.07, 0.11, 0.40)
const PAD_MARK := Color(0.93, 0.94, 0.98)
const PAD_WHITE := Color(0.97, 0.98, 1.0)

static func _pad_vinyl() -> ImageTexture:
	if _pad_texture != null:
		return _pad_texture
	var n := 256
	var grain := FastNoiseLite.new()
	grain.seed = CANVAS_SEED + 31
	grain.frequency = 0.09
	var data := PackedByteArray()
	data.resize(n * n * 3)
	for py: int in range(n):
		var ty := (float(py) + 0.5) / float(n)
		for px: int in range(n):
			var tx := (float(px) + 0.5) / float(n)
			var v := 1.0 + 0.05 * grain.get_noise_2d(float(px), float(py))
			var col := PAD_FIELD

			# Quilting: the pad is panelled, and a panelled vinyl catches the
			# rig along every seam.
			var seam_u := absf(fposmod(tx + 0.125, 0.25) - 0.125)
			var seam_v := absf(fposmod(ty + 0.16, 0.32) - 0.16)
			if seam_u < 0.008 or seam_v < 0.008:
				col = PAD_STITCH
			elif seam_u < 0.018 or seam_v < 0.018:
				v += 0.10
			# The stitch itself, dashed along the seam.
			if (seam_u < 0.008 and fposmod(ty, 0.04) < 0.020) \
					or (seam_v < 0.008 and fposmod(tx, 0.04) < 0.020):
				col = PAD_MARK

			# The mark: three stacked bars of decreasing width, once per face.
			#
			# This was a chevron group, matching the canvas mark, and it is
			# deliberately not one any more. Stretched over a pad face three
			# times taller than it is wide, three converging chevrons resolve
			# into a single large angular letterform, and a large angular
			# letterform on a turnbuckle pad is the most recognisable piece of
			# trade dress in professional wrestling. ARCHITECTURE.md's IP
			# guardrail is about resemblance, not about intent, so the shape
			# that could be mistaken is the shape that has to go. Stacked bars
			# read as branding at ring_corner distance and resemble nobody's.
			var cx := (tx - 0.5) * 2.0
			var widths := [0.62, 0.46, 0.30]
			for bar: int in range(3):
				# Placed in the clear band between the mid and top straps. The
				# straps land at v = 0.15 / 0.46 / 0.77 (the three rope heights
				# mapped onto the pad's own height), and a mark drawn across
				# one of those is a mark behind a strap.
				if absf(ty - (0.60 + 0.048 * float(bar))) < 0.020 \
						and absf(cx) < widths[bar]:
					col = PAD_MARK

			var out := col * v
			var i := (py * n + px) * 3
			data[i] = _byte(out.r)
			data[i + 1] = _byte(out.g)
			data[i + 2] = _byte(out.b)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_pad_texture = ImageTexture.create_from_image(img)
	return _pad_texture


## A normal map derived from the canvas's own weave.
##
## This is the fine-detail lever the albedo alone cannot pull. An albedo weave
## is flattened by the light: at the wide camera's grazing angle the mat is lit
## almost uniformly, so a 4% albedo ripple survives as a 4% pixel ripple and
## then gets averaged away by the mip chain. A normal ripple is re-lit every
## frame -- the thread crowns face the ring rig and the valleys do not -- so it
## produces a much larger pixel difference from the same surface, and it is the
## same mechanism A2 leans on with normal_scale in the library keys.
##
## Derived by central difference from the same height field _canvas() drew the
## albedo from, so the two cannot disagree about where a thread is.
const CANVAS_RELIEF := 4.0

static func _canvas_normal() -> ImageTexture:
	if _canvas_normal_texture != null:
		return _canvas_normal_texture
	_canvas()  # populates _canvas_height
	var n := CANVAS_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 3)
	for py: int in range(n):
		for px: int in range(n):
			var left := _canvas_height[py * n + posmod(px - 1, n)]
			var right := _canvas_height[py * n + posmod(px + 1, n)]
			var up := _canvas_height[posmod(py - 1, n) * n + px]
			var down := _canvas_height[posmod(py + 1, n) * n + px]
			var normal := Vector3((left - right) * CANVAS_RELIEF,
				(up - down) * CANVAS_RELIEF, 1.0).normalized()
			var i := (py * n + px) * 3
			data[i] = _byte(normal.x * 0.5 + 0.5)
			data[i + 1] = _byte(normal.y * 0.5 + 0.5)
			data[i + 2] = _byte(normal.z * 0.5 + 0.5)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_canvas_normal_texture = ImageTexture.create_from_image(img)
	return _canvas_normal_texture


## The printed band that runs round the skirt. The reference's apron carries
## large repeated branding; ours carries the same original mark the canvas
## does, repeated, because that is what the skirt of a real ring is for. Drawn
## rather than imported for the same IP reason the canvas mark is.
static func _apron_print() -> ImageTexture:
	if _apron_texture != null:
		return _apron_texture
	var w := 512
	var h := 64
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for py: int in range(h):
		var ty := (float(py) + 0.5) / float(h)
		for px: int in range(w):
			var tx := fposmod(float(px) / float(w) * 6.0, 1.0)
			var col := Color(0.16, 0.19, 0.34)
			if ty < 0.10 or ty > 0.90:
				col = Color(0.42, 0.48, 0.66)          # piping top and bottom
			else:
				var cx := (tx - 0.5) * 2.4
				var cy := (ty - 0.5) * 2.0
				var chev := cy - 0.55 * absf(cx)
				for offset: float in [-0.30, 0.02, 0.34]:
					if absf(chev - offset) < 0.10 and absf(cx) < 0.62:
						col = Color(0.86, 0.89, 0.98)
			var i := (py * w + px) * 3
			data[i] = _byte(col.r)
			data[i + 1] = _byte(col.g)
			data[i + 2] = _byte(col.b)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_apron_texture = ImageTexture.create_from_image(img)
	return _apron_texture


static func _byte(f: float) -> int:
	return clampi(int(round(clampf(f, 0.0, 1.0) * 255.0)), 0, 255)


# ==================================================================== ropes ===

func _build_ropes() -> void:
	var holder := _replace("Ropes")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for height: float in ROPE_HEIGHTS:
		for side: int in range(4):
			var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
			var out := Vector3(0, 0, 1) if side < 2 else Vector3(1, 0, 0)
			var sign_out := 1.0 if side % 2 == 0 else -1.0
			var base: Vector3 = out * (ROPE_SPAN * sign_out) + Vector3(0, height, 0)
			_sweep_rope(st, base, along, height)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RopeMesh"
	mesh_instance.mesh = st.commit()
	mesh_instance.set_surface_override_material(0, _rope_material())
	holder.add_child(mesh_instance)


## One span, swept as a tube along a parabola. A catenary and a parabola differ
## by less than a millimetre over 6m at this sag, and the parabola is the one
## that can be written down.
func _sweep_rope(st: SurfaceTool, base: Vector3, along: Vector3, height: float) -> void:
	var half := POST_XZ + ROPE_OVERRUN
	var sag: float = ROPE_SAG[height]
	var up := Vector3(0, 1, 0)
	var side_dir := along.cross(up).normalized()
	var previous: Array = []
	for seg: int in range(ROPE_SEGMENTS + 1):
		var t := float(seg) / float(ROPE_SEGMENTS)
		var s := lerpf(-half, half, t)
		var drop := sag * 4.0 * t * (1.0 - t)
		var centre: Vector3 = base + along * s - up * drop
		var ring: Array = []
		for r: int in range(ROPE_RINGS + 1):
			var a := TAU * float(r) / float(ROPE_RINGS)
			var normal: Vector3 = (side_dir * cos(a) + up * sin(a)).normalized()
			ring.append([centre + normal * ROPE_RADIUS, normal,
				Vector2(float(r) / float(ROPE_RINGS), s / 0.11)])
		if seg > 0:
			for r: int in range(ROPE_RINGS):
				_tri(st, previous[r], previous[r + 1], ring[r + 1])
				_tri(st, previous[r], ring[r + 1], ring[r])
		previous = ring


# ============================================= turnbuckles, posts and caps ===

func _build_turnbuckles_and_posts() -> void:
	var holder := _replace("Posts")
	var pad := SurfaceTool.new(); pad.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strap := SurfaceTool.new(); strap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steel := SurfaceTool.new(); steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := SurfaceTool.new(); dark.begin(Mesh.PRIMITIVE_TRIANGLES)

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post := Vector3(POST_XZ * sx, 0.0, POST_XZ * sz)
			# The pad faces ring centre, so its local axes are the diagonal.
			var inward := Vector3(-sx, 0, -sz).normalized()
			var tangent := Vector3(inward.z, 0, -inward.x)

			_cylinder(dark, post + Vector3(0, POST_BOTTOM, 0), POST_TOP - POST_BOTTOM,
				POST_RADIUS, 12)
			_cylinder(steel, post + Vector3(0, POST_TOP, 0), CAP_HEIGHT, CAP_RADIUS, 14)
			# A collar where the pad's laces gather at the foot of the post.
			_cylinder(steel, post + Vector3(0, PAD_BOTTOM - 0.05, 0), 0.05,
				POST_RADIUS + 0.02, 12)

			_oriented_box(pad, post + Vector3(0, (PAD_BOTTOM + PAD_TOP) * 0.5, 0),
				tangent, inward, Vector3(PAD_WIDTH, PAD_TOP - PAD_BOTTOM, PAD_DEPTH))

			for height: float in ROPE_HEIGHTS:
				var centre: Vector3 = post + Vector3(0, height, 0)
				for offset: float in [-STRAP_GAP, STRAP_GAP]:
					_oriented_box(strap, centre + Vector3(0, offset, 0), tangent, inward,
						Vector3(PAD_WIDTH + 0.012, STRAP_HEIGHT, PAD_DEPTH + 0.012))
				# The buckle sits on the outward face, where the strap closes.
				_oriented_box(steel, centre - inward * (PAD_DEPTH * 0.5 + BUCKLE.z * 0.4),
					tangent, inward, BUCKLE)

	_emit(holder, "PostMesh", dark, _resolve("ring_post", _mat(Color(0.30, 0.31, 0.35), 0.38)))
	_emit(holder, "PostSteel", steel, _steel())
	var pad_material := _resolve("ring_turnbuckle_pad", _mat(PAD_WHITE, 0.58),
		{"tint": PAD_WHITE})
	# Overridden for the same reason the canvas's albedo is: the library key is
	# a flat tinted fabric and this pad carries a mark. Its normal and
	# roughness maps are kept.
	pad_material.albedo_color = PAD_WHITE
	pad_material.albedo_texture = _pad_vinyl()
	pad_material.uv1_scale = Vector3.ONE
	_emit(holder, "TurnbucklePads", pad, pad_material)
	_emit(holder, "TurnbuckleStraps", strap, _resolve("ring_turnbuckle_pad",
		_mat(Color(0.94, 0.94, 0.92), 0.42), {"tint": Color(0.94, 0.94, 0.92)}))


# ==================================================================== apron ===
## The skirt boxes stay in ring.tscn (they carry the CC0 fabric this file must
## not re-license). What is added is the structure a hanging skirt has and four
## flat boards do not: the padded rail it hangs from, a hem, and vertical folds.

func _build_apron_detail() -> void:
	var holder := _replace("ApronDetail")
	var rail := SurfaceTool.new(); rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fold := SurfaceTool.new(); fold.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
		var tangent := Vector3(out.z, 0, -out.x)
		var mid: Vector3 = out * APRON_OUT
		_oriented_box(rail, mid + Vector3(0, APRON_TOP + 0.04, 0), tangent, out,
			Vector3(6.62, 0.13, 0.17))
		_oriented_box(rail, mid + Vector3(0, APRON_BOTTOM + 0.03, 0), tangent, out,
			Vector3(6.58, 0.07, 0.13))
		for i: int in range(APRON_FOLDS):
			var t := (float(i) + 0.5) / float(APRON_FOLDS) - 0.5
			_oriented_box(fold, mid + tangent * (t * 6.3)
				+ Vector3(0, (APRON_TOP + APRON_BOTTOM) * 0.5, 0), tangent, out,
				Vector3(0.055, APRON_TOP - APRON_BOTTOM - 0.16, 0.075))
	var band := SurfaceTool.new(); band.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
		var tangent := Vector3(out.z, 0, -out.x)
		# Hung at the skirt's middle, NOT up under the mat edge where the wide
		# camera would see more of it. Measured, both ways: raised to -0.36 and
		# brightened, the band lit the one strip of frame that was still pure
		# black and took void_fraction from 0.023 to 0.002 -- outside
		# VISUAL_BAR.md's 0.010-0.066 band, which voids a round. A real arena
		# is dark under the ring apron; filling that in is not an improvement,
		# it is the measurement telling me I overlit ringside.
		_oriented_box(band, out * (APRON_OUT + 0.045) + Vector3(0, -0.50, 0),
			tangent, out, Vector3(6.30, 0.46, 0.03))
	# A lit steel frame rail along the mat's edge was built here and then taken
	# back out, and the reason is worth leaving behind. It bought coarse detail
	# 0.134 -> 0.138 and cost void_fraction 0.023 -> 0.014, because the only
	# pure-black pixels left in the wide frame are the strip under the ring and
	# a rail runs straight through them. VISUAL_BAR.md's floor is 0.010 and
	# lighting is raising exposure in parallel, which will spend the rest of
	# that headroom. Four thousandths of coarse detail is not worth being the
	# agent who put the wave through the floor.

	var band_material := _resolve("ring_apron", _mat(Color(0.90, 0.92, 1.0), 0.70),
		{"tint": Color(0.90, 0.92, 1.0)})
	band_material.albedo_color = Color(0.90, 0.92, 1.0)
	band_material.albedo_texture = _apron_print()
	band_material.uv1_scale = Vector3.ONE
	_emit(holder, "ApronBand", band, band_material)
	_emit(holder, "ApronRail", rail, _resolve("ring_steel", _mat(Color(0.30, 0.34, 0.48), 0.55),
		{"tint": Color(0.30, 0.34, 0.48)}))
	_emit(holder, "ApronFolds", fold, _resolve("ring_apron", _mat(Color(0.17, 0.20, 0.34), 0.85)))


# ============================================================== steel steps ===

func _build_steps() -> void:
	var holder := _replace("Steps")
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var tangent := Vector3(0, 0, 1)
		var rise := (STEP_TOP_Y - STEP_FLOOR_Y) / float(STEP_TREADS)
		for i: int in range(STEP_TREADS):
			var top := STEP_FLOOR_Y + rise * float(i + 1)
			var depth := STEP_RUN * float(STEP_TREADS - i)
			var centre: Vector3 = out * (APRON_OUT + 0.06 + depth * 0.5) \
				+ Vector3(0, (STEP_FLOOR_Y + top) * 0.5, 0) + tangent * 0.35
			_oriented_box(st, centre, tangent, out,
				Vector3(STEP_WIDTH, top - STEP_FLOOR_Y, depth))
	_emit(holder, "StepsMesh", st, _steel())


# ================================================================== helpers ===

## Creates a container for one group of generated meshes.
##
## The meshes hang under RingBuilder itself, not under Ring. That is not a
## style choice: Ring is mid-instantiation while this node's _ready runs, and
## add_child() on a node that is still setting up its own children fails
## outright -- which is how the first wired build produced an empty ring and a
## row of "Parent node is busy setting up children" errors. RingBuilder sits at
## Ring's own origin with no transform of its own, so the local space the
## constants above are written in is unchanged.
func _replace(container: String) -> Node3D:
	var existing := get_node_or_null(container)
	if existing:
		remove_child(existing)
		existing.queue_free()
	var node := Node3D.new()
	node.name = container
	add_child(node)
	return node


func _emit(holder: Node3D, node_name: String, st: SurfaceTool, material: Material) -> void:
	st.generate_normals()
	st.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.set_surface_override_material(0, material)
	holder.add_child(instance)


func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	for vertex: Array in [a, b, c]:
		st.set_normal(vertex[1])
		st.set_uv(vertex[2])
		st.add_vertex(vertex[0])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	var normal := (b - a).cross(d - a).normalized()
	# Godot's front faces wind CLOCKWISE. The first wired build emitted a-b-c
	# / a-c-d, which is counter-clockwise seen from the side the normal points
	# at, so every generated face was back-facing: the mat rendered as a black
	# hole and every box was seen from the inside.
	for pair: Array in [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]:
		st.set_normal(normal)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


## A box whose local X follows `tangent` and local Z follows `forward`, so a
## turnbuckle pad can face ring centre at 45 degrees without a transform node.
func _oriented_box(st: SurfaceTool, centre: Vector3, tangent: Vector3,
		forward: Vector3, size: Vector3) -> void:
	var x: Vector3 = tangent.normalized() * size.x * 0.5
	var y := Vector3(0, size.y * 0.5, 0)
	var z: Vector3 = forward.normalized() * size.z * 0.5
	var corner := func(i: int, j: int, k: int) -> Vector3:
		return centre + x * float(i) + y * float(j) + z * float(k)
	var faces := [
		[corner.call(-1, 1, 1), corner.call(1, 1, 1), corner.call(1, 1, -1), corner.call(-1, 1, -1)],
		[corner.call(-1, -1, -1), corner.call(1, -1, -1), corner.call(1, -1, 1), corner.call(-1, -1, 1)],
		[corner.call(-1, -1, 1), corner.call(1, -1, 1), corner.call(1, 1, 1), corner.call(-1, 1, 1)],
		[corner.call(1, -1, -1), corner.call(-1, -1, -1), corner.call(-1, 1, -1), corner.call(1, 1, -1)],
		[corner.call(1, -1, 1), corner.call(1, -1, -1), corner.call(1, 1, -1), corner.call(1, 1, 1)],
		[corner.call(-1, -1, -1), corner.call(-1, -1, 1), corner.call(-1, 1, 1), corner.call(-1, 1, -1)],
	]
	for face: Array in faces:
		_quad(st, face[0], face[1], face[2], face[3],
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))


func _cylinder(st: SurfaceTool, base: Vector3, height: float, radius: float,
		sides: int) -> void:
	var top := base + Vector3(0, height, 0)
	for i: int in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_quad(st, base + d0 * radius, base + d1 * radius,
			top + d1 * radius, top + d0 * radius,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		st.set_normal(Vector3.UP)
		for point: Vector3 in [top, top + d0 * radius, top + d1 * radius]:
			st.set_uv(Vector2(point.x, point.z))
			st.add_vertex(point)
