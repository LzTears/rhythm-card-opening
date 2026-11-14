"""Production normalization only; AI original images are copied without modification.
No engine execution. Preserve alpha; nearest sampling for sprite-size normalization.
"""
from pathlib import Path
from PIL import Image, ImageOps
import json, shutil, hashlib

ROOT = Path(__file__).resolve().parent.parent
GEN = Path('C:/Users/Administrator/.codex/generated_images/01a1ca11-3497-7622-8eea-dba6e4e1bafc')
ITEMS = {
 'ui/menu-background.png': ('e24027c3-32c8-48a4-9d37-95c6586e72a0', (1600,900), 'background'),
 'ui/battle-table.png': ('553eb41d-0845-4960-96db-ab789aef4974', (1600,960), 'background'),
 'ui/menu-logo.png': ('af9879c3-1047-44e1-96e4-b21e4723749f', (2172,724), 'logo'),
 'packs/pack-0.png': ('09d77bdb-7d66-4be7-8d7f-dd3e344d305f', (300,400), 'pack'),
 'packs/pack-1.png': ('645caff3-b9c4-49d7-97df-5fe1dda46aef', (300,400), 'pack'),
 'packs/pack-2.png': ('2ad6bd45-1433-4637-a640-3d7ea94eaf2c', (300,400), 'pack'),
 'packs/pack-3.png': ('9c228cda-df9e-489e-9db5-9d42d516141e', (300,400), 'pack'),
 'packs/pack-4.png': ('db239d5c-8fba-464d-9bc9-ff34937e4578', (300,400), 'pack'),
 'dispensers/down.png': ('f6166439-3130-4262-a647-6b0337784846', (384,320), 'dispenser'),
 'cards/card_back.png': ('b9744b4e-640d-4783-b92d-b98ceece27fb', (512,512), 'cardback'),
}

def produce():
 manifest = {'date':'2026-11-11', 'generator':'OpenAI built-in image_gen, no API CLI',
 'usage':'Project-requested AI-generated original artwork; no third-party downloaded image or trademark used. Not legal certification.',
 'scope':'10 new independent production bitmaps. Existing 70 distinct animal fronts retained; not redrawn.', 'assets':{}}
 for rel,(uid,size,kind) in ITEMS.items():
  src=GEN/f'exec-{uid}.png'
  original=ROOT/'source'/f'{Path(rel).stem}{"-final" if kind=="pack" else ""}-original.png'
  shutil.copy2(src,original)
  im=Image.open(src).convert('RGBA')
  original_size=im.size
  source_bbox=im.getchannel('A').getbbox()
  core_bbox=im.getchannel('A').point(lambda v:255 if v>=128 else 0).getbbox()
  if kind in ('pack','dispenser'):
   # Low-alpha generator speckles outside the subject must not determine its UV.
   # Crop around the visible >=50% alpha silhouette; alpha within it is retained.
   im=im.crop(core_bbox)
  if kind=='dispenser':
   sprite=ImageOps.contain(im,(384,220),Image.Resampling.NEAREST)
   im=Image.new('RGBA',size)
   im.alpha_composite(sprite,((384-sprite.width)//2,280-sprite.height))
  elif kind=='pack':
   # The original art's silhouette ratio is retained. The registered texture is
   # 3:4, with symmetric transparent side padding; never widen the illustration.
   sprite=ImageOps.contain(im,(size[0]-2,size[1]-2),Image.Resampling.NEAREST)
   im=Image.new('RGBA',size)
   im.alpha_composite(sprite,((size[0]-sprite.width)//2,(size[1]-sprite.height)//2))
  elif kind=='logo':
   # Keep native canvas and alpha, matching the preexisting 3:1 Logo slot.
   im=im.resize(size,Image.Resampling.NEAREST)
  else:
   im=im.resize(size,Image.Resampling.LANCZOS if kind=='background' else Image.Resampling.NEAREST)
  dest=ROOT/rel
  dest.parent.mkdir(parents=True,exist_ok=True)
  im.save(dest)
  a=im.getchannel('A')
  manifest['assets'][rel]={'canvas':list(im.size),'alpha_bbox':list(a.getbbox()),
   'source':str(original.relative_to(ROOT)).replace('\\','/'), 'source_native_size':list(original_size),
   'source_alpha_bbox':list(source_bbox), 'source_core_bbox':list(core_bbox),
   'source_core_aspect':(core_bbox[2]-core_bbox[0])/(core_bbox[3]-core_bbox[1]),
   'source_core_3x4_relative_error':((core_bbox[2]-core_bbox[0])/(core_bbox[3]-core_bbox[1]))/.75-1 if kind=='pack' else None,
   'alpha_extrema':list(a.getextrema()),
   'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
   'normalization':'Sprites use aspect-preserving fit; packs have transparent side padding in 3:4 registered canvas. Generated alpha retained inside visible-core crop. No filter pixelation or scanlines.'}
 (ROOT/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 packs={k:v for k,v in manifest['assets'].items() if k.startswith('packs/')}
 (ROOT/'pack_manifest.json').write_text(json.dumps(packs,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(manifest,ensure_ascii=False,indent=2))

if __name__=='__main__': produce()
