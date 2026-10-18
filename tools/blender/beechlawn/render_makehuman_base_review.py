"""Preview the CC0 MakeHuman base against the player scale before rigging."""
from pathlib import Path
import bpy
import math
from mathutils import Vector

OBJ = Path(__file__).resolve().parents[3] / "games/beechlawn_rovers/references/third_party/makehuman/base.obj"
OUT = Path(__file__).resolve().parents[3] / "games/beechlawn_rovers/docs/art_briefs/makehuman_base_comparison.png"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
raw_vertices, raw_uvs, body_faces = [], [], []
group = ""
for line in OBJ.read_text().splitlines():
    if line.startswith("v "):
        raw_vertices.append(tuple(float(value) for value in line.split()[1:4]))
    elif line.startswith("vt "):
        raw_uvs.append(tuple(float(value) for value in line.split()[1:3]))
    elif line.startswith("g "):
        group = line.split(maxsplit=1)[1]
    elif line.startswith("f ") and group == "body":
        corners = []
        for token in line.split()[1:]:
            indices = token.split("/")
            corners.append((int(indices[0]) - 1, int(indices[1]) - 1 if len(indices) > 1 and indices[1] else 0))
        body_faces.append(corners)
used = sorted({v for face in body_faces for v, _uv in face})
remap = {old: new for new, old in enumerate(used)}
vertices = [(raw_vertices[i][0] * 10.6,
             raw_vertices[i][1] * 10.6 + 89.5,
             (raw_vertices[i][2] - 1.0765) * 10.6) for i in used]
faces = [[remap[v] for v, _uv in face] for face in body_faces]
mesh = bpy.data.meshes.new("MakeHuman_CC0_BodyOnly")
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name="UVMap")
for poly, corners in zip(mesh.polygons, body_faces):
    for loop_index, (_vertex_index, uv_index) in zip(poly.loop_indices, corners):
        uv.data[loop_index].uv = raw_uvs[uv_index]
body = bpy.data.objects.new("MakeHuman_CC0_BodyOnly", mesh)
bpy.context.collection.objects.link(body)
body.select_set(True)
bpy.context.view_layer.objects.active = body
for vertex in body.data.vertices:
    pass
body.rotation_euler.x = math.pi * .5
body.scale = (.01, .01, .01)  # centimetre-space authoring to metre-space review
for polygon in body.data.polygons:
    polygon.use_smooth = True
mat = bpy.data.materials.new("NeutralSkinPreview")
mat.diffuse_color = (.45, .28, .22, 1)
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.45, .28, .22, 1)
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .72
body.data.materials.clear()
body.data.materials.append(mat)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x, scene.render.resolution_y = 600, 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.eevee.taa_render_samples = 8
scene.world = bpy.data.worlds.new("BasePreviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.32, .36, .42, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55

def area(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0, 0, .92)) - light.location).to_track_quat("-Z", "Y").to_euler()

area("Key", (2.2, 3.3, 3.6), 450, 3.0, (1.0, .88, .76))
area("Fill", (-2.8, 2.2, 2.2), 260, 3.5, (.73, .83, 1.0))
area("Rim", (.5, -2.5, 3.1), 380, 2.6, (1.0, 1.0, 1.0))
bpy.ops.object.camera_add(location=(0, -4.7, 1.65))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, .92)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 68
scene.camera = camera
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.015))
bpy.context.object.name = "ReviewGround"
bpy.context.object.data.materials.append(mat)
scene.render.filepath = str(OUT)
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
