from pathlib import Path
from PIL import Image
import json,shutil,re
ROOT=Path(__file__).resolve().parent
GEN=Path('C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c')
BATCHES=[
 ('digimon-001-008','exec-0baf91d5-2664-4b4c-ac9a-fa9f6ab8088b.png',4,2,list(range(1,9)),None),
 ('digimon-009-016','exec-8166e7f0-f84f-4ff7-9f59-f581b2726f9c.png',4,2,list(range(9,17)),None),
 ('digimon-017-022','exec-d9ce6d80-1401-44ec-b030-72f5905dbe0c.png',3,2,list(range(17,23)),None),
 ('digimon-023-029','exec-7fe08271-9bcd-43cd-a81f-733f78387bc5.png',4,2,list(range(23,30)),None),
 ('digimon-030-035','exec-1390d30e-7b12-4787-a30c-1db3d47ce1f3.png',3,2,list(range(30,36)),None),
 ('digimon-036-039','exec-104fbf39-f796-4f4f-a9f0-bb9c3ff21312.png',2,2,list(range(36,40)),605),
 ('digimon-040-045','exec-14e13ea0-2e3f-45d2-88af-6ad0c0262e3c.png',3,2,list(range(40,46)),585),
 ('digimon-046-049','exec-f2cf5bc5-76e0-4c1e-9dc0-47772df422e8.png',2,2,list(range(46,50)),598),
]
def run():
 catalog=ROOT.parents[1]/'docs/concepts/catalogs-v1/digimon-49.md'
 rows={}
 for line in catalog.read_text(encoding='utf8').splitlines():
  if re.match(r'\| DIG-\d',line):
   p=[v.strip() for v in line.split('|')[1:-1]]; rows[p[0]]=dict(name=p[2],english=p[3],form=p[4],directory_name=p[-1])
 records=[]
 for label,file,cols,nrows,ids,split in BATCHES:
  src=ROOT/'sources'/f'{label}.png';shutil.copy2(GEN/file,src); im=Image.open(src)
  ye=[0,split,im.height] if split else [round(y*im.height/nrows) for y in range(nrows+1)]
  for i,num in enumerate(ids):
   x,y=i%cols,i//cols; box=(round(x*im.width/cols)+3,ye[y]+3,round((x+1)*im.width/cols)-3,ye[y+1]-3)
   out=im.crop(box); name=f'DIG-{num:03}';out.save(ROOT/'cards'/f'{name}.png');meta=rows[name]
   records.append(dict(id=name,**meta,art_path=f'res://assets/collection/cards/{name}.png',source=f'sources/{label}.png',source_size=list(im.size),crop_xyxy=list(box),size=list(out.size),alpha=False,method='image_gen character illustration, NOT downloaded official artwork',reference_url=f'https://digimon.net/reference_en/detail.php?directory_name={meta["directory_name"]}',rights='Digimon characters © Akiyoshi Hongo / Toei Animation / BANDAI. AI-generated fan illustration; no commercial license asserted.',layers='flattened character and digital background; no separate subject alpha'))
 (ROOT/'digimon-manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
 print(f'Exported {len(records)} distinct Digimon illustrations')
if __name__=='__main__':run()
