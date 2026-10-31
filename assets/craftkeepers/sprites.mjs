// 守艺人·百工夜行 —— 34 张换皮素材（画布尺寸与原素材严格一致）
import { P, doc, lg, rg, glow, ground, blobPath, specks, hatch, lanternString, star4, moon, mulberry } from './lib.mjs';

/* ---------------------------------- 角色 --------------------------------- */

function shouyirenFront() {
  const defs =
    glow('sfL', 47, 52, 15, P.lantern, 0.7) +
    lg('sfJ', [[0, '#4A8F86'], [1, P.tealDeep]]);
  const body = `
    <circle cx="47" cy="52" r="15" fill="url(#sfL)"/>
    ${ground(32, 76, 13, 3.2)}
    <rect x="25" y="58" width="6" height="15" rx="2" fill="${P.nightDeep}"/>
    <rect x="33" y="58" width="6" height="15" rx="2" fill="${P.nightDeep}"/>
    <rect x="23" y="71" width="10" height="4" rx="1.5" fill="${P.ink}"/>
    <rect x="33" y="71" width="10" height="4" rx="1.5" fill="${P.ink}"/>
    <path d="M21 41q11-7 22 0l2 20H19z" fill="url(#sfJ)"/>
    <path d="M32 37l-6.5 10 2 3.5 4.5-6 4.5 6 2-3.5z" fill="${P.cream}"/>
    <rect x="20" y="52" width="24" height="7" fill="${P.cinnabar}"/>
    <rect x="20" y="55.5" width="24" height="2" fill="${P.gold}" opacity="0.75"/>
    <path d="M21 43l-6 12 4 2.5 5-9z" fill="${P.tealDeep}"/>
    <path d="M43 43l7 7-3.5 3.5-6-6z" fill="${P.tealDeep}"/>
    <line x1="48" y1="50" x2="47" y2="44" stroke="${P.wood}" stroke-width="1.6"/>
    <ellipse cx="47" cy="54" rx="5" ry="6.5" fill="${P.lantern}"/>
    <ellipse cx="47" cy="54" rx="2.4" ry="3.6" fill="${P.cream}" opacity="0.8"/>
    <rect x="44" y="46.5" width="6" height="2" fill="${P.gold}"/>
    <circle cx="32" cy="24" r="10.5" fill="${P.cream}"/>
    <path d="M21.5 24.5c0-7 4.5-12.5 10.5-12.5s10.5 5.5 10.5 12.5c-2-4.5-6-6.8-10.5-6.8s-8.5 2.3-10.5 6.8z" fill="${P.ink}"/>
    <circle cx="32" cy="11" r="3.4" fill="${P.ink}"/>
    <rect x="28.6" y="9.6" width="6.8" height="1.8" rx="0.9" fill="${P.cinnabar}"/>
    <circle cx="27.6" cy="27.5" r="1.55" fill="${P.ink}"/>
    <circle cx="36.4" cy="27.5" r="1.55" fill="${P.ink}"/>
    <path d="M29.5 32.5q2.5 1.8 5 0" stroke="${P.cinnabar}" stroke-width="1.2" fill="none" stroke-linecap="round"/>
    <circle cx="24.5" cy="30" r="2.2" fill="${P.cinnabar}" opacity="0.28"/>
    <circle cx="39.5" cy="30" r="2.2" fill="${P.cinnabar}" opacity="0.28"/>`;
  return doc(64, 80, body, defs);
}

function shouyirenBack() {
  const defs =
    glow('sbL', 50, 22, 17, P.amber, 0.75) +
    lg('sbJ', [[0, '#4E938A'], [1, P.tealDeep]]);
  const body = `
    <circle cx="50" cy="22" r="17" fill="url(#sbL)"/>
    ${ground(32, 76, 13, 3.2)}
    <rect x="25" y="58" width="6" height="15" rx="2" fill="${P.nightDeep}"/>
    <rect x="33" y="58" width="6" height="15" rx="2" fill="${P.nightDeep}"/>
    <rect x="23" y="71" width="10" height="4" rx="1.5" fill="${P.ink}"/>
    <rect x="33" y="71" width="10" height="4" rx="1.5" fill="${P.ink}"/>
    <path d="M21 41q11-7 22 0l2 20H19z" fill="url(#sbJ)"/>
    <path d="M21 41q11-7 22 0v4q-11-6-22 0z" fill="${P.cream}" opacity="0.55"/>
    <rect x="20" y="52" width="24" height="7" fill="${P.cinnabar}"/>
    <rect x="26" y="44" width="12" height="14" rx="2.5" fill="${P.wood}"/>
    <rect x="26" y="44" width="12" height="4" rx="2" fill="${P.creamDim}"/>
    <path d="M43 43l9-16-2.5-1.5-7 13z" fill="${P.tealDeep}"/>
    <line x1="50" y1="26" x2="50" y2="18" stroke="${P.wood}" stroke-width="1.8"/>
    <ellipse cx="50" cy="15" rx="5.5" ry="7" fill="${P.lantern}"/>
    <ellipse cx="50" cy="15" rx="2.6" ry="4" fill="${P.cream}" opacity="0.85"/>
    <rect x="46.5" y="7" width="7" height="2.2" fill="${P.gold}"/>
    <path d="M50 22l0 5" stroke="${P.cinnabar}" stroke-width="1.4"/>
    <circle cx="32" cy="24" r="10.5" fill="${P.ink}"/>
    <path d="M22 26a10.5 10.5 0 0 0 20 0z" fill="${P.inkSoft}"/>
    <circle cx="32" cy="12" r="3.6" fill="${P.ink}"/>
    <path d="M28.4 12.4h7.2" stroke="${P.cinnabar}" stroke-width="2"/>
    <path d="M30 15.5q2 6 4 0" stroke="${P.creamDim}" stroke-width="1" fill="none" opacity="0.5"/>`;
  return doc(64, 80, body, defs);
}

/* ---------------------------------- 敌人 ---------------------------------- */

function paperScrap() {
  const defs = lg('psG', [[0, P.cream], [1, P.creamDim]]);
  const body = `
    ${ground(24, 44, 11, 3, 0.32)}
    <path d="${blobPath(24, 26, 15, 13, 7, 0.3)}" fill="url(#psG)"/>
    <path d="${blobPath(24, 26, 11, 11, 21, 0.34)}" fill="${P.creamDim}" opacity="0.55"/>
    ${specks(48, 48, 16, 33, P.ash, 0.2)}
    <path d="M17 20l5 3-2 4" stroke="${P.ink}" stroke-width="1.3" fill="none" opacity="0.55"/>
    <path d="M28 30l4-2 1 4" stroke="${P.ink}" stroke-width="1.3" fill="none" opacity="0.45"/>
    <ellipse cx="19.5" cy="25" rx="2.6" ry="3.4" fill="${P.nightDeep}"/>
    <ellipse cx="28.5" cy="25" rx="2.6" ry="3.4" fill="${P.nightDeep}"/>
    <circle cx="19.5" cy="24.2" r="0.9" fill="${P.cyan}" opacity="0.55"/>
    <circle cx="28.5" cy="24.2" r="0.9" fill="${P.cyan}" opacity="0.55"/>`;
  return doc(48, 48, body, defs);
}

function brokenKite() {
  const defs =
    glow('bkT', 12, 40, 14, P.cyan, 0.5) +
    lg('bkG', [[0, '#59C7D8'], [1, P.teal]]);
  const body = `
    <path d="M40 14l-14 3M40 18l-13 5" stroke="${P.cyan}" stroke-width="2" opacity="0.35" stroke-linecap="round"/>
    ${ground(24, 44, 10, 2.6, 0.28)}
    <path d="M24 6l13 12-13 18-13-18z" fill="url(#bkG)"/>
    <path d="M24 6l13 12H11z" fill="${P.cream}" opacity="0.32"/>
    <path d="M11 18h26" stroke="${P.nightDeep}" stroke-width="1.1" opacity="0.5"/>
    <path d="M24 6v30" stroke="${P.wood}" stroke-width="1.4"/>
    <path d="M30 30l7 6-4 1 1 5-6-7" fill="${P.cinnabar}" opacity="0.8"/>
    <path d="M24 36q-4 5-2 9" stroke="${P.wood}" stroke-width="1.2" fill="none"/>
    <path d="M22 45l4-2" stroke="${P.cinnabar}" stroke-width="1.6"/>
    <ellipse cx="19" cy="20" rx="2.4" ry="3" fill="${P.nightDeep}"/>
    <ellipse cx="29" cy="20" rx="2.4" ry="3" fill="${P.nightDeep}"/>
    <circle cx="19" cy="19.2" r="0.9" fill="${P.cyan}"/>
    <circle cx="29" cy="19.2" r="0.9" fill="${P.cyan}"/>
    <path d="M9 16l3-2 3 3" stroke="${P.cream}" stroke-width="1.2" fill="none" opacity="0.7"/>`;
  return doc(48, 48, body, defs);
}

function brokenPuppet() {
  const defs = lg('bpW', [[0, '#8A5C37'], [1, P.wood]]);
  const body = `
    ${ground(24, 44, 12, 3, 0.34)}
    <path d="M14 2l3 9M34 2l-3 9M24 1v6" stroke="${P.creamDim}" stroke-width="0.9" opacity="0.6"/>
    <circle cx="24" cy="13" r="7.5" fill="${P.cream}"/>
    <path d="M16.8 11.5a7.5 7.5 0 0 1 14.4 0z" fill="${P.woodDeep}"/>
    <path d="M20.5 15.5h2.2M25.3 15.5h2.2" stroke="${P.ink}" stroke-width="1.6" stroke-linecap="round"/>
    <path d="M22 19q2 1.4 4 0" stroke="${P.cinnabarDeep}" stroke-width="1.1" fill="none"/>
    <path d="M17 22h14l2 14q-9 4-18 0z" fill="url(#bpW)"/>
    <rect x="16" y="26" width="16" height="3" fill="${P.cinnabar}"/>
    <path d="M17 24l-6 8 3 2 6-6z" fill="#8A5C37"/>
    <path d="M31 24l6 8-3 2-6-6z" fill="#8A5C37"/>
    <circle cx="14" cy="32" r="1.6" fill="${P.gold}"/>
    <circle cx="34" cy="32" r="1.6" fill="${P.gold}"/>
    <path d="M20 36v6M28 36v6" stroke="${P.woodDeep}" stroke-width="3.2" stroke-linecap="round"/>
    <path d="M12 40q4 4 8 1" stroke="${P.creamDim}" stroke-width="0.8" fill="none" opacity="0.5"/>`;
  return doc(48, 48, body, defs);
}

function inkBlobElite() {
  const defs =
    glow('ibG', 48, 52, 40, P.night, 0.55) +
    lg('ibB', [[0, '#2C3444'], [1, P.ink]]);
  const body = `
    <circle cx="48" cy="52" r="40" fill="url(#ibG)"/>
    ${ground(48, 88, 26, 5, 0.4)}
    <path d="${blobPath(48, 50, 34, 17, 11, 0.26)}" fill="url(#ibB)"/>
    <path d="${blobPath(48, 44, 24, 13, 29, 0.3)}" fill="${P.inkSoft}" opacity="0.7"/>
    <path d="M30 78q4 12 8 2t8 8 8-4" stroke="${P.ink}" stroke-width="4" fill="none" stroke-linecap="round"/>
    ${specks(96, 96, 30, 41, P.cream, 0.16)}
    <path d="M34 40h9M38 34v16M53 38h8M57 34v14" stroke="${P.cream}" stroke-width="1.8" opacity="0.28"/>
    <ellipse cx="38" cy="52" rx="5.5" ry="7.5" fill="${P.cream}" opacity="0.9"/>
    <ellipse cx="58" cy="52" rx="5.5" ry="7.5" fill="${P.cream}" opacity="0.9"/>
    <ellipse cx="38" cy="53.5" rx="2.4" ry="3.4" fill="${P.nightDeep}"/>
    <ellipse cx="58" cy="53.5" rx="2.4" ry="3.4" fill="${P.nightDeep}"/>
    <path d="M40 66q8 6 16 0" stroke="${P.cinnabar}" stroke-width="2.4" fill="none" stroke-linecap="round"/>
    <path d="M74 26l3 6M20 30l4 5" stroke="${P.gray}" stroke-width="1.6" opacity="0.6"/>`;
  return doc(96, 96, body, defs);
}

function facelessNuoElite() {
  const defs =
    glow('fnG', 48, 50, 40, P.cinnabar, 0.5) +
    lg('fnM', [[0, '#E1573F'], [0.6, P.cinnabar], [1, P.cinnabarDeep]]);
  const body = `
    <circle cx="48" cy="50" r="40" fill="url(#fnG)"/>
    ${ground(48, 90, 24, 4.5, 0.4)}
    <path d="M18 20q30-14 60 0l-4 44q-26 14-52 0z" fill="url(#fnM)"/>
    <path d="M18 20q30-14 60 0" fill="none" stroke="${P.gold}" stroke-width="2.4"/>
    <path d="M22 64q26 14 52 0" fill="none" stroke="${P.gold}" stroke-width="2"/>
    <path d="M30 24q-8 16 2 26M66 24q8 16-2 26" stroke="${P.gold}" stroke-width="1.6" fill="none" opacity="0.8"/>
    <path d="M34 34q6-6 12 0" stroke="${P.nightDeep}" stroke-width="3" fill="none" stroke-linecap="round"/>
    <path d="M50 34q6-6 12 0" stroke="${P.nightDeep}" stroke-width="3" fill="none" stroke-linecap="round"/>
    <ellipse cx="40" cy="43" rx="6" ry="7" fill="${P.nightDeep}"/>
    <ellipse cx="56" cy="43" rx="6" ry="7" fill="${P.nightDeep}"/>
    <path d="M44 52l4 6 4-6z" fill="${P.nightDeep}" opacity="0.75"/>
    <path d="M34 64q14 8 28 0" fill="${P.nightDeep}" opacity="0.7"/>
    <path d="M46 22l3 10-6 2z" fill="${P.amber}" opacity="0.85"/>
    <path d="M28 6l6 10M68 6l-6 10" stroke="${P.cinnabarDeep}" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M24 52q-6 10-2 20M72 52q6 10 2 20" stroke="${P.creamDim}" stroke-width="1.2" fill="none" opacity="0.35"/>`;
  return doc(96, 96, body, defs);
}

function lostVisage() {
  const defs =
    glow('lvG', 40, 40, 34, P.gray, 0.45) +
    lg('lvR', [[0, '#39445A'], [0.5, P.ash], [1, P.nightDeep]]);
  const body = `
    <circle cx="40" cy="40" r="34" fill="url(#lvG)"/>
    ${ground(40, 106, 24, 5, 0.45)}
    <path d="M40 26L14 62q0 40 4 44h44q4-4 4-44z" fill="url(#lvR)"/>
    <path d="M40 26L14 62h52z" fill="${P.inkSoft}" opacity="0.7"/>
    <path d="M20 78q20 8 40 0M18 92q22 10 44 0" stroke="${P.nightDeep}" stroke-width="1.6" fill="none" opacity="0.7"/>
    <path d="M26 14h28l4 14q-18 8-36 0z" fill="${P.ink}"/>
    <path d="M18 28h44" stroke="${P.gold}" stroke-width="1.6" opacity="0.7"/>
    <ellipse cx="40" cy="42" rx="14" ry="16" fill="${P.cream}" opacity="0.92"/>
    <ellipse cx="40" cy="42" rx="14" ry="16" fill="none" stroke="${P.gold}" stroke-width="1.6"/>
    <path d="M33 38q3 3 6 0M43 38q3 3 6 0" stroke="${P.ash}" stroke-width="1.2" fill="none" opacity="0.5"/>
    <path d="M40 46v4" stroke="${P.ash}" stroke-width="1.2" opacity="0.4"/>
    <path d="M31 30l-3 18M49 30l3 18" stroke="${P.cinnabarDeep}" stroke-width="1.2" opacity="0.55"/>
    <path d="M14 62q-8 16-4 30M66 62q8 16 4 30" stroke="${P.ash}" stroke-width="2" fill="none" opacity="0.6"/>
    ${star4(40, 8, 5, P.cream, 0.5)}`;
  return doc(80, 112, body, defs);
}

/* ---------------------------------- 武器 ---------------------------------- */

function nuoBladeArc() {
  const defs =
    lg('waG', [[0, P.cinnabar], [0.45, P.lantern], [1, P.cream]], ' x1="0" y1="1" x2="1" y2="0"') +
    glow('waL', 78, 24, 18, P.amber, 0.7);
  const body = `
    <circle cx="78" cy="24" r="18" fill="url(#waL)"/>
    <path d="M12 78A52 52 0 0 1 84 20" fill="none" stroke="${P.amber}" stroke-width="24" opacity="0.18" stroke-linecap="round"/>
    <path d="M12 78A52 52 0 0 1 84 20" fill="none" stroke="url(#waG)" stroke-width="12" stroke-linecap="round"/>
    <path d="M16 74A46 46 0 0 1 80 24" fill="none" stroke="${P.cream}" stroke-width="3" opacity="0.55" stroke-linecap="round"/>
    <path d="M28 66l-6 8M42 54l-8 6M56 44l-8 7" stroke="${P.cinnabarDeep}" stroke-width="2" opacity="0.5"/>
    <g transform="translate(80 20)">
      <path d="M-8-7q8-5 16 0l-1 10q-7 4-14 0z" fill="${P.cinnabar}"/>
      <path d="M-6 1h4M2 1h4" stroke="${P.nightDeep}" stroke-width="2" stroke-linecap="round"/>
      <path d="M-4-5q4-3 8 0" stroke="${P.gold}" stroke-width="1.4" fill="none"/>
    </g>
    ${star4(60, 14, 5, P.cream, 0.8)}
    ${star4(26, 40, 4, P.amber, 0.7)}
    ${star4(70, 44, 3.5, P.cream, 0.6)}`;
  return doc(96, 96, body, defs);
}

function lanternHalo() {
  const cx = 128, cy = 128, R = 112;
  const defs =
    rg('lhR', [[0, P.amber, 0], [0.62, P.amber, 0], [0.78, P.lantern, 0.3], [0.92, P.cinnabar, 0.12], [1, P.cinnabar, 0]], ' cx="128" cy="128" r="128"');
  let petals = '';
  for (let i = 0; i < 20; i++) {
    const a = (i / 20) * Math.PI * 2;
    const x = cx + Math.cos(a) * R;
    const y = cy + Math.sin(a) * R;
    const col = i % 2 ? P.lantern : P.cinnabar;
    petals += `<g transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${(a * 180 / Math.PI + 90).toFixed(1)})">
      <ellipse rx="8.5" ry="12.5" fill="${col}" opacity="0.9"/>
      <ellipse rx="4" ry="7.5" fill="${P.cream}" opacity="0.5"/>
      <rect x="-3" y="-15" width="6" height="2.4" fill="${P.gold}" opacity="0.85"/>
    </g>`;
  }
  let ticks = '';
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * Math.PI * 2;
    ticks += `<circle cx="${(cx + Math.cos(a) * 92).toFixed(1)}" cy="${(cy + Math.sin(a) * 92).toFixed(1)}" r="${i % 5 === 0 ? 2 : 1}" fill="${P.gold}" opacity="${i % 5 === 0 ? 0.75 : 0.4}"/>`;
  }
  const body = `<circle cx="128" cy="128" r="128" fill="url(#lhR)"/>${ticks}${petals}`;
  return doc(256, 256, body, defs);
}

function sugarLadle() {
  const defs = lg('slG', [[0, '#E6C46A'], [1, P.goldDeep]]);
  const body = `
    <path d="M42 6L18 26" stroke="${P.wood}" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M42 6L18 26" stroke="${P.woodDeep}" stroke-width="1.6" stroke-linecap="round" opacity="0.6"/>
    <circle cx="15" cy="30" r="11.5" fill="url(#slG)"/>
    <circle cx="15" cy="30" r="8.5" fill="${P.lantern}"/>
    <path d="M8 30q7 6 14 0" stroke="${P.amber}" stroke-width="2.5" fill="none"/>
    <path d="M20 37q6 6 4 10" stroke="${P.amber}" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.9"/>
    <circle cx="24" cy="46" r="2.4" fill="${P.cream}" opacity="0.85"/>
    <path d="M9 24q4-3 8 0" stroke="${P.cream}" stroke-width="1.6" fill="none" opacity="0.6"/>`;
  return doc(48, 48, body, defs);
}

function sugarThread() {
  const defs = glow('stG', 16, 8, 15, P.amber, 0.75);
  const body = `
    <ellipse cx="16" cy="8" rx="16" ry="8" fill="url(#stG)"/>
    <path d="M1 8q6-1 10-2 5-1.5 9 0 5 2 11 2" stroke="${P.lantern}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <path d="M3 8q6-1 9-1.6 5-1.4 9 .2 4 1.6 9 1.4" stroke="${P.cream}" stroke-width="1.4" fill="none" stroke-linecap="round" opacity="0.8"/>
    <circle cx="13" cy="6.6" r="1.5" fill="${P.cream}"/>
    <circle cx="22" cy="8.6" r="1.2" fill="${P.amber}"/>`;
  return doc(32, 16, body, defs);
}

function shadowPuppet() {
  const defs = lg('spG', [[0, '#E8674B'], [1, P.cinnabarDeep]], ' x1="0" y1="0" x2="1" y2="1"');
  const body = `
    <path d="M24 3q9 5 9 15 0 8-4 13l3 12h-16l3-12q-4-5-4-13 0-10 9-15z" fill="url(#spG)" opacity="0.92"/>
    <path d="M24 3q9 5 9 15 0 8-4 13l3 12h-16l3-12q-4-5-4-13 0-10 9-15z" fill="none" stroke="${P.gold}" stroke-width="1.4"/>
    <circle cx="24" cy="12" r="4" fill="${P.amber}"/>
    <path d="M20 22h8M19 27h10" stroke="${P.gold}" stroke-width="1.2" opacity="0.85"/>
    <path d="M14 16l-7-5M34 16l7-5" stroke="${P.creamDim}" stroke-width="1.3" opacity="0.7"/>
    <path d="M12 9l-6-4M36 9l6-4" stroke="${P.wood}" stroke-width="1.8" stroke-linecap="round"/>
    <circle cx="18" cy="38" r="1.6" fill="${P.cream}" opacity="0.5"/>
    <circle cx="30" cy="38" r="1.6" fill="${P.cream}" opacity="0.5"/>
    <path d="M24 40l-3 5h6z" fill="${P.gold}" opacity="0.7"/>`;
  return doc(48, 48, body, defs);
}

function paperCutBird() {
  const defs = lg('pcG', [[0, '#E1573F'], [1, P.cinnabarDeep]]);
  const body = `
    <path d="M24 6q6 3 6 9 8-2 10 4-4 3-8 2 2 8-4 14-4 4-4 8-4-6-6-6t-6 6q0-4-4-8-6-6-4-14-4 1-8-2 2-6 10-4 0-6 6-9z" fill="url(#pcG)"/>
    <path d="M24 6q6 3 6 9 8-2 10 4-4 3-8 2 2 8-4 14-4 4-4 8-4-6-6-6t-6 6q0-4-4-8-6-6-4-14-4 1-8-2 2-6 10-4 0-6 6-9z" fill="none" stroke="${P.gold}" stroke-width="1.2" opacity="0.9"/>
    <circle cx="21" cy="17" r="1.8" fill="${P.cream}" opacity="0.85"/>
    <circle cx="27" cy="17" r="1.8" fill="${P.cream}" opacity="0.85"/>
    <circle cx="24" cy="26" r="2.4" fill="${P.cream}" opacity="0.7"/>
    <path d="M15 26q4 3 5 8M33 26q-4 3-5 8" stroke="${P.amber}" stroke-width="1.3" fill="none" opacity="0.8"/>
    <path d="M24 33l-2 8 2 3 2-3z" fill="${P.amber}" opacity="0.85"/>`;
  return doc(48, 48, body, defs);
}

function ironFlowerLadle() {
  const defs =
    glow('ifG', 30, 14, 20, P.lantern, 0.7) +
    lg('ifB', [[0, '#7A7F8C'], [1, '#3B4250']]);
  let spray = '';
  const pts = [[34, 6, 2.6], [42, 10, 2.1], [44, 20, 1.8], [36, 26, 1.5], [26, 4, 1.6], [18, 10, 1.3]];
  for (const [x, y, r] of pts) spray += `<circle cx="${x}" cy="${y}" r="${r}" fill="${P.amber}" opacity="0.9"/>`;
  const body = `
    <circle cx="30" cy="14" r="20" fill="url(#ifG)"/>
    <path d="M6 42L20 30" stroke="${P.woodDeep}" stroke-width="5" stroke-linecap="round"/>
    <path d="M8 28a11 11 0 1 0 16 14 11 11 0 0 0-16-14z" fill="url(#ifB)"/>
    <path d="M11 30q6 4 12 0" stroke="${P.gold}" stroke-width="2" fill="none"/>
    <path d="M14 26q6-8 16-10" stroke="${P.lantern}" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.9"/>
    <path d="M22 20q8-6 18-6" stroke="${P.cream}" stroke-width="1.6" fill="none" stroke-linecap="round" opacity="0.7"/>
    ${spray}`;
  return doc(48, 48, body, defs);
}

/* ---------------------------------- 掉落物 --------------------------------- */

function lightBloom() {
  const defs = glow('lbG', 12, 12, 12, P.amber, 0.8);
  const body = `
    <circle cx="12" cy="12" r="12" fill="url(#lbG)"/>
    <path d="M12 2q3 5 0 10-3-5 0-10zM12 22q3-5 0-10-3 5 0 10zM2 12q5-3 10 0-5 3-10 0zM22 12q-5-3-10 0 5 3 10 0z" fill="${P.cream}" opacity="0.9"/>
    <circle cx="12" cy="12" r="3.6" fill="${P.lantern}"/>
    <circle cx="12" cy="12" r="1.8" fill="${P.cream}"/>`;
  return doc(24, 24, body, defs);
}

function goldSparkItem() {
  const defs = glow('gsG', 15, 15, 15, P.gold, 0.8);
  const body = `
    <circle cx="15" cy="15" r="15" fill="url(#gsG)"/>
    ${star4(15, 15, 13, P.amber, 0.95)}
    ${star4(15, 15, 8, P.cream, 0.9)}
    <circle cx="15" cy="15" r="3.2" fill="${P.lantern}"/>
    <circle cx="9" cy="8" r="1.4" fill="${P.cream}" opacity="0.8"/>
    <circle cx="22" cy="20" r="1.2" fill="${P.cream}" opacity="0.7"/>`;
  return doc(30, 30, body, defs);
}

function craftBox() {
  const defs = lg('cbW', [[0, '#7A5133'], [1, P.woodDeep]]);
  const body = `
    ${ground(22, 38, 17, 3, 0.35)}
    <path d="M4 14q18-9 36 0v20q-18 6-36 0z" fill="url(#cbW)"/>
    <path d="M4 14q18-9 36 0" fill="none" stroke="${P.gold}" stroke-width="1.8"/>
    <rect x="4" y="21" width="36" height="3.4" fill="${P.gold}" opacity="0.85"/>
    <rect x="18" y="18" width="8" height="9" rx="1.6" fill="${P.amber}"/>
    <circle cx="22" cy="22.5" r="1.6" fill="${P.woodDeep}"/>
    <path d="M10 28h6M28 28h6" stroke="${P.creamDim}" stroke-width="1.2" opacity="0.5"/>
    <path d="M14 8q8-4 16 0" stroke="${P.cinnabar}" stroke-width="2" fill="none"/>`;
  return doc(44, 40, body, defs);
}

function copperCoin() {
  const defs = lg('ccG', [[0, '#EBC86F'], [1, P.goldDeep]]);
  const body = `
    <circle cx="12" cy="12" r="10.5" fill="url(#ccG)"/>
    <circle cx="12" cy="12" r="10.5" fill="none" stroke="${P.woodDeep}" stroke-width="1.2" opacity="0.6"/>
    <rect x="8.6" y="8.6" width="6.8" height="6.8" fill="${P.nightDeep}" opacity="0.85"/>
    <path d="M12 2v4M12 18v4M2 12h4M18 12h4" stroke="${P.cream}" stroke-width="1.2" opacity="0.45"/>`;
  return doc(24, 24, body, defs);
}

function ciba() {
  const defs = lg('ciG', [[0, '#F0C778'], [1, P.amber]]);
  const body = `
    ${ground(18, 32, 14, 3, 0.32)}
    <path d="M2 24q16-6 32 0l-3 8H5z" fill="#9A7B43"/>
    <path d="M6 26h24M5 30h26" stroke="${P.woodDeep}" stroke-width="1" opacity="0.5"/>
    <circle cx="13" cy="19" r="7" fill="url(#ciG)"/>
    <circle cx="24" cy="20" r="6" fill="url(#ciG)"/>
    <circle cx="19" cy="13" r="5.5" fill="${P.cream}" opacity="0.9"/>
    ${specks(36, 20, 14, 5, P.cinnabarDeep, 0.5, 0.7)}
    <path d="M10 6q3-4 0-7M18 4q3-3 0-6M26 6q3-4 0-7" stroke="${P.cream}" stroke-width="1.4" fill="none" opacity="0.35"/>`;
  return doc(36, 36, body, defs);
}

function firecracker() {
  const defs = glow('fcG', 26, 8, 12, P.lantern, 0.8);
  const body = `
    <circle cx="26" cy="8" r="12" fill="url(#fcG)"/>
    <rect x="6" y="12" width="8" height="22" rx="1.6" fill="${P.cinnabar}"/>
    <rect x="15" y="9" width="8" height="25" rx="1.6" fill="#D9503F"/>
    <rect x="24" y="12" width="8" height="22" rx="1.6" fill="${P.cinnabar}"/>
    <path d="M6 17h8M15 14h8M24 17h8M6 28h8M15 26h8M24 28h8" stroke="${P.gold}" stroke-width="1.6" opacity="0.85"/>
    <path d="M10 12q3-5 8-5M19 9q4-4 7-2M28 12q-2-5 3-7" stroke="${P.creamDim}" stroke-width="1.2" fill="none"/>
    ${star4(30, 6, 4.5, P.cream, 0.95)}
    <circle cx="33" cy="9" r="1.6" fill="${P.amber}"/>`;
  return doc(36, 36, body, defs);
}

function bronzeBell() {
  const defs = lg('bbG', [[0, '#7FB0A6'], [0.5, P.teal], [1, P.tealDeep]]);
  const body = `
    ${ground(18, 33, 11, 2.6, 0.3)}
    <path d="M18 5q9 0 10 12l2 10H6l2-10Q9 5 18 5z" fill="url(#bbG)"/>
    <path d="M6 27h24" stroke="${P.gold}" stroke-width="2.2"/>
    <path d="M15 3h6v3h-6z" fill="${P.gold}"/>
    <circle cx="18" cy="30" r="2.4" fill="${P.amber}"/>
    <path d="M12 14h12" stroke="${P.nightDeep}" stroke-width="1.2" opacity="0.4"/>
    <path d="M28 10q4 4 4 10M8 10q-4 4-4 10" stroke="${P.cream}" stroke-width="1.6" fill="none" opacity="0.45"/>
    <path d="M32 6q6 6 6 14M4 6q-6 6-6 14" stroke="${P.cream}" stroke-width="1.2" fill="none" opacity="0.25"/>`;
  return doc(36, 36, body, defs);
}

/* ---------------------------------- 地面 ---------------------------------- */

function stoneTile() {
  const rand = mulberry(90210);
  const defs = lg('stBase', [[0, '#1B2A3E'], [1, '#141F30']]);
  let stones = '';
  const rows = [
    { y: 2, h: 60, xs: [0, 96, 172], w: [94, 74, 82] },
    { y: 64, h: 56, xs: [0, 66, 158], w: [64, 90, 96] },
    { y: 122, h: 62, xs: [0, 110, 190], w: [108, 78, 64] },
    { y: 186, h: 68, xs: [0, 80, 166], w: [78, 84, 88] },
  ];
  for (const r of rows) {
    for (let i = 0; i < r.xs.length; i++) {
      const x = r.xs[i], w = r.w[i];
      const lit = 0.05 + rand() * 0.09;
      stones += `<rect x="${x}" y="${r.y}" width="${w}" height="${r.h}" fill="${P.cream}" opacity="${lit.toFixed(3)}"/>`;
      stones += `<rect x="${x}" y="${r.y}" width="${w}" height="${r.h}" fill="none" stroke="${P.nightDeep}" stroke-width="2" opacity="0.55"/>`;
      const cx = x + w / 2, cy = r.y + r.h / 2;
      stones += `<path d="M${(cx - 8).toFixed(0)} ${cy.toFixed(0)}q8 -6 16 0" stroke="${P.nightDeep}" stroke-width="1" fill="none" opacity="0.3"/>`;
    }
  }
  const body = `
    <rect width="256" height="256" fill="url(#stBase)"/>
    ${stones}
    ${hatch(0, 0, 256, 256, 9, P.cream, 0.015)}
    ${specks(256, 256, 90, 1337, P.cream, 0.06)}
    <g opacity="0.5">
      <circle cx="206" cy="92" r="15" fill="#101B2A" stroke="${P.gray}" stroke-width="1.6"/>
      <path d="M196 88h20M196 96h20M202 82v20M210 82v20" stroke="${P.gray}" stroke-width="1.2"/>
    </g>
    <path d="M0 0h256" stroke="${P.cream}" stroke-width="2" opacity="0.05"/>`;
  return doc(256, 256, body, defs);
}

/* ---------------------------------- 道具 ---------------------------------- */

function lanternStand() {
  const defs = glow('lsG', 24, 20, 20, P.lantern, 0.7);
  const body = `
    <circle cx="24" cy="20" r="20" fill="url(#lsG)"/>
    ${ground(24, 58, 14, 3, 0.35)}
    <path d="M8 56h32M12 56l4-16h16l4 16" fill="none" stroke="${P.woodDeep}" stroke-width="3"/>
    <path d="M24 30V14" stroke="${P.wood}" stroke-width="3"/>
    <rect x="15" y="6" width="18" height="16" rx="2.5" fill="${P.lantern}"/>
    <rect x="15" y="6" width="18" height="16" rx="2.5" fill="none" stroke="${P.woodDeep}" stroke-width="1.6"/>
    <rect x="19" y="9" width="10" height="10" fill="${P.cream}" opacity="0.75"/>
    <path d="M13 4h22" stroke="${P.gold}" stroke-width="2.4"/>
    <path d="M24 22v6" stroke="${P.cinnabar}" stroke-width="1.8"/>
    <path d="M22 28h4l-2 6z" fill="${P.cinnabar}"/>`;
  return doc(48, 60, body, defs);
}

function bambooBasket() {
  const defs = lg('bbtG', [[0, '#B79256'], [1, '#7C6033']]);
  const body = `
    ${ground(24, 54, 16, 3, 0.34)}
    <path d="M8 20h32l-4 32H12z" fill="url(#bbtG)"/>
    <path d="M8 20h32" stroke="${P.woodDeep}" stroke-width="2.4"/>
    ${hatch(10, 26, 28, 24, 5, P.woodDeep, 0.28, 1.4)}
    <path d="M12 8h24l-2 12H14z" fill="#A3824C"/>
    <path d="M14 10h20" stroke="${P.cream}" stroke-width="1.4" opacity="0.5"/>
    <path d="M17 4q7-4 14 0" stroke="${P.woodDeep}" stroke-width="1.8" fill="none"/>`;
  return doc(48, 56, body, defs);
}

function stoneLamp() {
  const defs = glow('slG', 24, 26, 14, P.cream, 0.45);
  const body = `
    <circle cx="24" cy="26" r="14" fill="url(#slG)"/>
    ${ground(24, 54, 14, 3, 0.35)}
    <path d="M6 46h36l-3 8H9z" fill="#5E6A7C"/>
    <rect x="19" y="34" width="10" height="14" fill="#6B7A8F"/>
    <path d="M12 20h24l-3 16H15z" fill="#7C8BA1"/>
    <rect x="18" y="24" width="12" height="9" rx="1.5" fill="${P.nightDeep}"/>
    <ellipse cx="24" cy="29.5" rx="3" ry="3.5" fill="${P.amber}" opacity="0.9"/>
    <path d="M8 18h32l-4-6H12z" fill="#5E6A7C"/>
    <path d="M24 8q4-4 0-6-4 2 0 6z" fill="${P.cream}" opacity="0.55"/>`;
  return doc(48, 56, body, defs);
}

function goodsCart() {
  const defs = lg('gcW', [[0, '#7A5133'], [1, P.woodDeep]]);
  const body = `
    ${ground(40, 56, 28, 4, 0.36)}
    <path d="M10 22h56l-4 22H14z" fill="url(#gcW)"/>
    <path d="M10 22h56" stroke="${P.gold}" stroke-width="1.6" opacity="0.6"/>
    ${hatch(12, 26, 52, 16, 6, P.woodDeep, 0.35, 1.6)}
    <circle cx="24" cy="46" r="9" fill="#4A3320" stroke="${P.gold}" stroke-width="1.8"/>
    <path d="M24 37v18M15 46h18M18 40l12 12M30 40l-12 12" stroke="${P.gold}" stroke-width="1.1" opacity="0.8"/>
    <path d="M46 10h12v14H46z" fill="${P.tealDeep}"/>
    <path d="M46 10h12" stroke="${P.cream}" stroke-width="1.4" opacity="0.5"/>
    <ellipse cx="52" cy="8" rx="7" ry="3" fill="${P.cinnabar}"/>
    <path d="M6 16l8 6" stroke="${P.wood}" stroke-width="3.4" stroke-linecap="round"/>`;
  return doc(80, 60, body, defs);
}

function sugarStall() {
  const defs =
    glow('ssG', 32, 56, 26, P.amber, 0.5) +
    lg('ssW', [[0, '#7A5133'], [1, P.woodDeep]]);
  const body = `
    <circle cx="32" cy="56" r="26" fill="url(#ssG)"/>
    ${ground(32, 92, 22, 4, 0.36)}
    <path d="M6 6h52l-4 8H10z" fill="${P.cinnabar}"/>
    <path d="M10 14h44" stroke="${P.cream}" stroke-width="1.2" opacity="0.4"/>
    <path d="M10 6V2M54 6V2" stroke="${P.wood}" stroke-width="2"/>
    <rect x="12" y="16" width="3.5" height="44" fill="${P.wood}"/>
    <rect x="48" y="16" width="3.5" height="44" fill="${P.wood}"/>
    <path d="M8 60h48l-4 14H12z" fill="url(#ssW)"/>
    <rect x="14" y="34" width="36" height="24" rx="2" fill="${P.cream}" opacity="0.85"/>
    <path d="M22 52q4-14 12-8 6 4 2 10-4 5-8-1-3-5-4 4" stroke="${P.amber}" stroke-width="2.4" fill="none" stroke-linecap="round"/>
    <circle cx="42" cy="40" r="3" fill="${P.gold}"/>
    <path d="M18 30q6-6 12 0" stroke="${P.cinnabar}" stroke-width="1.6" fill="none" opacity="0.7"/>`;
  return doc(64, 96, body, defs);
}

/* ---------------------------------- 特效 ---------------------------------- */

function goldSparkFx() {
  const defs = glow('gfG', 16, 16, 16, P.amber, 0.85);
  const body = `
    <circle cx="16" cy="16" r="16" fill="url(#gfG)"/>
    ${star4(16, 16, 14, P.cream, 0.95)}
    ${star4(16, 16, 7, P.amber, 0.9)}
    <circle cx="16" cy="16" r="2.6" fill="${P.cream}"/>
    <circle cx="6" cy="8" r="1.6" fill="${P.gold}" opacity="0.8"/>
    <circle cx="26" cy="24" r="1.4" fill="${P.gold}" opacity="0.7"/>`;
  return doc(32, 32, body, defs);
}

function kailianBurst() {
  const defs = glow('kbG', 24, 24, 24, P.lantern, 0.9);
  let rays = '';
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    const r1 = 12, r2 = i % 2 ? 21 : 24;
    rays += `<path d="M${(24 + Math.cos(a) * r1).toFixed(1)} ${(24 + Math.sin(a) * r1).toFixed(1)}L${(24 + Math.cos(a + 0.09) * r2).toFixed(1)} ${(24 + Math.sin(a + 0.09) * r2).toFixed(1)}L${(24 + Math.cos(a - 0.09) * r2).toFixed(1)} ${(24 + Math.sin(a - 0.09) * r2).toFixed(1)}Z" fill="${i % 2 ? P.amber : P.cream}" opacity="${i % 2 ? 0.75 : 0.95}"/>`;
  }
  const body = `
    <circle cx="24" cy="24" r="24" fill="url(#kbG)"/>
    ${rays}
    ${star4(24, 24, 13, P.cream, 1)}
    <circle cx="24" cy="24" r="5" fill="${P.lantern}"/>
    <circle cx="24" cy="24" r="2.4" fill="${P.cream}"/>`;
  return doc(48, 48, body, defs);
}

/* ---------------------------------- UI ---------------------------------- */

function bgNightMarket() {
  const defs =
    lg('bgS', [[0, '#0A1220'], [0.55, P.night], [1, '#1C2B41']]) +
    glow('bgM', 540, 190, 150, P.cream, 0.35) +
    lg('bgFade', [[0, P.nightDeep, 0], [1, P.nightDeep, 0.92]]);
  let roofs = '';
  const rand = mulberry(2026);
  let x = -20;
  while (x < 740) {
    const w = 60 + rand() * 70;
    const h = 40 + rand() * 50;
    const y = 620 - h;
    roofs += `<path d="M${x.toFixed(0)} ${y.toFixed(0)}h${w.toFixed(0)}v${h.toFixed(0)}H${x.toFixed(0)}z" fill="#182742"/>`;
    roofs += `<path d="M${(x - 8).toFixed(0)} ${y.toFixed(0)}q${(w / 2).toFixed(0)} -${(14 + rand() * 10).toFixed(0)} ${w.toFixed(0)} 0" fill="#22344F"/>`;
    const wins = Math.floor(w / 26);
    for (let i = 0; i < wins; i++) {
      if (rand() > 0.5) continue;
      roofs += `<rect x="${(x + 10 + i * 26).toFixed(0)}" y="${(y + 16 + rand() * 14).toFixed(0)}" width="8" height="10" fill="${P.lantern}" opacity="${(0.45 + rand() * 0.45).toFixed(2)}"/>`;
    }
    x += w + 4;
  }
  const body = `
    <rect width="720" height="1280" fill="url(#bgS)"/>
    <circle cx="540" cy="190" r="150" fill="url(#bgM)"/>
    ${moon(540, 190, 40)}
    ${specks(720, 620, 220, 777, P.cream, 0.35, 0.9)}
    <path d="M0 640q180-40 360-10t360-20v670H0z" fill="#101B2E" opacity="0.9"/>
    ${roofs}
    ${lanternString(40, 560, 680, 540, 14, 88, 2.2)}
    <path d="M60 700q-10-90 20-140-24 40-14 140z" fill="#0A1322"/>
    <path d="M76 700q4-110 40-160-30 60-28 160z" fill="#0A1322" opacity="0.8"/>
    <rect y="900" width="720" height="380" fill="url(#bgFade)"/>`;
  return doc(720, 1280, body, defs);
}

function uiLanternFrame() {
  const defs = lg('ufW', [[0, '#6B4630'], [1, P.woodDeep]]);
  const body = `
    <rect x="0" y="0" width="320" height="20" rx="9" fill="url(#ufW)"/>
    <rect x="5" y="4" width="310" height="12" rx="5" fill="${P.nightDeep}" opacity="0.8"/>
    <rect x="5" y="4" width="310" height="3" fill="${P.cream}" opacity="0.08"/>
    <path d="M0 10h6M314 10h6" stroke="${P.gold}" stroke-width="3"/>
    <circle cx="10" cy="10" r="8" fill="${P.gold}"/>
    <circle cx="310" cy="10" r="8" fill="${P.gold}"/>
    <circle cx="10" cy="10" r="4" fill="${P.cinnabar}"/>
    <circle cx="310" cy="10" r="4" fill="${P.cinnabar}"/>`;
  return doc(320, 20, body, defs);
}

function uiFlameFill() {
  // 亮度必须整体偏高：项目的 tint_progress 是乘法着色，暗底色会让任何 tint 都发脏。
  const defs = lg('ffMain', [[0, '#FFFFFF'], [0.42, '#FFF0DA'], [0.72, '#F0D8B4'], [1, '#CFB48E']]);
  const body = `
    <rect x="0" y="0" width="312" height="12" rx="5" fill="url(#ffMain)"/>
    <rect x="0" y="0" width="312" height="3" rx="1.5" fill="#FFFFFF" opacity="0.55"/>
    <rect x="0" y="9" width="312" height="3" rx="1.5" fill="#8A6E4A" opacity="0.22"/>
    <path d="M14 3v6M42 3v6M70 3v6M98 3v6M126 3v6M154 3v6M182 3v6M210 3v6M238 3v6M266 3v6M294 3v6" stroke="#8A6E4A" stroke-width="1" opacity="0.18"/>`;
  return doc(312, 12, body, defs);
}

function uiPaperCard() {
  const defs =
    lg('ucP', [[0, '#FBF3DF'], [1, '#E4D3AE']]) +
    glow('ucG', 100, 92, 92, P.amber, 0.3);
  let torn = '';
  for (let i = 0; i < 24; i++) {
    const y = 14 + i * 11.2;
    torn += `<path d="M${i % 2 ? 6 : 4} ${y.toFixed(1)}l4 3-4 3z" fill="${P.woodDeep}" opacity="0.5"/>`;
    torn += `<path d="M${i % 2 ? 196 : 194} ${y.toFixed(1)}l-4 3 4 3z" fill="${P.woodDeep}" opacity="0.5"/>`;
  }
  const body = `
    <rect x="4" y="6" width="192" height="270" rx="7" fill="${P.woodDeep}"/>
    <rect x="8" y="10" width="184" height="262" rx="5" fill="url(#ucP)"/>
    ${torn}
    <circle cx="100" cy="92" r="92" fill="url(#ucG)"/>
    ${specks(200, 280, 120, 404, P.goldDeep, 0.1)}
    <rect x="18" y="20" width="164" height="242" rx="4" fill="none" stroke="${P.cinnabar}" stroke-width="1.8" opacity="0.55"/>
    <rect x="18" y="62" width="164" height="1.6" fill="${P.cinnabar}" opacity="0.35"/>
    <path d="M44 42h112" stroke="${P.ink}" stroke-width="3.4" opacity="0.5" stroke-linecap="round"/>
    <g transform="translate(168 250)">
      <rect x="-13" y="-13" width="26" height="26" rx="3" fill="${P.cinnabar}" opacity="0.9"/>
      <path d="M-7-6h14M0-6v12M-5 5h10" stroke="${P.cream}" stroke-width="2.2"/>
    </g>`;
  return doc(200, 280, body, defs);
}

/* ---------------------------------- 导出 ---------------------------------- */

export const sprites = [
  { file: 'characters/shouyiren_front.svg', old: 'characters/player_front.svg', w: 64, h: 80, tier: 'P0', title: '阿满·正面', svg: shouyirenFront() },
  { file: 'characters/shouyiren_back.svg', old: 'characters/player_back.svg', w: 64, h: 80, tier: 'P0', title: '阿满·背面（提灯）', svg: shouyirenBack() },

  { file: 'enemies/paper_scrap.svg', old: 'enemies/enemy_cup.svg', w: 48, h: 48, tier: 'P0', title: '纸屑', svg: paperScrap() },
  { file: 'enemies/broken_kite.svg', old: 'enemies/enemy_cup_fast.svg', w: 48, h: 48, tier: 'P0', title: '断线纸鸢（保留青色速度预警）', svg: brokenKite() },
  { file: 'enemies/broken_puppet.svg', old: 'enemies/enemy_bag.svg', w: 48, h: 48, tier: 'P0', title: '断线傀儡', svg: brokenPuppet() },
  { file: 'enemies/ink_blob_elite.svg', old: 'enemies/enemy_elite_box.svg', w: 96, h: 96, tier: 'P0', title: '墨渍·精英', svg: inkBlobElite() },
  { file: 'enemies/faceless_nuo_elite.svg', old: 'enemies/enemy_elite_red.svg', w: 96, h: 96, tier: 'P0', title: '残面傩·精英', svg: facelessNuoElite() },
  { file: 'enemies/lost_visage.svg', old: 'enemies/enemy_reaper.svg', w: 80, h: 112, tier: 'P0', title: '失传之相', svg: lostVisage() },

  { file: 'weapons/nuo_blade_arc.svg', old: 'weapons/whip_arc.svg', w: 96, h: 96, tier: 'P0', title: '傩面刀·横扫弧', svg: nuoBladeArc() },
  { file: 'weapons/lantern_halo.svg', old: 'weapons/halo_ring.svg', w: 256, h: 256, tier: 'P0', title: '花灯·光环', svg: lanternHalo() },
  { file: 'weapons/sugar_ladle.svg', old: 'weapons/wand_glowstick.svg', w: 48, h: 48, tier: 'P0', title: '糖画·铜勺', svg: sugarLadle() },
  { file: 'weapons/sugar_thread.svg', old: 'weapons/bullet_glowstick.svg', w: 32, h: 16, tier: 'P0', title: '糖画·糖丝弹', svg: sugarThread() },
  { file: 'weapons/shadow_puppet.svg', old: 'weapons/knife_boxcutter.svg', w: 48, h: 48, tier: 'P0', title: '皮影·影人片', svg: shadowPuppet() },
  { file: 'weapons/paper_cut_bird.svg', old: 'weapons/phone_orbit.svg', w: 48, h: 48, tier: 'P0', title: '剪纸·绕身雀', svg: paperCutBird() },
  { file: 'weapons/iron_flower_ladle.svg', old: 'weapons/axe_extinguisher.svg', w: 48, h: 48, tier: 'P0', title: '打铁花·铁水勺', svg: ironFlowerLadle() },

  { file: 'items/light_bloom.svg', old: 'items/gem_blue.svg', w: 24, h: 24, tier: 'P0', title: '归色·光瓣（经验）', svg: lightBloom() },
  { file: 'items/gold_spark.svg', old: 'items/gem_orange.svg', w: 30, h: 30, tier: 'P0', title: '金花·大经验（1.6 倍面积）', svg: goldSparkItem() },
  { file: 'items/craft_box.svg', old: 'items/chest.svg', w: 44, h: 40, tier: 'P0', title: '百工箱（宝箱）', svg: craftBox() },
  { file: 'items/copper_coin.svg', old: 'items/coin.svg', w: 24, h: 24, tier: 'P0', title: '铜钱', svg: copperCoin() },
  { file: 'items/ciba.svg', old: 'items/pickup_bento.svg', w: 36, h: 36, tier: 'P0', title: '糍粑（回血）', svg: ciba() },
  { file: 'items/firecracker.svg', old: 'items/pickup_bomb.svg', w: 36, h: 36, tier: 'P0', title: '爆竹（清屏）', svg: firecracker() },
  { file: 'items/bronze_bell.svg', old: 'items/pickup_magnet.svg', w: 36, h: 36, tier: 'P0', title: '铜铃（磁吸）', svg: bronzeBell() },

  { file: 'ground/stone_tile.svg', old: 'ground/ground_tile.svg', w: 256, h: 256, tier: 'P0', title: '夜市石板路（无缝）', svg: stoneTile() },

  { file: 'props/lantern_stand.svg', old: 'props/prop_hydrant.svg', w: 48, h: 60, tier: 'P0', title: '灯架', svg: lanternStand() },
  { file: 'props/bamboo_basket.svg', old: 'props/prop_trash.svg', w: 48, h: 56, tier: 'P0', title: '竹筐堆', svg: bambooBasket() },
  { file: 'props/stone_lamp.svg', old: 'props/prop_cone.svg', w: 48, h: 56, tier: 'P0', title: '石灯', svg: stoneLamp() },
  { file: 'props/goods_cart.svg', old: 'props/prop_bike.svg', w: 80, h: 60, tier: 'P0', title: '货郎车', svg: goodsCart() },
  { file: 'props/sugar_stall.svg', old: 'props/prop_vending.svg', w: 64, h: 96, tier: 'P0', title: '糖画摊（立幅）', svg: sugarStall() },

  { file: 'fx/gold_spark_fx.svg', old: 'fx/fx_spark.svg', w: 32, h: 32, tier: 'P0', title: '金光·打击特效', svg: goldSparkFx() },
  { file: 'fx/kailian_burst.svg', old: 'fx/fx_evolve_star.svg', w: 48, h: 48, tier: 'P0', title: '开炉·进化爆发', svg: kailianBurst() },

  { file: 'ui/bg_night_market.svg', old: 'ui/bg_city_dusk.svg', w: 720, h: 1280, tier: 'P0', title: '夜市远景背景', svg: bgNightMarket() },
  { file: 'ui/ui_lantern_frame.svg', old: 'ui/ui_bar_frame.svg', w: 320, h: 20, tier: 'P0', title: '血条外框·漆木', svg: uiLanternFrame() },
  { file: 'ui/ui_flame_fill.svg', old: 'ui/ui_bar_fill.svg', w: 312, h: 12, tier: 'P0', title: '血条填充·灯火（暖色，避免与 tint 相乘发脏）', svg: uiFlameFill() },
  { file: 'ui/ui_paper_card.svg', old: 'ui/ui_card_frame.svg', w: 200, h: 280, tier: 'P0', title: '升级卡·宣纸木版', svg: uiPaperCard() },
];
