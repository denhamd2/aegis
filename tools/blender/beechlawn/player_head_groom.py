"""Skull-fitted directional fibres for the four reference identities.

Opaque tapered fibres avoid stacked alpha overdraw. Hairline-clipped root
surfaces are used only for full-haired players; bald crowns stay exposed.
"""
import bisect
import math
import random
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from player_head_finish import hair_regions


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

    def mask(p, kind):
        return float(hair_regions(tuple(p), identity)[0, kind])

    # Clip triangles to the smooth hairline field, instead of selecting whole
    # scalp polygons and leaving a jagged saw-tooth fringe along the forehead.
    root_points, root_faces, root_indices = [], [], {}
    if identity in ('shane_denham', 'john_orourke'):
        for tri in triangles:
            poly = [mesh.vertices[i].co.copy() for i in tri.vertices]
            clipped = []
            for start, end in zip(poly, poly[1:]+poly[:1]):
                a, b = mask(start, 0)-.5, mask(end, 0)-.5
                if a >= 0:
                    clipped.append(start)
                if (a >= 0) != (b >= 0):
                    lo, hi = 0., 1.
                    for _ in range(16):
                        middle = (lo+hi)*.5
                        value = mask(start.lerp(end, middle), 0)-.5
                        if (value >= 0) == (a >= 0):
                            lo = middle
                        else:
                            hi = middle
                    clipped.append(start.lerp(end, (lo+hi)*.5))
            if len(clipped) < 3:
                continue
            face = []
            for p in clipped:
                key = tuple(round(v, 5) for v in p)
                if key not in root_indices:
                    near, normal, _, _ = surface.find_nearest(p)
                    lift = .09+(.30 if identity == 'john_orourke' else .12)*max(0, min(1, (p.y-170)/5))
                    root_indices[key] = len(root_points)
                    root_points.append(near+normal*lift)
                face.append(root_indices[key])
            if len(set(face)) >= 3:
                root_faces.append(face)
    if not root_faces:
        root_points = [Vector((0, 166, 0)), Vector((.02, 166, 0)), Vector((0, 166.02, 0))]
        root_faces = [(0, 1, 2)]
    roots = bound_mesh(names[0], root_points, root_faces, rig, materials[3] if identity == 'john_orourke' else materials[0])
    roots['root_policy'] = 'clipped fitted hairline; exposed crowns for receded identities'

    distributions = [[], [], []]
    cumulative = [[], [], []]
    totals = [0., 0., 0.]
    for tri in triangles:
        a, b, c = [mesh.vertices[i].co for i in tri.vertices]
        n = (b-a).cross(c-a)
        area = n.length*.5
        if area < 1e-8:
            continue
        centre = (a+b+c)/3
        weights = hair_regions(tuple(centre), identity)[0]
        for kind, weight in enumerate(weights):
            if weight < .015 or (kind > 0 and n.z <= 0):
                continue
            totals[kind] += area*weight
            cumulative[kind].append(totals[kind])
            distributions[kind].append((a.copy(), b.copy(), c.copy()))
    counts = {
        'shane_denham': (3600, 0, 720), 'john_orourke': (3800, 6200, 680),
        'bordeaux_09': (2100, 4400, 680), 'des_feeney_sr': (1400, 2500, 640),
    }[identity]
    vertices, faces, face_materials, emitted_counts = [], [], [], []
    for kind, count in enumerate(counts):
        emitted, attempts = 0, 0
        if not distributions[kind]:
            assert count == 0, (identity, kind)
        while emitted < count and attempts < count*50:
            attempts += 1
            a, b, c = distributions[kind][bisect.bisect_left(cumulative[kind], rng.random()*totals[kind])]
            r, t = math.sqrt(rng.random()), rng.random()
            root = a*(1-r)+b*r*(1-t)+c*r*t
            if rng.random() > mask(root, kind):
                continue
            if kind > 0:
                hit, _, _, _ = surface.ray_cast(Vector((root.x, root.y, 30)), Vector((0, 0, -1)))
                if hit is None or abs(hit.z-root.z) > .14:
                    continue
            near, normal, _, _ = surface.find_nearest(root)
            if normal is None:
                continue
            if kind == 0:
                top = root.y > 170.7
                flow = Vector((-.85, -.10, .42)) if top else Vector((-.08*root.x, -1, -.22))
                if identity in ('bordeaux_09', 'des_feeney_sr'):
                    length, width, lift, rows = rng.uniform(.20, .42), rng.uniform(.012, .024), .035, 3
                else:
                    length = rng.uniform(1.2, 2.4) if top else rng.uniform(.35, .80)
                    if identity == 'john_orourke' and top:
                        length *= 1.25
                    width = rng.uniform(.055, .095) if top else rng.uniform(.018, .038)
                    lift = rng.uniform(.34, .70) if top else rng.uniform(.04, .12)
                    if identity == 'john_orourke' and top:
                        lift *= 1.35
                    rows = 5
            elif kind == 1:
                # Moustache flows away from the philtrum, beard toward the jaw.
                mustache = root.y > 160.0
                flow = Vector((math.copysign(.75, root.x), -.45, 0)) if mustache else Vector((-.045*root.x, -1, -.12))
                length = rng.uniform(.26, .52) if identity != 'des_feeney_sr' else rng.uniform(.35, .65)
                if identity == 'john_orourke':
                    length *= 1.8
                width, lift, rows = rng.uniform(.009, .019), rng.uniform(.015, .045), 3
                if identity == 'john_orourke':
                    lift = rng.uniform(.07, .20)
            else:
                flow = Vector((math.copysign(1, root.x), .12, 0))
                length, width, lift, rows = rng.uniform(.16, .32), rng.uniform(.008, .016), .018, 3
            tangent = flow-normal*flow.dot(normal)
            if tangent.length < 1e-7:
                continue
            tangent.normalize()
            across = normal.cross(tangent).normalized()
            start = len(vertices)
            curl = rng.uniform(-.10, .10) if kind == 0 else rng.uniform(-.015, .015)
            if identity == 'john_orourke' and kind == 0:
                tone = rng.choices((3, 4, 5), (20, 45, 35) if top else (50, 40, 10))[0]
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
    cards['finish_revision'] = 'four-head-reference-v1'
    print('FITTED_GROOM', identity, emitted_counts, len(faces)*2, 'fibre triangles', flush=True)
    return roots, cards
