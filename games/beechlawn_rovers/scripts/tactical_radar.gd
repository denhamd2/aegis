extends Control
## One lightweight draw pass for all active players, official and independent ball.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO,size)
	draw_rect(bounds, Color(0.02,0.04,0.03,0.65))
	var pitch := Rect2(Vector2(8,8),size-Vector2(16,16))
	draw_rect(pitch, Color(0.8,0.83,0.76,0.65),false,1.0)
	draw_line(Vector2(size.x/2,8),Vector2(size.x/2,size.y-8),Color(0.8,0.83,0.76,0.6))
	for actor in get_tree().get_nodes_in_group("football_players"):
		var player := actor as FootballPlayer
		var color := Color(0.2,0.45,0.95) if player.attack_sign>0 else Color(0.55,0.84,1.0)
		if player.controlled_by_human:color=Color(1.0,0.85,0.15)
		draw_circle(_map(player.global_position,pitch),3.5 if player.controlled_by_human else 2.5,color)
	var ball := get_node_or_null("../../Ball") as FootballBall
	if ball != null:draw_circle(_map(ball.global_position,pitch),2.1,Color.WHITE)

func _map(point: Vector3, rect: Rect2) -> Vector2:
	return rect.position+Vector2(clampf(point.x/105.0+0.5,0,1),clampf(point.z/68.0+0.5,0,1))*rect.size
