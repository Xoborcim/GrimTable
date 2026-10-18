"""Blender 5.0: re-export existing edited .blend files without rebuilding meshes.

blender --background --python tools/art/export_models.py -- legion_infantry
The build_assets.py authoring script is optional; artists can edit the sources.
"""
import bpy
import json
import sys
import math
import importlib.util
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUTPUTS={
    "legion_infantry":"assets/miniatures/legion/legion_infantry.glb",
    "heavy_walker":"assets/miniatures/legion/heavy_walker.glb",
    "swarm_creature":"assets/miniatures/swarm/swarm_creature.glb",
    "ruined_basilica":"assets/terrain/gothic/ruined_basilica.glb",
}

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
use_game_mesh='--use-game-mesh' in args
names=[arg for arg in args if not arg.startswith('--')]
spec=importlib.util.spec_from_file_location('grimtable_art',ROOT/'tools/art/build_assets.py')
helpers=importlib.util.module_from_spec(spec); spec.loader.exec_module(helpers)
for name in names or OUTPUTS:
    if name not in OUTPUTS: raise ValueError("Unknown authored asset: "+name)
    source=ROOT/'art/blender'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    if not use_game_mesh:
        # Re-evaluate the artist-edited source; never regenerate its design here.
        old=bpy.data.collections['02_GAME_EXPORT']
        for obj in list(old.objects): bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(old)
        helpers.SOURCE=bpy.data.collections['01_SOURCE_EDITABLE']
        helpers.MATS=sorted([mat for mat in bpy.data.materials if 'atlas_tile' in mat],key=lambda mat:int(mat['atlas_tile']))
        helpers.asset=name
        obj,group=helpers.game_mesh(bpy.data.materials['GT_0120_PaintedAtlas'])
    else: group=bpy.data.collections['02_GAME_EXPORT']
    bpy.ops.object.select_all(action='DESELECT')
    models=[obj for obj in group.objects if obj.type=='MESH']
    for obj in models:
        obj.hide_set(False); obj.select_set(True)
        if name!='ruined_basilica': obj.rotation_euler.z+=math.pi
    bpy.context.view_layer.objects.active=models[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/OUTPUTS[name]),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=True,export_extras=False)
    for obj in models:
        if name!='ruined_basilica': obj.rotation_euler.z-=math.pi
    triangles=0
    for obj in models: obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    metrics_path=ROOT/'docs/art'/(name+'_metrics.json')
    metrics=json.loads(metrics_path.read_text()) if metrics_path.exists() else {}
    metrics.update(asset=name,export=OUTPUTS[name],source='art/blender/'+name+'.blend',triangles=triangles,vertices=sum(len(obj.data.vertices) for obj in models),materials=sum(len(obj.data.materials) for obj in models),height_inches=max(obj.dimensions.z for obj in models),animations=[])
    metrics_path.write_text(json.dumps(metrics,indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print('GRIMTABLE RE-EXPORT',name,triangles,'triangles')
