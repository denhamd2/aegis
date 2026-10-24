extends Control
## One draw pass; orientation follows the side of the live gameplay camera.
var game: Node3D
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
 if not is_instance_valid(game): return
 var line := Color(.85,.87,.89,.40)
 draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.02,.025,.55))
 var pitch := Rect2(Vector2(9,9),size-Vector2(18,18))
 draw_rect(pitch,line,false,1)
 draw_line(Vector2(size.x/2,9),Vector2(size.x/2,size.y-9),line)
 draw_arc(size/2,8,0,TAU,32,line,1)
 for sign in [-1,1]:
  var x := pitch.position.x if sign == -1 else pitch.end.x-26
  draw_rect(Rect2(x,size.y/2-25,26,50),line,false,1)
  x = pitch.position.x-3 if sign == -1 else pitch.end.x
  draw_rect(Rect2(x,size.y/2-5,3,10),line,false,1)
 for actor in game._home_players+game._away_players:
  if not actor.visible or bool(actor.get_meta("sent_off",false)):continue
  var colour := Color("3268e6") if actor.attack_sign > 0 else Color("83d2f0")
  var point := _map(actor.position,pitch)
  if actor.controlled_by_human: draw_arc(point,4.5,0,TAU,16,Color.WHITE,1.2)
  draw_circle(point,2.5,colour)
 draw_circle(_map(game.ball.position,pitch),2,Color.WHITE)
func _map(point: Vector3, rect: Rect2) -> Vector2:
 var flip := 1.0 if game.camera_rig.get_node("Camera3D").global_position.z > 0 else -1.0
 return rect.position+Vector2(clampf(point.x/105*flip+.5,0,1),clampf(point.z/68*flip+.5,0,1))*rect.size
