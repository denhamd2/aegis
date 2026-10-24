extends Control
## Native vector HUD. Independent of the blue pre-match broadcast graphics.
const FONT := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const REGULAR := preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
const INK := Color(.025,.03,.04,.9)
var game: Node3D
var help_visible := false
var reader := preload("res://scripts/tactical_possession.gd").new()
var radar: Control
var possession: Dictionary = {}
var crest_cache: Dictionary = {}

func setup(match_scene: Node3D) -> void:
	game = match_scene
	name = "MatchHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar = Control.new()
	radar.set_script(preload("res://scripts/tactical_radar.gd"))
	radar.name = "TacticalRadar"
	radar.game = game
	add_child(radar)
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x/1280,viewport.y/720)
	scale = Vector2.ONE*factor
	size = viewport/maxf(factor,.01)
	radar.position = Vector2(size.x/2-94,size.y-136)
	radar.size = Vector2(188,112)
	radar.visible = not game._presentation_active and not game._full_time
	var actors: Array[FootballPlayer] = []
	actors.assign(game._home_players+game._away_players)
	possession = reader.sample(game.ball,actors)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		help_visible = not help_visible
		get_viewport().set_input_as_handled()

func _text(text: String, at: Vector2, font_size := 20, color := Color.WHITE, width := -1.0) -> void:
	draw_string(FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _draw() -> void:
	if not is_instance_valid(game): return
	var x := 24.0
	var y := 24.0
	draw_rect(Rect2(x,y,316,36),INK)
	draw_rect(Rect2(x+85,y,43,36),Color.WHITE)
	draw_rect(Rect2(x+173,y,43,36),Color.WHITE)
	_text("BEE",Vector2(x+35,y+25),22)
	_text(str(game._home_score),Vector2(x+101,y+25),24,Color("111318"))
	_text("BR27",Vector2(x+134,y+24),17)
	_text(str(game._away_score),Vector2(x+189,y+25),24,Color("111318"))
	_text("BOA",Vector2(x+255,y+25),22)
	_crest(game._home_team,Rect2(x+5,y+5,24,26))
	_crest(game._away_team,Rect2(x+222,y+5,25,26))
	draw_colored_polygon(PackedVector2Array([Vector2(x+96,y+37),Vector2(x+220,y+37),Vector2(x+210,y+63),Vector2(x+106,y+63)]),INK)
	_text(game.clock_label.text,Vector2(x+132,y+57),20)
	if game._presentation_active or game._full_time: return
	var home := game.player as FootballPlayer
	var away: FootballPlayer
	var carrier := possession.get("carrier") as FootballPlayer
	if game._spectator_mode: home = _relevant(game._home_players,carrier)
	away = _relevant(game._away_players,carrier)
	_player_strip(home,Vector2(26,size.y-67),false)
	_player_strip(away,Vector2(size.x-270,size.y-67),true)
	if game.message_label.text != "":
		var text: String = game.message_label.text
		var width := minf(650,FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+32)
		draw_rect(Rect2((size.x-width)/2,94,width,30),INK)
		_text(text,Vector2((size.x-width)/2+16,115),18,Color.WHITE,width-32)
	if game.restart.active() and not game.restart.released:
		var prompt: String = game.restart.kind+"   ·   WASD aim   ·   Hold/release E" if game.restart.taker.profile.role != "goalkeeper" and not game._spectator_mode else game.restart.kind+"   ·   Preparing delivery"
		draw_rect(Rect2(size.x/2-240,size.y-182,480,29),INK)
		_text(prompt,Vector2(size.x/2-224,size.y-161),17)
	if help_visible:
		draw_rect(Rect2(size.x-438,135,410,234),INK)
		var lines := ["KEYBOARD CONTROLS","WASD  Move   Shift  Sprint   Ctrl  Close / jockey","E  Pass   Q  Through   R  Loft   T  Cross","Space  Shoot   F  Tackle   G  Slide","J  Contain   H  Pressure   K  Shield","U / I / O / P / L / B  Skills","Tab  Switch   C  Camera   Esc  Title","F1  Close help"]
		for i in lines.size(): _text(lines[i],Vector2(size.x-420,161+i*26),17)
	else:
		draw_rect(Rect2(size.x-104,12,80,26),INK)
		_text("F1  HELP",Vector2(size.x-92,30),13,Color(.9,.9,.9))

func _crest(team: Resource, rect: Rect2) -> void:
	if team == null: return
	var texture: AtlasTexture = crest_cache.get(team.team_id)
	if texture == null:
		texture = AtlasTexture.new()
		if team.team_id == game._home_team.team_id:
			texture.atlas = preload("res://assets/ui/club_crest_source.jpg")
			texture.region = Rect2(294,134,692,974)
		else:
			texture.atlas = preload("res://assets/characters/textures/shared/bordeaux_outfield.png")
			var dimensions := texture.atlas.get_size()
			texture.region = Rect2(dimensions*Vector2(.341,.103),dimensions*Vector2(.074,.088))
		crest_cache[team.team_id] = texture
	var intrinsic_size := texture.get_size()
	var fitted := intrinsic_size*minf(rect.size.x/intrinsic_size.x,rect.size.y/intrinsic_size.y)
	draw_texture_rect(texture,Rect2(rect.get_center()-fitted*.5,fitted),false)

func _relevant(team: Array, carrier: FootballPlayer) -> FootballPlayer:
	if is_instance_valid(carrier) and carrier in team: return carrier
	var best: FootballPlayer
	var gap := INF
	for actor in team:
		if not actor.visible or bool(actor.get_meta("sent_off",false)): continue
		var distance: float = actor.position.distance_squared_to(game.ball.position)
		if distance < gap: best = actor; gap = distance
	return best

func _player_strip(actor: FootballPlayer, at: Vector2, away: bool) -> void:
	if not is_instance_valid(actor) or actor.profile == null: return
	draw_rect(Rect2(at,Vector2(244,37)),INK)
	var colour := Color("72c9ef") if away else Color("2459df")
	draw_rect(Rect2(at,Vector2(8,37)),colour)
	var title := "%d  %s" % [actor.profile.jersey_number,actor.profile.display_name]
	while FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x > 220:
		title = title.substr(0,title.length()-2)+"…"
	_text(title,at+Vector2(16,24),20)
	draw_rect(Rect2(at+Vector2(0,37),Vector2(244,5)),Color("797c82"))
	draw_rect(Rect2(at+Vector2(0,37),Vector2(244*clampf(actor.stamina/actor.tuning.stamina_max,0,1),5)),Color.WHITE)
	if not away and not game._spectator_mode and game.power_bar.value > 0:
		draw_rect(Rect2(at+Vector2(0,-8),Vector2(244,4)),INK)
		draw_rect(Rect2(at+Vector2(0,-8),Vector2(244*game.power_bar.value/100,4)),colour)
