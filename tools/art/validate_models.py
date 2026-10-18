"""Read-only, standard-library GLB/asset validation. No editor import assumptions."""
import json
import struct
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUTPUTS={
    'legion_infantry':'assets/miniatures/legion/legion_infantry.glb',
    'heavy_walker':'assets/miniatures/legion/heavy_walker.glb',
    'swarm_creature':'assets/miniatures/swarm/swarm_creature.glb',
    'ruined_basilica':'assets/terrain/gothic/ruined_basilica.glb',
}

def validate(name,path):
    data=(ROOT/path).read_bytes()
    magic,version,length,chunk,kind=struct.unpack_from('<5I',data)
    assert magic==0x46546c67 and version==2 and length==len(data) and kind==0x4e4f534a
    doc=json.loads(data[20:20+chunk])
    assert doc['asset']['version']=='2.0'
    triangles=0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            assert {'POSITION','NORMAL','TEXCOORD_0'}<=primitive['attributes'].keys()
            triangles+=doc['accessors'][primitive['indices']]['count']//3
    for group in ['buffers','images']:
        assert all('uri' not in item for item in doc.get(group,[])), 'Expected self-contained GLB'
    source=ROOT/'art/blender'/(name+'.blend')
    assert source.exists() and source.stat().st_size>100000
    assert len(doc['materials'])<=2
    assert 1000<triangles<350000
    assert not doc.get('animations'), 'Static assets deliberately use the existing motion fallback'
    return dict(asset=name,export=path,source=str(source.relative_to(ROOT)).replace('\\','/'),triangles=triangles,
                materials=len(doc['materials']),meshes=len(doc['meshes']),bytes=len(data),sha256=hashlib.sha256(data).hexdigest())

if __name__=='__main__':
    results=[validate(name,path) for name,path in OUTPUTS.items()]
    (ROOT/'docs/art/asset_validation.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))
