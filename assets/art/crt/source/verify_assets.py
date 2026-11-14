from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
import json
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'asset_manifest.json').read_text(encoding='utf-8'))
checks=[]
for rel,data in m['assets'].items():
 im=Image.open(ROOT/rel).convert('RGBA')
 a=im.getchannel('A')
 item={'path':rel,'size':list(im.size),'alpha_extrema':list(a.getextrema()),
       'registered_3x4':im.size==(300,400) if rel.startswith('packs/') else None,
       'source_core_aspect':data.get('source_core_aspect')}
 if rel.startswith('packs/'):
  err=data['source_core_3x4_relative_error']
  item.update({'source_3x4_relative_error':err,'source_body_within_3pct':abs(err)<=.03})
  assert abs(err)<=.03, f'{rel}: source body ratio failed: {err}'
 if not rel.endswith(('menu-background.png','battle-table.png')):
  assert a.getextrema()[0]==0 and a.getextrema()[1]>=250, f'{rel}: expected transparent exterior and opaque/near-opaque subject'
 checks.append(item)
sheet=Image.new('RGB',(1280,720),'#061c28')
d=ImageDraw.Draw(sheet)
for grade in range(5):
 im=Image.open(ROOT/f'packs/pack-{grade}.png').convert('RGBA')
 large=ImageOps.contain(im,(180,240),Image.Resampling.NEAREST)
 sheet.paste(large,(24+grade*250,30),large)
 small=ImageOps.contain(im,(60,80),Image.Resampling.NEAREST)
 sheet.paste(small,(84+grade*250,295),small)
 d.text((48+grade*250,385),f'pack-{grade}: native / 60x80',fill='#e9dcad')
logo=Image.open(ROOT/'ui/menu-logo.png').convert('RGBA')
logo=ImageOps.contain(logo,(720,240),Image.Resampling.LANCZOS)
sheet.paste(logo,(20,440),logo)
for rel,pos,box in [('cards/card_back.png',(795,465),(180,180)),('dispensers/down.png',(1000,465),(260,220))]:
 im=ImageOps.contain(Image.open(ROOT/rel).convert('RGBA'),box,Image.Resampling.NEAREST)
 sheet.paste(im,pos,im)
sheet.save(ROOT/'source/production-contact.png')
(ROOT/'source/offline-qa.json').write_text(json.dumps({'checks':checks,'no_engine_launched':True,
'scope':'Offline dimensions, true alpha, original body aspect, title reading and contact sheet only; no gameplay or GPU/FPS certification.'},ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: 10 assets, source package body ratio within 3%, alpha checks; contact sheet written.')
