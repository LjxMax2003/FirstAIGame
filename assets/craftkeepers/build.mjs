// 守艺人·百工夜行 —— 构建逻辑（被 generate.mjs 与 render_check 共用）
// 校验规则全部在这里，跑一次即知全部问题。
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { sprites } from './sprites.mjs';
import { scenery } from './scenery.mjs';

// 原工程 34 张素材的画布尺寸：换皮必须逐一对齐，否则 contact_r / 锚点会漂
export const EXPECT = {
  'characters/player_front.svg': [64, 80],
  'characters/player_back.svg': [64, 80],
  'enemies/enemy_cup.svg': [48, 48],
  'enemies/enemy_cup_fast.svg': [48, 48],
  'enemies/enemy_bag.svg': [48, 48],
  'enemies/enemy_elite_box.svg': [96, 96],
  'enemies/enemy_elite_red.svg': [96, 96],
  'enemies/enemy_reaper.svg': [80, 112],
  'weapons/whip_arc.svg': [96, 96],
  'weapons/halo_ring.svg': [256, 256],
  'weapons/wand_glowstick.svg': [48, 48],
  'weapons/bullet_glowstick.svg': [32, 16],
  'weapons/knife_boxcutter.svg': [48, 48],
  'weapons/phone_orbit.svg': [48, 48],
  'weapons/axe_extinguisher.svg': [48, 48],
  'items/gem_blue.svg': [24, 24],
  'items/gem_orange.svg': [30, 30],
  'items/chest.svg': [44, 40],
  'items/coin.svg': [24, 24],
  'items/pickup_bento.svg': [36, 36],
  'items/pickup_bomb.svg': [36, 36],
  'items/pickup_magnet.svg': [36, 36],
  'ground/ground_tile.svg': [256, 256],
  'props/prop_hydrant.svg': [48, 60],
  'props/prop_trash.svg': [48, 56],
  'props/prop_cone.svg': [48, 56],
  'props/prop_bike.svg': [80, 60],
  'props/prop_vending.svg': [64, 96],
  'fx/fx_spark.svg': [32, 32],
  'fx/fx_evolve_star.svg': [48, 48],
  'ui/bg_city_dusk.svg': [720, 1280],
  'ui/ui_bar_frame.svg': [320, 20],
  'ui/ui_bar_fill.svg': [312, 12],
  'ui/ui_card_frame.svg': [200, 280],
};

export function validate(all) {
  const errors = [];
  for (const a of all) {
    const svg = a.svg;
    const t = a.file;
    if (!svg.includes(`viewBox="0 0 ${a.w} ${a.h}"`)) errors.push(`${t}: viewBox 与声明尺寸不符`);
    if (!svg.trimEnd().endsWith('</svg>')) errors.push(`${t}: 未闭合`);
    if (/NaN|undefined|nullpx/.test(svg)) errors.push(`${t}: 含 NaN/undefined`);
    if (a.old && EXPECT[a.old] && (EXPECT[a.old][0] !== a.w || EXPECT[a.old][1] !== a.h))
      errors.push(`${t}: 画布 ${a.w}x${a.h} 与原素材 ${a.old} ${EXPECT[a.old].join('x')} 不一致`);
    const ids = [...svg.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
    const dup = ids.filter((x, i) => ids.indexOf(x) !== i);
    if (dup.length) errors.push(`${t}: id 重复 ${dup.join(',')}`);
    for (const r of [...svg.matchAll(/url\(#([^)]+)\)/g)].map((m) => m[1]))
      if (!ids.includes(r)) errors.push(`${t}: 悬空引用 url(#${r})`);
    // ThorVG（Godot 的 SVG 光栅器）对悬空引用会画成全透明，必须先在这里拦住
    for (const g of [...svg.matchAll(/<radialGradient[^>]*>/g)])
      if (!/gradientUnits="userSpaceOnUse"/.test(g[0])) errors.push(`${t}: radialGradient 缺 gradientUnits="userSpaceOnUse"`);
    for (const g of [...svg.matchAll(/<linearGradient[^>]*>/g)])
      if (!/x1=/.test(g[0])) errors.push(`${t}: linearGradient 缺方向坐标`);
    // 未闭合的 defs / 手写标签错误
    if ((svg.match(/<defs>/g) || []).length !== (svg.match(/<\/defs>/g) || []).length) errors.push(`${t}: defs 未闭合`);
    if ((svg.match(/<g[\s>]/g) || []).length !== (svg.match(/<\/g>/g) || []).length) errors.push(`${t}: <g> 未闭合`);
    // 禁用语法：ThorVG 支持不完整，用了就等于没画
    for (const bad of ['<text', '<clipPath', '<mask', '<filter', '<image', '@keyframes', '<style'])
      if (svg.includes(bad)) errors.push(`${t}: 含 ThorVG 支持不稳的 ${bad}`);
  }
  return errors;
}

export function build(baseDir) {
  const all = [...sprites, ...scenery];
  const errors = validate(all);
  const OUT = join(baseDir, 'art_shouyiren');
  rmSync(OUT, { recursive: true, force: true });
  const enc = new TextEncoder();
  for (const a of all) {
    const p = join(OUT, a.file);
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, a.svg, 'utf8');
  }

  const manifest = {
    theme: '守艺人·百工夜行',
    generated_at: new Date().toISOString().slice(0, 10),
    engine: 'Godot 4.7.2 / SVG 直接导入（与原素材同管线）',
    palette: {
      夜蓝: '#0F1B2D', 墨黑: '#1A1A1A', 朱砂: '#C53B2E', 灯笼橙: '#F2A03D',
      琥珀: '#E8B04B', 青绿: '#3E7C74', 米白: '#F4E8D0', 金: '#D9A441', 冷灰: '#6B7A8F',
    },
    counts: {
      reskin: sprites.length,
      new_p0: scenery.filter((s) => s.tier === 'P0').length,
      new_p1: scenery.filter((s) => s.tier === 'P1').length,
      total: all.length,
    },
    assets: all.map((a) => ({
      file: a.file, replaces: a.old, size: `${a.w}x${a.h}`, tier: a.tier, title: a.title,
      bytes: enc.encode(a.svg).length,
    })),
  };
  writeFileSync(join(baseDir, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf8');

  const groups = {};
  for (const a of all) {
    const k = a.file.split('/')[0];
    (groups[k] = groups[k] || []).push(a);
  }
  const tiles = Object.entries(groups)
    .map(
      ([g, list]) => `
  <section>
    <h2>${g} <span>${list.length}</span></h2>
    <div class="grid">
      ${list
        .map(
          (a) => `
        <figure>
          <div class="box"><img src="art_shouyiren/${a.file}" alt="${a.title}"></div>
          <figcaption><b>${a.title}</b><br><code>${a.file}</code><br>${a.w}×${a.h}${a.old ? ` ← ${a.old}` : ''} · ${a.tier}</figcaption>
        </figure>`
        )
        .join('')}
    </div>
  </section>`
    )
    .join('\n');

  writeFileSync(
    join(baseDir, '预览.html'),
    `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>守艺人·百工夜行 — 首版美术素材拼版</title>
<style>
  body{margin:0;padding:28px;background:#0B1220;color:#F4E8D0;font:14px/1.6 system-ui,"Microsoft YaHei",sans-serif}
  h1{font-size:22px;margin:0 0 6px} .sub{color:#9DB0C8;margin-bottom:22px}
  h2{font-size:15px;color:#E8B04B;border-left:3px solid #C53B2E;padding-left:8px;margin:28px 0 12px}
  h2 span{color:#6B7A8F;font-size:12px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(168px,1fr));gap:14px}
  figure{margin:0;background:#121E33;border:1px solid #23344F;border-radius:8px;padding:8px}
  .box{height:150px;display:flex;align-items:center;justify-content:center;background:repeating-conic-gradient(#16243C 0% 25%, #0F1B2D 0% 50%) 0 0/20px 20px;border-radius:5px;overflow:hidden}
  img{max-width:100%;max-height:100%;object-fit:contain}
  figcaption{font-size:11px;color:#9DB0C8;margin-top:6px;word-break:break-all}
  figcaption b{color:#F4E8D0;font-size:12px} code{color:#6B7A8F}
</style></head><body>
<h1>守艺人·百工夜行 — 首版美术素材拼版</h1>
<p class="sub">共 ${all.length} 张：${sprites.length} 张换皮（画布与原素材逐一对齐）+ ${manifest.counts.new_p0} 张 P0 新增 + ${manifest.counts.new_p1} 张 P1。棋盘格底表示透明。全部为首版程序化 SVG，供评审与二次手绘参照，尚未接入 Godot 工程。</p>
${tiles}
</body></html>`,
    'utf8'
  );

  return {
    count: all.length,
    errors,
    totalBytes: manifest.assets.reduce((s, a) => s + a.bytes, 0),
    manifest,
  };
}
