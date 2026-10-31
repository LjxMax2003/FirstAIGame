# 守艺人·百工夜行 — 首版美术资源

> 位置：`assets/craftkeepers/`
> 状态：**首版程序化 SVG 已全部产出并通过尺寸/语法自检 + Godot 实机光栅化校核**；60 张换皮图已接入 `GameDemo`（P2~P4）；L1 走路帧 10 张中**玩家的 4 张已接入**，敌人的 6 张未接。
> 边界：玩家朝向/走路帧的接线细节见 `reports/EXECUTION_LOG.md` §5（玩家操作反应）；Boss 三档美术仍未接线。

---

## 1. 里面有什么

| 路径 | 内容 |
|---|---|
| `art_shouyiren/` | **71 个 SVG**，按 `characters/enemies/weapons/items/ground/props/stalls/fx/ui` 分目录：生成器产出的 60 张 + 手工放入的 11 张（见下方警告） |
| `manifest.json` | 机器可读清单：新文件 → 替换的原文件、画布尺寸、优先级、标题、字节数 |
| `预览.html` | 拼版预览页（棋盘格底 = 透明），给评审和二次手绘用 |
| `校核_拼版_深色底.png` / `校核_拼版_浅色底.png` | Godot 光栅化后的实际渲染结果（55 张小图，原生尺寸） |
| `校核_大图_背景与过场.png` | 5 张 720×1280 大图（背景 / 图鉴底 / 三张过场） |
| `校核_L1帧图.png` | L1 走路帧的 4 倍放大条带（5 行 = 5 个角色，3 列 = 母图 / `_2` / `_3`） |
| `lib.mjs` `sprites.mjs` `scenery.mjs` `build.mjs` `generate.mjs` | 生成器：所有素材由代码产出，改一处即可全量重生成 |
| `render_check/` | Godot 光栅化校核用的最小工程（`project.godot` + `tools/Dump.gd` + `tools/FrameSheet.gd`） |

构成：**34 张换皮**（与原素材画布逐一对齐）+ **17 张 P0 新增** + **9 张 P1 新增**。

### ⚠ 生成器目录里有 11 个文件不在生成器里

`build()` 第一件事是 `rmSync(OUT, {recursive:true})`，所以**任何人重跑 `generate.mjs`，下面这 11 个手写文件都会被抹掉**：

- L1 走路帧 10 张（本次产出，见 §7）：`characters/shouyiren_front_2/3.svg`、`characters/shouyiren_back_2/3.svg`、`enemies/paper_scrap_2/3.svg`、`enemies/broken_kite_2/3.svg`、`enemies/broken_puppet_2/3.svg`
- `ui/ui_lantern_ticks.svg`（他人手工加入，同样未登记）

重生成前先把它们挪出去，或者按 §7 的交接说明登记进 `sprites.mjs`。

---

## 2. 为什么用代码生成而不是直接画

原工程 34 张素材本身就是手写 SVG（`viewBox` + 基础图元 + 渐变），并且数值契约对画布尺寸敏感：
`contact_r`、贴图留白比例、`draw_scale`、光环 332px 缩放方案，全都锚在固定尺寸上。
任何一张尺寸漂了，碰撞判定和视觉就会不一致。

所以首版用生成器产出，换来三件确定性的事：

1. **尺寸不可能漂**：`build.mjs` 的 `EXPECT` 表把 34 个原尺寸写死，不符就报错退出。
2. **风格不会散**：色板、接触阴影、光晕、撕纸边、木版排线全部收敛在 `lib.mjs` 的公共函数里。
3. **可迭代**：美术接手时不用重画，改参数（半径、色阶、密度）重跑即可对比。

这些是**首版可用素材**，不是终版手绘。定位见 §6。

---

## 3. 重新生成

```bash
cd assets/craftkeepers
node generate.mjs        # 需要 PATH 里有 node；本机没有，见下
```

本机 `node` 不在 PATH 上，实际产出是用 Qoder 内置 Node 内核跑 `build.mjs` 的 `build()` 完成的：

```js
const b = await import('file:///<绝对路径>/build.mjs');
const r = b.build('<美术资源绝对路径>');
console.log(r.count, r.errors);
```

两条路径跑的是同一份 `build.mjs`，产物一致。

### 自检项（`build()` 里的 `validate()`，任一不过即退出码非 0）

- `viewBox` 与声明尺寸一致；SVG 闭合；无 `NaN`/`undefined`
- 34 张换皮的画布与原素材逐一对齐（查 `EXPECT` 表）
- `id` 文件内唯一；所有 `url(#x)` 都能解析（**Godot 的 ThorVG 对悬空引用直接画成透明**）
- `radialGradient` 必须带 `gradientUnits="userSpaceOnUse"`（默认是 `objectBoundingBox`，光晕的 cx/cy/r 会被当成比例值画到框外 → 看不见）
- `linearGradient` 必须显式给方向（默认是横向，而这套素材的明暗语言是顶亮底暗）
- `<defs>` / `<g>` 成对闭合
- 禁用 `<text>` `<clipPath>` `<mask>` `<filter>` `<image>` `<style>` `@keyframes`——ThorVG 支持不完整，用了等于没画

---

## 4. 视觉校核怎么做的

本机没有可用的无头浏览器，所以用工程里已有的 Godot 4.7.2 直接光栅化：

```bash
GODOT=/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe
cd assets/craftkeepers
rm -rf render_check/art && cp -r art_shouyiren render_check/art
cd render_check
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tools/Dump.gd
```

`Dump.gd` 把每张 SVG 以**原生像素尺寸**贴进深色底 / 浅色底两张拼版（大图单独一张），
顺带打印每张的实测宽高——这是尺寸对齐的**独立验证**（不依赖生成器自己的声明）。

本轮实测结果：60 张全部加载成功，宽高与 `manifest.json` 完全一致。
L1 帧图加入后复跑：`svg found: 71`，10 张帧图实测 64×80 / 48×48 与母图一致，无加载失败。

帧图另有专用条带校核（4 倍放大 + 帧间差异占比）：

```bash
"$GODOT" --headless --path . --script res://tools/FrameSheet.gd   # 产出 frames_l1.png
```

### 校核中发现并已修掉的 6 个问题

| 问题 | 症状 | 修法 |
|---|---|---|
| 径向渐变单位错 | 所有光晕（灯笼/经验/特效）画成透明，等于没灯 | `rg()` 统一加 `gradientUnits="userSpaceOnUse"` |
| 线性渐变方向错 | 木纹/纸张/血条的顶亮底暗变成左亮右暗 | `lg()` 默认竖向，需要别的方向时显式传 |
| 血条填充底色太暗 | 与运行时 `tint` 相乘后发脏（阶段一踩过的坑） | `ui_flame_fill.svg` 整体提亮到近白，把颜色交给 tint |
| 升级卡读成"一团纸" | 用 `blobPath` 做 200×280 卡片，出来是个圆角八边形 | 改回圆角矩形 + 两侧撕口 + 朱砂双框 |
| 月亮读成日食 | 用暗圆压亮圆做月牙，深色底上是黑圈咬白圈 | 新增 `moon()`：同心圆光晕 + 两处月影 |
| 远景屋顶看不见 | 屋顶色与夜空色差 < 3 级，整张背景糊成一块 | 屋顶提到 `#182742`、檐口 `#22344F`，窗光不透明度提到 0.45~0.9 |

---

## 5. 落地接入清单（**尚未执行**）

真要换皮时按这个顺序做，每步都能单独回归：

1. 复制 `art_shouyiren/` → `GameDemo/first-xi-xue-gui/assets/art_shouyiren/`（**不要覆盖 `assets/art/`**，保留回退位）。
2. 改 `scripts/Art.gd` 的 34 个路径常量 + `PROP_LIST` + `ENEMY_LIST`。
3. 改 `scripts/WeaponDB.gd` 的 `svg`/`bullet_svg`、`scripts/EvolutionDB.gd` 的 `svg`、`scripts/PickupField.gd` 的 `svg`。
4. 改 7 个 `.tscn` 的 `ext_resource`：`Player` `Enemy` `Gem` `Game` `ui/HUD` `ui/PauseUI` `ui/DeathUI`。
5. `--import` 后跑 `SmokeTest.tscn`，**284 项必须全绿**（2026-10-27 实测基线 284/284、exit 0；只换图不改数值，任何一项变红都说明尺寸或路径错了）。
6. 新增的摊位/牌坊/戏台/Boss 图先只进 `PropField`/`ResourceField` 的白名单，不动数值。

## 6. 已知待改进（下一轮手绘重点）

1. **5 个摊位剪影过于接近**：共用同一套雨棚+案板，远看只靠颜色区分。需要给每个摊位一个独占轮廓符号（糖画的圆鏊、皮影的亮幕、铁花的炉口）。
2. **5 张立绘几乎同一张脸**：P1 占位，帽子/手持物不同但脸型脸型与袍色全同。
3. **快速兵预警仍偏弱**：`broken_kite.svg` 的青色拖尾在 48px 下能看见，但不如原方案的"亮青描边 + 拖尾"强；实施时仍需在 `Enemy.gd` 里加轮廓光，不能只靠贴图。
4. **`boss_warning_ring.svg` 用了 `stroke-dasharray`**：ThorVG 新版本支持，旧版本可能画成实线。真机验证前，预警圈优先用引擎侧 `draw_arc` + 虚线材质。
5. **光环贴图仍是 256×256**：`美术资产映射.md` §3 的 332px 方案（贴图放大 ×1.2873）需要美术单独出一版，本次未产出。
6. **过场图无人物**：三张 `intro_*.svg` 是"空场景 + 一盏灯"的构图，标题文字留给 UI 层画（ThorVG 的 `<text>` 不可靠）。要商店页级别的插画仍需人工。

---

## 7. L1 走路帧（玩家 4 张已接，敌人 6 张待接）

`动画实施方案.md` §5.3 的 10 张帧图已产出，直接放在各自母图旁边：

| 母图 | 帧 2 | 帧 3 | 实测帧间差异 | 动的部分 |
|---|---|---|---|---|
| `characters/shouyiren_front.svg` | `_2.svg` | `_3.svg` | 43.6% / 36.5% | 双腿交替 + 上身 bob + 提灯手臂前后摆（光晕跟灯走） |
| `characters/shouyiren_back.svg` | `_2.svg` | `_3.svg` | 42.9% / 36.4% | 同上，背包/发髻不动，灯笼举臂摆动 |
| `enemies/paper_scrap.svg` | `_2.svg` | `_3.svg` | 64.1% / 70.3% | 整体 ±4~5° 翻转 + 纸团轮廓重画 |
| `enemies/broken_kite.svg` | `_2.svg` | `_3.svg` | 54.4% / 53.2% | 机身倾斜 + 尾翼甩动 + 风痕位移/透明度 |
| `enemies/broken_puppet.svg` | `_2.svg` | `_3.svg` | 51.4% / 46.1% | 提线偏移 + 木偶倾斜 + 双腿交替 |

**已保证的契约**（程序侧不必再验，但改动时应保持）：

1. 画布与母图逐像素同尺寸（64×80 / 48×48），`viewBox` 一致 → `Enemy.gd:69` 的 `size`、`:72` 的 `touch_radius`、`:74` 的 `offset` 不会漂。
2. 图元数量与母图完全相同（25/22/25/14/14），只加 `<g transform>` 包裹，不增删元素。
3. 接触阴影 `ellipse fill="#08111E"` 与母图**逐字节相同**且不被 transform 包裹 → 脚底锚点不动，帧切换不会上下跳。
4. 通过 `build.mjs` 的 `validate()`：0 错误（含悬空 `url(#id)`、`gradientUnits`、`<g>` 配对、ThorVG 禁用语法）。

**程序侧待办（本目录之外）**：

- **玩家 4 张已完成**（`Art.ALL_PATHS` + `SLOT_ALIASES` 独立槽位 + `Player.gd` 四向朝向/步频轮播 + `SmokeTest` 12 条断言，见 `reports/EXECUTION_LOG.md` §5（玩家操作反应））。剩下敌人 3 组 6 张照同一套做即可。

- 帧图目前**不在生成器里**，重跑 `generate.mjs` 会连它们一起删掉（§1 警告）。要长期保留，需把姿态参数并进 `sprites.mjs`（母图函数加一个 `pose` 入参），并把 10 个 `file:` 条目加进导出数组。
- `Art.gd`：10 个路径进 `ALL_PATHS`（当前 62-71），并在 `SLOT_ALIASES`（93-106）里把 `shouyiren_front_2/3` 等映射到既有槽位——`SmokeTest.gd:472-478` 的槽位断言按**文件名主干精确比对**，不登记就会红。
- 切帧逻辑按 `动画实施方案.md` §5.3：`idx = int(_walk * 1.2 + _pool_index) % 3`，玩家 10fps、杂兵 8fps；出怪首帧仍是无后缀母图。
- 建议给 `SmokeTest.gd` 加第 13 项：切帧 1 秒后贴图仍命中同槽位。

> 若 `paper_scrap` 两帧在 8fps 下读成"闪烁"而不是"飘动"，把 `_2/_3` 的轮廓重画去掉，只保留 `rotate(±4~5°)`——差异占比会从 64~70% 掉到 20% 左右。

---

> **一句话**：60 张能跑、能看、尺寸锁死的 SVG 已经就位，L1 的 10 张走路帧也已按同一套锚点放进去；剩下的是一轮真正的手绘升级 + 程序侧登记，而不是从零开始画。

