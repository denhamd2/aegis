extends Node

func _ready() -> void:
	call_deferred("run")

func model_frame(node: Node3D) -> Transform3D:
	var frame := node.transform
	var parent := node.get_parent()
	while parent:
		if parent is Node3D: frame = parent.transform * frame
		parent = parent.get_parent()
	return frame

var overrides := {}

func local_pose(sk: Skeleton3D, bone: int) -> Transform3D:
	return overrides.get(sk.get_instance_id(), {}).get(bone, sk.get_bone_rest(bone))

func bone_frame(sk: Skeleton3D, bone: int) -> Transform3D:
	var pose := local_pose(sk,bone)
	var parent := sk.get_bone_parent(bone)
	return bone_frame(sk,parent) * pose if parent >= 0 else pose

func point(sk: Skeleton3D, bone: String) -> Vector3:
	return model_frame(sk) * bone_frame(sk,sk.find_bone(bone)).origin

func apply(anim: Animation, root: Node, at: float, direct_sk: Skeleton3D = null) -> void:
	var touched := {}
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		var sk := direct_sk
		if sk == null:
			sk = root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
		if sk == null: continue
		var bone := sk.find_bone(String(path.get_concatenated_subnames()))
		if bone < 0: continue
		var sid := sk.get_instance_id()
		if not touched.has(sid):
			overrides[sid] = {}
			touched[sid] = true
		var pose: Transform3D = local_pose(sk,bone)
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D: pose.origin = anim.position_track_interpolate(i,at)
			Animation.TYPE_ROTATION_3D: pose.basis = Basis(anim.rotation_track_interpolate(i,at)).scaled(pose.basis.get_scale())
			Animation.TYPE_SCALE_3D: pose.basis = pose.basis.orthonormalized().scaled(anim.scale_track_interpolate(i,at))
		overrides[sid][bone] = pose

func run() -> void:
	var src := (load("res://assets/characters/wrestler_base.glb") as PackedScene).instantiate()
	var src_sk := src.find_child("Skeleton3D", true, false) as Skeleton3D
	var roman := (load("res://scenes/roman_model.tscn") as PackedScene).instantiate()
	var roman_sk := roman.get_game_skeleton() as Skeleton3D
	print("REST src hips=", point(src_sk,"pelvis")," head=",point(src_sk,"Head")," frame=",model_frame(src_sk))
	print("REST roman hips=",point(roman_sk,"J_Hips")," head=",point(roman_sk,"J_Head")," frame=",model_frame(roman_sk))
	var rest: Dictionary = roman._rest_pair(src_sk,"pelvis",roman_sk,"J_Hips")
	print("PELVIS_REST source=",rest["source"]," target=",rest["target"]," source_parent=",rest["source_parent"]," target_parent=",rest["target_parent"])
	var source_lib := load("/tmp/aegis-wrap-candidate2-poses.tres") as AnimationLibrary
	var anim := source_lib.get_animation("running_grapple_inverted_drop__defender")
	var only := AnimationLibrary.new()
	only.add_animation("probe",anim)
	var mapped := roman.adapt_animation_library(only,src_sk) as AnimationLibrary
	for height: float in [1.0,1.905/1.866]:
		roman.apply_physique_height(height)
		for frame: float in [55.0,58.0,59.0,61.0,63.0]:
			src_sk.reset_bone_poses()
			for sk in roman._animation_skeletons(): sk.reset_bone_poses()
			apply(anim,src,frame/30,src_sk)
			apply(mapped.get_animation("probe"),roman,frame/30)
			var sp := point(src_sk,"pelvis")
			var sh := point(src_sk,"Head")
			var rp := point(roman_sk,"J_Hips")
			var rh := point(roman_sk,"J_Head")
			print("FK frame=",frame," scale=",height," src_pelvis=",sp," src_head=",sh," roman_pelvis=",rp," roman_head=",rh," src_head_rel=",sh-sp," roman_head_rel=",rh-rp)
	src.free()
	roman.free()
	get_tree().quit()
