"""Re-export manually edited 0131 source; does not regenerate the design.
Blender --background --python tools/art/export_composition_0131.py -- sanctum
"""
import sys,json
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).parent))
import build_composition_0131 as c
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if not args:raise ValueError('Specify edited source names explicitly')
reports=[]
for name in args:
    if name not in c.SPECS:raise ValueError('Unknown source '+name)
    bpy.ops.wm.open_mainfile(filepath=str(c.ROOT/'art/blender/environment/0131'/(name+'.blend')))
    group=bpy.data.collections['02_GAME_EXPORT']
    for obj in list(group.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(group)
    c.a.SOURCE=bpy.data.collections['01_SOURCE_EDITABLE'];c.a.MM=1;c.a.asset='0131_'+name
    c.a.MATS=sorted([m for m in bpy.data.materials if 'atlas_tile' in m],key=lambda m:int(m['atlas_tile']))
    for obj in c.a.SOURCE.objects:obj.hide_set(False);obj.hide_render=False
    reports.append(c.export_source(name,bpy.data.materials['GT_0131_ClusterAtlas']))
path=c.ROOT/'docs/environment/0131/mesh_metrics.json'
old=json.loads(path.read_text());path.write_text(json.dumps(list({r['asset']:r for r in old+reports}.values()),indent=2)+'\n')
print('GRIMTABLE EDITED COMPOSITION EXPORT',json.dumps(reports))
