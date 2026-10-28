"""Reference-led facial forms and portable anatomical surface finish.

Works on the current shared head topology. All coordinates are armature-local
centimetres (+Y up, +Z face); the protected neck, rig and body are untouched.
"""
import math
import json
from functools import lru_cache
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

IDENTITIES = ('shane_denham', 'john_orourke', 'bordeaux_09', 'des_feeney_sr')


@lru_cache(maxsize=1)
def portrait_proportions():
    return json.loads((Path(__file__).parent/'head_pipeline/portrait_proportions.json').read_text())['players']


def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3-2*t)


def field(x, y, cx, cy, sx, sy):
    return math.exp(-((abs(x)-cx)/sx)**2-((y-cy)/sy)**2)


def calibrate(point, identity):
    """Small measured form corrections with fixed eye centres and neck join."""
    x, y, z = point
    if y < 154:
        return Vector(point)
    data = portrait_proportions()[identity]
    ratios, weight = data['ratios'], data['weight']
    front = smooth(2.5, 7., z)
    neck = smooth(154., 157., y)
    # Outer face width changes leave the anatomical eye centres in place.
    outer = smooth(3.8, 7.2, abs(x))
    x *= 1+(ratios['face_width']-1)*weight*outer*neck
    x *= 1+(ratios['jaw_width']/ratios['face_width']-1)*weight*field(x, y, 4.8, 157.9, 3.0, 2.8)*front*neck
    nose = math.exp(-(x/2.7)**6-((y-162.35)/1.6)**4)*front
    x *= 1+(ratios['nose_width']-1)*weight*nose
    mouth = math.exp(-(x/5.7)**6-((y-159.88)/1.65)**2)*front
    mouth *= 1-smooth(160.9, 162.3, y)
    x *= 1+(ratios['mouth_width']-1)*weight*mouth
    mouth_shift = max(-.85, min(.85, (1-ratios['mouth_y'])*6.646*weight))
    chin_shift = max(-1.0, min(.60, (1-ratios['chin_y'])*11.026*weight))
    nose_shift = max(-.35, min(.35, (1-ratios['nose_y'])*4.176*weight))
    y += mouth_shift*math.exp(-(x/5.5)**6-((y-159.88)/1.5)**2)*front*neck
    y += chin_shift*field(x, y, 0, 155.8, 5.5, 1.65)*front*neck
    y += nose_shift*field(x, y, 0, 162.35, 2.5, 1.25)*front
    return Vector((x, y, z))


def sculpt(point, identity):
    x, y, z = point
    if y < 154:
        return point.copy()
    front = smooth(2.5, 8., z)
    neck = smooth(154., 157., y)
    # Keep all lip deformations monotonic. The earlier John closure crossed
    # upper/lower lip vertices and produced an inverted philtrum flap.
    params = {
        'shane_denham': (.32, .35, .28, .80, .90),
        'john_orourke': (.52, .48, .38, .81, .72),
        'bordeaux_09': (.50, .95, .54, .78, .83),
        'des_feeney_sr': (.44, 1.04, .52, .82, .88),
    }
    cheek_width, jaw_width, fullness, lip_width, lip_height = params[identity]
    cheek = field(x, y, 4.6, 162.7, 2.6, 2.35)*front
    jowl = field(x, y, 4.6, 157.9, 2.7, 2.5)*front*neck
    x += math.copysign(cheek_width*cheek+jaw_width*jowl, x)
    z += fullness*cheek+fullness*.90*jowl
    # Soften the inherited square mandibular corners and round the chin mass.
    z += .18*field(x, y, 0, 156.25, 3.6, 1.45)*front*neck
    x *= 1-.018*field(x, y, 7.2, 158.2, 1.7, 2.5)*neck
    # Recess the globes and add an anatomical lower-lid cushion. Globe and
    # orbital aperture dimensions are fitted together in eye_sculpt().
    eye_x = math.copysign(3.347, x)
    orbit = math.exp(-((x-eye_x)/2.35)**4-((y-166.526)/1.75)**4)*front
    height_scale = {'shane_denham': 1.10, 'john_orourke': 1.06,
                    'bordeaux_09': 1.01, 'des_feeney_sr': .92}[identity]
    y = 166.526+(y-166.526)*(1-(1-height_scale)*orbit)
    z -= .11*orbit
    z += .11*field(x, y, 3.5, 165.2, 1.9, .65)*front
    brow = field(x, y, 3.5, 167.7, 2.2, .65)*front
    z += (.22 if identity == 'des_feeney_sr' else .10)*brow
    if identity == 'des_feeney_sr':
        y -= .22*brow
        z += .25*brow+.25*field(x, y, 3.4, 165.0, 2.0, .70)*front
        fold_x = 1.9+.37*(162.-y)
        z -= .11*math.exp(-((abs(x)-fold_x)/.32)**2-((y-160.2)/1.7)**4)*front
        z += .30*field(x, y, 3.4, 156.3, 3., 1.6)*front*neck
    elif identity == 'shane_denham':
        z += .26*field(x, y, 4.4, 161.6, 2.4, 2.0)*front
        y -= .38*smooth(170., 177., y)
    # Broad, rounded nasal tissue; no shadow painted on a pointed wedge.
    tip = field(x, y, 0., 162.35, 1.5, 1.0)*front
    ala = field(x, y, 1.6, 161.85, .8, .65)*front
    nose_width = {'shane_denham': .12, 'john_orourke': .13,
                  'bordeaux_09': .09, 'des_feeney_sr': .22}[identity]
    x += math.copysign(nose_width*ala, x)
    z += {'shane_denham': .03, 'john_orourke': .08,
          'bordeaux_09': -.32, 'des_feeney_sr': .37}[identity]*tip
    z += .09*ala
    # Smoothly narrow the mouth without collapsing neighbouring cheek planes.
    mouth = math.exp(-(x/6.3)**6-((y-159.88)/2.2)**2)*smooth(4.5, 7.5, z)
    mouth *= 1-smooth(160.9, 162.5, y)
    x *= 1-(1-lip_width)*mouth
    y = 159.88+(y-159.88)*(1-(1-lip_height)*mouth)
    z -= .10*field(x, y, 0, 160.1, 2.65, .55)*front
    if identity == 'des_feeney_sr':
        y -= .075*field(x, y, 2.9, 159.9, .8, .6)*front
    if identity in ('bordeaux_09', 'des_feeney_sr'):
        # Rounded exposed skull; retain the actual forehead instead of moving
        # all facial features upward independently of eyes and pigment masks.
        y += (.45*math.exp(-(x/4.8)**2)-.016*x*x)*smooth(171., 177., y)
        z += .10*field(x, y, 0, 171.9, 5.9, 2.0)*front
    # Bound ear projection while retaining pinna topology and asymmetry.
    ear = smooth(8.0, 9.7, abs(x))*(1-smooth(3.5, 6.5, abs(z)))
    x -= math.copysign(.16*ear, x)
    return portrait_form(calibrate((x, y, z), identity), identity)


def portrait_form(point, identity):
    """Reference silhouette pass: skull height, fleshy cheeks and individual lids.

    The previous four heads retained the same long crown and hollow angular
    muzzle. These centimetre-space fields change structure, not a portrait decal.
    They deliberately leave the neck and eyeball centres unchanged.
    """
    x, y, z = point
    if y < 154:
        return Vector(point)
    front = smooth(3., 8., z)
    neck = smooth(154., 157., y)
    crown, cheek_fill, jaw_softness = {
        'shane_denham': (.86, .62, .34),
        'john_orourke': (.83, .76, .48),
        'bordeaux_09': (.76, .94, .63),
        'des_feeney_sr': (.78, .82, .74),
    }[identity]
    cheek = field(x, y, 4.5, 161.0, 2.5, 2.6) * front
    z += cheek_fill * cheek
    # Remove the inherited razor-straight cheek hollow and square jaw corner.
    z += .32 * field(x, y, 5.6, 159.2, 2.3, 2.0) * front * neck
    x -= math.copysign(jaw_softness * field(x, y, 6.8, 157.7, 1.5, 2.0) * neck, x)
    z += .24 * field(x, y, 0, 156.6, 3.4, 1.5) * front * neck
    # Residual landmark gaps from the archived front-view measurements:
    # John's snub nose sits higher; the two Des portraits have narrower mouths.
    nose = math.exp(-((y-162.25)/1.25)**4) * (1-smooth(2.8, 3.6, abs(x))) * front
    x *= 1-{'shane_denham':.06,'john_orourke':.12,'bordeaux_09':.12,'des_feeney_sr':.10}[identity]*nose
    y += {'shane_denham':.05,'john_orourke':.38,'bordeaux_09':.12,'des_feeney_sr':.30}[identity]*nose
    mouth = math.exp(-(x/5.2)**6-((y-159.85)/1.45)**2) * front
    x *= 1-{'shane_denham':.025,'john_orourke':.07,'bordeaux_09':.14,'des_feeney_sr':.18}[identity]*mouth
    if identity in ('bordeaux_09', 'des_feeney_sr'):
        # Both portraits have soft lower cheeks; the referee has older jowls.
        x += math.copysign(.42 * field(x, y, 5.1, 158.2, 2.2, 2.7) * neck, x)
        z += .35 * field(x, y, 3.5, 157.3, 3.0, 1.9) * front * neck
    # Subtle natural bilateral difference rather than identical mirrored planes.
    z += .075 * math.sin(x * .32) * field(x, y, 3.8, 162.3, 3.2, 3.2) * front
    if identity == 'shane_denham':
        z += .18 * field(x, y, 3.5, 167.6, 2.0, .7) * front
        z -= .16 * field(x, y, 0, 162.7, 1.2, 1.8) * front
    elif identity == 'john_orourke':
        z += .16 * field(x, y, 3.5, 165.4, 1.7, .6) * front
    elif identity == 'des_feeney_sr':
        # Structural bags and nasolabial folds remain visible without normals.
        z += .22 * field(x, y, 3.4, 165.0, 1.8, .55) * front
        fold_x = 2.0 + .32 * (162.0 - y)
        z -= .13 * math.exp(-((abs(x)-fold_x)/.34)**2-((y-160.1)/1.8)**4) * front
        for line in (169.3, 170.2):
            z -= .055 * math.exp(-((y-line-.08*math.cos(x*.5))/.14)**2-(x/5.2)**6) * front
    # Keep the facial landmarks below the brow; shorten the excessive crown.
    y -= (1-crown) * max(0., y-168.) * smooth(168., 170., y)
    return Vector((x, y, z))


def eye_sculpt(point, centre, identity):
    size = {'shane_denham': (.97, .97), 'john_orourke': (.95, .95),
            'bordeaux_09': (.95, .91), 'des_feeney_sr': (.95, .88)}[identity]
    p = point-centre
    return calibrate(centre+Vector((p.x*size[0], p.y*size[1], p.z*.96-.12)), identity)


def soften_cheek_planes(mesh):
    """Relax broad inherited cheek facets, protecting apertures and the neck."""
    neighbours = [set() for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        neighbours[a].add(b)
        neighbours[b].add(a)
    weights = []
    for vertex in mesh.vertices:
        x, y, z = vertex.co
        weight = .42 * field(x, y, 5.1, 161.1, 2.9, 3.1) * smooth(4., 7., z)
        weight *= smooth(154., 157., y)
        weight *= 1 - .95 * field(x, y, 3.1, 159.9, 1.2, .75)
        weights.append(weight)
    for _ in range(5):
        before = [vertex.co.copy() for vertex in mesh.vertices]
        for index, vertex in enumerate(mesh.vertices):
            if weights[index] > .002 and neighbours[index]:
                average = sum((before[n] for n in neighbours[index]), Vector()) / len(neighbours[index])
                vertex.co = before[index].lerp(average, weights[index])


def _smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


@lru_cache(maxsize=4)
def mask_landmark_fit(identity):
    landmarks = [(155.5, 9.5), (159.88, 10.6), (162.35, 12.), (166.526, 8.8)]
    original = np.array([a for a, _ in landmarks])
    fitted = np.array([calibrate((0, y, z), identity).y for y, z in landmarks])
    assert np.all(np.diff(fitted) > .5), 'Portrait fit reversed facial landmark order'
    data = portrait_proportions()[identity]
    return original, fitted, 1+(data['ratios']['mouth_width']-1)*data['weight']


def pigment_coordinates(points, identity):
    """Keep the anatomy-dependent pigment/groom masks with the fitted face."""
    p = np.atleast_2d(np.asarray(points, dtype=np.float64)).copy()
    original, fitted, mouth_scale = mask_landmark_fit(identity)
    y = p[:, 1].copy()
    mapped = np.interp(y, fitted, original)
    mapped = np.where(y < fitted[0], original[0]+y-fitted[0], mapped)
    mapped = np.where(y > fitted[-1], original[-1]+y-fitted[-1], mapped)
    p[:, 1] = y+(mapped-y)*_smooth(154., 156.5, y)
    influence = np.exp(-((p[:, 1]-159.5)/3.7)**4)*_smooth(4.5, 7., p[:, 2])
    p[:, 0] /= 1+(mouth_scale-1)*influence
    return p


def hair_regions(points, identity):
    """Scalp, beard/moustache and brows, all in the resulting sculpt space."""
    p = np.atleast_2d(np.asarray(points, dtype=np.float64))
    x, y, z = p.T
    ax = abs(x)
    angle = abs(np.arctan2(x, z+1.0))
    side = _smooth(.5, 1.6, angle)
    rear = _smooth(1.6, 3.1, angle)
    front = _smooth(4.5, 8.5, z)
    if identity == 'shane_denham':
        line = 172.65-6.3*side-3.0*rear+.07*np.sin(x*1.9)+.025*np.sin(x*5.1)
        line += .32*np.exp(-((ax-6.4)/1.4)**2)
        scalp = _smooth(line-.15, line+.25, y)
    elif identity == 'john_orourke':
        line = 171.85+.55*_smooth(0, 3, -x)-.28*_smooth(0, 3, x)-3.7*side-2.5*rear+.09*np.sin(x*2.8)
        scalp = _smooth(line-.17, line+.22, y)
    elif identity == 'robbie_roden':
        line = 172.35-5.0*side-2.6*rear+.07*np.sin(x*2.3)+.025*np.sin(x*5.3)
        scalp = _smooth(line-.18, line+.25, y)
    elif identity == 'david_murray':
        # The owner portrait shows open temples and an uneven fair hairline.
        line = 173.0-6.7*side-2.7*rear+1.05*np.exp(-((ax-5.8)/1.5)**2)
        line += .06*np.sin(x*2.0)+.02*np.sin(x*5.3)
        scalp = _smooth(line-.18, line+.27, y)
    elif identity == 'bordeaux_09':
        # Original side views 69911/69910: a high temporal wedge joins the
        # occipital band. Recession exposes the crown, not the entire skull.
        lower = 168.5-2.0*side-4.6*rear
        upper = 170.6+1.9*np.exp(-((angle-1.23)/.56)**2)
        edge = .07*np.sin(y*5.1+x*3.7)
        band = _smooth(.72, 1.05, angle)*_smooth(lower-.35, lower+.30, y)
        band *= 1-_smooth(upper-.35+edge, upper+.28+edge, y)
        sideburn = _smooth(.76, .95, angle)*(1-_smooth(1.18, 1.40, angle))
        sideburn *= _smooth(162.5, 164., y)*(1-_smooth(166.8, 168., y))
        sideburn *= 1-_smooth(7.0, 7.7, ax)
        scalp = np.maximum(band, sideburn*.85)
    else:
        line = 169.7-3.1*side-2.0*rear
        scalp = _smooth(1.00, 1.5, angle)*_smooth(line-.3, line+.7, y)*(1-_smooth(172.2, 174., y))
    # Facial-hair roots never sample the projecting nose or the oral cavity.
    x, y, z = pigment_coordinates(p, identity).T
    ax = abs(x)
    face = front*(1-_smooth(11.15, 11.65, z))
    arch = 160.83-.12*(ax/2.8)**2
    moustache_height = .72 if identity == 'des_feeney_sr' else .37
    moustache = np.exp(-(x/2.85)**6-((y-arch)/moustache_height)**4)*face
    moustache *= (1-.28*np.exp(-(x/.30)**2))
    if identity == 'bordeaux_09':
        beard = np.exp(-(x/3.15)**2-((y-156.7)/1.65)**2)*front
        connectors = np.exp(-((ax-2.45)/.30)**2-((y-158.65)/1.05)**2)*face*.48
        soul = np.exp(-(x/.8)**6-((y-158.85)/.45)**4)*face*.6
        facial = np.maximum.reduce((beard, moustache*.28, connectors*.55, soul))
    elif identity == 'john_orourke':
        # John's original portrait shows a full cheek/jaw beard connected to
        # the sideburns. A front-Z mask left an isolated bib in profile. Use
        # the head's angular surface instead, stopping in front of the ears.
        cheek_edge = 160.45+3.10*_smooth(.25, 1.15, angle)
        cheek_edge += .065*np.sin(x*4.9+y*3.1)
        neckline = 154.65+3.40*_smooth(.50, 1.40, angle)
        jaw = _smooth(neckline-.25, neckline+.65, y)
        jaw *= 1-_smooth(cheek_edge-.70, cheek_edge+.65, y)
        lateral = (1-_smooth(1.24, 1.46, angle))*_smooth(.40, 1.45, z)
        # Leave the lips, oral cavity and projecting nasal tissue bare.
        mouth_gap = np.exp(-(x/3.05)**6-((y-159.85)/.50)**4)*front
        jaw *= (1-mouth_gap)*(1-_smooth(10.9, 11.65, z))
        # Lighter, broken cheek growth transitions to the denser lower jaw;
        # a uniformly opaque mask looked like a cut-out side panel in-game.
        lower_growth = 1-_smooth(157.9, 160.8, y)
        density = .58+.30*lower_growth
        density *= .86+.14*np.sin(x*2.15+z*.70)*np.sin(y*2.6-z*1.3)
        beard = jaw*lateral*density
        sideburn = _smooth(.83, 1.05, angle)*(1-_smooth(1.25, 1.43, angle))
        sideburn *= _smooth(2.25, 3.1, z)*(1-_smooth(5.0, 6.2, z))
        sideburn *= _smooth(160.4, 162.1, y)
        sideburn *= 1-_smooth(line+.10, line+.55, p[:, 1])
        facial = np.maximum.reduce((beard, moustache, sideburn*.62))
    elif identity == 'des_feeney_sr':
        facial = moustache
    elif identity == 'robbie_roden':
        # The confirmed original has a short beard shadow around the jaw and
        # lip. Keep it below the cheeks and clear of the oral contact loops.
        jaw = _smooth(154.8,155.8,y)*(1-_smooth(160.1,161.6,y))*front
        jaw *= 1-np.exp(-(x/3.1)**6-((y-159.85)/.48)**4)
        facial = np.maximum(jaw*.30,moustache*.24)
    else:
        facial = np.zeros_like(x)
    brow_y = 167.95+.10*np.exp(-((ax-3.45)/1.45)**2)-.06*(ax-3.45)
    if identity=='shane_denham': brow_y -= .16
    brow = np.exp(-((ax-3.45)/1.75)**6-((y-brow_y)/.31)**2)*_smooth(7.4, 8.6, z)
    return np.stack((scalp, facial, brow), axis=1)


def finish_head(head, identity):
    facial_shapes(head)
    import shane_player_finish as skin
    from skin_palette import SHARED_SKIN, JOHN_SKIN, DES_PLAYER_SKIN, DES_REFEREE_SKIN
    pigments = {'shane_denham': SHARED_SKIN, 'john_orourke': JOHN_SKIN,
                'bordeaux_09': DES_PLAYER_SKIN, 'des_feeney_sr': DES_REFEREE_SKIN,
                'robbie_roden': SHARED_SKIN, 'david_murray': JOHN_SKIN}
    source_material = head.data.materials[0]
    shared_neck = next(n.image for n in source_material.node_tree.nodes
                       if n.type == 'TEX_IMAGE' and n.image and 'albedo' in n.image.name)
    for attribute in list(head.data.color_attributes):
        head.data.color_attributes.remove(attribute)
    mat = bpy.data.materials.new('MAT_Skin_Finished_'+identity)
    mat.use_nodes = True
    head.data.materials[0] = mat
    eyes = [sum((v.co for v in bpy.data.objects['Eye_'+side].data.vertices), Vector())/
            len(bpy.data.objects['Eye_'+side].data.vertices) for side in ('l', 'r')]
    pigment = np.asarray(pigments[identity], dtype=np.float32)

    def colour(points, eye_centres):
        x, y, z = pigment_coordinates(points, identity).T
        ax = abs(x)
        front = _smooth(3, 7, z)
        result = np.tile(pigment, (len(points), 1))
        cheek = np.exp(-((ax-4.3)/2.3)**2-((y-163.2)/1.9)**2)*front
        nose = np.exp(-(x/1.5)**4-((y-162.1)/1.5)**2)*front
        result += cheek[:, None]*np.array([.025, -.014, -.010])
        result += nose[:, None]*np.array([.020, -.012, -.010])
        lip = np.exp(-(x/3.1)**6-((y-159.85)/.40)**2)*front
        result += lip[:, None]*np.array([.028, -.071, -.046])
        under = np.exp(-((ax-3.45)/1.75)**4-((y-165.4)/.55)**2)*front
        result -= under[:, None]*np.array([.014, .016, .012])
        regions = hair_regions(points, identity)
        # Root pigment is subdued; the actual groom supplies dimensional hair.
        tones = {'shane_denham': (.17, .12, .08), 'john_orourke': (.32, .22, .15),
                 'bordeaux_09': (.10, .075, .055), 'des_feeney_sr': (.38, .36, .32),
                 'robbie_roden': (.14, .09, .06), 'david_murray': (.32, .22, .13)}
        facial_strength = {'john_orourke':.92,'bordeaux_09':.86,
                           'des_feeney_sr':.88,'robbie_roden':.35}.get(identity,.40)
        root = np.maximum(regions[:, 1]*facial_strength, regions[:, 2]*.88)
        result = result*(1-root[:, None])+np.asarray(tones[identity])*root[:, None]
        # Sparse original pigment variation; no source portrait illumination.
        freckles = np.maximum(0, np.sin(x*71+y*37)*np.sin(y*43+z*57)-.89)*front
        result -= freckles[:, None]*np.array([.030, .024, .018])
        # Low-amplitude vascular/pigment variation; no baked directional light.
        mottling = (np.sin(x*2.1+y*1.7)*np.sin(z*2.9-y*.8)) * front
        result += mottling[:, None]*np.array([.009, -.003, -.002])
        if identity in ('shane_denham', 'john_orourke', 'robbie_roden', 'david_murray'):
            # Restrained pigment is separate from shape/shadow: retain the
            # fair complexion, lip vermilion and local capillary variation.
            # The former uniformly pale face hid the individual facial planes.
            blend = _smooth(154., 158., points[:, 1])
            result += blend[:, None] * np.array([-.012, -.023, -.025])
            flush = np.exp(-((ax-4.0)/2.1)**4-((y-162.2)/1.65)**4)*front
            result += flush[:, None]*np.array([.018, -.012, -.009])
            rim = np.exp(-((ax-3.45)/1.45)**6-((y-166.1)/.42)**2)*front
            result += rim[:, None]*np.array([.007, -.011, -.009])
        return np.clip(result, 0, 1)

    def relief(points, eye_centres):
        x, y, z = points.T
        front = _smooth(4., 8., z)
        age = 2.0 if identity == 'des_feeney_sr' else .50
        value = np.zeros_like(x)
        for cy, depth in ((170.6, .012), (171.6, .010), (172.45, .007)):
            line = cy+.08*np.cos(x*.5)
            value -= age*depth*np.exp(-((y-line)/.12)**2-(x/5.3)**6)*front
        for slope in (-.28, .25):
            line = 166.35+slope*(abs(x)-4.6)
            value -= age*.006*np.exp(-((y-line)/.085)**2-((abs(x)-5.25)/.9)**4)*front
        if identity == 'des_feeney_sr':
            fold = 2.1+.45*(162-y)
            value -= .023*np.exp(-((abs(x)-fold)/.16)**2-((y-160.3)/1.6)**4)*front
            value -= .014*np.exp(-((y-165.05)/.12)**2-((abs(x)-3.5)/1.7)**4)*front
        elif identity in ('shane_denham', 'john_orourke', 'robbie_roden', 'david_murray'):
            # Fine lid/alar/philtrum relief follows anatomy; no directionally
            # lit portrait is baked into pigment. Millimetre-scale folds.
            brow = 167.10 + .08*np.cos(x*.7)
            value -= .006*np.exp(-((y-brow)/.075)**2-((abs(x)-3.45)/1.4)**6)*front
            fold = 1.85+.43*(162.25-y)
            value -= .008*np.exp(-((abs(x)-fold)/.13)**2-((y-160.9)/1.5)**4)*front
            value -= .004*np.exp(-((y-164.95)/.08)**2-((abs(x)-3.6)/1.45)**6)*front
        return value

    def roughness(points):
        x, y, z = pigment_coordinates(points, identity).T
        front = _smooth(3, 7, z)
        nose = np.exp(-(x/1.6)**4-((y-163.2)/2.5)**4)*front
        forehead = np.exp(-(x/5.0)**6-((y-170.0)/2.1)**4)*front
        cheeks = np.exp(-((abs(x)-4.3)/2.0)**4-((y-162.4)/2.0)**4)*front
        fine = np.sin(x*53+y*31)*np.sin(y*47-z*59)*.008
        lips = np.exp(-(x/3.15)**6-((y-159.85)/.48)**2)*front
        value = .58-.13*nose-.055*forehead+.045*cheeks-.065*lips+fine
        if identity in ('shane_denham','john_orourke','robbie_roden','david_murray'):
            # Real skin has an oilier T-zone and broken cheek response, not a
            # single wax-like lobe. Keep restrained variation at pore scale.
            value -= .025*nose
            value += .009*np.sin(x*117+y*83)*np.cos(y*109-z*59)*front
        return np.clip(value,.40,.68)

    previous = (skin.SKIN_PIGMENT.copy(), skin.skin_colour, skin.reference_skin_relief)
    skin.SKIN_PIGMENT = pigment
    skin.skin_colour = colour
    skin.reference_skin_relief = relief
    try:
        skin.bake_skin(head, None, mat, eyes, head_only=True, image_prefix=identity+'_finish',
                       detail_only=True, retained_neck_albedo=shared_neck,
                       roughness_callback=roughness,
                       pore_amplitude=.0022 if identity in ('shane_denham','john_orourke','robbie_roden','david_murray') else .00055,
                       detail_strength=.72)
    finally:
        skin.SKIN_PIGMENT, skin.skin_colour, skin.reference_skin_relief = previous
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = .60
    bsdf.inputs['Specular IOR Level'].default_value = .30
    mat.node_tree.nodes['Normal Map'].inputs['Strength'].default_value = .55 if identity == 'des_feeney_sr' else .46 if identity in ('shane_denham','john_orourke','robbie_roden','david_murray') else .34
    # A smaller anatomical iris leaves sclera visible. Des's old oversized
    # iris filled the whole lid aperture and read as a black oval.
    yy, xx = np.mgrid[0:512, 0:512]
    ex = (xx-255.5)/512
    ey = (yy-255.5)/512
    r = np.sqrt(ex*ex+ey*ey)
    angle = np.arctan2(ey, ex)
    rgb = np.tile(np.array([.72, .715, .69]), (512, 512, 1))
    iris_colour = {'shane_denham': (.30, .22, .13), 'john_orourke': (.21, .34, .38),
                   'bordeaux_09': (.24, .16, .09), 'des_feeney_sr': (.29, .24, .16),
                   'robbie_roden': (.25, .17, .10), 'david_murray': (.22, .34, .39)}[identity]
    iris_radius = .235 if identity == 'shane_denham' else .242 if identity == 'john_orourke' else .214
    iris = r < iris_radius
    grain = (np.sin(angle*83+r*179)+np.sin(angle*47-r*131))*.018
    for channel, base in enumerate(iris_colour):
        rgb[:, :, channel][iris] = base+grain[iris]
    rgb[(r>iris_radius-.014)&iris] *= .65
    rgb[r<(.067 if identity in ('shane_denham','john_orourke') else .057)] = (.009, .010, .009)
    eye_image = skin.image_from_array(identity+'_finish_eyes_albedo', np.clip(rgb, 0, 1))
    for side in ('l', 'r'):
        eye = bpy.data.objects['Eye_'+side]
        eye_mat = bpy.data.materials.new('MAT_Eye_Finished_'+identity+'_'+side)
        eye_mat.use_nodes = True
        eye.data.materials[0] = eye_mat
        skin.image_node(eye_mat, eye_image, 'Base Color')
        eye_bsdf = eye_mat.node_tree.nodes['Principled BSDF']
        eye_bsdf.inputs['Roughness'].default_value = .17
        eye_bsdf.inputs['Specular IOR Level'].default_value = .48
    head['finish_revision'] = 'four-head-reference-v2'
    head['pigment_policy'] = 'anatomical UV pigment and original groom; no projected portrait'
    if identity=='shane_denham':
        from player_oral_geometry import build_upper_teeth
        build_upper_teeth(bpy.data.objects['YBot_Armature'],identity)
    else:
        old=bpy.data.objects.get('Mouth_UpperTeeth')
        if old: bpy.data.objects.remove(old,do_unlink=True)
    return mat


def facial_shapes(head):
    """Small closed-mouth smile and fitted eyelid closure on the same topology."""
    if not head.data.shape_keys:
        head.shape_key_add(name='Basis')
    basis = head.data.shape_keys.key_blocks[0]
    smile = head.data.shape_keys.key_blocks.get('Smile') or head.shape_key_add(name='Smile')
    blink = head.data.shape_keys.key_blocks.get('Blink') or head.shape_key_add(name='Blink')
    fullness = head.data.shape_keys.key_blocks.get('Fullness') or head.shape_key_add(name='Fullness')
    from build_body_fullness import fullness as body_fullness
    centres = {side: sum((v.co for v in bpy.data.objects['Eye_'+side].data.vertices), Vector()) /
               len(bpy.data.objects['Eye_'+side].data.vertices) for side in ('l', 'r')}
    from mathutils.bvhtree import BVHTree
    globes={side:BVHTree.FromPolygons([v.co for v in bpy.data.objects['Eye_'+side].data.vertices],
            [list(p.vertices) for p in bpy.data.objects['Eye_'+side].data.polygons]) for side in centres}
    oral_weights={}
    if bpy.context.scene.get('head_player_id')=='shane_denham':
        from player_oral_geometry import upper_lip_weights
        oral_weights=upper_lip_weights(head)
    for index, point in enumerate(basis.data):
        x, y, z = point.co
        smile.data[index].co = point.co
        blink.data[index].co = point.co
        # The same field drives the shared collar/skin meshes. Its neutral
        # Basis and the master neck interface remain unchanged.
        fullness.data[index].co = body_fullness(point.co)
        if y < 154:
            continue
        front = smooth(5., 8., z)
        corner = field(x, y, 2.8, 159.9, 1.2, .85) * front
        cheek = field(x, y, 4.0, 161.7, 2.0, 1.5) * front
        smile.data[index].co += Vector((math.copysign(.11*corner, x), .23*corner+.09*cheek, .08*cheek))
        if bpy.context.scene.get('head_player_id')=='shane_denham':
            # Separate the original tooth-showing reference smile from neutral
            # identity. Smooth jaw/lip support avoids crossing the lip loops.
            oral=math.exp(-(x/3.45)**6-((y-159.8)/1.35)**4)*front
            upper=oral_weights.get(index,.5)
            smile.data[index].co += Vector((math.copysign(.11*corner,x),.27*corner+.11*cheek+(.60*upper-.28*(1-upper))*oral,.025*cheek))
        # Choose the nearer globe rather than depending on rig-side naming.
        side=min(centres,key=lambda side:abs(centres[side].x-x))
        centre=centres[side]
        dx, dy = x-centre.x, y-centre.y
        if abs(dx)<1.75 and abs(dy)<1.35 and z>centre.z-2.1:
            weight=(1-smooth(1.25,1.75,abs(dx)))*(1-smooth(.65,1.35,abs(dy)))
            lid=blink.data[index].co
            lid.y+=(centre.y-.035-y)*weight*.75
            hit,_,_,_=globes[side].ray_cast(Vector((x,lid.y,30)),Vector((0,0,-1)))
            if hit is not None:
                # Include the inset orbital surface behind the globe: only
                # moving the outer rim leaves an exposed central slit.
                lid.z+=max(0,hit.z+.12-z)*weight
    smile.value = blink.value = fullness.value = 0
