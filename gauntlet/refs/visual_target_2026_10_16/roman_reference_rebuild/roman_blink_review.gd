extends "res://tools/probe/visual_target_proofs.gd"
func _study_model(id: String) -> Node3D:
 var model := super._study_model(id)
 var lids := model.find_child("EyeLids", true, false) as EyeLids
 if lids: lids.hold(1.0)
 return model
func _render_metadata() -> Dictionary:
 var metadata := super._render_metadata()
 metadata["forced_blink_closure"] = 1.0
 return metadata
