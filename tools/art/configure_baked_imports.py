"""After the first Godot import, set data-safe mipmapped 3D bake imports."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
count=0
images=list((ROOT/'assets/materials/baked_0133').rglob('*.png'))
images+=list((ROOT/'assets/workshop').glob('legion_components_*.png'))
# The Workshop UV-island ID image deliberately stays lossless: its integer
# labels are CPU data, not display colors or a compressible material texture.
for image in images:
    path=Path(str(image)+'.import')
    if not path.exists():raise RuntimeError('Import in Godot first: '+str(image))
    original_text=path.read_text()
    text=original_text
    options={'compress/mode':'2','compress/high_quality':'true','compress/normal_map':'1' if image.stem=='normal' or image.stem.endswith('_normal') else '0','mipmaps/generate':'true','process/fix_alpha_border':'false','process/normal_map_invert_y':'false','detect_3d/compress_to':'0'}
    for key,value in options.items():
        text=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
    if text!=original_text:path.write_text(text)
    count+=1
print('Configured',count,'mipmapped BC-compressed bake textures; data channels retained, +Y normals')
for image in list((ROOT/'assets/workshop').glob('*_region_ids.png'))+list((ROOT/'assets/workshop').glob('legion_uv_islands.png')):
    path=Path(str(image)+'.import')
    if not path.exists():raise RuntimeError('Import in Godot first: '+str(image))
    original_text=path.read_text();text=original_text
    for key,value in {'compress/mode':'0','compress/normal_map':'0','mipmaps/generate':'false','process/fix_alpha_border':'false','detect_3d/compress_to':'0'}.items():
        text=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
    if text!=original_text:path.write_text(text)
print('Workshop categorical IDs and UV islands remain lossless, without mipmaps')
