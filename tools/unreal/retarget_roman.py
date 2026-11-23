"""Retarget the base rig's clips onto Roman's body and clothes, in the Unreal port.

Run inside the UE 5.9 editor of the port project (Tools > Execute Python
Script, or the editor MCP's execute_python). Idempotent.

Why this exists: in the first retarget Roman's hips stayed at bind height
(101.2) in every clip -- lying, bumping or thrown, he floated about a metre off
the canvas while the base rig's pelvis went down to 17.5. The same class of bug
as the Godot README's "Is anybody floating?". Three things in the retarget
setup each kept the hips from moving, and this script fixes all of them:

1. No IK rig had a retarget root, so the Pelvis Motion op had no bone to drive.
   Each rig's retarget root is now its hip bone.
2. Each rig's Spine chain started AT the hip bone, with FK translation mode
   NONE. The FK Chains op runs after Pelvis Motion, so it put the hips straight
   back to the retarget pose. Spine now starts one bone up (spine_01 / J_Spine1).
3. The Root Motion op wrote over J_Hips, which is the root of the body
   skeleton. The port moves the actor itself and plays clips in place, so that
   op is disabled.

Measured on Down_Supine at mid-clip with AnimPose (world space): base pelvis
17.5 -> Roman 19.3 (body and clothes), and Idle_Loop 87.0 -> 96.0. Roman's hips
sit about 10% higher than the base rig's, and Pelvis Motion scales the motion
by that ratio.

Each call handles a slice so no single editor call runs long. To choose what
runs, set these globals before the script body (the MCP runner prepends them):
    ONLY = ["Down_Supine"]     # just these clips (default: all)
    DEST_SUFFIX = "_Test"      # write to RomanRetarget_Test etc. instead
    START, COUNT = 0, 60       # slice of the sorted clip list
"""
import json

import unreal

SRC_DIR = "/Game/AegisTest/AllRig/wrestler_base_with_clips/SkeletalMeshes"
RIG_DIR = "/Game/AegisTest/Retarget"
RIGS = {  # IK rig -> (retarget root / hip bone, first spine bone above it)
    "IK_AegisBase": ("pelvis", "spine_01"),
    "IK_Roman": ("J_Hips_67ba20366b8ebad6c488009f6ec2f619", "J_Spine1_bf6fcaa773aa545a376928d6f271d6a0"),
    "IK_RomanClothes": ("J_Hips", "J_Spine1"),
}
SOURCE_RIG = "IK_AegisBase"
TARGETS = [  # (retargeter, target IK rig, destination folder)
    ("RTG_AegisToRoman", "IK_Roman", "/Game/AegisTest/RomanRetarget"),
    ("RTG_AegisToClothes", "IK_RomanClothes", "/Game/AegisTest/RomanClothesRetarget"),
]

ONLY = globals().get("ONLY")
DEST_SUFFIX = globals().get("DEST_SUFFIX", "")
START = globals().get("START", 0)
COUNT = globals().get("COUNT", 100000)


def fix_rigs():
    changed = []
    for rig_name, (hips, spine) in RIGS.items():
        rig = unreal.load_asset(RIG_DIR + "/" + rig_name)
        rc = unreal.IKRigController.get_controller(rig)
        dirty = False
        if str(rc.get_retarget_root()) != hips:
            if not rc.set_retarget_root(hips):
                raise RuntimeError("could not set %s retarget root to %s" % (rig_name, hips))
            dirty = True
        if str(rc.get_retarget_chain_start_bone("Spine")) != spine:
            if not rc.set_retarget_chain_start_bone("Spine", spine):
                raise RuntimeError("could not start %s Spine chain at %s" % (rig_name, spine))
            dirty = True
        if dirty:
            unreal.EditorAssetLibrary.save_loaded_asset(rig)
            changed.append(rig_name)
    return changed


def fix_retargeter(rtg_name, target_rig):
    rtg = unreal.load_asset(RIG_DIR + "/" + rtg_name)
    c = unreal.IKRetargeterController.get_controller(rtg)
    root_motion = c.get_index_of_op_by_name("Root Motion")
    if root_motion >= 0 and c.get_retarget_op_enabled(root_motion):
        c.set_retarget_op_enabled(root_motion, False)
    pelvis = c.get_op_controller(c.get_index_of_op_by_name("Pelvis Motion"))
    s = pelvis.get_settings()
    for prop, bone in [("source_pelvis_bone", RIGS[SOURCE_RIG][0]), ("target_pelvis_bone", RIGS[target_rig][0])]:
        ref = unreal.BoneReference()
        ref.set_editor_property("bone_name", bone)
        s.set_editor_property(prop, ref)
    pelvis.set_settings(s)
    for i in range(c.get_num_retarget_ops()):
        c.run_op_initial_setup(i)
    unreal.EditorAssetLibrary.save_loaded_asset(rtg)
    return rtg


def source_clips():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    clips = [a for a in ar.get_assets_by_path(SRC_DIR, recursive=True)
             if str(a.asset_class_path.asset_name) == "AnimSequence"]
    clips.sort(key=lambda a: str(a.asset_name))
    if ONLY:
        clips = [a for a in clips if str(a.asset_name) in ONLY]
    return clips[START:START + COUNT]


def hips_z(path, bone):
    """World-space hips height at mid-clip (AnimPose, not the local track)."""
    anim = unreal.load_asset(path)
    if not anim:
        return None
    pose = unreal.AnimPoseExtensions.get_anim_pose_at_time(
        anim, anim.get_play_length() / 2, unreal.AnimPoseEvaluationOptions())
    return round(unreal.AnimPoseExtensions.get_bone_pose(pose, bone, unreal.AnimPoseSpaces.WORLD).translation.z, 1)


rigs_changed = fix_rigs()
clips = source_clips()
source_mesh = unreal.load_asset(SRC_DIR + "/Mannequin_root")
report = {"rigs_changed": rigs_changed, "clips": len(clips), "targets": {}}
for rtg_name, rig_name, dest in TARGETS:
    rtg = fix_retargeter(rtg_name, rig_name)
    target_mesh = unreal.IKRigController.get_controller(unreal.load_asset(RIG_DIR + "/" + rig_name)).get_skeletal_mesh()
    out_dir = dest + DEST_SUFFIX
    # The batch operation does not overwrite: given an existing clip it writes
    # "<name>1" beside it, and the game loads clips by their plain name. So
    # clear each destination clip first, which keeps the script idempotent.
    for a in clips:
        old = out_dir + "/" + str(a.asset_name)
        if unreal.EditorAssetLibrary.does_asset_exist(old):
            unreal.EditorAssetLibrary.delete_asset(old)
    done = unreal.IKRetargetBatchOperation.duplicate_and_retarget(
        clips, source_mesh, target_mesh, rtg,
        target_path=out_dir, include_referenced_assets=False, overwrite_existing_files=True)
    for a in done:
        unreal.EditorAssetLibrary.save_asset(str(a.package_name), only_if_is_dirty=False)
    hips = RIGS[rig_name][0]
    report["targets"][rtg_name] = {
        "written": len(done), "dest": out_dir,
        "down_supine_hips_z": hips_z(out_dir + "/Down_Supine", hips),
        "idle_hips_z": hips_z(out_dir + "/Idle_Loop", hips),
    }
json.dumps(report)
