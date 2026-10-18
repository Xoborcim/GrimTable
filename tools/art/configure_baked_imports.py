"""After the first Godot import, set data-safe mipmapped 3D bake imports."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
count=0
for image in (ROOT/'assets/materials/baked_0133').rglob('*.png'):
    path=Path(str(image)+'.import')
    if not path.exists():raise RuntimeError('Import in Godot first: '+str(image))
    text=path.read_text()
    options={'compress/mode':'2','compress/high_quality':'true','compress/normal_map':'1' if image.stem=='normal' else '0','mipmaps/generate':'true','process/fix_alpha_border':'false','process/normal_map_invert_y':'false','detect_3d/compress_to':'0'}
    for key,value in options.items():
        text=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
    path.write_text(text);count+=1
print('Configured',count,'mipmapped BC-compressed bake textures; data channels retained, +Y normals')
