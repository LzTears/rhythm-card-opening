// Run pixelfx's unchanged tools/check.mjs on six project recipes in a temporary checkout.
import {copyFileSync,cpSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
const vendor='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const here=dirname(fileURLToPath(import.meta.url));
const qa=resolve(process.argv[2]??'C:/Users/Administrator/.codex/tmp/secondary-hierarchy','check-workspace');
for(const dir of ['src/fx/secondary','tools/lib'])mkdirSync(resolve(qa,dir),{recursive:true});
cpSync(resolve(vendor,'src/core'),resolve(qa,'src/core'),{recursive:true});
for(const file of ['tools/check.mjs','tools/lib/fxlib.mjs','tools/lib/png.mjs','package.json'])copyFileSync(resolve(vendor,file),resolve(qa,file));
const recipeURL=pathToFileURL(resolve(here,'secondary-rings.mjs')).href;
for(const e of ['E01','E02','E05'])for(const mode of ['ripple','echo']) {
  const content=`import { recipe } from ${JSON.stringify(recipeURL)};\nconst fx=recipe(${JSON.stringify(e)},${JSON.stringify(mode)},3);\nexport const meta=fx.meta; export const draw=fx.draw;\n`;
  writeFileSync(resolve(qa,'src/fx/secondary',`${mode}-${e}.js`),content);
}
const result=spawnSync(process.execPath,['tools/check.mjs','secondary'],{cwd:qa,encoding:'utf8',windowsHide:true});
process.stdout.write(result.stdout??'');process.stderr.write(result.stderr??'');
writeFileSync(resolve(qa,'result.txt'),(result.stdout??'')+(result.stderr??''));
process.exit(result.status??1);
