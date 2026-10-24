extends RefCounted
class_name FootballShotDirector
## Cuts establish new camera stations; damping applies only inside a shot.
var current_shot: StringName = &""
var cuts := 0
var _requested_shot: StringName = &""
var _wide_fallback := false
var _alternate_side := false
var obstruction := ""

func reset() -> void:
	current_shot = &""
	cuts = 0
	_requested_shot = &""
	_wide_fallback = false
	_alternate_side = false
	obstruction = ""

func frame(camera: Camera3D, id: StringName, target: Vector3, station: Vector3,
		fov: float, delta: float, game: Node3D, subject: Node3D = null) -> void:
	station.x = clampf(station.x, -57, 57)
	station.z = clampf(station.z, -40, 40)
	station.y = maxf(station.y, game.surface_height(station.x, station.z) + .18)
	if id != _requested_shot:
		_requested_shot = id
		_alternate_side = false
		var query := PhysicsRayQueryParameters3D.create(target, station)
		var excluded: Array[RID] = []
		if subject is CollisionObject3D: excluded.append(subject.get_rid())
		# Ball/net collision proxies are solid to football physics, but the
		# broadcast lens can look through the net's visible open weave.
		excluded.append(game.ball.get_rid())
		for body in game.get_node("Goals").find_children("NetCollision", "StaticBody3D", true, false):
			excluded.append(body.get_rid())
		for actor in game._home_players + game._away_players:
			if not actor.visible: excluded.append(actor.get_rid())
		query.exclude = excluded
		var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
		_wide_fallback = not hit.is_empty()
		obstruction = String(hit.collider.name) if not hit.is_empty() else ""
		if _wide_fallback:
			query.to = target + (station-target) * Vector3(1,1,-1)
			query.to.z = clampf(query.to.z,-40,40)
			_alternate_side = game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
			_wide_fallback = not _alternate_side
	# Keep the chosen station for this shot instead of flickering between
	# close and wide whenever a celebrating teammate crosses the sight line.
	if _wide_fallback:
		station = target + Vector3(-6 if target.x > 0 else 6, 4.5, 9)
		fov = 48
		id = StringName(String(id) + "_clear_wide")
	elif _alternate_side:
		station = target + (station-target) * Vector3(1,1,-1)
		station.z = clampf(station.z,-40,40)
	var cut := id != current_shot
	if cut:
		current_shot = id
		cuts += 1
		camera.global_position = station
		camera.fov = fov
		camera.reset_physics_interpolation()
	else:
		camera.global_position = camera.global_position.lerp(station, 1 - exp(-delta * 3))
	camera.look_at(target)
	if cut and game.grass_detail != null: game.grass_detail.prewarm(station)
	FootballCameraOptics.for_camera(camera).shot(id, target, fov, delta)
