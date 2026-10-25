"""Original skin pigment masks for Beechlawn keeper John O’Rourke."""
import math
import bpy
import numpy as np
from pathlib import Path
from mathutils import Vector

import shane_player_finish as _skin
_BASE_SKIN_COLOUR = _skin.skin_colour


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3.0-2.0*t)


def masks(p):
    x, y, z = p
    ax = abs(x)
    angle = abs(math.atan2(x, z+1.0))
    # Swept side part with a broken, asymmetric front hairline and full crown
    # root coverage; broad upper scalp must not read as a bald patch.
    part = math.exp(-((x-1.3)/.75)**2) * smooth(169.7, 171.0, y)
    front_line = 170.15 + 1.00*smooth(.0, 3.0, -x) - .45*smooth(0.0, 2.4, x)
    side_lower = 168.2 + 1.5*smooth(.25, .9, angle)
    frontal = smooth(1.8, 5.5, z)
    scalp = max(smooth(front_line-.55, front_line+.22, y)*frontal,
                smooth(side_lower-.5, side_lower+.25, y)*smooth(.55, .95, angle),
                smooth(168.6, 170.0, y)*(1-smooth(176.2, 177.2, y)))
    scalp *= 1.0 - .26*math.exp(-((x-1.25)/.32)**2) * smooth(170.0, 171.1, y)
    scalp *= 1.0 - .35*part
    scalp *= 1.0 - .65*smooth(174.8, 176.2, y)  # break the crown edge softly

    front = smooth(1.8, 6.0, z)
    # Full beard, softly tapered into the temples; chin silhouette is broader
    # and rounder than the shared starting face.
    cheek = smooth(158.0, 158.8, y) * (1.0-smooth(162.5, 163.5, y)) * smooth(2.65,3.25,ax)
    jaw = smooth(154.5, 155.4, y) * (1.0-smooth(157.9, 158.8, y))
    width = 5.15 + 1.05*smooth(158.0, 162.0, y)
    beard = max(cheek*.74, jaw) * (1.0-smooth(width-.25, width+.48, ax)) * front
    sideburn = smooth(.48, .95, angle) * smooth(160.3, 162.2, y) * (1-smooth(164.1, 165.0, y))
    beard = max(beard, sideburn*.82)
    moustache = smooth(160.05, 160.5, y) * (1-smooth(161.35, 161.85, y)) * (1-smooth(3.25, 3.8, ax)) * smooth(7.5, 8.8, z)
    soul = smooth(159.8, 160.3, y) * (1-smooth(161.0, 161.5, y)) * (1-smooth(.9, 1.3, ax)) * front
    beard = max(beard, moustache*.98, soul*.76)
    brow_y = 167.55 + .07*math.exp(-((ax-3.4)/1.5)**2)
    brow = math.exp(-((ax-3.45)/1.85)**6 - ((y-brow_y)/.25)**2) * smooth(7.6, 9.0, z)
    return max(0.0, min(1.0, scalp)), max(0.0, min(1.0, beard)), brow


def _smooth_array(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)


def john_skin_colour(points, eyes):
    """John-specific pigmentation and softly edged ginger-brown beard, baked to UVs."""
    p=_BASE_SKIN_COLOUR(points,eyes)
    x,y,z=points[:,0],points[:,1],points[:,2]
    front=np.clip((z-2.5)/4.0,0,1)
    ax=np.abs(x)
    jaw=_smooth_array(154.0,154.9,y)*(1-_smooth_array(159.0,160.0,y))
    cheek=_smooth_array(159.0,159.8,y)*(1-_smooth_array(161.8,162.7,y))*_smooth_array(2.7,3.3,ax)
    width=5.15+1.05*_smooth_array(158,162,y)
    beard=np.maximum(jaw,cheek*.82)*(1-_smooth_array(width-.25,width+.45,ax))*front
    side=np.clip((np.abs(np.arctan2(x,z+1.0))-.58)/.40,0,1)
    side=side*side*(3-2*side)
    beard=np.maximum(beard,side*_smooth_array(160,162,y)*(1-_smooth_array(164,165,y))*.72)
    moustache=_smooth_array(160.2,160.7,y)*(1-_smooth_array(161.45,161.9,y))*(1-_smooth_array(3.2,3.8,ax))*_smooth_array(7.0,8.5,z)
    chin=_smooth_array(159.5,160.0,y)*(1-_smooth_array(161.0,161.5,y))*(1-_smooth_array(.9,1.3,ax))*front
    coverage=np.clip(np.maximum.reduce([beard,moustache*.88,chin*.58]),0,.95)
    # Warm brown auburn pigment, matching the keeper sheet; the restrained
    # variation is pore/stubble scale so the beard does not become stripy.
    noise=(np.sin(x*23+y*17+z*13)*.007+np.sin(x*41-y*29)*.004)
    pigment=np.stack([.39+noise,.22+noise*.55,.11+noise*.30],axis=1)
    p=p*(1-coverage[:,None]*.40)+pigment*(coverage[:,None]*.40)
    return np.clip(p,0,1)


def finish_head(head):
    mesh = head.data
    # Give John's unique anatomical head its own UV skin bake. The shared
    # master was authored from Shane's skin atlas; that albedo must not bleed
    # into John's face. No facial photo is mapped onto the mesh.
    coordinates=np.array([item.uv[:] for item in mesh.uv_layers.active.data])
    low=coordinates.min(axis=0);span=coordinates.max(axis=0)-low
    head['skin_source_uv_low']=low.tolist();head['skin_source_uv_span']=span.tolist()
    for item in mesh.uv_layers.active.data:
        item.uv=((item.uv.x-low[0])/span[0]*.96+.02,(item.uv.y-low[1])/span[1]*.96+.02)
    eye_centres=[]
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side]
        eye_centres.append(sum((v.co for v in eye.data.vertices),Vector())/len(eye.data.vertices))
    shared_neck=next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'albedo' in n.image.name)
    skin_material=mesh.materials[0].copy();skin_material.name='MAT_Skin_John_ORourke'
    mesh.materials[0]=skin_material
    import shane_player_finish as skin_baker
    old_pigment=skin_baker.SKIN_PIGMENT.copy()
    from skin_palette import JOHN_SKIN
    skin_baker.SKIN_PIGMENT=np.array(JOHN_SKIN,dtype=np.float32)
    old_skin_colour=skin_baker.skin_colour
    try:
        skin_baker.skin_colour=john_skin_colour
        skin_baker.bake_skin(head,None,skin_material,eye_centres,head_only=True,image_prefix='john',neutral_base=True,retained_neck_albedo=shared_neck)
    finally:
        skin_baker.SKIN_PIGMENT=old_pigment
        skin_baker.skin_colour=old_skin_colour
    # Clear blue-grey irises from the keeper sheet, with radial fibers and a
    # narrow dark limbal ring. Texture follows the spherical eye UVs.
    yy,xx=np.mgrid[0:512,0:512]
    ex=(xx-255.5)/512;ey=(yy-255.5)/512+.045;radius=np.sqrt(ex*ex+ey*ey);angle=np.arctan2(ey,ex)
    eye_rgb=np.tile(np.array([.77,.75,.69],dtype=np.float32),(512,512,1))
    iris=radius<.218;pupil=radius<.078
    fibres=(np.sin(angle*81+radius*174)+np.sin(angle*47-radius*112))*.025
    for channel,base in enumerate((.105,.225,.295)):
        eye_rgb[:,:,channel][iris]=base+fibres[iris]*(1.0 if channel else .45)
    eye_rgb[(radius>.198)&iris]*=.54
    eye_rgb[pupil]=(.012,.015,.016)
    eye_image=skin_baker.image_from_array('john_blue_grey_eyes_albedo',eye_rgb)
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side]
        eye_material=eye.data.materials[0].copy();eye_material.name='MAT_Eye_John_BlueGrey'
        eye.data.materials[0]=eye_material
        skin_baker.image_node(eye_material,eye_image,'Base Color')
        eye_material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.24
    material = mesh.materials[0]
    nodes=material.node_tree.nodes
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .64
    bsdf.inputs['Specular IOR Level'].default_value = .22
    head['identity_reference'] = 'John O’Rourke #1; 69010.jpg and supplied goalkeeper sheet'
    head['pigment_policy'] = 'original facial anatomy with John-specific UV skin and beard pigment; no portrait projection'
    return material
