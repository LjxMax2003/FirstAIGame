// 守艺人·百工夜行 —— SVG 生成库
// 所有素材用同一套调色板与几何约定，保证 48px 剪影可读、风格统一。

export const P = {
  night: '#0F1B2D',
  nightDeep: '#08111E',
  ink: '#1A1A1A',
  inkSoft: '#2B2F3A',
  cinnabar: '#C53B2E',
  cinnabarDeep: '#8E2A20',
  lantern: '#F2A03D',
  amber: '#E8B04B',
  gold: '#D9A441',
  goldDeep: '#A8781F',
  teal: '#3E7C74',
  tealDeep: '#24524C',
  cream: '#F4E8D0',
  creamDim: '#D6C4A2',
  gray: '#6B7A8F',
  ash: '#495468',
  wood: '#5A3B25',
  woodDeep: '#3B2617',
  cyan: '#B8F6FF',
};

// 线性渐变默认竖向（顶亮底暗），符合木版/纸张的明暗语言
export function lg(id, stops, attrs = '') {
  const s = stops
    .map(([o, c, op]) => `<stop offset="${o}" stop-color="${c}"${op == null ? '' : ` stop-opacity="${op}"`}/>`)
    .join('');
  const a = attrs || 'x1="0" y1="0" x2="0" y2="1"';
  return `<linearGradient id="${id}" ${a}>${s}</linearGradient>`;
}

// 径向渐变一律用 userSpaceOnUse：光晕的 cx/cy/r 全部按画布像素给，
// 默认的 objectBoundingBox 单位会把它们当成比例值（>1 直接画到框外，等于画不出来）。
export function rg(id, stops, attrs = '') {
  const s = stops
    .map(([o, c, op]) => `<stop offset="${o}" stop-color="${c}"${op == null ? '' : ` stop-opacity="${op}"`}/>`)
    .join('');
  return `<radialGradient id="${id}" gradientUnits="userSpaceOnUse" ${attrs}>${s}</radialGradient>`;
}

export function doc(w, h, body, defs = '') {
  const d = defs ? `<defs>${defs}</defs>\n  ` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">\n  ${d}${body.trim()}\n</svg>\n`;
}

// 落地接触阴影：所有站立素材共用，保持同一透明度语言
export function ground(cx, cy, rx, ry, op = 0.35) {
  return `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${P.nightDeep}" opacity="${op}"/>`;
}

// 光晕：只用一盏暖光强调，不铺满
export function glow(id, cx, cy, r, col, inner = 0.85) {
  return rg(id, [[0, col, inner], [0.55, col, inner * 0.35], [1, col, 0]], ` cx="${cx}" cy="${cy}" r="${r}"`);
}

export function mulberry(seed) {
  let a = seed | 0;
  return function () {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 撕纸边：不规则多边形，用来做纸团/墨团/云头
export function blobPath(cx, cy, r, n, seed, wob = 0.22) {
  const rand = mulberry(seed);
  const pts = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const rr = r * (1 - wob / 2 + wob * rand());
    pts.push([(cx + Math.cos(a) * rr).toFixed(1), (cy + Math.sin(a) * rr).toFixed(1)]);
  }
  return 'M' + pts.map((p) => p.join(' ')).join('L') + 'Z';
}

// 宣纸纤维噪点
export function specks(w, h, n, seed, col, opMax = 0.14, rMax = 1.2) {
  const rand = mulberry(seed);
  let s = '';
  for (let i = 0; i < n; i++) {
    const x = (rand() * w).toFixed(1);
    const y = (rand() * h).toFixed(1);
    const r = (0.25 + rand() * rMax).toFixed(2);
    const o = ((0.3 + rand() * 0.7) * opMax).toFixed(2);
    s += `<circle cx="${x}" cy="${y}" r="${r}" fill="${col}" opacity="${o}"/>`;
  }
  return s;
}

// 短排线：木版水印的明暗处理
export function hatch(x, y, w, h, gap, col, op = 0.18, thick = 1) {
  let s = '';
  for (let i = 0; i * gap < h; i++) {
    const yy = y + i * gap;
    s += `<rect x="${x}" y="${yy.toFixed(1)}" width="${w}" height="${thick}" fill="${col}" opacity="${op}"/>`;
  }
  return s;
}

// 一串灯笼（背景/招牌/灯柱共用）
export function lanternString(x1, y1, x2, y2, count, seed, scale = 1) {
  const rand = mulberry(seed);
  let s = '';
  for (let i = 0; i < count; i++) {
    const t = count === 1 ? 0.5 : i / (count - 1);
    const x = x1 + (x2 - x1) * t;
    const sag = Math.sin(t * Math.PI) * (10 + rand() * 6);
    const y = y1 + (y2 - y1) * t + sag;
    const r = (3.4 + rand() * 1.4) * scale;
    const col = i % 3 === 0 ? P.cinnabar : i % 3 === 1 ? P.lantern : P.amber;
    s += `<line x1="${x.toFixed(1)}" y1="${(y - r).toFixed(1)}" x2="${x.toFixed(1)}" y2="${y.toFixed(1)}" stroke="${P.woodDeep}" stroke-width="0.8"/>`;
    s += `<g transform="translate(${x.toFixed(1)} ${y.toFixed(1)})">
      <ellipse rx="${r.toFixed(1)}" ry="${(r * 1.25).toFixed(1)}" fill="${col}" opacity="0.9"/>
      <ellipse rx="${(r * 0.5).toFixed(1)}" ry="${(r * 0.8).toFixed(1)}" fill="${P.cream}" opacity="0.35"/>
      <rect x="${(-r * 0.5).toFixed(1)}" y="${(-r * 1.4).toFixed(1)}" width="${(r).toFixed(1)}" height="${(r * 0.35).toFixed(1)}" fill="${P.gold}"/>
    </g>`;
  }
  s += `<path d="M${x1} ${y1} Q${((x1 + x2) / 2).toFixed(1)} ${((y1 + y2) / 2 + 14).toFixed(1)} ${x2} ${y2}" fill="none" stroke="${P.woodDeep}" stroke-width="1"/>`;
  return s;
}

// 一颗四角星光
export function star4(cx, cy, r, col, op = 1) {  const t = r * 0.28;
  return `<path d="M${cx} ${(cy - r).toFixed(1)}L${(cx + t).toFixed(1)} ${cy}L${cx} ${(cy + r).toFixed(1)}L${(cx - t).toFixed(1)} ${cy}Z" fill="${col}" opacity="${op}"/>
    <path d="M${(cx - r).toFixed(1)} ${cy}L${cx} ${(cy - t).toFixed(1)}L${(cx + r).toFixed(1)} ${cy}L${cx} ${(cy + t).toFixed(1)}Z" fill="${col}" opacity="${op * 0.85}"/>`;
}

// 满月：只用同心圆做月影，不用「暗圆遮亮圆」——那种画法在深色底上会读成日食
export function moon(cx, cy, r) {
  return `<circle cx="${cx}" cy="${cy}" r="${(r * 2.6).toFixed(1)}" fill="${P.cream}" opacity="0.07"/>
    <circle cx="${cx}" cy="${cy}" r="${(r * 1.6).toFixed(1)}" fill="${P.cream}" opacity="0.1"/>
    <circle cx="${cx}" cy="${cy}" r="${r.toFixed(1)}" fill="${P.cream}" opacity="0.9"/>
    <circle cx="${(cx - r * 0.32).toFixed(1)}" cy="${(cy - r * 0.2).toFixed(1)}" r="${(r * 0.2).toFixed(1)}" fill="${P.creamDim}" opacity="0.5"/>
    <circle cx="${(cx + r * 0.28).toFixed(1)}" cy="${(cy + r * 0.24).toFixed(1)}" r="${(r * 0.14).toFixed(1)}" fill="${P.creamDim}" opacity="0.45"/>`;
}
