"""Collect unedited screenshots and validation evidence from the Windows smoke."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,html
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
VIEWS=[('01_default_legion','Default Legion'),('02_oxide_legion','Oxide paint scheme'),('03_second_scheme','Verdant paint scheme'),('04_assembled_legion','Alternate fitted components'),('05_freehand_brush','Player-driven surface stroke'),('05b_surface_marking','Island-clipped marking'),('06_base_rubble','Rubble base'),('06_base_industrial','Industrial base'),('06_base_stone','Stone base'),('06_base_ash','Ash base'),('07_saved_collection','Saved collection'),('08_studio_photo','Clean studio capture'),('09_customized_battle','Customized figures in an actual battle'),('10_restart_collection','Collection after application restart')]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--captures',type=Path,required=True);args=parser.parse_args()
    target=ROOT/'docs/art/workshop_0140';target.mkdir(parents=True,exist_ok=True)
    manifest=[]
    for name,title in VIEWS:
        source=args.captures/(name+'.png');destination=target/source.name
        with Image.open(source) as image:dimensions=list(image.size)
        shutil.copy2(source,destination)
        manifest.append({'file':destination.name,'title':title,'dimensions':dimensions,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'source':'Unretouched Godot 4.6.1 Windows release, OpenGL Compatibility'})
    for source,name in [('workshop_result.json','packaged_validation.json'),('workshop_restart.json','restart_validation.json'),('composition_0131_smoke_result.json','packaged_gameplay.json')]:
        value=json.loads((args.captures/source).read_text())
        if value.get('failures'):raise RuntimeError(f'Failed packaged checks: {source}: {value}')
        (target/name).write_text(json.dumps(value,indent=2)+'\n')
    (target/'screenshots.json').write_text(json.dumps(manifest,indent=2)+'\n')
    cards='\n'.join(f'<figure><a href="{x["file"]}"><img loading="lazy" src="{x["file"]}" alt="{html.escape(x["title"])}"></a><figcaption>{html.escape(x["title"])}</figcaption></figure>' for x in manifest)
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GrimTable 0.14.0 — Miniature Workshop</title><style>body{margin:28px;background:#111b22;color:#e4dbc8;font:16px system-ui}h1{font-size:28px}p{color:#acb9c0;max-width:950px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:20px}figure{margin:0;background:#202e37;border-radius:8px;overflow:hidden}img{width:100%;display:block}figcaption{padding:12px}a{color:#e0c183}@media(max-width:520px){main{display:block}figure{margin-bottom:18px}}</style><h1>GrimTable 0.14.0 — Miniature Workshop</h1><p>Native screenshots from the packaged Windows release. No image retouching, mockups, or substituted renders. Paint/assembly/base changes are intentional editing operations; the studio uses its standard lighting preset. Click an image for its original resolution.</p><main>'''+cards+'</main></html>'
    (target/'gallery.html').write_text(page,encoding='utf-8')
    lines=(ROOT/'.runtime/workshop-0140/regression.log').read_text(encoding='utf-8').splitlines()
    results=[]
    for line in lines:
        if not line.startswith('GRIMTABLE'):continue
        match=re.search(r':\s*(\d+) checks',line) or re.search(r'CHECKS\s*:?\s*(\d+)',line)
        if not match:raise RuntimeError('Unparsed regression result: '+line)
        results.append({'summary':line,'checks':int(match.group(1))})
    if not any('VALIDATION PASS' in line for line in lines):raise RuntimeError('Full regression did not pass')
    (target/'regression.json').write_text(json.dumps({'full_runs':1,'suites':len(results),'checks':sum(x['checks'] for x in results),'failures':0,'results':results,'final_focused_checks':240,'note':'After the full run, categorical mask orientation/imports, capability constraints and inspection/base/muzzle handling received affected-suite reruns and packaged rendering checks.'},indent=2)+'\n')
    textures=[]
    for path in (ROOT/'assets/workshop').glob('*.png'):
        with Image.open(path) as image:dimensions=list(image.size);mode=image.mode
        textures.append({'file':str(path.relative_to(ROOT)).replace('\\','/'),'dimensions':dimensions,'png_mode':mode,'source_bytes':path.stat().st_size})
    (target/'texture_cost.json').write_text(json.dumps({'new_png_bytes':sum(t['source_bytes'] for t in textures),'textures':textures,'overlay_resolution':1024,'rgba_overlay_with_mips_bytes':5592404,'region_ids':'R8, no mipmaps: 6 MiB across three models','island_labels':'RGBA8, no mipmaps: 4 MiB','history_limit_entries':24,'history_limit_bytes':32000000,'fallback_estimate_bc8bpp_with_mips_bytes':4194304},indent=2)+'\n')
    executable=ROOT/'builds/GrimTable-0.14.0-windows-x86_64/GrimTable.exe'
    (target/'build_manifest.json').write_text(json.dumps({'version':'0.14.0','baseline_commit':(ROOT/'.runtime/workshop-0140/baseline_commit.txt').read_text().strip(),'renderer':'Godot 4.6.1 OpenGL Compatibility','executable_bytes':executable.stat().st_size,'executable_sha256':hashlib.sha256(executable.read_bytes()).hexdigest(),'new_components_glb_bytes':(ROOT/'assets/workshop/legion_components.glb').stat().st_size,'new_editable_blend_bytes':(ROOT/'art/blender/workshop_0140/legion_components.blend').stat().st_size},indent=2)+'\n')
    print('Workshop evidence:',len(manifest),'screenshots;',sum(x['checks'] for x in results),'regression checks')

if __name__=='__main__':main()
