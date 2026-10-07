class_name RomanHeadShape
extends SkeletonModifier3D
## Broadens Roman's face and thickens his neck toward the real man's build,
## on every frame, after the animation has posed the skeleton.
##
## Against the owner's side-by-side (the entrance card's close-up next to a
## broadcast still) the supplied model's head read long and narrow on a thin
## neck, where his is a broad, square face -- wide cheekbones, a heavy jaw --
## on a thick, muscular neck. The .glb is user-supplied and never hand-edited,
## so the correction is a bone scale, not a sculpt.
##
## A modifier rather than a one-off pose or rest edit because the animation
## writes each bone's pose every frame: anything set once is gone on the next
## one. SkeletonModifier3D runs after the AnimationMixer, so this multiplies
## whatever the clip posed.
##
## It is added to EVERY skeleton the model animates (RomanModel's
## _animation_skeletons): the body and head ride one, the hair and beard
## another, and scaling the head on only the first is exactly how he went
## bald once before -- the scalp swelled inside hair that did not.
##
## Scale propagates to children, so the neck's widening carries into the
## head; HEAD divides it back out so the head ends at its own factor.

## Local-axis factors (x across, y along the bone, z front-to-back), checked
## on a front render with clip_shot --face: x is his width.
const NECK := Vector3(1.10, 1.0, 1.07)
##
## Head width 1.05 -> 1.0 against 2K26 (RomanFaceShape): set against a
## broadcast still, the wider head read round and puffy beside 2K26's long,
## lean face; the cheekbones and jaw that made it broad are sculpted now.
const HEAD := Vector3(1.0, 1.0, 1.02)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var neck := skeleton.find_bone("J_Neck")
	var head := skeleton.find_bone("J_Head")
	if neck >= 0:
		skeleton.set_bone_pose_scale(neck, skeleton.get_bone_pose_scale(neck) * NECK)
	if head >= 0:
		var own := HEAD / (NECK if neck >= 0 else Vector3.ONE)
		skeleton.set_bone_pose_scale(head, skeleton.get_bone_pose_scale(head) * own)
