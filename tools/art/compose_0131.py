"""Curated location composition. Hollow first; Station only after visual gate."""
from pathlib import Path
import json,copy,sys
ROOT=Path(__file__).resolve().parents[2]
SCENARIOS=ROOT/'resources/scenarios'

def catalog():
    metrics=json.loads((ROOT/'docs/environment/0131/mesh_metrics.json').read_text())
    rows=[]
    labels={'sanctum':'Shattered Sanctum','transept':'Collapsed Transept','breached_gate':'Breached Gate','shrine':'Ruined Shrine','industrial_wreck':'Industrial Wreckage','checkpoint':'Destroyed Checkpoint','pipeline':'Broken Pipeline','crater':'Cratered Roadway','station_hall':'Ruptured Manufacturing Hall'}
    for metric in metrics:
        name=metric['asset'];record=dict(name='Clusters / '+labels[name],id=name,kind='ruin' if name=='sanctum' else 'box',size=metric['size'],visual_scene='res://'+metric['export'],blocks_movement=name!='crater',blocks_los=name not in ['crater','pipeline'],cover_bonus=1 if name=='crater' else 0)
        if metric['footprint_parts']:record['footprint_parts']=metric['footprint_parts']
        if name=='crater':record['movement_penalty']=2
        rows.append(record)
    rows.append(dict(id='cover_floor',name='Battlefield / Ruin Cover Floor',kind='box',size=[8,0.1,6],visual_scene='res://scenes/terrain/ground_area.tscn',blocks_movement=False,blocks_los=False,cover_bonus=1))
    (ROOT/'resources/environment/clusters_0131.json').write_text(json.dumps({'clusters':rows},indent=2)+'\n')
    return {r['id']:r for r in rows}

def asset(catalog,key,id,at,angle=0):
    record=copy.deepcopy(catalog[key]);record['id']=id;record['title']=record.pop('name').split(' / ')[-1]
    record.update(position=[at[0],0,at[1]],rotation=angle,tint='#747b76')
    return record

def hollow(cat):
    path=SCENARIOS/'hollow_basilica.json';data=json.loads(path.read_text())
    data['notes']='The Shattered Sanctum: surviving nave and crossing, collapsed west transept, breached eastern gate and a ruined service court. Upper levels are decorative; inspect actual footprints. Original GrimTable architecture.'
    data['board'].update(surface_layout='Sanctum',environment_art=True,atmosphere=.4)
    # Existing units/profile/base dimensions remain unchanged.
    data['terrain']=[asset(cat,'sanctum','nave',(-12,-4)),asset(cat,'transept','transept',(-20,6)),asset(cat,'breached_gate','gate',(15,-8)),asset(cat,'shrine','shrine',(-6,2))]
    data['terrain'] += [dict(id='bunker',title='Industrial Perimeter Casemate',kind='box',size=[7,3,4],position=[23,0,0],rotation=0,tint='#545e61',blocks_movement=True,blocks_los=True,visual_scene='res://assets/terrain/environment/breach_bunker.glb')]
    for key,id,at in [('industrial_wreck','court_remains',(20,7)),('checkpoint','checkpoint',(7,8)),('pipeline','process_link',(22,4)),('crater','impact',(3,3))]:
        if key in cat:data['terrain'].append(asset(cat,key,id,at))
    cover=asset(cat,'cover_floor','nave_cover',(-11,-3));cover['size']=[14,0.1,10];cover['title']='Ruined Nave Floor / Cover +1';data['terrain'].append(cover)
    if 'checkpoint' in cat:
        cover=asset(cat,'cover_floor','checkpoint_cover',(7,8));cover['size']=[9,0.1,6];cover['title']='Barricaded Courtyard / Cover +1';data['terrain'].append(cover)
    for obj,at,title in zip(data['objectives'],[(-15,2),(0,0),(15,5)],['Sanctum Reliquary','Breached Crossing','Broken Distribution Node']):obj.update(position=[at[0],0,at[1]],name=title)
    path.write_text(json.dumps(data,indent=2)+'\n')

def station(cat):
    path=SCENARIOS/'ashfall_station.json';data=json.loads(path.read_text())
    data['board'].update(surface_layout='Transport',environment_art=True,atmosphere=.3,clutter='Composed',weather='Vapor')
    data['notes']='A devastated transport station: the left cargo corridor passes a breached checkpoint; the eastern manufacturing hall encloses a ruptured generator and service yard. Original guided move and firing lane remain open.'
    terrain={r['id']:r for r in data['terrain'] if r['id'] not in ['manufacturing_hall','transport_checkpoint','severed_main','shell_impact','refinery_tower']}
    terrain['station_0'].update(title='Damaged transport casemate',size=[7,3,4],visual_scene='res://assets/terrain/environment/breach_bunker.glb')
    terrain['station_3']=asset(cat,'industrial_wreck','station_3',(17.5,-9))
    for key in ['cover_0','cover_1','rubble_apron']:terrain[key]['visual_scene']='res://scenes/terrain/ground_area.tscn'
    data['terrain']=list(terrain.values())
    data['terrain'] += [asset(cat,'station_hall','manufacturing_hall',(15,-10)),asset(cat,'checkpoint','transport_checkpoint',(-21,0)),asset(cat,'pipeline','severed_main',(-21,-9)),asset(cat,'crater','shell_impact',(-19,13))]
    data['terrain'].append(dict(id='refinery_tower',title='Station Refinery Core',kind='box',size=[7,11,6],position=[24,0,-16],rotation=0,tint='#6b655a',blocks_movement=True,blocks_los=True,visual_scene='res://assets/terrain/environment/refinery_core.glb'))
    for obj,title in zip(data['objectives'],['Transport Relay','Junction Control','Generator Distribution Node']):obj['name']=title
    path.write_text(json.dumps(data,indent=2)+'\n')

if __name__=='__main__':
    cat=catalog()
    if len(sys.argv)==1 or 'hollow' in sys.argv:hollow(cat)
    if 'station' in sys.argv:station(cat)
