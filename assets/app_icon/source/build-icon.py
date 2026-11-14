from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, json, shutil, struct, io
root=Path(r'C:/Users/Administrator/Desktop/代号1/圆卡旋风/assets/app_icon')
origin=Path(r'C:/Users/Administrator/.codex/generated_images/01a1d7b5-28ef-73f1-abce-2529c1bc63ad/exec-fe120cce-6660-49dd-9c59-942ab880d6ca.png')
master=root/'source/icon-master.png'
shutil.copyfile(origin, master)
(root/'source/.gdignore').write_text('', encoding='utf-8')
im=Image.open(master).convert('RGBA')
sizes=[16,24,32,48,64,128,256]
frames={s:im.resize((s,s), Image.Resampling.LANCZOS) for s in sizes}
frames[256].save(root/'icon.png', format='PNG', compress_level=9)
blobs=[]
for s in sizes:
    b=io.BytesIO(); frames[s].save(b, format='PNG', compress_level=9); blobs.append(b.getvalue())
offset=6+16*len(sizes)
entries=[]
for s,b in zip(sizes,blobs):
    entries.append(struct.pack('<BBBBHHII',s if s<256 else 0,s if s<256 else 0,0,0,1,32,len(b),offset)); offset+=len(b)
(root/'icon.ico').write_bytes(struct.pack('<HHH',0,1,len(sizes))+b''.join(entries)+b''.join(blobs))
# QA board: native-size renderings, composited only for preview.
board=Image.new('RGB',(820,340),(34,30,45)); draw=ImageDraw.Draw(board)
x=18
for s in sizes:
    y=36
    for yy in range(y,y+s,8):
        for xx in range(x,x+s,8):
            color=(69,66,79) if ((xx-x)//8+(yy-y)//8)%2 else (49,46,59)
            draw.rectangle((xx,yy,min(xx+7,x+s-1),min(yy+7,y+s-1)), fill=color)
    board.paste(frames[s],(x,y),frames[s]); draw.text((x,14),str(s)+'px',fill=(240,232,218)); x+=s+24
board.save(root/'source/icon-size-preview.png', compress_level=9)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def info(p): return {'path':str(p.relative_to(root)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':sha(p)}
assert sha(origin)==sha(master)
png=Image.open(root/'icon.png'); assert png.mode=='RGBA' and png.size==(256,256)
assert all(png.getpixel(p)[3]==0 for p in [(0,0),(255,0),(0,255),(255,255)])
ico=Image.open(root/'icon.ico')
assert ico.ico.sizes()=={(s,s) for s in sizes}
for s in sizes:
    assert ico.ico.getimage((s,s)).convert('RGBA').tobytes()==frames[s].tobytes()
refs=[]
for ref in ['assets/art/rhythm_v2/game-logo.png','assets/collection/backs/back_4.png']:
    p=root.parent.parent/ref; assert p.exists(); refs.append({'path':ref,'sha256':sha(p)})
manifest={
  'asset':'节拍开卡应用图标',
  'generation':{'method':'OpenAI imagegen','created_on':'2026-11-14','description':'AI生成的新图：紫金旋涡与红金卡牌，透明背景，无文字。','third_party_ip_added':False,'brand_references':refs},
  'source':dict(info(master),origin_path=str(origin).replace('\\','/'),original_bytes_preserved=True,width=im.width,height=im.height,mode=im.mode),
  'conversion':{'method':'Deterministic format conversion only; no drawing or AI regeneration','resize':'Pillow Image.Resampling.LANCZOS; each frame resized directly from the same source master','alpha':'RGBA preserved; PNG corners verified fully transparent'},
  'outputs':{'png':dict(info(root/'icon.png'),width=256,height=256,mode='RGBA'),'ico':dict(info(root/'icon.ico'),sizes=sizes,bit_depth=32,frame_encoding='PNG RGBA',frames_verified_against_master_resizes=True)},
  'preview':info(root/'source/icon-size-preview.png'),
  'godot':{'source_directory_ignored':True,'texture_import':'Default lossless; importer execution and verification owned by parent task','engine_started_by_asset_task':False}
}
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'png':manifest['outputs']['png'],'ico':manifest['outputs']['ico'],'master':manifest['source'],'preview':manifest['preview']},ensure_ascii=False,indent=2))
