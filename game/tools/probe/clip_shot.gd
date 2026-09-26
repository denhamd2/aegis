extends Node
## Renders frames of a named clip straight off an animation glb.
##
## The migration to Blender-authored clips (tools/blender/wrestling_clips.py)
## needs a way to LOOK at a clip without routing it through a match: the
## existing shot probes all reach a pose by driving the FSM, which cannot
## reach a celebration at all and reaches a strike only at the frame the
## match happens to pick. This plays the clip directly and grabs a strip of
## frames across it, which is the contact sheet the animation-quality-gate
## discipline wants.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 900x900 tools/probe/clip_shot.tscn -- \
##       --glb res://assets/animations/wrestling_clips.glb \
##       --clips Win_Celebrate,Strike_Forearm --out /tmp/clips
##   add `--hand r` (or l) for a close-up of that hand from three sides, or
##   `--face` for the face from front, three-quarter and side.

var _glb := "res://assets/animations/wrestling_clips.glb"
## The body to play the clips ON. wrestling_clips.glb ships the skeleton and
## the actions but no mesh (see drop_mesh() in tools/blender), so there is
## nothing to look at without a model -- and borrowing the library onto a
## separate rig is exactly what the game does, so reviewing it this way
## reviews the real path rather than a special case.
var _model := "res://assets/characters/wrestler_base.glb"
var _clips: Array = []
var _out := "/tmp/clips"
## Fractions through the clip to grab, so the strip covers the whole action
## regardless of its length.
var _at: Array = [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0]
## "l" or "r": frame that hand in close-up instead of the whole body, from
## three sides -- a finger or a thumb is a few pixels in the full-body views.
var _hand := ""

## Camera positions, as {name: [eye, aim]}.
##
## Two angles, because one is provably not enough: the glTF conversion turns
## the rig's Blender -Y forward into +Z in Godot, so a wrestler faces the
## front camera -- and a strike that travels forward runs straight down the
## lens axis and foreshortens to nothing. A forearm measured at
## (+0.26,-0.87,-0.41), clearly extended, rendered as a man standing still.
## Celebrations and guards read from the front; anything that travels needs
## the side.
const VIEWS := {
	"front": [Vector3(0.0, 1.35, 3.0), Vector3(0.0, 1.05, 0.0)],
	"side":  [Vector3(3.2, 1.35, 0.4), Vector3(0.0, 1.05, 0.4)],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--glb" and i + 1 < args.size():
			_glb = args[i + 1]
		elif args[i] == "--clips" and i + 1 < args.size():
			_clips = Array(args[i + 1].split(","))
		elif args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--face":
			_hand = "face"
		elif args[i] == "--hand" and i + 1 < args.size():
			_hand = args[i + 1]
		elif args[i] == "--model" and i + 1 < args.size():
			_model = args[i + 1]
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var model_packed: PackedScene = load(_model)
	if not model_packed:
		push_error("cannot load model %s" % _model)
		get_tree().quit(1)
		return
	var model: Node3D = model_packed.instantiate()
	add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if not player:
		push_error("%s has no AnimationPlayer" % _model)
		get_tree().quit(1)
		return

	# Lift the authored library off the clips glb and hand it to the model's
	# own player, which is the same move the roster models make to borrow the
	# base rig's animations.
	var clips_packed: PackedScene = load(_glb)
	if not clips_packed:
		push_error("cannot load clips %s" % _glb)
		get_tree().quit(1)
		return
	var clips: Node = clips_packed.instantiate()
	var clip_player: AnimationPlayer = clips.find_child("AnimationPlayer", true, false)
	if not clip_player:
		push_error("%s has no AnimationPlayer" % _glb)
		get_tree().quit(1)
		return
	# THROUGH the model's own adapter, never raw. The authored tracks name
	# "Armature/Skeleton3D:<bone>", which resolves on the base mannequin and on
	# nothing else: CodyModel sits under a `Source` node and RomanModel's bones
	# are named J_* entirely. Added raw, every track silently fails to resolve
	# and the player poses nothing -- so the probe rendered each roster model's
	# REST pose and labelled it with a clip name. Measured against
	# tools/probe/pose_compare.tscn, which samples the live skeleton: Cody's
	# "Idle_Ready" was his arms-down bind pose and Roman's was a flat T, while
	# the same clip through the adapter puts Cody's hands within 0.0 cm of the
	# mannequin's. Two clean-looking contact sheets, neither of them of a clip.
	for lib_name in clip_player.get_animation_library_list():
		var lib := clip_player.get_animation_library(lib_name)
		if model.has_method("adapt_animation_library"):
			lib = model.adapt_animation_library(lib)
		var target := StringName("authored")
		if player.has_animation_library(target):
			player.remove_animation_library(target)
		player.add_animation_library(target, lib)

	var names: Array = []
	for a in player.get_animation_library(&"authored").get_animation_list():
		names.append("authored/%s" % a)
	if not _clips.is_empty():
		names = []
		for c: String in _clips:
			names.append("authored/%s" % c)

	_light()
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 45.0

	for clip_name: String in names:
		if not player.has_animation(clip_name):
			push_error("no clip %s" % clip_name)
			continue
		var anim := player.get_animation(clip_name)
		# A track whose node path does not resolve is not an error in Godot --
		# it is simply ignored, and the pose that comes out is the rest pose.
		# That is how this probe shipped two contact sheets of a bind pose, so
		# it is checked rather than assumed, once per clip.
		# Resolved against the player's own root_node, which is what an
		# AnimationPlayer actually walks track paths from -- not against the
		# player's position in the tree, which is a different node and reports
		# every track broken.
		var anim_root: Node = player.get_node_or_null(player.root_node)
		var resolved := 0
		if anim_root != null:
			for track in anim.get_track_count():
				var node_path := String(anim.track_get_path(track)).split(":")[0]
				if anim_root.get_node_or_null(NodePath(node_path)) != null:
					resolved += 1
		if resolved == 0:
			push_error("%s: none of its %d tracks resolve on %s -- this would render the REST pose"
					% [clip_name, anim.get_track_count(), _model])
			continue
		print("  %s  %d/%d tracks resolve on %s"
				% [clip_name, resolved, anim.get_track_count(), _model.get_file()])
		var views: Dictionary = VIEWS if _hand == "" else ({
				"ffront": Vector3(0.0, 0.02, 0.62), "f34": Vector3(-0.42, 0.04, 0.45),
				"fside": Vector3(-0.62, 0.02, 0.0)} if _hand == "face" else {
				"hfront": Vector3(0.0, 0.05, 0.55), "hout": Vector3(0.55 * (1.0 if _hand == "l" else -1.0), 0.05, 0.1),
				"hback": Vector3(0.0, 0.1, -0.55)})
		for view_name: String in views:
			for frac: float in _at:
				player.play(clip_name)
				player.seek(anim.length * frac, true)
				player.advance(0.0)
				if _hand == "":
					var spot: Array = views[view_name]
					cam.global_position = spot[0]
					cam.look_at(spot[1], Vector3.UP)
				else:
					# The skeleton applies the seek on its own update, not here.
					await get_tree().process_frame
					var at := _hand_position(model, anim, anim_root)
					cam.global_position = at + (views[view_name] as Vector3)
					cam.look_at(at, Vector3.UP)
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var path := "%s/%s_%s_%02d.png" % [
						_out, clip_name.get_file(), view_name, int(frac * 100.0)]
				img.save_png(path)
				print("  %s  t=%.2fs" % [path, anim.length * frac])
	print("done")
	get_tree().quit(0)


## World position of the `_hand` wrist, on whichever skeleton names it (the
## mannequin's hand_r, Roman's J_Wrist_R, Cody's under his own names).
##
## Only a skeleton the clip actually drives: Roman's model carries two, and
## the one holding his clothes has J_Wrist bones that stand still.
func _hand_position(model: Node, anim: Animation, anim_root: Node) -> Vector3:
	var s := _hand.to_upper()
	var pairs: Array = [["hand_" + _hand, "middle_01_" + _hand],
			["J_Wrist_" + s, "J_MiddleF0_" + s]]
	if _hand == "face":
		# Between the head bone and the top of the neck lands on the eyes.
		pairs = [["head", "head"], ["Head", "Head"], ["J_Head", "J_Head"]]
	var driven: Array = []
	for track in anim.get_track_count():
		var node := anim_root.get_node_or_null(NodePath(
				String(anim.track_get_path(track)).split(":")[0]))
		if node is Skeleton3D and not driven.has(node):
			driven.append(node)
	if driven.is_empty():
		driven = model.find_children("*", "Skeleton3D", true, false)
	for sk: Skeleton3D in driven:
		for pair: Array in pairs:
			var i := sk.find_bone(pair[0])
			var j := sk.find_bone(pair[1])
			if i >= 0 and j >= 0:
				# Between the wrist and the knuckles: the middle of the hand.
				var at: Vector3 = sk.global_transform * ((sk.get_bone_global_pose(i).origin
						+ sk.get_bone_global_pose(j).origin) * 0.5)
				return at + (Vector3.UP * 0.09 if _hand == "face" else Vector3.ZERO)
	return Vector3(0.0, 1.2, 0.0)


func _light() -> void:
	var key := DirectionalLight3D.new()
	key.global_transform = Transform3D().looking_at(Vector3(-0.6, -1.0, -0.8), Vector3.UP)
	key.light_energy = 2.0
	add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
