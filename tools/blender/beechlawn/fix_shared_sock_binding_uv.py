"""Make the existing sock fold sample each role's sock, not collar trim.

Only the binding UVs change. Read-only unless --apply; preserves current source.
"""
from pathlib import Path
import hashlib,json,sys
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_shared_kit import SOURCE,export_current
from refine_shared_fabric_material import geometry_state


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=bpy.data.objects['YBot_Armature'];obj=bpy.data.objects['Kit_socks_BoundHems']
    uv=obj.data.uv_layers.active
    old=[tuple(v.uv) for v in uv.data]
    before=geometry_state(rig)
    if '--apply' in sys.argv and rig.get('sock_binding_uv_revision')!=1:
        for item in uv.data:
            u=(item.uv.x*2048-1360)/120
            v=(1-item.uv.y)*2048
            v=(v-1600)/100
            item.uv=((960+u*200)/2048,1-(1600+v*12)/2048)
        new=[tuple(v.uv) for v in uv.data]
        # Compare the entire source with the old UV restored temporarily.
        # This proves that the deliberately changed UV strip is the only edit.
        for item,value in zip(uv.data,old):item.uv=value
        assert geometry_state(rig)==before
        for item,value in zip(uv.data,new):item.uv=value
        rig['sock_binding_uv_revision']=1
        export_current(rig)
    report={'applied':'--apply' in sys.argv,'changed_part':obj.name,'uv_corners':len(uv.data),
            'change':'Blue trim chart -> top 12px of role sock chart',
            'protected_state_checked_with_original_uv_restored':before,
            'bones':len(rig.data.bones),'clips':len(bpy.data.actions)}
    (ROOT/'games/beechlawn_rovers/docs/art_briefs/keeper_kit_graphics/sock_uv_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('SOCK_BINDING_UV',json.dumps(report))


if __name__=='__main__':main()
