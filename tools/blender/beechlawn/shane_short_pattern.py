"""A sewn shorts shell: shared waist, saddle crotch, two independent leg loops.

No thigh skin is copied or inflated, and no opposite-leg nearest transfer is
used. The editable quad mesh has explicit hip/thigh weights and panel UVs.
"""
import math
import bmesh
from mathutils import Vector
from shane_player_finish import bound_mesh,smoothstep
from shane_tailored_kit import chart,repair_fabric_edge_uvs


def shorts_weights(point,side=None,bridge=False):
    x,y,z=point
    hips=smoothstep(84,102,y)
    if bridge:hips=max(hips,.78)
    if side is None:
        left=smoothstep(-2.5,2.5,x)
    else:left=1.0 if side>0 else 0.0
    return {"mixamorig:Hips":hips,
            "mixamorig:LeftUpLeg":(1-hips)*left,
            "mixamorig:RightUpLeg":(1-hips)*(1-left)}


def make_pattern_shorts(fit,material,rects):
    vertices=[];faces=[];weights=[];waist=[]
    def vertex(p,side=None,bridge=False):
        i=len(vertices);vertices.append(Vector(p))
        if p[1]>=86 and not bridge:
            near,_,index,_=fit.target_surface.find_nearest(Vector(p))
            weights.append(fit.target_weights(near,index))
        else:weights.append(shorts_weights(p,side,bridge))
        return i
    def section(y,side=None):
        points=[p for p in fit.target_positions if abs(p.y-y)<1.7 and (side is None or p.x*side>.5)]
        lo=[min(p[i] for p in points) for i in (0,2)]
        hi=[max(p[i] for p in points) for i in (0,2)]
        cx=0 if side is None else (lo[0]+hi[0])*.5
        cz=(lo[1]+hi[1])*.5
        rx=max(abs(lo[0]),abs(hi[0]))+1.25 if side is None else (hi[0]-lo[0])*.5+1.25
        if side is not None:rx=min(rx,abs(cx)-.55)
        return cx,cz,rx,(hi[1]-lo[1])*.5+1.3
    # Clockwise from front centre through the player's left side.
    for y in (103,102.3,101.2,99.8,97,92,87):
        cx,cz,rx,rz=section(y)
        ring=[]
        for j in range(64):
            a=math.tau*j/64
            ease=.13*math.sin(a*9+y*.8)*(1-smoothstep(98,103,y))
            ring.append(vertex(((rx+ease)*math.sin(a),y,cz+(rz+ease)*math.cos(a))))
        waist.append(ring)
    for a,b in zip(waist,waist[1:]):
        for j in range(64):faces.append((a[j],a[(j+1)%64],b[(j+1)%64],b[j]))
    # Shared saddle runs front-to-back between the two upper leg openings.
    bottom=waist[-1];saddle=[bottom[0]]
    for j in range(1,8):
        t=j/8
        front=vertices[bottom[0]].z;back=vertices[bottom[32]].z
        saddle.append(vertex((0,87-3.6*math.sin(math.pi*t),front+(back-front)*t),bridge=True))
    saddle.append(bottom[32])
    upper={1:bottom[:33]+list(reversed(saddle[1:-1])),
           -1:bottom[32:]+[bottom[0]]+saddle[1:-1]}
    hems=[]
    for side in (1,-1):
        previous=upper[side]
        for y in (82,78,72,66,63.2,62.6,62):
            ring=[]
            cx,cz,rx,rz=section(y,side)
            for j in range(40):
                # The upper loop has 32 outer-half points and 8 saddle
                # points. Match their arc progression without twisted quads.
                if j<=32:a=math.pi*j/32
                else:a=math.pi+math.pi*(j-32)/8
                if side<0:a=math.pi-a
                # Player-left loop goes front -> outer-left -> back -> inner.
                x=cx+side*rx*math.sin(a)
                z=cz+rz*math.cos(a)
                p=Vector((x,y,z))
                # Modest folds at the leg opening, independent of skin form.
                fold=.10*math.sin(a*7+(y-62)*.7)*(1-smoothstep(76,84,y))
                p.x+=side*math.sin(a)*fold;p.z+=math.cos(a)*fold
                p.x=side*max(.55,p.x*side)
                ring.append(vertex(p,side=side))
            for j in range(40):
                faces.append((previous[j],previous[(j+1)%40],ring[(j+1)%40],ring[j]))
            previous=ring
        hems.append((side,previous))
    obj=bound_mesh("Kit_Shorts",vertices,faces,fit.rig,material,weights)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    score=0.0
    for f in bm.faces:
        p=f.calc_center_median()
        cx=0 if p.y>86 else math.copysign(10,p.x)
        radial=Vector((p.x-cx,0,p.z-1.5))
        score+=f.normal.dot(radial)*f.calc_area()
    if score<0:
        for f in bm.faces:f.normal_flip()
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    layer=obj.data.uv_layers.active
    panel_width=2*max(abs(v.co.x) for v in obj.data.vertices)
    for p in obj.data.polygons:
        _,cz,_,_=section(p.center.y)
        front=p.center.z>cz
        for li in p.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            layer.data[li].uv=chart(rects,"shorts_front" if front else "shorts_back",
                                   .5+(co.x if front else -co.x)/panel_width,(co.y-62)/41)
    repair_fabric_edge_uvs(obj.data,"shorts",rects)
    # Folded, open hem lips: retain a real leg opening, not a cap across it.
    tv=[];tf=[];tw=[];tu=[]
    for side,ring in hems:
        for j in range(40):
            a,b=ring[j],ring[(j+1)%40];pa,pb=vertices[a],vertices[b]
            na=Vector((pa.x-side*10,0,pa.z-1.5)).normalized()
            nb=Vector((pb.x-side*10,0,pb.z-1.5)).normalized()
            start=len(tv)
            tv.extend((pa,pb,pb-nb*.16+Vector((0,.8,0)),pa-na*.16+Vector((0,.8,0))))
            tf.append((start,start+1,start+2,start+3))
            tw.extend((weights[a],weights[b],weights[b],weights[a]))
            tu.extend([chart(rects,"black",u,v) for u,v in ((.2,.2),(.8,.2),(.8,.8),(.2,.8))])
    trim=bound_mesh("Kit_Shorts_FoldedHems",tv,tf,fit.rig,material,tw,tu)
    print("SHANE_PATTERN_SHORTS",len(vertices),"vertices",len(faces),"quads")
    return obj,trim
