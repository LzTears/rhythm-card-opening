// Rebuild the selected unmodified pixelfx one-shot with Node 18+; no runtime JS needed.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const here=dirname(fileURLToPath(import.meta.url));
const root=process.env.PIXELFX_ROOT??"C:/Users/Administrator/.codex/vendor_imports/pixelfx-main";
const {loadEffect,renderFrames,spriteSheet,contactSheet}=await import(pathToFileURL(join(root,"tools/lib/fxlib.mjs")).href);
const fx=await loadEffect("impacts/crit-hit");
const frames=renderFrames(fx,{fps:30,actor:false});
const sheet=spriteSheet(fx,frames,"crit-hit");
writeFileSync(join(here,"crit-hit.png"),sheet.png);
writeFileSync(join(here,"crit-hit.json"),JSON.stringify(sheet.json,null,1)+"\n");
writeFileSync(join(here,"crit-hit-contact.png"),contactSheet(fx,frames,{max:28}));
console.log("Exported selected crit-hit: 28 frames 216x136, pivot 84,106, 5 columns, 6 rows.");
