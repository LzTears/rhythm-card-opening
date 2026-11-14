from pathlib import Path
from PIL import Image
import json,hashlib
p=Path(__file__).resolve().parents[1]
out={}
for group in ['packs','dispensers','pack_damage','ui']:
 d=p/group
 m=json.loads((d/'manifest.json').read_text(encoding='utf-8'))
 m['source_png_files']=[{'file':str(f.relative_to(d)).replace('\\','/'),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted((d/'source').glob('*.png'))]
 (d/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
 out[group]=[]
 for f in sorted(d.glob('*.png')):
  i=Image.open(f);i.load();assert i.mode=='RGBA'
  out[group].append({'path':str(f.relative_to(p)).replace('\\','/'),'size':list(i.size),'alpha_bbox':list(i.getchannel('A').getbbox()),'alpha_range':list(i.getchannel('A').getextrema()),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
assert sum(len(a) for a in out.values())==17
data={'version':'a2-production-1','date':'2026-11-09','generator':'built-in image_gen; backend model not separately reported','style_references':['REF-005A2-battle.png','REF-005A2-menu.png'],'processing':'sprite-gen native alpha cleanup/static extraction, nearest mechanical resizing/registration. No procedural drawing. Old assets preserved; no scripts/PRD/GDA modified by this asset task.','groups':out,'group_manifests':{k:k+'/manifest.json' for k in out},'qa':'17PNG actually decoded RGBA, source SHA captured, group art visually reviewed. Shape deviations are disclosed in packs/dispensers contracts; world uniform fit. See README.'}
(p/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('17 RGBA PNG decoded; group/source SHA manifests written.')

