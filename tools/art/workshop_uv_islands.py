"""Build an explicit UV-island ownership mask from the prepared Legion GLB.
Ordinary Python + NumPy/Pillow. No changes to source geometry or baked maps.
"""
from pathlib import Path
import json,struct
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
raw=(ROOT/'assets/miniatures/legion/legion_infantry.glb').read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
def accessor(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
    components={'VEC2':2,'VEC3':3,'SCALAR':1}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],components),dtype=dtype,buffer=binary,offset=offset,strides=(v.get('byteStride',np.dtype(dtype).itemsize*components),np.dtype(dtype).itemsize)).copy()
p=doc['meshes'][0]['primitives'][0]
uv=accessor(p['attributes']['TEXCOORD_0']);verts=accessor(p['attributes']['POSITION']);indices=accessor(p['indices']).reshape(-1,3)
parent=list(range(len(indices)))
def find(i):
    while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
    return i
seen={}
for i,tri in enumerate(indices):
    for vertex in tri:
        key=tuple(np.round(np.concatenate([uv[vertex],verts[vertex]]),6))
        if key in seen:parent[find(i)]=find(seen[key])
        else:seen[key]=i
labels={};mask=Image.new('I',(1024,1024));draw=ImageDraw.Draw(mask)
for i,tri in enumerate(indices):
    root=find(i)
    if root not in labels:labels[root]=len(labels)+1
    draw.polygon([tuple(p) for p in uv[tri]*1023],fill=labels[root])
values=np.array(mask,dtype=np.uint32)
rgba=np.zeros((1024,1024,4),dtype=np.uint8);rgba[:,:,0]=values%256;rgba[:,:,1]=(values//256)%256;rgba[:,:,2]=(values//65536)%256;rgba[:,:,3]=255
Image.fromarray(rgba).save(ROOT/'assets/workshop/legion_uv_islands.png')
(ROOT/'docs/art/workshop_0140/uv_islands.json').write_text(json.dumps({'islands':len(labels),'resolution':1024,'source':'0.13.3 uniquely unwrapped Legion atlas','encoding':'R + G*256 + B*65536, zero outside triangles'},indent=2)+'\n')
print('WORKSHOP UV ISLANDS',len(labels))
