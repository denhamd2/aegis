"""Sample the archived CC0 Toigo skin through the original anatomical UVs.

This supplies skin detail, not a front-facing portrait or a replacement head.
The head's dense UV allocation is an affine remap of those same source islands.
"""
from functools import lru_cache
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'games/beechlawn_rovers/references/third_party/makehuman/skin_toigo'


@lru_cache(maxsize=2)
def source_pixels(kind):
    if kind!='albedo':
        # This clean skin supplies pigment. Use our separately authored
        # relief; do not inherit scars or bruising from another skin's maps.
        return np.array([[[.5,.5,1.0]]],dtype=np.float32)
    path=SOURCE/'young_lightskinned_male_diffuse_Bronze.png'
    image=bpy.data.images.load(str(path),check_existing=True)
    image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
    pixels=np.empty(image.size[0]*image.size[1]*4,dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape(image.size[1],image.size[0],4)[:,:,:3]


def sample_skin(kind,size,head=None):
    source=source_pixels(kind);h,w=source.shape[:2]
    v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1)
    if head is not None:
        low=np.array(head['skin_source_uv_low']);span=np.array(head['skin_source_uv_span'])
        u=low[0]+(u-.02)*span[0]/.96
        v=low[1]+(v-.02)*span[1]/.96
    x=np.clip(u,0,1)*(w-1);y=np.clip(v,0,1)*(h-1)
    ix=x.astype(int);iy=y.astype(int);jx=np.minimum(ix+1,w-1);jy=np.minimum(iy+1,h-1)
    fx=(x-ix)[:,:,None];fy=(y-iy)[:,:,None]
    return ((source[iy,ix]*(1-fx)+source[iy,jx]*fx)*(1-fy)+
            (source[jy,ix]*(1-fx)+source[jy,jx]*fx)*fy).astype(np.float32)


def skin_tint(target):
    pixels=source_pixels('albedo')[::4,::4].reshape(-1,3)
    skin=(pixels[:,0]>pixels[:,1]*1.12)&(pixels[:,1]>pixels[:,2]*1.05)&(pixels[:,2]>.18)&(pixels[:,0]<.94)
    median=np.median(pixels[skin],axis=0)
    return np.clip(target/median,.75,1.25)
