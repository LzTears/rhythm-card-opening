from pathlib import Path
from PIL import Image
import numpy as np, json, shutil
from sprite_gen.frames.alpha_floor import clear_haze
ROOT=Path(__file__).resolve().parent
GEN=Path('C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c')
FILES=['exec-d65e1dbb-b7fe-4f43-8f77-899afd1d53d7.png','exec-60ab117f-838a-4470-a7da-63144de1db7d.png','exec-08e4598b-df73-4d3c-bc3f-6bb647a671c5.png','exec-34809e4e-f51a-4d20-a132-8519c2020d83.png','exec-1f653635-51ab-44d4-9437-a19d33e15a3e.png']
def run():
 (ROOT/'frames').mkdir(exist_ok=True)
 records=[]
 for grade,file in enumerate(FILES):
  src=ROOT/'sources'/f'frame-grade-{grade}.png'; shutil.copy2(GEN/file,src)
  im=Image.open(src).convert('RGBA'); im,cleanup=clear_haze(im,floor=64,edge=2); arr=np.asarray(im).copy()
  # Geometry fitting only: nine-patch resampling preserves actual generated frame art.
  a=arr[:,:,3]; cy,cx=im.height//2,im.width//2
  ys=np.where(a[:,cx]<64)[0]; ys=ys[(ys>im.height*.05)&(ys<im.height*.85)]
  xs=np.where(a[cy,:]<64)[0]; xs=xs[(xs>im.width*.02)&(xs<im.width*.98)]
  ends=[int(ys.max()+1)]
  for q in [.25,.75]:
   qys=np.where(a[:,int(im.width*q)]<64)[0]; qys=qys[(qys>im.height*.2)&(qys<im.height*.85)]
   ends.append(int(qys.max()+1))
  sx=[0,int(xs.min()),int(xs.max()+1),im.width]; sy=[0,int(ys.min()),max(ends),im.height]
  dx=[0,36,732,768]; dy=[0,86,760,1024]
  out=Image.new('RGBA',(768,1024))
  for y in range(3):
   for x in range(3):
    tile=im.crop((sx[x],sy[y],sx[x+1],sy[y+1])).resize((dx[x+1]-dx[x],dy[y+1]-dy[y]),Image.Resampling.LANCZOS)
    out.paste(tile,(dx[x],dy[y]))
  out.save(ROOT/'frames'/f'grade_{grade}.png')
  (ROOT/'frames'/f'grade_{grade}-alpha-cleanup.json').write_text(json.dumps(cleanup,indent=2),encoding='utf8')
  records.append(dict(grade=grade,source=str(src.relative_to(ROOT)),native_size=list(im.size),size=[768,1024],source_grid_x=sx,source_grid_y=sy,destination_grid_x=dx,destination_grid_y=dy,method='deterministic nine-patch geometry normalization of generated frame; native alpha retained',window_center_alpha=int(np.asarray(out)[400,384,3])))
 (ROOT/'frames'/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf8')
 print(records)
if __name__=='__main__':run()
