"""Blender 5 environment source production. Original meshes, inch coordinates.

Rebuild selected source: blender --background --disable-autoexec --python this.py
-- gatehouse. The independent .blend sources retain all editable components.
"""
import sys, math, json, random
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
import build_assets as a
ROOT=a.ROOT

def clean_environment(data):
    data.update()
    bad=[p.index for p in data.polygons if p.area<=1e-14]
    if len(bad)>max(64,len(data.polygons)//100): raise ValueError('Excess zero-area environment faces: '+str(len(bad))+' / '+str(len(data.polygons)))
    if not bad: return
    normals=[tuple(n.vector) for n in data.corner_normals]
    keep=[normals[i] for p in data.polygons if p.index not in set(bad) for i in p.loop_indices]
    bm=bmesh.new(); bm.from_mesh(data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in bad],context='FACES_ONLY')
    bm.to_mesh(data); bm.free(); data.update()
    if len(keep)==len(data.loops): data.normals_split_custom_set(keep)

a.clean_game_mesh=clean_environment

def block(name, center, size, tile=12):
    x,y,z=center; w,d,h=size
    return a.loft(name,[(z-h/2,x,y,w,d),(z+h/2,x,y,w,d)],tile,13,min(.025,min(size)*.12),8,power=7)

def frame(name,cx,sill,spring,width,rise,y):
    # Individual tapered voussoirs leave actual lancet-shaped negative space.
    for side in [-1,1]:
        a.span(name+' pier',(cx+side*width/2,y,sill),(cx+side*width/2,y,spring),[(0,.27,.4),(1,.23,.4)],12,2,8)
        points=[]
        for i in range(11):
            t=i/10
            points.append((cx+side*width/2*(1-t),y,spring+rise*math.sin(t*math.pi/2)))
        for i in range(10):
            a.span(name+' archstone',points[i],points[i+1],[(0,.25,.42),(1,.22,.42)],12,2,6)

def wall(name,width,height,y):
    outline=[(-width/2,0),(width/2,0),(width/2,height*.75),(width*.38,height*.78),(width*.31,height*.60),(width*.19,height*.68),(width*.16,height*.9),(0,height),(-width*.15,height*.95),(-width*.25,height*.82),(-width/2,height*.92)]
    shell=a.extrude_outline(name,outline,y,.45,12,13,.045)
    for x in [-width*.29,0,width*.29]:
        hole=[(x-.72,1.8),(x+.72,1.8),(x+.72,height*.53),(x+.5,height*.64),(x,height*.72),(x-.5,height*.64),(x-.72,height*.53)]
        cutter=a.extrude_outline('window cutter',hole,y-.5,1.5,4,4,0)
        a.boolean_cut(shell,cutter)
        frame(name+' window',x,1.8,height*.53,1.44,height*.19,y-.08)
        block('Broken sill',(x,y-.12,1.72),(1.85,.68,.19))
    return shell

def buttress(x,y,h):
    p=a.extrude_outline('Stepped load buttress',[(-.4,0),(.4,0),(.4,h*.88),(.13,h*.9),(-.05,h*.68),(-.4,h*.2)],-.32,.64,13,12,.035)
    p.rotation_euler.z=math.pi/2; a.position(p,(x,y,0))
    for z in [.3,h*.45,h*.81]: block('Buttress worn cap',(x,y-.08,z),(.82,.95,.16))

def rubble(width,depth,seed=130):
    rng=random.Random(seed)
    for i in range(32):
        x=rng.uniform(-width/2,width/2); y=rng.uniform(-depth/2,depth/2)
        w=rng.uniform(.14,.55); h=rng.uniform(.08,.28)
        obj=a.loft('Fractured masonry',[(0,x,y,w,w*.7),(h*.65,x+.04,y,w*.85,w*.8),(h,x-.05,y,w*.45,w*.55)],12,13,.015,6,power=2.5)
        obj.rotation_euler.z=rng.random()*2

def gatehouse():
    wall('Gatehouse broken western face',8,10.2,-.25)
    # Finials and exposed iron make the thin ruin legible from tactical zoom.
    for x,h in [(-3.65,10.6),(-1.15,11.7),(1.2,10.8),(3.65,8.6)]:
        buttress(x,-.25,h*.88)
        a.loft('Split monumental pinnacle',[(h-.6,x,-.1,.65,.7),(h,x,-.1,.43,.47),(h+.65,x,-.1,.06,.1)],12,2,.03,8)
        a.tube('Bent exposed support',[(x+.2,-.1,h*.8),(x+.2,-.13,h*.96),(x+.5,-.1,h*1.02)],.045,11)
    for x in [-2.45,2.4]:
        block('Low machine shrine',(x,-.6,.8),(1.4,.85,1.55),3)
        for j in range(5): block('Weathered vent vane',(x,-1.06,.35+j*.19),(1.13,.12,.07),11)
    for x in [-3,0,3]: block('Foundation shoe',(x,0,.12),(2.8,2.7,.24),13)
    rubble(7.5,2.5)

def cloister():
    wall('Collapsed cloister',8,5.8,-.13)
    for x in [-3.8,-1.28,1.28,3.8]: buttress(x,0,5.4)
    for x in [-2.5,0,2.5]:
        a.tube('Broken window iron',[(x,-.2,2),(x,-.2,4.0),(x+.18,-.25,4.4)],.04,11)
    rubble(7.8,.85,133)

def refinery():
    a.loft('Octagonal reactor footing',[(0,0,0,6.4,5.4),(.35,0,0,6.2,5.2),(.55,0,0,5.5,4.6)],13,3,.04,8,power=3)
    a.loft('Curved pressure vessel',[(.5,0,0,3.3,3.3),(1.1,0,0,4,4),(5.3,0,0,4,4),(6.2,0,0,2.8,2.8),(7.0,0,0,1.8,1.8),(8.3,0,0,1.8,1.8),(8.6,0,0,2.4,2.4)],11,3,.04,32,power=2,smooth=True)
    for z,r in [(1,2.1),(4.9,2.1),(6.2,1.5),(8.5,1.3)]: a.annulus('Riveted vessel hoop',(0,0,z),r,.15,.20,3,axis='Z',segments=32)
    for i in range(8):
        t=i*math.tau/8; x=math.cos(t)*2.5; y=math.sin(t)*2.1
        a.span('Load-bearing reactor rib',(x,y,.4),(x*.7,y*.7,6.4),[(0,.23,.35),(.7,.18,.3),(1,.1,.22)],3,14,8)
        a.tube('Curved coolant return',[(x,y,.4),(x,y,3.4),(x*.6,y*.6,5.8),(x*.36,y*.36,7.3)],.13,3)
    for x in [-2.65,2.65]:
        a.loft('Cooling stack',[(.4,x,0,1,1),(8.5,x,0,.8,.8),(9,x,0,1.1,1.1),(10.8,x,0,.85,.85)],3,11,.04,16,power=2)
        for z in [2,5,8,10.7]: a.annulus('Stack reinforcing ring',(x,0,z),.56,.12,.14,11,axis='Z')
    for x in [-.7,.7]:
        a.tube('Cold energy sight glass',[(x,-1.9,1.5),(x,-2.04,3.8),(x,-1.8,5.4)],.08,6)
    # Original neutral industrial plate numbering is geometric, not borrowed art.
    block('Instrument housing',(0,-2.15,2.6),(1.2,.5,.8),4)
    for x in [-.3,0,.3]: a.bolt('Gauge face',(x,-2.44,2.65),.07,5)

def cooling():
    for x in [-1.65,1.65]:
        a.loft('Flared cooling housing',[(0,x,0,2.5,3.4),(.5,x,0,2.3,3.1),(3.7,x,0,1.6,2.5),(5.4,x,0,2.3,2.8),(5.8,x,0,2.6,3.1)],11,3,.045,24,power=2.6,smooth=True)
        a.annulus('Cooling throat',(x,0,5.8),1.1,.16,.2,3,axis='Z')
        for i in range(9):
            t=i*math.tau/9
            a.span('Cooling reinforcing spline',(x+math.cos(t)*1.12,math.sin(t)*1.25,.4),(x+math.cos(t)*.9,math.sin(t)*1.05,5.4),[(0,.1,.1),(1,.075,.075)],3,14,6)
    for x in [-2,0,2]: a.tube('Broken feedpipe',[(x,1.5,.4),(x,1.5,1.3),(x+.4,1.4,1.7)],.18,11)

def bunker():
    outline=[(-3.5,0),(3.5,0),(3.5,1.3),(3,2.15),(2.3,2.5),(.7,2.5),(.3,2.1),(-.2,2.35),(-1,2.6),(-2.8,2.5),(-3.5,1.7)]
    shell=a.extrude_outline('Blasted casemate shell',outline,-1.7,3.4,13,12,.08)
    for x in [-2,1.7]:
        cut=a.extrude_outline('Firing slit cutter',[(x-.75,1.1),(x+.75,1.1),(x+.75,1.45),(x-.75,1.45)],-2.2,4.5,4,4,0)
        a.boolean_cut(shell,cut)
        block('Slit brow',(x,-1.78,1.58),(1.9,.22,.18),3)
    for x in [-2.9,0,2.9]:
        p=a.extrude_outline('Sloping blast brace',[(-.24,0),(.24,0),(.18,1.9),(-.12,2.3)],-.35,.7,3,14,.04)
        a.position(p,(x,-1.6,0))
    for x in [-2.8,2.8]: a.tube('Bunker return pipe',[(x,1.25,.2),(x,1.25,2.3),(x*.8,.9,2.8)],.12,11)
    rubble(6.8,3.8,138)

def shrine():
    a.loft('Octagonal relic pedestal',[(0,0,0,2.7,2.7),(.2,0,0,2.7,2.7),(.4,0,0,2.2,2.2),(1.5,0,0,1.5,1.5),(1.7,0,0,2.1,2.1)],12,2,.04,8,power=2)
    for x in [-.65,.65]:
        a.span('Split relic fork',(x,0,1.65),(x*.75,0,3.15),[(0,.26,.32),(1,.13,.2)],3,5,8)
    a.annulus('Original split-circle relic',(0,0,2.6),.72,.11,.2,5,axis='Y',segments=24)
    a.loft('Cold core',[(1.9,0,0,.26,.3),(2.65,0,0,.36,.4),(3,0,0,.08,.1)],6,14,.025,8)
    for side in [-1,1]: a.tube('Relic power lead',[(side*.8,.4,.1),(side*.9,.35,1.1),(side*.3,.2,1.8)],.065,11)

def crane():
    block('Abandoned press bed',(0,0,.7),(3.4,3.0,1.4),13)
    for x in [-1.05,0,1.05]:
        a.loft('Press housing',[(.8,x,0,.8,2.4),(1.8,x,0,.7,2.2),(2.0,x,0,.5,1.8)],3,14,.04,8,power=3)
        for y in [-.7,.0,.7]:block('Press access panel',(x,y,2.02),(.44,.4,.05),11)
    for x in [-2.7,2.7]:
        a.span('Tapered hoist column',(x,0,.1),(x,0,7.8),[(0,.65,.9),(1,.38,.55)],3,14,8)
        for z in [1,3,5,7]:
            a.span('Diagonal hoist brace',(x-.3,0,z),(x+.3,0,z+1.2),[(0,.08,.13),(1,.08,.13)],11,3,6)
        block('Anchored crane shoe',(x,0,.12),(1.2,2.8,.24),13)
    for z in [7.1,7.8]: a.span('Overhead I-beam',(-3.3,0,z),(3.3,0,z),[(0,.24,.4),(1,.24,.4)],11,14,8)
    for i in range(8): a.span('Overhead lattice',(-3+i*.8,0,7.1),(-2.2+i*.8,0,7.8),[(0,.08,.1),(1,.08,.1)],3,14,6)
    a.tube('Hanging load chain',[(.7,0,7.2),(.7,0,5),(.8,0,3.2)],.045,3)
    a.tube('Original heavy hook',[(.8,0,3.3),(.5,0,2.8),(.8,0,2.5),(1.1,0,2.7),(1.1,0,2.9)],.10,3)

def trench():
    # Raised low banks define difficult terrain; the central route stays flat.
    for y in [-1.15,1.15]:
        a.loft('Broken trench bank',[(0,0,y,8,1.0),(.28,0,y,7.8,.85),(.6,0,y,7.6,.4)],15,13,.035,12,power=7)
        for x in [-3,-1.8,-.6,.6,1.8,3]:
            block('Worn trench revetment',(x,y*.74,.3),(.85,.14,.56),11)
    for i in range(11): block('Damaged duckboard',(-3.5+i*.7,0,.045),(.48,1.4,.07),11)

ASSETS={'gatehouse':(gatehouse,[8,12.4,3]),'cloister':(cloister,[8,6,1.4]),'refinery_core':(refinery,[7,11,6]),'cooling_bank':(cooling,[6,6,4]),'breach_bunker':(bunker,[7,3,4]),'reliquary':(shrine,[3,3.3,3]),'hoist':(crane,[7,8,4]),'trench':(trench,[8,.7,3])}

def build(name):
    a.setup(); a.MM=1; a.asset='environment_'+name
    ASSETS[name][0]()
    # Reuse existing original atlas bytes, without regenerating miniature art.
    material=bpy.data.materials.new('GT_EnvironmentAtlas'); material.use_nodes=True
    nodes=material.node_tree.nodes; bsdf=nodes.get('Principled BSDF')
    pigment=nodes.new('ShaderNodeTexImage'); pigment.image=bpy.data.images.load(str(ROOT/'assets/miniatures/materials/painted_atlas.png'))
    orm=nodes.new('ShaderNodeTexImage'); orm.image=bpy.data.images.load(str(ROOT/'assets/miniatures/materials/painted_orm.png')); orm.image.colorspace_settings.name='Non-Color'
    channels=nodes.new('ShaderNodeSeparateColor'); links=material.node_tree.links
    links.new(pigment.outputs['Color'],bsdf.inputs['Base Color']); links.new(orm.outputs['Color'],channels.inputs[0]); links.new(channels.outputs['Green'],bsdf.inputs['Roughness']); links.new(channels.outputs['Blue'],bsdf.inputs['Metallic'])
    obj,game=a.game_mesh(material); obj.name='GT_0130_'+name
    for child in a.SOURCE.objects: child.hide_render=True; child.hide_set(True)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    output=ROOT/'assets/terrain/environment'/f'{name}.glb'; output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    for image in bpy.data.images:
        if image.source=='FILE': image.pack()
    dest=ROOT/'art/blender/environment'; dest.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/f'{name}.blend'))
    obj.data.calc_loop_triangles()
    return {'asset':name,'triangles':len(obj.data.loop_triangles),'source':str(dest.relative_to(ROOT)/f'{name}.blend'),'export':str(output.relative_to(ROOT)),'footprint':ASSETS[name][1],'blender':bpy.app.version_string}

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(ASSETS)
    results=[build(name) for name in args]
    dest=ROOT/'docs/environment'; dest.mkdir(parents=True,exist_ok=True)
    metrics=dest/'mesh_metrics.json'
    previous=json.loads(metrics.read_text()) if metrics.exists() else []
    combined={item['asset']:item for item in previous+results}
    metrics.write_text(json.dumps(list(combined.values()),indent=2))
    print('ENVIRONMENT ASSETS '+json.dumps(results))
