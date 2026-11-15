extends SceneTree
func _initialize() -> void:
 var model=load("res://scenes/kenny_model.tscn").instantiate()
 root.add_child(model)
 await process_frame
 var player=model.get_node("AnimationPlayer")
 var sk=model.get_game_skeleton()
 var head=sk.find_bone("Head")
 for clip in ["Idle", "A_TPose"]:
  if not player.has_animation(clip):
   print("POSE_MISSING ",clip)
   continue
  player.play(clip);player.seek(player.get_animation(clip).length*.3,true);player.pause()
  await process_frame
  sk.force_update_all_bone_transforms()
  var delta=sk.get_bone_global_pose(head)*sk.get_bone_global_rest(head).affine_inverse()
  print("HEAD_POSE ",clip," degrees=",delta.basis.get_euler()*180.0/PI," forward=",delta.basis*Vector3.FORWARD)
 model.free()
 quit()
