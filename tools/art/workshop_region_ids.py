"""Recover categorical paint IDs from preserved Blender palette ownership.
Python launcher needs NumPy/Pillow; Blender workers read existing sources only.
Unlike the continuous 0.13.3 finish bake, this map never interpolates ID numbers.
"""
from pathlib import Path
import sys,subprocess,json,os
ROOT=Path(__file__).resolve().parents[2]
ASSETS=['legion_infantry','heavy_walker','swarm_creature']

def worker(name):
    import bpy,numpy as np
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/baked_0133'/f'{name}.blend'))
    uvs=[];tiles=[]
    # The preserved relief mesh retains the original per-face bake recipes and
    # exact BakeUVs. Reading them avoids geometric nearest-neighbor ambiguity.
    for high in bpy.data.collections['03_HIGH_RELIEF_0133'].objects:
        if high.type!='MESH':continue
        mesh=high.data;mesh.calc_loop_triangles();uv=mesh.uv_layers['BakeUV']
        for tri in mesh.loop_triangles:
            material=mesh.materials[tri.material_index]
            if 'bake_tile' not in material:raise RuntimeError('Missing preserved bake material ownership')
            tiles.append(int(material['bake_tile']))
            uvs.append([tuple(uv.data[loop].uv) for loop in tri.loops])
    path=ROOT/'.runtime/workshop-0140'/f'{name}_ids.npz'
    np.savez_compressed(path,uv=np.array(uvs),ids=np.array(tiles))
    print('WORKSHOP REGION SOURCE',name,len(tiles),sorted(set(tiles)))

def main():
    import numpy as np
    from PIL import Image,ImageDraw,ImageFilter
    blender=os.environ.get('BLENDER_EXE',r'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe')
    report={}
    for name in ASSETS:
        if '--raster-only' not in sys.argv:subprocess.run([blender,'--background','--python',str(Path(__file__).resolve()),'--','--worker',name],cwd=ROOT,check=True)
        data=np.load(ROOT/'.runtime/workshop-0140'/f'{name}_ids.npz')
        size=2048 if name=='heavy_walker' else 1024
        image=Image.new('L',(size,size));draw=ImageDraw.Draw(image)
        for uv,tile in zip(data['uv'],data['ids']):
            # Blender UVs are bottom-up. glTF TEXCOORD_0 and PNG rows are top-down.
            exported=uv.copy();exported[:,1]=1-exported[:,1]
            draw.polygon([tuple(p) for p in exported*size],fill=int(tile)+1)
        covered=np.asarray(Image.fromarray((np.asarray(image)>0).astype('uint8')*255).filter(ImageFilter.MinFilter(3)))>0
        # Extend only empty padding; labels inside real triangles remain intact.
        values=np.asarray(image).copy()
        for _ in range(4):
            dilated=np.asarray(Image.fromarray(values).filter(ImageFilter.MaxFilter(3)))
            values=np.where(values==0,dilated,values).astype('uint8')
        target=ROOT/'assets/workshop'/f'{name}_region_ids.png';Image.fromarray(values).save(target)
        agreement={}
        regions=ROOT/'assets/materials/baked_0133'/name/'regions.png'
        if regions.exists():
            colors=np.asarray(Image.open(regions).convert('RGB'))
            for channel,expected in [(0,[1,2]),(1,[3]),(2,[6])]:
                confident=np.asarray(Image.fromarray((colors[:,:,channel]>245).astype('uint8')*255).filter(ImageFilter.MinFilter(7)))>0
                interior=confident&covered
                score=float(np.isin(values[interior],expected).mean())
                agreement[['primary','secondary','trim'][channel]]=score
                if score<.93:raise RuntimeError(f'{name}: categorical UV orientation/ownership disagrees with original paint masks: {agreement}')
        report[name]={'resolution':size,'triangles':len(data['ids']),'palette_ids':sorted(map(int,np.unique(data['ids']))),'ownership':'Exact preserved high-relief UV faces and original bake_tile recipes','bytes':target.stat().st_size,'existing_paint_mask_agreement':agreement,'agreement_test':'Fully opaque independent paint-mask interiors eroded by 3px on each side; excludes unmapped/padding texels','uv_orientation':'Blender V flipped to glTF/PNG row coordinates','encoding':'lossless R8: palette ID + 1; 0 outside mapped geometry; nearest sampling; no mips'}
    (ROOT/'docs/art/workshop_0140/region_ids.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':
    if '--worker' in sys.argv:worker(sys.argv[-1])
    else:main()
