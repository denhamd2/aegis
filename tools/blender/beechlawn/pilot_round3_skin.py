"""Isolated photo-registered skin-detail study; rejected after visual review."""
import bpy,json,sys,numpy as np
from pathlib import Path
here=Path(__file__).resolve().parent;root=here.parents[2];sys.path.insert(0,str(here))
inputs=root/'games/beechlawn_rovers/docs/art_briefs/br022_five_rounds_2026_10_30/inputs'
from author_four_head_finish import render
from player_head_groom import build_groom
import shane_player_finish
bpy.ops.wm.open_mainfile(filepath=str(here/'robbie_roden_head.blend'))
head=bpy.data.objects['Skin_Head'];rig=bpy.data.objects['YBot_Armature']
node=next(n for n in head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'head_anatomical_albedo' in n.image.name)
image=node.image;size=image.size[0];pixels=np.empty(size*size*4,dtype=np.float32);image.pixels.foreach_get(pixels);atlas=pixels.reshape(size,size,4).copy()
photo_image=bpy.data.images.load(str(inputs/'robbie_reference_crop.png'))
pw,ph=photo_image.size;pixels=np.empty(pw*ph*4,dtype=np.float32);photo_image.pixels.foreach_get(pixels);photo=pixels.reshape(ph,pw,4)[:,:,:3]
def blur(a,r):
 for axis in (0,1):
  pad=[(0,0)]*3;pad[axis]=(r,r);p=np.pad(a,pad,mode='edge')
  shape=list(p.shape);shape[axis]=1
  s=np.concatenate((np.zeros(shape,dtype=np.float32),np.cumsum(p,axis=axis,dtype=np.float32)),axis=axis)
  l=[slice(None)]*3;h=[slice(None)]*3;l[axis]=slice(0,a.shape[axis]);h[axis]=slice(2*r+1,None)
  a=(s[tuple(h)]-s[tuple(l)])/(2*r+1)
 return a
low=blur(blur(photo,8),8);detail=np.clip(photo/np.maximum(low,.025),.75,1.25)
record=json.loads((inputs/'robbie_landmarks.json').read_text())['players']['robbie_roden']['reference']
points=np.array(record['image_points']);left,right=points[468,:2],points[473,:2]
if left[0]>right[0]:left,right=right,left
centre=(left+right)*.5;axis=right-left;distance=np.linalg.norm(axis);c,s=axis/distance
mesh=head.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active
model=json.loads((inputs/'robbie_landmarks.json').read_text())['players']['robbie_roden']['model']
indices=[10,338,297,332,284,251,389,356,454,323,361,288,397,365,379,378,400,377,152,148,176,149,150,136,172,58,132,93,234,127,162,21,54,103,67,109,33,133,159,145,362,263,386,374,70,63,105,66,107,336,296,334,293,300,1,2,4,5,6,19,94,97,98,327,326,168,61,291,13,14,0,17,78,308,82,312]
model_points=np.asarray(model['normalized_points'])[indices,:2];photo_points=np.asarray(record['normalized_points'])[indices,:2]
def kernel(dist):
 return dist*dist*np.log(np.maximum(dist,1e-5))
n=len(indices);offset=model_points[:,None,:]-model_points[None,:,:];distance_grid=np.linalg.norm(offset,axis=2)
K=kernel(distance_grid)+np.eye(n)*.006;A=np.block([[K,np.ones((n,1)),model_points],[np.ones((1,n)),np.zeros((1,3))],[model_points.T,np.zeros((2,3))]])
coef=np.linalg.solve(A,np.concatenate((photo_points-model_points,np.zeros((3,2)))))
def warp(nx,ny):
 query=np.stack((nx.ravel(),ny.ravel()),axis=1)
 weight=kernel(np.linalg.norm(query[:,None,:]-model_points[None,:,:],axis=2))
 disp=np.concatenate((weight,np.ones((len(query),1)),query),axis=1)@coef
 disp=np.clip(disp,-.26,.26)
 return (query+disp).reshape((*nx.shape,2))
coverage=np.zeros((size,size),dtype=bool);applied=0
for triangle in mesh.loop_triangles:
 coords=np.array([uv.data[i].uv[:] for i in triangle.loops])*(size-1)
 lo=np.maximum(0,np.floor(coords.min(axis=0)).astype(int));hi=np.minimum(size-1,np.ceil(coords.max(axis=0)).astype(int))
 if (hi<lo).any():continue
 ax,ay=coords[0];bx,by=coords[1];cx,cy=coords[2];den=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
 if abs(den)<1e-8:continue
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
 a=((by-cy)*(xx-cx)+(cx-bx)*(yy-cy))/den;b=((cy-ay)*(xx-cx)+(ax-cx)*(yy-cy))/den;d=1-a-b
 inside=(a>=-.005)&(b>=-.005)&(d>=-.005)
 coords3=np.array([mesh.vertices[i].co[:] for i in triangle.vertices]);world=a[...,None]*coords3[0]+b[...,None]*coords3[1]+d[...,None]*coords3[2]
 wx,wy,wz=world[:,:,0],world[:,:,1],world[:,:,2]
 def smooth(q0,q1,x):
  t=np.clip((x-q0)/(q1-q0),0,1);return t*t*(3-2*t)
 cheek=smooth(2.0,2.9,np.abs(wx))*(1-smooth(5.2,6.8,np.abs(wx)))*smooth(160.6,162.1,wy)*(1-smooth(164.8,166.0,wy))
 forehead=smooth(168.4,169.3,wy)*(1-smooth(172.0,173.2,wy))*(1-smooth(5.0,6.5,np.abs(wx)))
 mask=smooth(7.2,9.2,wz)*np.clip(cheek+forehead,0,1)
 nx=wx/6.694;ny=(wy-166.526)/6.694
 mapped=warp(nx,ny);nx,ny=mapped[:,:,0],mapped[:,:,1]
 px=centre[0]+distance*(nx*c+ny*s);py=centre[1]+distance*(nx*s-ny*c)
 px=np.clip(np.rint(px).astype(int),0,pw-1);py=np.clip(np.rint(ph-1-py).astype(int),0,ph-1)
 mask*=inside*(px>1)*(px<pw-2)*(py>1)*(py<ph-2)
 region=atlas[lo[1]:hi[1]+1,lo[0]:hi[0]+1,:3]
 factor=1+(.70*mask)[...,None]*(detail[py,px]-1)
 region[inside]=np.clip(region[inside]*factor[inside],0,1)
 coverage[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=inside&(mask>.05)
 applied+=np.count_nonzero(inside&(mask>.05))
image.pixels.foreach_set(atlas.reshape(-1));image.update();image.pack()
out=root/'games/beechlawn_rovers/build/skin-pilot-tps';out.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'robbie_photo_skin.blend'),compress=True)
shane_player_finish.TEXTURES=out/'temporary_textures';shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
build_groom(head,rig,'robbie_roden');render(head,out,views=('front','threequarter'))
print('PHOTO_SKIN_PILOT',applied,int(coverage.sum()),flush=True)
