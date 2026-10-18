"""Blender Cycles high-to-low normal/AO bake and authored map masks.

No downloaded textures. The source heightfield, low plane and bake materials
are retained in surface_bake.blend. Layout masks derive from curated polygons
and localized damage events, not uniform procedural scatter.
"""
import bpy,math,json,sys,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/terrain/environment/0131/materials'
OUT.mkdir(parents=True,exist_ok=True)

def dist_segment(x,z,a,b):
    dx=b[0]-a[0];dz=b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(z-a[1])*dz)/max(.0001,dx*dx+dz*dz)))
    return math.hypot(x-a[0]-dx*t,z-a[1]-dz*t)
def inside(x,z,poly):
    hit=False;j=len(poly)-1
    for i,p in enumerate(poly):
        q=poly[j]
        if (p[1]>z)!=(q[1]>z) and x<(q[0]-p[0])*(z-p[1])/(q[1]-p[1])+p[0]:hit=not hit
        j=i
    return hit
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def noise(x,y):
    ix=math.floor(x);iy=math.floor(y);u=smooth(0,1,x-ix);v=smooth(0,1,y-iy)
    def h(a,b):
        n=math.sin(a*127.1+b*311.7)*43758.5453;return n-math.floor(n)
    return (h(ix,iy)*(1-u)+h(ix+1,iy)*u)*(1-v)+(h(ix,iy+1)*(1-u)+h(ix+1,iy+1)*u)*v
def save_image(name,size,pixels,space='Non-Color',alpha=False):
    image=bpy.data.images.new(name,width=size,height=size,alpha=alpha);image.colorspace_settings.name=space
    image.pixels.foreach_set(pixels);image.filepath_raw=str(OUT/(name+'.png'));image.file_format='PNG';image.save();return image

def bake():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    high_group=bpy.data.collections.new('01_HIGH_RELIEF_SOURCE');bpy.context.scene.collection.children.link(high_group)
    low_group=bpy.data.collections.new('02_LOW_BAKE_TARGET');bpy.context.scene.collection.children.link(low_group)
    # Explicit branching structural cracks carved into a dense stone relief.
    cracks=[((-.9,-.8),(-.1,-.1)),((-.1,-.1),(.7,.35)),((-.1,-.1),(-.25,.9)),((.35,.2),(.9,-.45)),((-.5,-.45),(-.9,.1))]
    n=160;verts=[];faces=[]
    for j in range(n+1):
        y=j/n*2-1
        for i in range(n+1):
            x=i/n*2-1
            crack=min(dist_segment(x,y,a,b) for a,b in cracks)
            h=.004*noise(x*23+4,y*23+9)+.002*noise(x*67-7,y*67+11)
            h-=.025*math.exp(-(crack/.018)**2)
            h+=.005*math.exp(-((crack-.032)/.018)**2)
            verts.append((x,y,h))
    for j in range(n):
        for i in range(n):
            k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1))
    mesh=bpy.data.meshes.new('Carved stone relief topology');mesh.from_pydata(verts,[],faces);mesh.update()
    high=bpy.data.objects.new('Original carved high relief',mesh);high_group.objects.link(high)
    for p in mesh.polygons:p.use_smooth=True
    low_mesh=bpy.data.meshes.new('Bake quad');low_mesh.from_pydata([(-1,-1,-.12),(1,-1,-.12),(1,1,-.12),(-1,1,-.12)],[],[(0,1,2,3)]);low_mesh.update()
    uv=low_mesh.uv_layers.new(name='SurfaceUV')
    for loop,point in zip(uv.data,[(0,0),(1,0),(1,1),(0,1)]):loop.uv=point
    low=bpy.data.objects.new('Low stone / target',low_mesh);low_group.objects.link(low)
    mat=bpy.data.materials.new('Baked relief target');mat.use_nodes=True;low_mesh.materials.append(mat)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.5;scene.render.bake.max_ray_distance=.7;scene.render.bake.margin=8
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');mat.node_tree.nodes.active=node
    bpy.ops.object.select_all(action='DESELECT');high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    for name,kind in [('fractured_normal','NORMAL'),('fractured_ao','AO')]:
        image=bpy.data.images.new(name,width=512,height=512,alpha=False);image.colorspace_settings.name='Non-Color';node.image=image
        bpy.ops.object.bake(type=kind)
        image.filepath_raw=str(OUT/(name+'.png'));image.file_format='PNG';image.save();image.pack()
        values=list(image.pixels)[0::4]
        assert max(values)-min(values)>.05,'Empty surface bake'
    high.hide_render=True;high.hide_set(True)
    source=ROOT/'art/blender/environment/0131';source.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/'surface_bake.blend'))
    print('GRIMTABLE CYCLES: actual 512px high-to-low NORMAL and AO bakes complete')

def mask(name,data):
    size=512;pixels=[]
    for j in range(size):
        z=j/(size-1)*44-22
        for i in range(size):
            x=i/(size-1)*60-30
            jitter=.25*math.sin(x*2.4+math.sin(z*1.7))+.16*math.sin(z*5.1+x)
            floor=0.;metal=0.;burn=0.;fracture=0.
            for polygons,channel in [(data['floor_polygons'],0),(data['metal_polygons'],1)]:
                for poly in polygons:
                    edge=min(dist_segment(x,z,poly[k-1],poly[k]) for k in range(len(poly)))
                    weight=smooth(-.12,.22,edge+jitter if inside(x,z,poly) else -edge+jitter)
                    if channel==0:floor=max(floor,weight)
                    else:metal=max(metal,weight)
            road=max(1-smooth(r['width']*.6,r['width']*.6+.2,dist_segment(x,z,r['from'],r['to'])+jitter*.35) for r in data['roads'])
            floor=max(floor,road*.65)
            for event in data['damage']:
                dx=x-event['at'][0];dz=z-event['at'][1];r=event['radius'];distance=math.hypot(dx,dz)
                affected=1-smooth(r*.18,r*1.2,distance+jitter*.6)
                floor*=1-affected*.88;metal*=1-affected*.9
                burn=max(burn,affected*(.92 if event['type'] in ['impact','blast','oil'] else .38))
                # Dust fan continues the exact wall-collapse origin into the floor.
                d=event['direction'];length=max(.0001,math.hypot(*d));along=(dx*d[0]+dz*d[1])/length;across=abs(dx*d[1]-dz*d[0])/length
                if along>0:
                    fan=(1-smooth(r,r*2.1,along))*(1-smooth(.3,r*.5+along*.25,across))
                    floor*=1-fan*.4
                if event['type']!='oil' and distance<r*2.3:
                    # A small set of fracture branches radiate from each actual
                    # blast/collapse; no uniformly distributed crack wallpaper.
                    for ray in range(5):
                        angle=ray*math.tau/5+event['at'][0]*.17
                        end=(event['at'][0]+math.cos(angle)*r*(1.5+.4*math.sin(ray)),event['at'][1]+math.sin(angle)*r*(1.5+.4*math.sin(ray)))
                        seam=dist_segment(x,z,event['at'],end)
                        fracture=max(fracture,(1-smooth(.035,.12,seam))*(1-smooth(r*.6,r*2.2,distance)))
            pixels.extend([floor,metal,burn,fracture])
    save_image(name.lower()+'_layout_mask',size,pixels,alpha=True)
    print('GRIMTABLE AUTHORED LAYOUT MASK',name)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['bake','Sanctum']
    if 'bake' in args:bake()
    layouts=json.loads((ROOT/'resources/environment/layouts_0131.json').read_text())
    for name in args:
        if name!='bake':mask(name,layouts[name])
