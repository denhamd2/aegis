"""Original casket/ambulance visual assets; game-frame metres (+Y up).

Run blender -b --factory-startup --python tools/blender/props/match_containers.py
The existing GDScript props own location, collision and interaction. Body,
LidVisual and DoorLVisual/DoorRVisual use their existing local pivot frames.
Construction references: Braun Chief XL brochure (May 2025), Batesville metal
casket catalogue. No logos, downloaded geometry or reference textures copied.
"""
from __future__ import annotations
import math
import pathlib
import sys
import json
import numpy as np
import bpy
from mathutils import Vector
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'weapons'))
import weapon_kit as kit

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/props'
TEX = OUT / 'textures'


def atlas(name, specs):
    """One 512px base/ORM/normal texel budget; four or eight material cells.
    Fine grain/weave/rubber detail stays in maps, not tessellation.
    """
    rng = np.random.RandomState(kit.seed_of(name))
    n = 512
    cols, rows = (2, 2) if len(specs) <= 4 else (4, 2)
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
        base[y:y+ch, x:x+cw] = np.clip(np.array(color)[None,None,:] + mod[:,:,None], 0, 1)
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
            bsdf.inputs['Emission Strength'].default_value = .65
        mats.append(mat)
    return mats, cols, rows


class Assembly:
    def __init__(self, name, mats, cols, rows):
        self.root = kit.state_root(name)
        self.parts = [kit.WeaponPart(name + '_' + str(i)) for i in range(len(mats))]
        self.mats, self.cols, self.rows = mats, cols, rows
    def finish(self):
        for i, part in enumerate(self.parts):
            if not len(part.bm.verts):
                part.bm.free();continue
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
    part.bm.faces.new([part.vert(Vector(v)) for v in vertices])


def export(name, roots):
    # Keep editable native sources with portable relative texture paths.
    bpy.context.preferences.filepaths.save_version = 0
    source = pathlib.Path(__file__).resolve().parent / (name + '.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
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
    x=side*.98
    rr=[]
    for offset,r in [(-.14,.28),(-.14,.36),(-.10,.42),(.10,.42),(.14,.36),(.14,.28)]:
        rr.append([Vector((x+offset,.42+r*math.sin(k*math.tau/24),z+r*math.cos(k*math.tau/24))) for k in range(24)])
    loft(rubber,rr,True,True)
    outer=x+side*.145
    tube(metal,[(outer-side*.015,.42,z),(outer,.42,z)],.267,24)
    tube(metal,[(outer,.42,z),(outer+side*.025,.42,z)],.11,16)
    for k in range(8):
        a=k*math.tau/8;y=.42+math.sin(a)*.19;zz=z+math.cos(a)*.19
        tube(rubber,[(outer+side*.002,y,zz),(outer+side*.004,y,zz)],.035,8)
        a+=math.pi/8;y=.42+math.sin(a)*.085;zz=z+math.cos(a)*.085
        tube(metal,[(outer+side*.026,y,zz),(outer+side*.033,y,zz)],.012,6)


def arch_path(z, radius=.48, samples=12):
    return [( .42+radius*math.sin(math.pi-k*math.pi/samples), z+radius*math.cos(math.pi-k*math.pi/samples)) for k in range(samples+1)]


def ambulance():
    kit.reset()
    mats,cols,rows=atlas('ambulance',[
        ((.84,.85,.83),.30,0.,'paint'),((.63,.035,.045),.38,0.,'paint'),
        ((.035,.055,.07),.14,.25,'glass'),((.035,.036,.038),.83,0.,'rubber'),
        ((.61,.63,.65),.30,.95,'metal'),((.55,.58,.59),.62,0.,'vinyl'),
        ((.14,.23,.24),.70,0.,'vinyl'),((.86,.10,.08),.28,0.,'lamp')])
    body=Assembly('Body',mats,cols,rows);white,red,glass,rubber,metal,inside,upholstery,lamp=body.parts
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
        box(red,(side*1.101,1.79,-2.15),(.009,.25,4.18),.002)
        box(metal,(side*1.105,.94,-2.65),(.018,.10,3.1),.005)
        for za,zb in [(-4.1,-2.8),(-2.65,-1.65)]:
            tube(rubber,[(side*1.104,1.04,za),(side*1.104,1.65,za),(side*1.104,1.65,zb),
                         (side*1.104,1.04,zb),(side*1.104,1.04,za)],.004,6)
            box(metal,(side*1.12,1.50,(za+zb)/2),(.025,.035,.12),.006)
        # Shallow exterior fender lip follows the cutout.
        tube(white,[(side*1.10,y,z) for y,z in arch_path(-.9,.49)],.025,8)
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
    box(lamp,(0,2.38,-4.64),(1.48,.12,.20),.025)
    for side in [-1,1]:
        for z in [-.12,-4.05]:box(lamp,(side*.93,2.88,z),(.16,.14,.08),.015)
        tube(metal,[(side*.94,3.10,-4.15),(side*.94,3.10,-.15)],.018,10)
    # Real rear jamb/seals: walls stay outside the existing landing corridor.
    for side in [-1,1]:
        box(metal,(side*1.07,1.96,.015),(.06,2.20,.07),.015)
        box(rubber,(side*1.025,1.96,.045),(.022,2.14,.025),.006)
        box(lamp,(side*.98,1.13,.057),(.12,.25,.04),.015)
    box(metal,(0,.66,.17),(1.9,.07,.34),.012)
    # Diamond plate tread is a shallow geometry pattern, shared metal surface.
    for x in np.linspace(-.8,.8,12):
        tube(metal,[(x-.025,.704,.07),(x+.025,.704,.17)],.004,4)
    # Interior: storage and stretcher against left wall, bench on right;
    # open middle floor at bed(-.3,.91,-1.55) is reserved for the wrestler.
    box(inside,(-.92,1.80,-3.35),(.23,1.10,1.55),.03)
    for z in [-3.83,-3.34,-2.85]:
        box(glass,(-.79,1.99,z),(.012,.48,.42),.01)
        tube(metal,[(-.78,1.62,z-.10),(-.78,1.62,z+.10)],.009,6)
    box(inside,(.82,1.13,-2.55),(.42,.44,2.20),.025)
    box(upholstery,(.82,1.39,-2.55),(.43,.10,2.20),.035)
    box(upholstery,(1.02,1.63,-2.55),(.055,.40,2.20),.025)
    box(metal,(-.84,1.12,-2.80),(.36,.055,2.05),.018)
    box(upholstery,(-.84,1.19,-2.80),(.34,.10,1.98),.03)
    for z in [-3.55,-2.05]:
        tube(metal,[(-.98,.94,z),(-.70,1.10,z),(-.98,1.10,z),(-.70,.94,z)],.013,8)
    for z in [-1.2,-3.3]:box(inside,(0,3.035,z),(.65,.018,.24),.025)
    body.finish()
    # Rear leaves are authored in the exact pre-existing pivot frame.
    for side,label in [(-1,'L'),(1,'R')]:
        door=Assembly('Door'+label+'Visual',mats,cols,rows)
        white,red,glass,rubber,metal,inside,upholstery,lamp=door.parts
        cx=-side*.54
        box(white,(cx,1.125,0),(1.08,2.19,.065),.035)
        box(inside,(cx,1.125,-.039),(1.01,2.11,.018),.025)
        tube(rubber,[(cx-.50,.065,.038),(cx+.50,.065,.038),(cx+.50,2.185,.038),
                     (cx-.50,2.185,.038),(cx-.50,.065,.038)],.008,6)
        box(rubber,(cx,1.66,.044),(.76,.61,.02),.05)
        box(glass,(cx,1.66,.057),(.68,.53,.012),.045)
        box(glass,(cx,1.66,-.052),(.68,.53,.012),.045)
        box(red,(cx,.945,.041),(1.025,.25,.014),.005)
        # Unbranded red/white safety chevrons across the lower door.
        for k in range(5):
            xa=-.50+k*.205
            panel(red,[(cx+xa,.12,.043),(cx+xa+.09,.12,.043),(cx+xa+.19,.40,.043),(cx+xa+.10,.40,.043)])
        hx=-side*.94
        box(rubber,(hx,1.20,.052),(.11,.23,.018),.02)
        tube(metal,[(hx,1.13,.075),(hx,1.27,.075)],.015,10)
        for y in [.40,1.95]:
            tube(metal,[(0,y-.06,.02),(0,y+.06,.02)],.023,12)
            box(metal,(-side*.06,y,.035),(.12,.07,.018),.008)
        door.finish()
    export('ambulance',[])


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);TEX.mkdir(parents=True,exist_ok=True)
    casket();ambulance()
