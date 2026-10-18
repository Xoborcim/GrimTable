"""Blender 5: split the preserved 0.13.3 Legion atlas into fitted cosmetic slots.
Run: blender --background --python tools/art/build_workshop.py
Original .blend and GLB files are read only. Output contains all alternatives.
"""
from pathlib import Path
import bpy, bmesh, math, json
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/workshop'; OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/baked_0133/legion_infantry.blend'))
scene=bpy.context.scene
low=next(o for o in bpy.data.collections['02_GAME_EXPORT'].objects if o.type=='MESH')
deps=bpy.context.evaluated_depsgraph_get()
def category(name):
    n=name.lower()
    if any(s in n for s in ['helmet','visor','mandibular','temple conduit','crown raised']): return 'head'
    if any(s in n for s in ['pauldron','socket inset']): return 'shoulders'
    if any(s in n for s in ['backpack','turbine','pack cooling']): return 'backpack'
    if 'rifle' in n: return 'weapon'
    if any(s in n for s in ['thorax','pector','chest','sternum','neck','shoulder','biceps','elbow','forearm','glove','finger','gauntlet']): return 'torso'
    return 'body'

samples=[]
for obj in bpy.data.collections['01_SOURCE_EDITABLE'].objects:
    if obj.type not in ['MESH','CURVE']: continue
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),depsgraph=deps)
    mesh.calc_loop_triangles()
    for t in mesh.loop_triangles:
        p=sum((obj.matrix_world@mesh.vertices[i].co for i in t.vertices),Vector())/3
        samples.append((p,category(obj.name)))
    bpy.data.meshes.remove(mesh)
tree=KDTree(len(samples))
for i,(p,_) in enumerate(samples): tree.insert(p,i)
tree.balance()
owners=[]
for f in low.data.polygons:
    center=low.matrix_world@f.center
    _,i,d=tree.find(center); owners.append(samples[i][1])

export=bpy.data.collections.new('WORKSHOP_GAME_EXPORT');scene.collection.children.link(export)
root=bpy.data.objects.new('LegionWorkshop',None);export.objects.link(root)
root.rotation_euler.z=math.pi
pivots={'body':(0,0,0),'torso':(0,0,19/25.4),'head':(0,0,33.5/25.4),'shoulders':(0,0,19/25.4),'backpack':(0,0,19/25.4),'weapon':(0,0,19/25.4)}
parts={}
for slot,p in pivots.items():
    obj=low.copy();obj.data=low.data.copy();export.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if owners[f.index]!=slot],context='FACES')
    bm.to_mesh(obj.data);bm.free()
    for v in obj.data.vertices: v.co=low.matrix_world@v.co-Vector(p)
    obj.matrix_world=Matrix.Identity(4);obj.parent=root;obj.location=p
    obj.name=slot+'_0';obj.hide_set(False);obj.hide_render=False
    obj.data.uv_layers.active=obj.data.uv_layers.get('BakeUV')
    for uv in list(obj.data.uv_layers):
        if uv.name!='BakeUV': obj.data.uv_layers.remove(uv)
    parts[slot]=obj

def mat(name,color,metal=.0):
    m=bpy.data.materials.new('GTPart_'+name);m.diffuse_color=(*color,1);m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.68
    return m
paint=mat('primary',(.12,.23,.34));metal=mat('metal',(.12,.14,.15),.65);trim=mat('trim',(.55,.45,.25),.35)
def extra(parent,name,loc,scale,material,kind='cube'):
    if kind=='cylinder': bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=1,depth=2)
    elif kind=='plate':
        outline=[(-.72,-1),(.72,-1),(1,-.45),(.82,1),(-.82,1),(-1,-.45)]
        vertices=[(x,y,z) for z in [-1,1] for x,y in outline]
        faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj
    else: bpy.ops.mesh.primitive_cube_add(size=2)
    obj=bpy.context.view_layer.objects.active;obj.name=name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    export.objects.link(obj);obj.parent=parent;obj.location=loc;obj.scale=scale
    obj.data.transform(Matrix.Diagonal((*scale,1)));obj.scale=(1,1,1)
    obj.data.materials.append(material)
    bevel=obj.modifiers.new('Hand-painted bevel','BEVEL');bevel.width=min(scale)*.35;bevel.segments=3
    obj.modifiers.new('Stable export triangles','TRIANGULATE')
    return obj

for slot in ['head','shoulders','backpack','weapon']:
    original=parts[slot]
    for index in [1,2]:
        obj=original.copy();obj.data=original.data.copy();export.objects.link(obj);obj.name=slot+'_'+str(index)
        if slot=='head':
            if index==1:
                extra(obj,'Surveyor sensor crest',(0,.012,.32),(.026,.09,.038),trim)
                extra(obj,'Surveyor antenna',(.15,.10,.35),(.009,.009,.16),metal,'cylinder')
            else:
                extra(obj,'Bastion armored brow',(0,-.17,.21),(.15,.028,.035),paint)
                extra(obj,'Bastion crown ridge',(0,.015,.36),(.032,.105,.028),trim)
        elif slot=='shoulders':
            for side in [-1,1]:
                extra(obj,'Shoulder reinforcement',(side*.415,.015,.51),(.13,.15,.018 if index==1 else .035),paint if index==1 else trim,'plate')
                if index==2:extra(obj,'Shoulder raised rib',(side*.43,-.15,.44),(.09,.014,.045),metal,'plate')
        elif slot=='backpack':
            if index==1:
                extra(obj,'Comms mast',(-.11,.28,.62),(.012,.012,.24),metal,'cylinder')
                extra(obj,'Comms transceiver',(-.11,.28,.79),(.06,.035,.025),paint)
            else:
                for side in [-1,1]:extra(obj,'Coolant canister',(side*.18,.34,.36),(.055,.055,.17),metal,'cylinder')
        else:
            if index==1:extra(obj,'Vented barrel guard',(.20,-.51,.30),(.07,.12,.055),paint)
            else:
                extra(obj,'Reinforced receiver rail',(.20,-.19,.42),(.055,.14,.025),trim)
                extra(obj,'Sight housing',(.20,-.18,.46),(.035,.045,.025),metal)

for index in [0,1,2,3]:
    socket=bpy.data.objects.new('accessory_'+str(index),None);export.objects.link(socket);socket.parent=root;socket.location=(-.28,.10,.77)
    if index==1:extra(socket,'Utility pouch',(0,0,0),(.065,.055,.08),paint)
    if index==2:
        extra(socket,'Field canister',(0,0,0),(.045,.045,.10),metal,'cylinder')
        extra(socket,'Canister strap',(0,-.045,0),(.055,.012,.025),trim)
    if index==3:extra(socket,'Signal tablet',(0,0,0),(.075,.035,.10),trim)

# Small original scenic pieces, bounded within the 32 mm base.
for index in [0,1,2,3]:
    socket=bpy.data.objects.new('decoration_'+str(index),None);export.objects.link(socket);socket.parent=root
    if index==1:
        for j in range(3):extra(socket,'Broken masonry',(-.32+j*.1,-.28,.02+j*.015),(.08,.07,.03),trim)
    if index==2:extra(socket,'Discarded conduit',(-.34,-.22,.055),(.035,.035,.17),metal,'cylinder').rotation_euler.y=math.pi/2
    if index==3:
        extra(socket,'Fractured floor tile',(-.31,-.25,.025),(.16,.10,.025),paint).rotation_euler.z=.35

for obj in scene.objects:obj.select_set(False)
for obj in export.objects:obj.select_set(True);obj.hide_set(False);obj.hide_render=False
bpy.context.view_layer.objects.active=parts['body']
source=ROOT/'art/blender/workshop_0140/legion_components.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'legion_components.glb'),export_format='GLB',use_selection=True,export_apply=True,export_tangents=True,export_animations=False,export_yup=True)
report={'family':'legion_infantry','source':str(source.relative_to(ROOT)),'slots':{'head':['Sentinel','Surveyor','Bastion'],'shoulders':['Standard','Reinforced','Bulwark'],'backpack':['Reactor','Signal','Coolant'],'weapon':['Service','Vented','Rail'],'accessory':['None','Pouch','Canister','Signal tablet'],'decoration':['None','Masonry','Conduit','Fractured tile']},'constraints':'Cosmetic only; 32mm base envelope; head yaw +/-25, upper torso yaw +/-8 degrees; no gameplay stats','category_faces':{s:owners.count(s) for s in pivots}}
report['components']=[{'id':obj.name,'node':obj.name,'family':'legion_infantry','slot':obj.name.split('_')[0],'attachment_position_y_up':[obj.location.x,obj.location.z,-obj.location.y],'pose_compatibility':'rigid_head_and_upper_assembly_v1','material_regions':['primary','trim','metal'],'visual_only':True} for obj in export.objects if obj.name.split('_')[0] in report['slots']]
for component in report['components']:
    component['attachment_rotation_degrees']=[0,0,0]
    component['constraints']={'head_yaw_degrees':[-25,25],'upper_assembly_yaw_degrees':[-8,8],'base_decoration_radius_inches':.63,'affects_collision':False,'affects_los':False,'weapon_statistics':'unchanged'}
(ROOT/'resources/workshop/legion_parts.json').write_text(json.dumps(report,indent=2)+'\n')
print('WORKSHOP ASSETS',json.dumps(report))
