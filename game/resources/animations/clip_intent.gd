class_name ClipIntent
extends RefCounted
## What each authored clip is MEANT to do, where that can be checked
## (PoseLint). Kept beside the clips it describes and read by
## tests/test_pose_lint.gd.
##
## LEAN: clip -> [fraction through the clip, "forward" | "back"]. The torso
## must lean that way by at least PoseLint.LEAN_MIN_DEG at that point. Every
## entry here is a clip that has at some point shipped leaning the wrong way:
## the tie-up, the grapple holds and the knee to the gut as backbends, and the
## stance reclined off its front foot (see the notes in wrestling_clips.py).
## Add a clip here whenever its lean is part of what it is.
const LEAN := {
	"Idle_Ready": [0.0, "forward"],
	"Tie_Up_Collar": [0.33, "forward"],
	"Grapple_Hold_Neutral": [0.33, "forward"],
	"Grapple_Hold_Attacker": [0.33, "forward"],
	"Grapple_Hold_Defender": [0.33, "forward"],
	"Move_Exec_Impact": [0.0, "forward"],
	# Dragging his head down, frame 8 of 30.
	"Clinch_Knee_Attacker": [0.27, "forward"],
	# Folding round the knee as it lands, frame 18 of 30.
	"Clinch_Knee_Defender": [0.6, "forward"],
}

## Clips authored in world space against a floor that is not the mat
## (wrestling_clips.py's _world_clip: steps, apron, rolling in and out, the
## tope to the floor). Their feet go below y = 0 by design, so PoseLint's
## below_mat check skips them; every other check still applies.
const OFF_MAT := ["Climb_Steps", "Rope_Step_Through", "Rope_Step_Through_Apron",
	"Apron_Step", "Roll_Out_Ropes", "Tope_Attacker", "Roll_In", "Apron_Climb",
	"Springboard_DK_Attacker", "Rope_Rebound"]

## A half of a two-man move. The pair's root trajectory places and lifts
## these at play time (GrappleRig), so their bodies cannot be judged against
## the mat alone -- a man mid-throw sits "below" it until the trajectory puts
## him in the air. The pair check (test_paired_poses.gd) judges them in
## place; PoseLint still checks their joints.
static func is_paired(clip: String) -> bool:
	return clip.ends_with("_Attacker") or clip.ends_with("_Defender")


## Clips allowed to break a PoseLint pose check, and why. Empty is the goal;
## an entry is a known, accepted exception, not a place to hide a defect.
const EXEMPT := {}
