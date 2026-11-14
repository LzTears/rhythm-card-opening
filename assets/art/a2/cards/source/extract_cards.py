"""Static alpha extraction only: sprite-gen cleanup and contain fit, no drawing."""
from pathlib import Path
import json, shutil, subprocess, sys, hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
SRC=ROOT/'source'
CLI=Path('C:/Users/Administrator/.codex/skills/sprite-gen/.venv/Scripts/sprite-gen.exe')

def extract(family, raw):
    dest=SRC/f'{family}-raw.png'
    if Path(raw).resolve()!=dest.resolve(): shutil.copy2(raw,dest)
    im=Image.open(dest).convert('RGBA'); w,h=im.size
    assert w*2==h*3, (w,h)
    # Empty sixth cell is intentionally excluded; no pixels are repainted.
    for name,box,grid,names in [('top',(0,0,w,h//2),'3x1','0,1,2'),('bottom',(0,h//2,w*2//3,h),'2x1','3,4')]:
        sheet=SRC/f'{family}-{name}.png'; im.crop(box).save(sheet)
        out=SRC/f'{family}-{name}-extracted';out.mkdir(exist_ok=True)
        subprocess.run([str(CLI),'slice-sheet','--sheet',str(sheet),'--out-dir',str(out),'--chroma-key','none','--alpha-floor','64','--alpha-edge','0','--grid',grid,'--names',names,'--prefix',f'{family}-','--cell-width','512','--cell-height','512','--baseline-y','486','--target-height','460','--fit','contain'],check=True)
        for p in out.glob(f'{family}-[0-4].png'): shutil.copy2(p,ROOT/p.name)
    sheet=Image.new('RGBA',(512*5,512))
    for n in range(5): sheet.alpha_composite(Image.open(ROOT/f'{family}-{n}.png'),(n*512,0))
    sheet.save(SRC/f'{family}-contact.png')

if __name__=='__main__': extract(sys.argv[1],sys.argv[2])
