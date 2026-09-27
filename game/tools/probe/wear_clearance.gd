extends Node
## Measures how far Roman's body passes THROUGH the AEW title worn round his
## waist, on every sampled frame of his real entrance.
##
##   godot4 --headless --path game --fixed-fps 30 \
##       tools/probe/wear_clearance.tscn -- --every 5 [--verbose] [--dump FILE]
##
## Written for the owner's entrance video, where part of the title sat inside
## Roman's stomach. The title (EntranceProps) has no collision and no render
## gate knows what a belt is, so this skins his meshes on the CPU -- the same
## sum the GPU does, bind pose by bind pose -- and takes every torso vertex
## inside the belt's height band, in the belt's own frame, against the belt
## line (roman_props.py's waist): how far outside the line the body reaches.
## Positive is through the strap. `--dump` writes those points (belt frame)
## for refitting the line; roman_props.py's WAIST_* came from one.
##
## A coat is not measured here. Nearest-surface tests against Cody's coat
## were tried and fire on every edge the body passes (the open front, the
## cuffs, the vents), so the coat is checked on pixels: coat_shot.tscn.

const MATCH_SCENE := "res://scenes/match.tscn"
## Must match tools/blender/roman_props.py.
const WAIST_HALF_X := 0.225
const WAIST_FRONT := 0.225
const WAIST_BACK := 0.165
## Body meshes that are not skin or clothing a belt sits over.
const SKIP := ["hair", "beard", "brow", "eye", "lash", "teeth", "tongue"]
## Body parts the belt goes round. Not the arms, which hang in its band
## outside it, nor the thighs: a knee lifted to climb the steps comes up in
## front of the plates' bottom edge, as it would under a real belt.
const TORSO_BONES := ["pelvis", "spine_01", "spine_02"]

var _every := 3
var _frame := 0
var _worst := {}
var _verbose := false
var _worst_bone := ""
## --dump PATH: every in-band body point near the belt line, belt frame.
var _dump: FileAccess


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--dump" and i + 1 < args.size():
			_dump = FileAccess.open(args[i + 1], FileAccess.WRITE)
		elif args[i] == "--verbose":
			_verbose = true
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	while not rang[0]:
		await get_tree().process_frame
		_frame += 1
		if _frame % _every != 0:
			continue
		var beat := ""
		if director._beat < director._beats.size():
			var b: Dictionary = director._beats[director._beat]
			beat = "%s %s" % [b["kind"], b.get("clip", b.get("shot", ""))]
		for w: WrestlerController in director._props:
			var props: EntranceProps = director._props[w]
			if is_instance_valid(props) and props._title and props._title_state == "worn":
				_note("title " + w.entrance_style, _title_depth(w, props), beat)
	for key: String in _worst:
		if _verbose:
			print("%s band" % key)
		var r: Array = _worst[key]
		print("%-18s worst %6.3f m  frame %5d  (%s)  samples %d" % [key, r[0], r[1], r[2], r[3]])
	if _dump:
		_dump.close()
	print("WEAR_CLEARANCE done at frame %d" % _frame)
	get_tree().quit()


func _note(key: String, depth: float, beat: String) -> void:
	var r: Array = _worst.get(key, [-INF, 0, "", 0])
	r[3] += 1
	if depth > r[0]:
		r[0] = depth
		r[1] = _frame
		r[2] = beat
	_worst[key] = r


## Body meshes of a wrestler: every skinned MeshInstance3D under him that is
## not hair, eyes or teeth, and not a prop.
func _body(w: WrestlerController) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in w.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null or not mi.is_visible_in_tree():
			continue
		var p := String(w.get_path_to(mi)).to_lower()
		if p.contains("entrance"):
			continue
		var skip := false
		for s in SKIP:
			if String(mi.name).to_lower().contains(s):
				skip = true
		if not skip:
			out.append(mi)
	return out


## CPU skinning: [positions, normals, dominant bone name] in world space.
func _skinned(mi: MeshInstance3D, with_normals: bool) -> Array:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var dom := PackedStringArray()
	if skel == null:
		return [pos, nrm, dom]
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	var names := PackedStringArray()
	for b in skin.get_bind_count():
		var idx := skin.get_bind_bone(b)
		if idx < 0:
			idx = skel.find_bone(skin.get_bind_name(b))
		names.append(skel.get_bone_name(maxi(idx, 0)))
		mats.append(skel.global_transform * skel.get_bone_global_pose(maxi(idx, 0))
				* skin.get_bind_pose(b))
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			continue
		var k := bones.size() / verts.size()
		for v in verts.size():
			var m := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
			var top := -1.0
			var top_name := ""
			for j in k:
				var wt := weights[v * k + j]
				if wt > top:
					top = wt
					top_name = names[bones[v * k + j]]
				if wt > 0.0:
					var t := mats[bones[v * k + j]]
					m.basis.x += t.basis.x * wt
					m.basis.y += t.basis.y * wt
					m.basis.z += t.basis.z * wt
					m.origin += t.origin * wt
			pos.append(m * verts[v])
			dom.append(top_name)
			if with_normals:
				nrm.append((m.basis * ns[v]).normalized())
	return [pos, nrm, dom]


## His skeleton's names for these canonical bones.
func _bones(w: WrestlerController, canonical: Array) -> Dictionary:
	var out := {}
	for c: String in canonical:
		out[w._skeleton_bone_name(c)] = true
	return out


## How far outside the belt line his body reaches, in metres, inside the
## band the belt covers.
func _title_depth(w: WrestlerController, props: EntranceProps) -> float:
	var inv := props._title.global_transform.affine_inverse()
	var lo := INF
	var hi := -INF
	for node in props._title.find_children("Title*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box: AABB = props._title.global_transform.affine_inverse() \
				* mi.global_transform * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	var worst := -INF
	var torso := _bones(w, TORSO_BONES)
	for mi in _body(w):
		var sk := _skinned(mi, false)
		for i in (sk[0] as PackedVector3Array).size():
			if not torso.has(sk[2][i]):
				continue
			var q := inv * (sk[0][i] as Vector3)
			if q.y < lo or q.y > hi:
				continue
			var x := q.x
			var z := q.z
			var r := Vector2(x, z).length()
			if r < 1e-4:
				continue
			var c := x / r
			var sn := z / r
			var hz := WAIST_FRONT if z < 0.0 else WAIST_BACK
			var line := 1.0 / sqrt((c * c) / (WAIST_HALF_X * WAIST_HALF_X)
					+ (sn * sn) / (hz * hz))
			if _dump and r - line > -0.04:
				_dump.store_line("%.4f %.4f %.4f" % [q.x, q.y, q.z])
			if r - line > worst:
				worst = r - line
				_worst_bone = "%s y%.2f x%.2f z%.2f" % [sk[2][i], q.y, q.x, q.z]
	if _verbose:
		print("  f%d title %.3f %s" % [_frame, worst, _worst_bone])
	return worst
