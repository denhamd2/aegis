"""Fitted short side/back hair, goatee and brow fibres for Boardeaux Des.

Skin-root pigment comes from des_player_finish.masks. Raised opaque tapered
fibres supply relief; there is no visible polygon cap or alpha-layer stack.
"""
import bisect,math,random
import bpy
from mathutils import Vector
from des_player_finish import masks


def build_groom(head,rig,texture_directory):
    from shane_player_finish import bound_mesh
    rng=random.Random(69016)
    mat=bpy.data.materials.new('MAT_Hair_Des_ShortDarkBrown');mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(.009,.0055,.0035,1)
    bsdf.inputs['Roughness'].default_value=.78
    bsdf.inputs['Specular IOR Level'].default_value=.18
    names=('Hair_Shane_ShortCropRoots','Hair_Shane_ShortCropCards')
    for name in names:
        old=bpy.data.objects.get(name)
        if old:bpy.data.objects.remove(old,do_unlink=True)
    # Stable runtime slot replaces the common cap. This tiny internal triangle
    # is intentionally inside the cranium; only rooted fibres are visible.
    roots=bound_mesh(names[0],[(0,166,0),(.03,166,0),(0,166.03,0)],[(0,1,2)],rig,mat)
    roots['root_policy']='smooth anatomical pigment on Skin_Head; no visible hard-edged cap'
    mesh=head.data;mesh.calc_loop_triangles()
    distributions=[[],[],[]];sums=[[],[],[]];totals=[0.0]*3
    for tri in mesh.loop_triangles:
        a,b,c=[mesh.vertices[i].co for i in tri.vertices]
        normal=(b-a).cross(c-a)
        area=normal.length*.5
        if area<1e-8:continue
        centre=(a+b+c)/3
        weights=masks(centre)
        for k,weight in enumerate(weights):
            if weight<.035:continue
            if k>0 and centre.z<5.0:continue
            totals[k]+=area*weight
            sums[k].append(totals[k]);distributions[k].append((a.copy(),b.copy(),c.copy(),normal.normalized()))
    vertices=[];faces=[];counts=[]
    for kind,count in enumerate((2600,4400,240)):
        assert distributions[kind],f'No groom sampling region {kind}'
        emitted=0;attempts=0
        while emitted<count and attempts<count*25:
            attempts+=1
            a,b,c,normal=distributions[kind][bisect.bisect_left(sums[kind],rng.random()*totals[kind])]
            r=math.sqrt(rng.random());t=rng.random();p=a*(1-r)+b*r*(1-t)+c*r*t
            if rng.random()>masks(p)[kind]:continue
            if kind==0:
                flow=Vector((-.06*p.x,-1.0,-.28));length=rng.uniform(.16,.34);width=rng.uniform(.018,.035);lift=rng.uniform(.025,.065)
            elif kind==1:
                flow=Vector((-.025*p.x,-1.0,.12));length=rng.uniform(.22,.48);width=rng.uniform(.014,.027);lift=rng.uniform(.035,.090)
            else:
                flow=Vector((1 if p.x>0 else -1,.12,0));length=rng.uniform(.14,.25);width=rng.uniform(.012,.025);lift=.025
            tangent=flow-normal*flow.dot(normal)
            if tangent.length<1e-7:continue
            tangent.normalize();across=normal.cross(tangent).normalized()
            start=len(vertices)
            for row in range(3):
                u=row/2;centre=p+normal*(.025+lift*math.sin(u*math.pi*.8))+tangent*length*u
                w=width*(1-.94*u)
                vertices.extend([centre-across*w*.5,centre+across*w*.5])
            for row in range(2):
                n=start+row*2;faces.append((n,n+1,n+3,n+2))
            emitted+=1
        counts.append(emitted)
    cards=bound_mesh(names[1],vertices,faces,rig,mat)
    cards['groom_guides']=sum(counts);cards['regions']='receded side/back scalp, goatee/moustache, brows'
    cards['normal_policy']='tapered raised fibres with geometric normals'
    print('DES_GROOM',counts,'guides;',len(faces)*2+1,'triangles; no alpha layers')
    return roots,cards
