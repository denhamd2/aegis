"""R8 reference-region macro groom from editable OWNED native Bezier guides.

This is the mass/silhouette stage. Closed, rounded bundle cores deliberately
precede fibre/alpha polish. No legacy guide paths or external character reads.
"""
import io,json,math,pathlib
import bpy
import numpy as np
from PIL import Image
from mathutils import Vector
from mathutils.bvhtree import BVHTree

COLLECTION='COL_Kenny_HeroGuides'
MID=.004

def surface(body,k):
    points=[k.game(body.matrix_world@v.co) for v in body.data.vertices]
    return BVHTree.FromPolygons(points,[list(p.vertices) for p in body.data.polygons],all_triangles=True)

def on_scalp(point,bvh,lift):
    q,n,_,_=bvh.find_nearest(Vector(point))
    if q is None:return np.array(point)
    if n.dot(q-Vector((MID,1.72,-.105)))<0:n=-n
    return np.array(q+n*lift)

def author(k):
    """Initial region blockout only. Normal builds read the editable curves."""
    if bpy.data.collections.get(COLLECTION):raise RuntimeError('Native hero guides already exist; edit them instead of silently resetting authoring.')
    col=bpy.data.collections.new(COLLECTION);bpy.context.scene.collection.children.link(col)
    col.hide_render=True;col.hide_viewport=True
    bvh=surface(bpy.data.objects['Body'],k);rng=np.random.default_rng(141108)
    counter={};regions={}
    def guide(region,target,points,radius,steps,sides,lifts=None,tone=None):
        count=counter.get(region,0);counter[region]=count+1
        pts=np.array(points,float)
        if lifts is not None:
            for i,lift in enumerate(lifts):
                if lift is not None:pts[i]=on_scalp(pts[i],bvh,lift)
        curve=bpy.data.curves.new('KennyHero_'+region+'_'+str(count),'CURVE');curve.dimensions='3D';curve.resolution_u=12
        spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(pts)-1)
        for point,p in zip(spline.bezier_points,pts):
            point.co=k.native(Vector(p));point.handle_left_type=point.handle_right_type='AUTO'
        obj=bpy.data.objects.new('CRV_HairGuide_'+region+'_'+str(count).zfill(2),curve);col.objects.link(obj)
        obj['region']=region;obj['target_mesh']=target;obj['radius_m']=radius;obj['steps']=steps;obj['sides']=sides
        obj['tip_taper_start']=float(rng.uniform(.70,.82));obj['flattening']=float(rng.uniform(.42,.64) if region in ['front_crest','crown_occiput'] else rng.uniform(.50,.72))
        obj['tone']=int(tone if tone is not None else rng.choice([0,1,2],p=[.46,.39,.15]));obj['root_mix_start']=float(rng.uniform(.08,.24))
        obj['normal_authority']='Editable Bezier control points/handles in this native file; no legacy guides.'
        regions.setdefault(region,[]).append(obj.name)
    # Front hairline -> low rolling crest -> rearward crown. Wide shallow S
    # changes are authored in the centre paths, not in alternating strip edges.
    for i,x in enumerate(np.linspace(-.067,.070,15)):
        side=-1 if x<-.008 else 1;phase=i*.69;w=.006*math.sin(phase)
        pts=[[MID+x,1.788+.008*math.cos(phase),-.013-.016*abs(x)/.07],
             [MID+x+side*.010,1.824,-.043],
             [MID+x-side*.013+w,1.849,-.086],
             [MID+x+side*.009,1.833,-.140],
             [MID+x-side*.006,1.794,-.194]]
        guide('front_crest','CurlSlick',pts,float(rng.uniform(.0075,.0100)),30,7,[.004,.009,.012,.011,.009])
    # Three staggered crown rows curl across the occiput and overlap the crest.
    for row in range(3):
        for j,x in enumerate(np.linspace(-.068,.070,7)):
            direction=-1 if (j+row)%2 else 1;shift=(row-1)*.004
            pts=[[MID+x+shift,1.842-row*.014,-.080-row*.023],
                 [MID+x+direction*.015,1.844-row*.020,-.125-row*.018],
                 [MID+x-direction*.010,1.811-row*.024,-.184-row*.009],
                 [MID+x+direction*.010,1.764-row*.020,-.216],
                 [MID+x-direction*.006,1.707-row*.016,-.218]]
            guide('crown_occiput','CurlSlick',pts,float(rng.uniform(.0080,.0110)),30,7,[.007,.012,.013,.011,.009])
    # Temple flow is deliberately tighter on viewer-right/wearer-left. Bulk
    # continues BEHIND the ear; forelock-side roots are looser and asymmetric.
    for side in [-1,1]:
        for j in range(5):
            spread=(j-2)*.003;offset=.004 if side<0 else 0
            pts=[[MID+side*(.058+j*.003),1.788+spread,-.025],
                 [MID+side*(.079+offset),1.784+spread,-.064],
                 [MID+side*(.093+offset),1.758+spread,-.112],
                 [MID+side*(.098+offset),1.714+spread,-.161]]
            guide('temple_sweep','CurlSlick',pts,.0065 if side<0 else .0057,22,6,[.003,.006,.007,.006],tone=1)
    # Close forelock with nested S/C returns, no outward freestanding handle.
    for j in range(5):
        d=(j-2)*.003
        pts=[[-.030+d,1.824,-.033],[-.060+d,1.832,-.019],[-.089+d,1.802,-.011],
             [-.086+d,1.775,-.019],[-.103+d,1.750,-.052],[-.096+d,1.723,-.090]]
        guide('close_forelock','CurlRinglets',pts,.0078-j*.00035,28,7,[.006,.009,None,None,None,None],tone=0)
    # Side masses arc back from the temples, preserving the readable ear.
    for side in [-1,1]:
        for j in range(9):
            d=(j-4)*.004;loose=.006 if side<0 else 0
            pts=[[MID+side*(.075+loose),1.781+d,-.105],
                 [MID+side*(.101+loose),1.746+d,-.165],
                 [MID+side*(.114+loose),1.690+d,-.192],
                 [MID+side*(.097+loose),1.633+d,-.218],
                 [MID+side*(.112+loose),1.576+d,-.215],
                 [MID+side*(.090+loose),1.510+d,-.242]]
            guide('side_fall','CurlRinglets',pts,float(rng.uniform(.0065,.0090)),30,6,[.005,.008,None,None,None,None])
    # Broad alternating C/S bends, different phase/lengths and staggered tips.
    # Their control knots are not identical helices or a flat nape curtain.
    for j,x in enumerate(np.linspace(-.082,.084,20)):
        sign=-1 if j%2 else 1;shift=float(rng.uniform(-.018,.018));end=float(rng.uniform(1.455,1.515))
        pts=[[MID+x,1.777+shift,-.174],
             [MID+x+sign*.012,1.727+shift,-.217],
             [MID+x-sign*.014,1.674+shift,-.240],
             [MID+x+sign*.013,1.620+shift,-.222],
             [MID+x-sign*.011,1.568+shift,-.250],
             [MID+x+sign*.008,end+.024,-.246],
             [MID+x-sign*.003,end,-.255]]
        guide('nape_fall','CurlRinglets',pts,float(rng.uniform(.0060,.0085)),34,6,[.005,.008,None,None,None,None,None])
    # Dark inner coverage is itself rounded layered flow, rather than an opaque
    # rectangular plate. It sits inside the authored outer C/S masses.
    for j,x in enumerate(np.linspace(-.076,.080,12)):
        sign=-1 if j%2 else 1
        pts=[[MID+x,1.747,-.198],[MID+x+sign*.010,1.685,-.219],
             [MID+x-sign*.008,1.616,-.224],[MID+x+sign*.007,1.548,-.237],
             [MID+x,1.515+(j%3)*.012,-.239]]
        guide('inner_coverage','CurlUndercoat',pts,.0085,18,5,[.004,None,None,None,None],tone=2)
    # A dedicated opaque atlas region belongs to the macro core geometry.
    # Fibre columns remain available for later detail, not required for mass.
    im=bpy.data.images[k.data('KennyOutputMaps')['kenny_curl_cards.png']]
    atlas=Image.open(io.BytesIO(bytes(im.packed_file.data))).convert('RGBA');pixels=np.array(atlas)
    pixels[:,:atlas.width//8,:]=255;atlas=Image.fromarray(pixels,'RGBA')
    image=k.store_map('kenny_hero_macro_atlas.png',atlas);image.name='HeroMap::kenny_curl_cards.png';image['output_name']='kenny_curl_cards.png'
    k.text('KennyHeroGroom',{'round':8,'guide_collection':COLLECTION,'regions':regions,'atlas':image.name,
           'stage':'Rounded macro mass blockout; fibre/alpha polish deliberately pending actual neutral silhouette gate.',
           'authority':'Editable native Bezier guides, radius/profile attributes and this neutral sweep helper. No legacy guide paths.'})

def sample_curve(obj,steps,k):
    points=obj.data.splines[0].bezier_points;path=[];segments=len(points)-1
    # Oversample then resample by arc length so travelling roots and long falls
    # do not inherit abrupt per-segment sample density changes.
    for i in range(segments):
        controls=np.array([k.game(obj.matrix_world@p)[:] for p in [points[i].co,points[i].handle_right,points[i+1].handle_left,points[i+1].co]])
        for t in np.linspace(0,1,18,endpoint=(i==segments-1)):
            path.append((1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3])
    path=np.array(path);arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(path,axis=0),axis=1))];arc/=max(arc[-1],1e-8)
    return np.array([np.interp(np.linspace(0,1,steps),arc,path[:,a]) for a in range(3)]).T

def build(k):
    info=k.data('KennyHeroGroom');body=bpy.data.objects['Body'];bvh=surface(body,k)
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');bundles={name:[] for name in ['CurlSlick','CurlRinglets','CurlUndercoat']}
    for obj in bpy.data.collections[COLLECTION].objects:
        if obj.type=='CURVE':bundles[obj['target_mesh']].append(obj)
    audit={'round':8,'stage':info['stage'],'editable_guide_counts':{},'region_counts':{},'mesh_triangles':{},'maximum_x_envelope_m':0.,'minimum_y_m':10.}
    for name,objects in bundles.items():
        verts=[];faces=[];uvs=[];colours=[]
        for obj in sorted(objects,key=lambda o:o.name):
            audit['region_counts'][obj['region']]=audit['region_counts'].get(obj['region'],0)+1
            steps=int(obj['steps']);sides=int(obj['sides']);path=sample_curve(obj,steps,k);radius=float(obj['radius_m']);flat=float(obj['flattening'])
            # Valid contact/conservative volume: roots and paths cannot tunnel
            # through the accepted head or shoulders between guide knots.
            for i,p in enumerate(path):
                q,n,_,_=bvh.find_nearest(Vector(p))
                if q is not None:
                    if n.dot(q-Vector((MID,1.63,-.105)))<0:n=-n
                    signed=(Vector(p)-q).dot(n)
                    if signed<radius*.65:path[i]=np.array(q+n*(radius*.65))
            previous=None;start=len(verts)
            tip=np.array(k.linear([(196,171,129),(139,111,80),(92,70,48)][int(obj['tone'])]));root=np.array(k.linear((55,42,30)))
            for i,p in enumerate(path):
                t=i/(steps-1);tangent=path[min(i+1,steps-1)]-path[max(0,i-1)];tangent/=max(np.linalg.norm(tangent),1e-9)
                if previous is None:previous=np.array([p[0]-MID,max(.02,p[1]-1.72),p[2]+.105]);previous/=max(np.linalg.norm(previous),1e-9)
                normal=previous-tangent*np.dot(previous,tangent)
                if np.linalg.norm(normal)<.01:normal=np.cross(tangent,[1,0,0])
                normal/=max(np.linalg.norm(normal),1e-9);previous=normal;across=np.cross(tangent,normal);across/=max(np.linalg.norm(across),1e-9)
                taper=1-.88*float(k.smooth((t-float(obj['tip_taper_start']))/(1-float(obj['tip_taper_start']))))
                r=radius*(.70+.30*math.sin(math.pi*t))*taper
                tone=float(k.smooth((t-float(obj['root_mix_start']))/.72));colour=np.clip(root+(tip-root)*tone,0,1)
                for j in range(sides):
                    a=math.tau*j/sides;q=p+across*(r*math.cos(a))+normal*(r*flat*math.sin(a))
                    verts.append(tuple(k.native(Vector(q))));uvs.append((.022+.078*j/sides,1-t));colours.append(list(colour)+[t])
                    audit['maximum_x_envelope_m']=max(audit['maximum_x_envelope_m'],abs(float(q[0]-MID)));audit['minimum_y_m']=min(audit['minimum_y_m'],float(q[1]))
                if i:
                    a=start+(i-1)*sides;b=a+sides
                    for j in range(sides):n=(j+1)%sides;faces.append((a+j,a+n,b+n,b+j))
            end=start+(steps-1)*sides
            for j in range(1,sides-1):
                faces.append((start,start+j,start+j+1));faces.append((end,end+j+1,end+j))
        obj=k.hair_mesh(name,verts,faces,uvs,colours,arm)
        audit['editable_guide_counts'][name]=len(objects);audit['mesh_triangles'][name]=sum(len(f.vertices)-2 for f in obj.data.polygons)
    outputs=k.data('KennyOutputMaps');outputs['kenny_curl_cards.png']=info['atlas'];k.text('KennyOutputMaps',outputs)
    # Material helper binds this stable compatibility name; keep its image
    # pointer on the owned hero atlas without destroying the R6 fallback atlas.
    for name in ['CurlSlick','CurlRinglets','CurlUndercoat']:
        k.hair_material(bpy.data.objects[name])
        mat=bpy.data.objects[name].data.materials[0]
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE':node.image=bpy.data.images[info['atlas']]
    k.text('KennyHeroGroomAudit',audit);out=k.evidence_dir(8);out.mkdir(parents=True,exist_ok=True)
    (out/'groom_source_audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('KENNY_HERO_GROOM',json.dumps(audit))
