extends Control
## Live roster-driven broadcast overlay; portraits are released with the intro.
const BOLD := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const REGULAR := preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
const BACKGROUND := preload("res://assets/ui/lineups/panel.png")
const PORTRAIT_SHADER := preload("res://assets/ui/lineups/portrait.gdshader")
const ROWS := [
	["striker_left", "striker_right"],
	["left_wing", "left_midfield", "right_midfield", "right_wing"],
	["left_back", "left_center_back", "right_center_back", "right_back"],
	["keeper"],
]
var teams: Array[FootballTeam] = []
var displayed_team := -1
var displayed_profiles: Array[FootballerProfile] = []
var manager_label: Label
var cards: Array[Control] = []
var _content: Control

func configure(home: FootballTeam, away: FootballTeam) -> void:
	teams = [home, away]
	position = Vector2(26, 68)
	size = Vector2(850, 752)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	hide()

func present_walk(time: float, duration: float) -> void:
	show()
	var half := duration * 0.5
	var index := 0 if time < half else 1
	if index != displayed_team:
		_rebuild(index)
	var local_time := time - float(index) * half
	modulate.a = smoothstep(0.0, 0.35, local_time) * (1.0 - smoothstep(half - 0.35, half, local_time))

func _rebuild(index: int) -> void:
	displayed_team = index
	displayed_profiles.clear()
	cards.clear()
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var team := teams[index]
	var accent := Color(0.48, 0.83, 1.0) if index == 1 else Color(0.58, 0.77, 1.0)
	_label(_content, "HOME  /  STARTING XI" if index == 0 else "AWAY  /  STARTING XI", Vector2(128, 18), Vector2(550, 22), 17, accent)
	_label(_content, team.display_name.to_upper(), Vector2(126, 41), Vector2(570, 50), 39, Color.WHITE)
	_label(_content, "4–4–2", Vector2(700, 39), Vector2(120, 42), 31, accent)
	_add_crest(index)
	var profiles := {}
	for profile in team.roster:
		profiles[profile.starting_slot] = profile
	for row_index in ROWS.size():
		var row: Array = ROWS[row_index]
		for column in row.size():
			var profile := profiles.get(row[column]) as FootballerProfile
			if profile == null:
				continue
			var center_x := 425.0 if row.size() == 1 else (280.0 + column * 290.0 if row.size() == 2 else 115.0 + column * 205.0)
			_add_card(profile, Vector2(center_x - 95.0, 125.0 + row_index * 145.0), accent)
	manager_label = _label(_content, "PLAYER-MANAGER  ·  " + team.manager_name.to_upper(), Vector2(34, 708), Vector2(780, 32), 23, Color.WHITE)
	if OS.has_feature("web") and OS.has_feature("debug"):
		JavaScriptBridge.eval("window.BEECHLAWN_LINEUP_TEAM = '%s'" % team.display_name)
		var numbers: Array[int] = []
		var identities: Array[String] = []
		for profile in displayed_profiles:
			numbers.append(profile.jersey_number)
			identities.append(profile.display_name)
		JavaScriptBridge.eval("window.BEECHLAWN_LINEUP_STATE = " + JSON.stringify({
			"team": team.display_name, "manager": team.manager_name,
			"numbers": numbers, "identities": identities, "formation": "4-4-2"}))

func _add_card(profile: FootballerProfile, at: Vector2, accent: Color) -> void:
	var card := Control.new()
	card.position = at
	card.size = Vector2(190, 132)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("player_id", profile.player_id)
	card.set_meta("jersey_number", profile.jersey_number)
	_content.add_child(card)
	var portrait := TextureRect.new()
	portrait.position = Vector2(51, 0)
	portrait.size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not profile.lineup_portrait_path.is_empty():
		portrait.texture = load(profile.lineup_portrait_path) as Texture2D
	var material := ShaderMaterial.new()
	material.shader = PORTRAIT_SHADER
	var region := profile.lineup_portrait_region
	material.set_shader_parameter("source_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	portrait.material = material
	card.add_child(portrait)
	var strip := ColorRect.new()
	strip.position = Vector2(0, 92)
	strip.size = Vector2(190, 32)
	strip.color = Color(0.015, 0.035, 0.075, 0.96)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(strip)
	var label := _label(card, "%d  %s" % [profile.jersey_number, _short_name(profile.display_name)], Vector2(2, 93), Vector2(186, 30), 22, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var underline := ColorRect.new()
	underline.position = Vector2(0, 124)
	underline.size = Vector2(190, 2)
	underline.color = accent
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(underline)
	displayed_profiles.append(profile)
	cards.append(card)

func _add_crest(index: int) -> void:
	var crest := TextureRect.new()
	crest.position = Vector2(34, 12)
	crest.size = Vector2(68, 88)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	if index == 0:
		atlas.atlas = load("res://assets/ui/club_crest_source.jpg") as Texture2D
		atlas.region = Rect2(294, 134, 692, 974)
		var mask := ShaderMaterial.new()
		mask.shader = load("res://assets/ui/club_crest_mask.gdshader") as Shader
		crest.material = mask
	else:
		atlas.atlas = load("res://assets/characters/textures/shared/bordeaux_outfield.png") as Texture2D
		var dimensions := atlas.atlas.get_size()
		atlas.region = Rect2(dimensions * Vector2(0.341, 0.103), dimensions * Vector2(0.074, 0.088))
	atlas.filter_clip = true
	crest.texture = atlas
	_content.add_child(crest)

func _short_name(full_name: String) -> String:
	var split := full_name.split(" ", false)
	return (split[0].left(1) + ". " + " ".join(split.slice(1))).to_upper() if split.size() > 1 else full_name.to_upper()

func _label(parent: Node, text: String, at: Vector2, bounds: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = bounds
	label.add_theme_font_override("font", BOLD)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
