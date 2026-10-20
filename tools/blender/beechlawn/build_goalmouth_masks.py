"""Original goalmouth wear/water masks in world metres; no photo projection.
R=mud, G=standing water. Both Godot's material and ball sample this same PNG.
"""
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/environment/surfaces/kilmore_goalmouth_masks.png'
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def build():
 w,h=1024,512
 x=((np.arange(w)+.5)/w-.5)*105
 z=((np.arange(h)+.5)/h-.5)*68
 x,z=np.meshgrid(x,z);mud=np.zeros_like(x);water=np.zeros_like(x)
 for side in (-1,1):
  # Different depressions at each goal, all in the keeper's heavily worn arc.
  dx=x-side*50.6
  noise=.12*np.sin(x*3.1+z*2.7)+.08*np.sin(x*6.7-z*4.3)+.11*np.sin(z*1.8+x*.8)
  wear=np.exp(-((dx/4.0)**2+(z/5.3)**2))
  mud=np.maximum(mud,smooth(.12,.72,wear+noise*.24))
  for cx,cz,rx,rz in ((50.9*side,-1.5*side,1.7,1.15),(48.5*side,1.3*side,1.45,.85),(51.3*side,2.4*side,1.15,.65)):
   d=((x-cx)/rx)**2+((z-cz)/rz)**2
   water=np.maximum(water,1-smooth(.66,1.2,d+noise*1.8))
 water*=smooth(.25,.7,mud)
 rgb=np.stack((mud,water,np.zeros_like(mud)),axis=-1)
 OUT.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(np.uint8(np.clip(rgb,0,1)*255)).save(OUT)
 print(OUT)
if __name__=='__main__':build()
