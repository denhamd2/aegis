extends Node
## Real-controller landing diagnostic. Never loaded by gameplay.
## CPU skins individual surfaces with post-modifier bone poses and active
## morphs. Reports arms separately: an arm cannot masquerade as back contact.
## godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers cody,roman --out /tmp/landing.json

var _defender: WrestlerController
var _rig: Node
var _surfaces: Array[Dictionary] = []
var _poses: Dictionary = {}
var _stamps: Dictionary = {}
var _clocks: Dictionary = {}
var _last_clock := 0.0
var _morph_weights: Dictionary = {}
var _rows: Array = []
var _out := "/tmp/landing.json"
var _ticks := 0
var _started := false
var _finished_tick := -1
var _roster := "cody,roman"
var _half_tick := false
var _phase_shifted := false
var _swap_roles := false
var _attacker: WrestlerController

func _ready() -> void:
	set_process(false)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--wrestlers" and i + 1 < args.size(): _roster = args[i + 1]
		if args[i] == "--out" and i + 1 < args.size(): _out = args[i + 1]
		if args[i] == "--half-tick": _half_tick = true
		if args[i] == "--swap-roles": _swap_roles = true
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	for name in ["Arena", "LightRig", "RingReflections"]:
		var cosmetic := scene.get_node_or_null(NodePath(name))
		if cosmetic: cosmetic.free()
	scene.entrances = false
	var pair := Roster.pair_from_spec(_roster)
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	var attacker: WrestlerController = scene.get_node("WrestlerB" if _swap_roles else "WrestlerA")
	_defender = scene.get_node("WrestlerA" if _swap_roles else "WrestlerB")
	_attacker = attacker
	attacker.is_ai = false
	_defender.is_ai = false
	_defender.global_position = attacker.global_position - attacker.global_basis.z * 0.9
	attacker.look_at(_defender.global_position)
	_defender.look_at(attacker.global_position)
	await get_tree().physics_frame
	_prepare()
	_rig = scene.get_node("GrappleRig")
	_rig.grapple_finished.connect(func(_a, _d): _finished_tick = _ticks)
	var move: MoveDef = load("res://resources/moves/running_grapple_inverted_drop.tres")
	attacker._begin_running_paired(move)
	_started = true
	set_process(true)

func _prepare() -> void:
	for mesh: MeshInstance3D in _defender.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var path := String(_defender.get_path_to(mesh))
		if path.to_lower().contains("entrance"): continue
		var sk := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if sk == null: continue
		if not _poses.has(sk):
			_poses[sk] = []
			sk.skeleton_updated.connect(_capture.bind(sk))
		var bindings: Array[int] = []
		var regions: Array[String] = []
		for b in mesh.skin.get_bind_count():
			var index := mesh.skin.get_bind_bone(b)
			if index < 0: index = sk.find_bone(mesh.skin.get_bind_name(b))
			assert(index >= 0, "Unresolved skin binding")
			bindings.append(index)
			regions.append(_region(sk, index))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var material := mesh.get_active_material(surface)
			var label := material.resource_name if material else "unassigned"
			var cosmetic := false
			for token in ["hair", "beard", "brow", "eye", "lash", "teeth", "tongue", "mouthbag"]:
				if (path + "/" + label).to_lower().contains(token): cosmetic = true
			if _defender.get_node("CharacterModel") is RomanModel and String(mesh.name) in ["Ringlets", "lambert1_skinned", "body_skinned"]:
				cosmetic = true # Roman side hair, hanging hair and M_Tongue
			_surfaces.append({"mesh": mesh, "sk": sk, "surface": surface,
				"path": path, "material": label, "cosmetic": cosmetic,
				"arrays": arrays, "bindings": bindings, "regions": regions})

func _region(sk: Skeleton3D, index: int) -> String:
	# Explicit limb stops before walking up to the spine.
	while index >= 0:
		var bone := String(sk.get_bone_name(index)).to_lower()
		for token in ["arm", "hand", "finger", "thumb", "shoulder", "clavicle"]:
			if bone.contains(token): return "arm"
		for token in ["leg", "thigh", "calf", "foot", "toe"]:
			if bone.contains(token): return "leg"
		if bone.contains("head"): return "head"
		if bone.contains("neck"): return "neck"
		if bone.contains("spine"): return "back"
		if bone.contains("hip") or bone.contains("pelvis"): return "pelvis"
		index = sk.get_bone_parent(index)
	return "other"

func _capture(sk: Skeleton3D) -> void:
	var poses: Array[Transform3D] = []
	for index in sk.get_bone_count(): poses.append(sk.get_bone_global_pose(index))
	_poses[sk] = poses
	_stamps[sk] = Engine.get_physics_frames()
	_clocks[sk] = _defender._anim_playback.get_current_play_position()
	for entry in _surfaces:
		if entry.sk != sk: continue
		var mesh: MeshInstance3D = entry.mesh
		var weights: Array[float] = []
		for shape in mesh.mesh.get_blend_shape_count(): weights.append(mesh.get_blend_shape_value(shape))
		_morph_weights[mesh] = weights

func _process(_delta: float) -> void:
	if _started: _sample.call_deferred()

func _sample() -> void:
	_ticks += 1
	# Diagnostic-only phase offset after lead-in. Sample between 60Hz keys
	# without changing simulation Hz or doubling any gameplay counters.
	if _half_tick and not _phase_shifted and _rig.progress() > 0.2:
		_phase_shifted = true
		_rig.animation_player.advance(1.0 / 120.0)
		_attacker.anim_tree.advance(1.0 / 120.0)
		_defender.anim_tree.advance(1.0 / 120.0)
		return # wait for fresh post-modifier snapshots on the next frame
	var clock: float = _rig.progress() * 2.2 if _rig.is_active() else 2.2
	_last_clock = maxf(_last_clock, clock)
	if _ticks > 240:
		push_error("Landing probe timed out before completion")
		get_tree().quit(1)
		return
	if _last_clock < 1.8: return
	var coherent := true
	for sk in _poses:
		if _stamps.get(sk, -1) != Engine.get_physics_frames(): coherent = false
		if absf(float(_clocks.get(sk, -1.0)) - _defender._anim_playback.get_current_play_position()) > 0.0001: coherent = false
	assert(coherent, "Mixed/stale skeleton sample")
	var results: Array = []
	var floor_y := MatGuard.MAT_Y
	for entry in _surfaces:
		var mesh: MeshInstance3D = entry.mesh
		var sk: Skeleton3D = entry.sk
		var poses: Array = _poses[sk]
		if poses.is_empty():
			results.append({"path": entry.path, "invalid": "no skeleton_updated"})
			continue
		var matrices: Array[Transform3D] = []
		for b in entry.bindings.size():
			# Use the final world frame after ALL skeleton callbacks: a later
			# PairSeparation callback can translate this character model.
			matrices.append(sk.global_transform * poses[entry.bindings[b]] * mesh.skin.get_bind_pose(b))
		var arrays: Array = entry.arrays
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty(): continue
		var stride := bones.size() / vertices.size()
		var morphs: Array = mesh.mesh.surface_get_blend_shape_arrays(entry.surface)
		var regions := {}
		for v in vertices.size():
			var position := vertices[v]
			for shape in morphs.size():
				var weight: float = _morph_weights[mesh][shape]
				if weight == 0.0: continue
				var shape_vertices: PackedVector3Array = morphs[shape][Mesh.ARRAY_VERTEX]
				if mesh.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
					position += (shape_vertices[v] - vertices[v]) * weight
				else: position += shape_vertices[v] * weight
			var world := Vector3.ZERO
			var dominant := 0
			var highest := -1.0
			for j in stride:
				var weight := weights[v * stride + j]
				var bind := bones[v * stride + j]
				if weight > highest:
					highest = weight
					dominant = bind
				if weight > 0.0: world += (matrices[bind] * position) * weight
			var region: String = entry.regions[dominant]
			var y := world.y - floor_y
			if not regions.has(region) or y < float(regions[region].y):
				regions[region] = {"y": y, "vertex": v}
		results.append({"path": entry.path, "surface": entry.surface,
			"material": entry.material, "cosmetic": entry.cosmetic,
			"pose_tick": _stamps[sk], "regions": regions})
	_rows.append({"tick": _ticks, "physics_tick": Engine.get_physics_frames(),
		"source_frame": _last_clock * 30.0, "raw_root_seconds": clock, "coherent": coherent, "pose_seconds": _defender._anim_playback.get_current_play_position(), "pose_node": _defender._anim_playback.get_current_node(), "active": _rig.is_active(),
		"state": _defender.fsm.current_state, "finished_tick": _finished_tick, "surfaces": results})
	if (_finished_tick >= 0 and _ticks >= _finished_tick + 12) or _ticks > 220:
		var file := FileAccess.open(_out, FileAccess.WRITE)
		file.store_string(JSON.stringify({"roster": _roster, "half_tick": _half_tick, "swap_roles": _swap_roles, "samples": _rows}, "\t"))
		print("LANDING_PROBE ", _out, " samples=", _rows.size(), " finished=", _finished_tick)
		get_tree().quit(0 if _finished_tick >= 0 else 1)
