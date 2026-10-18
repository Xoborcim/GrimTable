"""Blender 5: export edited environment source without regenerating design.

-- gatehouse (or any name in build_environment.ASSETS). No automatic unit yaw.
"""
import sys,json
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).parent))
import build_environment as env
a=env.a;ROOT=env.ROOT
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for name in args or env.ASSETS:
    if name not in env.ASSETS:raise ValueError('Unknown environment source')
    source=ROOT/'art/blender/environment'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    group=bpy.data.collections['02_GAME_EXPORT']
    for obj in list(group.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(group)
    a.SOURCE=bpy.data.collections['01_SOURCE_EDITABLE'];a.asset='environment_'+name
    a.MATS=sorted([m for m in bpy.data.materials if 'atlas_tile' in m],key=lambda m:int(m['atlas_tile']))
    obj,group=a.game_mesh(bpy.data.materials['GT_EnvironmentAtlas'])
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/terrain/environment'/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    obj.data.calc_loop_triangles()
    path=ROOT/'docs/environment/mesh_metrics.json';metrics=json.loads(path.read_text())
    for metric in metrics:
        if metric['asset']==name:metric['triangles']=len(obj.data.loop_triangles)
    path.write_text(json.dumps(metrics,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print('ENVIRONMENT SOURCE RE-EXPORT',name,len(obj.data.loop_triangles))
