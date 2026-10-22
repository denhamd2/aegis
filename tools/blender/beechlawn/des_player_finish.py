"""Original anatomical UV skin and facial-hair pigment for Boardeaux Des #9.

All identity masks follow the same centimetre-space sculpt used by the groom.
The exported Principled material has direct image inputs and no vertex-colour
mix chain. The owner's portrait is never projected onto the mesh.
"""
import math
import bpy
import numpy as np
from mathutils import Vector


def smooth(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a)));return t*t*(3-2*t)


def face_lift(y):
    return 1.65*smooth(155.5,159.2,y)*(1-smooth(169.5,174.5,y))-.70*smooth(172,177,y)


def canonical_y(value):
    lo,hi=value-2.0,value+1.0
    for _ in range(16):
        mid=(lo+hi)*.5
        if mid+face_lift(mid)<value:lo=mid
        else:hi=mid
    return (lo+hi)*.5


def masks(p):
    x,y,z=p;y=canonical_y(y);ax=abs(x)
    angle=abs(math.atan2(x,z+1.0))
    side=smooth(.72,1.65,angle);rear=smooth(1.7,2.9,angle)
    lower=171.2-3.0*side-2.6*rear
    scalp=smooth(.88,1.42,angle)*smooth(lower-.55,lower+.95,y)*(1-smooth(173.0,175.1,y))
    frontal=smooth(4.2,7.0,z)
    edge=.025*math.sin(x*8+y*11)+.018*math.sin(x*21-y*15)
    beard=(1-smooth(.78,1.10,math.sqrt((x/3.9)**2+((y-156.5)/2.35)**2)+edge))*frontal
    connectors=math.exp(-((ax-2.85)/.32)**2-((y-158.65)/1.20)**2)*frontal*.6
    soul=smooth(157.85,158.35,y)*(1-smooth(159.0,159.45,y))*(1-smooth(.65,1.1,ax))*frontal
    # Follow the upper lip with a soft arch; leave the vermilion clear.
    centre=160.78-.10*ax
    radius=math.sqrt((x/2.65)**2+((y-centre)/.47)**2)+edge
    moustache=(1-smooth(.62,1.12,radius))*(1-.30*math.exp(-(x/.32)**2))*smooth(6.0,8.0,z)
    goatee=max(beard,connectors*.73,soul*.72,moustache*.83)
    brow_y=168.05+.08*math.exp(-((ax-3.5)/1.4)**2)-.065*(ax-3.5)
    brow=math.exp(-((ax-3.5)/1.65)**6-((y-brow_y)/.25)**2)*smooth(7.0,8.2,z)
    return scalp,goatee,brow


def _smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)


def _canonical_y(values):
    lo=values-2.;hi=values+1.
    for _ in range(16):
        mid=(lo+hi)*.5
        lift=1.65*_smooth(155.5,159.2,mid)*(1-_smooth(169.5,174.5,mid))-.7*_smooth(172,177,mid)
        below=mid+lift<values
        lo=np.where(below,mid,lo);hi=np.where(below,hi,mid)
    return (lo+hi)*.5


def des_skin_colour(points, eyes):
    import shane_player_finish as skin
    x,y,z=points.T; y=_canonical_y(y);ax=np.abs(x)
    colour=np.tile(skin.SKIN_PIGMENT,(len(points),1))
    front=_smooth(3.,7.,z)
    cheek=np.exp(-((ax-4.4)/2.5)**2-((y-163.1)/2.3)**2)*front
    colour+=cheek[:,None]*np.array([.025,-.007,-.009])
    nose=np.exp(-(x/1.5)**4-((y-162.3)/1.6)**2)*front
    colour+=nose[:,None]*np.array([.012,-.006,-.006])
    under=np.exp(-((ax-3.4)/1.65)**4-((y-165.5)/.65)**2)*front
    colour-=under[:,None]*np.array([.018,.019,.018])
    lip=np.exp(-(x/2.65)**6-((y-159.95)/.30)**2)*front
    colour+=lip[:,None]*np.array([.012,-.035,-.020])
    angle=np.abs(np.arctan2(x,z+1.0));side=_smooth(.72,1.65,angle);rear=_smooth(1.7,2.9,angle)
    lower=171.2-3.*side-2.6*rear
    scalp=_smooth(.88,1.42,angle)*_smooth(lower-.55,lower+.95,y)*(1-_smooth(173.0,175.1,y))
    edge=.025*np.sin(x*8+y*11)+.018*np.sin(x*21-y*15)
    beard=(1-_smooth(.78,1.10,np.sqrt((x/3.9)**2+((y-156.5)/2.35)**2)+edge))*_smooth(4.2,7,z)
    connectors=np.exp(-((ax-2.85)/.32)**2-((y-158.65)/1.20)**2)*_smooth(4.2,7,z)*.6
    soul=_smooth(157.85,158.35,y)*(1-_smooth(159.,159.45,y))*(1-_smooth(.65,1.1,ax))*_smooth(4.2,7,z)
    centre=160.78-.10*ax
    radius=np.sqrt((x/2.65)**2+((y-centre)/.47)**2)+edge
    moustache=(1-_smooth(.62,1.12,radius))*(1-.30*np.exp(-(x/.32)**2))*_smooth(6.,8.,z)
    goatee=np.maximum.reduce([beard,connectors*.73,soul*.72,moustache*.83])
    brow_y=168.05+.08*np.exp(-((ax-3.5)/1.4)**2)-.065*(ax-3.5)
    brow=np.exp(-((ax-3.5)/1.65)**6-((y-brow_y)/.25)**2)*_smooth(7.,8.2,z)
    hair=np.maximum.reduce([scalp*.66,goatee*.84,brow*.72])
    fibre=np.sin(x*71+y*19+z*13)*.004+np.sin(x*41-y*89)*.003
    dark=np.stack([.025+fibre,.016+fibre*.7,.011+fibre*.5],axis=1)
    colour=colour*(1-hair[:,None])+dark*hair[:,None]
    # Broad colour variation is low amplitude and independent of illumination.
    colour+=(np.sin(x*2.3+y*1.1+z*.9)*.0018)[:,None]*(1-hair[:,None])
    return np.clip(colour,0,1)


def des_relief(points, eyes):
    x,y,z=points.T;y=_canonical_y(y);ax=np.abs(x)
    front=_smooth(4.,8.,z)
    height=np.zeros_like(x)
    for cy,depth in ((170.2,.002),(171.0,.0015),(171.9,.001)):
        line=cy+.07*np.cos(x*.6)
        height-=depth*np.exp(-((y-line)/.12)**2-(x/5.4)**6)*front
    fold_x=1.7+.40*(162.1-y)
    height-=.003*np.exp(-((ax-fold_x)/.16)**2-((y-160.5)/1.65)**4)*front
    bag=165.2-.10*(ax-3.4)**2
    height-=.002*np.exp(-((y-bag)/.10)**2-((ax-3.4)/1.75)**6)*front
    return height


def finish_head(head):
    import shane_player_finish as skin
    mesh=head.data
    shared_images=[node.image for node in mesh.materials[0].node_tree.nodes if node.type=='TEX_IMAGE' and node.image is not None and 'albedo' in node.image.name]
    assert len(shared_images)==1, 'Resolve the shared head albedo before baking an individual neck transition'
    shared_neck=shared_images[0]
    for attribute in list(mesh.color_attributes):mesh.color_attributes.remove(attribute)
    # New clean node tree: every exported surface input is a glTF-supported
    # image or scalar, so Blender and Godot render the same pigment.
    material=bpy.data.materials.new('MAT_Skin_Des_Feeney_Player');material.use_nodes=True
    mesh.materials[0]=material
    eyes=[sum((v.co for v in bpy.data.objects['Eye_'+side].data.vertices),Vector())/len(bpy.data.objects['Eye_'+side].data.vertices) for side in ('l','r')]
    previous=(skin.SKIN_PIGMENT.copy(),skin.skin_colour,skin.reference_skin_relief)
    from skin_palette import DES_PLAYER_SKIN
    skin.SKIN_PIGMENT=np.array(DES_PLAYER_SKIN,dtype=np.float32)
    skin.skin_colour=des_skin_colour;skin.reference_skin_relief=des_relief
    try:
        skin.bake_skin(head,None,material,eyes,head_only=True,image_prefix='des_feeney_player',detail_only=True,retained_neck_albedo=shared_neck)
    finally:
        skin.SKIN_PIGMENT,skin.skin_colour,skin.reference_skin_relief=previous
    bsdf=material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value=.57
    bsdf.inputs['Specular IOR Level'].default_value=.28
    material.node_tree.nodes.get('Normal Map').inputs['Strength'].default_value=.18
    yy,xx=np.mgrid[0:512,0:512];ex=(xx-255.5)/512;ey=(yy-255.5)/512+.045
    radius=np.sqrt(ex*ex+ey*ey);angle=np.arctan2(ey,ex)
    rgb=np.tile(np.array([.76,.73,.68],dtype=np.float32),(512,512,1))
    iris=radius<.265;pupil=radius<.085
    grain=(np.sin(angle*79+radius*173)+np.sin(angle*37-radius*119))*.009
    for channel,base in enumerate((.15,.105,.060)):rgb[:,:,channel][iris]=base+grain[iris]
    rgb[(radius>.245)&iris]*=.58;rgb[pupil]=(.008,.007,.006)
    eye_image=skin.image_from_array('des_feeney_player_eyes_albedo',rgb)
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side]
        mat=bpy.data.materials.new('MAT_Eye_Des_Player_'+side);mat.use_nodes=True
        eye.data.materials[0]=mat;skin.image_node(mat,eye_image,'Base Color')
        mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.24
    head['identity_reference']='Boardeaux player Des Feeney #9; original 69016.jpg portrait, 69017.jpg turnaround'
    head['pigment_policy']='anatomical UV pigment, licensed source micro-detail and separate groom; no portrait projection'
    return material
