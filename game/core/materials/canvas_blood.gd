class_name CanvasBlood
extends Node
## The blood a match leaves on the ring canvas (the owner's blood round):
## drips under a bleeding man, spatter thrown off him by a shot, a pool where
## he lies and the smear where he is dragged or crawls through it.
##
## One stain map over the whole mat (SIZE texels across its 6 m, 6 mm a
## texel), painted on the CPU and drawn by canvas_blood.gdshader as the
## canvas material's next pass. That is the cap: however much a match
## bleeds, it is one texture and one pass, never a growing pile of decals --
## and decals do not exist on the web build's renderer at all.
##
## PRESENTATION ONLY: nothing reads it back. Its own RandomNumberGenerator,
## fixed seed, so the same match stains the same way.

const SHADER := preload("res://core/materials/canvas_blood.gdshader")
const GROUP := &"canvas_blood"
const SIZE := 1024
## Seconds of match one turn of the green (time) channel spans.
const TIME_SPAN := 1200.0
## Seconds for fresh blood on the canvas to dry dark.
const DRY_SECONDS := 180.0
## The most often the map is sent to the GPU.
const UPLOAD_EVERY := 0.2

var mesh: MeshInstance3D
var canvas_material: BaseMaterial3D
var material: ShaderMaterial
var image: Image
var texture: ImageTexture
var clock := 0.0
var _dirty := false
var _since := 0.0
var _rng := RandomNumberGenerator.new()


## Hangs a CanvasBlood on the ring's floor mesh, whose surface 0 is the mat.
static func attach(floor_mesh: MeshInstance3D) -> CanvasBlood:
	var c := CanvasBlood.new()
	c.name = "CanvasBlood"
	c.mesh = floor_mesh
	c.canvas_material = floor_mesh.get_surface_override_material(0) as BaseMaterial3D
	c._rng.seed = 7
	floor_mesh.add_child(c)
	c.add_to_group(GROUP)
	return c


static func of(tree: SceneTree) -> CanvasBlood:
	return tree.get_first_node_in_group(GROUP) as CanvasBlood if tree else null


func _process(delta: float) -> void:
	clock += delta
	if material:
		material.set_shader_parameter("now", clock)
	_since += delta
	if _dirty and _since >= UPLOAD_EVERY:
		flush()


## Sends what has been painted to the GPU now.
func flush() -> void:
	_since = 0.0
	if not _dirty or image == null:
		return
	_dirty = false
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		material.set_shader_parameter("stains", texture)
	else:
		texture.update(image)


## The map and the pass are made on the first drop: a match nobody bleeds
## in costs nothing.
func _ensure() -> bool:
	if image:
		return true
	if canvas_material == null:
		return false
	image = Image.create(SIZE, SIZE, false, Image.FORMAT_RG8)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("time_span", TIME_SPAN)
	material.set_shader_parameter("dry", DRY_SECONDS)
	material.render_priority = 1
	canvas_material.next_pass = material
	return true


## The texel under world point `p`, or (-1, -1) off the mat.
func texel(p: Vector3) -> Vector2:
	var l := mesh.to_local(p) if mesh else p
	var h := RingBuilder.MAT_HALF
	if absf(l.x) > h or absf(l.z) > h:
		return Vector2(-1, -1)
	# the mat's UV mapping (RingBuilder._build_canvas): u along +Z, v toward -X
	return Vector2((l.z + h) / (2.0 * h), (h - l.x) / (2.0 * h)) * SIZE


func on_mat(p: Vector3) -> bool:
	return texel(p).x >= 0.0


## Adds `amount` of blood in a round-ish spot `radius` metres across at `p`.
## `rough` 0..1 breaks the edge up. Returns false off the mat.
func stamp(p: Vector3, radius: float, amount: float, rough := 0.35) -> bool:
	var c := texel(p)
	if c.x < 0.0 or not _ensure():
		return false
	var r := maxf(radius / (2.0 * RingBuilder.MAT_HALF) * SIZE, 0.6)
	# a lumpy outline: four lobes at random phases, so no two pools match
	var lobes := []
	for i in 4:
		lobes.append([_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, rough), i + 2])
	var t := clampf(clock / TIME_SPAN, 0.0, 1.0)
	var reach := int(ceil(r * (1.0 + rough))) + 1
	for y in range(maxi(0, int(c.y) - reach), mini(SIZE, int(c.y) + reach + 1)):
		for x in range(maxi(0, int(c.x) - reach), mini(SIZE, int(c.x) + reach + 1)):
			var d := Vector2(x + 0.5, y + 0.5) - c
			var a := d.angle()
			var edge := r
			for l: Array in lobes:
				edge *= 1.0 + float(l[1]) * 0.5 * sin(a * float(l[2]) + float(l[0]))
			var k := 1.0 - smoothstep(edge * 0.8, edge, d.length())
			if k <= 0.0:
				continue
			var px := image.get_pixel(x, y)
			px.r = minf(1.0, px.r + amount * k)
			px.g = t
			image.set_pixel(x, y, px)
	_dirty = true
	return true


## A drip landing: a drop and, from any height, a few tiny satellites.
func drip(p: Vector3, size := 1.0) -> bool:
	if not stamp(p, 0.007 * size, 0.7, 0.25):
		return false
	for i in _rng.randi_range(0, 2):
		var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.025 * size
		stamp(p + off, 0.0035 * size, 0.6, 0.1)
	return true


## Blood thrown off a man by a shot: specks flung along `dir` (flat), the
## nearest biggest, and a streak or two where a run of it hit at a skim.
func spatter(p: Vector3, dir: Vector3, strength := 1.0) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	var n := int(6 + 14 * clampf(strength, 0.0, 1.5))
	for i in n:
		var along := _rng.randf_range(0.08, 0.9) * (0.6 + 0.4 * strength)
		var spread := _rng.randf_range(-0.35, 0.35) * along
		var q := p + dir * along + side * spread
		stamp(q, lerpf(0.009, 0.003, along) * _rng.randf_range(0.6, 1.3), 0.75, 0.2)
	for i in int(1 + strength):
		var from := p + dir * _rng.randf_range(0.1, 0.3) + side * _rng.randf_range(-0.12, 0.12)
		smear(from, from + dir * _rng.randf_range(0.12, 0.3), 0.006, 0.5)


## A drag of blood from `a` to `b`, `width` metres wide: a few streaks side
## by side, as a body dragged through a pool leaves them, each running out
## at its own length.
func smear(a: Vector3, b: Vector3, width: float, amount := 0.35) -> void:
	var dir := b - a
	dir.y = 0.0
	var side := dir.normalized().cross(Vector3.UP) if dir.length() > 0.001 else Vector3.RIGHT
	# the band of it first, thin and thinning out (the 19 Oct review: a drag
	# was a fan of separate stripes; a body pulled through blood paints a
	# broad film with darker streaks combed into it)
	var band_steps := maxi(2, int(a.distance_to(b) / maxf(width * 0.25, 0.004)))
	for i in band_steps + 1:
		var k := float(i) / band_steps
		stamp(a.lerp(b, k) + side * sin(k * 3.0) * width * 0.15, width * 0.55 * (1.0 - 0.35 * k),
				amount * 0.16 * (1.0 - 0.6 * k), 0.3)
	var streaks := maxi(1, int(width / 0.025))
	for j in streaks:
		var across := (float(j) / maxf(streaks - 1, 1) - 0.5) * width
		var reach := _rng.randf_range(0.55, 1.0)
		var w := width / streaks * _rng.randf_range(0.6, 1.1)
		var end := a.lerp(b, reach) + side * across * 0.8
		var start := a + side * across
		var steps := maxi(2, int(start.distance_to(end) / maxf(w * 0.22, 0.002)))
		var wander := _rng.randf_range(0.0, TAU)
		for i in steps + 1:
			var k := float(i) / steps
			var drift := side * sin(k * 5.0 + wander) * w * 0.4
			stamp(start.lerp(end, k) + drift, w * (1.0 - 0.5 * k),
					amount * (1.0 - 0.7 * k) * 0.3, 0.1)


## How much blood is on the mat (texels with any), 0..1 of its area.
func coverage() -> float:
	if image == null:
		return 0.0
	var n := 0
	for y in range(0, SIZE, 4):
		for x in range(0, SIZE, 4):
			if image.get_pixel(x, y).r > 0.1:
				n += 1
	return float(n) / float((SIZE / 4) * (SIZE / 4))
