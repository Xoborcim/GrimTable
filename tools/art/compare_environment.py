"""Arrange unchanged native Godot frames; no retouching or resampling."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
folder=ROOT/'docs/environment'
before=Image.open(folder/'ashen_basilica_before.png').convert('RGB')
after=Image.open(folder/'ashen_basilica_0130.png').convert('RGB')
assert before.size==after.size
w,h=before.size
sheet=Image.new('RGB',(w*2,h+88),(18,26,31));sheet.paste(before,(0,88));sheet.paste(after,(w,88))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',30)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
draw.text((20,10),'0.12.0 / Ashen Basilica',font=font,fill=(220,222,215))
draw.text((w+20,10),'0.13.0 / Recomposed Ashen Basilica',font=font,fill=(173,207,207))
for x in [20,w+20]:draw.text((x,52),'Same viewport and camera. Unchanged native Godot captures.',font=small,fill=(176,185,185))
sheet.save(folder/'ashen_basilica_comparison_0130.png')
print('ENVIRONMENT COMPARISON',sheet.size)
