// Reproduce with Node 18+ and a local pixelfx checkout. No runtime JS dependency in Godot.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const root = process.env.PIXELFX_ROOT ?? "C:/Users/Administrator/.codex/vendor_imports/pixelfx-main";
const { loadEffect, renderFrames, spriteSheet, contactSheet } = await import(pathToFileURL(join(root,"tools/lib/fxlib.mjs")).href);
const spec = JSON.parse(readFileSync(join(here,"source.json"),"utf8"));
const fx = await loadEffect("impacts/hit-spark");
const frames = renderFrames(fx,{fps:24,actor:false,options:spec.options});
const sheet = spriteSheet(fx,frames,"heavy_hit");
writeFileSync(join(here,"heavy_hit.png"),sheet.png);
writeFileSync(join(here,"heavy_hit.json"),JSON.stringify(sheet.json,null,2)+"\n");
writeFileSync(join(here,"heavy_hit_contact.png"),contactSheet(fx,frames,{max:400}));
console.log("Exported heavy_hit: 13 frames, 136x80, pivot 44,64.");
