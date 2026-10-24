"""Skull-fitted directional fibres for the four reference identities.

Opaque tapered fibres avoid stacked alpha overdraw. Hairline-clipped root
surfaces follow each player's coverage; bald crowns stay exposed.
"""
import bisect
import math
import random
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from player_head_finish import hair_regions


def portrait_root_material(identity):
    """Feathered directional undergrowth beneath the two fitted hero grooms."""
    width, height = 1024, 512
    u = (np.arange(width)+.5)/width
    y = 155.+24.*(np.arange(height)+.5)/height
    angle = np.tile(u*2*math.pi-math.pi, height)
    points = np.stack((8*np.sin(angle),np.repeat(y,width),8*np.cos(angle)-1),axis=1)
    coverage = hair_regions(points,identity)[:,0]
    rng = np.random.default_rng(69012 if identity=='shane_denham' else 69010)
    columns = rng.random(width)
    shifts = (3*np.sin(y*.7)).astype(int)
    grain = columns[(np.arange(width)[None,:]+shifts[:,None])%width].ravel()
    if identity=='john_orourke':
        # Crown undergrowth follows the side sweep. Vertical cylindrical
        # columns at the part made a visibly striped cap under the fibres.
        rows=rng.random(height)
        diagonal=(np.sin(u*math.pi*2)*6).astype(int)
        swept=rows[(np.arange(height)[:,None]+diagonal[None,:])%height]
        top=np.clip((y-169.8)/2.2,0,1)[:,None]
        grain=(grain.reshape(height,width)*(1-top)+swept*top).ravel()
    # PNG pigment is sRGB. Reusing a linear material factor here made the
    # imported undercoat nearly black (9/5/3 and 21/14/7 in the saved PNG).
    pigment = (.23,.16,.105) if identity=='shane_denham' else (.37,.285,.175)
    rgba = np.ones((width*height,4),dtype=np.float32)
    rgba[:,:3] = np.array(pigment)*(.8+.45*grain[:,None])
    rgba[:,3] = coverage
    name=identity+'_scalp_roots'
    from shane_player_finish import image_from_array
    image=image_from_array(name,rgba.reshape(height,width,4))
    material=bpy.data.materials.new('MAT_PortraitScalpRoots_'+identity)
    material.use_nodes=True
    material.surface_render_method='DITHERED'
    nodes=material.node_tree.nodes
    texture=nodes.new('ShaderNodeTexImage');texture.image=image
    shader=nodes['Principled BSDF']
    material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    material.node_tree.links.new(texture.outputs['Alpha'],shader.inputs['Alpha'])
    shader.inputs['Roughness'].default_value=.72
    shader.inputs['Specular IOR Level'].default_value=.20
    return material


def des_root_material():
    """Original directional undergrowth, feathered through a cylindrical UV map.

    A solid opaque scalp shell reads as a painted patch. Sparse clipped root
    clusters and the separate dimensional fibres leave skin visible between
    hairs, including the receding edge. No photographic lighting is baked in.
    """
    width,height=1024,512
    u=(np.arange(width)+.5)/width
    y=155.+24.*(np.arange(height)+.5)/height
    angle=np.tile(u*2*math.pi-math.pi,height)
    points=np.stack((8*np.sin(angle),np.repeat(y,width),8*np.cos(angle)-1),axis=1)
    coverage=hair_regions(points,'bordeaux_09')[:,0]
    rng=np.random.default_rng(69911)
    # Continuous density stays stable through mips. Binary noise made the
    # band look like scattered black dots in the native medium close-up.
    # Column-wise grain follows short hairs; fitted fibres supply relief.
    alpha=coverage.astype(np.float32)
    columns=rng.random(width)
    shift=(np.sin(y*1.7)*2).astype(np.int32)
    grain=columns[(np.arange(width)[None,:]+shift[:,None])%width].ravel()
    tone=.75+.45*grain+.06*rng.random(width*height)
    rgba=np.ones((width*height,4),dtype=np.float32)
    rgba[:,:3]=tone[:,None]*np.array((.045,.032,.023))
    rgba[:,3]=alpha
    name='Des_side_back_root_clusters'
    old=bpy.data.images.get(name)
    if old: bpy.data.images.remove(old)
    image=bpy.data.images.new(name,width=width,height=height,alpha=True)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw=str(Path(__file__).resolve().parents[3]/'games/beechlawn_rovers/assets/characters/textures/des_side_back_root_clusters.png')
    image.file_format='PNG'
    image.save()
    material=bpy.data.materials.new('MAT_Des_SideBackRoots')
    material.use_nodes=True
    material.surface_render_method='DITHERED'
    nodes=material.node_tree.nodes
    texture=nodes.new('ShaderNodeTexImage');texture.image=image
    shader=nodes['Principled BSDF']
    material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    material.node_tree.links.new(texture.outputs['Alpha'],shader.inputs['Alpha'])
    shader.inputs['Roughness'].default_value=.72
    shader.inputs['Specular IOR Level'].default_value=.20
    return material


def build_groom(head, rig, identity):
    from shane_player_finish import bound_mesh
    rng = random.Random(271022+sum(map(ord, identity)))
    names = ('Hair_Shane_ShortCropRoots', 'Hair_Shane_ShortCropCards')
    for name in names:
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
    colours = {
        'shane_denham': ((.038, .019, .009), (.057, .029, .014), (.078, .043, .022)),
        'john_orourke': ((.065, .030, .013), (.095, .048, .022), (.135, .075, .038)),
        'bordeaux_09': ((.012, .007, .004), (.020, .012, .007), (.034, .022, .013)),
        'des_feeney_sr': ((.055, .051, .046), (.115, .110, .100), (.235, .225, .210)),
    }[identity]
    # John's beard/brows retain their approved warm brown palette. His scalp
    # has a separate dark-blonde base and brighter wheat highlights.
    if identity == 'john_orourke':
        colours += ((.105, .068, .029), (.225, .158, .071), (.38, .285, .14))
    elif identity == 'bordeaux_09':
        # Scalp brown/occasional grey is distinct from his darker chin goatee.
        colours += ((.035, .024, .017), (.064, .046, .033), (.14, .13, .115))
    materials = []
    for index, colour in enumerate(colours):
        mat = bpy.data.materials.new(f'MAT_FittedHair_{identity}_{index}')
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = (*colour, 1)
        bsdf.inputs['Roughness'].default_value = .70 if identity != 'des_feeney_sr' else .76
        bsdf.inputs['Specular IOR Level'].default_value = .20
        materials.append(mat)
    mesh = head.data
    mesh.calc_loop_triangles()
    triangles = list(mesh.loop_triangles)
    surface = BVHTree.FromPolygons([v.co for v in mesh.vertices], [list(p.vertices) for p in mesh.polygons])

    # Evaluate each anatomical field once per vertex/triangle, not once per
    # corner, clipping bisection and attempted fibre. Scalar NumPy calls were
    # dominating the bounded exporter (over 80 seconds for one small groom).
    vertex_masks = hair_regions(np.asarray([tuple(v.co) for v in mesh.vertices]), identity)
    centres = np.asarray([tuple(sum((mesh.vertices[i].co for i in tri.vertices), Vector())/3) for tri in triangles])
    centre_masks = hair_regions(centres, identity)

    # Clip triangles to the smooth hairline field, instead of selecting whole
    # scalp polygons and leaving a jagged saw-tooth fringe along the forehead.
    root_points, root_faces, root_indices, root_tones = [], [], {}, []
    def root_region(kind):
        for tri in triangles:
            boundary=.025 if identity in ('bordeaux_09','shane_denham','john_orourke') and kind==0 else .5
            poly = [(mesh.vertices[i].co.copy(),float(vertex_masks[i,kind])-boundary) for i in tri.vertices]
            clipped = []
            for (start,a), (end,b) in zip(poly, poly[1:]+poly[:1]):
                if a >= 0:
                    clipped.append(start)
                if (a >= 0) != (b >= 0):
                    clipped.append(start.lerp(end, a/(a-b)))
            if len(clipped) < 3:
                continue
            face = []
            for p in clipped:
                key = (kind, *(round(v, 5) for v in p))
                if key not in root_indices:
                    near, normal, _, _ = surface.find_nearest(p)
                    lift=.027
                    if kind==0:
                        lift=.045 if identity=='bordeaux_09' else .09+(.30 if identity=='john_orourke' else .12)*max(0,min(1,(p.y-170)/5))
                    root_indices[key] = len(root_points)
                    root_points.append(near+normal*lift)
                face.append(root_indices[key])
            if len(set(face)) >= 3:
                root_faces.append(face)
                root_tones.append(3 if identity in ('john_orourke','bordeaux_09') and kind == 0 else 1 if identity == 'des_feeney_sr' else 0)
    if identity in ('shane_denham', 'john_orourke', 'bordeaux_09'): root_region(0)
    # Facial hair is pigment plus dense tapered fibres. An opaque fitted
    # undercoat produced a conspicuous solid trapezoid on the chin in Godot.
    if not root_faces:
        root_points = [Vector((0, 166, 0)), Vector((.02, 166, 0)), Vector((0, 166.02, 0))]
        root_faces = [(0, 1, 2)]
    root_uvs=[((math.atan2(p.x,p.z+1)+math.pi)/(2*math.pi),(p.y-155.)/24.) for p in root_points]
    roots = bound_mesh(names[0], root_points, root_faces, rig, materials[3] if identity == 'john_orourke' else materials[0],uvs=root_uvs)
    roots.data.materials.clear()
    if identity in ('bordeaux_09','shane_denham','john_orourke'):
        roots.data.materials.append(des_root_material() if identity=='bordeaux_09' else portrait_root_material(identity))
        for polygon in roots.data.polygons: polygon.material_index=0
    else:
        for mat in materials: roots.data.materials.append(mat)
        for polygon, tone in zip(roots.data.polygons,root_tones): polygon.material_index=tone
    roots['root_policy'] = 'clipped fitted hairline; exposed crowns for receded identities'

    distributions = [[], [], []]
    cumulative = [[], [], []]
    totals = [0., 0., 0.]
    for triangle_index,tri in enumerate(triangles):
        a, b, c = [mesh.vertices[i].co for i in tri.vertices]
        n = (b-a).cross(c-a)
        area = n.length*.5
        if area < 1e-8:
            continue
        centre = (a+b+c)/3
        weights = centre_masks[triangle_index]
        for kind, weight in enumerate(weights):
            lateral_beard = identity == 'john_orourke' and kind == 1
            if weight < .015 or (kind > 0 and not lateral_beard and n.z <= 0):
                continue
            totals[kind] += area*weight
            cumulative[kind].append(totals[kind])
            distributions[kind].append((a.copy(), b.copy(), c.copy(), *[float(vertex_masks[i,kind]) for i in tri.vertices]))
    counts = {
        'shane_denham': (6000, 0, 720), 'john_orourke': (5200, 12000, 680),
        'bordeaux_09': (5200, 13000, 680), 'des_feeney_sr': (1400, 6500, 640),
    }[identity]
    vertices, faces, face_materials, emitted_counts = [], [], [], []
    for kind, count in enumerate(counts):
        emitted, attempts = 0, 0
        if not distributions[kind]:
            assert count == 0, (identity, kind)
        while emitted < count and attempts < count*50:
            attempts += 1
            a, b, c, ma, mb, mc = distributions[kind][bisect.bisect_left(cumulative[kind], rng.random()*totals[kind])]
            r, t = math.sqrt(rng.random()), rng.random()
            root = a*(1-r)+b*r*(1-t)+c*r*t
            if rng.random() > ma*(1-r)+mb*r*(1-t)+mc*r*t:
                continue
            lateral_beard = identity == 'john_orourke' and kind == 1
            if kind > 0 and not lateral_beard:
                hit, _, _, _ = surface.ray_cast(Vector((root.x, root.y, 30)), Vector((0, 0, -1)))
                if hit is None or abs(hit.z-root.z) > .14:
                    continue
            near, normal, _, _ = surface.find_nearest(root)
            if normal is None:
                continue
            if lateral_beard:
                # A frontal visibility ray cannot validate the sides of a
                # curved jaw. Check outward locally, excluding hidden folds.
                radial = Vector((root.x, 0, root.z+1))
                if normal.dot(radial) <= 0:
                    continue
                hit, _, _, _ = surface.ray_cast(root+normal*.70, -normal, .90)
                if hit is None or (hit-root).length > .14:
                    continue
            if kind == 0:
                top = root.y > 170.7
                flow = Vector((-.85, -.10, -.32+.035*root.x)) if top else Vector((-.08*root.x, -1, -.22))
                if identity == 'john_orourke' and top:
                    # A true side part, with a short opposite sweep and
                    # curved fringe groups; a single direction made a helmet.
                    part = root.x-3.0
                    sweep = -.95 if part < 0 else .70
                    fringe = max(0,min(1,(root.z-3.5)/5))
                    flow = Vector((sweep, -.10-.22*fringe, -.55+.75*fringe))
                    flow += Vector((.10*math.sin(root.z*1.3),0,.12*math.sin(root.x*.85)))
                if identity == 'bordeaux_09':
                    flow = Vector((-.08*root.x, -.90, -.40))
                    length, width, lift, rows = rng.uniform(.55, 1.05), rng.uniform(.014, .027), .075, 4
                elif identity == 'des_feeney_sr':
                    length, width, lift, rows = rng.uniform(.20, .42), rng.uniform(.012, .024), .035, 3
                else:
                    length = rng.uniform(1.2, 2.4) if top else rng.uniform(.35, .80)
                    if identity == 'shane_denham':
                        length = rng.uniform(.65, 1.15) if top else rng.uniform(.25, .55)
                    if identity == 'john_orourke' and top:
                        length *= 1.65
                    width = rng.uniform(.055, .095) if top else rng.uniform(.018, .038)
                    lift = rng.uniform(.34, .70) if top else rng.uniform(.04, .12)
                    if identity == 'shane_denham' and top:
                        lift = rng.uniform(.14, .30)
                    if identity == 'shane_denham':
                        width = rng.uniform(.020,.045) if top else rng.uniform(.012,.025)
                        # Short irregular crop, without a uniform opaque cap.
                        flow += Vector((.16*math.sin(root.z*1.7),0,.12*math.sin(root.x*1.4)))
                    if identity == 'john_orourke' and top:
                        lift *= 1.65
                        width = rng.uniform(.030,.065)
                        if root.z>7.8: length *= .65
                    rows = 5
            elif kind == 1:
                # Moustache flows away from the philtrum, beard toward the jaw.
                mustache = root.y > 160.0
                if identity == 'john_orourke':
                    mustache = mustache and abs(root.x) < 3.2 and root.z > 8
                flow = Vector((math.copysign(.75, root.x), -.45, 0)) if mustache else Vector((-.045*root.x, -1, -.12))
                if lateral_beard and not mustache:
                    flow = Vector((-.10*root.x+.18*math.sin(root.y*2.4+root.z), -1,
                                   .20+.16*math.sin(root.x*1.5+root.y)))
                length = rng.uniform(.26, .52) if identity != 'des_feeney_sr' else rng.uniform(.35, .65)
                if identity == 'john_orourke':
                    # A clipped beard has a soft edge of shorter hairs; long
                    # equally dense fibres formed a rigid chin curtain.
                    coverage=ma*(1-r)+mb*r*(1-t)+mc*r*t
                    length *= .75+min(1.,coverage)*.65
                width, lift, rows = rng.uniform(.009, .019), rng.uniform(.015, .045), 3
                if identity == 'john_orourke':
                    lift = rng.uniform(.025, .10)
            else:
                flow = Vector((math.copysign(1, root.x), .12, 0))
                length, width, lift, rows = rng.uniform(.19, .36), rng.uniform(.011, .020), .018, 3
            tangent = flow-normal*flow.dot(normal)
            if tangent.length < 1e-7:
                continue
            tangent.normalize()
            across = normal.cross(tangent).normalized()
            start = len(vertices)
            curl = rng.uniform(-.10, .10) if kind == 0 else rng.uniform(-.015, .015)
            if identity == 'john_orourke' and kind == 0:
                tone = rng.choices((3, 4, 5), (35, 50, 15) if top else (65, 30, 5))[0]
            elif identity == 'bordeaux_09' and kind == 0:
                tone = rng.choices((3, 4, 5), (72, 24, 4))[0]
            else:
                tone = rng.choices((0, 1, 2), (24, 61, 15) if identity != 'des_feeney_sr' else (15, 40, 45))[0]
            for row in range(rows):
                u = row/(rows-1)
                path = root+tangent*length*u+across*curl*math.sin(math.pi*u)
                fitted, fitted_normal, _, _ = surface.find_nearest(path)
                if fitted is None:
                    fitted, fitted_normal = near, normal
                # Root and entire fibre follow the anatomical surface, avoiding
                # floating chin spikes when a straight strand crosses the jaw.
                base_lift = .09 if kind == 0 and identity in ('shane_denham', 'john_orourke') else .018
                if kind == 0 and identity == 'bordeaux_09':
                    base_lift = .065
                if kind == 0 and identity in ('shane_denham', 'john_orourke'):
                    crown = max(0, min(1, (fitted.y-170)/5))
                    base_lift += (.30 if identity == 'john_orourke' else .12)*crown+.04
                centre = fitted+fitted_normal*(base_lift+lift*math.sin(math.pi*u*.8))
                breadth = width*(.03+.97*(1-u)**.7)
                vertices.extend((centre-across*breadth*.5, centre+across*breadth*.5))
            for row in range(rows-1):
                n = start+row*2
                faces.append((n, n+1, n+3, n+2))
                face_materials.append(tone)
            emitted += 1
        assert emitted >= count*.98, (identity, kind, emitted, count)
        emitted_counts.append(emitted)
    cards = bound_mesh(names[1], vertices, faces, rig, materials[1])
    cards.data.materials.clear()
    for mat in materials:
        cards.data.materials.append(mat)
    for polygon, index in zip(cards.data.polygons, face_materials):
        polygon.material_index = index
    cards['groom_guides'] = sum(emitted_counts)
    cards['groom_regions'] = 'scalp, fitted facial hair, eyebrows'
    cards['finish_revision'] = 'four-head-reference-v2'
    from build_body_fullness import fullness as body_fullness
    for obj in (roots,cards):
        basis=obj.shape_key_add(name='Basis')
        shape=obj.shape_key_add(name='Fullness')
        for point,base in zip(shape.data,basis.data): point.co=body_fullness(base.co)
    print('FITTED_GROOM', identity, emitted_counts, len(faces)*2, 'fibre triangles', flush=True)
    return roots, cards
