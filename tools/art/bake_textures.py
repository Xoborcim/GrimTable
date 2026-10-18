"""GrimTable 0.13.3: derive padded UVs, local surface bakes and GLBs.

Run with ordinary Python: python tools/art/bake_textures.py --assets sanctum legion_infantry
Original .blend files are read only. Derived editable low/high sources are saved
under art/blender/baked_0133; existing GLB destinations receive the finished art.
Existing exports are copied to a content-addressed .runtime/bake_backups folder
before replacement. The milestone also preserves a complete 0.13.2 archive.
"""
from pathlib import Path
import argparse, hashlib, json, math, os, shutil, struct, subprocess, sys, time

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'assets/materials/baked_0133'
SOURCES=ROOT/'art/blender/baked_0133'
REPORTS=ROOT/'docs/art/baked_0133'
ASSETS={
 'legion_infantry':('art/blender/legion_infantry.blend','assets/miniatures/legion/legion_infantry.glb',1024,'armor'),
 'heavy_walker':('art/blender/heavy_walker.blend','assets/miniatures/legion/heavy_walker.glb',2048,'armor'),
 'swarm_creature':('art/blender/swarm_creature.blend','assets/miniatures/swarm/swarm_creature.glb',1024,'organic'),
 'sanctum':('art/blender/environment/0131/sanctum.blend','assets/terrain/environment/0131/sanctum.glb',2048,'stone'),
 'transept':('art/blender/environment/0131/transept.blend','assets/terrain/environment/0131/transept.glb',1024,'stone'),
 'breached_gate':('art/blender/environment/0131/breached_gate.blend','assets/terrain/environment/0131/breached_gate.glb',1024,'stone'),
 'shrine':('art/blender/environment/0131/shrine.blend','assets/terrain/environment/0131/shrine.glb',512,'stone'),
 'industrial_wreck':('art/blender/environment/0131/industrial_wreck.blend','assets/terrain/environment/0131/industrial_wreck.glb',1024,'industrial'),
 'checkpoint':('art/blender/environment/0131/checkpoint.blend','assets/terrain/environment/0131/checkpoint.glb',1024,'industrial'),
 'pipeline':('art/blender/environment/0131/pipeline.blend','assets/terrain/environment/0131/pipeline.glb',512,'industrial'),
 'crater':('art/blender/environment/0131/crater.blend','assets/terrain/environment/0131/crater.glb',512,'stone'),
 'station_hall':('art/blender/environment/0131/station_hall.blend','assets/terrain/environment/0131/station_hall.glb',2048,'industrial'),
 'refinery_core':('art/blender/environment/refinery_core.blend','assets/terrain/environment/refinery_core.glb',1024,'industrial'),
 'scenic_ground':('art/blender/legion_infantry.blend','assets/miniatures/bases/scenic_ground.glb',512,'base'),
}
PALETTE=['315f86','86a8bc','c5bda5','48515a','202830','a08d5f','76c9c7','594350','493456','998388','d1bc8b','73513b','827d6d','55584e','a6ada8','474239']
ROUGH=[.68,.64,.78,.55,.86,.66,.35,.94,.72,.84,.69,.89,.93,.95,.39,.98]
METAL=[.18,.15,0,.72,.24,.65,.25,0,0,0,0,.38,0,0,.86,0]

def digest(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def repair_subpixel_tangents(path):
    """Give vanishing bevel slivers a finite orthogonal tangent after export.

    MikkTSpace returns zero for numerically degenerate UV derivatives. Retain
    their silhouette geometry; reject this workaround on meaningful face area.
    """
    import numpy as np
    data=bytearray(path.read_bytes());length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]);start=20+length+8;repairs=0;affected=0.;area=0.
    def view(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
        size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride=v.get('byteStride',np.dtype(dtype).itemsize*size)
        return np.ndarray((a['count'],size),dtype=dtype,buffer=data,offset=start+v.get('byteOffset',0)+a.get('byteOffset',0),strides=(stride,np.dtype(dtype).itemsize))
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attributes=primitive['attributes'];t=view(attributes['TANGENT']);normals=view(attributes['NORMAL'])
            bad=np.linalg.norm(t[:,:3],axis=1)<.5
            indices=view(primitive['indices']).reshape(-1,3);p=view(attributes['POSITION'])[indices]
            areas=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)*.5
            affected+=float(areas[bad[indices].any(axis=1)].sum());area+=float(areas.sum())
            for i in np.flatnonzero(bad):
                n=normals[i];axis=np.array([1,0,0]) if abs(n[0])<.8 else np.array([0,1,0])
                tangent=np.cross(n,axis);t[i,:3]=tangent/np.linalg.norm(tangent);repairs+=1
    if affected/max(area,1e-9)>1e-4:raise RuntimeError('UV tangent degeneracy affects meaningful surface area; improve unwrap')
    path.write_bytes(data)
    return {'fallback_vertices':repairs,'affected_surface_fraction':affected/max(area,1e-9),'method':'Orthogonal fallback only for numerically degenerate, subpixel bevel slivers; no geometry removed'}

def launcher():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets',nargs='+',choices=list(ASSETS),default=['sanctum','legion_infantry'])
    parser.add_argument('--blender',type=Path)
    parser.add_argument('--samples',type=int,default=12)
    args=parser.parse_args()
    blender=args.blender or shutil.which('blender') or os.environ.get('BLENDER_EXE') or Path('C:/Program Files/Blender Foundation/Blender 5.0/blender.exe')
    if not Path(blender).is_file():parser.error('Blender not found: pass --blender PATH or BLENDER_EXE')
    REPORTS.mkdir(parents=True,exist_ok=True)
    for name in args.assets:
        source=ROOT/ASSETS[name][0]
        if not source.exists():parser.error('Missing original source '+str(source))
        original=digest(source)
        existing=ROOT/ASSETS[name][1]
        if existing.exists():
            backup=ROOT/'.runtime/bake_backups'/(name+'_'+digest(existing)+'.glb')
            backup.parent.mkdir(parents=True,exist_ok=True)
            if not backup.exists():shutil.copy2(existing,backup)
        derived=SOURCES/(name+'.blend')
        if derived.exists():
            backup=ROOT/'.runtime/bake_backups'/(name+'_'+digest(derived)+'.blend')
            backup.parent.mkdir(parents=True,exist_ok=True)
            if not backup.exists():shutil.copy2(derived,backup)
        print('BAKING',name,flush=True)
        log=REPORTS/(name+'_bake.log')
        with log.open('w',encoding='utf8') as output:
            result=subprocess.run([str(blender),'--background','--disable-autoexec','--python-exit-code','1','--python',str(Path(__file__)),'--',name,str(max(4,args.samples))],cwd=ROOT,stdout=output,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError(f'{name}: Blender failed ({result.returncode}); see {log}\n'+log.read_text(encoding='utf8',errors='replace')[-3500:])
        if digest(source)!=original:raise RuntimeError('Original source unexpectedly changed: '+str(source))
        print('BAKED',name,flush=True)

def worker(name,samples):
    import faulthandler
    faulthandler.dump_traceback_later(60,repeat=True)
    import bpy
    import numpy as np
    from mathutils import Vector
    started=time.monotonic()
    source,export,resolution,kind=ASSETS[name]
    source=ROOT/source
    source_hash=digest(source)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    print('BAKE STAGE',name,'loaded source',flush=True)
    scene=bpy.context.scene
    # Remove render-only scene objects from the bake's visibility, not from source.
    for obj in scene.objects:obj.hide_render=True
    game=bpy.data.collections.get('02_GAME_EXPORT')
    if game is None:raise RuntimeError('Missing 02_GAME_EXPORT collection')
    if name=='scenic_ground':
        game.name='ORIGINAL_EXPORT_0120'
        game=bpy.data.collections.new('02_GAME_EXPORT');scene.collection.children.link(game)
        parts=[]
        for obj in bpy.data.collections['03_STUDIO_BASE'].objects:
            if obj.type=='MESH' and obj.name.endswith('__game') and 'beveled painted rim' not in obj.name:
                copy=obj.copy();copy.data=obj.data.copy();game.objects.link(copy);copy.hide_set(False);parts.append(copy)
        if not parts:raise RuntimeError('Missing evaluated studio-base parts')
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name='GT_SharedScenicGround'
    lows=[obj for obj in game.objects if obj.type=='MESH']
    if not lows:raise RuntimeError('No export meshes')
    directory=OUTPUT/name;directory.mkdir(parents=True,exist_ok=True)
    SOURCES.mkdir(parents=True,exist_ok=True);REPORTS.mkdir(parents=True,exist_ok=True)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=samples
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.render.bake.margin=4 if resolution<=1024 else 8
    scene.render.bake.margin_type='EXTEND'
    scene.render.bake.use_clear=False
    scene.render.bake.normal_space='TANGENT'
    scene.render.bake.normal_r='POS_X';scene.render.bake.normal_g='POS_Y';scene.render.bake.normal_b='POS_Z'
    if scene.world is None:scene.world=bpy.data.worlds.new('Neutral bake world')
    scene.world.color=(.05,.05,.05)
    miniature=kind in ['armor','organic']
    max_z=max((o.matrix_world@Vector(c)).z for o in lows for c in o.bound_box)
    min_z=min((o.matrix_world@Vector(c)).z for o in lows for c in o.bound_box)
    mats=[];bake_nodes=[]

    def color(hex):
        channels=[int(hex[i:i+2],16)/255 for i in [0,2,4]]
        return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in channels)

    def node(tree,typ):return tree.nodes.new(typ)
    def mathnode(tree,op,a,b=0):
        if op=='CLAMP':return mathnode(tree,'MINIMUM',1,mathnode(tree,'MAXIMUM',0,a))
        n=node(tree,'ShaderNodeMath');n.operation=op
        for i,value in enumerate([a,b]):
            if isinstance(value,(int,float)):n.inputs[i].default_value=value
            else:tree.links.new(value,n.inputs[i])
        return n.outputs[0]
    def combine(tree,channels):
        n=node(tree,'ShaderNodeCombineXYZ')
        for i,value in enumerate(channels):
            if isinstance(value,(int,float)):n.inputs[i].default_value=value
            else:tree.links.new(value,n.inputs[i])
        return n.outputs[0]

    for tile in range(16):
        mat=bpy.data.materials.new(f'BakeRecipe_{tile:02d}');mat.use_nodes=True
        tree=mat.node_tree;tree.nodes.clear()
        output=node(tree,'ShaderNodeOutputMaterial');emit=node(tree,'ShaderNodeEmission');tree.links.new(emit.outputs[0],output.inputs['Surface'])
        geometry=node(tree,'ShaderNodeNewGeometry');coords=node(tree,'ShaderNodeTexCoord')
        separate=node(tree,'ShaderNodeSeparateXYZ');tree.links.new(geometry.outputs['Position'],separate.inputs[0])
        height=mathnode(tree,'MULTIPLY',mathnode(tree,'SUBTRACT',separate.outputs['Z'],min_z),1/max(.001,max_z-min_z))
        foot=mathnode(tree,'MAXIMUM',0,mathnode(tree,'SUBTRACT',1,mathnode(tree,'MULTIPLY',height,5 if miniature else 2.6)))
        edge=mathnode(tree,'CLAMP',mathnode(tree,'MULTIPLY',mathnode(tree,'SUBTRACT',geometry.outputs['Pointiness'],.49),12))
        if tile==1 and kind=='armor':edge=mathnode(tree,'MAXIMUM',edge,.75)
        cavity=mathnode(tree,'CLAMP',mathnode(tree,'MULTIPLY',mathnode(tree,'SUBTRACT',.50,geometry.outputs['Pointiness']),12))
        dirt=mathnode(tree,'MINIMUM',.65,mathnode(tree,'ADD',mathnode(tree,'MULTIPLY',foot,.45),mathnode(tree,'MULTIPLY',cavity,.4)))
        noise=node(tree,'ShaderNodeTexNoise');noise.inputs['Scale'].default_value=35 if miniature else 5
        noise.inputs['Detail'].default_value=2;tree.links.new(coords.outputs['Object'],noise.inputs['Vector'])
        wear_noise=node(tree,'ShaderNodeTexNoise');wear_noise.inputs['Scale'].default_value=190 if miniature else 12
        wear_noise.inputs['Detail'].default_value=1.5;tree.links.new(coords.outputs['Object'],wear_noise.inputs['Vector'])
        chips=mathnode(tree,'CLAMP',mathnode(tree,'MULTIPLY',mathnode(tree,'SUBTRACT',wear_noise.outputs['Fac'],.53),5))
        wear=mathnode(tree,'MULTIPLY',edge,chips)
        paint=tile in [0,1,2,5] and kind=='armor'
        surface_palette={2:'939b91',12:'747d76',13:'4c544d'} if not miniature else {}
        base=(.72,.72,.72) if paint and tile!=1 else ((1,1,1) if paint else color(surface_palette.get(tile,PALETTE[tile])))
        factor=mathnode(tree,'ADD',.91,mathnode(tree,'MULTIPLY',noise.outputs['Fac'],.16))
        if not miniature and tile in [2,12,13]:
            # Paint course joints into the same object-local pattern carved in
            # the high mesh. Surface variation follows the architecture.
            x,y,z=(separate.outputs[k] for k in ['X','Y','Z'])
            normal_parts=node(tree,'ShaderNodeSeparateXYZ');tree.links.new(geometry.outputs['Normal'],normal_parts.inputs[0])
            floor=mathnode(tree,'GREATER_THAN',mathnode(tree,'ABSOLUTE',normal_parts.outputs['Z']),.7)
            u=mathnode(tree,'ADD',x,mathnode(tree,'MULTIPLY',y,mathnode(tree,'SUBTRACT',1,floor)))
            v=mathnode(tree,'ADD',mathnode(tree,'MULTIPLY',z,mathnode(tree,'SUBTRACT',1,floor)),mathnode(tree,'MULTIPLY',y,floor))
            row=mathnode(tree,'DIVIDE',v,.48)
            stagger=mathnode(tree,'MULTIPLY',mathnode(tree,'MODULO',mathnode(tree,'FLOOR',row),2),.58)
            fu=mathnode(tree,'FRACT',mathnode(tree,'DIVIDE',mathnode(tree,'ADD',u,stagger),1.16))
            fv=mathnode(tree,'FRACT',row)
            du=mathnode(tree,'MULTIPLY',mathnode(tree,'MINIMUM',fu,mathnode(tree,'SUBTRACT',1,fu)),1.16)
            dv=mathnode(tree,'MULTIPLY',mathnode(tree,'MINIMUM',fv,mathnode(tree,'SUBTRACT',1,fv)),.48)
            mortar=mathnode(tree,'CLAMP',mathnode(tree,'MULTIPLY',mathnode(tree,'SUBTRACT',.035,mathnode(tree,'MINIMUM',du,dv)),32))
            factor=mathnode(tree,'MULTIPLY',factor,mathnode(tree,'SUBTRACT',1,mathnode(tree,'MULTIPLY',mortar,.24)))
            blocks=node(tree,'ShaderNodeTexWhiteNoise');blocks.noise_dimensions='3D'
            tree.links.new(combine(tree,[mathnode(tree,'FLOOR',mathnode(tree,'DIVIDE',mathnode(tree,'ADD',u,stagger),1.16)),mathnode(tree,'FLOOR',row),0]),blocks.inputs['Vector'])
            factor=mathnode(tree,'MULTIPLY',factor,mathnode(tree,'ADD',.86,mathnode(tree,'MULTIPLY',blocks.outputs['Value'],.28)))
        if kind=='organic' and tile==8:factor=mathnode(tree,'ADD',.80,mathnode(tree,'MULTIPLY',height,.32))
        pigment=combine(tree,[mathnode(tree,'MULTIPLY',factor,c) for c in base])
        primary=1.0 if kind=='armor' and tile in [0,1] else 0.0
        secondary=1.0 if kind=='armor' and tile==2 else 0.0
        trim=1.0 if kind=='armor' and tile==5 else 0.0
        # Glow remains a separate fixed region, with no exaggerated light baked in.
        regions=combine(tree,[primary,secondary,trim])
        finish=combine(tree,[edge,dirt,tile/15])
        rough=mathnode(tree,'MINIMUM',.98,mathnode(tree,'ADD',(.94 if tile in surface_palette else ROUGH[tile]),mathnode(tree,'MULTIPLY',dirt,.12)))
        response=combine(tree,[wear if kind=='armor' else 1,rough,0 if tile in surface_palette else METAL[tile]])
        mat['bake_tile']=tile
        image_node=node(tree,'ShaderNodeTexImage');image_node.name='BAKE_TARGET';image_node.select=True
        tree.nodes.active=image_node
        mats.append((mat,emit,{'pigment':pigment,'regions':regions,'finish':finish,'response':response}))
        bake_nodes.append(image_node)

    print('BAKE STAGE',name,'material recipes ready',flush=True)
    # Recover palette ownership before replacing the deliberately overlapping UVs.
    for obj in lows:
        obj.hide_set(False);obj.hide_render=False
        uv=obj.data.uv_layers.active
        tiles=[]
        for face in obj.data.polygons:
            mean=sum((uv.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
            tiles.append(min(3,int(mean.x*4))+4*min(3,int(mean.y*4)))
        obj.data.materials.clear()
        for mat,_,_ in mats:obj.data.materials.append(mat)
        for face,tile in zip(obj.data.polygons,tiles):face.material_index=tile
        layer=obj.data.uv_layers.new(name='BakeUV');obj.data.uv_layers.active=layer;layer.active_render=True
    print('BAKE STAGE',name,'palette ownership ready',flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in lows:obj.select_set(True)
    bpy.context.view_layer.objects.active=lows[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(50),island_margin=.003,area_weight=.3,correct_aspect=True,scale_to_bounds=True,margin_method='FRACTION',rotate_method='AXIS_ALIGNED_Y')
    bpy.ops.object.mode_set(mode='OBJECT')
    print('BAKE STAGE',name,'unique UV layout ready',flush=True)
    # Triangulate before baking: export and Cycles must use the same tangent basis.
    for obj in lows:
        modifier=obj.modifiers.new('Stable bake/export triangles','TRIANGULATE')
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.calc_tangents(uvmap='BakeUV')

    def image(label,space='Non-Color',fill=(0,0,0,1)):
        im=bpy.data.images.new(name+'_'+label,width=resolution,height=resolution,alpha=True)
        im.colorspace_settings.name=space;im.generated_color=fill
        return im
    def bake(label,typ='EMIT',space='Non-Color'):
        print('BAKE STAGE',name,label,flush=True)
        im=image(label,space)
        for mat,emit,sockets in mats:
            if typ=='EMIT':mat.node_tree.links.new(sockets[label],emit.inputs['Color'])
        for target in bake_nodes:target.image=im;target.select=True;target.id_data.nodes.active=target
        scene.render.bake.use_selected_to_active=False
        bpy.ops.object.select_all(action='DESELECT')
        for obj in lows:obj.select_set(True)
        bpy.context.view_layer.objects.active=lows[0]
        bpy.ops.object.bake(type=typ)
        return im

    pigment=bake('pigment',space='sRGB')
    regions=bake('regions') if kind=='armor' else None
    finish=bake('finish')
    response=bake('response')
    ao=bake('ao','AO')
    # Keep all scalar maps independent of a fixed light or sun direction.
    arrays={}
    for label,im in [('pigment',pigment),('finish',finish),('response',response),('ao',ao)]+([('regions',regions)] if regions else []):
        values=np.empty(resolution*resolution*4,dtype=np.float32);im.pixels.foreach_get(values);arrays[label]=values.reshape(-1,4)
    orm=image('orm');packed=arrays['response'].copy();packed[:,0]=arrays['ao'][:,0];packed[:,3]=1;orm.pixels.foreach_set(packed.ravel())
    if kind=='armor':
        # Alpha is scalar edge-local wear, not opacity. Import must keep data
        # RGB at zero alpha; the shader never enables material transparency.
        packed_finish=arrays['finish'].copy();packed_finish[:,3]=arrays['response'][:,0]
        finish.pixels.foreach_set(packed_finish.ravel())

    # Real high-to-low normal bake. Existing silhouettes are retained. A derived
    # high mesh carries physical masonry joints, carapace growth grooves or
    # restrained panel scoring; the optimized export topology stays unchanged.
    high_group=bpy.data.collections.new('03_HIGH_RELIEF_0133');scene.collection.children.link(high_group)
    highs=[];displacements=[]
    for low in lows:
        print('BAKE STAGE',name,'high-relief mesh',low.name,flush=True)
        high=low.copy();high.data=low.data.copy();high.name=low.name+'_HIGH_RELIEF'
        high_group.objects.link(high);high.hide_render=False;high.hide_set(False)
        bpy.context.view_layer.objects.active=high
        subdivision=high.modifiers.new('Surface relief tessellation','SUBSURF');subdivision.subdivision_type='SIMPLE';subdivision.levels=1
        bpy.ops.object.modifier_apply(modifier=subdivision.name)
        # Material indices survive subdivision; detail is gated by material.
        owners={}
        for face in high.data.polygons:
            for v in face.vertices:owners.setdefault(v,face.material_index)
        high.data.update()
        # Cache normals before changing coordinates. Reading vertex.normal after
        # every edit would recalculate the complete mesh for each vertex.
        normals=[vertex.normal.copy() for vertex in high.data.vertices]
        for vertex in high.data.vertices:
            tile=owners.get(vertex.index,0);p=high.matrix_world@vertex.co
            n=normals[vertex.index]
            displacement=0.0
            if tile in [12,13] and kind in ['stone','industrial','base']:
                u,v=(p.x,p.y) if abs(n.z)>.7 else ((p.y,p.z) if abs(n.x)>.7 else (p.x,p.z))
                course=abs((v/.48+.5)%1-.5)*.48
                joint=abs(((u+(int(math.floor(v/.48))%2)*.58)/1.16+.5)%1-.5)*1.16
                displacement=-.009*math.exp(-(min(course,joint)/.018)**2)
            elif kind=='organic' and tile==8:
                ridge=math.sin(p.z*90+p.x*9+math.sin(p.y*8))
                displacement=.0018*max(0,ridge)**5
            elif kind=='armor' and tile in [0,1,3,14]:
                # Scoring follows exposed metal/panel bands, rather than noise.
                scoring=math.exp(-((p.z-(.95 if name=='legion_infantry' else 2.0)+p.x*.18)/.008)**2)
                displacement=-.0018*scoring*(.5+.5*math.cos(p.x*18))
            vertex.co+=n*displacement;displacements.append(abs(displacement))
        high.data.update();highs.append(high)
    normal=image('normal',fill=(.5,.5,1,1))
    for target in bake_nodes:target.image=normal;target.select=True;target.id_data.nodes.active=target
    for obj in lows+highs:obj.hide_render=True
    scene.render.bake.use_selected_to_active=True
    scene.render.bake.cage_extrusion=.018 if miniature else .04
    scene.render.bake.max_ray_distance=.045 if miniature else .10
    for low,high in zip(lows,highs):
        bpy.ops.object.select_all(action='DESELECT');low.hide_render=False;high.hide_render=False
        low.select_set(True);high.select_set(True);bpy.context.view_layer.objects.active=low
        bpy.ops.object.bake(type='NORMAL')
        low.hide_render=True;high.hide_render=True
    scene.render.bake.use_selected_to_active=False

    # glTF fallback gets default paint; the Godot shader uses neutral undercoat
    # plus separate region masks. Color edits never touch normal/ORM/weathering.
    display=pigment
    if regions:
        display=image('display_color','sRGB');values=arrays['pigment'].copy();weights=arrays['regions'][:,:3]
        tint=np.ones_like(values[:,:3])
        for i,hex in enumerate(['315f86','c5bda5','a08d5f']):tint+=weights[:,i:i+1]*(np.array(color(hex))-1)
        values[:,:3]*=tint;display.pixels.foreach_set(values.ravel())
    outputs={'pigment':pigment,'normal':normal,'orm':orm,'finish':finish}
    if regions:outputs.update(regions=regions,display_color=display)
    metrics=[]
    for label,im in outputs.items():
        im.filepath_raw=str(directory/(label+'.png'));im.file_format='PNG';im.save();im.pack()
        pixels=np.empty(resolution*resolution*4,dtype=np.float32);im.pixels.foreach_get(pixels)
        if not np.isfinite(pixels).all():raise ValueError('Non-finite '+label)
        metrics.append({'map':label,'resolution':[resolution,resolution],'bytes':Path(im.filepath_raw).stat().st_size,'space':im.colorspace_settings.name,'min':float(pixels.min()),'max':float(pixels.max())})

    material=bpy.data.materials.new('GT_Baked0133_'+name);material.use_nodes=True
    tree=material.node_tree;bsdf=tree.nodes.get('Principled BSDF')
    def texture(im):
        n=tree.nodes.new('ShaderNodeTexImage');n.image=im;return n
    tree.links.new(texture(display).outputs['Color'],bsdf.inputs['Base Color'])
    separate=tree.nodes.new('ShaderNodeSeparateColor');tree.links.new(texture(orm).outputs['Color'],separate.inputs[0])
    tree.links.new(separate.outputs['Green'],bsdf.inputs['Roughness']);tree.links.new(separate.outputs['Blue'],bsdf.inputs['Metallic'])
    nmap=tree.nodes.new('ShaderNodeNormalMap');nmap.inputs['Strength'].default_value=.65;tree.links.new(texture(normal).outputs['Color'],nmap.inputs['Color']);tree.links.new(nmap.outputs[0],bsdf.inputs['Normal'])
    # glTF AO association is included via the standard glTF Material Output group.
    group=bpy.data.node_groups.get('glTF Material Output') or bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
    if not group.interface.items_tree:group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
    ao_node=tree.nodes.new('ShaderNodeGroup');ao_node.node_tree=group;tree.links.new(separate.outputs['Red'],ao_node.inputs['Occlusion'])
    triangles=0
    for low in lows:
        for layer_name in [layer.name for layer in low.data.uv_layers]:
            if layer_name!='BakeUV':low.data.uv_layers.remove(low.data.uv_layers[layer_name])
        low.data.uv_layers.active_index=0;low.data.uv_layers[0].active_render=True
        low.data.materials.clear();low.data.materials.append(material)
        for face in low.data.polygons:face.material_index=0
        low.hide_render=False;low.hide_set(False);triangles+=len(low.data.polygons)
    # Save derived source before export yaw. Originals and their high-level
    # editable collections remain available in the original files and archive.
    for high in highs:high.hide_render=True;high.hide_set(True)
    scene.render.bake.use_clear=False
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/(name+'.blend')),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for low in lows:
        low.select_set(True)
        if miniature:low.rotation_euler.z+=math.pi
    bpy.context.view_layer.objects.active=lows[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/export),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_tangents=True,export_animations=False,export_extras=False)
    tangent_repairs=repair_subpixel_tangents(ROOT/export)
    report={'asset':name,'kind':kind,'source':str(source.relative_to(ROOT)).replace('\\','/'),'source_sha256':source_hash,'derived_source':str((SOURCES/(name+'.blend')).relative_to(ROOT)).replace('\\','/'),'export':export,'triangles':triangles,'resolution':resolution,'bake_samples':samples,'bake_margin':scene.render.bake.margin,'uv':'Unique BakeUV, Smart Project 50 degrees, fractional margin .003; exported as TEXCOORD_0','normal_basis':'MikkTSpace / X+ Y+ Z+ / triangulated before baking','high_vertices':sum(len(h.data.vertices) for h in highs),'max_relief_inches':max(displacements),'maps':metrics,'elapsed_seconds':round(time.monotonic()-started,2),'glb_bytes':(ROOT/export).stat().st_size,'glb_sha256':digest(ROOT/export)}
    report['tangent_guard']=tangent_repairs
    (REPORTS/(name+'_bake.json')).write_text(json.dumps(report,indent=2)+'\n')
    print('GRIMTABLE BAKED',json.dumps(report),flush=True)

if __name__=='__main__':
    if '--' in sys.argv:
        args=sys.argv[sys.argv.index('--')+1:];worker(args[0],int(args[1]))
    else:launcher()
