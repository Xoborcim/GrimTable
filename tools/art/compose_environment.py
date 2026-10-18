"""Original curated 0.13 showcase layouts; no random terrain placement."""
from pathlib import Path
import json,copy
ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/'resources/scenarios'
base=json.loads((DIR/'ashen_basilica.json').read_text())

def terrain(id,title,at,size,style='',model='',angle=0,kind='box',movement=True,los=True,cover=0,penalty=0):
    item=dict(id=id,title=title,position=[at[0],0,at[1]],size=size,art_style=style,kind=kind,rotation=angle,tint='#777366',blocks_movement=movement,blocks_los=los,cover_bonus=cover,movement_penalty=penalty)
    if model:item['visual_scene']='res://assets/terrain/environment/'+model+'.glb'
    return item

def compose(id,name,theme):
    data=copy.deepcopy(base);data['id']=id;data['name']=name
    data['notes']='Three lanes around a broken ceremonial crossing. Upper floors are decorative; inspect terrain for authoritative cover and LOS. Original GrimTable environment.'
    data['board']=dict(width=60,depth=44,theme=theme,lighting='Dusk',atmosphere=.55,environment_art=True,clutter='Composed',weather='Theme',surround='Obsidian')
    # Keep opposing formations in clear staging pockets, outside dense midfield.
    for n,army in enumerate(data['armies']):
        center=[-17,-2,15][n%3];z=(16 if n%3==0 else 15)*(1 if army['team']==0 else -1)
        old=sum(m['position'][0] for m in army['models'])/len(army['models'])
        for model in army['models']: model['position']=[model['position'][0]-old+center,0,z]
    t=[]
    add=lambda *args,**kwargs:t.append(terrain(*args,**kwargs))
    if theme=='cathedral':
        add('nave','Hollow Nave / solid ruined wall',(-8,-5),[13,10,7],'gothic',kind='ruin')
        add('gate','Broken Processional Gate',(17,-10),[8,12.4,3],model='gatehouse',angle=-12)
        add('cloister','West Cloister / solid wall',(-23,0),[8,6,1.4],model='cloister',angle=90)
        add('choir','Shattered Choir',(19,12),[8,6,1.4],model='cloister',angle=180)
        add('altar','Reliquary of the Last Signal',(-17,-2),[3,3.3,3],model='reliquary')
        add('engine','Ancient Cooling Shrine',(22,0),[6,6,4],model='cooling_bank')
        add('vestry','Blasted Vestry / broken wall',(-20,10),[6,4,4],'gothic',kind='ruin',angle=180)
        add('screen','Broken Civic Screen',(7,-10),[6,3,.8],'gothic')
    else:
        add('core','Abandoned Refinery Core' if theme=='toxic' else 'Ashfall Reactor Shrine',(-9,-5),[7,11,6],model='refinery_core')
        add('coolers','Ruptured Cooling Bank',(18,-9),[6,6,4],model='cooling_bank')
        add('gantry','Silent Freight Hoist',(-21,8),[7,8,4],model='hoist')
        add('bulkhead','Broken Industrial Gate',(20,11),[8,6,1.4],model='cloister',angle=180)
        add('silo','Emergency Process Tower',(-23,-10),[4,7,4],'refinery')
        add('exchange','Armored Transformer',(8,9),[4,4,4],'generator')
    add('bunker','Blasted Casemate / solid cover',(14,3),[7,3,4],model='breach_bunker',angle=-15)
    add('trench','Collapsed Revetment / difficult ground',(-13,8),[8,.7,3],model='trench',movement=False,los=False,cover=1,penalty=2)
    add('breach','Broken Defense Line',(3,-5),[4,1,.8],'barricade',los=False)
    add('shield','Scorched Blast Shield',(-5,8),[4,1,.8],'barricade',angle=18,los=False)
    add('pipe','Severed Conduit',(-20,3),[5,1.8,2],'pipes',angle=90,los=False)
    add('wreck','Abandoned Gun Carriage',(24,4),[4,1.4,3],'wreckage',los=False)
    add('impact','Shell Impact / crater cover',(5,1),[4,.12,4],'crater',movement=False,los=False,cover=1)
    add('rubble','Broken Flagstone / unstable footing',(-3,-2),[5,.12,3],'rubble',movement=False,los=False,penalty=2)
    add('cache','Old Supply Apron',(-18,-5),[6,.12,4],'rubble',movement=False,los=False,cover=1)
    add('pad','Relay Maintenance Apron',(17,7),[6,.12,4],'rubble',movement=False,los=False,cover=1)
    if theme=='toxic':
        for item in t:
            if item['id']=='core':item['position']=[-13,0,-8]
            if item['id']=='coolers':item['position']=[20,0,-5];item['rotation']=-18
            if item['id']=='bunker':item['position']=[13,0,-5];item['rotation']=12
        add('runoff','Contaminated Runoff / difficult ground',(-2,10),[7,.12,4],'pool',movement=False,los=False,penalty=2)
        add('sludge','Leaking Waste Pad',(22,-1),[5,.12,4],'pool',movement=False,los=False,penalty=2)
    else:
        add('pillar','Shattered Civic Column',(2,11),[2,5,2],'pillar')
    data['terrain']=t
    for objective,at,name in zip(data['objectives'],[(-17,1),(0,0),(17,7)],['Reliquary Access' if theme=='cathedral' else 'Coolant Control','Broken Crossing' if theme=='cathedral' else 'Process Junction','Emergency Relay']):
        objective['position']=[at[0],0,at[1]];objective['name']=name
    (DIR/(id+'.json')).write_text(json.dumps(data,indent=2)+'\n')

if __name__=='__main__':
    compose('hollow_basilica','The Hollow Basilica','cathedral')
    compose('ashen_basilica','The Ashen Basilica','cathedral')
    compose('ashfall_manufactorum','Ashfall Manufactorum','ashfall')
    compose('toxic_forge','Toxic Forge','toxic')
