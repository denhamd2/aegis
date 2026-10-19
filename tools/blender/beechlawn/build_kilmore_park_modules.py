"""Build reusable, original Kilmore Drive park backdrop modules for Beechlawn.

Run from repo root:
  blender -b --python tools/blender/beechlawn/build_kilmore_park_modules.py

The modules are intentionally low-cost and camera-facing: local residential
house facade, public-park tree, parked hatchback and weathered wall segment.
They use original geometry/materials and export as GLB for Godot instancing.
"""

from pathlib import Path
import bpy
import math
import random
import sys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "games/beechlawn_rovers/assets/environment/kilmore"
SRC = ROOT / "tools/blender/beechlawn/kilmore_park_modules.blend"
OUT.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=0.8, metallic=0.0):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


BRICK = mat("MAT_House_BrickMuted", (0.34, 0.245, 0.19), .92)
RENDER = mat("MAT_House_RenderWarm", (0.49, 0.46, 0.41), .9)
ROOF = mat("MAT_Roof_DarkTile", (0.12, 0.11, 0.10), .9)
FRAME = mat("MAT_Window_OffWhite", (0.78, 0.75, 0.66), .78)
GLASS = mat("MAT_Window_GlassBlueGrey", (0.105, 0.17, 0.19), .28)
DOOR = mat("MAT_Door_DeepGreen", (0.14, 0.20, 0.16), .78)
GUTTER = mat("MAT_Gutter_DarkPVC", (0.18, 0.19, 0.18), .6)
TRUNK = mat("MAT_Tree_Bark", (0.23, 0.16, 0.105), .95)
LEAF_A = mat("MAT_Tree_Foliage_A", (0.11, 0.20, 0.10), .98)
LEAF_B = mat("MAT_Tree_Foliage_B", (0.16, 0.24, 0.12), .98)
WALL = mat("MAT_Wall_AgedConcrete", (0.39, 0.41, 0.37), .96)
WALL_DARK = mat("MAT_Wall_DampVariation", (0.29, 0.32, 0.29), .98)
CAR_RED = mat("MAT_Car_MutedRed", (0.31, 0.095, 0.07), .38)
CAR_BLUE = mat("MAT_Car_MutedBlue", (0.12, 0.21, 0.29), .42)
CAR_SILVER = mat("MAT_Car_SilverGrey", (0.34, 0.35, 0.33), .45, .18)
CAR_WHITE = mat("MAT_Car_OffWhite", (0.53, 0.53, 0.49), .48, .12)
CAR_GLASS = mat("MAT_Car_Glass", (0.075, 0.12, 0.14), .23)
TIRE = mat("MAT_Tire_Rubber", (0.025, 0.028, 0.027), .88)
METAL = mat("MAT_Car_Trim", (0.28, 0.29, 0.27), .42, .65)


def add_surface_maps(material,kind):
    """Original tileable pigment/relief maps; no photographed backdrop planes."""
    size=256;values=[];heights=[]
    for y in range(size):
        for x in range(size):
            grain=(math.sin(x*117.13+y*43.7)*43758.54)%1
            if kind=='brick':
                row=y//32;u=(x+(row%2)*32)%64
                mortar=u<3 or y%32<3
                value=.72 if mortar else .82+grain*.2+math.sin((x//64)*4.1+row*2.8)*.1
                height=.1 if mortar else .8+grain*.1
            elif kind=='roof':
                seam=x%64<2 or y%64<3
                value=.65 if seam else .87+grain*.17+math.sin(x*.025+y*.05)*.06
                height=.15 if seam else .65+(y%64)/256
            elif kind=='bark':
                groove=.5+.5*math.sin(x*.39+math.sin(y*.027)*2)
                value=.64+groove*.5+grain*.13;height=groove*.7+grain*.05
            else:
                value=.87+grain*.2+.025*math.sin(x*.31)*math.sin(y*.023);height=grain*.18
            values.append(value);heights.append(height)
    color=material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
    image=bpy.data.images.new('Original_'+kind+'_Albedo',width=size,height=size)
    image.pixels.foreach_set([v for n in values for v in (color[0]*n,color[1]*n,color[2]*n,1)])
    image.pack();texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image
    material.node_tree.links.new(texture.outputs['Color'],material.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    normal=bpy.data.images.new('Original_'+kind+'_Normal',width=size,height=size)
    normal.colorspace_settings.name='Non-Color';pixels=[]
    for y in range(size):
        for x in range(size):
            nx=(heights[y*size+(x-1)%size]-heights[y*size+(x+1)%size])*.28
            ny=(heights[((y-1)%size)*size+x]-heights[((y+1)%size)*size+x])*.28
            n=Vector((nx,ny,1)).normalized();pixels.extend((n.x*.5+.5,n.y*.5+.5,n.z*.5+.5,1))
    normal.pixels.foreach_set(pixels);normal.pack()
    nodes=material.node_tree.nodes;links=material.node_tree.links
    tex=nodes.new('ShaderNodeTexImage');tex.image=normal;mapping=nodes.new('ShaderNodeNormalMap');mapping.inputs['Strength'].default_value=.35
    links.new(tex.outputs['Color'],mapping.inputs['Color']);links.new(mapping.outputs['Normal'],nodes['Principled BSDF'].inputs['Normal'])

for surface,kind in ((BRICK,'brick'),(RENDER,'render'),(ROOF,'roof'),(TRUNK,'bark')):
    add_surface_maps(surface,kind)


def active_collection():
    return bpy.context.collection


def make_root(name):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    active_collection().objects.link(root)
    return root


def cube_obj(name, dims, loc, material, bevel=0.0, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if material in (BRICK,RENDER,ROOF):
        layer=obj.data.uv_layers.active
        for polygon in obj.data.polygons:
            for li in polygon.loop_indices:
                p=obj.data.vertices[obj.data.loops[li].vertex_index].co
                if abs(polygon.normal.z)>.5:uv=(p.x/.65,p.y/.65)
                elif abs(polygon.normal.y)>.5:uv=(p.x/.65,p.z/.65)
                else:uv=(p.y/.65,p.z/.65)
                layer.data[li].uv=uv
    if bevel:
        bevel_mod = obj.modifiers.new("Bevel_Silhouette", "BEVEL")
        bevel_mod.width = bevel
        bevel_mod.segments = 2
        bevel_mod.profile = 0.5
        obj.modifiers.new("Weighted_Normals", "WEIGHTED_NORMAL")
    if parent:
        obj.parent = parent
    return obj


def cylinder_obj(name, radius, depth, loc, material, vertices=12, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
        end_fill_type="NGON", location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def uv_sphere(name, loc, scale, material, segments=12, rings=8, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    # Softly perturb the crown from a perfect UV sphere so the tree reads as
    # overlapping natural foliage rather than a row of geometric balls.
    for vertex in obj.data.vertices:
        direction = vertex.co.normalized()
        wobble = math.sin(direction.x * 8.1 + direction.y * 11.7) * math.sin(direction.z * 9.3 - direction.x * 3.2)
        vertex.co = direction * (1.0 + wobble * .055)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def roof_panel(name, loc, rot_x, parent):
    panel = cube_obj(name, (9.1, 4.25, .16), loc, ROOF, .035, parent)
    panel.rotation_euler.x = rot_x
    return panel


def build_house(name="SM_Kilmore_HouseFacade_A", variant=0):
    root = make_root(name)
    # 8.4 m wide × 5.2 m deep × 5.7 m high, grounded at Z=0.
    facade_material = BRICK if variant == 0 else RENDER
    gable_material = RENDER if variant == 0 else BRICK
    cube_obj("House_Facade", (8.4, 5.2, 4.35), (0, 0, 2.18), facade_material, .05, root)
    # Rendered upper gable and eaves produce a recognizable Irish suburban roof silhouette.
    verts = [(-4.22,-2.63,4.32),(4.22,-2.63,4.32),(0,-2.63,5.72),
             (-4.22,2.63,4.32),(4.22,2.63,4.32),(0,2.63,5.72)]
    faces = [(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)]
    mesh = bpy.data.meshes.new("House_GableMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(gable_material)
    gable = bpy.data.objects.new("House_Gable", mesh)
    active_collection().objects.link(gable)
    gable.parent = root
    roof_panel("Roof_Slope_Left", (0, -1.05, 4.65), math.radians(18), root)
    roof_panel("Roof_Slope_Right", (0, 1.05, 4.65), -math.radians(18), root)
    # A simple ridge and restrained tile battens break the repeated dark roof
    # plane at the distant broadcast angle without adding high-poly detail.
    cylinder_obj("Roof_Ridge", .12, 8.65, (0, 0, 5.38), GUTTER, 10, root).rotation_euler.y = math.pi / 2
    for x in (-3.2, -1.6, 0, 1.6, 3.2):
        for side in (-1, 1):
            rib = cube_obj("Roof_Tile_Rib", (.045, 4.05, .045), (x, side * .98, 4.68), GUTTER, .018, root)
            rib.rotation_euler.x = math.radians(18 if side < 0 else -18)
    # Field-facing elevation is at -Y.
    for x in (-2.55, 2.55):
        cube_obj("Window_Frame", (1.55, .13, 1.32), (x, -2.67, 2.65), FRAME, .045, root)
        cube_obj("Window_Glass", (1.28, .045, 1.05), (x, -2.75, 2.65), GLASS, .025, root)
        cube_obj("Window_Mullion_V", (.055, .035, 1.04), (x, -2.78, 2.65), FRAME, .012, root)
        cube_obj("Window_Mullion_H", (1.26, .035, .055), (x, -2.78, 2.65), FRAME, .012, root)
        cube_obj("Window_Sill", (1.72, .2, .12), (x, -2.72, 1.96), FRAME, .025, root)
    cube_obj("Front_Door", (.98, .14, 2.1), (0, -2.69, 1.07), DOOR, .035, root)
    cube_obj("Door_Light", (.32, .04, .72), (0, -2.78, 1.53), GLASS, .018, root)
    cube_obj("Doorstep", (1.35, .55, .15), (0, -2.9, .075), WALL, .035, root)
    # Eaves and downpipes break up the large facade planes.
    cube_obj("Front_Gutter", (9.2, .18, .16), (0, -2.24, 4.43), GUTTER, .04, root)
    for x in (-4.25, 4.25):
        cylinder_obj("Downpipe", .065, 4.35, (x, -2.36, 2.2), GUTTER, 10, root)
    cube_obj("Chimney", (.62, .62, 1.2), (2.9 if variant == 0 else -2.9, .8, 5.45), facade_material, .05, root)
    if variant == 1:
        # Small recessed porch gives the alternate terrace a different entry
        # silhouette while remaining a single inexpensive backdrop module.
        cube_obj("Porch_Canopy", (2.2, 1.0, .16), (0, -3.05, 2.72), ROOF, .04, root)
        for x in (-.92, .92):
            cylinder_obj("Porch_Post", .075, 2.6, (x, -3.42, 1.42), FRAME, 8, root)
        cube_obj("Porch_Step", (2.5, .55, .12), (0, -3.05, .08), WALL, .03, root)
    # Low front garden wall and two narrow posts soften the join to grass.
    cube_obj("Garden_Wall", (8.3, .16, .43), (0, -3.1, .25), WALL, .025, root)
    for x in (-3.9, -1.3, 1.3, 3.9):
        cube_obj("Garden_Wall_Pier", (.23, .25, .68), (x, -3.1, .34), FRAME, .035, root)


def build_tree():
    root = make_root("SM_Kilmore_ParkTree_A")
    # 7.5 m mature deciduous silhouette; shared canopy material, three clump sizes.
    cylinder_obj("Tree_Trunk", .28, 4.4, (0, 0, 2.2), TRUNK, 12, root)
    for loc, rot, radius in [((-.68,0,3.65),(-.18,0,.26),.14),
                             ((.62,.05,3.8),(.18,0,-.24),.13),
                             ((0,.1,4.1),(0,.1,0),.11)]:
        branch = cylinder_obj("Tree_Branch", radius, 1.9, loc, TRUNK, 9, root)
        branch.rotation_euler = rot
    add_leaf_crown(root,420,13,Vector((0,0,5.4)),Vector((2.8,2.4,2.2)))


def build_tree_sparse():
    """Open-canopy deciduous tree for the park-edge skyline variation."""
    root = make_root("SM_Kilmore_ParkTree_B")
    cylinder_obj("Tree_Trunk", .23, 5.2, (0, 0, 2.6), TRUNK, 12, root)
    for loc, rot, radius, length in [((-.48,0,4.15),(-.22,0,.33),.10,2.2),
                                    ((.55,.04,4.55),(.18,0,-.3),.10,2.5),
                                    ((0,.08,5.05),(-.12,.04,.08),.09,1.9)]:
        branch = cylinder_obj("Tree_Branch", radius, length, loc, TRUNK, 9, root)
        branch.rotation_euler = rot
    add_leaf_crown(root,220,29,Vector((0,0,5.7)),Vector((2.0,1.8,1.7)))


def add_leaf_crown(root,count,seed,centre,extent):
    """Original leaf cards on a branched crown instead of opaque canopy balls."""
    rng=random.Random(seed)
    image=bpy.data.images.get("Kilmore_OriginalLeaf_RGBA")
    if image is None:
        image=bpy.data.images.new("Kilmore_OriginalLeaf_RGBA",width=64,height=128,alpha=True)
        pixels=[]
        for y in range(128):
            v=y/127
            width=math.sin(math.pi*v)**.72*.48
            for x in range(64):
                u=x/63-.5
                inside=abs(u)<width*(.96+.04*math.sin(v*70))
                vein=math.exp(-(u/.018)**2)*.13
                shade=.83+.14*math.sin(v*29+abs(u)*26)+vein
                pixels.extend((.17*shade,.28*shade,.075*shade,1.0 if inside else 0.0))
        image.pixels.foreach_set(pixels);image.pack()
    leaf=mat("MAT_Kilmore_LeafCards",(.12,.24,.07),.9)
    nodes=leaf.node_tree.nodes;links=leaf.node_tree.links
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    cutoff=nodes.new('ShaderNodeMath');cutoff.operation='GREATER_THAN';cutoff.inputs[1].default_value=.45
    links.new(tex.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
    links.new(tex.outputs['Alpha'],cutoff.inputs[0]);links.new(cutoff.outputs[0],nodes['Principled BSDF'].inputs['Alpha'])
    leaf.surface_render_method='DITHERED'
    vertices=[];faces=[]
    for index in range(count):
        direction=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-1,1))).normalized()
        endpoint=centre+Vector((direction.x*extent.x,direction.y*extent.y,direction.z*extent.z))*rng.uniform(.5,1)
        if index%12==0:
            start=Vector((0,0,3.8));branch=cylinder_obj('Crown_Branch',.025,(endpoint-start).length,(endpoint+start)/2,TRUNK,6,root)
            branch.rotation_euler=(endpoint-start).to_track_quat('Z','Y').to_euler()
        for twig in range(8):
            p=endpoint+Vector((rng.uniform(-.32,.32),rng.uniform(-.32,.32),rng.uniform(-.28,.28)))
            n=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-.5,1))).normalized()
            along=n.cross(Vector((0,0,1)))
            if along.length<.01:along=Vector((1,0,0))
            along.normalize();across=n.cross(along).normalized()
            length=rng.uniform(.12,.23);width=length*.47
            start=len(vertices)
            vertices.extend((p-along*width-across*length,p+along*width-across*length,p+along*width+across*length,p-along*width+across*length))
            faces.append((start,start+1,start+2,start+3))
    mesh=bpy.data.meshes.new('LeafCrown');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('Tree_LeafCards',mesh);bpy.context.collection.objects.link(obj);obj.parent=root;mesh.materials.append(leaf)
    uv=mesh.uv_layers.new(name='LeafUV')
    for polygon in mesh.polygons:
        for li,coord in zip(polygon.loop_indices,((0,0),(1,0),(1,1),(0,1))):uv.data[li].uv=coord


def build_car(name="SM_Kilmore_ParkedHatchback_A", paint=CAR_RED):
    root = make_root(name)
    # Axis X is vehicle length, Y is depth, Z is vertical; front points -Y.
    cube_obj("Car_LowerBody", (4.05,1.78,.86), (0,0,.72), paint, .22, root)
    cube_obj("Car_Cabin", (2.45,1.48,.86), (-.06,.08,1.43), paint, .2, root)
    cube_obj("Car_FrontGlass", (.055,1.25,.59), (-1.27,0,1.48), CAR_GLASS, .035, root).rotation_euler.y=-.24
    cube_obj("Car_RearGlass", (.055,1.12,.55), (1.18,0,1.48), CAR_GLASS, .035, root).rotation_euler.y=.20
    for y in (-.76,.76):
        cube_obj("Car_SideGlass", (1.9,.055,.5), (0,y,1.48), CAR_GLASS, .025, root)
        cube_obj("Car_WindowPillar", (.11,.065,.62), (.1,y,1.48), paint,.015,root)
        cube_obj("Car_DoorHandle", (.18,.055,.045), (.5,y*1.2,1.05), METAL,.015,root)
        cube_obj("Car_WingMirror", (.22,.16,.13), (-.8,y*1.3,1.28),paint,.035,root)
    for x in (-1.27,1.27):
        for y in (-.8,.8):
            bpy.ops.mesh.primitive_torus_add(major_radius=.27, minor_radius=.11,
                major_segments=12, minor_segments=6, location=(x,y,.38), rotation=(math.pi/2,0,0))
            wheel = bpy.context.object
            wheel.name = "Car_Tire"
            wheel.data.materials.append(TIRE)
            wheel.parent = root
            cylinder_obj("Car_Hub", .18, .16, (x,y,.38), METAL, 12, root).rotation_euler.x = math.pi/2
    cube_obj("Car_Bumper_Front", (.12,1.75,.18), (-2.04,0,.48), GUTTER, .04, root)
    cube_obj("Car_Bumper_Rear", (.12,1.75,.18), (2.04,0,.48), GUTTER, .04, root)
    for y in (-.56,.56):
        cube_obj("Car_Headlamp", (.06,.38,.2), (-2.05,y,.88), FRAME, .045, root)


def build_wall():
    root = make_root("SM_Kilmore_BoundaryWall_4m")
    cube_obj("Wall_Main", (4.0,.32,1.62), (0,0,.81), WALL, .035, root)
    cube_obj("Wall_Cap", (4.12,.43,.13), (0,0,1.67), FRAME, .035, root)
    for x in (-1.84, -0.92, 0, .92, 1.84):
        cube_obj("Wall_WeatherPatch", (.15,.025,.5), (x,-.177,.45 + (int((x+2)*10)%3)*.1), WALL_DARK, .025, root)


def export_module(root_name, filename):
    root = bpy.data.objects[root_name]
    mesh_children = [obj for obj in root.children_recursive if obj.type == "MESH"]
    # Join retains UV layer names. Unify the material UV0 first so leaf
    # cards do not acquire the bark's empty UVMap and disappear at alpha=0.
    for obj in mesh_children:
        if obj.data.uv_layers:
            obj.data.uv_layers[0].name = "UVMap"
            obj.data.uv_layers.active_index = 0
            obj.data.uv_layers[0].active_render = True
    if len(mesh_children) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in mesh_children:
            bpy.context.view_layer.objects.active=obj
            for modifier in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        for obj in mesh_children:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = mesh_children[0]
        # Merge each module's small prop parts into one material-slotted mesh.
        # This retains the authored PBR materials while avoiding dozens of
        # separate draw objects every time Godot instances a house or car.
        bpy.ops.object.join()
        mesh_children[0].name = root_name + "_CombinedMesh"
        mesh_children[0].parent = root
    bpy.ops.object.select_all(action="DESELECT")
    selected = [root] + list(root.children_recursive)
    for obj in selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(OUT / filename), export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_animations=False)
    for obj in selected:
        obj.select_set(False)


clear_scene()
build_house()
build_house("SM_Kilmore_HouseFacade_B", 1)
build_tree()
build_tree_sparse()
build_car("SM_Kilmore_ParkedHatchback_A", CAR_RED)
build_car("SM_Kilmore_ParkedHatchback_B", CAR_BLUE)
build_car("SM_Kilmore_ParkedHatchback_C", CAR_SILVER)
build_car("SM_Kilmore_ParkedHatchback_D", CAR_WHITE)
build_wall()
export_module("SM_Kilmore_HouseFacade_A", "kilmore_house_a.glb")
export_module("SM_Kilmore_HouseFacade_B", "kilmore_house_b.glb")
export_module("SM_Kilmore_ParkTree_A", "kilmore_tree_a.glb")
export_module("SM_Kilmore_ParkTree_B", "kilmore_tree_b.glb")
export_module("SM_Kilmore_ParkedHatchback_A", "kilmore_hatchback_a.glb")
export_module("SM_Kilmore_ParkedHatchback_B", "kilmore_hatchback_b.glb")
export_module("SM_Kilmore_ParkedHatchback_C", "kilmore_hatchback_c.glb")
export_module("SM_Kilmore_ParkedHatchback_D", "kilmore_hatchback_d.glb")
export_module("SM_Kilmore_BoundaryWall_4m", "kilmore_wall_4m.glb")
# Arrange the editable source as a compact, reviewable module lineup. GLBs above
# were exported at their individual local origins for instancing in Godot.
for index, root_name in enumerate(("SM_Kilmore_HouseFacade_A", "SM_Kilmore_HouseFacade_B",
		"SM_Kilmore_ParkTree_A", "SM_Kilmore_ParkTree_B",
		"SM_Kilmore_ParkedHatchback_A", "SM_Kilmore_ParkedHatchback_B",
		"SM_Kilmore_ParkedHatchback_C", "SM_Kilmore_ParkedHatchback_D",
		"SM_Kilmore_BoundaryWall_4m")):
	bpy.data.objects[root_name].location.x = index * 10.0
# Studio preview for proportion/material review; it is excluded from all GLBs.
ground = mat("MAT_PreviewGround", (0.29, 0.32, 0.27), .98)
bpy.ops.mesh.primitive_plane_add(size=1, location=(19.5, 0.0, -0.07))
floor = bpy.context.object
floor.name = "Preview_Ground"
floor.dimensions = (98.0, 30.0, 1.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
floor.data.materials.append(ground)
world = bpy.data.worlds.new("Kilmore_ModulePreview_World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.38, .43, .48, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .48
bpy.context.scene.world = world
key_data = bpy.data.lights.new("LGT_Overcast_Key", "AREA")
key_data.energy = 2600
key_data.shape = "DISK"
key_data.size = 13
key = bpy.data.objects.new("LGT_Overcast_Key", key_data)
bpy.context.collection.objects.link(key)
key.location = (35.0, -12.0, 22.0)
key.rotation_euler = (Vector((35.0, 0.0, 2.3)) - key.location).to_track_quat("-Z", "Y").to_euler()
camera_data = bpy.data.cameras.new("CAM_Kilmore_Modules")
camera = bpy.data.objects.new("CAM_Kilmore_Modules", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (40.0, -49.0, 18.0)
camera.rotation_euler = (Vector((40.0, 0.0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.lens = 29
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 16
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "games/beechlawn_rovers/docs/art_briefs/kilmore_modules_preview.png")
if "--no-render" not in sys.argv:
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC))
print("KILMORE_EXPORTS", *(str(p) for p in sorted(OUT.glob("kilmore_*.glb"))))
