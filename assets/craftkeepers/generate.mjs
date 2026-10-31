// 守艺人·百工夜行 —— 素材生成入口
// 用法：node generate.mjs        （需要 PATH 里有 node）
// 产物：art_shouyiren/**.svg、manifest.json、预览.html
// 校验规则见 build.mjs 的 validate()；任何一项不过都会以非 0 退出。
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from './build.mjs';

const r = build(join(dirname(fileURLToPath(import.meta.url))));
console.log(`生成 ${r.count} 个 SVG，共 ${(r.totalBytes / 1024).toFixed(1)} KB`);
if (r.errors.length) {
  console.log('校验失败：');
  for (const e of r.errors) console.log('  - ' + e);
  process.exit(1);
}
console.log('校验通过：尺寸对齐 / viewBox / 渐变单位 / 引用完整 / 无 ThorVG 不稳语法');
