from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urljoin
import urllib.request,json,concurrent.futures
from PIL import Image,ImageOps,ImageDraw
ROOT=Path(__file__).resolve().parent
class Parser(HTMLParser):
 def __init__(self):super().__init__();self.imgs=[]
 def handle_starttag(self,t,a):
  if t=='img':
   d=dict(a)
   for k in ['data-original','data-src','real_src','src']:
    if d.get(k) and not 'grey.jpg' in d[k]:self.imgs.append(d[k]);break
def get(u):return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read()
PAGES={'cats':'https://www.thepaper.cn/newsDetail_forward_27024899','dogs':'https://finance.sina.com.cn/tech/2021-07-19/doc-ikqciyzk6358187.shtml','pandas':'https://www.gamersky.com/zl/201901/1147934.shtml'}
def run(item):
 key,u=item
 try:
  raw=get(u).decode('utf8',errors='replace');p=Parser();p.feed(raw);results=[]
  for i,url in enumerate(p.imgs):
   url=urljoin(u,url)
   if not any(x in url for x in ['imagepphcloud','sinaimg','gamersky.com']):continue
   try:
    b=get(url);file=ROOT/'references'/f'{key}-{i:02}.png';file.write_bytes(b)
    im=Image.open(file)
    if im.width<80 or im.height<80:continue
    results.append({'file':file.name,'url':url,'size':list(im.size),'page':u})
   except:pass
  return results
 except Exception as e:return [{'error':str(e),'page':u}]
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:groups=list(ex.map(run,PAGES.items()))
 records=sum(groups,[]);(ROOT/'references/media-index.json').write_text(json.dumps(records,indent=2),encoding='utf8')
 fs=[ROOT/'references'/r['file'] for r in records if 'file' in r]
 out=Image.new('RGB',(1200,((len(fs)+5)//6)*190),'#eeeeee');draw=ImageDraw.Draw(out)
 for i,f in enumerate(fs):
  im=Image.open(f).convert('RGB');out.paste(ImageOps.contain(im,(190,160)),((i%6)*200,(i//6)*190));draw.text(((i%6)*200,(i//6)*190+163),f.name,fill='black')
 out.save(ROOT/'references/media-contact.jpg');print('media references',len(fs))
