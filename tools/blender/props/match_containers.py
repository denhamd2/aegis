"""Original casket/ambulance visual assets; game-frame metres (+Y up).

Run blender -b --factory-startup --python tools/blender/props/match_containers.py
The existing GDScript props own location, collision and interaction. Body,
LidVisual and DoorLVisual/DoorRVisual use their existing local pivot frames.
Construction references: owner-supplied WWE 2K ambulance images (72065.jpg and
open-door views), Braun Chief XL brochure (May 2025), Batesville casket catalogue.
All geometry and textures are project-authored; no downloaded model data.
The ambulance .blend opens assembled at its established door hinges. GLB export
temporarily restores identity roots because AmbulanceProp supplies those pivots.
"""
from __future__ import annotations
import math
import pathlib
import sys
import json
import argparse
import numpy as np
import bpy
from mathutils import Vector
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'weapons'))
import weapon_kit as kit

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/props'
TEX = OUT / 'textures'


def atlas(name, specs):
    """One 512px base/ORM/normal texel budget; up to twelve material cells.
    Fine grain/weave/rubber detail stays in maps, not tessellation.
    """
    rng = np.random.RandomState(kit.seed_of(name))
    n = 512
    cols, rows = (2, 2) if len(specs) <= 4 else (4, math.ceil(len(specs)/4))
    base = np.zeros((n, n, 3), np.float32)
    orm = np.ones_like(base)
    height = np.zeros((n, n), np.float32)
    cw, ch = n // cols, n // rows
    for i, (color, rough, metal, kind) in enumerate(specs):
        x, y = (i % cols) * cw, (i // cols) * ch
        yy, xx = np.mgrid[:ch, :cw]
        noise = rng.uniform(-1, 1, (ch, cw))
        weave = np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)
        mod = noise * .008
        relief = noise * .003
        rv = np.full((ch, cw), rough, np.float32)
        if kind == 'cloth':
            mod += weave * .018
            relief = weave * .08
            rv += weave * .04
        elif kind == 'metal':
            brush = np.repeat(rng.uniform(-1, 1, (ch, 1)), cw, axis=1)
            rv += brush * .035
            relief = brush * .018
        elif kind == 'rubber':
            relief = .05 * np.sin(xx * .35) * np.sin(yy * .35)
            rv += noise * .035
        elif kind == 'vinyl':
            relief = noise * .035
            rv += noise * .025
        elif kind == 'lamp':
            relief = .04 * np.cos(xx * .7)
        tile_color=np.array(color)[None,None,:] + mod[:,:,None]
        if name=='ambulance' and kind in ['lamp','lens']:
            sx,sy=xx/(cw-1),yy/(ch-1)
            rib=np.cos(sx*math.pi*28)
            cross=np.cos(sy*math.pi*18)
            edge=np.power(np.maximum(np.sin(sx*math.pi)*np.sin(sy*math.pi),0),.18)
            # Moulded optics: the edge absorbs light, fine prisms vary specular
            # response. This is authored optical detail, not baked arena lighting.
            factor=.70+.24*edge+.035*rib+.025*cross
            tile_color=np.array(color)[None,None,:]*factor[:,:,None]+noise[:,:,None]*.003
            relief=.25*rib+.10*cross
            rv=np.clip(rough+.035*rib+.025*cross,.09,.45)
        if name=='ambulance' and kind=='rubber':
            # Left quarter: quiet sidewall bead rings. Right: fine chevron tread.
            # Explicit tyre UVs use these regions; seals sample a quiet point.
            sx,sy=xx/cw,yy/ch
            tread_mask=sx>.28
            phase=sy*math.pi*56+np.abs(sx-.64)*math.pi*14
            grooves=np.power(np.maximum(np.cos(phase),0),6)
            relief=np.where(tread_mask,-.26*grooves,.025*np.cos(sx*math.pi*100))
            rv=np.where(tread_mask,rough-.04*grooves,rough+.02*noise)
            tile_color=np.array(color)[None,None,:]+noise[:,:,None]*.002
        base[y:y+ch, x:x+cw] = np.clip(tile_color, 0, 1)
        orm[y:y+ch, x:x+cw, 1] = np.clip(rv, .06, 1)
        orm[y:y+ch, x:x+cw, 2] = metal
        height[y:y+ch, x:x+cw] = relief
    mats = []
    for i, (_, _, _, kind) in enumerate(specs):
        # Separate atlas cells into equally small material tiles. This retains
        # the total texel budget and avoids unrelated paint/metal colours
        # bleeding together in mipmaps around small bevels and wheel edges.
        x, y = (i % cols) * cw, (i // cols) * ch
        tile = [TEX / f'{name}_{i}_{suffix}.png' for suffix in ['base','orm','normal']]
        kit.save_rgb(base[y:y+ch, x:x+cw], tile[0])
        kit.save_rgb(orm[y:y+ch, x:x+cw], tile[1])
        kit.save_rgb(kit.normal_from_height(height[y:y+ch, x:x+cw], 1.2), tile[2])
        mat = kit.pbr_material(f'{name}_{i}_{kind}', *tile, normal_strength=.5)
        bsdf = mat.node_tree.nodes['Principled BSDF']
        if kind == 'paint':
            bsdf.inputs['Coat Weight'].default_value = .25
            bsdf.inputs['Coat Roughness'].default_value = .22
        if kind == 'lamp':
            tex = next(n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image.filepath.endswith('_base.png'))
            mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = .24 if name=='ambulance' else .65
        mats.append(mat)
    return mats, cols, rows


class Assembly:
    def __init__(self, name, mats, cols, rows):
        self.root = kit.state_root(name)
        self.parts = [kit.WeaponPart(name + '_' + str(i)) for i in range(len(mats))]
        if mats[0].name.startswith('ambulance_'):
            # Allocate face data before faces exist; adding it during authoring
            # would invalidate the BMFace reference supplied to authored_uv().
            for part in self.parts:part.bm.faces.layers.int.new('authored_uv')
        self.mats, self.cols, self.rows = mats, cols, rows
    def finish(self):
        for i, part in enumerate(self.parts):
            if not len(part.bm.verts):
                part.bm.free();continue
            # Keep explicitly authored optical/tyre UVs through cube projection
            # and welding. Surface-position keys are independent of face winding.
            uv_saved={}
            flag=part.bm.faces.layers.int.get('authored_uv')
            key=lambda p:tuple(round(float(x),4) for x in p)
            if flag:
                for face in part.bm.faces:
                    if face[flag]:
                        uv_saved[tuple(sorted(key(v.co) for v in face.verts))]={
                            key(l.vert.co):tuple(l[part.uv].uv) for l in face.loops}
            obj = kit.add_mesh(self.root, part, self.mats[i], smooth=True, uv_scale=1.0, auto_smooth_deg=55)
            # Keep continuous planar coordinates across adjacent grid faces;
            # remapping every quad separately made upholstered panels look tiled.
            uv = obj.data.uv_layers.active.data
            us = [item.uv.x for item in uv]
            vs = [item.uv.y for item in uv]
            u0,v0=min(us),min(vs)
            du,dv=max(max(us)-u0,.001),max(max(vs)-v0,.001)
            for item in uv:
                old = item.uv.copy()
                item.uv = ((old.x-u0)/du, (old.y-v0)/dv)
            if self.mats[i].name.startswith('ambulance_') and i==3:
                for item in uv:item.uv=(.015,.015)
            for poly in obj.data.polygons:
                face_key=tuple(sorted(key(obj.data.vertices[v].co) for v in poly.vertices))
                saved=uv_saved.get(face_key)
                if saved:
                    for li in poly.loop_indices:
                        pos=key(obj.data.vertices[obj.data.loops[li].vertex_index].co)
                        uv[li].uv=saved[pos]

        return self.root


def loop(hw, hl, radius, y, n=4, centre_x=0):
    out=[]
    for sx,sz,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
        cx,cz=sx*(hw-radius),sz*(hl-radius)
        for k in range(n+1):
            a=math.radians(start + 90*k/n)
            out.append(Vector((centre_x+cx+radius*math.cos(a),y,cz+radius*math.sin(a))))
    return out


def loft(part, rings, cap_bottom=False, cap_top=False):
    verts=[[part.vert(v) for v in ring] for ring in rings]
    for a,b in zip(verts,verts[1:]):
        for k in range(len(a)):
            j=(k+1)%len(a);part.quad(a[k],a[j],b[j],b[k])
    if cap_bottom:part.bm.faces.new(list(reversed(verts[0])))
    if cap_top:part.bm.faces.new(verts[-1])


def box(part, at, size, bevel=.008):
    part.box(Vector(at), Vector(size), bevel=bevel, bevel_segments=2)


def tube(part, points, radius=.012, sides=10, caps=True):
    part.tube([Vector(p) for p in points],radius,sides,caps=caps)


def ellipse(part, centre, size, segments=20, rings=10):
    c=Vector(centre);s=Vector(size)
    rr=[]
    for j in range(rings+1):
        phi=math.pi*(j+.015)/(rings+.03)
        rr.append([c+Vector((s.x*math.sin(phi)*math.cos(2*math.pi*k/segments),
                            s.y*math.cos(phi),s.z*math.sin(phi)*math.sin(2*math.pi*k/segments))) for k in range(segments)])
    loft(part,rr,True,True)


def polygon_prism(part, yz, halfwidth):
    rings=[[Vector((x,y,z)) for y,z in yz] for x in [-halfwidth,halfwidth]]
    loft(part,rings,True,True)


def panel(part, vertices):
    return part.bm.faces.new([part.vert(Vector(v)) for v in vertices])


def authored_uv(part, face, coords):
    flag=part.bm.faces.layers.int.get('authored_uv') or part.bm.faces.layers.int.new('authored_uv')
    face[flag]=1
    for item,coord in zip(face.loops,coords):item[part.uv].uv=coord


def export(name, roots):
    # Keep editable native sources with portable relative texture paths.
    bpy.context.preferences.filepaths.save_version = 0
    source = pathlib.Path(__file__).resolve().parent / (name + '.blend')
    # Native source opens assembled. Runtime supplies these existing hinges;
    # clear only for export, without duplicate preview meshes or extra GLB nodes.
    preview=[]
    if name=='ambulance':
        for side,label in [(-1,'L'),(1,'R')]:
            root=bpy.data.objects['Door'+label+'Visual']
            preview.append((root,root.location.copy()))
            root.location=kit.to_blender(Vector((side*1.1,.85,0)))
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    for root,location in preview:root.location=location
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_apply=True,export_yup=True,
        export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=True)
    deps=bpy.context.evaluated_depsgraph_get();tri=0;surfaces=0
    for obj in bpy.data.objects:
        if obj.type=='MESH':
            mesh=obj.evaluated_get(deps).to_mesh();mesh.calc_loop_triangles();tri+=len(mesh.loop_triangles);surfaces+=1
    print('CONTAINER_EXPORT',name,'triangles',tri,'surfaces',surfaces,'bytes',path.stat().st_size)
    assert tri <= (8000 if name=='casket' else 20000), (name,tri)


def casket():
    kit.reset()
    mats,cols,rows=atlas('casket',[
        ((.032,.028,.035),.23,0.,'paint'), ((.72,.53,.24),.27,.92,'metal'),
        ((.83,.78,.68),.54,0.,'cloth'), ((.18,.025,.045),.85,0.,'cloth')])
    body=Assembly('Body',mats,cols,rows);lac,brass,satin,drape=body.parts
    # Full rounded profile, hollow opening; top footprint preserves game WIDTH/LENGTH.
    profiles=[(.32,.35,1.02,.07),(.35,.40,1.09,.065),(.39,.40,1.09,.065),
              (.405,.365,1.045,.075),(.65,.375,1.055,.075),(.765,.39,1.075,.065),
              (.79,.405,1.09,.065),(.82,.405,1.09,.065),(.82,.34,1.025,.055),(.43,.34,1.025,.055)]
    loft(lac,[loop(hw,hl,r,y) for y,hw,hl,r in profiles],True,True)
    # Draped bier has a real scalloped hem and hanging folds.
    drings=[]
    for y,amp in [(.025,.025),(.10,.02),(.29,.008),(.32,0)]:
        ring=loop(.445,1.12,.055,y,n=8)
        drings.append([Vector((v.x*(1+amp*math.cos(k*math.pi*.75)),v.y+.008*math.sin(k*1.5),v.z)) for k,v in enumerate(ring)])
    loft(drape,drings,True,True)
    # Side padding stops below the rim and follows the inner wall.
    for side in [-1,1]:
        satin.grid_panel(Vector((side*.335,.47,-.98)),Vector((0,0,1.96)),Vector((0,.31,0)),
            40,3,.008,lambda s,t:.009*math.sin(s*math.pi*28)*math.sin(t*math.pi))
    box(satin,(0,.445,0),(.66,.06,2.01),.025)
    ellipse(satin,(0,.52,.80),(.265,.065,.18),20,8)
    # Continuous swing bars with three round rosettes and curved brackets per side.
    for side in [-1,1]:
        x=side*.438
        tube(brass,[(x,.535,-.88),(x,.535,.88)],.015,12)
        for z in [-.75,0,.75]:
            tube(brass,[(side*.38,.57,z),(side*.402,.57,z)],.037,12)
            tube(brass,[(side*.40,.575,z),(side*.43,.56,z),(x,.535,z)],.010,8)
    # Hinge barrels remain behind the clear opening.
    for z in [-.75,0,.75]:tube(brass,[(-.393,.808,z-.055),(-.393,.808,z+.055)],.014,10)
    body.finish()
    lid=Assembly('LidVisual',mats,cols,rows);lac,brass,satin,_=lid.parts
    # Coordinates relative to the established hinge (-.39,.82,0).
    loft(lac,[loop(hw,hl,r,y,centre_x=.39) for y,hw,hl,r in
        [(.0,.405,1.09,.065),(.025,.405,1.09,.065),(.05,.385,1.07,.08),
         (.10,.34,1.01,.10),(.145,.22,.91,.11)]],True,True)
    # Recessed padded interior panel, pleated across its width.
    satin.grid_panel(Vector((.075,-.008,-.97)),Vector((.63,0,0)),Vector((0,0,1.94)),
        18,24,.012,lambda s,t:.018*math.sin(math.pi*s)*math.sin(math.pi*t)+.004*math.sin(t*math.pi*32))
    tube(brass,loop(.365,1.045,.055,-.014,centre_x=.39)+[loop(.365,1.045,.055,-.014,centre_x=.39)[0]],.004,6)
    lid.finish();export('casket',[body.root,lid.root])


def wheel(parts, side, z):
    rubber,metal=parts[3],parts[4]
    x=side*.98;segments=32
    profile=[(-.14,.28),(-.14,.36),(-.10,.42),(.10,.42),(.14,.36),(.14,.28)]
    rr=[[rubber.vert(Vector((x+offset,.42+r*math.sin(k*math.tau/segments),
                            z+r*math.cos(k*math.tau/segments)))) for k in range(segments)]
        for offset,r in profile]
    for j,(a,b) in enumerate(zip(rr,rr[1:])):
        for k in range(segments):
            kk=(k+1)%segments
            face=rubber.bm.faces.new([a[k],a[kk],b[kk],b[k]])
            if j==2:ua,ub=.29,.99
            else:ua,ub=[.04+.20*(profile[q][1]-.28)/.14 for q in [j,j+1]]
            authored_uv(rubber,face,[(ua,k/segments),(ua,(k+1)/segments),
                                     (ub,(k+1)/segments),(ub,k/segments)])
    rubber.bm.faces.new(list(reversed(rr[0])));rubber.bm.faces.new(rr[-1])
    outer=x+side*.145
    def hub_ring(axial,r,cy=.42,cz=z,n=24):
        return [Vector((outer+side*axial,cy+r*math.sin(k*math.tau/n),cz+r*math.cos(k*math.tau/n))) for k in range(n)]
    # Rolled outer rim, dished steel face and proud centre cap catch broad
    # highlights; vents sit in short recessed collars rather than painted dots.
    loft(metal,[hub_ring(a,r) for a,r in [(-.014,.267),(.008,.252),(.026,.155),(.040,.108)]],True,True)
    for k in range(8):
        a=k*math.tau/8;y=.42+math.sin(a)*.19;zz=z+math.cos(a)*.19
        loft(metal,[hub_ring(.023,.037,y,zz,8),hub_ring(.030,.035,y,zz,8),
                    hub_ring(.031,.029,y,zz,8)])
        panel(rubber,hub_ring(.024,.029,y,zz,8))
        a+=math.pi/8;y=.42+math.sin(a)*.085;zz=z+math.cos(a)*.085
        panel(rubber,hub_ring(.041,.019,y,zz,8))
        tube(metal,[(outer+side*.044,y,zz),(outer+side*.059,y,zz)],.014,6)


def arch_path(z, radius=.48, samples=12):
    return [( .42+radius*math.sin(math.pi-k*math.pi/samples), z+radius*math.cos(math.pi-k*math.pi/samples)) for k in range(samples+1)]


def ambulance():
    kit.reset()
    mats,cols,rows=atlas('ambulance',[
        ((.86,.87,.84),.28,0.,'paint'),((.63,.028,.038),.32,0.,'paint'),
        ((.035,.043,.047),.17,.15,'glass'),((.028,.028,.030),.83,0.,'rubber'),
        ((.76,.78,.79),.22,1.,'metal'),((.77,.73,.56),.55,0.,'vinyl'),
        ((.29,.055,.065),.64,0.,'vinyl'),((.55,.58,.57),.16,.12,'lens'),
        ((.85,.83,.12),.39,0.,'paint'),((.98,.45,.018),.20,0.,'lamp')])
    body=Assembly('Body',mats,cols,rows)
    white,red,glass,rubber,metal,inside,upholstery,clear,yellow,amber=body.parts

    def detail_box(part, at, size, bevel=.003):
        # Small manufactured fittings need a single chamfer, not a many-ring bevel.
        part.box(Vector(at),Vector(size),bevel=bevel,bevel_segments=1)

    def rounded_panel(part, centre, width, height, radius, axis='rear'):
        # A thin window's corner radius must not be clamped by its 1 mm depth.
        cx,cy,cz=centre;points=[];coords=[]
        radius=min(radius,width*.49,height*.49)
        for sx,sy,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
            for j in range(5):
                a=math.radians(start+j*22.5)
                u=sx*(width/2-radius)+radius*math.cos(a)
                v=sy*(height/2-radius)+radius*math.sin(a)
                points.append((cx+u,cy+v,cz) if axis=='rear' else (cx,cy+v,cz+u))
                coords.append((u/width+.5,v/height+.5))
        face=panel(part,points)
        if part.name.endswith(('_7','_9')):authored_uv(part,face,coords)

    def rear_profile(part,x,y,rings):
        outlines=[]
        for z,w,h,r in rings:
            points=[];r=min(r,w*.49,h*.49)
            for sx,sy,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
                for j in range(5):
                    a=math.radians(start+j*22.5)
                    points.append(Vector((x+sx*(w/2-r)+r*math.cos(a),
                                          y+sy*(h/2-r)+r*math.sin(a),z)))
            outlines.append(points)
        loft(part,outlines)

    def clip_rect(poly,xlo,xhi,ylo,yhi):
        for axis,limit,greater in [(0,xlo,True),(0,xhi,False),(1,ylo,True),(1,yhi,False)]:
            output=[]
            for a,b in zip(poly,poly[1:]+poly[:1]):
                ina=(a[axis]>=limit) if greater else (a[axis]<=limit)
                inb=(b[axis]>=limit) if greater else (b[axis]<=limit)
                if ina:output.append(a)
                if ina!=inb:
                    t=(limit-a[axis])/(b[axis]-a[axis])
                    output.append(tuple(a[k]+t*(b[k]-a[k]) for k in range(2)))
            poly=output
            if len(poly)<3:return []
        return poly

    def rear_lens(parts,x,y,z,w,h,kind):
        metal,rubber=parts[4],parts[3]
        rounded_panel(metal,(x,y,z),w+.026,h+.026,.035)
        rounded_panel(rubber,(x,y,z+.003),w+.010,h+.010,.029)
        rounded_panel(parts[kind],(x,y,z+.006),w,h,.025)

    def tread(part, plane, lo, hi, y, z):
        # Dense alternating 90-degree lozenges: a raised tread pattern rather
        # than parallel scratches. Only four triangles per shallow stamp.
        for row in range(6):
            for k in range(32):
                x=lo+(hi-lo)*(k+.5)/32 + (.012 if row%2 else 0)
                v=(row+.5)*(.21/6 if plane=='rear' else .27/6)
                pts=[(-.021,-.009),(-.014,-.016),(.021,.009),(.014,.016)]
                if (row+k)%2:pts=[(-b,a) for a,b in pts]
                if plane=='rear':
                    vv=[part.vert(Vector((x+a,y+v+b,z))) for a,b in pts]
                    c=part.vert(Vector((x,y+v,z+.0035)))
                else:
                    vv=[part.vert(Vector((x+a,y,z+v+b))) for a,b in pts]
                    c=part.vert(Vector((x,y+.0035,z+v)))
                for j in range(4):part.tri(vv[j],vv[(j+1)%4],c)
    # Real module skin, rounded roof and sill. Rear remains an unobstructed opening.
    box(inside,(0,.85,-2.15),(2.2,.08,4.3),.015)
    box(white,(0,1.96,-4.27),(2.2,2.20,.06),.018)
    white.grid_panel(Vector((-1.1,3.08,-4.3)),Vector((2.2,0,0)),Vector((0,0,4.3)),12,2,.06,
        lambda s,t:-.055*math.sin(math.pi*s))
    # Side wall profile includes a true rear wheel opening, not a wheel pasted onto a box.
    for side in [-1,1]:
        profile=[(.43,-4.3),(.43,-1.38)]+arch_path(-.9)[1:-1]+[(.43,-.42),(.43,0),(3.06,0),(3.06,-4.3)]
        p=kit.WeaponPart('side');polygon_prism(p,profile,.028)
        # Transfer the small thickness extrusion to the sides.
        for v in p.bm.verts:
            # Blender X equals game X.
            v.co.x+=side*1.07
        # Merge authored vertices through bmesh by copying the evaluated positions.
        mapping={v:white.bm.verts.new(v.co) for v in p.bm.verts}
        for f in p.bm.faces:white.bm.faces.new([mapping[v] for v in f.verts])
        p.bm.free()
        # Recessed cabinet seams and belt stripe terminate before the rear jamb.
        # Major livery is paint, without shared lamp emission or baked warm light.
        for ya,yb in [(1.44,1.79)]:
            for za,zb in ([(-4.25,-1.40),(-.40,-.045)] if ya<.9 else [(-4.25,-.045)]):
                panel(red,[(side*1.102,ya,za),(side*1.102,yb,za),
                           (side*1.102,yb,zb),(side*1.102,ya,zb)])
        # Broad lower red skirt follows the wheel aperture, with fine white
        # separator lines. The cutout remains a genuine hole in the module.
        panel(red,[(side*1.102,1.04,-4.25),(side*1.102,1.04,-.045),
                   (side*1.102,.55,-.045)]+
                  [(side*1.102,max(.55,y),z) for y,z in reversed(arch_path(-.9,.495))]+
                  [(side*1.102,.55,-4.25)])
        for ya,yb in [(.72,.746),(.965,.986)]:
            for za,zb in [(-4.25,-1.41),(-.39,-.045)]:
                panel(white,[(side*1.105,ya,za),(side*1.105,yb,za),
                             (side*1.105,yb,zb),(side*1.105,ya,zb)])
        # Stepped taper at the rear is the strongest side-view identity feature.
        for k in range(7):
            ya=1.81+k*.155;yb=ya+.126
            za=-1.26+k*.128;zb=za+.095
            panel(red,[(side*1.103,ya,za),(side*1.103,yb,zb),
                       (side*1.103,yb,-.045),(side*1.103,ya,-.045)])
        detail_box(metal,(side*1.108,.88,-2.65),(.018,.075,3.1),.003)
        for za,zb in [(-4.1,-2.8),(-2.65,-1.65)]:
            tube(rubber,[(side*1.104,1.04,za),(side*1.104,1.65,za),(side*1.104,1.65,zb),
                         (side*1.104,1.04,zb),(side*1.104,1.04,za)],.004,6)
            box(metal,(side*1.12,1.50,(za+zb)/2),(.025,.035,.12),.006)
        # Shallow exterior fender lip follows the cutout.
        tube(white,[(side*1.10,y,z) for y,z in arch_path(-.9,.49)],.025,8)
        # Forward side service door, tall glazed aperture and functional hardware.
        tube(metal,[(side*1.109,.96,-3.76),(side*1.109,2.89,-3.76),
                    (side*1.109,2.89,-2.77),(side*1.109,.96,-2.77)],.009,6)
        rounded_panel(metal,(side*1.114,2.12,-3.24),.53,.78,.07,'side')
        rounded_panel(rubber,(side*1.117,2.12,-3.24),.50,.75,.065,'side')
        rounded_panel(glass,(side*1.121,2.12,-3.24),.46,.71,.06,'side')
        detail_box(metal,(side*1.123,1.28,-2.94),(.025,.16,.035),.009)
        # Small high utility/vent panel and chrome lamp housings.
        detail_box(metal,(side*1.114,2.67,-1.95),(.025,.27,.30),.018)
        detail_box(glass,(side*1.130,2.67,-1.95),(.008,.21,.24),.009)
        for z in [-3.95,-1.30]:
            detail_box(metal,(side*1.114,2.68,z),(.022,.17,.075),.008)
        for y,z,w,h in [(2.72,-4.12,.22,.23),(1.18,-2.60,.18,.11),(1.69,-.26,.22,.11)]:
            rounded_panel(metal,(side*1.113,y,z),w+.035,h+.035,.035,'side')
            rounded_panel(amber,(side*1.118,y,z),w,h,.028,'side')
        # Readable flag stripes and canton, kept separate from reflective paint.
        for k in range(7):
            ya=1.94+k*.032
            panel(red,[(side*1.114,ya,-4.17),(side*1.114,ya+.016,-4.17),
                       (side*1.114,ya+.016,-3.84),(side*1.114,ya,-3.84)])
        panel(glass,[(side*1.115,2.045,-4.17),(side*1.115,2.15,-4.17),
                     (side*1.115,2.15,-4.035),(side*1.115,2.045,-4.035)])
        for a in range(4):
            for b in range(3):
                yy=2.059+a*.024;zz=-4.153+b*.045
                panel(white,[(side*1.116,yy,zz),(side*1.116,yy+.008,zz),
                             (side*1.116,yy+.008,zz+.01),(side*1.116,yy,zz+.01)])
        wheel(body.parts,side,-.9)
        wheel(body.parts,side,-4.9)
    # Cab side silhouette: sloping hood, raked windshield, lower roof than module.
    # True front wheel openings in both flanks.
    profile=[(.35,-5.9),(.35,-5.38)]+arch_path(-4.9)[1:-1]+[(.35,-4.42),(.35,-4.3),
             (2.25,-4.3),(2.23,-4.94),(1.34,-5.43),(1.20,-5.90)]
    for side in [-1,1]:
        panel(white,[(side*1.045,y,z) for y,z in profile])
        # Lower door and side glass follow the A pillar, not rectangular decals.
        panel(glass,[(side*1.051,1.48,-5.30),(side*1.051,2.14,-4.93),
                     (side*1.051,2.14,-4.39),(side*1.051,1.48,-4.39)])
        tube(rubber,[(side*1.056,1.45,-5.33),(side*1.056,2.17,-4.94),(side*1.056,2.17,-4.36),
                     (side*1.056,.95,-4.36),(side*1.056,.95,-4.43)],.008,6)
        box(metal,(side*1.067,1.28,-4.53),(.025,.035,.17),.006)
        tube(white,[(side*1.05,y,z) for y,z in arch_path(-4.9,.49)],.03,8)
        # Small mirror on a braced arm, folded close to the existing width envelope.
        tube(rubber,[(side*1.04,1.57,-5.18),(side*1.14,1.62,-5.12)],.018,8)
        box(rubber,(side*1.14,1.69,-5.12),(.06,.22,.14),.025)
        box(glass,(side*1.175,1.69,-5.12),(.006,.16,.10),.008)
    # Hood, raked glazed windscreen and roof form a continuous closed upper shell.
    for z0,y0,z1,y1,w0,w1 in [(-5.90,1.20,-5.43,1.34,1.045,1.045),
                             (-5.43,1.34,-4.94,2.23,1.045,1.045),
                             (-4.94,2.23,-4.30,2.25,1.045,1.045)]:
        panel(white,[(-w0,y0,z0),(w0,y0,z0),(w1,y1,z1),(-w1,y1,z1)])
    panel(glass,[(-.94,1.44,-5.385),(.94,1.44,-5.385),(.94,2.15,-4.991),(-.94,2.15,-4.991)])
    # Windshield surround / wipers / divided grille and lamps.
    tube(rubber,[(-.96,1.425,-5.395),(.96,1.425,-5.395),(.96,2.17,-4.982),
                 (-.96,2.17,-4.982),(-.96,1.425,-5.395)],.012,8)
    for x in [-.5,.38]:tube(rubber,[(x,1.45,-5.40),(x+.29,1.49,-5.38)],.009,6)
    box(white,(0,.86,-5.88),(2.09,.66,.05),.025)
    box(rubber,(0,.88,-5.916),(1.17,.33,.025),.025)
    for y in [.77,.84,.91,.98]:box(metal,(0,y,-5.934),(1.10,.025,.025),.005)
    box(metal,(0,.50,-5.88),(2.15,.16,.14),.025)
    for side in [-1,1]:
        box(metal,(side*.80,1.03,-5.925),(.32,.20,.04),.02)
        box(inside,(side*.80,1.03,-5.95),(.28,.15,.012),.015)
    # Low profile light bar, roof rub rails and restrained emergency lamps.
    box(rubber,(0,2.30,-4.64),(1.58,.06,.22),.02)
    box(amber,(0,2.38,-4.64),(1.48,.12,.20),.025)
    for side in [-1,1]:
        for z in [-4.05]:box(amber,(side*.93,2.88,z),(.16,.14,.08),.015)
        # Rounded corner caps / lower rub rail provide a manufactured module edge.
        tube(white,[(side*1.06,.88,.005),(side*1.06,3.015,.005)],.050,10)
        tube(white,[(side*1.06,3.04,-4.22),(side*1.06,3.04,-.045)],.045,10)
        for a,b in [(.42,.70),(.85,.89)]:
            def roof_y(x):return 3.112+.055*math.sin(math.pi*(x+1.1)/2.2)
            panel(red,[(side*a,roof_y(side*a),-4.23),(side*b,roof_y(side*b),-4.23),
                       (side*b,roof_y(side*b),-.06),(side*a,roof_y(side*a),-.06)])
    # Left rear side ladder: two curved return rails, seven rungs, discrete mounts.
    # Detail projects 100 mm from the shell; no change to gameplay/collision frames.
    for z in [-.83,-.17]:
        path=[(-1.195,.57,z),(-1.195,3.07,z)]
        for j in range(1,7):
            a=j*math.pi/12
            path.append((-1.095-.10*math.cos(a),3.07+.10*math.sin(a),z))
        path.append((-.985,3.17,z))
        tube(metal,path,.022,10)
        for y in [.77,1.85,2.82]:
            tube(metal,[(-1.10,y,z),(-1.195,y,z)],.014,8)
            detail_box(metal,(-1.115,y,z),(.018,.075,.065),.004)
    for y in np.linspace(.66,2.88,8):
        tube(metal,[(-1.195,y,-.83),(-1.195,y,-.17)],.017,10)
    # Real rear jamb/seals: walls stay outside the existing landing corridor.
    for side in [-1,1]:
        box(metal,(side*1.07,1.96,.015),(.06,2.20,.07),.015)
        box(rubber,(side*1.025,1.96,.045),(.022,2.14,.025),.006)
        rear_lens(body.parts,side*.965,2.75,.070,.235,.34,9)
    # References with doors open show a fixed brow. Only the authored leaf top
    # changes; established runtime hinges, collision, bed and lip stay untouched.
    # A formed sloping inner return clears the measured escape-head trajectory:
    # the compartment-side lower edge rises 160 mm while the outside bank face
    # remains at y 2.66 / z +.068. This changes no gameplay collision or timing.
    polygon_prism(white,[(2.82,-.032),(3.06,-.032),(3.06,.068),(2.66,.068)],1.06)
    for x in [-.45,0,.45]:
        rear_lens(body.parts,x,2.955,.079,.285,.145,9)
        # Projecting die-cast flood pod with a rolled bright bezel, recessed
        # dark reflector well and smaller pale prismatic face.
        rounded_panel(rubber,(x,2.745,.080),.333,.203,.045)
        rear_profile(metal,x,2.745,[(.083,.324,.194,.042),(.096,.310,.180,.040),
                                   (.112,.278,.150,.035),(.119,.253,.128,.027)])
        rounded_panel(glass,(x,2.745,.120),.253,.128,.027)
        rounded_panel(clear,(x,2.745,.124),.238,.113,.024)
    for x in [-.97,-.46,0,.46,.97]:
        rear_lens(body.parts,x,3.025,.078,.075,.035,1)
    # Substantial full-width formed bumper: vertical plate riser, tread and lights.
    detail_box(metal,(0,.69,.18),(2.20,.25,.34),.015)
    detail_box(metal,(0,.558,.21),(2.22,.055,.39),.012)
    tread(metal,'rear',-1.04,1.04,.58,.354)
    tread(metal,'top',-1.04,1.04,.818,.015)
    for side in [-1,1]:
        for k,kind in enumerate([7,9,1]):
            x=side*(.62+k*.17)
            rear_lens(body.parts,x,.685,.359,.14,.14,kind)
    # Interior: storage and stretcher against left wall, bench on right;
    # open middle floor at bed(-.3,.91,-1.55) is reserved for the wrestler.
    box(inside,(-.92,1.80,-3.35),(.23,1.10,1.55),.03)
    # Forward bulkhead double cabinet stays a full metre beyond the reserved
    # victim corridor. The handles and relief are fixed furniture, not doors AI
    # can interact with, matching the warm storage face visible through the rear.
    box(inside,(0,1.88,-4.105),(1.92,1.86,.25),.025)
    for x in [-.47,.47]:
        detail_box(rubber,(x,1.89,-3.972),(.905,1.73,.012),.006)
        box(inside,(x,1.89,-3.952),(.876,1.70,.025),.018)
        hx=x-math.copysign(.31,x)
        tube(metal,[(hx,1.69,-3.930),(hx,1.98,-3.930)],.013,8)
        for y in [1.72,1.95]:
            tube(metal,[(hx,y,-3.934),(hx,y,-3.910)],.015,8)
    for z in [-3.83,-3.34,-2.85]:
        box(glass,(-.79,1.99,z),(.012,.48,.42),.01)
        tube(metal,[(-.78,1.62,z-.10),(-.78,1.62,z+.10)],.009,6)
    box(inside,(.82,1.13,-2.55),(.42,.44,2.20),.025)
    box(upholstery,(.82,1.42,-2.55),(.44,.16,2.20),.045)
    box(upholstery,(.99,1.75,-2.55),(.105,.65,2.20),.035)
    for z in [-3.10,-2.55,-2.00]:
        tube(upholstery,[(.615,1.505,z),(.99,1.505,z)],.004,6)
    box(metal,(-.84,1.12,-2.80),(.36,.055,2.05),.018)
    box(upholstery,(-.84,1.19,-2.80),(.34,.10,1.98),.03)
    for z in [-3.55,-2.05]:
        tube(metal,[(-.98,.94,z),(-.70,1.10,z),(-.98,1.10,z),(-.70,.94,z)],.013,8)
    for z in [-1.2,-3.3]:box(inside,(0,3.035,z),(.65,.018,.24),.025)
    body.finish()
    # Rear leaves are authored in the exact pre-existing pivot frame.
    for side,label in [(-1,'L'),(1,'R')]:
        door=Assembly('Door'+label+'Visual',mats,cols,rows)
        white,red,glass,rubber,metal,inside,upholstery,clear,yellow,amber=door.parts
        cx=-side*.54
        box(white,(cx,.92,0),(1.08,1.78,.065),.035)
        box(inside,(cx,.92,-.039),(1.01,1.70,.018),.025)
        tube(rubber,[(cx-.50,.065,.038),(cx+.50,.065,.038),(cx+.50,1.775,.038),
                     (cx-.50,1.775,.038),(cx-.50,.065,.038)],.008,6)
        rounded_panel(yellow,(cx,.92,.041),1.025,1.70,.025)
        # One coherent red/yellow V pattern in the closed-door world frame.
        xlo,xhi=cx-.51,cx+.51
        for k in range(-1,8):
            phase=k*.54
            # world X is side*1.1+local X; each leaf stays on its own side.
            def stripe_y(x):return phase-1.24*side*(side*1.1+x)
            poly=clip_rect([(xlo,stripe_y(xlo)),(xhi,stripe_y(xhi)),
                            (xhi,stripe_y(xhi)+.255),(xlo,stripe_y(xlo)+.255)],
                           xlo,xhi,.07,1.77)
            if poly:panel(red,[(x,y,.044) for x,y in poly])
        # Tall, lower glazing leaves space for the upper warning/flood bank.
        rounded_panel(rubber,(cx,1.10,.047),.550,.840,.078)
        rear_profile(metal,cx,1.10,[(.048,.544,.834,.077),(.055,.535,.825,.073),
                                   (.058,.509,.799,.065),(.055,.501,.791,.062)])
        for part,z,w,h,r in [(rubber,.059,.501,.791,.062),
                              (glass,.060,.48,.77,.058),(glass,-.052,.49,.78,.06)]:
            rounded_panel(part,(cx,1.10,z),w,h,r)
        hx=-side*.94
        box(rubber,(hx,1.20,.052),(.11,.23,.018),.02)
        tube(metal,[(hx,1.13,.075),(hx,1.27,.075)],.015,10)
        for y in [.40,1.65]:
            tube(metal,[(0,y-.06,.02),(0,y+.06,.02)],.023,12)
            box(metal,(-side*.06,y,.035),(.12,.07,.018),.008)
        # Exterior latch lever and threshold hardware read at the reference angle.
        for yy in [.22,1.57]:
            tube(metal,[(cx,yy,.057),(cx+.15,yy+.015,.057)],.012,8)
            tube(metal,[(cx-.025,yy,.052),(cx-.025,yy,.066)],.032,10)
        door.finish()
    export('ambulance',[])


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',choices=['ambulance','casket'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True);TEX.mkdir(parents=True,exist_ok=True)
    if args.only in [None,'casket']:casket()
    if args.only in [None,'ambulance']:ambulance()
