extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	assert(FileAccess.file_exists("res://assets/characters/supporters/LICENSE-MIT.txt"),"The source license must ship")
	for avatar in 12:
		var audit:=FootballSupporterAssets.audit(avatar)
		assert(audit.bones==80 and audit.clips.size()==9)
		assert(audit.vat_decoded_bytes<8*1024*1024)
		for level in 3:
			var data:=FootballSupporterAssets.lod(avatar,level)
			assert(data.triangles<=[600,100,64][level])
			var image:Image=data.positions.get_image()
			assert(image.get_format() in [Image.FORMAT_RGBH,Image.FORMAT_RGBAH,Image.FORMAT_RGBF,Image.FORMAT_RGBAF],"Signed VAT positions need float channels")
			for sample in mini(32,int(data.vertex_count)):
				var id:=posmod(sample*97,int(data.vertex_count))
				var pixel:=image.get_pixel(id%int(data.width),image.get_height()-1-id/int(data.width))
				var expected:=Vector3(data.vertices[id*3],data.vertices[id*3+1],data.vertices[id*3+2])
				assert(Vector3(pixel.r,pixel.g,pixel.b).distance_to(expected)<.003,"VAT importer changed channels: avatar=%d LOD=%d id=%d actual=%s expected=%s"%[avatar,level,id,Vector3(pixel.r,pixel.g,pixel.b),expected])
	var session:=root.get_node("MatchSession");session.venue_id=&"rovers_arena"
	var game:Node3D=load("res://scenes/match_11v11.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var crowd:=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
	assert(crowd!=null and crowd.attendance==49554)
	assert(game.find_child("RoversArena",true,false).get_meta("seat_count")==49554)
	var sections:Array=RoversArena.layout().sections
	var away_sections:Dictionary={0:true,1:true,47:true,48:true,49:true}
	for section:Dictionary in sections:
		assert((section.support_side=="away")==away_sections.has(int(section.id)),"Away support must occupy only the lower NE/North blocks")
	var side_counts:Dictionary={"home":0,"away":0};var team_counts:Dictionary={"home":0,"away":0}
	var flag_counts:Dictionary={"south":0,"other_home":0,"away":0}
	var phases:Dictionary={}
	for batch:Dictionary in crowd.batches:
		assert(batch.nodes.size()==3,"Keep all three GPU crowd levels")
		for record:Dictionary in batch.records:
			side_counts[record.support_side]+=1
			if record.team_clothes:team_counts[record.support_side]+=1
			assert((record.garment_variant<8)==record.team_clothes)
			assert(record.custom.a==1.0 and record.custom.b>0.0,"Keep visibility and garment metadata")
			phases[record.custom.r]=true
	assert(side_counts.home==46436 and side_counts.away==3118)
	assert(team_counts.home==37149 and team_counts.away==2494,"Exact 80/20 split rounded per support side")
	assert(phases.size()>90,"Bodies need independent animation phases")
	for record:Dictionary in crowd.flags:
		assert(record.flag_bearer and record.role==record.support_side+"_flag")
		if record.support_side=="away":flag_counts.away+=1
		elif record.bank=="South":flag_counts.south+=1
		else:flag_counts.other_home+=1
	assert(flag_counts=={"south":36,"other_home":12,"away":16})
	assert(crowd.hero_pool.size()==32 and crowd.flags.size()==64)
	assert(crowd._flag_poles.instance_count==64 and crowd._flag_cloth.instance_count==64)
	assert(crowd.states.home_flag.to=="Flag" and crowd.states.away_flag.to=="Flag")
	assert(crowd._flag_material.get_shader_parameter("away_primary").is_equal_approx(game._away_team.primary_kit_color))
	assert(crowd.materials.home[0].get_shader_parameter("team_primary").is_equal_approx(game._home_team.primary_kit_color))
	assert(crowd.materials.away[0].get_shader_parameter("team_primary").is_equal_approx(game._away_team.primary_kit_color))
	var close_mesh:=crowd.hero_pool[0].model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var garment_uv:PackedVector2Array=close_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert(garment_uv.size()>0,"Close-up GLBs need the garment mask in UV2")
	var min_mask:=1.0;var max_mask:=0.0
	for uv:Vector2 in garment_uv:min_mask=minf(min_mask,uv.y);max_mask=maxf(max_mask,uv.y)
	assert(min_mask<.01 and max_mask>.99,"Close-up garment mask must distinguish clothing from skin and hair")
	var away_hero:Dictionary=crowd.hero_pool[0]
	away_hero.record=crowd.flags.filter(func(record:Dictionary):return record.support_side=="away")[0]
	crowd._colour_hero(away_hero)
	var hero_material:=close_mesh.material_override as ShaderMaterial
	assert(hero_material.get_shader_parameter("team_primary").is_equal_approx(game._away_team.primary_kit_color))
	assert(is_equal_approx(hero_material.get_shader_parameter("garment_variant"),away_hero.record.custom.b))
	away_hero.record={}
	assert(game.find_child("Dockside",true,false)!=null)
	game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game._home_players[0],Vector3(40,1,0),25)
	assert(crowd.states.side.to=="Rise" and crowd.states.side.next=="Stand","A section rises during high action without a false goal celebration")
	assert(crowd.states.home.to=="Attention" and crowd.states.away.to=="Attention")
	assert(crowd.states.home_flag.to=="Flag" and crowd.states.away_flag.to=="Flag")
	crowd._process(1.6);assert(crowd.states.side.to=="Stand")
	crowd._process(2.1);assert(crowd.states.side.to=="Sit")
	crowd._process(1.7);assert(crowd.states.side.to=="Seated")
	var before:=crowd.snapshot()
	game._home_score+=1
	game.events.emit_event(FootballMatchEvent.Kind.GOAL,&"Beechlawn Rovers",game._away_players[0],Vector3(53,1,0))
	assert(crowd.states.home.to=="Rise" and crowd.states.away.to=="Disappoint","Own-goal reaction follows scoring side")
	assert(crowd.states.home_flag.to=="Cheer" and crowd.states.away_flag.to=="Disappoint")
	crowd._process(1.6);assert(crowd.states.home.to=="Cheer")
	crowd._process(4.6);assert(crowd.states.home.to=="Sit")
	assert(crowd.states.home_flag.to=="Flag" and crowd.states.away_flag.to=="Flag")
	crowd._process(1.7);assert(crowd.states.home.to=="Seated")
	var live:=crowd.snapshot();crowd.apply_snapshot(before)
	assert(crowd.replaying and crowd.clock==before[0] and crowd.states.home_flag.to=="Flag")
	crowd.restore_live()
	assert(not crowd.replaying and crowd.snapshot()==live,"Replay restores exact live crowd state")
	game._away_score+=1
	game.events.emit_event(FootballMatchEvent.Kind.GOAL,&"Boardeaux",game._home_players[0],Vector3(-53,1,0))
	assert(crowd.states.home.to=="Disappoint" and crowd.states.away.to=="Rise","Opposite own goal follows the scoring side")
	assert(crowd.states.home_flag.to=="Disappoint" and crowd.states.away_flag.to=="Cheer")
	game.free();await process_frame
	session.venue_id=&"kilmore_drive"
	game=load("res://scenes/match_11v11.tscn").instantiate();root.add_child(game);await process_frame
	crowd=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
	assert(crowd.park and crowd.attendance==8 and crowd.hero_pool.size()==8)
	assert(crowd.states.home.to=="Stand" and crowd.flags.is_empty())
	assert(crowd.hero_pool[0].model.find_children("*","MeshInstance3D",true,false)[0].material_override is StandardMaterial3D,"Kilmore's casual spectators keep their original material")
	for batch:Dictionary in crowd.batches:
		for record:Dictionary in batch.records:assert(record.pose.basis.z.dot(Vector3(0,0,1))>.99,"Park spectators face the pitch")
	game.free();await process_frame
	print("SUPPORTER_CROWD PASS: 49554 seats, 3118 away, 80/20 garments, 36/12/16 flags, score/replay states and eight unchanged park fans")
	quit()
