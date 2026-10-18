"""Read-only Blender source / self-contained GLB and used texture validation."""
import bpy,json,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from validate_models import validate
ROOT=Path(__file__).resolve().parents[2]
results=[]
for item in json.loads((ROOT/'docs/environment/0131/mesh_metrics.json').read_text()):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/item['source']))
    source=bpy.data.collections['01_SOURCE_EDITABLE'];game=bpy.data.collections['02_GAME_EXPORT']
    assert len(source.objects)>0 and 1<=len(game.objects)<=2
    bpy.context.view_layer.update()
    from mathutils import Vector
    for obj in source.objects:
        if not obj.name.startswith('Fractured foundation / continuous'):continue
        corners=[obj.matrix_world@Vector(corner) for corner in obj.bound_box]
        assert max(abs(p.x) for p in corners)<=item['size'][0]/2+.5,item['asset']+' displaced footing X'
        assert max(abs(p.y) for p in corners)<=item['size'][2]/2+.5,item['asset']+' displaced footing Z'
    for obj in game.objects:
        assert obj.data.uv_layers and len(obj.data.materials)==1
        assert all(p.area>1e-14 for p in obj.data.polygons),item['asset']+' degenerate face'
        assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
    result=validate('environment/0131/'+item['asset'],item['export'])
    assert result['triangles']==item['triangles']
    result['source_parts']=len(source.objects);result['nondegenerate_source']=True
    results.append(result)
maps=[]
for name in ['fractured_normal','fractured_ao','sanctum_layout_mask','transport_layout_mask']:
    image=bpy.data.images.load(str(ROOT/'assets/terrain/environment/0131/materials'/(name+'.png')))
    assert tuple(image.size)==(512,512)
    pixels=list(image.pixels);contrast=max(pixels[0::4])-min(pixels[0::4]);assert contrast>.05
    maps.append({'image':name,'size':list(image.size),'red_channel_range':contrast})
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/environment/0131/surface_bake.blend'))
assert bpy.data.collections['01_HIGH_RELIEF_SOURCE'].objects and bpy.data.collections['02_LOW_BAKE_TARGET'].objects
(ROOT/'docs/environment/0131/asset_validation.json').write_text(json.dumps({'assets':results,'textures':maps,'blender':bpy.app.version_string},indent=2)+'\n')
print('GRIMTABLE COMPOSITION SOURCES:',len(results),'editable sources, GLBs and four 512px surface maps pass')
