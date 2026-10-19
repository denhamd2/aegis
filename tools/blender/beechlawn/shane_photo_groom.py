"""Original short brown groom: close roots, curved clumps and tapered fibres.

Author offline for Shane's individual head, retaining the common head weights.
The cap is only a dark root layer; visible volume comes from curved geometry.
"""
import math
import random
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def build_groom(head, rig, texture_directory):
    from shane_player_finish import bound_mesh
    texture_directory.mkdir(parents=True, exist_ok=True)
    rng = random.Random(69012)
    # Own material and atlas: a character groom must not change the shared hair.
    mat = bpy.data.materials.new("MAT_Hair_Shane_PhotoCrop")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .80
    bsdf.inputs["Specular IOR Level"].default_value = .12
    width, height = 1024, 512
    atlas = np.zeros((height, width, 4), dtype=np.float32)
    # Opaque root strip at the bottom of the atlas; the rest is 16 tapered tufts.
    noise = np.random.default_rng(69012)
    for y in range(400, height):
        for x in range(width):
            grain = .8 + .18*math.sin(x*1.91+y*.41) + noise.uniform(-.045,.045)
            atlas[y,x,:3] = np.array([.049,.025,.012])*grain
            atlas[y,x,3] = 1
    for slot in range(16):
        for strand in range(11):
            root = 5 + strand*5.2 + rng.uniform(-1,1)
            reach = rng.uniform(.60,1.0)
            tone = rng.uniform(.72,1.35)
            curve = rng.uniform(-3.2,3.2)
            for y in range(int(380*reach)):
                t = y/380
                centre = slot*64 + root + curve*t*t + math.sin(t*6+strand)*.42
                radius = (.65+.28*(1-t))*min(1,max(0,(reach-t)*35))
                for x in range(max(slot*64,int(centre-2)),min((slot+1)*64,int(centre+3))):
                    opacity = max(0,min(1,radius+.5-abs(x-centre)))
                    if opacity > atlas[y,x,3]:
                        atlas[y,x,:3] = np.array([.070,.036,.017])*tone
                        atlas[y,x,3] = opacity
    image = bpy.data.images.new("shane_photo_crop_strands_rgba",width=width,height=height,alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(atlas.reshape(-1))
    image.filepath_raw = str(texture_directory/"shane_photo_crop_strands_rgba.png")
    image.file_format = "PNG"
    image.save()
    image = bpy.data.images.load(image.filepath_raw,check_existing=False)
    image.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage");tex.image=image
    uv = mat.node_tree.nodes.new("ShaderNodeUVMap");uv.uv_map="JerseyUV"
    mat.node_tree.links.new(uv.outputs["UV"],tex.inputs["Vector"])
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    alpha=mat.node_tree.nodes.new("ShaderNodeMath");alpha.operation="GREATER_THAN";alpha.inputs[1].default_value=.28
    mat.node_tree.links.new(tex.outputs["Alpha"],alpha.inputs[0])
    mat.node_tree.links.new(alpha.outputs[0],bsdf.inputs["Alpha"])
    mat.surface_render_method="DITHERED"
    for name in ("Hair_Shane_ShortCropRoots","Hair_Shane_ShortCropCards"):
        bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)

    def hairline(p):
        angle=abs(math.atan2(p.x,p.z+1))
        t=max(0,min(1,(angle-.55)/1.1));t=t*t*(3-2*t)
        back=max(0,min(1,(angle-1.65)/1.49));back=back*back*(3-2*back)
        return 172.6-6.5*t-3.2*back+.09*math.sin(p.x*1.6)

    # Start with scalp topology and smooth the contour in geometry, then fit
    # the shell outside the head. No silhouette is supplied by a brown paint patch.
    polygons=[list(p.vertices) for p in head.data.polygons
              if p.center.y>=hairline(p.center)-.25 and (abs(p.center.x)<8.2 or p.center.y>171)]
    ids=sorted({i for f in polygons for i in f});remap={i:n for n,i in enumerate(ids)}
    root_points=[head.data.vertices[i].co.copy() for i in ids]
    cap=bound_mesh("Hair_Shane_ShortCropRoots",root_points,
                   [[remap[i] for i in f] for f in polygons],rig,mat,
                   uvs=[(.5+math.atan2(p.x,p.z+1)/math.tau,.84) for p in root_points])
    sub=cap.modifiers.new("Root_Contour_Smoothing","SUBSURF");sub.levels=1
    with bpy.context.temp_override(object=cap,active_object=cap):
        bpy.ops.object.modifier_apply(modifier=sub.name)
    surface=BVHTree.FromPolygons([v.co for v in head.data.vertices],
                                 [list(p.vertices) for p in head.data.polygons])
    for v in cap.data.vertices:
        near,normal,_,_=surface.find_nearest(v.co)
        v.co=near+normal*.19
    cap.data.update();cap.data.calc_loop_triangles()
    triangles=list(cap.data.loop_triangles)
    # Sample by triangle area, avoiding an artificial dense ring on small faces.
    areas=[];total=0
    for tri in triangles:
        a,b,c=[cap.data.vertices[i].co for i in tri.vertices]
        total+=(b-a).cross(c-a).length/2;areas.append(total)
    import bisect
    vertices=[];faces=[];uvs=[]
    guide_count = 1800
    for index in range(guide_count):
        tri=triangles[bisect.bisect_left(areas,rng.random()*total)]
        a,b,c=[cap.data.vertices[i].co for i in tri.vertices]
        r=math.sqrt(rng.random());t=rng.random()
        root=a*(1-r)+b*r*(1-t)+c*r*t
        _,normal,_,_=surface.find_nearest(root)
        top=root.y>170.8
        flow=Vector((-.9,.08,.65)) if top else Vector((-.08*root.x,-1,-.25))
        tangent=(flow-normal*flow.dot(normal)).normalized()
        across=normal.cross(tangent).normalized()
        length=rng.uniform(1.2,2.6) if top else rng.uniform(.50,1.10)
        breadth=rng.uniform(.18,.32) if top else rng.uniform(.12,.22)
        lift=rng.uniform(.28,.65) if top else rng.uniform(.08,.20)
        slot=index%16;start=len(vertices)
        for row in range(6):
            t=row/5
            # Curvature lifts individual tufts into a dimensional cropped crown.
            centre=root+tangent*length*t+normal*(.015+lift*math.sin(t*math.pi*.8))
            taper=1-.70*t*t
            for column in (-1,0,1):
                vertices.append(centre+across*column*breadth*.5*taper
                                +normal*(1-abs(column))*breadth*.18)
                uvs.append(((slot*64+3+(column+1)*29)/1024,.006+t*.725))
        for row in range(5):
            for column in range(2):
                n=start+row*3+column
                faces.append((n+3,n+4,n+1,n))
    cards=bound_mesh("Hair_Shane_ShortCropCards",vertices,faces,rig,mat,uvs=uvs)
    # Deliberately retain each curved strip's geometric normals. The earlier
    # scalp-normal override flattened every tuft into the same painted shell.
    cards["groom_guides"]=guide_count
    cards["normal_policy"]="curved geometric normals; no scalp-normal override"
    print("SHANE_PHOTO_GROOM",guide_count,"curved tufts",len(faces)*2,"triangles")
    return cap,cards
