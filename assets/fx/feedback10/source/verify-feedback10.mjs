import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=join(dirname(fileURLToPath(import.meta.url)),'..');
const manifestPath=join(root,'manifest.json');
const manifest=JSON.parse(readFileSync(manifestPath,'utf8'));
let total=0;
for(const [key,info] of Object.entries(manifest.effects)){
 const data=JSON.parse(readFileSync(join(root,key+'.json'),'utf8'));
 const meta=data.meta.pixelfx;
 if(meta.frames!==info.frame_count||meta.fps!==30||meta.loop!==false||!info.ending_empty)throw new Error('metadata mismatch: '+key);
 const adapted=join(root,'source/adapted',info.source_id+'.js');
 const source=existsSync(adapted)?adapted:join(root,'source/original/fx',info.source_id+'.js');
 info.source_sha256=createHash('sha256').update(readFileSync(source)).digest('hex');
 info.png_sha256=createHash('sha256').update(readFileSync(join(root,key+'.png'))).digest('hex');
 info.previews=Array.from({length:manifest.round},(_,i)=>'res://verification/feedback10/art/round'+(i+1)+'/'+key+'/contact.png');
 total+=meta.frames;
}
writeFileSync(manifestPath,JSON.stringify(manifest,null,2));
console.log(JSON.stringify({sheets:Object.keys(manifest.effects).length,frames:total,round:manifest.round,license:manifest.license}));
