extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 root.get_node("MatchSession").venue_id = &"kilmore_drive"
 var game = load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 for legacy in ["League","Score","Clock","Controls","Power","Message"]:
  assert(not game.get_node("HUD/"+legacy).visible,"Legacy HUD overlaps replacement")
 assert(game.clock_label.text == "03:00")
 var hud: Control = game.match_hud
 assert(hud.name == "MatchHUD" and hud.radar != null)
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  root.size = resolution
  hud._process(0)
  assert(hud.radar.position.y > 0)
  assert(is_equal_approx(hud.radar.position.x+hud.radar.size.x/2,hud.size.x/2))
  assert(hud.radar.position.y+hud.radar.size.y < hud.size.y)
 var carrier: FootballPlayer = game._away_players[3]
 assert(hud._relevant(game._away_players,carrier) == carrier)
 game._set_power(.65)
 assert(is_equal_approx(game.power_bar.value,65) and not game.power_bar.visible)
 var help := InputEventKey.new();help.keycode=KEY_F1;help.pressed=true
 hud._unhandled_key_input(help)
 assert(hud.help_visible)
 game._presentation_active = true
 hud._process(0)
 assert(not hud.radar.visible)
 print("HUD PASS: monochrome replacement, clock, responsive radar at 3 aspects, carrier identity, distinct power, help and presentation visibility")
 game.free();quit()
