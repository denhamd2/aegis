extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var session := root.get_node("MatchSession")
 assert(FootballMatchVenue.valid_id(&"bad") == &"kilmore_drive")
 var cfg := "user://venue_selection_test.cfg"
 session.venue_id = &"rovers_arena"; session.switch_mode = &"manual"
 assert(session.save_preferences(cfg) == OK)
 session.venue_id = &"kilmore_drive"; session.switch_mode = &"assisted"
 session.load_preferences(cfg)
 assert(session.venue_id == &"rovers_arena" and session.switch_mode == &"manual")
 DirAccess.remove_absolute(cfg)
 for id in FootballMatchVenue.IDS:
  session.venue_id = id
  var game = load("res://scenes/match_11v11.tscn").instantiate()
  root.add_child(game)
  game.set_physics_process(false); game._set_players_physics_enabled(false)
  await physics_frame
  assert(game.venue.id == id and game.ball.surface_profile == game.venue)
  assert(game._home_players.size() == 11 and game._away_players.size() == 11)
  assert(game._net_impacts.size() == 2,"Both functional nets must keep impact animation")
  assert(game.get_node("Goals").find_children("GoalDetector","Node3D",true,false).size() == 2)
  var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
  for point in [Vector2(17,11),Vector2(-30,-18),Vector2(36,20)]:
   var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,2,point.y),Vector3(point.x,-2,point.y),1)
   var hit: Dictionary = space.intersect_ray(ray)
   assert(not hit.is_empty())
   assert(absf(hit.position.y-game.surface_height(point.x,point.y))<.004)
   assert(is_equal_approx(game.surface_height(point.x,point.y),game.ball.surface_height(point.x,point.y)))
  if id == &"rovers_arena":
   assert(game.surface_height(17,11) == 0)
   var arena: Node3D = game.get_node("ParkEdge/RoversArena")
   assert(arena.get_meta("seat_count") > 45000)
   assert(arena.find_children("CornerFlag*","MeshInstance3D",true,false).size() == 4)
   assert(arena.find_children("SeatsNear*","MultiMeshInstance3D",true,false).size() == 24)
   assert(arena.find_children("SeatsFar*","MultiMeshInstance3D",true,false).size() == 24)
   assert(game.ball.wet_surface.sample_at(Vector3(50.9,0,-1.5)) == Vector2.ZERO,"Arena inherited Kilmore puddles")
  else:
   assert(absf(game.surface_height(17,11)) > .001)
   assert(game.ball.wet_surface.sample_at(Vector3(50.9,0,-1.5)).y > .9)
  game.free()
 session.venue_id = &"kilmore_drive"
 var menu = load("res://scenes/title_screen.tscn").instantiate()
 root.add_child(menu)
 var venue := menu.options_layer.get_node("VenueSelect") as OptionButton
 venue.select(1); venue.item_selected.emit(1)
 assert(session.venue_id == &"rovers_arena")
 assert(menu.canvas.get_node("SelectedVenue").text.contains("ROVERS ARENA"))
 var switch := menu.options_layer.get_node("PlayerSwitching") as OptionButton
 switch.select(0); switch.item_selected.emit(0)
 assert(session.switch_mode == &"assisted")
 menu.free()
 print("VENUE_SELECTION PASS: persistence, invalid fallback, both grounds, flat/uneven physics, goals/nets/flags, section LOD, independent wet surfaces and menu bindings")
 quit()
