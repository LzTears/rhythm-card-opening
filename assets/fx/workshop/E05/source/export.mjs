// Offline authoring/export only. Uses the locally preserved pixelfx MIT toolkit.
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { loadEffect, renderFrames, contactSheet } from "./pixelfx/tools/lib/fxlib.mjs";
import { encodePNG } from "./pixelfx/tools/lib/png.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2] || join(HERE, "round-preview"));
mkdirSync(out, { recursive: true });
const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
const source = join(HERE, "pixelfx/src/fx/workshop/frost-crystals.js");
const fx = await loadEffect("workshop/frost-crystals", join(HERE, "pixelfx/src/fx"));
const frames = renderFrames(fx, { bg: "dark" });
if (frames.n !== 24 || frames.fps !== 30) throw Error("Expected complete 24-frame @30FPS source");
const W = 128, H = 128, columns = 6, rows = 4, sw = W * columns, sh = H * rows;
const color = new Uint8Array(sw * sh * 4), light = new Uint8Array(sw * sh * 4);
const bounds = [];
let passed = true, maxLight = 0;
for (let f = 0; f < frames.n; f++) {
  const ox = (f % columns) * W, oy = Math.floor(f / columns) * H;
  const record = { frame: f, time: f / 30, color: null, light: null };
  for (const [channel, raw, sheet] of [["color", frames.frames[f].raw, color], ["light", frames.frames[f].light, light]]) {
    let x0 = W, y0 = H, x1 = -1, y1 = -1, count = 0, outer = 0, minRadius = Infinity, maxRadius = 0, white = 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const pixel = raw[y * W + x], r = pixel & 255, g = (pixel >>> 8) & 255, b = (pixel >>> 16) & 255;
      const a = channel === "color" ? (pixel >>> 24) & 255 : (r || g || b ? 255 : 0);
      if (!a) continue;
      const at = ((y + oy) * sw + x + ox) * 4;
      sheet.set([r, g, b, a], at);
      const radius = Math.hypot(x + .5 - 64, y + .5 - 64);
      x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
      count++; minRadius = Math.min(minRadius, radius); maxRadius = Math.max(maxRadius, radius);
      outer += Number(x === 0 || y === 0 || x === W - 1 || y === H - 1);
      white += Number(r > 240 && g > 240 && b > 240);
      if (channel === "light") maxLight = Math.max(maxLight, r, g, b);
    }
    record[channel] = { pixels: count, bbox: count ? [x0, y0, x1 - x0 + 1, y1 - y0 + 1] : null,
      outer_edge_pixels: outer, minimum_radius: count ? minRadius : null, maximum_radius: maxRadius, white_pixels: white };
    if (outer || maxRadius > 64 || (count && minRadius < 12)) passed = false;
  }
  bounds.push(record);
}
const colorPNG = encodePNG(sw, sh, color), lightPNG = encodePNG(sw, sh, light);
writeFileSync(join(out, "crystals-color.png"), colorPNG);
writeFileSync(join(out, "crystals-light.png"), lightPNG);
writeFileSync(join(out, "contact.png"), contactSheet(fx, frames, { max: 24, zoom: 2 }));
copyFileSync(source, join(out, "frost-crystals.js"));
const meta = {
  key: "crystals_E05", source_id: "workshop/frost-crystals#six-chunks-two-stars",
  source_file: "source/pixelfx/src/fx/workshop/frost-crystals.js", source_sha256: sha(readFileSync(source)),
  adaptation: "Original workshop topdown composition using pixelfx painter/facet/glint techniques; 6 baked crystals and 2 stars, no actor or runtime particle nodes.",
  size: [W, H], pivot: [64, 64], floor_pivot: [64, 64], columns, rows, frames: 24, fps: 30,
  source_duration: 23 / 30, sample_end: 23 / 30, duration: 24 / 30, body_radius_px: 64,
  color: "crystals-color.png", light: "crystals-light.png", color_sha256: sha(colorPNG), light_sha256: sha(lightPNG),
  terminal_pixels: { color: bounds[23].color.pixels, light: bounds[23].light.pixels },
  outer_edge_pixels_all_frames: { color: bounds.reduce((n, f) => n + f.color.outer_edge_pixels, 0), light: bounds.reduce((n, f) => n + f.light.outer_edge_pixels, 0) },
  palette: fx.meta.options.palette,
};
writeFileSync(join(out, "crystals.json"), JSON.stringify(meta, null, 2) + "\n");
passed &&= bounds[23].color.pixels === 0 && bounds[23].light.pixels === 0 && maxLight <= 64;
const audit = { passed, scope: "offline pixelfx source/rendered color+light channels, complete frames, true radius and centre clearance", frames: 24, fps: 30,
  body_radius_px: 64, centre_clear_radius_px: 12, maximum_light_channel: maxLight,
  source_sha256: meta.source_sha256, color_sha256: meta.color_sha256, light_sha256: meta.light_sha256, per_frame: bounds };
writeFileSync(join(out, "bounds-audit.json"), JSON.stringify(audit, null, 2) + "\n");
console.log(JSON.stringify({ passed, frames: 24, fps: 30, terminal_pixels: meta.terminal_pixels, maximum_light_channel: maxLight, out }));
if (!passed) process.exitCode = 1;
