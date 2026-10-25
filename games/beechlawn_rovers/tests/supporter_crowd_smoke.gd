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
	assert(crowd!=null and crowd.attendance>44000 and crowd.attendance<48000)
	assert(crowd.hero_pool.size()==32 and crowd.flags.size()==64)
	assert(game.find_child("Dockside",true,false)!=null)
	game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game._home_players[0],Vector3(40,1,0),25)
	assert(crowd.states.side.to=="Rise" and crowd.states.side.next=="Stand","A section rises during high action without a false goal celebration")
	crowd._process(1.6);assert(crowd.states.side.to=="Stand")
	crowd._process(2.1);assert(crowd.states.side.to=="Sit")
	crowd._process(1.7);assert(crowd.states.side.to=="Seated")
	var before:=crowd.snapshot()
	game._home_score+=1
	game.events.emit_event(FootballMatchEvent.Kind.GOAL,&"Beechlawn Rovers",game._away_players[0],Vector3(53,1,0))
	assert(crowd.states.home.to=="Rise" and crowd.states.away.to=="Disappoint","Own-goal reaction follows scoring side")
	crowd._process(1.6);assert(crowd.states.home.to=="Cheer")
	crowd._process(4.6);assert(crowd.states.home.to=="Sit")
	crowd._process(1.7);assert(crowd.states.home.to=="Seated")
	var live:=crowd.snapshot();crowd.apply_snapshot(before)
	assert(crowd.replaying and crowd.clock==before[0]);crowd.restore_live()
	assert(not crowd.replaying and crowd.snapshot()==live,"Replay restores exact live crowd state")
	game.free();await process_frame
	session.venue_id=&"kilmore_drive"
	game=load("res://scenes/match_11v11.tscn").instantiate();root.add_child(game);await process_frame
	crowd=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
	assert(crowd.park and crowd.attendance==8 and crowd.hero_pool.size()==8)
	assert(crowd.states.home.to=="Stand" and crowd.flags.is_empty())
	for batch:Dictionary in crowd.batches:
		for record:Dictionary in batch.records:assert(record.pose.basis.z.dot(Vector3(0,0,1))>.99,"Park spectators face the pitch")
	game.free();await process_frame
	print("SUPPORTER_CROWD PASS: signed VAT, 12 human variants, budgets, attendance, flags, event/replay isolation and eight park fans")
	quit()
