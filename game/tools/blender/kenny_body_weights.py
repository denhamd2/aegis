"""Kenny's own body: Cody's supplied model with the hip skin weights smoothed.

    /tmp/claude-0/bpyenv/bin/python game/tools/blender/kenny_body_weights.py
    (or: blender -b --python game/tools/blender/kenny_body_weights.py)

The owner (12 Nov): "I want Kenny to have his own model and not have a
dependency on Cody's." kenny_body.glb is that model. Cody's file is only the
build input here; the game loads kenny_body.glb and nothing of Cody's.

Why the weights: in the parity review's high kicks (front kick, clinch knee,
flying knee, side kick) the tights at the hip ballooned into a fan wider than
the hips at ~90 degrees of hip flexion. Measured on the supplied mesh, the
thigh band is all thigh (pelvis 0.3%), and the pelvis-to-thigh blend happens
over only ~0.2 m (z 0.80-1.00: pelvis 21% -> 41%). A short, steep blend is
what folds and balloons under a large bend. Smoothing the pelvis/thigh groups
over the hip band spreads that blend so the cloth bends over a longer arc.
Only vertices in the band, below the waist and away from the hands, change.

Deterministic: same input, same output.
"""
import os
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "characters", "cody_rhodes.glb")
OUT = os.environ.get("KENNY_BODY_OUT", os.path.join(ROOT, "assets", "characters", "kenny_body.glb"))

# The hip band (Blender world z, metres): the crotch to the belt line.
BAND = (0.74, 1.02)
GROUPS = ("pelvis", "thigh_l", "thigh_r")
SMOOTH_FACTOR = 0.5
SMOOTH_REPEAT = 12


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    body = bpy.data.objects.get("Body")
    if body is None:
        raise RuntimeError("no Body mesh in " + SRC)
    mw = body.matrix_world
    names = {g.name for g in body.vertex_groups}
    for g in GROUPS:
        if g not in names:
            raise RuntimeError("Body has no vertex group " + g)
    # Select only the hip band, away from the hands (which hang at this height).
    hand_groups = {g.index for g in body.vertex_groups if "hand" in g.name or "finger" in g.name
                   or "thumb" in g.name or "index" in g.name or "middle" in g.name
                   or "ring" in g.name or "pinky" in g.name or "lowerarm" in g.name}
    picked = 0
    for v in body.data.vertices:
        z = (mw @ v.co).z
        on_hand = any(e.group in hand_groups and e.weight > 0.01 for e in v.groups)
        v.select = BAND[0] < z < BAND[1] and not on_hand
        picked += v.select
    print("kenny_body_weights: %d vertices in the hip band" % picked)
    bpy.context.view_layer.objects.active = body
    for ob in bpy.context.view_layer.objects:
        ob.select_set(ob == body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    body.data.use_paint_mask_vertex = True
    for g in GROUPS:
        body.vertex_groups.active_index = body.vertex_groups[g].index
        bpy.ops.object.vertex_group_smooth(group_select_mode="ACTIVE",
                                           factor=SMOOTH_FACTOR, repeat=SMOOTH_REPEAT, expand=0.0)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_skins=True,
                              export_animations=False, export_morph=True,
                              export_yup=True, export_apply=False)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
