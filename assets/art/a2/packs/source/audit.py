from pathlib import Path
from PIL import Image
import hashlib,json
base=Path(__file__).resolve().parents[2]
for folder in ['packs','dispensers']:
 p=base/folder
 assets=[]
 for f in sorted(p.glob('*.png')):
  im=Image.open(f);b=im.getchannel('A').getbbox()
  d={'file':f.name,'size':list(im.size),'alpha_bbox':list(b),'visible_size':[b[2]-b[0],b[3]-b[1]],'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'filter':'nearest'}
  if folder=='packs':
   d.update({'grade':int(f.stem[-1]),'name':['普通','稀有','史诗','传说','远古'][int(f.stem[-1])],'uv_bbox':[b[0]/im.width,b[1]/im.height,b[2]/im.width,b[3]/im.height],'draw_rule':'Uniform fit visible bbox into 60x80du. Never force source width and height independently; source varies <4% from 3:4. Full top/bottom crimp seals included.'})
  else:
   d.update({'facing':'down','mouth_dark_aperture_center_px':[192,244],'mouth_emission_lip_px':[192,272],'draw_rule':'Uniform fit visible bbox into80x64du; visible body80x45.833du, do not stretch into80x64. Rotate sprite for sides, rotate anchor with it. Mouth lip center is emission anchor.'})
  assets.append(d)
 manifest={'version':'a2-production-1','generator':'built-in image_gen','style_reference':'REF-005A2-battle.png only, not A3','prompt':'source/prompt.txt','extraction':'sprite-gen3.15 slice-sheet --chroma-key none --alpha-floor '+('200' if folder=='packs' else '220')+' --alpha-edge0; same-alpha native preservation, no drawing or nonuniform stretch','assets':assets,'qa':{'viewed':True,'limitations':['Model did not hit exact identical silhouette dimensions. Actual alpha bbox and uniform-fit contract recorded.','Generated alpha maximum254 preserved.','Dispenser is wider than80:64 target; fit preserving aspect rather than deform.']}}
 (p/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 print(folder,json.dumps(assets,ensure_ascii=False))

