// Project-authored 16px gold coin. MIT pixelfx PNG encoder only; no generated artwork.
import {writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url));
const root=process.env.PIXELFX_ROOT??'C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const {encodePNG}=await import(pathToFileURL(join(root,'tools/lib/png.mjs')).href);
const rows=['................','.....oooooo.....','...ooyyyyyyoo...','..oyywwyyyyyyo..','..oywyyyyyyyyo..','.oywyoooyyyyyyo.','.oyyyoyyoyyyyyo.','.oyyyoyyoyyyyyo.','.oyyyoyyoyyyyyo.','.oyyyoyyoyyyyyo.','.oyyyyoooyyyyyo.','..oyyyyyyyyyo...','..obyyyyyyybo...','...oobbbboo.....','.....oooo.......','................'];
const colors={o:[82,48,33,255],b:[183,119,43,255],y:[246,190,66,255],w:[255,244,180,255]};
const rgba=new Uint8Array(16*16*4);
rows.forEach((row,y)=>[...row].forEach((c,x)=>{if(colors[c])rgba.set(colors[c],(y*16+x)*4)}));
writeFileSync(join(here,'coin-icon.png'),encodePNG(16,16,rgba));
console.log('Wrote project-authored 16x16 coin icon');
