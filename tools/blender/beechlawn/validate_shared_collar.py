"""Actual mesh/pose collar regressions; Blender source QA, no build dependency."""
from pathlib import Path
import argparse,json,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_shared_kit import SOURCE
from refine_shared_shoulders import folds,POSES

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',default=str(SOURCE))
    parser.add_argument('--out',default=str(ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_collar_raglan/collar_validation.json'))
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.source).resolve()))
    rig=bpy.data.objects['YBot_Armature']
    obj=bpy.data.objects['Kit_Shane_ContinuousVBinding'];obj.data.calc_loop_triangles()
    count=int(obj.get('collar_vertex_count',min(480,len(obj.data.vertices))))
    assert all(t.area>1e-7 for t in obj.data.loop_triangles),'Collapsed trim faces'
    results=folds(rig,obj,[tuple(t.vertices) for t in obj.data.loop_triangles])
    report={'trim_triangles':len(obj.data.loop_triangles),'collar_vertices_per_pose':count,
            'inverted_trim_triangles':{n:v['inverted_triangles'] for n,v in results.items()},'skin':{},
            'limits':'Vertex samples against evaluated source skin in nine fixed poses; not an all-pose, per-pixel or native M1 acceptance.'}
    for name,frame in POSES:
        rig.animation_data.action=bpy.data.actions['AN_Beechlawn_'+name]
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        points=[];faces=[]
        for part in ('YBot_Joints','Skin_Head'):
            evaluated=bpy.data.objects[part].evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh=evaluated.to_mesh();mesh.calc_loop_triangles();offset=len(points)
            points += [v.co.copy() for v in mesh.vertices]
            faces += [tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles]
            evaluated.to_mesh_clear()
        skin=BVHTree.FromPolygons(points,faces,all_triangles=True)
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
        negative=[];minimum=float('inf')
        for v in list(mesh.vertices)[:count]:
            hit,normal,_,_=skin.find_nearest(v.co)
            signed=(v.co-hit).dot(normal);minimum=min(minimum,signed)
            # 0.1 mm numerical tolerance in the rig's centimetre space.
            if signed<-.01:negative.append((v.index,round(signed,5)))
        mesh.calc_loop_triangles()
        assert all(t.area>1e-7 for t in mesh.loop_triangles),('Collapsed posed trim',name)
        evaluated.to_mesh_clear()
        report['skin'][name]={'penetrating_vertices':len(negative),'minimum_signed_clearance_cm':minimum,
                              'worst_vertices':sorted(negative,key=lambda p:p[1])[:5]}
    target=Path(args.out);target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(report,indent=2)+'\n')
    assert not any(v['penetrating_vertices'] for v in report['skin'].values()),'Collar penetrates evaluated skin'
    assert not any(report['inverted_trim_triangles'].values()),'Trim inverts in a fixed pose'
    print('SHARED_COLLAR_VALIDATION PASS '+json.dumps({'poses':len(POSES),'samples_per_pose':count,'triangles':report['trim_triangles']}),flush=True)

if __name__=='__main__':main()
