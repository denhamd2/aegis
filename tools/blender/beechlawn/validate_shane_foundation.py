"""Validate the actual Blender source, rig preservation and offline pose probes.

Run with blender -b --python tools/blender/beechlawn/validate_shane_foundation.py.
This structural check is complemented by rendered visual review, not a likeness
score or a replacement for gameplay/Mac validation.
"""
from pathlib import Path
import hashlib
import json
import struct
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BLEND = ROOT / "tools/blender/beechlawn/shane_denham_08.blend"
SOURCE = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
GLB = ROOT / "games/beechlawn_rovers/assets/characters/_prototypes/shane_denham_08_prototype.glb"
OUT = ROOT / "games/beechlawn_rovers/docs/art_briefs/br022_shane_foundation_validation.json"
bpy.ops.wm.open_mainfile(filepath=str(BLEND))
rig = bpy.data.objects["YBot_Armature"]
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
actions = {a.name: a for a in bpy.data.actions}
retarget=json.loads((OUT.parent/"br022_shane_leg_retarget.json").read_text())
leg_paths={'pose.bones["'+name+'"].rotation_quaternion' for name in retarget['changed_rotation_bones']}


def action_hash(action):
    values = [(f.data_path, f.array_index,
               [(tuple(p.co), tuple(p.handle_left), tuple(p.handle_right), p.interpolation)
                for p in f.keyframe_points]) for f in action.fcurves if f.data_path not in leg_paths]
    return hashlib.sha256(repr(values).encode()).hexdigest()


with bpy.data.libraries.load(str(SOURCE), link=False) as (source, loaded):
    action_names = tuple(source.actions)
    loaded.actions = list(action_names)
    loaded.armatures = list(source.armatures)
source_rig = loaded.armatures[0]
assert len(source_rig.bones) == len(rig.data.bones) == 65
for bone in source_rig.bones:
    current = rig.data.bones[bone.name]
    assert (current.head_local - bone.head_local).length < 1e-5
    assert (current.tail_local - bone.tail_local).length < 1e-5
    assert (current.parent.name if current.parent else None) == (bone.parent.name if bone.parent else None)
    assert max(abs(current.matrix_local[r][c] - bone.matrix_local[r][c]) for r in range(4) for c in range(4)) < 1e-5
for name, original in zip(action_names, loaded.actions):
    assert name in actions and action_hash(actions[name]) == action_hash(original), name
original_actions=dict(zip(action_names,loaded.actions))
baseline=bpy.data.objects.new("WORK_SourcePoseValidation",source_rig)
bpy.context.scene.collection.objects.link(baseline)
baseline.animation_data_create()
bpy.context.view_layer.update()
for bone in baseline.pose.bones:bone.rotation_mode='QUATERNION'

report = {"rig_bones_unchanged": 65, "animation_action_names_preserved": len(action_names),
          "all_other_animation_curves_unchanged": True,
          "retargeted_rotation_bones": retarget['changed_rotation_bones'],
          "forward": rig.get("anatomical_fit_forward"),
          "joint_fit_max_endpoint_error_cm": rig.get("anatomical_fit_max_endpoint_error_cm"),
          "meshes": {}, "pose_probes": {}}
assert report["joint_fit_max_endpoint_error_cm"] < .001
metadata = json.loads((ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_shot_contact.json").read_text())
fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
assert fps == metadata["fps"], (fps, metadata["fps"])
report["animation_source_fps"] = fps
surface = bpy.data.objects["YBot_Surface"]
surface.data.calc_loop_triangles()
kit_uv=surface.data.uv_layers.get("JerseyUV")
zero_uv=0
for triangle in surface.data.loop_triangles:
    if surface.data.materials[triangle.material_index].name!="MAT_Beechlawn_HomeKit_Atlas":
        continue
    a,b,c=[kit_uv.data[li].uv for li in triangle.loops]
    zero_uv+=int(abs((b-a).cross(c-a))<1e-10)
assert zero_uv==0, ("Undefined cloth normal-map tangents",zero_uv)
report["zero_area_kit_uv_triangles"]=zero_uv
layout=json.loads((ROOT / "games/beechlawn_rovers/assets/characters/textures/beechlawn_home_tailored_atlas_layout.json").read_text())
x0,y0,x1,y1=layout["rects"]["black"]; size=layout["size"]
chest_trim_faces=0
for polygon in surface.data.polygons:
    if surface.data.materials[polygon.material_index].name!="MAT_Beechlawn_HomeKit_Atlas":
        continue
    p=polygon.center
    if abs(p.x)<18 and 120<p.y<138 and p.z>0:
        chest_trim_faces+=int(all(x0/size<kit_uv.data[li].uv.x<x1/size and
                                 1-y1/size<kit_uv.data[li].uv.y<1-y0/size
                                 for li in polygon.loop_indices))
assert chest_trim_faces==0, ("Chest artwork incorrectly samples plain trim",chest_trim_faces)
report["printed_chest_faces_sampling_plain_trim"]=chest_trim_faces
head_material=bpy.data.objects["Skin_Head"].data.materials[0]
head_images=[n.image for n in head_material.node_tree.nodes if n.type=="TEX_IMAGE" and n.image]
assert any("shane_head_anatomical_albedo_2k" in image.name and tuple(image.size)==(2048,2048)
           for image in head_images), "Head lacks its anatomical 2K skin texture"
assert not any("face_reference" in image.name or "denham_head_albedo" in image.name
               for image in head_images), "Historical portrait atlas is attached to the face"
report["head_texture"]="2K anatomical skin from CC0 source and authored pigment; no portrait overlay"
def material_vertices(name):
    slots = {i for i, material in enumerate(surface.data.materials) if material.name == name}
    return {i for polygon in surface.data.polygons if polygon.material_index in slots for i in polygon.vertices}
pupils = material_vertices("MAT_Eye_OffWhite")  # iris is painted on the actual eye surface
boots = material_vertices("MAT_Boot_BlackLeather")
eye_front = sum(surface.data.vertices[i].co.z for i in pupils) / len(pupils)
toe_direction = rig.data.bones["mixamorig:LeftToeBase"].tail_local - rig.data.bones["mixamorig:LeftToeBase"].head_local
assert eye_front > rig.data.bones["mixamorig:Head"].head_local.z and toe_direction.z > 0
sole_y = min(surface.data.vertices[i].co.y for i in boots)
assert 0.0 <= sole_y <= .3, sole_y
report["face_and_toes_share_forward_axis"] = True
report["rest_boot_sole_height_cm"] = sole_y
for obj in meshes:
    names = {g.index: g.name for g in obj.vertex_groups}
    used = {i for p in obj.data.polygons for i in p.vertices}
    bad = 0
    maximum = 0
    for i in used:
        weights = [g.weight for g in obj.data.vertices[i].groups
                   if g.weight > 1e-7 and names[g.group] in rig.data.bones]
        bad += int(abs(sum(weights) - 1.0) > 1e-5)
        maximum = max(maximum, len(weights))
    assert bad == 0 and maximum <= 4, (obj.name, bad, maximum)
    assert obj.parent == rig and obj.matrix_parent_inverse.is_identity
    report["meshes"][obj.name] = {"used_vertices": len(used), "bad_weight_sums": bad,
                                 "max_positive_influences": maximum,
                                 "materials": len(obj.data.materials)}

# The duplicated neck boundary must remain coincident during existing clips.
head, body = bpy.data.objects["Skin_Head"], bpy.data.objects["YBot_Joints"]
head_positions = {tuple(round(c, 4) for c in v.co): v.index for v in head.data.vertices}
seam_pairs = [(head_positions[tuple(round(c, 4) for c in v.co)], v.index)
              for v in body.data.vertices if tuple(round(c, 4) for c in v.co) in head_positions]
assert len(seam_pairs) >= 8, len(seam_pairs)
report["shared_neck_boundary_vertices"] = len(seam_pairs)
def shading_normals(obj):
    values=np.zeros((len(obj.data.vertices),3),dtype=np.float64)
    for loop,normal in zip(obj.data.loops,obj.data.corner_normals):
        values[loop.vertex_index]+=normal.vector
    values/=np.maximum(np.linalg.norm(values,axis=1,keepdims=True),1e-8)
    return values
head_normals,body_normals=shading_normals(head),shading_normals(body)
angles=[float(np.degrees(np.arccos(np.clip(np.dot(head_normals[a],body_normals[b]),-1,1))))
        for a,b in seam_pairs]
assert max(angles)<1.0,("Head/body shading seam",max(angles))
report["neck_shading_normal_max_gap_degrees"]=max(angles)
group_names={g.index:g.name for g in surface.vertex_groups}
bad_short_vertices=0
kit_vertices=material_vertices("MAT_Beechlawn_HomeKit_Atlas")
for i in kit_vertices:
    v=surface.data.vertices[i]
    if not 62<=v.co.y<85:continue
    weights={group_names[g.group]:g.weight for g in v.groups}
    if weights.get("mixamorig:LeftUpLeg",0)>.6 and v.co.x<.49:bad_short_vertices+=1
    if weights.get("mixamorig:RightUpLeg",0)>.6 and v.co.x>-.49:bad_short_vertices+=1
assert bad_short_vertices==0,("Shorts crossed anatomical side in rest pose",bad_short_vertices)
report["shorts_rest_vertices_crossing_anatomical_side"]=bad_short_vertices
for name, action in actions.items():
    for actor in (rig,baseline):
        actor.animation_data.action=None
        for bone in actor.pose.bones:
            bone.location=(0,0,0);bone.rotation_mode='QUATERNION';bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
    rig.animation_data.action = action
    baseline.animation_data.action=original_actions[name]
    lo, hi = action.frame_range
    probes = []
    for frame in sorted({int(lo), int((lo + hi) * .5), int(hi)}):
        bpy.context.scene.frame_set(frame)
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = {}
        for obj in meshes:
            e = obj.evaluated_get(graph)
            data = e.to_mesh()
            coords = np.empty(len(data.vertices) * 3, dtype=np.float32)
            data.vertices.foreach_get("co", coords)
            coords = coords.reshape((-1, 3))
            assert np.isfinite(coords).all() and np.max(np.abs(coords)) < 1000.0
            evaluated[obj.name] = coords.copy()
            e.to_mesh_clear()
        seam = max(float(np.linalg.norm(evaluated[head.name][a] - evaluated[body.name][b]))
                   for a, b in seam_pairs)
        assert seam < .001, (name, frame, seam)
        joint_error=max((rig.pose.bones[n].matrix.translation-baseline.pose.bones[n].matrix.translation).length
                        for n in retarget['changed_rotation_bones'])
        assert joint_error<.025,(name,frame,"Retarget changed contact path",joint_error)
        probes.append({"frame": frame, "neck_gap_cm": seam,
                       "retarget_joint_path_error_cm": joint_error,
                       "body_bounds_cm": np.stack((evaluated[body.name].min(axis=0),
                                                   evaluated[body.name].max(axis=0))).round(4).tolist()})
    report["pose_probes"][name] = probes

data = GLB.read_bytes()
size = struct.unpack_from("<I", data, 12)[0]
gltf = json.loads(data[20:20+size])
hair=next(m for m in gltf["materials"] if m["name"]=="MAT_Hair_ShortBrown")
assert hair.get("alphaMode")=="MASK", "Hair cards must export with alpha testing, not blended sorting"
report["hair_alpha_mode"]=hair["alphaMode"]
triangles = sum(gltf["accessors"][p["indices"]]["count"] // 3
                for m in gltf["meshes"] for p in m["primitives"])
skin = next(m for m in gltf["materials"] if m["name"] == "MAT_Skin_FairNatural")
assert ("baseColorTexture" in skin["pbrMetallicRoughness"] or
        "baseColorFactor" in skin["pbrMetallicRoughness"]), "Skin exports without pigment"
report["exported_animation_durations_seconds"] = {}
for animation in gltf["animations"]:
    name = animation["name"]
    if name not in actions:
        continue
    accessors = [gltf["accessors"][s["input"]] for s in animation["samplers"]]
    actual = max(a["max"][0] for a in accessors) - min(a["min"][0] for a in accessors)
    expected = float(actions[name].frame_range[1] - actions[name].frame_range[0]) / fps
    assert abs(actual - expected) < 1.01 / fps, (name, actual, expected)
    report["exported_animation_durations_seconds"][name] = actual
report["export"] = {"triangles": triangles,
                    "material_surfaces": sum(len(m["primitives"]) for m in gltf["meshes"]),
                    "explicit_skin_base_color": skin["pbrMetallicRoughness"].get("baseColorFactor",[1,1,1,1]),
                    "baked_skin_texture": "baseColorTexture" in skin["pbrMetallicRoughness"]}
report["export"]["sha256"] = hashlib.sha256(data).hexdigest()
report["limitations"] = ["Facial likeness and hair still require visual approval against the sheets",
                          "Garment coverage requires full-clip and gameplay review, beyond sparse pose probes",
                          "No M1 frame-time claim", "Pose probes test structure; renders test appearance"]
OUT.write_text(json.dumps(report, indent=2) + "\n")
print("SHANE_FOUNDATION_VALIDATION", report["export"], "actions", len(report["pose_probes"]),
      "weight_sums", "PASS", "shared_neck_boundary", len(seam_pairs), "rig_preservation", "PASS")
