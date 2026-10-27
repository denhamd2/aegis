extends Node3D
class_name FootballSupporterCrowd
## Stable seat IDs, animated 3D VAT LODs and a bounded near-camera skeleton pool.
const ASSETS:=preload("res://scripts/supporter_assets.gd")
const SNAPSHOT_FLOATS:=36
const ROLES:=["home","side","away","home_flag","away_flag"]
const HOME_TEAM:=preload("res://data/teams/beechlawn_11.tres")
const AWAY_TEAM:=preload("res://data/teams/bordeaux_11.tres")
static var _clock_registered:=false
var park:=false
var game:Node3D
var clock:=0.0
var attendance:=0
var states:Dictionary={}
var materials:Dictionary={}
var batches:Array[Dictionary]=[]
var hero_pool:Array[Dictionary]=[]
var active_heroes:Dictionary={}
var flags:Array[Dictionary]=[]
var _flag_poles:MultiMesh
var _flag_cloth:MultiMesh
var _flag_material:ShaderMaterial
var team_colours:Dictionary={}
var _selection_time:=0.0
var _threat_time:=0.0
var _scores:=Vector2i.ZERO
var _live_snapshot:=PackedFloat32Array()
var replaying:=false

func build(entries:Array,sections:Array,park_crowd:=false) -> void:
	park=park_crowd;name="AnimatedSupporters"
	_set_team_colours(HOME_TEAM,AWAY_TEAM)
	if not _clock_registered:
		_clock_registered=true
	for role in ROLES:
		var idle:String="Stand" if park else "Flag" if role.ends_with("_flag") else "Seated"
		states[role]={"from":idle,"to":idle,"from_time":0.0,"to_time":0.0,"at":-10.0,"until":1e9,"next":""}
		materials[role]=[]
	var groups:Dictionary={}
	var lowest:Dictionary={}
	var side_totals:Dictionary={"home":0,"away":0}
	var side_index:Dictionary={"home":0,"away":0}
	var flag_ids:Dictionary={} if park else _choose_flag_seats(entries,sections)
	for entry:Array in entries:
		var section:int=int(entry[4]);lowest[section]=minf(float(lowest.get(section,1e9)),float(entry[1]))
		var side:String=sections[section].get("support_side","home")
		side_totals[side]+=1
	for i in entries.size():
		var entry:Array=entries[i];var section_id:int=int(entry[4]);var section:Dictionary=sections[section_id]
		var side:String=section.get("support_side","home")
		var bearer:bool=flag_ids.has(i)
		var role:String=(side+"_flag") if bearer else "side" if side=="home" and section.get("role","")=="side" else side
		var avatar:=i%12
		# Four variants in each block; adjacent blocks shift across all twelve.
		if not park:avatar=(section_id*5+i%4)%12
		var key:="%d_%d_%d_%s"%[section_id,int((float(entry[1])-float(lowest[section_id]))/6.0),avatar,role]
		if not groups.has(key):groups[key]={"section":section_id,"avatar":avatar,"role":role,"support_side":side,"records":[]}
		var pose:=Transform3D(Basis(Vector3.UP,float(entry[3])),Vector3(entry[0],entry[1],entry[2]))
		pose.basis=pose.basis*Basis(Vector3.UP,PI) # Chairs face local -Z; avatars face +Z.
		var centre:Array=section.get("centre",[0,0,0])
		var origin:=Vector3(centre[0],centre[1],centre[2])
		var garment_variant:int=i%12
		var team_clothes:=false
		if not park:
			var index:int=side_index[side];side_index[side]=index+1
			var team_total:=roundi(float(side_totals[side])*.8)
			team_clothes=floori(float(index+1)*team_total/side_totals[side])>floori(float(index)*team_total/side_totals[side])
			garment_variant=posmod(index*7+section_id*3,8) if team_clothes else 8+posmod(index*3+section_id,4)
		var custom:=Color(float(i%97)/97.0,float(posmod(i*19,101))/101.0,(float(garment_variant)+.5)/12.0,1)
		var record:={"id":i,"pose":pose,"custom":custom,"avatar":avatar,"role":role,"support_side":side,"team_clothes":team_clothes,"garment_variant":garment_variant,"section":section_id,"bank":section.get("bank",""),"flag_bearer":bearer,"instance":groups[key].records.size()}
		groups[key].records.append(record)
		groups[key]["centre"]=origin;attendance+=1
		if bearer:flags.append(record)
	for key in groups:
		var batch:Dictionary=groups[key];batch["nodes"]=[]
		var average:=Vector3.ZERO
		for record:Dictionary in batch.records:average+=record.pose.origin
		batch.centre=average/float(batch.records.size())
		for level in 3:
			var data:=ASSETS.lod(batch.avatar,level);var mesh:=data.mesh as ArrayMesh
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=batch.records.size()
			for i in batch.records.size():
				var record:Dictionary=batch.records[i];var pose:Transform3D=record.pose;pose.origin-=batch.centre
				mm.set_instance_transform(i,pose);mm.set_instance_custom_data(i,record.custom)
			var node:=MultiMeshInstance3D.new();node.name="Crowd_%s_LOD%d"%[key,level];node.position=batch.centre;node.multimesh=mm
			node.layers=4;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_begin=[0,24,65][level];node.visibility_range_end=[24,65,320][level]
			node.visibility_range_begin_margin=2;node.visibility_range_end_margin=2
			node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			# Material instances share state per role/avatar/LOD, not per block.
			var mat_key:="%s_%d_%d"%[batch.role,batch.avatar,level]
			if not materials.has(mat_key):
				materials[mat_key]=ASSETS.material(batch.avatar,level)
				materials[mat_key].set_meta("support_side",batch.support_side)
				_set_material_colours(materials[mat_key],batch.support_side)
				materials[batch.role].append(materials[mat_key])
			node.material_override=materials[mat_key];add_child(node);batch.nodes.append(node)
		for record:Dictionary in batch.records:record["batch"]=batches.size()
		batches.append(batch)
	for role in ROLES:_sync_materials(role)
	_create_pool()
	if not park:_create_flags()
	set_meta("attendance",attendance);set_meta("crowd_style","full-body GPU vertex animation, 12 avatars, 3 LODs, bounded rig pool")
	call_deferred("_bind")

static func _choose_flag_seats(entries:Array,sections:Array) -> Dictionary:
	var south:Array[int]=[];var other:Array[int]=[];var away:Array[int]=[]
	for i in entries.size():
		var section:Dictionary=sections[int(entries[i][4])]
		if section.get("support_side","home")=="away":away.append(i)
		elif section.get("bank","")=="South":south.append(i)
		else:other.append(i)
	var chosen:Dictionary={}
	for selection in [[south,36],[other,12],[away,16]]:
		var candidates:Array=selection[0];var wanted:int=selection[1]
		assert(candidates.size()>=wanted)
		for n in wanted:
			chosen[candidates[int((float(n)+.5)*candidates.size()/wanted)]]=true
	return chosen

func _set_team_colours(home:FootballTeam,away:FootballTeam) -> void:
	team_colours={"home":[home.primary_kit_color,home.secondary_kit_color],"away":[away.primary_kit_color,away.secondary_kit_color]}
	for role in ROLES:
		if not materials.has(role):continue
		for material:ShaderMaterial in materials[role]:_set_material_colours(material,material.get_meta("support_side"))
	if _flag_material!=null:
		_flag_material.set_shader_parameter("home_primary",team_colours.home[0])
		_flag_material.set_shader_parameter("home_secondary",team_colours.home[1])
		_flag_material.set_shader_parameter("away_primary",team_colours.away[0])
		_flag_material.set_shader_parameter("away_secondary",team_colours.away[1])

func _set_material_colours(material:ShaderMaterial,side:String) -> void:
	material.set_shader_parameter("team_primary",team_colours[side][0])
	material.set_shader_parameter("team_secondary",team_colours[side][1])

func _bind() -> void:
	if game!=null:return
	var node:Node=get_parent()
	while node!=null:
		if node.get("events")!=null:game=node as Node3D;break
		node=node.get_parent()
	if game!=null:
		if game.get("_home_team") is FootballTeam and game.get("_away_team") is FootballTeam:
			_set_team_colours(game.get("_home_team"),game.get("_away_team"))
		_scores=Vector2i(game._home_score,game._away_score)
		game.events.occurred.connect(_on_event)

func _create_pool() -> void:
	for i in (8 if park else 32):
		var avatar:=i%12;var model:=ASSETS.hero(avatar,park);model.name="NearSupporter_%02d"%i;add_child(model);model.hide()
		var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var skeleton:=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		hero_pool.append({"model":model,"player":player,"skeleton":skeleton,"avatar":avatar,"record":{},"clips":{}})
		for state in ASSETS.STATES:hero_pool[-1].clips[state]=ASSETS.animation(player,state)

func _set_state(role:String,state:String,duration:float,next_state:="") -> void:
	var data:Dictionary=states[role]
	if data.to==state:
		if next_state!="":data.next=next_state;data.until=maxf(float(data.until),clock+duration)
		return
	data.from=data.to;data.from_time=data.to_time;data.to=state;data.to_time=clock;data.at=clock;data.until=clock+duration;data.next=next_state
	_sync_materials(role)
func _sync_materials(role:String) -> void:
	var state:Dictionary=states[role]
	for mat:ShaderMaterial in materials[role]:
		# Each role list holds materials for three LODs of its avatar variants.
		var data:=ASSETS.lod(int(mat.get_meta("avatar")),int(mat.get_meta("level")))
		for part in ["from","to"]:
			var kind:String=state[part];var clip:Dictionary=data.clips[kind]
			mat.set_shader_parameter("clip_"+part,Vector4(clip.start,clip.frames,clip.duration,1 if kind in ["Rise","Sit"] else 0))
		mat.set_shader_parameter("from_time",state.from_time);mat.set_shader_parameter("to_time",state.to_time);mat.set_shader_parameter("transition_time",state.at)

func _on_event(event:FootballMatchEvent) -> void:
	if replaying:return
	if event.kind==FootballMatchEvent.Kind.GOAL:
		# Score deltas correctly identify own goals; last-touch team cannot.
		var home:=event.score.x>_scores.x;_scores=event.score
		for role in ROLES:
			var supporting:bool=(not role.begins_with("away"))==home
			if role.ends_with("_flag") and not park:
				_set_state(role,"Cheer" if supporting else "Disappoint",4.5 if supporting else 3.5,"Flag")
			else:
				_set_state(role,"Cheer" if park and supporting else "Stand" if park else "Rise" if supporting else "Disappoint",4.5 if park else 1.5 if supporting else 3.5,"Cheer" if supporting and not park else "")
	elif event.kind==FootballMatchEvent.Kind.BALL_CONTACT and event.action in [&"shot",&"power",&"finesse",&"header",&"volley"]:
		for role in ["home","side","away"]:
			var rise:bool=role=="side" and not park
			_set_state(role,"Rise" if rise else "Stand" if park else "Attention",1.5 if rise else 2,"Stand" if rise else "")
	elif event.kind==FootballMatchEvent.Kind.FULL_TIME:
		for role in ROLES:
			_set_state(role,"Cheer" if role.ends_with("_flag") and not park or park else "Rise",1.5,"Flag" if role.ends_with("_flag") and not park else "")

func _process(delta:float) -> void:
	if not replaying:
		clock+=delta
		for role in ROLES:
			var state:Dictionary=states[role]
			if clock>=float(state.until):
				var next:String=state.next if state.next!="" else "Flag" if role.ends_with("_flag") and not park else "Cheer" if state.to=="Rise" else "Sit" if state.to in ["Cheer","Flag","Stand"] and not park else "Stand" if park else "Seated"
				_set_state(role,next,4.5 if next=="Cheer" else 1.6 if next=="Sit" else 2 if next=="Stand" and not park else 1e9)
		_threat_time+=delta
		if _threat_time>.1 and game!=null:
			_threat_time=0
			if absf(game.ball.position.x)>35 and absf(game.ball.position.z)<20 and game.ball.linear_velocity.length()>9:
				for role in ["home","side","away"]:
					if states[role].to=="Seated" or park:
						var rise:bool=role=="side" and not park
						_set_state(role,"Rise" if rise else "Stand" if park else "Attention",1.5 if rise else 2,"Stand" if rise else "")
	RenderingServer.global_shader_parameter_set("football_crowd_clock",clock)
	_selection_time+=delta
	if _selection_time>.25:
		_selection_time=0;_select_heroes()
	for hero:Dictionary in hero_pool:
		if not hero.record.is_empty():_pose_hero(hero)
	_update_flags()

func _select_heroes() -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var limit:=8 if park else 32 if game!=null and (game._intro_active or game._presentation_active) else 16
	var candidates:Array[Dictionary]=[]
	for batch:Dictionary in batches:
		if not park and camera.global_position.distance_to(to_global(batch.centre))>43:continue
		for record:Dictionary in batch.records:
			var distance:float=camera.global_position.distance_to(to_global(record.pose.origin))
			if park or distance<18:
				record["distance"]=distance;candidates.append(record)
	candidates.sort_custom(func(a:Dictionary,b:Dictionary):return a.distance<b.distance)
	var selected:Dictionary={}
	for record:Dictionary in candidates:
		if selected.size()>=limit:break
		selected[record.id]=record
	for id in active_heroes.keys():
		if not selected.has(id):
			var hero:Dictionary=active_heroes[id];_mask_record(hero.record,true);hero.model.hide();hero.record={};active_heroes.erase(id)
	for id in selected:
		if active_heroes.has(id):continue
		var record:Dictionary=selected[id]
		var chosen:Dictionary={}
		for hero:Dictionary in hero_pool:
			if hero.record.is_empty() and hero.avatar==record.avatar:chosen=hero;break
		if chosen.is_empty():
			for hero:Dictionary in hero_pool:
				if hero.record.is_empty():chosen=hero;_recast_hero(chosen,int(record.avatar));break
		if not chosen.is_empty():
			chosen.record=record;chosen.model.transform=record.pose;_colour_hero(chosen);_pose_hero(chosen);chosen.model.show();_mask_record(record,false);active_heroes[id]=chosen

func _recast_hero(hero:Dictionary,avatar:int) -> void:
	hero.model.free()
	var model:=ASSETS.hero(avatar,park);add_child(model);model.hide()
	hero.model=model;hero.avatar=avatar;hero.player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	hero.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	hero.skeleton=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	hero.clips={}
	for state in ASSETS.STATES:hero.clips[state]=ASSETS.animation(hero.player,state)

func _colour_hero(hero:Dictionary) -> void:
	if park:return
	var record:Dictionary=hero.record
	for mesh:MeshInstance3D in hero.model.find_children("*","MeshInstance3D",true,false):
		var material:=mesh.material_override as ShaderMaterial
		material.set_shader_parameter("team_primary",team_colours[record.support_side][0])
		material.set_shader_parameter("team_secondary",team_colours[record.support_side][1])
		material.set_shader_parameter("garment_variant",record.custom.b)

func _mask_record(record:Dictionary,enabled:bool) -> void:
	var custom:Color=record.custom;custom.a=1 if enabled else 0
	for node:MultiMeshInstance3D in batches[record.batch].nodes:node.multimesh.set_instance_custom_data(record.instance,custom)

func _pose_hero(hero:Dictionary) -> void:
	var record:Dictionary=hero.record;var state:Dictionary=states[record.role];var custom:Color=record.custom
	var delay:=custom.g*.65;var phase:=custom.r*2.6
	var blend:=smoothstep(0,.55,clock-float(state.at)-delay)
	var player:=hero.player as AnimationPlayer;var skeleton:=hero.skeleton as Skeleton3D
	var from_pose:Array[Transform3D]=[]
	if blend<1:
		_seek(player,hero.clips[state.from],clock-float(state.from_time)-delay+(0 if state.from in ["Rise","Sit"] else phase),String(state.from))
		for bone in skeleton.get_bone_count():from_pose.append(skeleton.get_bone_pose(bone))
	var seconds:float=clock-float(state.to_time)-delay+(0 if state.to in ["Rise","Sit"] else phase)
	_seek(player,hero.clips[state.to],seconds,String(state.to))
	if blend<1:
		for bone in skeleton.get_bone_count():
			var pose:=from_pose[bone].interpolate_with(skeleton.get_bone_pose(bone),blend)
			skeleton.set_bone_pose_position(bone,pose.origin);skeleton.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion())
static func _seek(player:AnimationPlayer,clip:StringName,seconds:float,state:String) -> void:
	var duration:=player.get_animation(clip).length
	var at:=clampf(seconds,0,duration) if state in ["Rise","Sit"] else fposmod(seconds,duration)
	player.play(clip);player.seek(at,true);player.advance(0)

func _create_flags() -> void:
	# Bearers are selected before batching so their bodies use Fan_Flag independently.
	var pole:=CylinderMesh.new();pole.top_radius=.012;pole.bottom_radius=.012;pole.height=1.4;pole.radial_segments=5
	var white:=StandardMaterial3D.new();white.albedo_color=Color(.72,.73,.7);white.roughness=.55;pole.material=white
	var cloth:=PlaneMesh.new();cloth.orientation=PlaneMesh.FACE_Z;cloth.size=Vector2(.65,.42);cloth.subdivide_width=8;cloth.subdivide_depth=3
	_flag_material=ShaderMaterial.new();_flag_material.shader=preload("res://shaders/supporter_flag.gdshader");cloth.material=_flag_material
	_set_team_colours(HOME_TEAM,AWAY_TEAM)
	for mesh:Mesh in [pole,cloth]:
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=flags.size()
		var node:=MultiMeshInstance3D.new();node.name="SupporterFlagPoles" if mesh==pole else "SupporterFlags";node.multimesh=mm;node.layers=4;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=180
		# Hand samples move in the render loop, so physics interpolation would
		# present the pole and cloth one simulation tick behind the animated body.
		node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(node)
		if mesh==pole:_flag_poles=mm
		else:_flag_cloth=mm
	_update_flags()
func _update_flags() -> void:
	if _flag_poles==null:return
	for i in flags.size():
		var record:Dictionary=flags[i];var state:Dictionary=states[record.role];var custom:Color=record.custom
		var blend:=smoothstep(0,.55,clock-float(state.at)-custom.g*.65)
		var a:=ASSETS.hand(record.avatar,state.from,clock-float(state.from_time)-custom.g*.65+(0 if state.from in ["Rise","Sit"] else custom.r*2.6))
		var b:=ASSETS.hand(record.avatar,state.to,clock-float(state.to_time)-custom.g*.65+(0 if state.to in ["Rise","Sit"] else custom.r*2.6))
		var hand:Vector3=record.pose*a.lerp(b,blend)
		var basis:Basis=record.pose.basis*Basis(Vector3.FORWARD,sin(clock*1.7+custom.r*6.28)*.08)
		_flag_poles.set_instance_transform(i,Transform3D(basis,hand+basis*Vector3(0,.5,0)))
		_flag_cloth.set_instance_transform(i,Transform3D(basis,hand+basis*Vector3(.325,1.0,0)))
		_flag_cloth.set_instance_custom_data(i,Color(custom.r,custom.g,1.0 if record.support_side=="away" else 0.0,1.0))

func snapshot() -> PackedFloat32Array:
	var data:=PackedFloat32Array([clock])
	for role in ROLES:
		var s:Dictionary=states[role]
		data.append_array(PackedFloat32Array([ASSETS.STATES.find(s.from),ASSETS.STATES.find(s.to),s.from_time,s.to_time,s.at,s.until,ASSETS.STATES.find(s.next)]))
	return data
func apply_snapshot(data:PackedFloat32Array) -> void:
	if data.size()!=SNAPSHOT_FLOATS:return
	if not replaying:_live_snapshot=snapshot();replaying=true
	clock=data[0]
	for i in ROLES.size():
		var offset:=1+i*7;var role:String=ROLES[i]
		var restored:Dictionary={"from":ASSETS.STATES[int(data[offset])],"to":ASSETS.STATES[int(data[offset+1])],"from_time":data[offset+2],"to_time":data[offset+3],"at":data[offset+4],"until":data[offset+5],"next":ASSETS.STATES[int(data[offset+6])] if data[offset+6]>=0 else ""}
		if restored!=states[role]:states[role]=restored;_sync_materials(role)
func restore_live() -> void:
	if not replaying:return
	apply_snapshot(_live_snapshot);replaying=false;_live_snapshot=PackedFloat32Array()
