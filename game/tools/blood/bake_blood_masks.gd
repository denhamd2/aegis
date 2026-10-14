extends Node
## Bakes each wrestler's blood "reveal map" (Blood; the owner's blood round).
##
##   godot --headless --path game tools/blood/bake_blood_masks.tscn
##
## A wrestler bleeds a little and then more: a cut at the hairline, rivulets
## running down the forehead and over the brows, the face covered, then
## streaks down the neck and the chest -- a crimson mask by the end of a bloody
## match. That progression is one texture per skin surface, in that surface's
## own UV space: each texel holds the bleed level (0-1) at which blood first
## shows there, red channel the head wound, green the back (tacks, nails,
## barbed wire). The shader (blood_overlay.gdshader) shows blood wherever the
## wrestler's bleed has passed the texel's value. Painting it in UV space, not
## projecting decals, is what keeps the blood ON him: a projected decal slides
## across a skinned body as it moves.
##
## The field is computed from where each vertex sits on the body at rest --
## the head bone, the chest, the feet for which way is forward -- so one
## definition fits every model. Deterministic: same models, same PNGs.

const OUT := "res://assets/characters/blood/"
const SIZE := 512
const MODELS := ["res://scenes/roman_model.tscn", "res://scenes/cody_model.tscn",
		"res://scenes/kenny_model.tscn"]
## Never: a texel at this value never bleeds.
const NEVER := 1.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for path: String in MODELS:
		var model := (load(path) as PackedScene).instantiate() as Node3D
		add_child(model)
		await get_tree().process_frame
		_bake_model(model, path.get_file().get_basename())
		model.queue_free()
		await get_tree().process_frame
	print("BLOOD MASKS DONE")
	get_tree().quit()


static func key_for(model_name: String, mesh: MeshInstance3D, surface: int) -> String:
	return "%s_%s_%d" % [model_name, String(mesh.name).to_snake_case(), surface]


func _bake_model(model: Node3D, model_name: String) -> void:
	var skin: Array = model.get_meta("skin_materials", [])
	# the skeleton with the whole body on it (Roman's model also carries a
	# 471-bone face rig, with a head and no feet)
	var sk: Skeleton3D = null
	var frame := {}
	for node in model.find_children("", "Skeleton3D", true, false):
		frame = body_frame(node as Skeleton3D)
		if not frame.is_empty():
			sk = node
			break
	if sk == null or skin.is_empty():
		push_warning("%s: no body skeleton or no skin_materials" % model_name)
		return
	_place_wound(model, sk, skin, frame)
	print("  %s: crown %.3f, wound %s" % [model_name, frame["crown"], frame["wound"]])
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_sk := sk.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			if not skin.has(mi.get_surface_override_material(surface)):
				continue
			var img := _bake_surface(mi.mesh, surface, to_sk, frame)
			var key := key_for(model_name, mi, surface)
			img.save_png(OUT + key + ".png")
			print("  %s" % key)


## Puts the head wound ON his skin, at the hairline: CROWN_DROP below the
## top of his scalp, on the front of the forehead. Measured off the mesh, not
## the head bone, because the rigs put that bone anywhere from the neck
## (Cody's and Kenny's, 1.57 m) to the jaw (Roman's) -- off the bone, Cody's
## cut opened at the bridge of his nose.
const CROWN_DROP := 0.075
const FACE_DEPTH := 0.085


static func _place_wound(model: Node3D, sk: Skeleton3D, skin: Array, f: Dictionary) -> void:
	var up: Vector3 = f["up"]
	var fwd: Vector3 = f["fwd"]
	var right: Vector3 = f["right"]
	var head: Vector3 = f["head"]
	var pts := PackedVector3Array()
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_sk := sk.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			if not skin.has(mi.get_surface_override_material(surface)):
				continue
			for v: Vector3 in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p := to_sk * v
				var flat := p - head
				flat -= up * flat.dot(up)
				if flat.length() < 0.13 and (p - head).dot(up) > -0.05:
					pts.append(p)
	var crown := -INF
	for p in pts:
		crown = maxf(crown, p.dot(up))
	var line := crown - CROWN_DROP
	var front := -INF
	for p in pts:
		if absf(p.dot(up) - line) < 0.015 and absf((p - head).dot(right)) < 0.025:
			front = maxf(front, (p - head).dot(fwd))
	if crown == -INF or front == -INF:
		return
	f["crown"] = crown
	f["wound"] = head + up * (line - head.dot(up)) + fwd * (front - 0.004)


## The body's frame at rest, skeleton space: up, forward (the way the feet
## point), right, and the points the wounds are measured from.
static func body_frame(sk: Skeleton3D) -> Dictionary:
	var head := _bone(sk, ["head", "Head", "J_Head", "mixamorig:Head", "CC_Base_Head"])
	var chest := _bone(sk, ["spine_03", "Spine2", "J_Spine2", "mixamorig:Spine2", "spine.003", "CC_Base_Spine02"])
	var foot := _bone(sk, ["foot_r", "RightFoot", "J_Foot_R", "mixamorig:RightFoot", "CC_Base_R_Foot"])
	var ball := _bone(sk, ["ball_r", "RightToeBase", "J_Toe_R", "mixamorig:RightToeBase", "CC_Base_R_ToeBase"])
	if head < 0 or chest < 0 or foot < 0 or ball < 0:
		return {}
	var at := func(i: int) -> Vector3: return sk.get_bone_global_rest(i).origin
	var up := Vector3.UP
	var fwd: Vector3 = (at.call(ball) - at.call(foot))
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(up).normalized()
	var h: Vector3 = at.call(head)
	return {"up": up, "fwd": fwd, "right": right, "head": h,
			"wound": h + up * 0.13 + fwd * 0.09, "chest": at.call(chest), "crown": NAN}


static func _bone(sk: Skeleton3D, names: Array) -> int:
	for n: String in names:
		var i := sk.find_bone(n)
		if i >= 0:
			return i
	return -1


func _bake_surface(mesh: Mesh, surface: int, to_sk: Transform3D, f: Dictionary) -> Image:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array(range(verts.size()))
	# Each texel's place on the body, interpolated across its triangle, and
	# the field evaluated THERE: a rivulet is a centimetre wide and a torso
	# triangle five, so a field evaluated at the vertices and interpolated
	# came out as blocks (Cody's chest, the first render).
	var pos := PackedVector3Array()
	pos.resize(verts.size())
	for i in verts.size():
		pos[i] = to_sk * verts[i]
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var set := PackedByteArray()
	r.resize(SIZE * SIZE)
	g.resize(SIZE * SIZE)
	set.resize(SIZE * SIZE)
	r.fill(NEVER)
	g.fill(NEVER)
	for t in range(0, index.size(), 3):
		var ia := index[t]
		var ib := index[t + 1]
		var ic := index[t + 2]
		var a := uvs[ia] * SIZE
		var b := uvs[ib] * SIZE
		var c := uvs[ic] * SIZE
		var x0 := clampi(int(floor(minf(a.x, minf(b.x, c.x)))), 0, SIZE - 1)
		var x1 := clampi(int(ceil(maxf(a.x, maxf(b.x, c.x)))), 0, SIZE - 1)
		var y0 := clampi(int(floor(minf(a.y, minf(b.y, c.y)))), 0, SIZE - 1)
		var y1 := clampi(int(ceil(maxf(a.y, maxf(b.y, c.y)))), 0, SIZE - 1)
		var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(den) < 1e-9:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				var py := y + 0.5
				var wa := ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / den
				var wb := ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / den
				var wc := 1.0 - wa - wb
				if wa < -0.02 or wb < -0.02 or wc < -0.02:
					continue
				var k := y * SIZE + x
				var p := pos[ia] * wa + pos[ib] * wb + pos[ic] * wc
				r[k] = head_field(p, f)
				g[k] = back_field(p, f)
				set[k] = 1
	# grow each island a few texels so filtering never pulls in NEVER at a seam
	for pass_i in 4:
		var grow := set.duplicate()
		for y in SIZE:
			for x in SIZE:
				var k := y * SIZE + x
				if set[k] == 1:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
						continue
					var n := ny * SIZE + nx
					if set[n] == 1:
						r[k] = r[n]
						g[k] = g[n]
						grow[k] = 1
						break
		set = grow
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var k := y * SIZE + x
			img.set_pixel(x, y, Color(clampf(r[k], 0.0, 1.0), clampf(g[k], 0.0, 1.0), 0.0))
	return img


## The head wound: the bleed (0-1) at which blood first shows at `p`
## (skeleton space, rest). A cut at the hairline; rivulets of different
## widths running straight down from it, wandering a little; a sheet over the
## middle of the face; past the chin only the rivulets go on, onto the neck and
## down the chest. The front only -- blood runs down a standing man's face,
## not round to the back of his head.
static func head_field(p: Vector3, f: Dictionary) -> float:
	var up: Vector3 = f["up"]
	var fwd: Vector3 = f["fwd"]
	var right: Vector3 = f["right"]
	var rel := p - (f["wound"] as Vector3)
	var y := rel.dot(up)
	var x := rel.dot(right)
	# in front of the head's centre, or of the chest's for the body below
	# within FACE_DEPTH behind the front of the forehead: the face, the
	# cheeks and the jaw, not the ears or the back of the skull. From the cut,
	# not the head bone -- Cody's face sits 9 cm off his rig's bone.
	var head_front := FACE_DEPTH + rel.dot(fwd)
	var chest_front := (p - (f["chest"] as Vector3)).dot(fwd)
	var drop := -y
	if drop < -0.015:
		# above the cut: only a small patch round it
		return clampf(0.05 + rel.length() * 7.0, 0.0, NEVER) if head_front > 0.0 else NEVER
	var front := head_front if drop < 0.26 else chest_front
	if front < -0.01:
		return NEVER
	var s := _rivulets(x, maxf(drop, 0.0))
	var sheet := exp(-pow(x / 0.04, 2.0))
	# The rivulets run first and fast; the sheet between them fills in late,
	# from the middle out. (2.6 / 1.6 / 2.2 covered the whole face by bleed
	# 0.35 -- the first render read as a red mask, not a cut.)
	var t := 0.04 + maxf(drop, 0.0) * (3.2 - 2.5 * maxf(s, 0.5 * sheet)) + absf(x) * 5.0 * (1.0 - s)
	if drop > 0.22:
		t += (1.0 - s) * 0.6          # past the chin: the rivulets alone
	if drop > 0.30:
		t += (drop - 0.30) * 0.8      # and they thin out down the chest
	return clampf(t, 0.0, NEVER)


## Rivulets: how much `x` (across the face, m) is in one, `drop` m below the
## cut. Five of them, each a little off straight down.
static func _rivulets(x: float, drop: float) -> float:
	var best := 0.0
	var centres := [-0.045, -0.018, 0.004, 0.026, 0.05]
	var widths := [0.007, 0.011, 0.009, 0.012, 0.007]
	for i in centres.size():
		var c: float = centres[i] + 0.010 * sin(drop * 22.0 + i * 1.7) + 0.004 * sin(drop * 61.0 + i)
		best = maxf(best, exp(-pow((x - c) / float(widths[i]), 2.0)))
	return best


## The back: punctures and smears across the upper back (landings on tacks,
## nails, barbed wire, glass), coming through in patches.
static func back_field(p: Vector3, f: Dictionary) -> float:
	var fwd: Vector3 = f["fwd"]
	var up: Vector3 = f["up"]
	# the shoulder blades, where a man lands on the tacks: a fixed drop below
	# the head, because the rigs' "chest" bones sit anywhere from the lower
	# back (Roman's J_Spine2, 44 cm under the head) to the sternum (25 cm)
	var centre: Vector3 = (f["chest"] as Vector3)
	centre.y = (f["head"] as Vector3).y - 0.30
	var behind := -(p - centre).dot(fwd)
	if behind < 0.0:
		return NEVER
	var r := (p - centre - fwd * (p - centre).dot(fwd)).length()
	if r > 0.34:
		return NEVER
	var n := _noise(p * 28.0)
	return clampf(0.08 + (r / 0.34) * 0.85 - 0.45 * (n - 0.5), 0.0, NEVER)


## Value noise, 0-1, from a hash of the lattice: deterministic everywhere.
static func _noise(p: Vector3) -> float:
	var i := p.floor()
	var fr := p - i
	var u := fr * fr * (Vector3.ONE * 3.0 - fr * 2.0)
	var v := []
	for dz in 2:
		for dy in 2:
			for dx in 2:
				v.append(_hash(i + Vector3(dx, dy, dz)))
	var x00 := lerpf(v[0], v[1], u.x)
	var x10 := lerpf(v[2], v[3], u.x)
	var x01 := lerpf(v[4], v[5], u.x)
	var x11 := lerpf(v[6], v[7], u.x)
	return lerpf(lerpf(x00, x10, u.y), lerpf(x01, x11, u.y), u.z)


static func _hash(p: Vector3) -> float:
	var h := sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453
	return h - floor(h)
