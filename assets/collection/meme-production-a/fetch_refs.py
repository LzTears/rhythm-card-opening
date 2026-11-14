from pathlib import Path
import urllib.request,re,json,concurrent.futures,html
ROOT=Path(__file__).resolve().parent
ITEMS={
'panda':'https://gengtu.net/memes/panda-head-covering-mouth-sneer-meme/',
'sweat':'https://news.mydrivers.com/1/766/766760.htm',
'broken':'https://www.ithome.com/0/520/321.htm',
'doge':'https://knowyourmeme.com/memes/doge',
'cheems':'https://knowyourmeme.com/memes/cheems',
'happy':'https://knowyourmeme.com/memes/happy-happy-happy-cat',
'pop':'https://knowyourmeme.com/memes/pop-cat',
'huh':'https://knowyourmeme.com/memes/huh-cat',
'banana':'https://knowyourmeme.com/memes/sad-banana-cat',
'apple':'https://knowyourmeme.com/memes/apple-cat',
'vibe':'https://knowyourmeme.com/memes/catjam-vibing-cat',
'nailong':'https://pdan.com.cn/12761.html',
'swole':'https://knowyourmeme.com/memes/swole-doge-vs-cheems',
'bonk':'https://knowyourmeme.com/memes/bonk-cheems',
'drog':'https://knowyourmeme.com/memes/drog-wo-de-dao-dun-cheems-frog',
'oiia':'https://knowyourmeme.com/memes/oo-ee-a-e-a-cat-remixes',
}
def get(u):
 return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read()
def run(item):
 key,url=item
 try:
  raw=get(url).decode('utf8',errors='replace');(ROOT/'references'/f'{key}.html').write_text(raw,encoding='utf8')
  og=re.findall(r'<meta[^>]*(?:property|name)=[\"\']og:image[\"\'][^>]*content=[\"\']([^\"\']+)',raw,re.I)
  imgs=re.findall(r'<img[^>]+(?:src|data-src)=[\"\']([^\"\']+)',raw,re.I)
  urls=list(dict.fromkeys(html.unescape(u) for u in og+imgs if u.startswith('http')))
  result={'key':key,'page':url,'images':urls[:30]}
  if og:
   u=html.unescape(og[0]); data=get(u); f=ROOT/'references'/f'{key}-reference.jpg';f.write_bytes(data);result['reference_file']=f.name
  return result
 except Exception as e:return {'key':key,'page':url,'error':str(e)}
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:results=list(ex.map(run,ITEMS.items()))
 (ROOT/'references/index.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
 for r in results:print(r['key'],r.get('reference_file',r.get('error','NO_OG')),r.get('images',[])[:3])
