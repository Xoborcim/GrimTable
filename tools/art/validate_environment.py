"""Run in Blender 5: read-only source and self-contained GLB validation."""
import bpy,json,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from validate_models import validate
results=[]
for item in json.loads((ROOT/'docs/environment/mesh_metrics.json').read_text()):
    name=item['asset']
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/environment'/(name+'.blend')))
    source=bpy.data.collections['01_SOURCE_EDITABLE'];game=bpy.data.collections['02_GAME_EXPORT']
    assert len(source.objects)>0 and len(game.objects)==1
    obj=game.objects[0];assert obj.data.uv_layers
    assert all(p.area>1e-14 for p in obj.data.polygons)
    assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
    result=validate('environment/'+name,'assets/terrain/environment/'+name+'.glb')
    assert result['triangles']==item['triangles']
    result['source_parts']=len(source.objects);result['nondegenerate_source']=True
    results.append(result)
(ROOT/'docs/environment/asset_validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('GRIMTABLE ENVIRONMENT SOURCES: 8 sources and GLBs pass')
