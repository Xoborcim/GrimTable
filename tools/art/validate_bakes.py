"""Validate bake outputs, unique UV interiors, tangents and retained silhouettes.

Requires numpy and Pillow. Does not modify art. Overlap checks sample triangle
interiors at up to 1024px; thin subpixel faces are explicitly not exhaustive.
"""
from pathlib import Path
import argparse, hashlib, json, struct, zipfile
import numpy as np
from PIL import Image
from bake_textures import ROOT, ASSETS, OUTPUT, REPORTS

def glb(data):
    assert data[:4]==b'glTF'
    length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]);offset=20+length
    blob=data[offset+8:offset+8+struct.unpack_from('<I',data,offset)[0]]
    return doc,blob

def accessor(doc,blob,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    stride=v.get('byteStride',np.dtype(dtype).itemsize*count)
    return np.ndarray((a['count'],count),dtype=dtype,buffer=blob,offset=offset,strides=(stride,np.dtype(dtype).itemsize)).copy()

def uv_audit(triangles,size):
    coverage=np.zeros((size,size),dtype=np.uint16)
    for tri in triangles:
        xy=tri*size
        low=np.maximum(0,np.floor(xy.min(axis=0)).astype(int));high=np.minimum(size-1,np.ceil(xy.max(axis=0)).astype(int))
        if np.any(high<low):continue
        x,y=np.meshgrid(np.arange(low[0],high[0]+1)+.5,np.arange(low[1],high[1]+1)+.5)
        p=xy[0];q=xy[1];r=xy[2]
        determinant=(q[1]-r[1])*(p[0]-r[0])+(r[0]-q[0])*(p[1]-r[1])
        if abs(determinant)<1e-8:continue
        a=((q[1]-r[1])*(x-r[0])+(r[0]-q[0])*(y-r[1]))/determinant
        b=((r[1]-p[1])*(x-r[0])+(p[0]-r[0])*(y-r[1]))/determinant
        interior=(a>1e-5)&(b>1e-5)&(a+b<1-1e-5)
        coverage[low[1]:high[1]+1,low[0]:high[0]+1]+=interior
    return coverage

def validate(name,baseline):
    source,export,res,kind=ASSETS[name]
    report=json.loads((REPORTS/(name+'_bake.json')).read_text())
    assert hashlib.sha256((ROOT/source).read_bytes()).hexdigest()==report['source_sha256'],'Original source changed'
    doc,blob=glb((ROOT/export).read_bytes())
    uvs=[];positions=[];triangles=0
    for mesh in doc['meshes']:
        assert len(mesh['primitives'])==1,'Unexpected material/draw split'
        for primitive in mesh['primitives']:
            at=primitive['attributes'];pos=accessor(doc,blob,at['POSITION']);positions.append(pos)
            uv=accessor(doc,blob,at['TEXCOORD_0']);tangent=accessor(doc,blob,at['TANGENT'])
            indices=accessor(doc,blob,primitive['indices']).ravel()
            assert np.isfinite(pos).all() and np.isfinite(uv).all() and np.isfinite(tangent).all()
            assert uv.min()>=-.00001 and uv.max()<=1.00001,'UV outside atlas'
            assert np.abs(np.linalg.norm(tangent[:,:3],axis=1)-1).max()<.003,'Invalid tangent length'
            triangles+=indices.size//3;uvs.append(uv[indices].reshape(-1,3,2))
    assert triangles==report['triangles'],'Triangle count changed'
    if baseline and name!='scenic_ground':
        old,oldblob=glb(baseline.read(export));old_positions=[]
        for mesh in old['meshes']:
            for primitive in mesh['primitives']:old_positions.append(accessor(old,oldblob,primitive['attributes']['POSITION']))
        old_positions=np.concatenate(old_positions);new_positions=np.concatenate(positions)
        bounds_error=float(max(np.abs(old_positions.min(0)-new_positions.min(0)).max(),np.abs(old_positions.max(0)-new_positions.max(0)).max()))
        assert bounds_error<.0001,('Changed silhouette bounds',name,bounds_error)
    else:bounds_error=0
    coverage=uv_audit(np.concatenate(uvs),min(1024,res))
    used=coverage>0
    overlaps=float(np.count_nonzero(coverage>1)/max(1,np.count_nonzero(used)))
    assert overlaps<.001,('Destructive UV interior overlap',name,overlaps)
    material=doc['materials'][0]
    for texture in [material['pbrMetallicRoughness']['baseColorTexture'],material['pbrMetallicRoughness']['metallicRoughnessTexture'],material['normalTexture'],material['occlusionTexture']]:
        assert texture.get('texCoord',0)==0,'Unexpected tangent UV association'
    metrics=[]
    for record in report['maps']:
        path=OUTPUT/name/(record['map']+'.png');im=Image.open(path)
        assert im.size==(res,res)
        values=np.asarray(im.convert('RGBA'))/255
        metrics.append({'map':record['map'],'bytes':path.stat().st_size,'dimensions':list(im.size),'rgba8_mip_bytes':round(res*res*4*4/3)})
        if record['map']=='normal':
            decoded=values[:,:,:3]*2-1
            mask=values[:,:,3]>.5
            assert float(decoded[:,:,2][mask].mean())>.65,'Mostly inverted tangent normals'
            normal_variation=float(decoded[:,:,:2][mask].std())
            assert normal_variation>.002,'Empty normal bake'
    return {'asset':name,'triangles':triangles,'source_preserved':True,'bounds_error_inches':bounds_error,'uv_raster_size':min(1024,res),'uv_coverage':float(np.count_nonzero(used)/coverage.size),'uv_interior_overlap_fraction':overlaps,'tangents_finite_unit':True,'normal_xy_stddev':normal_variation,'textures':metrics}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--assets',nargs='+',choices=list(ASSETS))
    args=parser.parse_args();names=args.assets or [n for n in ASSETS if (REPORTS/(n+'_bake.json')).exists()]
    baseline_path=ROOT/'builds/GrimTable-0.13.2-source-baseline.zip'
    baseline=zipfile.ZipFile(baseline_path) if baseline_path.exists() else None
    results=[]
    try:
        for name in names:
            result=validate(name,baseline);results.append(result)
            print('VALIDATED',name,'UV occupancy',round(result['uv_coverage']*100,1),'% / overlap',result['uv_interior_overlap_fraction'],flush=True)
    finally:
        if baseline:baseline.close()
    summary={'assets':results,'new_png_bytes':sum(t['bytes'] for r in results for t in r['textures']),'uncompressed_rgba8_mip_bytes':sum(t['rgba8_mip_bytes'] for r in results for t in r['textures']),'uv_limit':'Raster triangle-interior audit at up to 1024px; subpixel UVs need visual seam review.'}
    (REPORTS/'bake_validation.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('GRIMTABLE BAKE VALIDATION PASS',len(results),'assets')
