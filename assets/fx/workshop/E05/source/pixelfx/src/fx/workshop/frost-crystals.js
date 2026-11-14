// Faceted ice and glint techniques adapted from Sprite Fusion's open-source ice/pickup effects,
// https://www.spritefusion.com/pixel-art-vfx/ice — MIT, Copyright (c) 2026 Hugo Duprez.
// Original workshop composition: six discrete chips and two stars, with an empty aiming centre.
import { fit, smooth, clamp, sparkle } from "../../core/index.js";

export const meta = {
  name: "Workshop frost crystals",
  desc: "Six large cyan ice facets punch outward around an empty centre; two cold contact stars snap on, then the chips drift and shrink away.",
  tags: ["ice", "crystal", "workshop", "topdown", "one-shot"],
  size: [128, 128], origin: [64, 64], duration: 23 / 30, fps: 30,
  loop: false, bg: "dark",
  options: { palette: ["#123e61", "#176796", "#198bc0", "#31b5df", "#73dbf0", "#b7f2f8", "#e9feff", "#ffffff"], seed: 51 },
};

const SITES = [
  [-26, -25, 23, 15, -.55, 0], [13, -35, 29, 18, .60, .017],
  [36, -10, 22, 15, 1.05, .033], [27, 27, 19, 13, -.40, .017],
  [-10, 35, 26, 16, .26, .050], [-36, 13, 20, 14, -.80, .033],
];

function chip(p, x, y, h, w, angle, C, hot) {
  const c = Math.cos(angle), s = Math.sin(angle);
  const P = (a, b) => [x + a * c - b * s, y + a * s + b * c];
  const a = P(-w * .04, -h * .52), b = P(w * .48, -h * .22), d = P(w * .38, h * .32);
  const e = P(-w * .12, h * .50), f = P(-w * .48, h * .16), g = P(-w * .43, -h * .27);
  const ridge = P(-w * .06, -h * .04);
  const outline = [a, b, d, e, f, g].map(([px, py]) => {
    const length = Math.hypot(px - x, py - y) || 1;
    return [px + (px - x) / length, py + (py - y) / length];
  });
  p.poly(outline, C[0]);
  p.poly([a, ridge, e, f, g], hot ? C[6] : C[3]);
  p.poly([a, b, d, e, ridge], C[2]);
  p.poly([a, g, ridge, b], hot ? C[7] : C[5]);
  p.line(...a, ...ridge, C[6]);
  p.line(...ridge, ...e, C[4]);
  p.line(...b, ...d, C[1]);
  p.glow(x, y, Math.max(4, w * .70), C[4], hot ? .13 : .07);
}

export function draw(p, t, o) {
  if (t < 0 || t >= meta.duration) return;
  const C = fit(o.palette, 8);
  for (let i = 0; i < SITES.length; i++) {
    const [sx, sy, height, width, angle, delay] = SITES[i], u = t - delay;
    if (u < 0 || u >= .70) continue;
    const grow = .55 + .45 * (1 - Math.pow(1 - clamp(u / .09), 4));
    const spread = .72 + .28 * (1 - Math.pow(1 - clamp(u / .18), 4));
    const melt = 1 - smooth(.36 - i * .006, .69 - i * .004, u), scale = grow * melt;
    if (scale < .06) continue;
    const drift = smooth(.12, .58, u), radial = 1 + drift * .035;
    const tumble = Math.round(drift * 4) / 4 * (i % 2 ? .17 : -.14);
    chip(p, sx * spread * radial, sy * spread * radial + drift * (i % 2 ? 2 : 3),
      height * scale, width * scale, angle + tumble, C, u < .034);
  }
  for (const [x, y, start, arm] of [[-29, 34, 0, 6], [37, 24, .067, 5]]) {
    const u = t - start;
    if (u < 0 || u > .36) continue;
    const strength = (1 - smooth(.06, .36, u));
    sparkle(p, x, y, arm * strength, C[6], C[3], .06 * strength);
  }
}
