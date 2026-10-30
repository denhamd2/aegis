"""Isolated closed-mouth Robbie smile study; rejected after visual review."""
import bpy,math,sys
from pathlib import Path
here=Path(__file__).resolve().parent;root=here.parents[2];sys.path.insert(0,str(here))
from author_four_head_finish import render
from player_head_groom import build_groom
import shane_player_finish
for strength in (.7,1.0):
 bpy.ops.wm.open_mainfile(filepath=str(here/'robbie_roden_head.blend'))
 head=bpy.data.objects['Skin_Head'];keys=head.data.shape_keys.key_blocks;smile=keys['Smile'];basis=keys['Basis']
 for i,p in enumerate(smile.data):
  x,y,z=basis.data[i].co;ax=abs(x)
  front=max(0,min(1,(z-7.5)/2.3))
  corner=math.exp(-((ax-3.25)/1.05)**4-((y-159.68)/.85)**4)*front
  cheek=math.exp(-((ax-4.55)/2.25)**2-((y-162.0)/1.95)**2)*front
  lowerlid=math.exp(-((ax-3.45)/1.65)**4-((y-165.50)/.65)**4)*front
  upper=math.exp(-(x/3.2)**6-((y-160.10)/.43)**4)*front
  p.co.x+=math.copysign(.20*corner*strength,x)
  p.co.y+=(.50*corner+.20*cheek+.12*lowerlid+.04*upper)*strength
  p.co.z+=(.06*corner+.22*cheek+.07*lowerlid)*strength
 smile.value=1
 out=root/f'games/beechlawn_rovers/build/five_rounds/round_2_pilot_{strength}/robbie_roden'
 shane_player_finish.TEXTURES=out/'temporary_textures';shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
 build_groom(head,bpy.data.objects['YBot_Armature'],'robbie_roden')
 render(head,out,views=('front','threequarter'))
 print('SMILE_PILOT',strength,flush=True)
