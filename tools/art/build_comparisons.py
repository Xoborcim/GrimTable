"""Arrange unchanged rendered images into labeled side-by-side review sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
folder=ROOT/'docs/art/comparisons'
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
for name in ['legion_infantry','heavy_walker','swarm_creature','ruined_basilica']:
    before=folder/(name+'_before.png'); after=folder/(name+'_after.png')
    if not before.exists() or not after.exists(): continue
    a,b=Image.open(before).convert('RGB'),Image.open(after).convert('RGB')
    assert a.size==b.size
    sheet=Image.new('RGB',(a.width*2,a.height+88),'#111a22')
    sheet.paste(a,(0,88)); sheet.paste(b,(a.width,88))
    draw=ImageDraw.Draw(sheet)
    draw.text((25,12),'0.11.0 authored geometry',font=font,fill='#d6d5cc')
    draw.text((a.width+25,12),'0.12.0 Blender mesh',font=font,fill='#b0d5d5')
    draw.text((25,49),'Same camera, height, studio lights and base. Baseline batching indices corrected.',font=small,fill='#b7b9b9')
    sheet.save(folder/(name+'_side_by_side.png'))
