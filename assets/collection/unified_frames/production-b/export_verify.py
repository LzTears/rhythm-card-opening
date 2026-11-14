from pathlib import Path
from PIL import Image
from sprite_gen.util.resample import resize_cell
import sys,json,hashlib
import numpy as np
d=Path('assets/collection/unified_frames'); k=sys.argv[1]
source=d/'production-b'/'sources'/(k+'-native.png')
im=Image.open(source).convert('RGBA'); out=resize_cell(im,(768,1024)); final=d/(k+'.png');out.save(final)
a=np.asarray(out)[...,3]
def area(b):
 x0,y0,x1,y1=b;r=a[int(y0*1024):int(y1*1024),int(x0*768):int(x1*768)]
 return {'min':int(r.min()),'max':int(r.max()),'alpha_zero_fraction':float((r==0).mean())}
r={'id':k,'native_size':list(im.size),'size':list(out.size),'sha256':hashlib.sha256(final.read_bytes()).hexdigest(),'window':area((.08,.12,.92,.67)),'bottom_paper':area((.25,.80,.75,.95)),'top_paper':area((.4,.025,.6,.06)),'corners':[int(a[0,0]),int(a[0,-1]),int(a[-1,0]),int(a[-1,-1])]}
(d/'production-b'/(k+'-qa.json')).write_text(json.dumps(r,indent=2),encoding='utf-8');print(json.dumps(r))

