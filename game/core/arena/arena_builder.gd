extends Node3D
class_name ArenaBuilder
## Builds the hall around the ring: a raked seating bowl, its crowd, the
## entrance stage, the overhead truss, and the shell (walls, roof, floor).
##
## Why this is generated rather than authored in the .tscn, and why it is not
## a downloaded arena model, are both deliberate:
##
## - A twenty-row raked bowl with a few thousand seats is not hand-typeable as
##   transforms. Expressed as the dozen numbers below it is reviewable and
##   tunable; expressed as a .tscn it would be transform soup nobody can check.
## - No CC0 wrestling arena exists to download. The ones that do exist are
##   branded (extracted game assets or trademarked trade dress, both barred by
##   ARCHITECTURE.md's IP guardrail), and none is an arena *bowl* -- they are
##   all rings, which scenes/ring.tscn already has. See
##   assets/environment/CREDITS.md.
##
## Everything here is cosmetic. Nothing in this file creates a
## CollisionObject3D, joins a physics layer, or is read by gameplay: the ring's
## own colliders in ring.tscn remain the only bodies the match touches. The
## crowd's idle motion is a vertex shader, so it runs on the render thread and
## cannot reach MatchReferee.compute_end_state_hash(). ARCHITECTURE.md permits
## cosmetic motion on exactly that condition.
##
## Placement is seeded (CROWD_SEED), so the same build produces the same
## arena every run and captures stay comparable between rounds.

# --- The ring this hall is built around -------------------------------------
# Read, never written. ring.tscn's mat is 6m square with the ropes at 3.1m,
# and camera.md derives the 41-degree lens from that 3.1m figure -- so these
# are the one set of numbers here that may not be changed to suit the arena.
const RING_HALF_EXTENT := 3.3
## Arena floor level, matching ring.tscn's own ArenaFloor before it moved here.
## The mat sits ~1.1m above it, which is what gives the apron something to be.
const FLOOR_Y := -1.1

# --- Ringside ---------------------------------------------------------------
## Barricade line. Everything between the ring and this is open ringside floor.
const BARRICADE_RADIUS := 9.0
const BARRICADE_HEIGHT := 1.1

# --- Seating bowl -----------------------------------------------------------
## Row geometry. RUN is tread depth, RISE is step height; a real bowl rakes at
## roughly 27 degrees and 0.48/0.95 gives that. Not a reference measurement --
## gauntlet/refs/ measures nothing about seating rake -- so this is an
## engineering value and is not defended as "how it should look".
const ROW_RUN := 0.95
const ROW_RISE := 0.48
const LOWER_ROWS := 12
const UPPER_ROWS := 8
## Walkway between the two tiers.
const CONCOURSE_DEPTH := 2.6

# --- Entrance stage ---------------------------------------------------------
## The stage occupies the -Z wedge. The default match camera looks down -Z, so
## this is the half of the hall that actually lands in the money shot -- which
## is the half where filling the void is worth the polygons.
const STAGE_HALF_WIDTH := 6.0
const STAGE_DECK_Y := 0.35
const STAGE_BACK := -24.0
## The ramp runs from the stage lip to the barricade line, descending to floor.
const RAMP_HALF_WIDTH := 1.8

# --- Shell ------------------------------------------------------------------
const WALL_EXTENT := 32.0
const WALL_TOP := 17.0
const ROOF_Y := 14.0
const TRUSS_Y := 7.6

# --- Crowd ------------------------------------------------------------------
## Distance between seats along a row.
@export var seat_pitch: float = 0.62
## Fraction of seats that are actually occupied. A sold-out bowl reads as a
## solid block; leaving gaps is what makes it read as people.
@export var crowd_fill: float = 0.86
## Fixed so the arena is identical every run.
const CROWD_SEED := 20260902

## Crowd shirt palette. Deliberately desaturated and dark: the reference
## frames' crowd sits at relative luminance 0.014 (VISUAL_BAR.md), so a bright
## crowd would not be closer to the reference, it would be further from it.
## What the crowd is for here is *variance*, not brightness.
const CROWD_COLORS: Array[Color] = [
	Color(0.20, 0.21, 0.26),
	Color(0.28, 0.24, 0.24),
	Color(0.17, 0.20, 0.24),
	Color(0.31, 0.29, 0.27),
	Color(0.22, 0.26, 0.28),
	Color(0.26, 0.22, 0.29),
	Color(0.15, 0.16, 0.19),
	Color(0.33, 0.31, 0.33),
]


var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = CROWD_SEED
	_build_floor()
	_build_barricades()
	_build_bowl()
	_build_stage()
	_build_truss()
	_build_shell()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## Named materials come from core/materials/material_library.gd, which owns
## the full map set (albedo/normal/roughness/AO/metalness), the sRGB-vs-linear
## slotting, the PBR-correctness rules, and the texel density. This is the one
## line of adapter that keeps the hall's call sites reading as art direction.
##
## Every hall material is `house_lit` in the library, meaning it carries its
## albedo map as a multiplied emission map -- emission is unlit, so without
## that the maps below would be invisible no matter how good they are. The
## multiply darkens the mean, which is why each call site wraps `_house_lit()`
## in `MaterialLibrary.house_compensate()`: that divides the map's own mean
## back out of the emission energy, so the house *level* this file solves for
## is preserved and only its *variance* changes.
func _textured(key: String) -> StandardMaterial3D:
	return MaterialLibrary.resolve(key)


## House light, carried by the materials rather than by lights aimed at the
## stands.
##
## Nothing out here is within reach of the four ring spotlights (spot_range 10,
## and the bowl starts at 9m), and adding real fill lights out in the hall
## would spill onto the mat -- ring lighting is a different slice's variable
## and this must not touch it. So the hall lights itself.
##
## The level is not a taste call. VISUAL_BAR.md measures the reference
## footage's crowd at relative luminance 0.014, and measure_frame.py counts a
## pixel as void below 0.0025 -- so a real arena's stands sit about five times
## above the void floor, dim but genuinely lit, never black. The first pass
## here ran the hall at roughly 0.03 sRGB and pushed void_fraction the wrong
## way (0.125 -> 0.265 across the beat frames): more geometry than before, but
## most of it too dark to count as anything.
##
## HOUSE_TARGET is that measured 0.014, with headroom. The extra is not
## padding for its own sake: at exactly 0.0025 a surface *dithers* across the
## threshold rather than clearing it, which the first fix attempt showed as a
## speckled void mask over the stage backdrop. Sitting a comfortable margin
## above the floor is what makes the hall read as lit rather than as noise.
const HOUSE_TARGET := 0.020

## What the Environment's ambient is assumed to return off a diffuse surface,
## as a fraction of its linear albedo.
##
## Deliberately conservative. Ambient measured far lower on vertical faces than
## on the treads facing up, so crediting it fully left the bowl's risers below
## the void floor while its treads sat on target -- the same material reading
## two ways depending on which way a face pointed. Under-crediting ambient
## makes emission carry the house level, which is orientation-independent, and
## is why the hall now lights evenly.
const AMBIENT_RETURN := 0.05

## `reach` scales the target for surfaces that should sit under or over the
## house level -- the tunnel mouth is meant to read as a recess, the video
## wall as the brightest thing out there.
##
## The arithmetic is done in LINEAR light, which is the correction that made
## this work. Emission resolves as srgb_to_linear(albedo) * energy, so
## compensating with the *sRGB* luminance -- as the first version did -- leaves
## dark albedos far short: at albedo 0.12 the stage backdrop rendered at 0.0026
## linear against a 0.014 target while the bowl's 0.30 albedo landed on 0.017.
## Same formula, six-fold different result, purely from the gamma curve.
func _house_lit(mat: StandardMaterial3D, reach: float = 1.0) -> StandardMaterial3D:
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	var albedo_linear := maxf(mat.albedo_color.srgb_to_linear().get_luminance(),
			0.0001)
	var wanted := HOUSE_TARGET * reach
	mat.emission_energy_multiplier = maxf(
			wanted / albedo_linear - AMBIENT_RETURN, 0.0)
	return mat


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

## One axis-aligned box, with UVs taken from in-plane world coordinates so
## texel density stays constant no matter how big the box is. Boxes are solid
## and allowed to abut; interior faces are never seen.
static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var origin := center + normal * (normal.abs() * h).length()
		var eu := u * (u.abs() * h).length()
		var ev := v * (v.abs() * h).length()
		var corners := [
			origin - eu - ev, origin + eu - ev,
			origin + eu + ev, origin - eu + ev,
		]
		var uvs: Array[Vector2] = []
		for c: Vector3 in corners:
			uvs.append(Vector2((c * u.abs()).length() * signf(c.dot(u)),
					(c * v.abs()).length() * signf(c.dot(v))))
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			for i: int in tri:
				st.set_normal(normal)
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])


static func _mesh_instance(name: String, st: SurfaceTool,
		mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = st.commit()
	node.material_override = mat
	# The hall is a backdrop. Casting shadows from thousands of seats onto
	# nothing would cost fill rate no capture can spend.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _new_surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# ---------------------------------------------------------------------------
# Floor, barricades
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	var st := _new_surface()
	_add_box(st, Vector3(0.0, FLOOR_Y - 0.1, 0.0),
			Vector3(WALL_EXTENT * 2.0, 0.2, WALL_EXTENT * 2.0))
	add_child(_mesh_instance("Floor", st,
			MaterialLibrary.house_compensate(_house_lit(_textured("arena_floor"), 0.7))))


func _build_barricades() -> void:
	var st := _new_surface()
	var y := FLOOR_Y + BARRICADE_HEIGHT * 0.5
	var span := BARRICADE_RADIUS * 2.0
	for sign: float in [1.0, -1.0]:
		_add_box(st, Vector3(0.0, y, BARRICADE_RADIUS * sign),
				Vector3(span, BARRICADE_HEIGHT, 0.16))
		_add_box(st, Vector3(BARRICADE_RADIUS * sign, y, 0.0),
				Vector3(0.16, BARRICADE_HEIGHT, span))
	add_child(_mesh_instance("Barricades", st,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_barricade"), 0.8))))


# ---------------------------------------------------------------------------
# Seating bowl
# ---------------------------------------------------------------------------

## Each row is a solid block spanning from the bowl floor up to its own tread
## height, so the stack reads as a staircase with no gaps to fall through and
## no hidden faces to z-fight. The -Z side is split around the stage opening.
func _build_bowl() -> void:
	var steps := _new_surface()
	var seats: Array[Transform3D] = []
	var colors: Array[Color] = []

	var inner := BARRICADE_RADIUS
	var tread_y := FLOOR_Y
	for tier: int in [0, 1]:
		var rows: int = LOWER_ROWS if tier == 0 else UPPER_ROWS
		if tier == 1:
			inner += CONCOURSE_DEPTH
			_add_concourse(steps, inner - CONCOURSE_DEPTH, inner, tread_y)
		for r: int in rows:
			var outer := inner + ROW_RUN
			tread_y += ROW_RISE
			_add_row(steps, inner, outer, tread_y)
			_seat_row(inner, outer, tread_y, seats, colors)
			inner = outer

	add_child(_mesh_instance("SeatingBowl", steps, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_bowl")))))
	add_child(_build_crowd(seats, colors))


## Cut around the stage exactly as the seating rows are. Built uncut, the
## concourse closes the gap the rows leave and walls the entrance off -- a
## false-colour pass showed it as a solid block filling the centre of frame
## behind the ring, which is what was reading as void there.
func _add_concourse(st: SurfaceTool, inner: float, outer: float,
		y: float) -> void:
	_ring_band(st, inner, outer, FLOOR_Y, y, true)


func _add_row(st: SurfaceTool, inner: float, outer: float, y: float) -> void:
	_ring_band(st, inner, outer, FLOOR_Y, y, true)


## A square annulus between `inner` and `outer`, solid from `base_y` to
## `top_y`. Split around the stage on -Z when `cut_stage` is set.
func _ring_band(st: SurfaceTool, inner: float, outer: float, base_y: float,
		top_y: float, cut_stage: bool) -> void:
	var height := top_y - base_y
	if height <= 0.0:
		return
	var mid_y := (base_y + top_y) * 0.5
	var depth := outer - inner
	var mid_r := (inner + outer) * 0.5

	# +Z bank, full width.
	_add_box(st, Vector3(0.0, mid_y, mid_r),
			Vector3(outer * 2.0, height, depth))
	# -Z bank, split around the entrance stage.
	if cut_stage:
		var wing := (outer - STAGE_HALF_WIDTH) * 0.5
		if wing > 0.0:
			for sign: float in [1.0, -1.0]:
				_add_box(st,
						Vector3(sign * (STAGE_HALF_WIDTH + wing), mid_y, -mid_r),
						Vector3(wing * 2.0, height, depth))
	else:
		_add_box(st, Vector3(0.0, mid_y, -mid_r),
				Vector3(outer * 2.0, height, depth))
	# +X and -X banks, spanning only the gap the Z banks leave.
	for sign: float in [1.0, -1.0]:
		_add_box(st, Vector3(sign * mid_r, mid_y, 0.0),
				Vector3(depth, height, inner * 2.0))


## Seats along one row's tread, on whichever banks that row actually has.
func _seat_row(inner: float, outer: float, y: float,
		out_seats: Array[Transform3D], out_colors: Array[Color]) -> void:
	var seat_r := inner + (outer - inner) * 0.45
	# +Z bank faces -Z, and so on: every spectator looks at the ring.
	_seat_run(Vector3(-outer, y, seat_r), Vector3(outer, y, seat_r), PI,
			out_seats, out_colors)
	_seat_run(Vector3(-inner, y, -seat_r), Vector3(inner, y, -seat_r), 0.0,
			out_seats, out_colors, STAGE_HALF_WIDTH)
	_seat_run(Vector3(seat_r, y, -inner), Vector3(seat_r, y, inner), -PI * 0.5,
			out_seats, out_colors)
	_seat_run(Vector3(-seat_r, y, -inner), Vector3(-seat_r, y, inner), PI * 0.5,
			out_seats, out_colors)


func _seat_run(from: Vector3, to: Vector3, facing: float,
		out_seats: Array[Transform3D], out_colors: Array[Color],
		skip_abs_x: float = 0.0) -> void:
	var span := from.distance_to(to)
	var count := int(span / seat_pitch)
	if count <= 0:
		return
	for i: int in count:
		var t := (float(i) + 0.5) / float(count)
		var at := from.lerp(to, t)
		if skip_abs_x > 0.0 and absf(at.x) < skip_abs_x:
			continue
		if _rng.randf() > crowd_fill:
			continue
		var jitter := Vector3(_rng.randf_range(-0.06, 0.06), 0.0,
				_rng.randf_range(-0.06, 0.06))
		var basis := Basis(Vector3.UP, facing + _rng.randf_range(-0.25, 0.25))
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.9, 1.08))
		out_seats.append(Transform3D(basis, at + jitter))
		out_colors.append(CROWD_COLORS[_rng.randi() % CROWD_COLORS.size()])


# ---------------------------------------------------------------------------
# Crowd
# ---------------------------------------------------------------------------

## One MultiMesh for the whole bowl: a few thousand seated impostors in one
## draw call. They are impostors, not characters -- a torso and a head, no
## faces, no limbs. At bowl distance under the match lens what a crowd reads
## as is a broken-up silhouette with colour variance, and that is all this is
## claiming to be.
func _build_crowd(seats: Array[Transform3D],
		colors: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _spectator_mesh()
	mm.instance_count = seats.size()
	for i: int in seats.size():
		mm.set_instance_transform(i, seats[i])
		mm.set_instance_color(i, colors[i])

	var node := MultiMeshInstance3D.new()
	node.name = "Crowd"
	node.multimesh = mm
	node.material_override = _crowd_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _spectator_mesh() -> ArrayMesh:
	var st := _new_surface()
	_add_box(st, Vector3(0.0, 0.34, 0.0), Vector3(0.42, 0.58, 0.30))
	_add_box(st, Vector3(0.0, 0.74, 0.0), Vector3(0.21, 0.23, 0.21))
	return st.commit()


## The idle bob. This is a vertex shader on purpose: it runs on the render
## thread, reads only TIME and INSTANCE_ID, and writes nothing back, so it
## cannot feed into gameplay state or change a replay's end-state hash --
## which is the condition ARCHITECTURE.md puts on cosmetic motion.
func _crowd_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled;

uniform float bob_amplitude = 0.045;
uniform float bob_speed = 1.6;
uniform float house_light = 0.55;

varying vec3 seat_color;

void vertex() {
	seat_color = COLOR.rgb;
	// Golden-ratio phase spread: adjacent seats never bob together, and the
	// pattern never repeats along a row.
	float phase = fract(float(INSTANCE_ID) * 0.6180339887) * 6.2831853;
	VERTEX.y += (sin(TIME * bob_speed + phase) * 0.5 + 0.5) * bob_amplitude;
}

void fragment() {
	ALBEDO = seat_color;
	EMISSION = seat_color * house_light;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


# ---------------------------------------------------------------------------
# Entrance stage
# ---------------------------------------------------------------------------

## Deck, ramp to the ring, tunnel mouth, and a blank screen. The screen is
## deliberately blank: a logo there would be branding, and ARCHITECTURE.md
## scopes branding to original art this project does not have yet.
func _build_stage() -> void:
	var deck := _new_surface()
	var stage_front := -BARRICADE_RADIUS
	var deck_depth := stage_front - STAGE_BACK
	_add_box(deck, Vector3(0.0, (FLOOR_Y + STAGE_DECK_Y) * 0.5,
			(stage_front + STAGE_BACK) * 0.5),
			Vector3(STAGE_HALF_WIDTH * 2.0, STAGE_DECK_Y - FLOOR_Y, deck_depth))
	# Ramp: a short stack of steps rather than a wedge, because _add_box only
	# makes axis-aligned boxes and a visible staircase is honest grey-box.
	var steps := 6
	for i: int in steps:
		var t := float(i) / float(steps)
		var y := lerpf(STAGE_DECK_Y, FLOOR_Y, t)
		var z0 := lerpf(stage_front, -RING_HALF_EXTENT - 1.0, t)
		var z1 := lerpf(stage_front, -RING_HALF_EXTENT - 1.0,
				float(i + 1) / float(steps))
		_add_box(deck, Vector3(0.0, (FLOOR_Y + y) * 0.5, (z0 + z1) * 0.5),
				Vector3(RAMP_HALF_WIDTH * 2.0, y - FLOOR_Y, absf(z1 - z0)))
	add_child(_mesh_instance("EntranceStage", deck, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_stage_deck"), 1.1))))

	# Backdrop behind the stage, at house level. Without it the tunnel is a
	# hole onto the Environment's background colour -- which measure_frame.py
	# scores as void, and which measured as a quarter of the frame's middle
	# band on the first capture. The tunnel has to be a recess in something,
	# not an opening onto nothing.
	var backdrop := _new_surface()
	_add_box(backdrop, Vector3(0.0, (FLOOR_Y + WALL_TOP) * 0.5, STAGE_BACK - 0.4),
			Vector3(STAGE_HALF_WIDTH * 2.4, WALL_TOP - FLOOR_Y, 0.4))
	add_child(_mesh_instance("StageBackdrop", backdrop, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_stage_backdrop"), 0.8))))

	var portal := _new_surface()
	# Tunnel mouth: a recessed frame standing proud of the backdrop, so the
	# entrance reads as a doorway. Deliberately below house level -- a tunnel
	# should be the darkest thing on the stage -- but not black.
	for sign: float in [1.0, -1.0]:
		_add_box(portal, Vector3(sign * 4.4, STAGE_DECK_Y + 2.4, STAGE_BACK + 0.6),
				Vector3(3.2, 4.8, 1.2))
	_add_box(portal, Vector3(0.0, STAGE_DECK_Y + 5.2, STAGE_BACK + 0.6),
			Vector3(11.9, 0.8, 1.2))
	add_child(_mesh_instance("TunnelMouth", portal,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_tunnel"), 0.6))))

	var screen := _new_surface()
	_add_box(screen, Vector3(0.0, STAGE_DECK_Y + 8.4, STAGE_BACK + 0.9),
			Vector3(14.0, 5.4, 0.4))
	# Bright enough to read as a video wall, dark enough not to be the subject.
	# The albedo is deliberately not near-black: _house_lit divides the target
	# by the linear albedo, so a very dark panel asks for an absurd emission
	# energy (this was 7.6 before, and blew the screen out to flat pale blue).
	# metallic was 0.1, which is not a material -- a glass-fronted LED wall is
	# a dielectric, so the library's entry is 0.0 with specular 0.5.
	var screen_mat := MaterialLibrary.resolve("arena_screen")
	add_child(_mesh_instance("StageScreen", screen,
			_house_lit(screen_mat, 2.4)))


# ---------------------------------------------------------------------------
# Truss and shell
# ---------------------------------------------------------------------------

## A lighting grid above the ring. The roof alone left the camera's upper
## third a single flat emissive plane; this is what puts structure in it.
## It sits above the four SpotLight3Ds in match.tscn (y 5.5, range 10) so it
## neither occludes them nor changes how the mat is lit.
func _build_truss() -> void:
	var st := _new_surface()
	var reach := 11.0
	for offset: float in [-7.5, -2.5, 2.5, 7.5]:
		_add_box(st, Vector3(0.0, TRUSS_Y, offset),
				Vector3(reach * 2.0, 0.24, 0.24))
		_add_box(st, Vector3(offset, TRUSS_Y, 0.0),
				Vector3(0.24, 0.24, reach * 2.0))
	# Chords, so the grid reads as truss rather than as bare pipe.
	for offset: float in [-7.5, -2.5, 2.5, 7.5]:
		_add_box(st, Vector3(0.0, TRUSS_Y + 0.55, offset),
				Vector3(reach * 2.0, 0.14, 0.14))
		_add_box(st, Vector3(offset, TRUSS_Y + 0.55, 0.0),
				Vector3(0.14, 0.14, reach * 2.0))
	# Drops to the roof, so it hangs from something.
	for x: float in [-7.5, 7.5]:
		for z: float in [-7.5, 7.5]:
			_add_box(st, Vector3(x, (TRUSS_Y + ROOF_Y) * 0.5, z),
					Vector3(0.16, ROOF_Y - TRUSS_Y, 0.16))
	add_child(_mesh_instance("Truss", st, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_truss"), 0.9))))


func _build_shell() -> void:
	var st := _new_surface()
	var span := WALL_EXTENT * 2.0
	var mid_y := (FLOOR_Y + WALL_TOP) * 0.5
	var height := WALL_TOP - FLOOR_Y
	for sign: float in [1.0, -1.0]:
		_add_box(st, Vector3(0.0, mid_y, WALL_EXTENT * sign),
				Vector3(span, height, 0.4))
		_add_box(st, Vector3(WALL_EXTENT * sign, mid_y, 0.0),
				Vector3(0.4, height, span))
	_add_box(st, Vector3(0.0, ROOF_Y, 0.0), Vector3(span, 0.4, span))
	add_child(_mesh_instance("Shell", st, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_shell"), 0.85))))
