"""Body-derived, smoothed and deliberately cut kit; no runtime cloth solver.

The source body's shoulder/crotch topology provides continuous sewn junctions.
Boundary rings are cut to actual collar, wrist, waist and hem landmarks before
adding thickness ribbons, with one explicit atlas chart per garment panel.
"""
import json
import math
import bpy
import bmesh
from mathutils import Vector
from shane_player_finish import TEXTURES, bound_mesh, image_node, smoothstep
from shane_anatomical_foundation import select_faces

# Used only for a smooth front-facing V influence; the actual binding follows
# the garment cut loop, rather than forcing its vertices onto an ellipse.
COLLAR_Z = -2.5


def setup_material(material):
    nodes=material.node_tree.nodes
    # Clear the old procedural fabric graph: retain exportable image maps only.
    for node in list(nodes):
        if node.type not in {"BSDF_PRINCIPLED","OUTPUT_MATERIAL"}: nodes.remove(node)
    for file,socket,space in (("beechlawn_home_tailored_2k_albedo.png","Base Color","sRGB"),
                              ("beechlawn_home_cloth_roughness.png","Roughness","Non-Color")):
        image=bpy.data.images.load(str(TEXTURES/file),check_existing=False)
        image.colorspace_settings.name=space; image.pack()
        image_node(material,image,socket)
    image=bpy.data.images.load(str(TEXTURES/"beechlawn_home_knit_normal.png"),check_existing=False)
    image.colorspace_settings.name="Non-Color"; image.pack()
    tex=nodes.new("ShaderNodeTexImage"); tex.image=image
    normal=nodes.new("ShaderNodeNormalMap"); normal.inputs["Strength"].default_value=.24
    material.node_tree.links.new(tex.outputs["Color"],normal.inputs["Color"])
    material.node_tree.links.new(normal.outputs["Normal"],nodes["Principled BSDF"].inputs["Normal"])
    nodes["Principled BSDF"].inputs["Sheen Weight"].default_value=.15


def boundary_edges(mesh):
    counts={}
    for p in mesh.polygons:
        for edge in p.edge_keys:
            e=tuple(sorted(edge)); counts[e]=counts.get(e,0)+1
    return [e for e,n in counts.items() if n==1]


def weights_at(fit,point):
    near,normal,index,distance=fit.target_surface.find_nearest(point)
    return fit.target_weights(near,index)


def chart(rects,name,u,v):
    x0,y0,x1,y1=rects[name]
    return ((x0+max(.002,min(.998,u))*(x1-x0))/2048,
            1-(y1-max(.002,min(.998,v))*(y1-y0))/2048)


def repair_fabric_edge_uvs(mesh,kind,rects):
    """Give edge-on cut faces valid fabric UVs instead of zero-area tangents."""
    mesh.calc_loop_triangles(); uv=mesh.uv_layers.active
    bad=set()
    for triangle in mesh.loop_triangles:
        a,b,c=[uv.data[li].uv for li in triangle.loops]
        if abs((b-a).cross(c-a))<1e-10: bad.add(triangle.polygon_index)
    for index in bad:
        polygon=mesh.polygons[index]
        region="blue" if kind=="socks" else "black"
        centre=sum((mesh.vertices[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
        printed_panel=kind=="shirt" and abs(centre.x)<22 and 100<centre.y<156
        original_uv=sum((uv.data[li].uv for li in polygon.loop_indices),Vector((0,0)))/len(polygon.loop_indices)
        for j,li in enumerate(polygon.loop_indices):
            angle=math.tau*j/len(polygon.loop_indices)
            if printed_panel:
                # Preserve the local artwork sample on edge-on chest faces.
                # Sending these to plain black punched holes in the sponsor.
                uv.data[li].uv=original_uv+Vector((math.cos(angle),math.sin(angle)))*.0012
            else:
                uv.data[li].uv=chart(rects,region,.5+.32*math.cos(angle),.5+.32*math.sin(angle))
    print("KIT_EDGE_UV_REPAIR",kind,len(bad))


def make_garment(fit,name,faces,material,kind,rects):
    # Clip the continuous fitted anatomy with actual planes. Selecting faces
    # by their centres left jagged partial rings and, for shorts, isolated
    # patches when a boundary traversed a coarse source face.
    obj=fit.piece(name,fit.groups["body"],material)
    mesh=obj.data
    # Offline subdivision supplies enough rings at hems and joint bends.
    bm=bmesh.new(); bm.from_mesh(mesh)
    low,high={"shirt":(100.5,155.0),"shorts":(62.0,103.0),"socks":(7.9,45.5)}[kind]
    planes=[(Vector((0,low,0)),Vector((0,1,0))),
            (Vector((0,high,0)),Vector((0,1,0)))]
    if kind=="shirt":
        planes.extend(((Vector((72.4,0,0)),Vector((1,0,0))),
                       (Vector((-72.4,0,0)),Vector((1,0,0)))))
    for point,normal in planes:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                              dist=.00001,plane_co=point,plane_no=normal)
    remove=[p for p in bm.faces if not (low-.001<p.calc_center_median().y<high+.001)
            or (kind=="shirt" and abs(p.calc_center_median().x)>72.401)]
    bmesh.ops.delete(bm,geom=remove,context="FACES")
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
    bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=1,use_grid_fill=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    boundary={v for e in bm.edges if e.is_boundary for v in e.verts}
    for _ in range(5 if kind=="shirt" else 7):
        bmesh.ops.smooth_vert(bm,verts=[v for v in bm.verts if v not in boundary],
                              factor=.48,use_axis_x=True,use_axis_y=True,use_axis_z=True)
    bm.to_mesh(mesh); bm.free(); mesh.update()
    edges=boundary_edges(mesh); boundary={i for edge in edges for i in edge}
    collar=set(); cuffs=set(); hem=set(); chest_depth={}
    group_names={g.index:g.name for g in obj.vertex_groups}
    for vertex in mesh.vertices:
        p=vertex.co.copy()
        anatomical_side=1.0 if p.x>=0 else -1.0
        if kind=="shorts" and p.y<86:
            left=sum(g.weight for g in vertex.groups if "Left" in group_names[g.group] and "Leg" in group_names[g.group])
            right=sum(g.weight for g in vertex.groups if "Right" in group_names[g.group] and "Leg" in group_names[g.group])
            if abs(left-right)>.05:
                anatomical_side=1.0 if left>right else -1.0
        _,normal,_,_=fit.target_surface.find_nearest(p)
        if kind=="shirt":
            if vertex.index in boundary:
                if abs(p.x)>60:
                    p.x=math.copysign(72.4,p.x); cuffs.add(vertex.index)
                elif p.y<113:
                    p.y=100.5; hem.add(vertex.index)
                elif p.y>154.0:
                    p += normal*.8
                    collar.add(vertex.index)
            if vertex.index not in collar:
                p += normal*(.9 if abs(p.x)>22 else 1.25)
            if vertex.index in hem:
                p.y=100.5
            # Low-amplitude drape by the side seams and waist; centre chest
            # stays smooth so typography cannot inherit anatomical creases.
            if abs(p.x)<24 and 102<p.y<124:
                fold=math.sin(p.y*1.05+abs(p.x)*.38)*.11*smoothstep(7,20,abs(p.x))
                p+=normal*fold
            if p.z>-1 and abs(p.x)<20 and 115<p.y<146:
                # A jersey spans the pectorals; it must not reproduce the
                # body's nipple/cleavage cavities. That concave extracted
                # surface folded through itself and split the sponsor.
                level=round(p.y*2)/2
                if level not in chest_depth:
                    hits=[fit.target_surface.ray_cast(Vector((x,level,40)),Vector((0,0,-1)))[0]
                          for x in (-10,-5,0,5,10)]
                    chest_depth[level]=max(hit.z for hit in hits if hit is not None)
                envelope=chest_depth[level]+1.5-.006*p.x*p.x
                influence=(1-smoothstep(16,20,abs(p.x)))*smoothstep(115,121,p.y)*(1-smoothstep(140,146,p.y))
                p.z+=max(0,envelope-p.z)*influence
        else:
            p+=normal*(1.55 if kind=="shorts" else .30)
            if vertex.index in boundary:
                if kind=="shorts":
                    p.y=103.0 if p.y>89 else 62.0
                else:
                    p.y=45.5 if p.y>25 else 7.9
                hem.add(vertex.index)
            if kind=="shorts":
                # Relax the leg openings into an actual loose sports short.
                centre=math.copysign(9.2,p.x)
                low=1-smoothstep(62,86,p.y)
                p.x+=(p.x-centre)*.10*low
                p.z+=math.sin((p.y-62)*.7+abs(p.x)*.4)*.16*low
        # Open garment pieces can inherit inward normals after cutting. Use
        # the original closed anatomical surface to establish outward clearance.
        near,outward,_,_=fit.target_surface.find_nearest(p)
        clearance={"shirt":1.15,"shorts":1.8,"socks":.35}[kind]
        if vertex.index not in collar and (p-near).dot(outward)<clearance:
            p=near+outward*clearance
        if kind=="shirt" and abs(p.x)<15.0 and p.y>143.0:
            # Cut above the shoulders, then compress only the neck rows. The
            # former horizontal cut at 151 also cut the shoulder caps, leaving
            # open jagged strips that no collar binding could close.
            neck_influence=1-smoothstep(6.5,11.0,abs(p.x))
            p.y-=4.0*smoothstep(143,155,p.y)*neck_influence
            # Dip the neighbouring rows too. Moving only the boundary inverted
            # the first row of quads and left a jagged spike above the V.
            angle=math.atan2(p.x,p.z-COLLAR_Z)
            p.y-=3.2*max(0.0,math.cos(angle))*(1-abs(math.sin(angle)))*smoothstep(143,151,p.y)
        if kind=="shirt" and vertex.index in hem:
            # Clearance projection must not lift individual hem vertices.
            p.y=100.5
        if kind=="shorts" and p.y<86.0:
            # Inflation into the narrow thigh gap pushed each inner-leg shell
            # across the centreline. Preserve its original anatomical side;
            # coordinate sign after inflation is no longer reliable.
            p.x=anatomical_side*max(.50,p.x*anatomical_side)
        vertex.co=p
    mesh.update()
    oriented=bmesh.new(); oriented.from_mesh(mesh)
    unseen=set(oriented.faces)
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
            _,outward,_,_=fit.target_surface.find_nearest(face.calc_center_median())
            score+=face.normal.dot(outward)*face.calc_area()
        if score<0:
            for face in component: face.normal_flip()
    oriented.to_mesh(mesh); oriented.free(); mesh.update()
    # Bisect/subdivision interpolate the original anatomical deform layer.
    # Keep that correspondence: nearest-surface rebinding could jump across
    # the narrow inner-thigh gap and attach cloth to the opposite leg.
    from shane_anatomical_foundation import normalize_weights
    if kind=="shirt":
        arm_groups={g.index:g for g in obj.vertex_groups if "Arm" in g.name}
        hips=obj.vertex_groups.get("mixamorig:Hips") or obj.vertex_groups.new(name="mixamorig:Hips")
        for vertex in mesh.vertices:
            p=vertex.co
            if abs(p.x)<24 and 100<=p.y<112:
                # The jersey hem belongs to the pelvis, above the leg sockets.
                # Leg influence here pulled it into jagged teeth during steps.
                amount=1-smoothstep(103,112,p.y)
                old=[(g.group,g.weight) for g in vertex.groups]
                for index,weight in old:obj.vertex_groups[index].add([vertex.index],weight*(1-amount),"REPLACE")
                retained=next((weight for index,weight in old if index==hips.index),0)
                hips.add([vertex.index],retained*(1-amount)+amount,"REPLACE")
            if abs(p.x)>=23 or not 103<p.y<145:
                continue
            # The generic anatomical heat weights reach too far down the
            # chest. Below the axilla the shirt follows the ribcage; upper-arm
            # motion must not drag sponsor/crest polygons into folds.
            influence=smoothstep(134,143,p.y)*smoothstep(14,23,abs(p.x))
            for assignment in list(vertex.groups):
                group=arm_groups.get(assignment.group)
                if group is not None:
                    group.add([vertex.index],assignment.weight*influence,"REPLACE")
    normalize_weights(obj)
    names={g.index:g.name for g in obj.vertex_groups}
    weights=[]
    for vertex in mesh.vertices:
        weights.append({names[g.group]:g.weight for g in vertex.groups if g.weight>1e-7})
    uv=mesh.uv_layers.active
    for polygon in mesh.polygons:
        centre=sum((mesh.vertices[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
        sleeve=kind=="shirt" and abs(centre.x)>22.5
        front=centre.z>-2.0
        for li in polygon.loop_indices:
            p=mesh.vertices[mesh.loops[li].vertex_index].co
            if sleeve:
                side="Left" if p.x>0 else "Right"
                axis_y=fit.rig.data.bones["mixamorig:"+side+"Arm"].head_local.y
                axis_z=fit.rig.data.bones["mixamorig:"+side+"Arm"].head_local.z
                angle=math.atan2(p.z-axis_z,p.y-axis_y)
                # UV seam at the underside, not across the blue outer stripe.
                v=.5+angle/math.tau
                uv.data[li].uv=chart(rects,"sleeve_l" if p.x>0 else "sleeve_r",
                                      (abs(p.x)-22.5)/(72.4-22.5),v)
            elif kind=="shirt":
                uv.data[li].uv=chart(rects,"front" if front else "back",
                                      .5+(p.x if front else -p.x)/46.0,(p.y-100.5)/50.0)
            elif kind=="shorts":
                uv.data[li].uv=chart(rects,"shorts_front" if front else "shorts_back",
                                      .5+(p.x if front else -p.x)/52.0,(p.y-62)/41.0)
            else:
                axis=math.copysign(9.2,p.x)
                uv.data[li].uv=chart(rects,"socks",.5+math.atan2(p.x-axis,p.z+1.5)/math.tau,(p.y-7.9)/37.6)
    repair_fabric_edge_uvs(mesh,kind,rects)
    # Actual narrow edge thickness: no double-sided infinitely thin cutouts.
    vertices=[]; faces_out=[]; uv_out=[]; weights_out=[]
    for a,b in edges:
        pa,pb=mesh.vertices[a].co.copy(),mesh.vertices[b].co.copy()
        if kind=="shirt":
            group=collar if a in collar and b in collar else cuffs if a in cuffs and b in cuffs else hem
            if a not in group or b not in group: continue
            if group is collar:
                # A continuous purpose-built V binding is added below; no
                # per-edge ribbons around an anatomical cut.
                continue
            elif group is cuffs:
                da=db=Vector((-math.copysign(1.4,pa.x),0,0))
            else:
                da=db=Vector((0,1.0,0))
        else:
            da=db=Vector((0,1.2 if kind=="shorts" else -2.0,0))
        start=len(vertices)
        points=(pa,pb,pb+db,pa+da)
        vertices.extend(points); faces_out.append((start,start+1,start+2,start+3))
        region="blue" if kind=="socks" else "black"
        uv_out.extend([chart(rects,region,.2,.2),chart(rects,region,.8,.2),chart(rects,region,.8,.8),chart(rects,region,.2,.8)])
        weights_out.extend((weights[a],weights[b],weights[b],weights[a]))
    trim=bound_mesh("Kit_"+kind+"_BoundHems",vertices,faces_out,fit.rig,material,weights_out,uv_out)
    if kind=="shirt":
        # Preserve the real cut loop. An ideal ellipse buried its front in the
        # neck and pulled the shoulders into folds when enlarged. Four shared
        # rings make the black/blue/black binding follow the sewn neckline.
        collar_edges=[(a,b) for a,b in edges if a in collar and b in collar]
        collar_ids=sorted({i for edge in collar_edges for i in edge})
        lookup={i:j for j,i in enumerate(collar_ids)}
        cv=[]; cf=[]; cu=[]; cw=[]; count=len(collar_ids)
        for ring,t in enumerate((0.0,.17,.34,1.0)):
            for i in collar_ids:
                p=mesh.vertices[i].co.copy()
                radial=Vector((p.x,0,p.z-COLLAR_Z)).normalized()
                # Band sits just above the cloth and slopes down/out into it.
                p += radial*(.1+.65*t)+Vector((0,-.9*t,0))
                cv.append(p); cw.append(weights[i]); cu.append((0,0))
        for ring in range(3):
            for a,b in collar_edges:
                a,b=lookup[a],lookup[b]
                cf.append((ring*count+a,ring*count+b,
                           (ring+1)*count+b,(ring+1)*count+a))
        binding=bound_mesh("Kit_Shane_ContinuousVBinding",cv,cf,fit.rig,material,cw,cu)
        # Boundary edges are stored as unordered index pairs. Reconcile the
        # shared ring winding before smooth shading; alternating winding
        # cancels the vertex normals and produces bright triangular teeth.
        normals=bmesh.new(); normals.from_mesh(binding.data)
        bmesh.ops.recalc_face_normals(normals,faces=list(normals.faces))
        score=0.0
        for face in normals.faces:
            _,outward,_,_=fit.target_surface.find_nearest(face.calc_center_median())
            score+=face.normal.dot(outward)*face.calc_area()
        if score<0:
            for face in normals.faces: face.normal_flip()
        normals.to_mesh(binding.data); normals.free(); binding.data.update()
        layer=binding.data.uv_layers.active
        for polygon in binding.data.polygons:
            region="blue" if polygon.index//len(collar_edges)==1 else "black"
            for li,coord in zip(polygon.loop_indices,((.2,.2),(.8,.2),(.8,.8),(.2,.8))):
                layer.data[li].uv=chart(rects,region,*coord)
    return obj,trim


def build_tailored_kit(fit,material,modular=False):
    layout=json.loads((TEXTURES/"beechlawn_home_tailored_atlas_layout.json").read_text())
    rects=layout["rects"]
    setup_material(material)
    for name in ("YBot_Surface","Kit_Shorts","Kit_Socks"):
        obj=bpy.data.objects.get(name)
        if obj: bpy.data.objects.remove(obj,do_unlink=True)
    neck=fit.joints["neck"].y; pelvis=fit.joints["pelvis"].y
    wrist=abs(fit.joints["l-hand"].x); knee=fit.joints["l-knee"].y
    ankle=fit.joints["l-ankle"].y
    shirt_faces=select_faces(fit,"body",lambda p: pelvis+.8<p.y<neck-1.0 and abs(p.x)<wrist-.7)
    target={source:fit.target_positions[i] for i,source in enumerate(fit.body_ids)}
    shorts_faces=[face for face in fit.groups["body"]
                  if 62<sum(target[i].y for i,_ in face)/len(face)<102
                  and abs(sum(target[i].x for i,_ in face)/len(face))<28]
    socks_faces=select_faces(fit,"body",lambda p: ankle-3<p.y<ankle+.82*(knee-ankle))
    shirt,st=make_garment(fit,"YBot_Surface",shirt_faces,material,"shirt",rects)
    if modular:
        short=shirt.copy(); short.data=shirt.data.copy()
        bpy.context.collection.objects.link(short); short.name="Kit_Shirt_ShortSleeve"
        bm=bmesh.new();bm.from_mesh(short.data)
        for x in (-39.0,39.0):
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,
                plane_co=Vector((x,0,0)),plane_no=Vector((1,0,0)))
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)>39.001],context="FACES")
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
        bm.to_mesh(short.data);bm.free();short.data.update()
    from shane_short_pattern import make_pattern_shorts
    shorts,pt=make_pattern_shorts(fit,material,rects)
    socks,kt=make_garment(fit,"Kit_Socks",socks_faces,material,"socks",rects)
    # Remove hidden skin using the actual fitted garment heights. The old
    # source-space masks no longer matched the lengthened shorts/sock tops.
    body=bpy.data.objects["YBot_Joints"]
    bm=bmesh.new(); bm.from_mesh(body.data)
    def covered_face(face):
        p=face.calc_center_median()
        return (63.0<p.y<103.0 or 9.0<p.y<44.5 or
                (103.0<=p.y<148.0 and abs(p.x)<(34.0 if modular else 72.0)) or
                (148.0<=p.y<151.0 and abs(p.x)>8.0))
    bmesh.ops.delete(bm,geom=[face for face in bm.faces if covered_face(face)],context="FACES")
    bm.to_mesh(body.data); bm.free(); body.data.update()
    print("SHANE_TAILORED_KIT",[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in (shirt,shorts,socks)],
          "weights=anatomical_shirt_socks_and_patterned_hip_thigh_shorts")
    return (shirt,shorts,socks,st,pt,kt)
