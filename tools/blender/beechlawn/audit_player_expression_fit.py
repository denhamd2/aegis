"""Measure fitted eye closure and the actual occluded/visible dental surface."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES
from refine_feeney_eyes import aperture,surface
SOURCES={**FOUR_SOURCES,'robbie_roden':'robbie_roden_head.blend',
         'david_murray':'david_murray_head.blend'}

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
report={}
for identity in SOURCES:
    bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
    head=bpy.data.objects['Skin_Head']
    closed=[p.co.copy() for p in head.data.shape_keys.key_blocks['Blink'].data]
    eyes={}
    for side in ('l','r'):
        eye=bpy.data.objects['Eye_'+side]
        opened=aperture(head,eye)
        shut=aperture(head,eye,closed,True)
        assert shut['visible_samples']<opened['visible_samples']*.05,(identity,side,opened,shut)
        eyes[side]={'open':opened,'closed':shut}
    report[identity]={'eyes':eyes}
    if identity=='shane_denham':
        dental=bpy.data.objects['Mouth_UpperTeeth']
        counts={}
        for name in ('Basis','Smile'):
            skin=surface(head.data,[p.co.copy() for p in head.data.shape_keys.key_blocks[name].data])
            teeth=surface(dental.data)
            visible=0
            for i in range(201):
                for j in range(61):
                    origin=Vector((-3+i*.03,158.8+j*.03,30))
                    t,_,_,_=teeth.ray_cast(origin,Vector((0,0,-1)))
                    if t is None:continue
                    h,_,_,_=skin.ray_cast(origin,Vector((0,0,-1)))
                    visible+=int(h is None or t.z>h.z+.005)
            counts[name]=visible
        report[identity]['dental_visibility_samples']=counts
        assert counts['Basis']<10,('Teeth protrude through neutral lips',counts)
        assert counts['Smile']>100,('Smile does not expose fitted teeth',identity,counts)
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps({'result':'PASS','players':report,'scope':'Source geometry visibility; native expression appearance remains separate'},indent=2)+'\n')
print('EXPRESSION_FIT PASS',json.dumps(report),flush=True)
