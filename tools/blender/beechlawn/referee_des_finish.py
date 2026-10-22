"""Reference-led skin, age detail and grey moustache UV bake for referee Des."""
import math
import bpy
import numpy as np
from mathutils import Vector
import shane_player_finish as _skin

_BASE_SKIN_COLOUR = _skin.skin_colour
_BASE_SKIN_RELIEF = _skin.reference_skin_relief


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0.0, 1.0)
    return t*t*(3.0-2.0*t)


def des_referee_colour(points, eyes):
    p = _BASE_SKIN_COLOUR(points, eyes)
    x, y, z = points[:, 0], points[:, 1], points[:, 2]
    ax = np.abs(x)
    front = np.clip((z-2.5)/4.0, 0.0, 1.0)
    eye_y = sum(q.y for q in eyes)*.5
    eye_x = sum(abs(q.x) for q in eyes)*.5
    # Gentle age pigment and warmer nose/cheek tone, laid into the unique UVs.
    cheek = np.exp(-((ax-4.4)/2.3)**2-((y-(eye_y-3.3))/1.8)**2)*front
    nose = np.exp(-(x/1.4)**2-((y-(eye_y-2.9))/1.8)**2)*front
    p += cheek[:,None]*np.array([.025,-.012,-.010])
    p += nose[:,None]*np.array([.018,-.009,-.006])
    under_eye = np.exp(-((ax-eye_x)/1.8)**4-((y-(eye_y-.8))/.62)**2)*front
    p -= under_eye[:,None]*np.array([.027,.025,.021])
    # Full, salt-and-pepper grey moustache with a natural faded edge.
    mustache_centre=160.9-.22*(ax/2.8)**2
    moustache = smooth(mustache_centre-.82,mustache_centre-.58,y)*(1-smooth(mustache_centre+.48,mustache_centre+.76,y))
    moustache *= (1-smooth(2.55,3.25,ax))*smooth(5.8,7.2,z)
    # Mid-value salt-and-pepper grey with irregular fibre-sized variation.
    grain = (np.sin(x*31+y*19+z*11)*.018 + np.sin(x*67-y*37)*.010)
    grey = np.stack([.39+grain,.355+grain,.31+grain],axis=1)
    coverage=np.clip(moustache*.92,0,.92)
    p=p*(1-coverage[:,None]*.88)+grey*(coverage[:,None]*.88)
    # Soft grey brows from the reference's heavy, lowered brow.
    brow_line=eye_y+1.15-.025*(ax-eye_x)**2
    brow=np.exp(-((ax-eye_x)/1.85)**6-((y-brow_line)/.28)**2)*smooth(7.2,8.6,z)
    brow_color=np.array([.26,.22,.18])
    p=p*(1-brow[:,None]*.38)+brow_color*(brow[:,None]*.38)
    return np.clip(p,0,1)


def des_age_relief(points, eyes):
    x,y,z=points[:,0],points[:,1],points[:,2]
    ax=np.abs(x); front=np.clip((z-3.5)/4.0,0,1)
    eye_y=sum(q.y for q in eyes)*.5; eye_x=sum(abs(q.x) for q in eyes)*.5
    h=_BASE_SKIN_RELIEF(points,eyes).copy()
    # Fine forehead furrows, crows-feet and restrained smile folds.
    for line_y,depth in ((eye_y+3.1,.0038),(eye_y+4.0,.0027),(eye_y+4.8,.0018)):
        h-=depth*np.exp(-((y-line_y)/.105)**2-(x/5.0)**6)*front
    for side in (-1.0,1.0):
        crease_x=side*(eye_x+1.0)
        for slope in (-.42, .18):
            line=eye_y-.15+slope*(ax-eye_x)
            h-=.0035*np.exp(-((y-line)/.09)**2-((ax-eye_x-1.05)/1.05)**4)*front
        fold=eye_y-3.5-.22*(ax-4.0)
        h-=.003*np.exp(-((ax-4.2)/.13)**2-((y-fold)/1.3)**4)*front
    return h


def finish_head(head):
    mesh=head.data
    uv=mesh.uv_layers.active
    coords=np.asarray([loop.uv[:] for loop in uv.data],dtype=np.float32)
    low=coords.min(axis=0); span=coords.max(axis=0)-low
    head['skin_source_uv_low']=low.tolist();head['skin_source_uv_span']=span.tolist()
    for item in uv.data:
        item.uv=((item.uv.x-low[0])/span[0]*.96+.02,(item.uv.y-low[1])/span[1]*.96+.02)
    eyes=[]
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side]
        eyes.append(sum((v.co for v in eye.data.vertices),Vector())/len(eye.data.vertices))
    import shane_player_finish as skin
    old_pigment=skin.SKIN_PIGMENT.copy();old_colour=skin.skin_colour;old_relief=skin.reference_skin_relief
    from skin_palette import DES_REFEREE_SKIN
    skin.SKIN_PIGMENT=np.array(DES_REFEREE_SKIN,dtype=np.float32)
    skin.skin_colour=des_referee_colour;skin.reference_skin_relief=des_age_relief
    shared_neck=next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'albedo' in n.image.name)
    mat=mesh.materials[0].copy();mat.name='MAT_Skin_Des_Feeney_Referee';mesh.materials[0]=mat
    try:
        skin.bake_skin(head,None,mat,eyes,head_only=True,image_prefix='des_feeney_referee',neutral_base=True,retained_neck_albedo=shared_neck)
    finally:
        skin.SKIN_PIGMENT=old_pigment;skin.skin_colour=old_colour;skin.reference_skin_relief=old_relief
    # Older, hazel-brown eyes with restrained iris contrast.
    yy,xx=np.mgrid[0:512,0:512];ex=(xx-255.5)/512;ey=(yy-255.5)/512+.045
    radius=np.sqrt(ex*ex+ey*ey);angle=np.arctan2(ey,ex)
    colour=np.tile(np.array([.74,.70,.64],dtype=np.float32),(512,512,1))
    iris=radius<.22;pupil=radius<.08
    fibers=(np.sin(angle*73+radius*139)+np.sin(angle*41-radius*96))*.018
    for channel,base in enumerate((.29,.20,.115)):
        colour[:,:,channel][iris]=base+fibers[iris]
    colour[(radius>.198)&iris]*=.56;colour[pupil]=(.012,.010,.008)
    iris_image=skin.image_from_array('des_feeney_referee_eyes_albedo',colour)
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side];m=eye.data.materials[0].copy();m.name='MAT_Des_Referee_Eyes'
        eye.data.materials[0]=m;skin.image_node(m,iris_image,'Base Color')
        m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.28
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.64
    bsdf.inputs['Specular IOR Level'].default_value=.22
    head['identity_reference']='Des Feeney Sr., referee; 69015.jpg portrait and 69018.jpg turnaround'
    head['pigment_policy']='original aged facial anatomy and UV-baked skin/moustache pigment; no portrait projection'
    return mat
