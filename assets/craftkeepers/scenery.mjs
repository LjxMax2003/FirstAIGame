// 守艺人·百工夜行 —— P0 / P1 新增素材（摊位、Boss、UI、过场、立绘）
import { P, doc, lg, rg, glow, ground, blobPath, specks, hatch, lanternString, star4, moon, mulberry } from './lib.mjs';

/* --------------------------------- 摊位（P0） -------------------------------- */

function stallCanopy(seed) {
  const rand = mulberry(seed);
  let scallops = '';
  for (let i = 0; i < 12; i++) {
    const x = 6 + i * 14.6;
    scallops += `<path d="M${x.toFixed(1)} 34l7 9 7-9z" fill="${i % 2 ? P.cinnabar : P.cream}" opacity="0.9"/>`;
  }
  let stripes = '';
  for (let i = 0; i < 9; i++) {
    const x = 8 + i * 19;
    stripes += `<path d="M${x} 18h9l-2 16H${x + 1}z" fill="${P.cream}" opacity="0.22"/>`;
  }
  return `
    <path d="M2 18q88-20 176 0l-4 16H6z" fill="${P.cinnabar}"/>
    ${stripes}
    <path d="M2 18q88-20 176 0" fill="none" stroke="${P.gold}" stroke-width="2"/>
    ${scallops}`;
}

function stallBase(seed, accent) {
  return `
    ${ground(90, 134, 74, 7, 0.4)}
    <rect x="26" y="86" width="128" height="46" fill="${P.woodDeep}" opacity="0.85"/>
    ${hatch(28, 90, 124, 40, 8, P.nightDeep, 0.4, 2)}
    <path d="M12 78h156l-6 30H18z" fill="#6B4630"/>
    <rect x="10" y="72" width="160" height="9" rx="2" fill="#8A5C37"/>
    <rect x="10" y="72" width="160" height="3" fill="${P.cream}" opacity="0.28"/>
    <path d="M18 108h144" stroke="${P.gold}" stroke-width="2" opacity="0.65"/>
    <rect x="14" y="82" width="6" height="52" fill="${P.wood}"/>
    <rect x="160" y="82" width="6" height="52" fill="${P.wood}"/>
    <path d="M20 70q70-12 140 0" fill="none" stroke="${accent}" stroke-width="2" opacity="0.55"/>
    <g transform="translate(8 40)">${lanternMini(P.lantern)}</g>
    <g transform="translate(164 40)">${lanternMini(accent)}</g>
    ${stallCanopy(seed)}`;
}

function lanternMini(col) {
  return `<line x1="0" y1="-4" x2="0" y2="2" stroke="${P.woodDeep}" stroke-width="1.4"/>
    <ellipse cy="9" rx="6" ry="8" fill="${col}"/>
    <ellipse cy="9" rx="2.8" ry="5" fill="${P.cream}" opacity="0.55"/>
    <rect x="-3.4" y="-1" width="6.8" height="2.4" fill="${P.gold}"/>
    <path d="M0 17v5" stroke="${P.cinnabar}" stroke-width="1.4"/>`;
}

function stallSugar() {
  const defs = glow('sgG', 60, 62, 40, P.amber, 0.6);
  const body = `
    <circle cx="60" cy="62" r="40" fill="url(#sgG)"/>
    ${stallBase(1001, P.lantern)}
    <circle cx="58" cy="60" r="26" fill="#2E2A24"/>
    <circle cx="58" cy="60" r="26" fill="none" stroke="${P.gold}" stroke-width="2"/>
    <path d="M46 70q2-14 10-10 8 4 2 12-5 8-9-2" stroke="${P.amber}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <path d="M58 60q8-10 14-2" stroke="${P.amber}" stroke-width="3" fill="none" stroke-linecap="round"/>
    <path d="M92 40l14-14" stroke="${P.wood}" stroke-width="3.4" stroke-linecap="round"/>
    <circle cx="112" cy="36" r="7" fill="${P.gold}"/>
    <path d="M108 34q4 4 8 0" stroke="${P.lantern}" stroke-width="2.6" fill="none"/>
    <rect x="112" y="60" width="42" height="12" rx="2" fill="${P.cream}" opacity="0.9"/>
    <path d="M116 66h34" stroke="${P.ash}" stroke-width="2" opacity="0.35"/>
    ${star4(150, 30, 5, P.amber, 0.8)}`;
  return doc(180, 140, body, defs);
}

function stallShadow() {
  const defs =
    glow('sdG', 90, 52, 62, P.cream, 0.5) +
    lg('sdS', [[0, '#F6EEDC'], [1, '#DCCBA8']]);
  let ribs = '';
  for (let i = 0; i < 5; i++) ribs += `<rect x="${22 + i * 34}" y="34" width="4" height="40" fill="${P.woodDeep}" opacity="0.7"/>`;
  const body = `
    <circle cx="90" cy="52" r="62" fill="url(#sdG)"/>
    ${stallBase(1002, P.cinnabar)}
    <rect x="20" y="30" width="140" height="48" rx="3" fill="url(#sdS)"/>
    <rect x="20" y="30" width="140" height="48" rx="3" fill="none" stroke="${P.woodDeep}" stroke-width="3"/>
    ${ribs}
    <g opacity="0.88">
      <path d="M74 40q7 0 8 7l-2 8 4 10h-8l-2-8-4 8h-8l4-11-3-8 2-7z" fill="${P.cinnabarDeep}"/>
      <circle cx="80" cy="38" r="5.5" fill="${P.cinnabarDeep}"/>
      <path d="M96 44l16-6M96 52l16 6" stroke="${P.ink}" stroke-width="1.6"/>
      <path d="M112 38l4 20M112 58l4-14" stroke="${P.woodDeep}" stroke-width="1.4"/>
    </g>
    <ellipse cx="132" cy="56" rx="9" ry="11" fill="${P.lantern}" opacity="0.85"/>
    <ellipse cx="132" cy="56" rx="4" ry="6" fill="${P.cream}"/>
    <path d="M20 78h140" stroke="${P.gold}" stroke-width="2" opacity="0.7"/>`;
  return doc(180, 140, body, defs);
}

function stallLantern() {
  const defs = glow('sl2G', 90, 44, 60, P.lantern, 0.55);
  let hang = '';
  for (let i = 0; i < 6; i++) {
    const x = 24 + i * 26;
    const y = 26 + (i % 2) * 10;
    const col = i % 3 === 0 ? P.cinnabar : i % 3 === 1 ? P.lantern : P.amber;
    hang += `<g transform="translate(${x} ${y})">${lanternMini(col)}<ellipse cy="9" rx="7" ry="9" fill="${col}" opacity="0.85"/></g>`;
  }
  const body = `
    <circle cx="90" cy="44" r="60" fill="url(#sl2G)"/>
    ${stallBase(1003, P.amber)}
    <rect x="16" y="20" width="150" height="4" rx="2" fill="${P.woodDeep}"/>
    ${hang}
    <rect x="34" y="84" width="60" height="18" rx="2" fill="${P.cream}" opacity="0.85"/>
    ${hatch(36, 86, 56, 16, 6, P.ash, 0.25, 2)}
    <circle cx="124" cy="92" r="8" fill="${P.gold}"/>
    <path d="M118 92h12" stroke="${P.woodDeep}" stroke-width="2"/>`;
  return doc(180, 140, body, defs);
}

function stallPaper() {
  const defs = lg('spB', [[0, '#E7DAC0'], [1, '#C8B693']]);
  let cuts = '';
  const rand = mulberry(4242);
  for (let i = 0; i < 8; i++) {
    const x = 26 + (i % 4) * 34;
    const y = 30 + Math.floor(i / 4) * 24;
    const r = 9 + rand() * 3;
    cuts += `<g transform="translate(${x} ${y})">
      <path d="${blobPath(0, 0, r, 8, i * 17 + 3, 0.3)}" fill="${P.cinnabar}" opacity="0.92"/>
      <circle r="${(r * 0.28).toFixed(1)}" fill="${P.cream}" opacity="0.8"/>
      <path d="M${-r * 0.6} 0h${r * 1.2}" stroke="${P.cream}" stroke-width="1.2" opacity="0.6"/>
    </g>`;
  }
  const body = `
    ${stallBase(1004, P.cinnabar)}
    <rect x="18" y="24" width="144" height="54" rx="2" fill="url(#spB)"/>
    <rect x="18" y="24" width="144" height="54" rx="2" fill="none" stroke="${P.woodDeep}" stroke-width="2.5"/>
    ${cuts}
    <path d="M60 88h44l-3 10H63z" fill="#B0432F"/>
    <path d="M70 92h6M84 92h6" stroke="${P.cream}" stroke-width="2"/>
    ${star4(150, 24, 5, P.cream, 0.7)}`;
  return doc(180, 140, body, defs);
}

function stallForge() {
  const defs =
    glow('fgG', 60, 76, 46, P.lantern, 0.8) +
    lg('fgF', [[0, '#5A5F6B'], [1, '#2F3541']]);
  let sparks = '';
  const rand = mulberry(8899);
  for (let i = 0; i < 14; i++) {
    const x = 40 + rand() * 70;
    const y = 8 + rand() * 46;
    sparks += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(0.8 + rand() * 1.8).toFixed(1)}" fill="${P.amber}" opacity="${(0.4 + rand() * 0.6).toFixed(2)}"/>`;
  }
  const body = `
    <circle cx="60" cy="76" r="46" fill="url(#fgG)"/>
    ${stallBase(1005, P.cinnabar)}
    <path d="M34 44h50l6 40H28z" fill="url(#fgF)"/>
    <path d="M34 44h50" stroke="${P.gold}" stroke-width="2"/>
    <ellipse cx="59" cy="46" rx="18" ry="6" fill="${P.lantern}"/>
    <ellipse cx="59" cy="46" rx="10" ry="3.4" fill="${P.cream}" opacity="0.85"/>
    <path d="M52 40q7-12 14 0" stroke="${P.amber}" stroke-width="3" fill="none" opacity="0.8"/>
    ${sparks}
    <rect x="104" y="52" width="26" height="20" rx="3" fill="${P.wood}"/>
    <path d="M104 62h26" stroke="${P.gold}" stroke-width="1.6" opacity="0.7"/>
    <path d="M118 52l10-14" stroke="${P.woodDeep}" stroke-width="3" stroke-linecap="round"/>
    <rect x="132" y="76" width="30" height="8" rx="2" fill="#4A5568"/>
    <path d="M136 84v8M156 84v8" stroke="#4A5568" stroke-width="3"/>`;
  return doc(180, 140, body, defs);
}

/* ------------------------------- 场景地标（P0） ------------------------------ */

function lanternPillar() {
  const defs = glow('lpG', 40, 60, 54, P.lantern, 0.5);
  let lant = '';
  for (let i = 0; i < 5; i++) {
    const y = 22 + i * 30;
    const col = i % 2 ? P.cinnabar : P.lantern;
    const r = 12 - i * 0.6;
    lant += `<g transform="translate(40 ${y})">
      <ellipse rx="${r.toFixed(1)}" ry="${(r * 1.3).toFixed(1)}" fill="${col}"/>
      <ellipse rx="${(r * 0.45).toFixed(1)}" ry="${(r * 0.8).toFixed(1)}" fill="${P.cream}" opacity="0.5"/>
      <rect x="${(-r * 0.5).toFixed(1)}" y="${(-r * 1.45).toFixed(1)}" width="${r.toFixed(1)}" height="3" fill="${P.gold}"/>
      <rect x="${(-r * 0.5).toFixed(1)}" y="${(r * 1.15).toFixed(1)}" width="${r.toFixed(1)}" height="3" fill="${P.gold}"/>
      <path d="M0 ${(r * 1.45).toFixed(1)}v7" stroke="${P.cinnabar}" stroke-width="1.6"/>
    </g>`;
  }
  const body = `
    <circle cx="40" cy="70" r="54" fill="url(#lpG)"/>
    ${ground(40, 196, 20, 4, 0.4)}
    <rect x="36" y="8" width="8" height="188" rx="2" fill="${P.woodDeep}"/>
    <rect x="36" y="8" width="3" height="188" fill="${P.wood}" opacity="0.7"/>
    ${lant}
    <path d="M22 12h36" stroke="${P.gold}" stroke-width="3"/>
    <path d="M14 16q26 8 52 0" fill="none" stroke="${P.wood}" stroke-width="2"/>`;
  return doc(80, 200, body, defs);
}

function archway() {
  const defs =
    lg('awR', [[0, '#3E4C63'], [1, '#1E2A3C']]) +
    glow('awG', 160, 96, 120, P.amber, 0.35);
  const body = `
    <rect width="320" height="200" fill="none"/>
    <circle cx="160" cy="96" r="120" fill="url(#awG)"/>
    ${ground(160, 196, 130, 6, 0.4)}
    <rect x="42" y="70" width="16" height="126" fill="${P.woodDeep}"/>
    <rect x="262" y="70" width="16" height="126" fill="${P.woodDeep}"/>
    <rect x="42" y="70" width="5" height="126" fill="${P.cinnabarDeep}" opacity="0.8"/>
    <rect x="273" y="70" width="5" height="126" fill="${P.cinnabarDeep}" opacity="0.8"/>
    <rect x="120" y="86" width="14" height="110" fill="${P.woodDeep}" opacity="0.85"/>
    <rect x="186" y="86" width="14" height="110" fill="${P.woodDeep}" opacity="0.85"/>
    <path d="M8 56q152-30 304 0l-8 20H16z" fill="url(#awR)"/>
    <path d="M8 56q152-30 304 0" fill="none" stroke="${P.gold}" stroke-width="2.4" opacity="0.8"/>
    <path d="M0 52q10-16 26-10M320 52q-10-16-26-10" stroke="#3E4C63" stroke-width="7" fill="none" stroke-linecap="round"/>
    ${hatch(20, 62, 280, 12, 5, P.nightDeep, 0.35, 2)}
    <rect x="122" y="76" width="76" height="30" rx="3" fill="${P.nightDeep}"/>
    <rect x="122" y="76" width="76" height="30" rx="3" fill="none" stroke="${P.gold}" stroke-width="2.4"/>
    ${hatch(130, 84, 60, 16, 6, P.cream, 0.18, 3)}
    <g transform="translate(60 84)">${lanternMini(P.lantern)}</g>
    <g transform="translate(252 84)">${lanternMini(P.cinnabar)}</g>
    <path d="M160 106v10" stroke="${P.cinnabar}" stroke-width="2"/>`;
  return doc(320, 200, body, defs);
}

function oldStage() {
  const defs =
    lg('osR', [[0, '#43536B'], [1, '#202D40']]) +
    glow('osL', 200, 120, 140, P.amber, 0.45) +
    lg('osC', [[0, '#E4564A'], [1, P.cinnabarDeep]]);
  const body = `
    <circle cx="200" cy="120" r="140" fill="url(#osL)"/>
    ${ground(200, 214, 170, 7, 0.42)}
    <path d="M10 60q190-40 380 0l-12 24H22z" fill="url(#osR)"/>
    <path d="M10 60q190-40 380 0" fill="none" stroke="${P.gold}" stroke-width="2.6" opacity="0.75"/>
    <path d="M0 56q14-20 34-12M400 56q-14-20-34-12" stroke="#43536B" stroke-width="9" fill="none" stroke-linecap="round"/>
    ${hatch(26, 68, 348, 14, 6, P.nightDeep, 0.35, 2.4)}
    <rect x="44" y="84" width="18" height="120" fill="${P.woodDeep}"/>
    <rect x="338" y="84" width="18" height="120" fill="${P.woodDeep}"/>
    <rect x="44" y="84" width="6" height="120" fill="${P.cinnabarDeep}" opacity="0.85"/>
    <rect x="350" y="84" width="6" height="120" fill="${P.cinnabarDeep}" opacity="0.85"/>
    <rect x="66" y="88" width="268" height="106" fill="${P.nightDeep}"/>
    <rect x="66" y="88" width="268" height="106" fill="url(#osC)" opacity="0.55"/>
    <path d="M92 90q10 52 0 102M200 90q-8 52 0 102M308 90q-10 52 0 102" stroke="${P.cinnabarDeep}" stroke-width="16" fill="none" opacity="0.7"/>
    <ellipse cx="200" cy="150" rx="52" ry="34" fill="${P.amber}" opacity="0.28"/>
    <path d="M172 176q0-32 28-32t28 32z" fill="${P.cream}" opacity="0.9"/>
    <circle cx="200" cy="132" r="12" fill="${P.cream}"/>
    <path d="M188 126a12 12 0 0 1 24 0z" fill="${P.ink}"/>
    <path d="M192 176h16v-12h-16z" fill="${P.cinnabar}"/>
    <rect x="30" y="188" width="340" height="20" fill="#5A3B25"/>
    <rect x="30" y="188" width="340" height="5" fill="${P.gold}" opacity="0.6"/>
    <g transform="translate(70 74)">${lanternMini(P.lantern)}</g>
    <g transform="translate(322 74)">${lanternMini(P.lantern)}</g>`;
  return doc(400, 220, body, defs);
}

/* --------------------------------- Boss（P0） -------------------------------- */

function bossDrum() {
  const defs =
    glow('bdG', 80, 88, 74, P.cinnabar, 0.5) +
    lg('bdB', [[0, '#D14A38'], [0.5, P.cinnabar], [1, P.cinnabarDeep]]) +
    lg('bdS', [[0, '#D9CBAC'], [1, '#9C8F73']]);
  let studs = '';
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2;
    studs += `<circle cx="${(80 + Math.cos(a) * 56).toFixed(1)}" cy="${(56 + Math.sin(a) * 19).toFixed(1)}" r="3.2" fill="${P.gold}"/>`;
  }
  const body = `
    <circle cx="80" cy="88" r="74" fill="url(#bdG)"/>
    ${ground(80, 150, 46, 8, 0.45)}
    <path d="M24 56h112l-8 78q-48 14-96 0z" fill="url(#bdB)"/>
    <ellipse cx="80" cy="56" rx="56" ry="19" fill="url(#bdS)"/>
    <ellipse cx="80" cy="56" rx="56" ry="19" fill="none" stroke="${P.woodDeep}" stroke-width="3"/>
    ${studs}
    <path d="M30 78q50 16 100 0" fill="none" stroke="${P.gold}" stroke-width="3" opacity="0.85"/>
    <path d="M32 112q48 14 96 0" fill="none" stroke="${P.gold}" stroke-width="2.4" opacity="0.6"/>
    <path d="M46 40q34-22 68 0l-6 12q-28-16-56 0z" fill="${P.nightDeep}" opacity="0.75"/>
    <path d="M56 46h48" stroke="${P.gray}" stroke-width="2" opacity="0.5"/>
    <g opacity="0.9">
      <path d="M18 22l52 30" stroke="${P.wood}" stroke-width="6" stroke-linecap="round"/>
      <circle cx="70" cy="52" r="7" fill="${P.creamDim}"/>
      <path d="M142 22l-52 30" stroke="${P.wood}" stroke-width="6" stroke-linecap="round"/>
      <circle cx="90" cy="52" r="7" fill="${P.creamDim}"/>
    </g>
    <path d="M80 96q-6 12 2 18" stroke="${P.gray}" stroke-width="2" fill="none" opacity="0.35"/>`;
  return doc(160, 160, body, defs);
}

function bossFacelessNuo() {
  const defs =
    glow('bnG', 64, 58, 58, P.cream, 0.32) +
    lg('bnM', [[0, '#F4ECD8'], [0.6, P.cream], [1, '#C9B896']]) +
    lg('bnR', [[0, '#3A2E46'], [1, P.nightDeep]]);
  const body = `
    <circle cx="64" cy="58" r="58" fill="url(#bnG)"/>
    ${ground(64, 154, 40, 6, 0.45)}
    <path d="M64 74L20 116q2 30 8 38h72q6-8 8-38z" fill="url(#bnR)"/>
    <path d="M28 128q36 10 72 0M26 142q38 12 76 0" stroke="${P.cinnabarDeep}" stroke-width="1.8" fill="none" opacity="0.6"/>
    <path d="M64 74L20 116h88z" fill="${P.ink}" opacity="0.55"/>
    <ellipse cx="64" cy="56" rx="34" ry="40" fill="url(#bnM)"/>
    <ellipse cx="64" cy="56" rx="34" ry="40" fill="none" stroke="${P.gold}" stroke-width="3"/>
    <path d="M30 44q34-24 68 0" fill="none" stroke="${P.cinnabar}" stroke-width="3.4"/>
    <path d="M40 30q10 14 4 26M88 30q-10 14-4 26" stroke="${P.cinnabarDeep}" stroke-width="2" fill="none" opacity="0.7"/>
    <path d="M50 12l14 12 14-12-6 20h-16z" fill="${P.cinnabar}"/>
    <path d="M64 96v10" stroke="${P.cinnabar}" stroke-width="2"/>
    <ellipse cx="64" cy="62" rx="20" ry="24" fill="${P.nightDeep}" opacity="0.9"/>
    <path d="M52 50q6 8 4 20M76 50q-6 8-4 20" stroke="${P.cream}" stroke-width="1.4" fill="none" opacity="0.25"/>
    <path d="M44 92q20 12 40 0" fill="none" stroke="${P.gold}" stroke-width="2" opacity="0.6"/>
    ${star4(64, 62, 9, P.cream, 0.22)}`;
  return doc(128, 160, body, defs);
}

function bossLongNightLantern() {
  const defs =
    glow('lnG', 80, 84, 72, P.cream, 0.42) +
    lg('lnB', [[0, '#4C5C74'], [1, '#22304A']]) +
    lg('lnC', [[0, '#DCE9F5'], [0.5, '#9FB6CE'], [1, '#5C7391']]);
  let ribs = '';
  for (let i = 0; i < 6; i++) {
    const x = 34 + i * 19;
    ribs += `<path d="M${x} 44q${i < 3 ? 22 : -22} 40 0 84" fill="none" stroke="${P.nightDeep}" stroke-width="2" opacity="0.5"/>`;
  }
  const body = `
    <circle cx="80" cy="84" r="72" fill="url(#lnG)"/>
    <path d="M80 0v22" stroke="${P.gray}" stroke-width="4"/>
    <rect x="54" y="22" width="52" height="10" rx="3" fill="${P.gold}"/>
    <ellipse cx="80" cy="86" rx="46" ry="52" fill="url(#lnC)"/>
    ${ribs}
    <ellipse cx="80" cy="86" rx="46" ry="52" fill="none" stroke="${P.gold}" stroke-width="3"/>
    <rect x="54" y="134" width="52" height="10" rx="3" fill="${P.gold}"/>
    <path d="M68 144v12M80 144v16M92 144v12" stroke="${P.cinnabar}" stroke-width="2.4" opacity="0.7"/>
    <ellipse cx="80" cy="86" rx="20" ry="26" fill="${P.nightDeep}" opacity="0.55"/>
    <path d="M80 74q8 10 0 20-8-10 0-20z" fill="${P.cream}" opacity="0.5"/>
    <path d="M66 60q-6 26 4 50M94 60q6 26-4 50" stroke="${P.cream}" stroke-width="1.6" fill="none" opacity="0.3"/>
    <path d="M34 86h-14M160 86h-14" stroke="${P.gold}" stroke-width="3" opacity="0.6"/>
    ${star4(24, 34, 6, P.cream, 0.3)}
    ${star4(138, 44, 5, P.cream, 0.25)}`;
  return doc(160, 160, body, defs);
}

/* --------------------------------- UI（P0） --------------------------------- */

function uiPaperTexture() {
  const defs = lg('ptB', [[0, '#F6EEDA'], [1, '#E9DCC0']]);
  const rand = mulberry(6161);
  let fibers = '';
  for (let i = 0; i < 60; i++) {
    const x = rand() * 256, y = rand() * 256, l = 6 + rand() * 22, a = rand() * Math.PI;
    fibers += `<path d="M${x.toFixed(1)} ${y.toFixed(1)}q${(Math.cos(a) * l * 0.5).toFixed(1)} ${(Math.sin(a) * l * 0.5).toFixed(1)} ${(Math.cos(a) * l).toFixed(1)} ${(Math.sin(a) * l).toFixed(1)}" stroke="#B9A882" stroke-width="0.7" fill="none" opacity="${(0.08 + rand() * 0.16).toFixed(2)}"/>`;
  }
  let cloud = '';
  for (let i = 0; i < 4; i++) {
    const y = 24 + i * 66;
    cloud += `<path d="M0 ${y}q64 10 128 0t128 4" stroke="#C9B896" stroke-width="1.2" fill="none" opacity="0.3"/>`;
  }
  const body = `
    <rect width="256" height="256" fill="url(#ptB)"/>
    ${cloud}
    ${fibers}
    ${specks(256, 256, 200, 909, P.goldDeep, 0.09, 0.9)}`;
  return doc(256, 256, body, defs);
}

function uiWoodSign() {
  const defs =
    lg('wsW', [[0, '#7A5133'], [1, P.woodDeep]]) +
    glow('wsL', 120, 40, 120, P.amber, 0.25);
  const body = `
    <rect x="0" y="0" width="240" height="80" rx="6" fill="${P.nightDeep}" opacity="0.35"/>
    <path d="${blobPath(120, 40, 118, 48, 555, 0.012)}" fill="url(#wsW)"/>
    <rect x="12" y="10" width="216" height="60" rx="4" fill="none" stroke="${P.gold}" stroke-width="2.4" opacity="0.85"/>
    <rect x="18" y="16" width="204" height="48" rx="3" fill="${P.nightDeep}" opacity="0.35"/>
    <circle cx="120" cy="40" r="118" fill="url(#wsL)"/>
    ${hatch(24, 22, 192, 36, 7, P.cream, 0.05, 2)}
    <path d="M8 8l8 8M232 8l-8 8M8 72l8-8M232 72l-8-8" stroke="${P.gold}" stroke-width="2" opacity="0.7"/>
    <g transform="translate(120 78)"><path d="M-6 0h12l-6 12z" fill="${P.cinnabar}" opacity="0.9"/></g>`;
  return doc(240, 80, body, defs);
}

function uiSeal() {
  const defs = lg('seG', [[0, '#D9503F'], [1, P.cinnabarDeep]]);
  const body = `
    <rect x="2" y="2" width="60" height="60" rx="5" fill="url(#seG)"/>
    <rect x="2" y="2" width="60" height="60" rx="5" fill="none" stroke="${P.cream}" stroke-width="2.6" opacity="0.85"/>
    <path d="M14 16h36M32 16v32M18 32h28M14 48h36M22 24v16M42 24v16" stroke="${P.cream}" stroke-width="3.4" stroke-linecap="square" opacity="0.9"/>
    ${specks(64, 64, 26, 77, P.cinnabarDeep, 0.3, 1.2)}`;
  return doc(64, 64, body, defs);
}

function introBase(title) {
  const defs =
    lg('inS', [[0, '#070E19'], [0.5, P.night], [1, '#16223A']]) +
    glow('inG', 360, 470, 300, P.lantern, 0.5) +
    lg('inFade', [[0, P.nightDeep, 0.1], [1, P.nightDeep, 0.98]]);
  return { defs, title };
}

function intro01() {
  const { defs } = introBase();
  const body = `
    <rect width="720" height="1280" fill="url(#inS)"/>
    ${specks(720, 700, 260, 1212, P.cream, 0.4, 1)}
    ${moon(580, 180, 42)}
    <path d="M0 640q140-30 300-6t420-14v660H0z" fill="#0A1424" opacity="0.9"/>
    <path d="M60 700h180v-90H60zM300 730h220v-130H300z" fill="#16253C"/>
    <circle cx="360" cy="470" r="300" fill="url(#inG)"/>
    <line x1="360" y1="296" x2="360" y2="392" stroke="#1B2C46" stroke-width="4"/>
    <g transform="translate(360 430) scale(3)">
      <line x1="0" y1="-14" x2="0" y2="-6" stroke="${P.woodDeep}" stroke-width="1.6"/>
      <ellipse rx="7" ry="9" fill="${P.lantern}"/>
      <ellipse rx="3.2" ry="5.2" fill="${P.cream}" opacity="0.7"/>
      <rect x="-4" y="-12" width="8" height="2.6" fill="${P.gold}"/>
      <path d="M0 9v6" stroke="${P.cinnabar}" stroke-width="1.4"/>
    </g>
    <path d="M282 618h156l-10 62H292z" fill="#0C1828"/>
    <rect x="276" y="606" width="168" height="14" rx="3" fill="#16253C"/>
    <path d="M240 690q120 18 240 0" stroke="#1B2C46" stroke-width="3" fill="none" opacity="0.85"/>
    <path d="M0 880h720v400H0z" fill="url(#inFade)"/>
    <rect x="120" y="940" width="480" height="120" rx="8" fill="none"/>`;
  return doc(720, 1280, body, defs);
}

function intro02() {
  const { defs } = introBase();
  const tools = [
    [120, 'ladle'], [250, 'knife'], [380, 'brush'], [510, 'drumstick'], [620, 'lantern']
  ];
  let t = '';
  for (const [x, kind] of tools) {
    if (kind === 'ladle') t += `<g transform="translate(${x} 560) scale(2.2)"><path d="M-14 14L10-10" stroke="${P.wood}" stroke-width="4" stroke-linecap="round"/><circle cx="-16" cy="16" r="9" fill="${P.gold}"/><circle cx="-16" cy="16" r="5.5" fill="${P.lantern}"/></g>`;
    if (kind === 'knife') t += `<g transform="translate(${x} 560) scale(2.2)"><path d="M-6 16l4-24h10l4 24z" fill="#B9C4D4"/><path d="M-6 16h18" stroke="${P.gold}" stroke-width="2"/><path d="M0-8h6v22H0z" fill="${P.cinnabar}"/></g>`;
    if (kind === 'brush') t += `<g transform="translate(${x} 560) scale(2.2)"><path d="M0-20v26" stroke="${P.wood}" stroke-width="4"/><path d="M-5 6h10l-3 14h-4z" fill="${P.ink}"/></g>`;
    if (kind === 'drumstick') t += `<g transform="translate(${x} 560) scale(2.2)"><path d="M-12 12L12-12" stroke="${P.wood}" stroke-width="4" stroke-linecap="round"/><circle cx="14" cy="-14" r="5" fill="${P.creamDim}"/><path d="M-12 12l-4 6" stroke="${P.cinnabar}" stroke-width="3"/></g>`;
    if (kind === 'lantern') t += `<g transform="translate(${x} 560) scale(2.2)"><ellipse rx="9" ry="12" fill="${P.cinnabar}"/><ellipse rx="4" ry="6.5" fill="${P.cream}" opacity="0.6"/><rect x="-5" y="-15" width="10" height="3" fill="${P.gold}"/></g>`;
  }
  const body = `
    <rect width="720" height="1280" fill="url(#inS)"/>
    ${specks(720, 700, 220, 3131, P.cream, 0.35, 1)}
    <circle cx="360" cy="560" r="320" fill="url(#inG)"/>
    <path d="M40 620h640l-30 40H70z" fill="#5A3B25"/>
    <rect x="40" y="600" width="640" height="24" rx="4" fill="#7A5133"/>
    <rect x="40" y="600" width="640" height="7" fill="${P.cream}" opacity="0.22"/>
    ${t}
    ${lanternString(80, 300, 640, 280, 9, 22, 2)}
    <rect x="70" y="660" width="580" height="150" fill="${P.woodDeep}" opacity="0.9"/>
    ${hatch(80, 672, 560, 130, 12, P.nightDeep, 0.35, 3)}
    <path d="M60 812q300 40 600 0" fill="none" stroke="${P.cinnabar}" stroke-width="3" opacity="0.3"/>
    <path d="M0 900h720v380H0z" fill="url(#inFade)"/>`;
  return doc(720, 1280, body, defs);
}

function intro03() {
  const { defs } = introBase();
  let stalls = '';
  const xs = [60, 250, 440, 600];
  for (let i = 0; i < xs.length; i++) {
    const x = xs[i], y = 700;
    const s = 1.1 + (i % 2) * 0.15;
    stalls += `<g transform="translate(${x} ${y}) scale(${s})" opacity="0.95">
      <path d="M-40 0h80l-6 34H-34z" fill="#5A3B25"/>
      <rect x="-36" y="-30" width="72" height="30" fill="#22304A" opacity="0.85"/>
      <path d="M-46-40q46-16 92 0l-4 12H-42z" fill="${i % 2 ? P.cinnabar : P.lantern}" opacity="0.9"/>
      <ellipse cx="0" cy="-14" rx="9" ry="11" fill="${P.cream}" opacity="0.45"/>
    </g>`;
  }
  let crowd = '';
  const rand = mulberry(707);
  for (let i = 0; i < 22; i++) {
    const x = 30 + rand() * 660;
    const y = 760 + rand() * 60;
    const r = 8 + rand() * 4;
    crowd += `<g opacity="0.82"><ellipse cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" rx="${r.toFixed(1)}" ry="${(r * 1.6).toFixed(1)}" fill="#0A1424"/><circle cx="${x.toFixed(1)}" cy="${(y - r * 1.5).toFixed(1)}" r="${(r * 0.55).toFixed(1)}" fill="#0A1424"/></g>`;
  }
  const body = `
    <rect width="720" height="1280" fill="url(#inS)"/>
    ${moon(150, 170, 40)}
    ${specks(720, 620, 240, 4242, P.cream, 0.4, 1)}
    <path d="M0 560q180-40 360-8t360-24v752H0z" fill="#0C1828"/>
    <circle cx="360" cy="620" r="330" fill="url(#inG)"/>
    ${lanternString(20, 420, 700, 400, 16, 15, 2.4)}
    ${lanternString(60, 520, 660, 500, 12, 66, 1.8)}
    ${stalls}
    ${crowd}
    <path d="M320 470q40-70 0-120-40 50 0 120z" fill="${P.cream}" opacity="0.12"/>
    <rect x="0" y="980" width="720" height="300" fill="url(#inFade)"/>`;
  return doc(720, 1280, body, defs);
}

/* --------------------------- P1：立绘 / 图鉴 / Boss 特效 -------------------------- */

function bust(accent, hat, prop) {
  const defs =
    glow('buG', 64, 96, 76, accent, 0.35) +
    lg('buB', [[0, '#3F6F68'], [1, P.tealDeep]]) +
    lg('buS', [[0, P.cream], [1, '#DCCBA6']]);
  return doc(128, 160, `
    <rect width="128" height="160" fill="${P.nightDeep}"/>
    <circle cx="64" cy="96" r="76" fill="url(#buG)"/>
    <path d="${blobPath(64, 80, 74, 22, accent.charCodeAt(1) * 7, 0.05)}" fill="${P.night}" opacity="0.85"/>
    <path d="M40 92q24-14 48 0l6 66H34z" fill="url(#buB)"/>
    <path d="M64 88l-8 14 3 3 5-7 5 7 3-3z" fill="url(#buS)"/>
    <ellipse cx="64" cy="58" rx="21" ry="24" fill="url(#buS)"/>
    <path d="M43 60c0-16 8-26 21-26s21 10 21 26c-4-9-11-13-21-13s-17 4-21 13z" fill="${P.ink}"/>
    ${hat}
    <circle cx="56" cy="60" r="2.4" fill="${P.ink}"/>
    <circle cx="72" cy="60" r="2.4" fill="${P.ink}"/>
    <path d="M59 70q5 4 10 0" stroke="${P.cinnabar}" stroke-width="1.6" fill="none" stroke-linecap="round"/>
    <circle cx="50" cy="66" r="3.4" fill="${P.cinnabar}" opacity="0.22"/>
    <circle cx="78" cy="66" r="3.4" fill="${P.cinnabar}" opacity="0.22"/>
    ${prop}
    <rect x="6" y="6" width="116" height="148" rx="4" fill="none" stroke="${accent}" stroke-width="2" opacity="0.6"/>`, defs);
}

function charSugar() {
  const hat = `<path d="M42 36h44l-4-8H46z" fill="${P.woodDeep}"/>`;
  const prop = `<g transform="translate(96 110) scale(1.5)"><path d="M-8 8L6-6" stroke="${P.wood}" stroke-width="3" stroke-linecap="round"/><circle cx="-9" cy="9" r="6" fill="${P.gold}"/><circle cx="-9" cy="9" r="3.4" fill="${P.lantern}"/></g>`;
  return bust(P.amber, hat, prop);
}
function charShadow() {
  const hat = `<path d="M40 34q24-12 48 0v6H40z" fill="${P.cinnabarDeep}"/>`;
  const prop = `<g transform="translate(96 112) scale(1.5)"><path d="M-6 10l3-18h8l3 18z" fill="${P.cinnabar}" opacity="0.9"/><path d="M-3-8h10" stroke="${P.gold}" stroke-width="2"/></g>`;
  return bust(P.cinnabar, hat, prop);
}
function charPaper() {
  const hat = `<path d="M44 30q20-10 40 0l-6 10H50z" fill="${P.inkSoft}"/><circle cx="64" cy="24" r="5" fill="${P.cinnabar}"/>`;
  const prop = `<g transform="translate(96 112) scale(1.4)"><path d="${blobPath(0, 0, 10, 8, 91, 0.28)}" fill="${P.cinnabar}"/><circle r="2.6" fill="${P.cream}" opacity="0.8"/></g>`;
  return bust(P.cream, hat, prop);
}
function charLantern() {
  const hat = `<path d="M42 32h44v8H42z" fill="${P.woodDeep}"/><path d="M38 32q26-10 52 0" fill="none" stroke="${P.gold}" stroke-width="2"/>`;
  const prop = `<g transform="translate(96 110) scale(1.5)"><ellipse rx="8" ry="10" fill="${P.lantern}"/><ellipse rx="3.6" ry="5.6" fill="${P.cream}" opacity="0.7"/><rect x="-4" y="-13" width="8" height="2.6" fill="${P.gold}"/></g>`;
  return bust(P.lantern, hat, prop);
}
function charForge() {
  const hat = `<path d="M40 36q24-16 48 0l-4 6q-20-10-40 0z" fill="${P.ink}"/><path d="M52 24q12-8 24 0" stroke="${P.cinnabar}" stroke-width="3" fill="none"/>`;
  const prop = `<g transform="translate(96 112) scale(1.5)"><path d="M-8-6h16l-4 16h-8z" fill="#5A5F6B"/><path d="M-8-6h16" stroke="${P.amber}" stroke-width="2.4"/><circle cx="2" cy="-12" r="2.4" fill="${P.lantern}"/></g>`;
  return bust(P.cinnabar, hat, prop);
}

function codexBg() {
  const defs =
    lg('cxP', [[0, '#F3EAD4'], [1, '#DFCEA8']]) +
    lg('cxEdge', [[0, P.woodDeep, 0], [1, P.woodDeep, 0.5]]);
  let lines = '';
  for (let i = 0; i < 9; i++) lines += `<rect x="60" y="${260 + i * 96}" width="600" height="2" fill="${P.ash}" opacity="0.12"/>`;
  const body = `
    <rect x="6" y="8" width="708" height="1264" rx="18" fill="${P.nightDeep}" opacity="0.35"/>
    <rect x="14" y="16" width="692" height="1248" rx="14" fill="url(#cxP)"/>
    ${specks(720, 1280, 620, 5151, P.goldDeep, 0.1)}
    <rect x="34" y="34" width="652" height="1212" rx="8" fill="none" stroke="${P.cinnabar}" stroke-width="2.6" opacity="0.5"/>
    <rect x="46" y="46" width="628" height="1188" rx="6" fill="none" stroke="${P.ash}" stroke-width="1.2" opacity="0.3"/>
    <rect y="0" width="720" height="150" fill="url(#cxEdge)" opacity="0.18"/>
    ${lines}
    <g transform="translate(360 120)">
      <rect x="-40" y="-24" width="80" height="48" rx="4" fill="${P.cinnabar}" opacity="0.9"/>
      <rect x="-40" y="-24" width="80" height="48" rx="4" fill="none" stroke="${P.cream}" stroke-width="2.4"/>
      <path d="M-22-10h44M0-10v22M-16 12h32" stroke="${P.cream}" stroke-width="4"/>
    </g>
    <path d="M60 1120q60-40 120 0t120 0 120 0 120 0" stroke="${P.teal}" stroke-width="2.4" fill="none" opacity="0.35"/>`;
  return doc(720, 1280, body, defs);
}

function bossWarningRing() {
  const defs = rg('bwR', [[0, P.cinnabar, 0], [0.6, P.cinnabar, 0.06], [0.82, P.cinnabar, 0.5], [1, P.lantern, 0.15]], ' cx="128" cy="128" r="128"');
  let ticks = '';
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    const r1 = 100, r2 = 116;
    ticks += `<path d="M${(128 + Math.cos(a) * r1).toFixed(1)} ${(128 + Math.sin(a) * r1).toFixed(1)}L${(128 + Math.cos(a) * r2).toFixed(1)} ${(128 + Math.sin(a) * r2).toFixed(1)}" stroke="${P.cinnabar}" stroke-width="${i % 3 === 0 ? 4 : 2}" opacity="0.75"/>`;
  }
  const body = `
    <circle cx="128" cy="128" r="128" fill="url(#bwR)"/>
    <circle cx="128" cy="128" r="104" fill="none" stroke="${P.cinnabar}" stroke-width="3" stroke-dasharray="14 10" opacity="0.9"/>
    <circle cx="128" cy="128" r="78" fill="none" stroke="${P.lantern}" stroke-width="2" opacity="0.5"/>
    ${ticks}`;
  return doc(256, 256, body, defs);
}

function bossMaskGlow() {
  const defs = glow('bmg', 64, 64, 64, P.cream, 0.6);
  const body = `
    <circle cx="64" cy="64" r="64" fill="url(#bmg)"/>
    <ellipse cx="64" cy="64" rx="34" ry="42" fill="none" stroke="${P.cream}" stroke-width="3" opacity="0.8"/>
    <path d="M30 50q34-26 68 0" fill="none" stroke="${P.gold}" stroke-width="3" opacity="0.7"/>
    <path d="M44 60q6 10 4 22M84 60q-6 10-4 22" stroke="${P.cream}" stroke-width="2" fill="none" opacity="0.4"/>
    ${star4(64, 64, 26, P.cream, 0.25)}`;
  return doc(128, 128, body, defs);
}

function bossLanternDrain() {
  const defs = rg('bld', [[0, '#0A1424', 0.95], [0.5, P.night, 0.75], [1, P.tealDeep, 0.1]], ' cx="128" cy="128" r="128"');
  let arms = '';
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    arms += `<path d="M128 128q${(Math.cos(a) * 60).toFixed(0)} ${(Math.sin(a) * 60).toFixed(0)} ${(Math.cos(a + 1) * 108).toFixed(0)} ${(Math.sin(a + 1) * 108).toFixed(0)}" stroke="${P.gray}" stroke-width="9" fill="none" opacity="0.6" stroke-linecap="round"/>`;
  }
  let petals = '';
  const rand = mulberry(3300);
  for (let i = 0; i < 18; i++) {
    const a = rand() * Math.PI * 2;
    const r = 40 + rand() * 80;
    petals += `<ellipse cx="${(128 + Math.cos(a) * r).toFixed(1)}" cy="${(128 + Math.sin(a) * r).toFixed(1)}" rx="5" ry="8" fill="${P.lantern}" opacity="${(0.35 + rand() * 0.5).toFixed(2)}" transform="rotate(${(rand() * 360).toFixed(0)} ${(128 + Math.cos(a) * r).toFixed(1)} ${(128 + Math.sin(a) * r).toFixed(1)})"/>`;
  }
  const body = `
    <circle cx="128" cy="128" r="128" fill="url(#bld)"/>
    ${arms}
    ${petals}
    <circle cx="128" cy="128" r="24" fill="${P.nightDeep}"/>
    <circle cx="128" cy="128" r="24" fill="none" stroke="${P.gray}" stroke-width="2" opacity="0.6"/>`;
  return doc(256, 256, body, defs);
}

/* ---------------------------------- 导出 ---------------------------------- */

export const scenery = [
  { file: 'stalls/stall_sugar.svg', old: null, w: 180, h: 140, tier: 'P0', title: '糖画摊', svg: stallSugar() },
  { file: 'stalls/stall_shadow.svg', old: null, w: 180, h: 140, tier: 'P0', title: '皮影摊', svg: stallShadow() },
  { file: 'stalls/stall_lantern.svg', old: null, w: 180, h: 140, tier: 'P0', title: '花灯摊', svg: stallLantern() },
  { file: 'stalls/stall_paper.svg', old: null, w: 180, h: 140, tier: 'P0', title: '剪纸摊', svg: stallPaper() },
  { file: 'stalls/stall_forge.svg', old: null, w: 180, h: 140, tier: 'P0', title: '铁花炉', svg: stallForge() },
  { file: 'stalls/lantern_pillar.svg', old: null, w: 80, h: 200, tier: 'P0', title: '灯柱', svg: lanternPillar() },
  { file: 'stalls/archway.svg', old: null, w: 320, h: 200, tier: 'P0', title: '夜市牌坊', svg: archway() },
  { file: 'stalls/old_stage.svg', old: null, w: 400, h: 220, tier: 'P0', title: '老戏台', svg: oldStage() },

  { file: 'enemies/boss_drum.svg', old: null, w: 160, h: 160, tier: 'P0', title: '哑鼓（一更 Boss）', svg: bossDrum() },
  { file: 'enemies/boss_faceless_nuo.svg', old: null, w: 128, h: 160, tier: 'P0', title: '无面傩（三更 Boss）', svg: bossFacelessNuo() },
  { file: 'enemies/boss_long_night_lantern.svg', old: null, w: 160, h: 160, tier: 'P0', title: '长夜灯（五更压轴）', svg: bossLongNightLantern() },

  { file: 'ui/ui_paper_texture.svg', old: null, w: 256, h: 256, tier: 'P0', title: '宣纸底纹（无缝）', svg: uiPaperTexture() },
  { file: 'ui/ui_wood_sign.svg', old: null, w: 240, h: 80, tier: 'P0', title: '木招牌（标题底）', svg: uiWoodSign() },
  { file: 'ui/ui_seal.svg', old: null, w: 64, h: 64, tier: 'P0', title: '朱砂印章', svg: uiSeal() },
  { file: 'ui/intro_01.svg', old: null, w: 720, h: 1280, tier: 'P0', title: '过场一·一盏灯（无人物无文字）', svg: intro01() },
  { file: 'ui/intro_02.svg', old: null, w: 720, h: 1280, tier: 'P0', title: '过场二·六艺案头', svg: intro02() },
  { file: 'ui/intro_03.svg', old: null, w: 720, h: 1280, tier: 'P0', title: '过场三·百工夜市复原', svg: intro03() },

  { file: 'characters/char_sugar.svg', old: null, w: 128, h: 160, tier: 'P1', title: '立绘·糖画匠', svg: charSugar() },
  { file: 'characters/char_shadow.svg', old: null, w: 128, h: 160, tier: 'P1', title: '立绘·皮影匠', svg: charShadow() },
  { file: 'characters/char_paper.svg', old: null, w: 128, h: 160, tier: 'P1', title: '立绘·剪纸娘', svg: charPaper() },
  { file: 'characters/char_lantern.svg', old: null, w: 128, h: 160, tier: 'P1', title: '立绘·花灯翁', svg: charLantern() },
  { file: 'characters/char_forge.svg', old: null, w: 128, h: 160, tier: 'P1', title: '立绘·铁花汉', svg: charForge() },
  { file: 'ui/codex_bg.svg', old: null, w: 720, h: 1280, tier: 'P1', title: '百工谱图鉴底', svg: codexBg() },
  { file: 'fx/boss_warning_ring.svg', old: null, w: 256, h: 256, tier: 'P1', title: 'Boss 大招地面预警圈', svg: bossWarningRing() },
  { file: 'fx/boss_mask_glow.svg', old: null, w: 128, h: 128, tier: 'P1', title: '傩面开脸光效', svg: bossMaskGlow() },
  { file: 'fx/boss_lantern_drain.svg', old: null, w: 256, h: 256, tier: 'P1', title: '长夜灯·吸光漩涡', svg: bossLanternDrain() },
];
