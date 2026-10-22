"""Fitted swept auburn cap, directional locks and clipped beard for John."""
import bisect, math, random
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from john_player_finish import masks


def build_groom(head, rig, texture_directory=None):
    from shane_player_finish import bound_mesh
    rng=random.Random(69010)
    root_name='Hair_Shane_ShortCropRoots';cards_name='Hair_Shane_ShortCropCards'
    for name in (root_name,cards_name):
        old=bpy.data.objects.get(name)
        if old:bpy.data.objects.remove(old,do_unlink=True)
    root_material=bpy.data.materials.new('MAT_John_Auburn_Roots');root_material.use_nodes=True
    root_bsdf=root_material.node_tree.nodes.get('Principled BSDF')
    root_bsdf.inputs['Base Color'].default_value=(.095,.043,.018,1)
    root_bsdf.inputs['Roughness'].default_value=.86

    def hairline(p):
        angle=abs(math.atan2(p.x,p.z+1.0));side=max(0,min(1,(angle-.45)/1.0));side=side*side*(3-2*side)
        rear=max(0,min(1,(angle-1.55)/1.55));rear=rear*rear*(3-2*rear)
        # High forehead, softly breaking across the right temple, with a
        # lower ear/rear boundary from the supplied side and back views.
        return 170.0+.55*max(0,min(1,-p.x/3.0))-.30*max(0,min(1,p.x/2.4))-2.8*side-2.15*rear+.20*math.sin(p.x*1.4)+.08*math.sin(p.x*3.1)

    source=head.data
    scalp_faces=[list(p.vertices) for p in source.polygons if p.center.y>=hairline(p.center)-.28 and (abs(p.center.x)<8.4 or p.center.y>170)]
    ids=sorted({i for f in scalp_faces for i in f});remap={i:n for n,i in enumerate(ids)}
    root_points=[source.vertices[i].co.copy() for i in ids]
    roots=bound_mesh(root_name,root_points,[[remap[i] for i in f] for f in scalp_faces],rig,root_material,
        uvs=[(.5+math.atan2(p.x,p.z+1.0)/(2*math.pi),.82) for p in root_points])
    sub=roots.modifiers.new('John_Scalp_Silhouette_Smooth','SUBSURF');sub.levels=1
    with bpy.context.temp_override(object=roots,active_object=roots):bpy.ops.object.modifier_apply(modifier=sub.name)
    surface=BVHTree.FromPolygons([v.co for v in source.vertices],[list(p.vertices) for p in source.polygons])
    for v in roots.data.vertices:
        near,normal,_,_=surface.find_nearest(v.co)
        crown=max(0,min(1,(v.co.y-169.0)/6.0))
        # Root mass adds restrained height over the crown but stays fitted at
        # the temple and nape, so the silhouette does not become a helmet.
        v.co=near+normal*(.16+.42*crown)+Vector((0,.30*crown,0))
    roots.data.update();roots.data.calc_loop_triangles()
    roots['root_policy']='smoothed anatomical scalp shell under the raised clump groom; irregular swept hairline'

    hair_colors=((.115,.047,.020,1),(.16,.066,.029,1),(.21,.092,.043,1),(.27,.132,.066,1))
    beard_colors=((.20,.085,.033,1),(.25,.112,.044,1),(.30,.145,.060,1),(.36,.185,.082,1))
    materials=[]
    for i,color in enumerate(hair_colors+beard_colors):
        mat=bpy.data.materials.new(('MAT_John_Auburn_%02d'%i) if i<4 else ('MAT_John_Beard_%02d'%(i-4)))
        mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Roughness'].default_value=.82
        bsdf.inputs['Specular IOR Level'].default_value=.10;materials.append(mat)

    roots.data.calc_loop_triangles();scalp_tris=list(roots.data.loop_triangles);scalp_cum=[];scalp_total=0.0
    for tri in scalp_tris:
        a,b,c=[roots.data.vertices[i].co for i in tri.vertices]
        scalp_total+=(b-a).cross(c-a).length*.5;scalp_cum.append(scalp_total)
    source.calc_loop_triangles();beard_tris=[];beard_cum=[];beard_total=0.0
    for tri in source.loop_triangles:
        a,b,c=[source.vertices[i].co for i in tri.vertices]
        area=(b-a).cross(c-a).length*.5
        if area<1e-8:continue
        weight=masks((a+b+c)/3)[1]
        if weight<.025:continue
        beard_total+=area*weight;beard_cum.append(beard_total);beard_tris.append(tri)

    vertices=[];faces=[];face_materials=[];counts=[0,0]
    for kind,count in ((0,1500),):
        tris,cum,total=(scalp_tris,scalp_cum,scalp_total) if kind==0 else (beard_tris,beard_cum,beard_total)
        assert tris and total>0,'John groom has no fitted sampling surface'
        emitted=0;attempts=0
        while emitted<count and attempts<count*32:
            attempts+=1;tri=tris[bisect.bisect_left(cum,rng.random()*total)]
            mesh=roots.data if kind==0 else source
            a,b,c=[mesh.vertices[i].co for i in tri.vertices]
            r=math.sqrt(rng.random());t=rng.random();root=a*(1-r)+b*r*(1-t)+c*r*t
            if kind==0:
                near,normal,_,_=surface.find_nearest(root)
                if normal is None:continue
                anchor=root  # the root is already lifted off the scalp shell
                top=root.y>170.2
                flow=Vector((-.82+rng.uniform(-.28,.28),rng.uniform(-.16,.18),.38+rng.uniform(-.28,.28))) if top else Vector((-.12*root.x,-1,-.20))
                length=rng.uniform(.90,1.85) if top else rng.uniform(.42,.80)
                breadth=rng.uniform(.13,.22) if top else rng.uniform(.08,.14)
                lift=rng.uniform(.08,.20) if top else rng.uniform(.05,.13)
                rows=6;mat_index=rng.choices(range(4),(17,46,31,6))[0]
            else:
                if rng.random()>masks(root)[1]:continue
                near,normal,_,_=surface.find_nearest(root)
                if normal is None:continue
                anchor=near
                flow=Vector((-.10*root.x,-1.0,-.20));length=rng.uniform(.20,.34);breadth=rng.uniform(.025,.045);lift=rng.uniform(.020,.050)
                rows=4;mat_index=4+rng.choices(range(4),(24,48,24,4))[0]
            tangent=flow-normal*flow.dot(normal)
            if tangent.length<1e-7:continue
            tangent.normalize();across=normal.cross(tangent).normalized();start=len(vertices)
            curve=rng.uniform(-.13,.13) if kind==0 else rng.uniform(-.018,.018)
            for row in range(rows):
                u=row/(rows-1)
                arc=curve*math.sin(u*math.pi)
                vol=(.035*math.sin(u*math.pi*.82) if kind==0 and root.y>170.2 else .025*math.sin(u*math.pi))
                centre=anchor+normal*(.025+lift*math.sin(u*math.pi*.78)+vol)+tangent*length*u+across*arc
                taper=(1-.74*u*u) if kind==0 else ((1-u)**.68+.02)
                width=breadth*taper
                for col in (-1,0,1):
                    vertices.append(centre+across*col*width*.5+normal*(1-abs(col))*width*.10)
            for row in range(rows-1):
                for col in range(2):
                    n=start+row*3+col;faces.append((n+3,n+4,n+1,n));face_materials.append(mat_index)
            emitted+=1;counts[kind]+=1
    cards=bound_mesh(cards_name,vertices,faces,rig,materials[1])
    cards.data.materials.clear()
    for mat in materials:cards.data.materials.append(mat)
    for poly,index in zip(cards.data.polygons,face_materials):poly.material_index=index
    cards['groom_guides']=sum(counts);cards['regions']='side swept auburn clumps; low-density fine ginger beard hairs over continuous pigment'
    cards['normal_policy']='smooth shaped clumps and fine tapered fibres; no projected portrait or alpha-card stack'
    print('JOHN_GROOM',counts,'guides;',len(faces)*2,'triangles; fitted scalp and beard')
    return roots,cards
