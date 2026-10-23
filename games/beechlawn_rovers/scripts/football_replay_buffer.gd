extends RefCounted
class_name FootballReplayBuffer
## Immutable 30Hz snapshots. No rules, AI, collision or ball resimulation.
const HZ := 30.0
const HISTORY_FRAMES := 360
const BOOKMARK_FRAMES := 240
const MAX_BOOKMARKS := 3
const MAX_DATA_BYTES := 60 * 1024 * 1024 # Leave 4MiB of the 64MiB budget for metadata.
var history: Array[Dictionary] = []
var bookmarks: Array[Dictionary] = []
var actors: Array[Node3D] = []
var skeletons: Array[Skeleton3D] = []
var game: Node3D
var stride := 21
var clock := 0.0
var accumulator := 0.0
func setup(match_scene: Node3D) -> void:
	game=match_scene
	for actor in game._home_players+game._away_players: actors.append(actor)
	var official := game.get_node_or_null("Referee") as Node3D
	if official != null: actors.append(official)
	for actor in actors:
		var found := actor.get_node("Visual").find_children("*","Skeleton3D",true,false)
		var skeleton := found[0] as Skeleton3D if not found.is_empty() else null
		skeletons.append(skeleton)
		stride+=8+(skeleton.get_bone_count()*7 if skeleton != null else 0)
func sample(delta: float, recording: bool) -> void:
	clock+=delta
	if not recording: accumulator=0;return
	accumulator+=delta
	if accumulator+0.000001 < 1/HZ: return
	accumulator=fmod(accumulator,1/HZ)
	var data := PackedFloat32Array()
	data.resize(stride)
	var offset := _write(data,0,game.ball.global_position,game.ball.global_basis.get_rotation_quaternion())
	for side in [-1,1]:
		var impact: Dictionary=game._net_impacts.get(side,{})
		var point := Vector3.ZERO;var force := Vector3.ZERO;var age := 2.0
		if not impact.is_empty():
			point=vector_parameter(impact.material,"impact_point")
			force=vector_parameter(impact.material,"impact_vector")
			age=float(impact.age)
		data[offset]=age;offset+=1
		for value in [point.x,point.y,point.z,force.x,force.y,force.z]: data[offset]=value;offset+=1
	for index in actors.size():
		var actor := actors[index]
		data[offset]=1 if actor.visible else 0;offset+=1
		offset=_write(data,offset,actor.global_position,actor.global_basis.get_rotation_quaternion())
		var skeleton := skeletons[index]
		if skeleton == null: continue
		for bone in skeleton.get_bone_count(): offset=_write(data,offset,skeleton.get_bone_pose_position(bone),skeleton.get_bone_pose_rotation(bone))
	assert(offset==stride)
	history.append({"time":clock,"pose":data})
	if history.size()>HISTORY_FRAMES: history.pop_front()
static func vector_parameter(material: ShaderMaterial,name: StringName) -> Vector3:
	var value = material.get_shader_parameter(name)
	return value if value is Vector3 else Vector3.ZERO
static func _write(data: PackedFloat32Array, offset: int, position: Vector3, rotation: Quaternion) -> int:
	data[offset]=position.x;data[offset+1]=position.y;data[offset+2]=position.z
	data[offset+3]=rotation.x;data[offset+4]=rotation.y;data[offset+5]=rotation.z;data[offset+6]=rotation.w
	return offset+7
func bookmark(kind: StringName) -> Dictionary:
	if history.size()<8: return {}
	var frames := history.slice(maxi(0,history.size()-BOOKMARK_FRAMES))
	var entry := {"kind":kind,"frames":frames,"duration":float(frames[-1].time)-float(frames[0].time)}
	bookmarks.append(entry)
	while bookmarks.size()>MAX_BOOKMARKS or data_bytes()>MAX_DATA_BYTES: bookmarks.pop_front()
	return entry
func data_bytes() -> int:
	var count := history.size()
	for entry in bookmarks: count+=entry.frames.size()
	return count*stride*4
func clear_history() -> void:
	history.clear();accumulator=0
static func position(data: PackedFloat32Array, offset: int) -> Vector3:
	return Vector3(data[offset],data[offset+1],data[offset+2])
static func rotation(data: PackedFloat32Array, offset: int) -> Quaternion:
	return Quaternion(data[offset+3],data[offset+4],data[offset+5],data[offset+6]).normalized()
func apply_frame(entry: Dictionary, seconds: float, ghosts: Array[Node3D], ghost_ball: Node3D, ghost_skeletons: Array[Skeleton3D]) -> void:
	var frames: Array=entry.frames
	var at := float(frames[0].time)+clampf(seconds,0,float(entry.duration))
	var index := 0
	# Bookmarks contain at most 240 entries. Binary search avoids pose scans.
	var low := 0;var high := frames.size()-1
	while low<high:
		var middle := (low+high+1)/2
		if float(frames[middle].time)<=at: low=middle
		else: high=middle-1
	index=low
	var next := mini(index+1,frames.size()-1)
	var factor := clampf((at-float(frames[index].time))/maxf(.001,float(frames[next].time)-float(frames[index].time)),0,1)
	var a: PackedFloat32Array=frames[index].pose
	var b: PackedFloat32Array=frames[next].pose
	ghost_ball.transform=Transform3D(Basis(rotation(a,0).slerp(rotation(b,0),factor)),position(a,0).lerp(position(b,0),factor))
	var offset := 7
	for side in [-1,1]:
		if game._net_impacts.has(side):
			var material: ShaderMaterial=game._net_impacts[side].material
			material.set_shader_parameter("impact_age",lerpf(a[offset],b[offset],factor))
			material.set_shader_parameter("impact_point",position(a,offset+1))
			material.set_shader_parameter("impact_vector",position(a,offset+4))
		offset+=7
	for actor_index in ghosts.size():
		ghosts[actor_index].visible=a[offset]>.5;offset+=1
		ghosts[actor_index].transform=Transform3D(Basis(rotation(a,offset).slerp(rotation(b,offset),factor)),position(a,offset).lerp(position(b,offset),factor))
		offset+=7
		var skeleton := ghost_skeletons[actor_index]
		if skeleton==null:continue
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_position(bone,position(a,offset).lerp(position(b,offset),factor))
			skeleton.set_bone_pose_rotation(bone,rotation(a,offset).slerp(rotation(b,offset),factor))
			offset+=7
