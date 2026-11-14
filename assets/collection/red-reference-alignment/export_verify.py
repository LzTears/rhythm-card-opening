from PIL import Image
from sprite_gen.util.resample import resize_cell
from pathlib import Path
import json, hashlib
import numpy as np
d=Path('assets/collection/red-reference-alignment')
report={}
for k in ['galaxy','digimon']:
    source=d/'sources'/('frame_'+k+'-native.png')
    im=Image.open(source).convert('RGBA')
    out=resize_cell(im,(768,1024))
    final=d/('frame_'+k+'.png')
    out.save(final)
    a=np.asarray(out)[...,3]
    def region(box):
        x0,y0,x1,y1=box
        r=a[int(y0*1024):int(y1*1024),int(x0*768):int(x1*768)]
        return {'min':int(r.min()),'max':int(r.max()),'zero_fraction':float((r==0).mean()),'opaque_fraction':float((r==255).mean())}
    report[k]={'native_size':list(im.size),'final_size':list(out.size),'alpha_extrema':list(out.getchannel('A').getextrema()),'window_interior':region((.08,.12,.92,.67)),'bottom_paper_interior':region((.2,.8,.8,.95)),'top_paper_interior':region((.4,.025,.6,.06)),'corner_alpha':[int(a[0,0]),int(a[0,-1]),int(a[-1,0]),int(a[-1,-1])],'final_sha256':hashlib.sha256(final.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
(d/'alpha-qa.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))

