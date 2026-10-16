extends "res://tools/probe/clip_shot.gd"
func _light() -> void:
 super._light()
 var model := find_child("RomanModel",true,false) as RomanModel
 if model:
  model.aim_eyes(func(): return Vector3(0,1.72,10))
