extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var game=load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 game._set_players_physics_enabled(false)
 var visuals:Array=[]
 for actor in game._home_players+game._away_players:
  var visual:FootballerVisual=actor._footballer_visual
  visual.reset_to_idle()
  visual.set_locomotion_speed(6)
  visuals.append(visual)
 for label in ["layers","bypass"]:
  if label=="bypass":
   for visual in visuals:
    var tree:=visual.animation_tree.tree_root as AnimationNodeBlendTree
    tree.disconnect_node("Receive",0)
    tree.disconnect_node("output",0)
    tree.connect_node("output",0,"Shield")
  var start:=Time.get_ticks_usec()
  for tick in 160:
   for visual in visuals:visual.animation_tree.advance(1./60)
  print("RECEIVE_GRAPH_COST ",label," us=",Time.get_ticks_usec()-start)
 game.free()
 quit()
