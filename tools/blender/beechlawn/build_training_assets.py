"""Build original Beechlawn Rovers blockout assets in Blender.

Run from the repository root with:
  blender --background --python tools/blender/beechlawn/build_training_assets.py

The geometry follows the supplied goal/ball reference sheets. All meshes and
materials are generated here, so the .blend remains editable and the GLBs are
self-contained for Godot.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
GAME = os.path.join(ROOT, "games/beechlawn_rovers")
SOURCE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.join(GAME, "assets/environment")
os.makedirs(SOURCE_DIR, exist_ok=True)
os.makedirs(ENV_DIR, exist_ok=True)

def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.collections:
        if block.name != "Collection":
            bpy.data.collections.remove(block)
    root = bpy.context.scene.collection
    for child in list(root.children):
        root.children.unlink(child)
    return root

def collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll

def move_to(obj, coll):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    coll.objects.link(obj)
    return obj

def material(name, color, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat

def rod_between(name, start, end, radius, mat, coll, vertices=10):
    a, b = Vector(start), Vector(end)
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
        depth=delta.length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.data.materials.append(mat)
    return move_to(obj, coll)

def make_goal():
    coll = collection("Goal_7.32m_NoStanchions")
    white = material("Painted steel - worn off-white", (0.78, 0.78, 0.72), 0.42, 0.22)
    net = material("Knotted nylon net", (0.68, 0.70, 0.66), 0.92)
    # Width and height are the clear playing opening (IFAB dimensions). The
    # post centers sit one radius outside that opening; the goal has no rear
    # stanchions or separate support legs.
    width, height, depth = 7.32, 2.44, 1.8
    post_radius = 0.061
    frame_half_width = width * 0.5 + post_radius
    clear_top = height
    frame_top = height + post_radius
    # Blender Z is vertical. Goal mouth faces toward -Y; the rear net reaches +Y.
    for x in (-frame_half_width, frame_half_width):
        rod_between("Goalpost", (x, 0, 0), (x, 0, frame_top), post_radius, white, coll, 16)
        rod_between("Net side rail", (x, 0, 0), (x, depth, 0), 0.026, white, coll, 8)
        rod_between("Net roof rail", (x, 0, clear_top), (x, depth, clear_top), 0.026, white, coll, 8)
    rod_between("Crossbar", (-frame_half_width, 0, frame_top), (frame_half_width, 0, frame_top), post_radius, white, coll, 16)
    rod_between("Rear ground rail", (-frame_half_width, depth, 0), (frame_half_width, depth, 0), 0.025, white, coll, 8)
    rod_between("Rear roof rail", (-frame_half_width, depth, clear_top), (frame_half_width, depth, clear_top), 0.025, white, coll, 8)
    spacing = 0.32
    # Fine static nylon lines give a clear net silhouette without a deform rig.
    ix = int((frame_half_width * 2.0) / spacing)
    iz = int(height / spacing)
    for i in range(ix + 1):
        x = -frame_half_width + frame_half_width * 2.0 * i / ix
        rod_between("Net rear vertical", (x, depth, 0), (x, depth, clear_top), 0.009, net, coll, 6)
        rod_between("Net roof cross-thread", (x, 0, clear_top), (x, depth, clear_top), 0.009, net, coll, 6)
    for j in range(iz + 1):
        z = clear_top * j / iz
        rod_between("Net rear horizontal", (-frame_half_width, depth, z), (frame_half_width, depth, z), 0.009, net, coll, 6)
        rod_between("Net side thread L", (-frame_half_width, 0, z), (-frame_half_width, depth, z), 0.009, net, coll, 6)
        rod_between("Net side thread R", (frame_half_width, 0, z), (frame_half_width, depth, z), 0.009, net, coll, 6)
    for i in range(ix + 1):
        x = -frame_half_width + frame_half_width * 2.0 * i / ix
        rod_between("Net floor cross-thread", (x, 0, 0), (x, depth, 0), 0.009, net, coll, 6)
    return coll

def make_ball_texture():
    # Equirectangular grunge map: off-white, scuffed panels, dark/red graphics,
    # and thin seam lines. The texture is intentionally subdued like a used ball.
    w, h = 1024, 512
    image = bpy.data.images.new("Beechlawn_Ball_Worn_Albedo", width=w, height=h, alpha=True)
    pixels = [0.0] * (w*h*4)
    for y in range(h):
        v = y / h
        for x in range(w):
            u = x / w
            n = (math.sin(x*0.091 + y*0.037) + math.sin(x*0.027 - y*0.13) + math.sin(y*0.41 + x*0.006)) / 6.0
            grime = max(0.0, math.sin(x*0.041 + y*0.057) * math.sin(y*0.083-x*0.021))
            base = 0.79 + n*0.08 - grime*0.13
            # Repeating six-sided panel-like color marks; panel seams remain fine.
            cell_u = (u * 8.0) % 1.0
            cell_v = (v * 4.0) % 1.0
            edge = min(cell_u, 1-cell_u, cell_v, 1-cell_v)
            seam = edge < 0.012
            graphic = ((0.18 < cell_u < 0.50 and abs(cell_v-0.5) < (cell_u-0.12)*0.80)
                or (0.55 < cell_u < 0.88 and abs(cell_v-0.5) < (0.88-cell_u)*0.72))
            phase = (int(u*8) + int(v*4)) % 3
            if graphic and phase == 0:
                rgb = (0.12,0.13,0.14)
            elif graphic and phase == 1:
                rgb = (0.48,0.10,0.12)
            elif seam:
                rgb = (0.35,0.34,0.31)
            else:
                rgb = (base, base*0.98, base*0.92)
            # Tiny stains and black rubber abrasion, distributed deterministically.
            stain = max(0.0, math.sin(x*0.17+y*0.29)*math.sin(y*0.23-x*0.11)-0.88)
            rgb = tuple(max(0.015, c - stain*0.34) for c in rgb)
            idx = (y*w+x)*4
            pixels[idx:idx+4] = [rgb[0],rgb[1],rgb[2],1.0]
    image.pixels.foreach_set(pixels)
    image.pack()
    return image

def make_ball():
    coll = collection("Used_Size5_Football")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=0.11, location=(0,0,0))
    obj = move_to(bpy.context.object, coll)
    obj.name = "Match ball - 220mm"
    bpy.ops.object.shade_smooth()
    image = make_ball_texture()
    mat = bpy.data.materials.new("Worn match ball - scuffed printed panels")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.8
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.append(mat)
    return coll

def export_collection(coll, path):
    bpy.ops.object.select_all(action="DESELECT")
    objects = list(coll.objects)
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    # Merge static rods into one mesh before export; preserve the separate
    # frame/net materials as glTF primitives to keep draw calls low.
    if len(objects) > 1:
        bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False,
        export_lights=False)

def main():
    reset_scene()
    goal = make_goal()
    ball = make_ball()
    # Organize the source file for an artist to open and revise.
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "beechlawn_training_assets.blend"))
    export_collection(goal, os.path.join(ENV_DIR, "football_goal.glb"))
    export_collection(ball, os.path.join(ENV_DIR, "football_ball.glb"))
    print("Beechlawn assets built:", len(goal.objects), "goal objects;", len(ball.objects), "ball object")

if __name__ == "__main__":
    main()
