"""Re-export only current fitted grooms; avoid rebaking untouched skin atlases."""
from pathlib import Path
import argparse
import sys
import bpy
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES
from build_roster_heads import export
from player_head_groom import build_groom
OUTPUTS={'shane_denham':'shane_crop','john_orourke':'john_swept',
         'bordeaux_09':'des_side_hair','des_feeney_sr':'referee_grey'}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--player',choices=SOURCES)
parser.add_argument('--save-source',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for identity,filename in SOURCES.items():
    if args.player and args.player != identity:
        continue
    bpy.ops.wm.open_mainfile(filepath=str(HERE/filename))
    rig=bpy.data.objects['YBot_Armature']
    rig.animation_data_clear()
    build_groom(bpy.data.objects['Skin_Head'],rig,identity)
    if args.save_source:
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(HERE/filename),compress=True)
    export(ROOT/f'games/beechlawn_rovers/assets/characters/shared/heads/{OUTPUTS[identity]}.glb',
           ('Hair_Shane_ShortCropRoots','Hair_Shane_ShortCropCards'))
print('GROOM_ONLY_EXPORT PASS',flush=True)
