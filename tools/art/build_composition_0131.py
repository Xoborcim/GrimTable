"""Blender 5 original location clusters. Coordinates/footprints use Godot inches.

-- sanctum transept breached_gate shrine. Editable source remains distinct from
the atlas-consolidated game mesh. No downloaded geometry or texture inputs.
"""
import bpy,sys,json,math,random
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).parent))
import build_environment as e
a=e.a;ROOT=e.ROOT
DEST=ROOT/'assets/terrain/environment/0131'

def part(x,z,w,h,d):return {'center':[x,h/2,z],'size':[w,h,d]}
SPECS={
 'sanctum':{'name':'Shattered Sanctum','size':[20,13.5,15],'parts':[part(-7,-6,4,10,.9),part(-1,-6,4,12,.9),part(6,-6,3,5.5,.9),part(-8.4,-3.3,.9,8,4.6),part(-8.4,2.7,.9,4.5,3.2),part(-2,2.5,1.4,9,1.4),part(5,2.5,1.4,4,1.4),part(7,-3.7,3,.7,1.4),part(-4.8,0,2.4,.6,2.2)]},
 'transept':{'name':'Collapsed Transept','size':[11,6,8],'parts':[part(-4.8,-1,.9,5,5.8),part(-2.4,-3.2,4,3.4,.8),part(2,-3.2,2.3,1.7,.8),part(2.6,.4,3.4,.7,1.6),part(-1.8,-1.4,3.8,.6,2.2)]},
 'breached_gate':{'name':'Breached Gate','size':[11,8,7],'parts':[part(-4,0,1.8,7,2),part(4,0,1.8,5,2),part(-4,2.1,2.7,1.4,1.3),part(3.6,2.1,2.7,1.3,1.3)]},
 'shrine':{'name':'Ruined Shrine','size':[5,3.5,4],'parts':[part(-1,0,1.7,1.4,1.8),part(1.35,.1,1.7,.6,1.2)]},
 'industrial_wreck':{'name':'Industrial Wreckage','size':[11,6.5,8],'parts':[part(2.6,0,4,4.7,3.4),part(-3,-2,2,2.7,2),part(-3,2.5,3,1.2,1.1)]},
 'checkpoint':{'name':'Destroyed Checkpoint','size':[9,3.5,6],'parts':[part(-2.9,-1.5,2.7,1.5,.9),part(2.9,-1.5,2.7,1.3,.9),part(.6,1.2,2.7,2.5,2.5),part(-3,1.5,1.8,1.2,1.3)]},
 'pipeline':{'name':'Broken Pipeline','size':[10,2.6,5],'parts':[part(-3,0,3.5,1.8,2),part(3,0,3.5,1.8,2)]},
 'crater':{'name':'Cratered Roadway','size':[9,.3,8],'parts':[]},
 'station_hall':{'name':'Ruptured Manufacturing Hall','size':[17,9,10],'parts':[part(-7.8,-1.2,.8,6.5,6.8),part(7.8,-1.2,.8,5.5,6.8),part(-4.5,-4.5,5.8,8,.8),part(3.5,-4.5,6.5,7.5,.8)]}}
CURRENT=None

def xyz(p):return (p[0],-p[2],p[1])
def block(name,at,size,tile=12):
    # Store the center as the object origin so later rotations are local.
    # Baking world coordinates into vertices would swing footings around (0,0).
    obj=e.block(name,(0,0,0),(size[0],size[2],size[1]),tile)
    a.position(obj,xyz(at))
    return obj
def cable(name,points,r=.04,tile=11):return a.tube(name,[xyz(p) for p in points],r,tile,4)
def pillar(name,x,z,h):
    a.loft(name,[(0,x,-z,1.7,1.7),(.18,x,-z,1.6,1.6),(.4,x,-z,1.25,1.25),(h-.5,x,-z,.85,.95),(h-.3,x,-z,1.1,1.15),(h,x,-z,.65,.76)],12,2,.025,12,power=2.6)
    for k in range(6):
        t=k*math.tau/6
        cable(name+' exposed flute',[(x+math.cos(t)*.47,.4,z+math.sin(t)*.47),(x+math.cos(t)*.4,h-.5,z+math.sin(t)*.4)],.035,13)

def wall(x,z,w,h,seed=0,angle=0):
    old=set(a.SOURCE.objects)
    outline=[(-w/2,0),(w/2,0),(w/2,h*.61),(w*.32,h*.75),(w*.2,h*.68),(.10*w,h*.94),(-w*.15,h),(-w*.27,h*.86),(-w/2,h*.91)]
    shell=a.extrude_outline('Ruptured masonry / shear profile',outline,-.45,.9,12,13,.035)
    count=max(1,int(w/2.3))
    for i in range(count):
        cx=(i-(count-1)/2)*2.3
        spring=h*.52;rise=h*.22;sill=min(1.3,h*.2);width=min(1.6,w*.52)
        hole=[(cx-width/2,sill),(cx+width/2,sill),(cx+width/2,spring),(cx+width*.3,spring+rise*.65),(cx,spring+rise),(cx-width*.3,spring+rise*.65),(cx-width/2,spring)]
        a.boolean_cut(shell,a.extrude_outline('Void / original lancet',hole,-1.2,2.5,4,4,0))
        e.frame('Fractured window tracery',cx,sill,spring,width,rise,-.49)
    for edge in [-1,1]:
        px=edge*(w/2-.19)
        a.loft('Masonry pier / surviving load path',[(0,px,0,.58,1.2),(.4,px,0,.53,1.0),(h*.85,px,0,.34,.75),(h*.9,px,0,.46,.87)],13,12,.025,8,power=4)
    # World-aligned geometry remains on the recorded narrow wall footprint.
    transform=Matrix.Translation(Vector((x,-z,0)))@Matrix.Rotation(-angle,4,'Z')
    for obj in set(a.SOURCE.objects)-old:obj.matrix_world=transform@obj.matrix_world

def footing(points,width=.42):
    for k in range(len(points)-1):
        p,q=Vector(points[k]),Vector(points[k+1]);mid=(p+q)/2
        obj=block('Fractured foundation / continuous building trace',(mid.x,.045,mid.y),((p-q).length+.05,.09,width),13)
        obj.rotation_euler.z=-math.atan2(q.y-p.y,q.x-p.x)
        # Cut the perimeter with short displaced, exposed stone fragments.
        for t in [.18,.55,.84]:
            at=p.lerp(q,t)
            slab=block('Chipped footing stone',(at.x,.065,at.y),(.55,.08,width*.85),12);slab.rotation_euler.z=-.2+k*.13

def fractured_floor(bounds,events,seed=131,metal=False):
    """Owned, beveled paving with physical gaps, impact loss and split fragments."""
    rng=random.Random(seed);xmin,xmax,zmin,zmax=bounds
    row=0;z=zmin+.7
    while z<zmax-.3:
        x=xmin+.7+(row%2)*.68
        while x<xmax-.35:
            distance=min(math.hypot(x-p[0],z-p[1])/p[2] for p in events)
            edge=min(x-xmin,xmax-x,z-zmin,zmax-z)
            if distance>.38 and not (edge<.8 and rng.random()<.35):
                w=rng.uniform(1.1,1.4);d=rng.uniform(1.25,1.55);h=rng.uniform(.025,.065)
                outline=[(-w*.5,-d*.35),(-w*.3,-d*.5),(w*.42,-d*.5),(w*.5,d*.18),(w*.3,d*.5),(-w*.5,d*.45)]
                # Collapse rings turn whole tiles into displaced triangular remnants.
                shapes=[outline] if distance>1.05 else [[outline[0],outline[1],outline[2],(.1,.1)],[outline[3],outline[4],outline[5],(-.1,.03)]]
                for j,shape in enumerate(shapes):
                    dx=(j-.5)*.13 if len(shapes)>1 else 0
                    verts=[(x+px+dx,-z-pz,level) for level in [.002,h] for px,pz in shape]
                    n=len(shape);faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
                    tile=(3 if rng.random()>.22 else 11) if metal else (12 if rng.random()>.14 else 13)
                    a.mesh('Floor / fractured surviving flagstone',verts,faces,tile,13,.009)
            x+=1.52
        row+=1;z+=1.75

def in_part(x,z):
    return any(abs(x-p['center'][0])<p['size'][0]/2 and abs(z-p['center'][2])<p['size'][2]/2 for p in CURRENT['parts'])

def spill(origin,direction,length,width,count=90,seed=131):
    rng=random.Random(seed)
    d=Vector(direction).normalized();side=Vector((-d.y,d.x))
    for i in range(count):
        t=rng.random()**1.7;across=rng.uniform(-1,1)*(width*.2+t*width*.5)
        at=Vector(origin)+d*(t*length)+side*across
        w=rng.uniform(.15,.6)*(1-t*.6)
        h=rng.uniform(.18,.72)*(1-t*.5) if in_part(at.x,at.y) else rng.uniform(.025,.075)
        limits=[p['size'][1] for p in CURRENT['parts'] if abs(at.x-p['center'][0])<p['size'][0]/2 and abs(at.y-p['center'][2])<p['size'][2]/2]
        if limits:h=min(h,max(limits)*.88)
        a.loft('Collapse fan / sized masonry fragment',[(.006,at.x,-at.y,w,w*.65),(h*.6,at.x+.025,-at.y,w*.9,w*.7),(h,at.x-.02,-at.y,w*.5,w*.45)],12 if i%5 else 13,13,.008,6,power=2.5)
        if i%9==0 and in_part(at.x,at.y):cable('Torn reinforcement',[(at.x,0,at.y),(at.x+.1,.3,at.y+.1),(at.x+.3,.36,at.y+.3)],.025)

def sanctum():
    fractured_floor((-9.4,8.8,-6.5,5),[(-8.3,-.4,2.5),(2.7,-5.7,2.6),(7,-3.7,1.8)],131)
    for x,w,h in [(-7,4,10),(-1,4,12),(6,3,5.5)]:wall(x,-6,w,h)
    wall(-8.4,-3.3,4.6,8,angle=math.pi/2)
    wall(-8.4,2.7,3.2,4.5,angle=math.pi/2)
    pillar('Sanctum / broken west crossing pier',-2,2.5,9)
    pillar('Sanctum / sheared east crossing pier',5,2.5,4)
    # A cantilevered half-arch makes the breach itself the landmark silhouette.
    points=[]
    for i in range(10):
        t=i/12;points.append((-2+3.5*t,8.4+2.8*math.sin(t*math.pi/2),2.5))
    for p,q in zip(points,points[1:]):
        a.span('Crossing / fractured voussoir',xyz(p),xyz(q),[(0,.47,.72),(1,.44,.68)],12,2,8)
    cable('Crossing / exposed internal arch tie',points,.06,3)
    # Grounded fallen crown, inside its explicit low collision part.
    for i in range(5):
        s=block('Fallen arch crown',(5.9+i*.55,.25+math.sin(i)*.1,-3.7),(.6,.48,.8),12);s.rotation_euler[1]=.17*(i-2)
    footing([(-9,-6.5),(8,-6.5),(8,5),(1,5),(-9,5),(-9,-6.5)])
    footing([(-3,-6),(-3,5)],.19)
    for x,z,d,l,w in [(2.7,-5.7,(0,1),4.4,3.6),(-8.3,-.4,(1,.3),4,2.5),(5,-3.7,(.1,1),3,2.5)]:spill((x,z),d,l,w,70,131+int(x*3))
    # A ruptured machinery niche joins the sacred and industrial construction.
    for x in [-7.9,-6.7]:
        block('Sanctum / soot-black machine door',(x,1.3,-5.6),(.8,1.9,.25),3)
        for j in range(4):block('Machine niche vent',(x,.6+j*.31,-5.42),(.62,.08,.1),11)
    cable('Hanging broken service trunk',[(-1,8,-5.6),(1,5,-5.3),(2.5,2,-4.8),(3,.05,-3.8)],.08,11)

def transept():
    fractured_floor((-5.2,5,-3.7,3.6),[(-2,-3,3.4),(2.6,.4,1.9)],143)
    wall(-4.8,-1,5.8,5,angle=math.pi/2)
    wall(-2.4,-3.2,4,3.4)
    wall(2,-3.2,2.3,1.7)
    footing([(-5,-3.6),(4.8,-3.6),(4.8,3.5),(-5,3.5),(-5,-3.6)])
    # Column shaft has fallen from its stump into a blocked rubble strip.
    for x in [1.3,2.1,2.9,3.7]:
        ring=a.annulus('Collapsed column / displaced drum',(x,-.4,.36),.52,.2,.6,12,axis='X',segments=12)
        ring.data.materials[1]=a.MATS[2]
        ring.rotation_euler.z=.06*(x-2)
    cable('Collapsed beam / bowed tie',[(1,.5,.4),(2,.4,.7),(4,.25,.6)],.07,11)
    spill((-2,-3),(0,1),5,5,130,145)
    spill((2.6,.4),(-.2,1),2.5,4,65,146)

def breached_gate():
    fractured_floor((-5,5,-1.7,3.3),[(0,1,2.8)],150)
    for x,h in [(-4,7),(4,5)]:
        pillar('Gate / armored support',x,0,h)
        for y in [.8,2.6,h-.5]:block('Gate reinforcement collar',(x,y,0),(1.6,.18,1.7),3)
        cable('Gate / snapped door runner',[(x-.5,.4,-.6),(x-.5,h-.3,-.6),(x-.8,h+.3,-.4)],.075,11)
    # Broken bulkhead halves remain attached to their supports, leaving a true gap.
    for side in [-1,1]:
        block('Breached gate leaf',(side*3.9,.7,2.1),(2.5,1.3,.5),3)
        for j in range(4):block('Gate leaf battered ribs',(side*3.9,.4+j*.2,1.8),(2.1,.09,.08),11)
    footing([(-5,-1.7),(5,-1.7)],.65)
    footing([(-5,-1.7),(-5,3),(5,3),(5,-1.7)],.35)
    spill((-4,0),(.35,1),3,2,90,151);spill((4,0),(-.4,1),3,2,90,152)
    cable('Gate / broken power umbilical',[(-4,.1,1),(-2,.1,2),(-1,.05,2.8),(-.4,.04,3.3)],.055)

def shrine():
    # Fractured stepped pedestal with its original split-ring ornament toppled.
    for y,w in [(.15,1.9),(.4,1.65),(.8,1.4),(1.2,1.6)]:block('Shrine / shattered plinth',(-1,y,0),(w,.22,w*.8),12)
    ornament=a.annulus('Shrine / toppled original ornament',(1.35,-.1,.38),.6,.16,.22,5,axis='Y',segments=20);ornament.rotation_euler.x=.9
    block('Shrine / cracked terminal',(-1,1.45,0),(.65,.35,.4),3)
    block('Shrine / dead screen',(-1,1.64,.08),(.46,.03,.27),4)
    cable('Shrine / torn lead',[(-1,.2,.5),(-.5,.07,.9),(.4,.06,1.3),(1,.04,1.7)],.045)
    footing([(-2.3,-1.6),(2.3,-1.6),(2.3,1.6),(-2.3,1.6),(-2.3,-1.6)],.2)
    spill((-.7,0),(1,.3),2,2,70,154)

def terminal(x,z):
    a.loft('Terminal / fractured armored console',[(0,x,-z,1.6,1.3),(.4,x,-z,1.5,1.2),(1.3,x,-z,1.3,1.0),(1.8,x,-z+.15,1.1,.8)],3,13,.025,8,power=4)
    screen=block('Terminal / dead recessed screen',(x,1.4,z+.53),(.94,.58,.06),4)
    cable('Terminal / shattered glass line',[(x-.35,1.2,z+.57),(x-.05,1.5,z+.57),(x+.13,1.4,z+.57),(x+.4,1.65,z+.57)],.018,13)
    for j in range(3):block('Terminal / worn controls',(x-.22+j*.22,1.04,z+.57),(.10,.06,.06),5)
    cable('Terminal / severed structural lead',[(x,.3,z-.4),(x+.3,.06,z-1),(x+1,.04,z-1.2)],.055,11)

def industrial_wreck():
    fractured_floor((-5,5,-3.6,3.6),[(2.5,.6,2),(-2.5,-2,1)],161,True)
    x,z=2.6,0
    shell=a.loft('Wreck / half-buried curved pressure shell',[(0,x,-z,3.9,3.3),(.5,x,-z,3.7,3.1),(3.3,x,-z,3.15,2.8),(4,x,-z,2.5,2.3),(4.55,x-.2,-z+.1,1.6,1.9)],11,3,.04,24,power=2.5)
    cutter=a.loft('Rotor access recess',[(-.6,0,0,2.0,2.0),(.6,0,0,2.0,2.0)],4,4,0,32,power=2)
    cutter.rotation_euler.x=math.pi/2;a.position(cutter,xyz((x,2.1,1.3)));a.boolean_cut(shell,cutter)
    # Recesses expose a damaged rotor instead of a featureless cylinder.
    for radius in [1.14,.82,.38]:
        a.annulus('Wreck / exposed broken generator rotor',xyz((x,2.1,1.45)),radius,.15,.18,3,axis='Y',segments=24)
    for j in range(9):
        angle=j*math.tau/9
        if j in [2,3]:continue
        a.span('Rotor / surviving radial vane',xyz((x+math.cos(angle)*.3,2.1+math.sin(angle)*.3,1.5)),xyz((x+math.cos(angle)*1.05,2.1+math.sin(angle)*1.05,1.5)),[(0,.12,.16),(1,.18,.16)],3,14,6)
    for side in [-1,1]:
        cable('Wreck / ruptured coolant return',[(x+side*1.4,.2,-.8),(x+side*1.4,2.8,-.8),(x+side*.8,4.1,-.4),(x+side*.4,4.5,-.5)],.14,11)
    for j in range(5):block('Wreck / slashed louver',(x-.8+j*.38,3.3,.9),(.12,.55,.12),3)
    terminal(-3,-2)
    # The collapsed service beam is grounded within its low authoritative part.
    beam=block('Wreck / collapsed structural beam',(-3,.3,2.5),(2.8,.48,.55),3);beam.rotation_euler[1]=.13
    cable('Wreck / cable junction pulled apart',[(-3,.1,-1.5),(-2,.06,-.5),(-1,.05,1),(1,.04,1.4)],.07)
    footing([(-5,-3.5),(5,-3.5),(5,3.5),(-5,3.5),(-5,-3.5)],.26)
    spill((2.6,.4),(-1,.2),4,3.5,110,163)
    spill((-3,-2),(.4,1),2,2.5,65,164)

def checkpoint():
    fractured_floor((-4.4,4.4,-2.5,2.8),[(.5,1.2,1.7)],170,True)
    for x in [-2.9,2.9]:
        p=a.extrude_outline('Checkpoint / blast-sheared barrier',[(-1.35,0),(1.35,0),(1.35,1.0),(.7,1.3),(.25,1.0),(-.2,1.45),(-1.1,1.5),(-1.35,1.1)],1.05,.9,13,12,.04)
        a.position(p,(x,0,0))
        for j in range(4):block('Barricade / worn armored inset',(x-.8+j*.5,.55,-1.02),(.3,.3,.05),11)
    x,z=.6,1.2
    a.loft('Checkpoint / destroyed turret pedestal',[(0,x,-z,2.5,2.5),(.3,x,-z,2.4,2.4),(.8,x,-z,1.5,1.7),(1.4,x,-z,1.7,1.8),(2.2,x+.1,-z,1.3,1.5),(2.4,x+.15,-z,.8,1.0)],3,13,.025,12,power=3)
    a.annulus('Turret / exposed rotation race',xyz((x,.55,z)),1.15,.18,.18,11,axis='Z',segments=24)
    a.span('Turret / bent inert barrel',xyz((x,1.8,z+.2)),xyz((x+.5,1.1,z+1.1)),[(0,.38,.38),(.7,.29,.29),(1,.2,.2)],3,14,10)
    for j in range(3):
        block('Supply cache / abandoned ammunition case',(-3, .23+j*.30,1.5),(1.5,.29,1.0),11)
        block('Supply cache / reinforced case latch',(-3,.23+j*.3,2.02),(.28,.12,.04),3)
    for side in [-1,1]:cable('Checkpoint / detached communications lead',[(side*3,.2,-1),(side*2,.06,0),(side*1.2,.04,.4)],.04,11)
    footing([(-4.3,-2.4),(4.3,-2.4)],.35)
    spill((.6,1.2),(-.4,-1),2.7,3,100,172)

def pipeline():
    fractured_floor((-4.9,4.9,-1.6,1.6),[(0,0,1.8)],180,True)
    for side in [-1,1]:
        for zz in [-.5,.5]:
            cable('Pipeline / severed pressure main',[(side*4.5,.65,zz),(side*3,.8,zz),(side*1.5,1.05,zz+.14)],.29,11)
            ring=a.annulus('Pipeline / exposed torn flange',xyz((side*1.6,1.0,zz+.1)),.38,.09,.12,3,axis='X',segments=16)
        for xx in [side*2.5,side*4]:block('Pipeline / cracked concrete saddle',(xx,.24,0),(.6,.45,1.9),13)
    cable('Pipeline / torn control harness',[(-1.2,.2,1),(-.5,.05,1.3),(.4,.05,1.6),(1.6,.1,1.1)],.04)
    spill((-1.5,0),(.8,.3),3,2.8,95,182)

def crater():
    # The center is recessed relative to the raised shattered lip; the canonical
    # standing plane remains Y=0. No below-board hole or new elevation rule.
    verts=[(0,0,.004)];segments=56
    radii=[.7,1.5,2.0,2.6,3.3,3.8]
    heights=[.009,.025,.14,.19,.06,.008]
    for k,(r,h) in enumerate(zip(radii,heights)):
        for i in range(segments):
            t=math.tau*i/segments;rough=1+.06*math.sin(i*2.3)+.025*math.cos(i*1.7)
            verts.append((math.cos(t)*r*rough,-math.sin(t)*r*rough,h*(.8+.2*math.sin(i*.71)**2)))
    faces=[]
    for row in range(len(radii)-1):
        for i in range(segments):faces.append((1+row*segments+i,1+row*segments+(i+1)%segments,1+(row+1)*segments+(i+1)%segments,1+(row+1)*segments+i))
    faces.extend((0,1+(i+1)%segments,1+i) for i in range(segments))
    obj=a.mesh('Impact / concave crater bowl',verts,faces,15,15,0,True)
    obj['ground_contact']=True
    fractured_floor((-4.3,4.3,-3.6,3.6),[(0,0,3.4)],190)
    for i in range(20):
        t=math.tau*i/20;r=2.65+math.sin(i*1.7)*.3
        a.loft('Crater / expelled broken roadway',[(.01,math.cos(t)*r,-math.sin(t)*r,.55,.5),(.13,math.cos(t)*r,-math.sin(t)*r,.4,.35)],13,12,.008,6,power=2.5)
    # Radial tears read as one impact, instead of evenly scattered rubble.
    for i in [0,3,6,10,14,17]:
        t=i*math.tau/20
        cable('Crater / radial fracture seam',[(math.cos(t)*2,.025,math.sin(t)*2),(math.cos(t+.03)*3,.025,math.sin(t+.03)*3),(math.cos(t-.07)*4,.025,math.sin(t-.07)*4)],.025,4)

def station_hall():
    fractured_floor((-8.1,8.1,-4.8,4.4),[(1.2,-4.4,2.6),(6,1,2.5)],201,True)
    # Profile-extruded factory shell, torn roof line, deep service apertures.
    for x,w,h in [(-4.5,5.8,8),(3.5,6.5,7.5)]:
        contour=[(-w/2,0),(w/2,0),(w/2,h*.65),(w*.22,h*.8),(.2,h*.69),(-w*.15,h),(-w*.5,h*.95)]
        shell=a.extrude_outline('Factory / ripped reinforced shell',contour,-.4,.8,3,11,.045)
        for cx in [-w*.24,w*.24]:
            hole=[(cx-.65,2),(cx+.65,2),(cx+.65,h*.65),(cx-.65,h*.65)]
            a.boolean_cut(shell,a.extrude_outline('Factory / service aperture',hole,-1,2,4,4,0))
        a.position(shell,(x,4.5,0))
        for cx in [-w*.42,0,w*.42]:
            cable('Factory / exposed structural rib',[(x+cx,.2,-4.5),(x+cx,h*.8,-4.5)],.09,11)
        for j in range(5):block('Factory / ventilator louvers',(x,1.0+j*.17,-3.98),(1.5,.09,.12),11)
    for x,h in [(-7.8,6.5),(7.8,5.5)]:
        profile=[(-3.4,0),(3.4,0),(3.4,2.6),(1.4,3.2),(.3,h*.65),(-1,h),(-3.4,h*.95)]
        side=a.extrude_outline('Factory / sheared return wall',profile,-.4,.8,3,11,.035)
        side.matrix_world=Matrix.Translation(Vector((x,1.2,0)))@Matrix.Rotation(math.pi/2,4,'Z')@side.matrix_world
        for z in [-3.6,1.4]:
            block('Factory / structural column',(x,h*.38,z),(.8,h*.76,1.0),11)
    # Broken overhead hoist remains attached to rear piers; front stays open.
    for y in [5.6,6.2]:cable('Hoist / surviving rear truss',[(-6.5,y,-4),(4,y,-4)],.13,11)
    for j in range(7):cable('Hoist / diagonal web',[(-6.5+j*1.4,5.6,-4),(-5.8+j*1.4,6.2,-4)],.07,11)
    cable('Hoist / torn lifting cable',[(1.4,6,-3.8),(1.5,4.7,-3.7),(1.2,3.3,-3.4)],.045,11)
    footing([(-8,-4.8),(8,-4.8),(8,4),(-8,4),(-8,-4.8)],.6)
    spill((1.2,-4.4),(0,1),5,4,125,203)
    spill((7.8,1),(-1,.3),3,3,85,204)

def material_atlas():
    directory=DEST/'materials';directory.mkdir(parents=True,exist_ok=True)
    palette=list(a.PALETTE)
    palette[12]=('Ash-grey masonry','787e7a',0,.94);palette[13]=('Soot mortar','454b48',0,.96)
    palette[2]=('Pale worn edge','a6aaa0',0,.9);palette[11]=('Muted iron oxide','65503f',.5,.92)
    a.PALETTE=palette
    size=512;rng=random.Random(131);images=[]
    for name,is_orm in [('composition_pigment',False),('composition_orm',True)]:
        data=[]
        for y in range(size):
            for x in range(size):
                _,color,metal,rough=palette[x//128+(y//128)*4]
                shade=.94+rng.random()*.035+.025*math.sin(x*.08+math.sin(y*.1))
                rgb=[int(color[i:i+2],16)/255*shade for i in [0,2,4]]
                data.extend([1,min(1,rough+rng.random()*.03),metal,1] if is_orm else rgb+[1])
        image=bpy.data.images.new(name,width=size,height=size,alpha=False);image.colorspace_settings.name='Non-Color' if is_orm else 'sRGB'
        image.pixels.foreach_set(data);image.filepath_raw=str(directory/(name+'.png'));image.file_format='PNG';image.save();images.append(image)
    return images

def build(name,images):
    global CURRENT
    CURRENT=SPECS[name];a.setup();a.MM=1;a.asset='0131_'+name
    globals()[name]()
    mat=bpy.data.materials.new('GT_0131_ClusterAtlas');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
    pigment=nodes.new('ShaderNodeTexImage');pigment.image=bpy.data.images.load(str(images[0]))
    orm=nodes.new('ShaderNodeTexImage');orm.image=bpy.data.images.load(str(images[1]));orm.image.colorspace_settings.name='Non-Color'
    split=nodes.new('ShaderNodeSeparateColor');links.new(pigment.outputs['Color'],bsdf.inputs['Base Color']);links.new(orm.outputs['Color'],split.inputs[0]);links.new(split.outputs['Green'],bsdf.inputs['Roughness']);links.new(split.outputs['Blue'],bsdf.inputs['Metallic'])
    return export_source(name,mat)

def export_source(name,mat):
    global CURRENT
    CURRENT=SPECS[name]
    # Thin contact geometry must not self-shadow at tabletop shadow-map scale.
    # Keep it as a separate draw in the GLB rather than losing that distinction
    # when joining the export. Both meshes retain the same atlas material.
    source_group=a.SOURCE;bpy.context.view_layer.update()
    structure=a.collection('TEMP_structure');ground=a.collection('TEMP_ground')
    for source in source_group.objects:
        maximum=max((source.matrix_world@Vector(corner)).z for corner in source.bound_box)
        (ground if maximum<.14 or source.get('ground_contact',False) else structure).objects.link(source)
    models=[]
    if structure.objects:
        a.SOURCE=structure
        obj,group=a.game_mesh(mat);obj.name='GT_0131_'+name+'_Structure';models.append(obj)
    else:group=a.collection('02_GAME_EXPORT')
    if ground.objects:
        a.SOURCE=ground
        low,extra=a.game_mesh(mat);low.name='GT_0131_'+name+'_GroundContact'
        a.link_only(low,group);bpy.data.collections.remove(extra);models.append(low)
    bpy.data.collections.remove(structure);bpy.data.collections.remove(ground);a.SOURCE=source_group
    obj=models[0]
    for source in a.SOURCE.objects:source.hide_render=True;source.hide_set(True)
    bpy.ops.object.select_all(action='DESELECT')
    for model in models:model.select_set(True)
    bpy.context.view_layer.objects.active=obj
    DEST.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    for img in bpy.data.images:
        if img.source=='FILE':img.pack()
    source=ROOT/'art/blender/environment/0131';source.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')))
    for model in models:model.data.calc_loop_triangles()
    return dict(asset=name,triangles=sum(len(model.data.loop_triangles) for model in models),meshes=len(models),source=str((source/(name+'.blend')).relative_to(ROOT)).replace('\\','/'),export=str((DEST/(name+'.glb')).relative_to(ROOT)).replace('\\','/'),size=CURRENT['size'],footprint_parts=CURRENT['parts'])

if __name__=='__main__':
    a.setup();DEST.mkdir(parents=True,exist_ok=True)
    images=material_atlas();paths=[image.filepath_raw for image in images]
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['sanctum','transept','breached_gate','shrine']
    reports=[build(name,paths) for name in args]
    folder=ROOT/'docs/environment/0131';folder.mkdir(parents=True,exist_ok=True)
    metrics=folder/'mesh_metrics.json';old=json.loads(metrics.read_text()) if metrics.exists() else []
    metrics.write_text(json.dumps(list({i['asset']:i for i in old+reports}.values()),indent=2)+'\n')
    print('GRIMTABLE 0131 CLUSTERS '+json.dumps(reports))
