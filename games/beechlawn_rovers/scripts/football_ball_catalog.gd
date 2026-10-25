extends RefCounted
class_name FootballBallCatalog
## Appearance only. The authoritative FootballBall and its collider never change.
const DEFAULT: StringName = &"ucl_26_27_league"
const IDS: Array[StringName] = [DEFAULT, &"worn_sunday_league"]
const LABELS := ["adidas UCL 26/27 League", "Worn Sunday-league ball"]
const SCENES := {
	&"ucl_26_27_league": preload("res://assets/environment/ucl_26_27_league.glb"),
	&"worn_sunday_league": preload("res://assets/environment/old_used_ball.glb"),
}

static func valid_id(id: StringName) -> StringName:
	return id if id in IDS else DEFAULT

static func configure(visual: Node3D, id: StringName) -> void:
	id = valid_id(id)
	if visual.get_meta("appearance_id", &"") == id and visual.get_child_count() == 1:
		return
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	var model := (SCENES[id] as PackedScene).instantiate() as Node3D
	model.name = "Model"
	visual.add_child(model)
	visual.set_meta("appearance_id", id)
