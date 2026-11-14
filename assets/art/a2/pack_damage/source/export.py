from pathlib import Path
from PIL import Image
from sprite_gen.frames.alpha_floor import clear_haze
import hashlib,json
p=Path(__file__).resolve().parents[1]
i=Image.open(p/'source/generated-atlas.png').convert('RGBA')
i,report=clear_haze(i,floor=200,edge=0)
i.save(p/'source/alpha-cleaned.png')
(p/'source/alpha-cleanup.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assets=[]
preview=Image.new('RGBA',(768,384),(84,139,128,255))
base=Image.open(p.parent/'packs/pack-0.png').convert('RGBA')
for n in range(3):
 # Static atlas registration: identical source field per cell, identical destination full canvas.
 box=(n*512+32,160,n*512+480,856)
 field=i.crop(box).resize((240,320),Image.Resampling.NEAREST)
 out=Image.new('RGBA',(256,384))
 out.alpha_composite(field,(8,32))
 f=p/f'damage-{n+1}.png';out.save(f)
 a=out.getchannel('A')
 center=a.crop((72,112,184,272))
 assert center.getbbox() is None, 'central badge must remain completely transparent'
 d={'stage':n+1,'file':f.name,'size':[256,384],'alpha_bbox':list(a.getbbox()),'registered_body_box':[8,32,248,352],'source_cell_crop':list(box),'central_clear_rect':[72,112,184,272],'central_alpha_max':center.getextrema()[1],'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
 assets.append(d)
 comp=base.copy();comp.alpha_composite(out);preview.alpha_composite(comp,(n*256,0))
preview.save(p/'source/registered-preview.png')
meta={'version':'a2-damage-1','generator':'built-in image_gen','prompt':'source/prompt.txt','style_reference':'A2 pack-0.png','canvas_registration':'All stages256x384, same fieldcrop and destination body8,32..248,352. Do NOT bbox-crop these overlays independently. Sample same full UV as base, multiply overlay alpha by basealpha in shader.','extraction':'sprite-gen native clear_haze floor200 edge0; static equal-cell crops+nearest registration only, no painted marks. Overlay coordinate registration resizes field, BASE packs never stretched.','assets':assets,'qa':'Actual generated overlay and base-composite preview viewed. Center alpha0 assert; marks at top/bottom seals and side edges; stage intensity differs. At runtime basealpha clipping mandatory; source has faint outline at seals, no centerfill.'}
(p/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(assets))

