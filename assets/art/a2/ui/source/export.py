from pathlib import Path
from PIL import Image
import hashlib,json
p=Path(__file__).resolve().parents[1]
s=p/'source'
names=['panel','button-normal','button-hover','button-pressed','button-disabled','button-primary']
for n in names:
 i=Image.open(s/'extracted'/f'{n}.png').convert('RGBA');i=i.crop(i.getchannel('A').getbbox());i.resize((round(i.width/2),round(i.height/2)),Image.Resampling.NEAREST).save(p/f'{n}.png')
for n,src,size in [('menu-background','menu-generated',(1600,900)),('battle-table','table-generated',(1600,960))]:
 Image.open(s/f'{src}.png').convert('RGBA').resize(size,Image.Resampling.NEAREST).save(p/f'{n}.png')
assets=[]
for f in sorted(p.glob('*.png')):
 i=Image.open(f);d={'file':f.name,'size':list(i.size),'alpha_bbox':list(i.getchannel('A').getbbox()),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'filter':'nearest'}
 if f.stem in names:d.update({'stretch_margin_ltrb':[24]*4 if f.stem=='panel' else [22]*4,'content_margin_ltrb':[24]*4 if f.stem=='panel' else [22,8,22,8],'nine_slice':'stretch both axes; draw_center true'})
 assets.append(d)
meta={'version':'a2-ui-1','generator':'built-in image_gen','prompts':json.loads((s/'prompts.json').read_text(encoding='utf-8')),'style':'REF-005A2-battle and menu, not A3','table_mapping':'1000x600du UV0..1 ONCE; no repeat. No midpoint fake ports.','extraction':'sprite-gen native alpha230 edge0 then alpha bbox crop and0.5nearest downsample. Backgrounds nearest exact-aspect normalization. No procedural drawing.','assets':assets,'source_files':[{'file':str(f.relative_to(p)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in s.glob('*.png')],'qa':'Viewed generator outputs and contact; menu no text/buttons and portrait packets, owl/bee/dolphin nofox. Table no cards/machines/false ports. UI has slight center tonal variation; outside alpha haze removed via sprite-gen.'}
(p/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
c=Image.new('RGBA',(1000,600),(84,139,128,255))
for k,n in enumerate(names):c.alpha_composite(Image.open(p/f'{n}.png'),(20+(k%3)*330,20+(k//3)*300))
c.save(s/'contact.png')
print(json.dumps(assets))

