extends SceneTree
func fingerprint(a: Animation) -> PackedByteArray:
 var data: Array = [a.length,a.loop_mode,a.step]
 for t in a.get_track_count():
  var keys: Array = []
  for k in a.track_get_key_count(t):
   keys.append([a.track_get_key_time(t,k),a.track_get_key_transition(t,k),a.track_get_key_value(t,k)])
  data.append([a.track_get_type(t),a.track_get_path(t),a.track_is_enabled(t),a.track_get_interpolation_type(t),a.track_get_interpolation_loop_wrap(t),keys])
 return var_to_bytes(data)
func _init() -> void:
 var before: AnimationLibrary=load("res://resources/animations/paired_poses.tres")
 var after: AnimationLibrary=load("/tmp/aegis-running-drop-poses.tres")
 var changed: Array=[]
 assert(before.get_animation_list()==after.get_animation_list())
 for name in before.get_animation_list():
  if fingerprint(before.get_animation(name)) != fingerprint(after.get_animation(name)):
   changed.append(name)
 print("POSE_DIFF ",changed," total ",before.get_animation_list().size())
 quit()
