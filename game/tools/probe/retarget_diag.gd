extends Node
## Prints the two rigs' hip rest transforms and, for a real Death01 key, what
## the position retarget produces -- the bone-local formula against the
## parent-frame one.
##
## Written to localise "Roman floats when he is pinned", and kept because the
## bug it found is invisible in every other instrument: bare_render shows the
## symptom, this shows which term produces it. The rest bases it prints are
## also where test_roman_model.gd's fixture numbers come from, so run this if
## either rig is ever re-exported and those constants need re-reading.
##
## Usage:
##   godot4 --headless --path game tools/probe/retarget_diag.tscn

const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const ROMAN := "res://scenes/roman_model.tscn"

func _ready() -> void:
	var base: Node = (load(BASE_RIG) as PackedScene).instantiate()
	add_child(base)
	var src: Skeleton3D = null
	for c in base.find_children("", "Skeleton3D", true, false):
		if (c as Skeleton3D).find_bone("pelvis") >= 0:
			src = c
			break
	var roman: Node = (load(ROMAN) as PackedScene).instantiate()
	add_child(roman)
	await get_tree().process_frame
	var tgt: Skeleton3D = null
	for c in roman.find_children("", "Skeleton3D", true, false):
		if (c as Skeleton3D).find_bone("J_Hips") >= 0:
			tgt = c
			break
	var si := src.find_bone("pelvis")
	var ti := tgt.find_bone("J_Hips")
	var srest := src.get_bone_rest(si)
	var trest := tgt.get_bone_rest(ti)
	print("source pelvis rest origin = ", srest.origin)
	print("target J_Hips rest origin = ", trest.origin)
	print("source parent index = ", src.get_bone_parent(si),
			"   target parent index = ", tgt.get_bone_parent(ti))
	var sq := srest.basis.get_rotation_quaternion()
	var tq := trest.basis.get_rotation_quaternion()
	print("source rest basis euler deg = ", srest.basis.get_euler() * 180.0 / PI)
	print("target rest basis euler deg = ", trest.basis.get_euler() * 180.0 / PI)
	var rot := tq * sq.inverse()
	print("rotation (target*source^-1) euler deg = ",
			Basis(rot).get_euler() * 180.0 / PI)

	# A real key: Death01's pelvis position track, sampled near the middle.
	var ap: AnimationPlayer = base.find_child("AnimationPlayer", true, false)
	var anim: Animation = ap.get_animation_library("").get_animation("Death01")
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if String(anim.track_get_path(t).get_concatenated_subnames()) != "pelvis":
			continue
		var key_v: Vector3 = anim.position_track_interpolate(t, 1.2)
		print("\nDeath01 pelvis key at 1.2s = ", key_v)
		var offset := key_v - srest.origin
		var slen := srest.origin.length()
		var scale := 1.0 if slen <= 0.0001 else trest.origin.length() / slen
		print("  offset from source rest = ", offset, "   scale = ", scale)
		print("  CURRENT  (rotate by bone rest bases) -> ",
				trest.origin + (rot * offset) * scale)
		# Parent-frame: root bone, so both parent rotations are identity.
		var sp := Quaternion.IDENTITY
		if src.get_bone_parent(si) >= 0:
			sp = src.get_bone_global_rest(src.get_bone_parent(si)).basis.get_rotation_quaternion()
		var tp := Quaternion.IDENTITY
		if tgt.get_bone_parent(ti) >= 0:
			tp = tgt.get_bone_global_rest(tgt.get_bone_parent(ti)).basis.get_rotation_quaternion()
		var world := sp * offset
		var local := tp.inverse() * world
		print("  PROPOSED (rotate by parent global rests) -> ",
				trest.origin + local * scale)
		print("  Cody (verbatim copy, known correct) pelvis y = 0.079")
		break
	get_tree().quit()
