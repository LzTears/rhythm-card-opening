"""Deterministic atlas crop/export; drawings come exclusively from image_gen."""
from pathlib import Path
from PIL import Image
import json, shutil
ROOT=Path(__file__).resolve().parent
GEN=Path('C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c')
BATCHES=[
 ('galaxy-001-008','exec-a51a4dbc-9e0b-4d45-84c9-144b85aee8d8.png',4,2,list(range(1,9))),
 ('galaxy-009-016','exec-52fb4ccf-0b56-4dab-8bda-3a0b98120c1b.png',4,2,list(range(9,17))),
 ('galaxy-017-022','exec-eff8a9f4-99a3-49e9-b70b-bd264b549b4d.png',3,2,list(range(17,23))),
 ('galaxy-023-029','exec-196aecd9-923b-449d-b8c0-ff0928338cdf.png',4,2,list(range(23,30))),
 ('galaxy-030-035','exec-bacb0824-b297-45b2-b006-f32b2eae8a97.png',3,2,list(range(30,36))),
 ('galaxy-036-039','exec-2b4b5f36-4894-4706-a657-63bc4a73a688.png',2,2,list(range(36,40))),
 ('galaxy-040-045','exec-c8bd4b28-6c18-40ea-a1a1-a49fd012850e.png',3,2,list(range(40,46))),
 ('galaxy-046-049','exec-c1f0d5bc-8af1-4877-8bf7-e14ff10599ee.png',2,2,list(range(46,50))),
]
def build():
 records=[]
 for label,filename,cols,rows,ids in BATCHES:
  dest=ROOT/'sources'/f'{label}.png'; shutil.copy2(GEN/filename,dest)
  im=Image.open(dest)
  for i,number in enumerate(ids):
   x,y=i%cols,i//cols
   row_edges={'galaxy-030-035':[0,600,im.height],'galaxy-046-049':[0,590,im.height]}.get(label,[round(v*im.height/rows) for v in range(rows+1)])
   box=(round(x*im.width/cols)+2,row_edges[y]+2,round((x+1)*im.width/cols)-2,row_edges[y+1]-2)
   out=im.crop(box); name=f'GAL-{number:03}'
   out.save(ROOT/'cards'/f'{name}.png')
   records.append(dict(id=name,art_path=f'res://assets/collection/cards/{name}.png',source=f'sources/{label}.png',source_size=list(im.size),crop_xyxy=list(box),size=list(out.size),alpha=False,method='image_gen independent illustration atlas, deterministic cell crop',layers='flattened illustration; frame, typography and holo are runtime layers'))
 (ROOT/'galaxy-manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
 print(f'Exported {len(records)} distinct galaxy illustrations')
if __name__=='__main__': build()
