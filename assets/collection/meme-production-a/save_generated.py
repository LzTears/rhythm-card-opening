from pathlib import Path
from PIL import Image
import shutil,json,hashlib,sys
ROOT=Path(__file__).resolve().parent
GEN=Path('C:/Users/Administrator/.codex/generated_images/01a1d076-8038-7562-b19d-16badf5a618c')
def save(number,file):
 name=f'MEM-{int(number):03}';src=GEN/file;dst=ROOT/'sources'/f'{name}.png';shutil.copy2(src,dst);shutil.copy2(src,ROOT.parent/'cards'/f'{name}.png')
 path=ROOT/'manifest.json';rows=json.loads(path.read_text(encoding='utf8')) if path.exists() else []
 rows=[r for r in rows if r['id']!=name];im=Image.open(src)
 rows.append(dict(id=name,art_path=f'res://assets/collection/cards/{name}.png',source=f'meme-production-a/sources/{name}.png',original_generated_path=str(src),native_size=list(im.size),output_size=list(im.size),mode=im.mode,sha256=hashlib.sha256(src.read_bytes()).hexdigest(),method='one built-in image_gen call per independent illustration; unmodified output copy',qa='Viewed generated image; no readable text/frame/watermark; full principal silhouette. Safety margin judged visually, not alpha segmentation.'))
 path.write_text(json.dumps(sorted(rows,key=lambda r:r['id']),ensure_ascii=False,indent=2),encoding='utf8');print(name,im.size)
if __name__=='__main__':save(*sys.argv[1:])
