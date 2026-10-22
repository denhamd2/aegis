"""Reference-led Shane finishing, evaluated offline in armature-local cm.

All geometry uses the existing production rest pose. No portrait, runtime
cloth, constraints or extra animation tracks are introduced.
"""
from pathlib import Path
import math
import random
import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
TEXTURES = ROOT / "games/beechlawn_rovers/assets/characters/textures"
from skin_palette import SHARED_SKIN
SKIN_PIGMENT = np.array(SHARED_SKIN,dtype=np.float32)


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def reference_proportions(point):
    """Compact cranium/face and solid Sunday-league build, without rig edits."""
    x, y, z = point
    original_y = y
    head = smoothstep(148.0, 154.0, y)
    if head:
        # Preserve crown height; shorten the overlong lower face/neck join.
        y += head * ((179.0 + (y-179.0)*.91) - y)
        x *= 1.0 + .045*head
        front = smoothstep(-2.0, 5.0, z)
        cheek = math.exp(-((abs(x)-4.8)/2.7)**2 - ((original_y-160.4)/3.3)**2)
        jaw = math.exp(-((abs(x)-4.3)/2.8)**2 - ((original_y-155.3)/2.8)**2)
        x += math.copysign((.36*cheek + .40*jaw)*head, x)
        z += front*head*(.25*cheek + .18*jaw)
        # Front/profile fitting in centimetres. Apply to all head components,
        # keeping the eyelids and curved eyeballs in the same coordinate warp.
        face=smoothstep(3.5,7.0,z)
        nose=math.exp(-(x/1.9)**4-((y-162.2)/1.9)**2)*face
        bridge=math.exp(-(x/.95)**4-((y-165.0)/2.0)**2)*face
        ala=math.exp(-((y-161.6)/1.45)**2)*face*(1-smoothstep(2.0,3.2,abs(x)))
        z += 1.35*nose + .40*bridge
        x *= 1+.23*ala
        mouth=math.exp(-((y-159.6)/1.4)**2)*face*(1-smoothstep(3.4,5.0,abs(x)))
        x *= 1+.22*mouth
        orbit=math.exp(-((abs(x)-3.4)/1.7)**4-((y-166.5)/1.0)**2)
        x *= 1-.035*orbit
        brow=math.exp(-((abs(x)-3.3)/2.0)**4-((y-167.9)/.7)**2)*face
        z += .30*brow
        lower_jaw=math.exp(-((abs(x)-5.5)/2.0)**2-((y-156.7)/1.8)**2)*face
        x -= math.copysign(.30*lower_jaw,x)
        x *= 1-.11*math.exp(-((y-152.5)/2.1)**2)
    torso = math.exp(-((y-119.0)/17.0)**4) * math.exp(-(x/22.0)**8)
    x *= 1.0 + .065*torso
    z += .5*torso*smoothstep(-1.0, 5.0, z)
    if abs(x) > 74 and y > 125:
        # Keep the wrist and finger bases stable, reduce oversized fingertips.
        t = smoothstep(74, 82, abs(x))
        x = math.copysign(74 + (abs(x)-74)*(1-.08*t), x)
    return Vector((x, y, z))


def image_from_array(name, array, colorspace="sRGB"):
    height, width = array.shape[:2]
    rgba = np.ones((height, width, 4), dtype=np.float32)
    rgba[:, :, :array.shape[2]] = array
    image = bpy.data.images.new(name, width=width, height=height, alpha=True)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(rgba.reshape(-1))
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    # Reload disk pixels: GENERATED image buffers are linear while the saved
    # colour PNG is sRGB. Loading it makes Blender and glTF sample identically.
    path = image.filepath_raw
    bpy.data.images.remove(image)
    loaded = bpy.data.images.load(path, check_existing=False)
    loaded.colorspace_settings.name = colorspace
    loaded.pack()
    return loaded


def image_node(material, image, socket, uv_name="JerseyUV"):
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    for link in list(bsdf.inputs[socket].links):
        links.remove(link)
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = uv_name
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    links.new(uv.outputs["UV"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], bsdf.inputs[socket])
    return tex


def reconcile_skin_normals(head, body, fitter):
    """Orient open skin islands against the closed anatomy, then sew shading.

    Recalculating an open head/neck independently can pick opposite windings.
    Positional seam tests alone miss that almost-180-degree normal mismatch.
    """
    for obj in (head,body):
        bm=bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        unseen=set(bm.faces); flipped=0
        while unseen:
            seed=unseen.pop(); component={seed}; stack=[seed]
            while stack:
                face=stack.pop()
                for edge in face.edges:
                    for neighbour in edge.link_faces:
                        if neighbour in unseen:
                            unseen.remove(neighbour); component.add(neighbour); stack.append(neighbour)
            score=0.0
            for face in component:
                _,outward,_,_=fitter.target_surface.find_nearest(face.calc_center_median())
                score+=face.normal.dot(outward)*face.calc_area()
            if score<0:
                for face in component: face.normal_flip()
                flipped+=len(component)
        bm.to_mesh(obj.data); bm.free(); obj.data.update()
        print("SHANE_SKIN_WINDING",obj.name,"flipped_faces",flipped)
    coordinates={tuple(round(c,4) for c in v.co):v.index for v in head.data.vertices}
    normals={obj.name:[v.normal.copy() for v in obj.data.vertices] for obj in (head,body)}
    seams=0
    for v in body.data.vertices:
        key=tuple(round(c,4) for c in v.co)
        if key in coordinates:
            hi=coordinates[key]
            average=(normals[head.name][hi]+normals[body.name][v.index]).normalized()
            normals[head.name][hi]=average; normals[body.name][v.index]=average
            seams+=1
    for obj in (head,body):
        obj.data.normals_split_custom_set_from_vertices(normals[obj.name])
        obj.data.update()
    print("SHANE_SKIN_SHADING_SEAM",seams)


def skin_colour(points, eyes):
    x, y, z = points[:, 0], points[:, 1], points[:, 2]
    colour = np.tile(SKIN_PIGMENT, (len(points), 1))
    front = np.clip((z-1.5)/4, 0, 1)
    eye_y = sum(p.y for p in eyes)/2
    eye_x = sum(abs(p.x) for p in eyes)/2
    def field(cx, cy, sx, sy):
        return np.exp(-((np.abs(x)-cx)/sx)**2 - ((y-cy)/sy)**2) * front
    # Pigment, not photographic illumination: cheeks, nose, lips, brows.
    flush = field(4.5, eye_y-3.0, 2.4, 2.0)
    colour += flush[:, None]*np.array([.055, -.022, -.020])
    nose = field(0, eye_y-2.8, 1.55, 1.7)
    colour += nose[:, None]*np.array([.025, -.015, -.012])
    lip_y = eye_y-6.4
    lips = np.exp(-(x/3.4)**6 - ((y-lip_y)/.47)**2)*front
    colour += lips[:, None]*np.array([.015, -.065, -.040])
    under_eye = field(eye_x, eye_y-.85, 1.55, .6)
    colour += under_eye[:, None]*np.array([-.035, -.035, -.025])
    brow_line = eye_y+1.25 - .035*(np.abs(x)-eye_x)**2
    brow = np.exp(-((np.abs(x)-eye_x)/1.75)**6 - ((y-brow_line)/.21)**2)*front
    brow *= .78+.22*np.cos(x*48+y*13)
    colour = colour*(1-brow[:, None]*.64) + brow[:, None]*np.array([.16, .085, .048])*.64
    # Restrained near-neutral variation over the rest of the body.
    colour += (np.sin(x*2.7+y*1.7+z)*.004)[:, None]
    return np.clip(colour, 0, 1)


def reference_skin_relief(points,eyes):
    """Sub-millimetre expression/age detail, baked in anatomical UV space."""
    x,y,z=points[:,0],points[:,1],points[:,2]
    front=np.clip((z-4)/4,0,1);eye_y=sum(p.y for p in eyes)/2
    height=np.zeros_like(x)
    for offset,depth in ((3.0,.014),(3.85,.017),(4.65,.011)):
        line=eye_y+offset+.11*np.cos(x*.55)
        height-=depth*np.exp(-((y-line)/.07)**2-(x/5.2)**6)*front
    # Restrained outer-eye creases and nasolabial folds from the neutral board.
    for slope in (-.35,.25):
        line=eye_y-.25+slope*(np.abs(x)-5)
        height-=.006*np.exp(-((y-line)/.06)**2-((np.abs(x)-5.5)/1.05)**4)*front
    crease_x=1.8+.43*(eye_y-4.4-y)
    height-=.010*np.exp(-((np.abs(x)-crease_x)/.085)**2-((y-(eye_y-5.5))/1.65)**4)*front
    return height


def bake_skin(head, body, material, eyes, *, head_only=False, image_prefix="shane", color_overlay=None, neutral_base=False, detail_only=False, retained_neck_albedo=None):
    """Rasterize anatomical pigment onto the original licensed body UVs."""
    size = 2048 if head_only else 512
    from shane_skin_source import sample_skin,skin_tint
    retained=None
    if retained_neck_albedo is not None:
        assert head_only and tuple(retained_neck_albedo.size)==(size,size), 'Neck retention requires the matching head atlas'
        pixels=np.empty(size*size*4,dtype=np.float32)
        retained_neck_albedo.pixels.foreach_get(pixels)
        retained=pixels.reshape(size,size,4)[:,:,:3]
    if neutral_base:
        # Player-specific face UVs can come from a different starting mesh than
        # the licensed source skin. Keep the surface clean instead of carrying
        # another model's eye/nose/mouth markings into this identity atlas.
        photo=np.tile(SKIN_PIGMENT,(size,size,1)).astype(np.float32)
    else:
        photo=sample_skin("albedo",size,head if head_only else None)*skin_tint(SKIN_PIGMENT)
    if detail_only:
        # Keep the licensed skin's small surface variation without inheriting
        # its broad face colour, lip/eye shading or another identity's marks.
        def box_blur(array, radius):
            for axis in (0, 1):
                padding=[(0,0)]*3; padding[axis]=(radius,radius)
                padded=np.pad(array,padding,mode="edge")
                zero_shape=list(padded.shape);zero_shape[axis]=1
                sums=np.concatenate((np.zeros(zero_shape,dtype=np.float32),np.cumsum(padded,axis=axis,dtype=np.float32)),axis=axis)
                left=[slice(None)]*3;right=[slice(None)]*3
                left[axis]=slice(0,array.shape[axis]);right[axis]=slice(radius*2+1,None)
                array=(sums[tuple(right)]-sums[tuple(left)])/(radius*2+1)
            return array
        low=box_blur(box_blur(photo,8),8)
        photo=SKIN_PIGMENT*np.clip(photo/np.maximum(low,.025),.85,1.15)**.5
    atlas = np.tile(SKIN_PIGMENT, (size, size, 1))
    relief=np.zeros((size,size),dtype=np.float32) if head_only else None
    filled = np.zeros((size, size), dtype=bool)
    for obj in ((head,) if head_only else (body,)):
        mesh = obj.data
        mesh.calc_loop_triangles()
        uv = mesh.uv_layers.active
        for triangle in mesh.loop_triangles:
            coords = np.array([uv.data[li].uv[:] for li in triangle.loops])* (size-1)
            lo = np.maximum(0, np.floor(coords.min(axis=0)).astype(int))
            hi = np.minimum(size-1, np.ceil(coords.max(axis=0)).astype(int))
            if (hi < lo).any():
                continue
            ax, ay = coords[0]; bx, by = coords[1]; cx, cy = coords[2]
            den = (by-cy)*(ax-cx) + (cx-bx)*(ay-cy)
            if abs(den) < 1e-8:
                continue
            yy, xx = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
            a = ((by-cy)*(xx-cx) + (cx-bx)*(yy-cy))/den
            b = ((cy-ay)*(xx-cx) + (ax-cx)*(yy-cy))/den
            c = 1-a-b
            mask = (a >= -.005) & (b >= -.005) & (c >= -.005)
            points = np.array([mesh.vertices[i].co[:] for i in triangle.vertices])
            samples = a[..., None]*points[0] + b[..., None]*points[1] + c[..., None]*points[2]
            colors = skin_colour(samples.reshape(-1, 3), eyes).reshape(samples.shape)
            if color_overlay is not None:
                colors=color_overlay(samples.reshape(-1,3),colors.reshape(-1,3)).reshape(samples.shape)
            # Preserve the source skin's registered fine detail and local
            # pigmentation, with bounded reference-specific pigment tuning.
            colors=np.clip(photo[lo[1]:hi[1]+1,lo[0]:hi[0]+1]*colors/SKIN_PIGMENT,0,1)
            if retained is not None:
                # The head keeps the master's anatomical UVs. Preserve the
                # shared skin exactly at the protected neck, then transition
                # over 3 cm into the individual face rather than a hard seam.
                blend=np.clip((samples[:,:,1]-154.0)/3.0,0,1)
                blend=(blend*blend*(3-2*blend))[:,:,None]
                colors=retained[lo[1]:hi[1]+1,lo[0]:hi[0]+1]*(1-blend)+colors*blend
            atlas[lo[1]:hi[1]+1, lo[0]:hi[0]+1][mask] = colors[mask]
            if head_only:
                heights=reference_skin_relief(samples.reshape(-1,3),eyes).reshape(samples.shape[:2])
                relief[lo[1]:hi[1]+1,lo[0]:hi[0]+1][mask]=heights[mask]
            filled[lo[1]:hi[1]+1, lo[0]:hi[0]+1][mask] = True
    # Eight-pixel island gutter, keeping mipmaps from pulling in unrelated art.
    for _ in range(8):
        new = filled.copy()
        for axis, step in ((0, 1), (0, -1), (1, 1), (1, -1)):
            valid = np.roll(filled, step, axis) & ~new
            atlas[valid] = np.roll(atlas, step, axis)[valid]
            if head_only:relief[valid]=np.roll(relief,step,axis)[valid]
            new |= valid
        filled = new
    rng = np.random.default_rng(8)
    atlas = np.clip(atlas + rng.normal(0, .002, (size, size, 1)), 0, 1)
    filename=f"{image_prefix}_head_anatomical_albedo_2k" if head_only else "shane_body_anatomical_albedo"
    image_node(material, image_from_array(filename, atlas), "Base Color")
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = .58
    # A reusable baked micro-normal, no procedural shader dependency in Godot.
    if head_only:
        # Downsample the sculpt-relief bake to 1K, then add restrained pores.
        height=relief.reshape(1024,2,1024,2).mean(axis=(1,3))
        noise=rng.normal(0,.00055,height.shape)
        noise=(noise+np.roll(noise,1,0)+np.roll(noise,1,1))/3
        height+=noise
        dy,dx=np.gradient(height,25/1024)
        vectors=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
        base=sample_skin("normal",1024,head)*2-1
        vectors[:,:,:2]+=base[:,:,:2]*.65
        vectors/=np.linalg.norm(vectors,axis=2,keepdims=True)
        normal=vectors*.5+.5
        normal_image=image_from_array(f"{image_prefix}_head_detail_normal_1k",normal,"Non-Color")
    else:
        noise = rng.normal(0, .025, (512, 512))
        dx, dy = np.gradient(noise)
        normal = np.stack((.5-dx*.45, .5-dy*.45, np.ones_like(dx)), axis=2)
        base=sample_skin("normal",512)*2-1
        vectors=normal*2-1;vectors[:,:,:2]+=base[:,:,:2]*.5
        vectors/=np.maximum(np.linalg.norm(vectors,axis=2,keepdims=True),1e-8)
        normal=vectors*.5+.5
        normal_image = image_from_array("shane_skin_micro_normal", normal, "Non-Color")
    tex = material.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = normal_image
    normal_node = material.node_tree.nodes.new("ShaderNodeNormalMap")
    normal_node.inputs["Strength"].default_value = .55 if head_only else .18
    material.node_tree.links.new(tex.outputs["Color"], normal_node.inputs["Color"])
    material.node_tree.links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])


def bound_mesh(name, vertices, faces, rig, material, weights=None, uvs=None):
    from shane_anatomical_foundation import attach, normalize_weights
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for face in mesh.polygons:
        face.use_smooth = True
    layer = mesh.uv_layers.new(name="JerseyUV")
    if uvs:
        for polygon in mesh.polygons:
            for li in polygon.loop_indices:
                layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    groups = {}
    for index in range(len(vertices)):
        for bone, value in (weights[index] if weights else {"mixamorig:Head": 1.0}).items():
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([index], value, "REPLACE")
    attach(obj, rig); normalize_weights(obj)
    return obj


def hairline(point):
    angle = abs(math.atan2(point.x, point.z+1.0))
    line=172.6-6.5*smoothstep(.55,1.65,angle)-3.2*smoothstep(1.65,3.14,angle)
    return line+.13*math.sin(point.x*1.7)+.08*math.sin(point.x*3.1)


def build_hair(head, rig, material):
    from shane_short_hair import build_short_crop
    return build_short_crop(head,rig,material)


def finish_head(fitter, materials):
    head=bpy.data.objects["Skin_Head"]; body=bpy.data.objects["YBot_Joints"]
    reconcile_skin_normals(head,body,fitter)
    eyes=[]
    eye_material=bpy.data.objects["Eye_l"].data.materials[0]
    for side in ("l","r"):
        obj=bpy.data.objects["Eye_"+side]
        centre=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        eyes.append(centre)
        radius=max(abs(v.co.x-centre.x) for v in obj.data.vertices)
        for polygon in obj.data.polygons:
            for li in polygon.loop_indices:
                p=obj.data.vertices[obj.data.loops[li].vertex_index].co
                obj.data.uv_layers.active.data[li].uv=(.5+(p.x-centre.x)/(2*radius),.5+(p.y-centre.y)/(2*radius))
    # Put the iris and pupil ON the curved eyeball. Separate frontal iris
    # discs previously protruded beyond the lid and produced a staring look.
    for obj in list(bpy.data.objects):
        if obj.name.startswith("EyeDetail_"): bpy.data.objects.remove(obj,do_unlink=True)
    yy,xx=np.mgrid[0:512,0:512]; x=(xx-255.5)/512; y=(yy-255.5)/512+.045
    radius=np.sqrt(x*x+y*y); angle=np.arctan2(y,x)
    colour=np.tile(np.array([.71,.70,.66],dtype=np.float32),(512,512,1))
    iris=radius<.215; pupil=radius<.083
    fibres=(np.sin(angle*79+radius*150)+np.sin(angle*43-radius*92))*.014
    for channel,base in enumerate((.24,.155,.075)):
        colour[:,:,channel][iris]=base+fibres[iris]
    edge=(radius>.195)&iris; colour[edge]*=.60
    colour[pupil]=(.016,.020,.018)
    image_node(eye_material,image_from_array("shane_brown_hazel_eyes_albedo",colour),"Base Color")
    eye_material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.24
    # Give the face its own dense UV allocation, preserving the licensed
    # anatomical islands rather than projecting a portrait onto the head.
    layer=head.data.uv_layers.active
    coordinates=np.array([item.uv[:] for item in layer.data])
    low=coordinates.min(axis=0); span=coordinates.max(axis=0)-low
    head["skin_source_uv_low"]=low.tolist();head["skin_source_uv_span"]=span.tolist()
    for item in layer.data:
        item.uv=((item.uv.x-low[0])/span[0]*.96+.02,(item.uv.y-low[1])/span[1]*.96+.02)
    face_material=materials["skin"].copy(); face_material.name="MAT_Skin_Shane_Baked"
    head.data.materials[0]=face_material
    bake_skin(head,body,materials["skin"],eyes)
    bake_skin(head,body,face_material,eyes,head_only=True)
    # Real lid topology comes from the archived eye-height targets. Set the
    # reference's brown/hazel iris instead of the previous green cast.
    materials["iris"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.12,.065,.025,1)
    build_hair(head,fitter.rig,materials["hair"])
    print("SHANE_REFERENCE_FACE", "eye_centres_cm",[list(p) for p in eyes],
          "head_vertices",len(head.data.vertices),"portrait_texture",False)
