extends Resource
class_name FootballGoalProfile
@export var model_path := "res://assets/environment/kilmore/park_goal.glb"
@export var depth := 1.8
@export var net_height := 2.5
@export var stadium_box := false
@export var net_meshes := PackedStringArray(["SaggingNet"])
@export var rear_poles: Array[Vector3] = []
