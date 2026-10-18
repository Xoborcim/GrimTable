"""Run in Blender: verifies all four editable source/game collections and normals."""
import bpy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
results=[]
for name in ['legion_infantry','heavy_walker','swarm_creature','ruined_basilica']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender'/(name+'.blend')))
    source=bpy.data.collections['01_SOURCE_EDITABLE']
    game=bpy.data.collections['02_GAME_EXPORT']
    assert len(source.objects)>15 and len(game.objects)==1
    obj=game.objects[0]
    assert obj.type=='MESH' and obj.data.uv_layers
    assert all(poly.area>1e-14 for poly in obj.data.polygons)
    assert all(all(abs(c)<1000 for c in vertex.co) for vertex in obj.data.vertices)
    assert not obj.animation_data
    results.append(dict(asset=name,editable_parts=len(source.objects),game_meshes=len(game.objects),uv_layer=obj.data.uv_layers.active.name))
(ROOT/'docs/art/source_validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('GRIMTABLE BLENDER SOURCES PASS',json.dumps(results))
