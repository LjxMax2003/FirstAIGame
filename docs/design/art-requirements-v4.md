# 《守艺人·百工夜行》v4 美术需求（AI 执行版）

> 输入：`docs/design/skills-and-midgame-v4.md`（技能扩充与中期难度 v4）
> 本文只定义**美术需求、优先级、尺寸、锚点、验收标准**，**不生成任何图片**。下一步按 §9 的指令再产出。
> 主要读者：下一个负责生图 / 画 SVG / 接线的 AI。人类美术可作为审阅清单。
>
> **结论：P0 17 张、P1 5 张、P2 5 张，共 27 张。**
> P0 不做，v4 的新机制在实机里会“看不见 / 认不出”；P1 是辨识度与手感补强；P2 是氛围与长线打磨。

---

## 0. 先读这段（AI 速览）

| 项目 | 结论 |
|---|---|
| 美术方向 | 夜蓝底上的一盏暖灯；纸、木、铜、墨四种材质；木刻平涂 + 宣纸纤维；轮廓先于细节 |
| 风格红线 | 敌人冷、玩家暖；无血腥；无真实宗教/祭祀；无文字；无霓虹/科幻/3D/写实 |
| 交付格式 | **优先 SVG**（Godot 4.7.2 直接导入，同现有管线）；若工具只能出位图，按画布 4× 输出透明 PNG，再描摹/重绘成 SVG，不能直接缩小位图当最终资产 |
| 输出根目录 | `assets/craftkeepers/art_shouyiren/` |
| 运行时镜像 | `GameDemo/first-xi-xue-gui/assets/art_shouyiren/` |
| 命名 | 全小写、下划线、`.svg`；不用中文文件名、空格、版本号后缀 |
| P0 数量 | 17 张（3 武器共 7 张 + 2 被动共 2 张 + 结界 3 张 + 浆壳兵 3 张 + 更鼓 2 张） |
| P1 数量 | 5 张（2 进化世界贴图 + 回春跳字 + 壳裂纹 + HUD 护盾点） |
| P2 数量 | 5 张（年画小冲击 + 2 进化爆发 + 鼓楼摆件 + 壳碎死亡） |
| 不要做 | 不重绘旧 34 张、不新增 Boss/地图/摊位、不做音频、不做数值改动、不做 UI 大改版 |
| 关键尺寸 | 图标 48×48；光环 256×256；墨线 256×32；年画落点 256×256；护盾 128×128；敌人壳 48×48；更鼓波纹 256×256 |
| 关键锚点 | 图标居中；墨线左中；光环/落点/波纹居中；浆壳兵脚底 `y=44` 与母图一致 |

**一句话**：这 27 张不是“再画一套国风素材”，而是让 v4 的 5 个新机制在 720×1280、48px 敌人、同屏 300+ 的条件下**一眼能认出、一眼能判断**。

---

## 1. 从 v4 到美术需求的映射

| v4 功能 | P0（不做就看不懂） | P1（辨识度/手感） | P2（氛围/长线） |
|---|---|---|---|
| 铜锣 `gong` | 武器图标、世界光环 | 进化「开市锣」光环 | 开市锣进化爆发 |
| 墨斗 `inkline` | 武器图标、墨线、命中墨点 | 进化「龙筋墨线」墨线 | 龙筋墨线进化爆发 |
| 木版年画 `print` | 武器图标、落点预警、落点成画 | — | 中心小冲击 |
| 回春 `regen` | 被动卡图标 | 回春跳字 | — |
| 结界 `shield` | 被动卡图标、护身罩、破罩 | HUD 护盾点 | — |
| 浆壳兵 `shelled` | 3 种结壳杂兵整图 | 受击壳裂纹 | 壳碎死亡 |
| 更鼓 `drum` | HUD 更鼓图标、跨更波纹 | — | 夜市鼓楼摆件 |

**优先级定义**

- **P0**：缺了会让新机制“无贴图 / 无反馈 / 分不清”，或代码路径直接指向空文件。必须随 v4 一起进。
- **P1**：缺了不阻塞玩法，但会让进化形态、护盾余量、回春反馈变弱。首版尽量。
- **P2**：纯氛围或低频表现，可第二版补。不得挤占 P0 工时。

---

## 2. 全局美术规范

### 2.1 美术方向（给生图模型的总提示）

> 中国非遗手艺主题的 2D 夜市民俗幻想；夜蓝底、暖灯点；纸、木、铜、墨四种材质；木刻平涂、宣纸纤维、少量金粉；轮廓清晰、层次少、颜色克制；像手艺留下的痕迹，不像魔法光效。

**统一光源**：左上暖光，右下冷影。所有新资产必须服从这一方向，否则会和现有 71 张 SVG 脱节。

**统一材质语言**

| 材质 | 表现 |
|---|---|
| 纸 | 米白 / 米黄，撕边、纤维噪点、轻微透光 |
| 木 | 深褐木纹、木刻排线、榫卯/竹篾结构 |
| 铜 | 金铜色、深金边、少量铜绿、圆钉/铆钉 |
| 墨 | 墨黑、墨蓝黑、飞白、纸面晕染；不发光 |
| 浆 | 米白偏冷、干裂、稻草纤维；**不用暖金** |

### 2.2 色板（沿用 `assets/craftkeepers/lib.mjs`）

| 色 | 值 | 用途 |
|---|---|---|
| 夜蓝 | `#0F1B2D` | 背景/暗部 |
| 深夜 | `#08111E` | 接触阴影 |
| 墨黑 | `#1A1A1A` | 墨斗、忘影剪影 |
| 柔墨 | `#2B2F3A` | 墨线外晕 |
| 朱砂 | `#C53B2E` | 年画、印章、鼓身、绳结 |
| 深朱 | `#8E2A20` | 朱砂暗部 |
| 灯笼橙 | `#F2A03D` | 玩家灯焰/花灯 |
| 琥珀 | `#E8B04B` | 糖画/金火星 |
| 金 | `#D9A441` | 铜锣、精英、进化 |
| 深金 | `#A8781F` | 铜器暗部 |
| 青绿 | `#3E7C74` | 皮影/纸鸢/回春 |
| 深青 | `#24524C` | 青绿暗部 |
| 米白 | `#F4E8D0` | 纸/灯罩/伞面 |
| 米黄 | `#D6C4A2` | 旧纸/浆壳 |
| 冷灰 | `#6B7A8F` | 被遗忘物 |
| 灰蓝 | `#495468` | 浆壳裂纹/暗部 |
| 木褐 | `#5A3B25` | 木器 |
| 深木 | `#3B2617` | 木器暗部 |
| 亮青 | `#B8F6FF` | 快速兵速度预警（只用于快速兵） |

**用色规则**

- 玩家/掉落永远暖色；敌人与浆壳永远冷色或低饱和。新武器 FX 不得用大面积暖橙抢玩家灯。
- 铜锣/更鼓可以用金铜，但面积要小于玩家灯焰；墨斗以墨黑为主，金只做 1px 高光。
- 浆壳兵禁用 `#F2A03D` / `#E8B04B` 大面积，避免和灯花、糖画、金币混淆。
- 精英/进化可以用金/朱砂描边，但不要只靠体型区分。

### 2.3 画布、锚点与缩放

| 类型 | 画布 | 锚点 | 实机尺寸 | 说明 |
|---|---|---|---|---|
| 武器/被动图标 | 48×48 | 居中 | 卡面 68×68；HUD 槽 40×40 | 内容控制在 4–44px，留 4px 安全边 |
| 铜锣光环 | 256×256 | 居中 `(128,128)` | 直径 300px（半径 150） | 环中心线 `r≈122`，外缘 ≤127；缩放 `r*2/256` |
| 墨线 | 256×32 | 左中 `(0,16)` | 长度按实际判定拉伸 | 视觉从 `x=6` 到 `x=250`；拉伸 1–3× 不糊 |
| 年画落点 | 256×256 | 居中 `(128,128)` | 直径 210px（半径 105） | 圆/方框外缘贴 `r=124–127` |
| 护身罩 | 128×128 | 居中 `(64,64)` | 罩住 64×80 玩家 | 中心 44px 完全透明 |
| 破罩 | 96×96 | 居中 | 一次性 0.35s | 纸屑 + 竹篾 + 红线 |
| 浆壳兵 | 48×48 | 脚底 `(24,44)` | 与母图 1:1 | 接触阴影与母图逐字节一致 |
| 更鼓图标 | 48×48 | 居中 | HUD 40×40 | 24px 剪影仍可辨 |
| 更鼓波纹 | 256×256 | 居中 | 世界内扩散 | 中心透明，只画环 |
| 小特效 | 32/48/64/96 | 居中 | 一次性 | 不铺满屏幕 |

**硬规则**

1. `width` / `height` / `viewBox` 三者必须与上表完全一致；不允许“画布大一点、实机再缩”。
2. 敌人/浆壳兵不得改变母图碰撞尺寸与脚底锚点；壳层只加视觉，不动 `contact_r` / `touch_radius` / `offset`。
3. 光环、落点、护盾、波纹的**视觉外缘**必须与玩法半径对齐，误差 ≤6px；不能让玩家“看着够不到却被烧到”。
4. 所有图标必须能在 40px（HUD）和 68px（卡面）之间无损缩放；不要依赖 1px 细节传达语义。

### 2.4 48px 可读性（最高优先）

每张敌人/图标必须通过三步：

1. 缩到目标尺寸（敌人 48px，图标 40px）；
2. 填充纯黑，看剪影；
3. 能区分“它是什么、和邻居有什么不同”。

**必须能区分的邻组**

| 新资产 | 不能混淆的已有资产 | 区分手段 |
|---|---|---|
| 铜锣图标 | 铜铃 `bronze_bell`、更鼓图标 | 铜锣是宽圆盘 + 短槌；铜铃窄、有提手；更鼓是桶形 + 鼓架 |
| 墨斗图标 | 纸鹊 `paper_cut_bird`、糖画勺 | 墨斗是矩形木斗 + 一条直线；纸鹊是飞鸟折角；糖画勺是勺 + 糖丝 |
| 年画图标 | 百工匣 `craft_box`、卡框 | 年画是“木板 + 纸 + 朱印”的扁平叠层；百工匣是立体木箱 + 铜扣 |
| 回春图标 | 糍粑 `ciba`、灯花 | 回春是窄腰药葫芦 + 新芽；糍粑是圆白团；灯花是蓝白星花 |
| 结界图标 | 花灯光环、铜铃 | 结界是俯视油纸伞/竹篾伞面，有 8 根伞骨；花灯是圆形灯晕；铜铃有提手 |
| 3 种浆壳兵 | 原 3 种杂兵、墨渍精英 | 纸屑壳偏碎、纸鸢壳偏薄且保留青尾、傀儡壳偏块状且保留提线；壳色冷米白 + 深灰裂纹 |
| 更鼓图标 | 铜锣、铜铃、哑鼓 Boss | 更鼓是桶形鼓身 + 双腿鼓架 + 交叉鼓槌；哑鼓 Boss 是 160px 大鼓，不用于 HUD |

### 2.5 SVG 技术约束（Godot / ThorVG）

现有管线用 Godot 4.7.2 直接导入 SVG，必须遵守：

- **禁止**：`<text>`、`<clipPath>`、`<mask>`、`<filter>`、`<image>`、`<style>`、`@keyframes`、外部字体、外链图片。
- `radialGradient` 必须带 `gradientUnits="userSpaceOnUse"`，否则光晕会画到框外变透明。
- `linearGradient` 必须显式给方向；本套明暗语言默认“顶亮底暗”，不要依赖默认横向。
- 所有 `id` 文件内唯一；所有 `url(#id)` 必须能解析；悬空引用在 ThorVG 里会直接画成透明。
- `<defs>` / `<g>` 必须成对闭合；禁止 `NaN` / `undefined`。
- 避免 `stroke-dasharray` 作为关键轮廓；需要虚线用重复短段/圆点实现，旧版 ThorVG 可能画成实线。
- 不用 `mix-blend-mode` / CSS；透明用 `opacity` / `fill-opacity`。
- 背景必须透明；不要铺满画布的底色矩形。
- 图层控制在 2–4 层；平涂为主，渐变只用于光晕/纸面明暗。
- 建议体积：图标 < 6KB，世界 FX < 15KB，敌人变体 < 8KB。

### 2.6 合规与禁忌（沿用 `docs/theme/craftkeepers/compliance.md`）

- **无血腥**：死亡/破壳用纸屑、墨点、浆片、光尘；不出现血肉、骨骼、断肢。
- **无真实宗教/祭祀**：不出现佛像、神像、真实符咒、请神/画符/念咒流程；年画用通用吉庆纹样（鱼、莲、回纹、水波），不用门神/具体神灵。
- **无文字**：SVG 内不写汉字、拼音、数字；需要“更”“开市”等字样时由 UI Label 层渲染。
- **不恐怖化**：傩面、皮影、剪纸是美的、温暖的；不做 Jump Scare、邪教感。
- **不混地域**：新增纹样只做通用吉庆语汇，不冒充某地特定流派；需要地域考据时先问顾问。
- **不写实危险操作**：打铁花、熬糖只做风格化；新增内容不涉及可模仿的危险步骤。

### 2.7 性能与层级

| 层级 | 建议 | 原因 |
|---|---|---|
| 地面/预警 | 光环、年画预警、更鼓波纹在地面层，敌人之下 | 不遮挡敌群，先读“范围”再读“怪” |
| 敌人 | 浆壳兵与原杂兵同层 | 不改变碰撞与遮挡关系 |
| 玩家/护盾 | 护盾在玩家之上、UI 之下 | 玩家始终可见，罩子只做边缘 |
| 弹道/墨线 | 墨线在敌人之上 | 细线必须能看见，否则读不出“打中了” |
| UI | 更鼓图标、护盾点在最上层 | 不被场景特效盖住 |

- 新 FX 一律**静态贴图 + 代码 tween**，不新增逐帧动画贴图；同屏 300+ 时不能出现每怪一张独立材质。
- 光环/落点/波纹中心透明，避免大面积加法混合；单张 alpha 峰值 ≤0.55。
- 不给杂兵逐只挂 shader；浆壳兵只换贴图，不新增材质。

---

## 3. 资产总表

### 3.1 P0（17 张，必须）

| ID | 文件（相对 `art_shouyiren/`） | 画布 | 类型 | 用途 | 为什么是 P0 |
|---|---|---|---|---|---|
| `gong_icon` | `weapons/gong_icon.svg` | 48×48 | 图标 | 铜锣卡面/HUD | 没有它，三选一卡与武器槽是空图 |
| `gong_aura` | `weapons/gong_aura.svg` | 256×256 | 世界光环 | 铜锣判定范围 | 没有它，玩家看不见 150 半径的领域 |
| `inkline_icon` | `weapons/inkline_icon.svg` | 48×48 | 图标 | 墨斗卡面/HUD | 同上 |
| `inkline_beam` | `weapons/inkline_beam.svg` | 256×32 | 弹道/光束 | 墨斗直线穿透 | 没有它，墨斗只有伤害数字没有“线” |
| `inkline_impact` | `weapons/inkline_impact.svg` | 48×48 | 命中特效 | 墨线命中点 | 细线命中需要落点反馈 |
| `print_icon` | `weapons/print_icon.svg` | 48×48 | 图标 | 年画卡面/HUD | 同上 |
| `print_zone_warn` | `weapons/print_zone_warn.svg` | 256×256 | 地面预警 | 0.45s 延迟落点 | 没有预警，年画像“凭空爆” |
| `print_zone_stamp` | `weapons/print_zone_stamp.svg` | 256×256 | 地面爆发 | 年画落点成画 | 没有它，年画没有“刷一张”的主题 |
| `passive_regen` | `items/passive_regen.svg` | 48×48 | 图标 | 回春被动卡 | 被动卡图标缺失会回退成卡框 |
| `passive_shield` | `items/passive_shield.svg` | 48×48 | 图标 | 结界被动卡 | 同上 |
| `shield_ward` | `fx/shield_ward.svg` | 128×128 | 护身罩 | 结界吸收期 | 没有它，护盾完全不可见 |
| `shield_break` | `fx/shield_break.svg` | 96×96 | 破罩特效 | 护盾被打碎 | 没有它，玩家不知道“盾没了” |
| `paper_scrap_shell` | `enemies/paper_scrap_shell.svg` | 48×48 | 敌人变体 | 纸屑结壳 | 中期机制的核心视觉 |
| `broken_kite_shell` | `enemies/broken_kite_shell.svg` | 48×48 | 敌人变体 | 纸鸢结壳 | 必须保留快速兵青尾 |
| `broken_puppet_shell` | `enemies/broken_puppet_shell.svg` | 48×48 | 敌人变体 | 傀儡结壳 | 必须保留提线/关节 |
| `ui_geng_drum` | `ui/ui_geng_drum.svg` | 48×48 | HUD 图标 | 更鼓 buff 标识 | 没有它，+8% 全局伤害不可见 |
| `drum_ripple` | `fx/drum_ripple.svg` | 256×256 | 世界波纹 | 跨更瞬间 | 没有它，更鼓只有数字跳变 |

### 3.2 P1（5 张，首版尽量）

| ID | 文件 | 画布 | 类型 | 用途 | 说明 |
|---|---|---|---|---|---|
| `gong_aura_evolved` | `weapons/gong_aura_evolved.svg` | 256×256 | 世界光环 | 开市锣 | 金边 + 朱绳 + 更多铜钉；中心仍透明 |
| `inkline_beam_evolved` | `weapons/inkline_beam_evolved.svg` | 256×32 | 弹道/光束 | 龙筋墨线 | 金褐“龙筋”芯 + 墨边；不裁白 |
| `regen_tick` | `fx/regen_tick.svg` | 32×32 | 回血跳字 | 回春每跳 | 青绿/米白叶片露珠；不用金色 |
| `shell_crack` | `fx/shell_crack.svg` | 48×48 | 受击叠加 | 浆壳受击 | 3–4 条裂纹；代码不支持叠加时可不接 |
| `ui_shield_pip` | `ui/ui_shield_pip.svg` | 20×20 | HUD 小图标 | 护盾余量 | 小伞/护罩点；代码不做 HUD 护盾条时可不接 |

### 3.3 P2（5 张，第二版）

| ID | 文件 | 画布 | 类型 | 用途 | 说明 |
|---|---|---|---|---|---|
| `print_stamp_impact` | `weapons/print_stamp_impact.svg` | 64×64 | 命中特效 | 年画中心小冲击 | 可选；已有落点成画时可省 |
| `evolve_gong_burst` | `fx/evolve_gong_burst.svg` | 96×96 | 进化爆发 | 开市锣进化 | 铜环 + 金芒 + 朱绳；区别于开脸 |
| `evolve_inkline_burst` | `fx/evolve_inkline_burst.svg` | 96×96 | 进化爆发 | 龙筋墨线进化 | 墨龙盘绕 + 金筋；区别于开脸 |
| `prop_drum_tower` | `props/prop_drum_tower.svg` | 160×240 | 场景摆件 | 夜市鼓楼 | 纯氛围；不参与碰撞 |
| `shell_shatter` | `fx/shell_shatter.svg` | 64×64 | 死亡特效 | 浆壳兵死亡 | 干浆片 + 纸屑；无血 |

### 3.4 明确复用、不要新画的

| 需求 | 复用现有资产/代码 | 说明 |
|---|---|---|
| 进化宝箱 | `items/craft_box.svg` | v4 没有新宝箱外观，沿用百工匣 |
| 进化瞬间（P0） | `fx/kailian_burst.svg` + HUD 文字 | P2 才考虑开市锣/龙筋墨线的专属爆发 |
| HUD 进化标识 | 现有金边 + `MAX` 文字 | 不新增进化图标 |
| 伤害数字 / 更次文字 / buff 数值 | UI Label | SVG 内禁止写字 |
| 浆壳 17–20min 渐散 | `modulate.a` 或壳层透明度 | 不做额外渐散贴图 |
| 武器槽底板 / 卡框 / 血条 | 现有 `ui_*.svg` | 不重绘 UI 框架 |

---

## 4. P0 逐项规格

### 4.1 铜锣（gong）

#### `weapons/gong_icon.svg` — 48×48

- **构图**：正面略 3/4 的铜锣圆盘，直径 36px，外圈 4px 厚；中心鼓包 10px；8 颗小铜钉；右上角一根短木槌（约 45°）；顶部一段朱砂绳结。
- **配色**：`#D9A441` 主铜色，`#A8781F` 暗部，`#F4E8D0` 1–2px 高光，`#C53B2E` 绳结。
- **透明**：背景透明；不要外发光溢出画布。
- **剪影**：40px 下必须是“宽圆盘 + 斜槌”，不能读成铜铃或更鼓。
- **禁止**：文字、真实神像、复杂云纹、霓虹光。

#### `weapons/gong_aura.svg` — 256×256

- **构图**：以 `(128,128)` 为圆心的铜锣光环。主环中心线 `r=122`，环宽 10px；外缘 ≤127。主环上 12 颗铜钉（`r=112`，3px）；内圈两道回声环 `r=100` / `r=84`，透明度 0.18 / 0.10；4 个极简“槌击”缺口，不要做成花瓣。
- **透明**：中心 `r<40` 完全透明；环内填充 alpha ≤0.08；主环 alpha ≤0.55。
- **对齐**：引擎按 `scale = 半径*2/256` 缩放；视觉环与 150 判定半径误差 ≤6px。
- **与花灯区分**：花灯是暖橙纸罩/灯瓣/呼吸光；铜锣是金铜几何双环 + 铜钉，**不要纸瓣、不要灯笼骨架**。
- **层级**：地面层，玩家/敌人之下。
- **禁止**：文字、满圆填充、暖橙大面积、复杂光晕。

### 4.2 墨斗（inkline）

#### `weapons/inkline_icon.svg` — 48×48

- **构图**：左侧一个 28×18px 的木墨斗（矩形斗身 + 线轮 + 小摇柄），一条绷紧的墨线从斗口斜向右上，末端一个小墨点。整体像“木工工具”，不是枪/法杖。
- **配色**：`#5A3B25` 木身，`#3B2617` 暗部，`#1A1A1A` 墨线，`#F4E8D0` 线轮高光，`#3E7C74` 一点点纸面反光。
- **剪影**：矩形斗 + 直线，40px 下与纸鹊（飞鸟折角）明显不同。
- **禁止**：红色、发光、箭头、现代工具。

#### `weapons/inkline_beam.svg` — 256×32

- **构图**：水平向右的墨线。视觉从 `x=6` 到 `x=250`，`y=16`。核心线 3px `#1A1A1A`；外侧 10px `#2B2F3A` 晕，alpha 0.35；两端 8px 渐隐；沿线 2–3 个极淡纸纤维点。
- **锚点**：左中 `(0,16)`。代码若用 Sprite2D，必须设 `offset=(-128,0)` 或等价左锚点；若用 Line2D，本图可作为端点/命中纹理，但核心线表现仍要保留。
- **拉伸**：X 轴 1–3× 不糊；2× 时核心线 ≤8px。Y 轴不要超过 1.4×。
- **层级**：敌人之上。
- **禁止**：箭头、白色高光、霓虹、渐变彩虹。

#### `weapons/inkline_impact.svg` — 48×48

- **构图**：命中点的墨溅/纸面晕染：中心 4px 墨核，3–5 个不规则墨点，外圈 1px 青黑晕。
- **配色**：`#1A1A1A` / `#2B2F3A` / `#24524C`；不用红。
- **寿命**：代码 0.2s 淡出；静态图即可。

### 4.3 木版年画（print）

#### `weapons/print_icon.svg` — 48×48

- **构图**：一块 30×24px 的木刻版（深木色，表面有刻线），上面斜压一张 26×20px 米白纸，纸角一枚 8×8px 朱砂抽象方印；右下角露出一点刻刀/棕刷。
- **配色**：`#5A3B25` / `#3B2617` 木板，`#F4E8D0` / `#D6C4A2` 纸，`#C53B2E` 印，`#3E7C74` 一点套色。
- **剪影**：扁平叠层“木板 + 纸 + 印”，与百工匣（立体箱 + 铜扣）区分。
- **禁止**：门神/真实神灵、可读汉字、复杂人物。

#### `weapons/print_zone_warn.svg` — 256×256

- **构图**：`(128,128)` 为圆心，外缘 `r=124–127`（对应 105 判定半径）。外圈 6px 木刻方/圆框，四角/四边 4 个套色对位 marks；内部通用吉庆纹样（鱼、莲、回纹、水波）alpha ≤0.15；中心 60% 留空。
- **配色**：朱砂描边 alpha 0.5，木褐内框 alpha 0.35，米白极淡纸纹。
- **透明**：内部填充 alpha ≤0.18；不能盖住脚下敌人。
- **层级**：地面层，敌人之下。
- **禁止**：文字、门神、真实神灵、满圆实心。

#### `weapons/print_zone_stamp.svg` — 256×256

- **构图**：与 warn 同一几何，但“印下去”的高对比版本：朱砂/青绿/米白套色，2px 套色错位（故意不完美），中心 35–45% 填充，外圈保留木刻框；纸面纤维可见。
- **透明**：中心填充 alpha ≤0.45；不要完全不透明；命中后 0.18s 淡出。
- **层级**：地面层，可略高于敌人但 alpha ≤0.65；不要遮挡血条。
- **禁止**：可读文字、真实门神、过亮纯白。

### 4.4 回春 / 结界（regen / shield）

#### `items/passive_regen.svg` — 48×48

- **构图**：窄腰药葫芦（约 20×30px），葫芦口冒一株 8px 新芽/两片叶，旁边一滴露珠；葫芦身有 1–2 道米白高光。
- **配色**：`#3E7C74` 叶/暗部，`#F4E8D0` 葫芦高光，`#D9A441` 极小金色系绳（≤4px）。
- **剪影**：窄腰葫芦 + 芽，40px 下区别于糍粑（圆白团）和灯花（星形）。
- **禁止**：红十字、现代药瓶、文字。

#### `items/passive_shield.svg` — 48×48

- **构图**：俯视油纸伞/竹篾护罩，伞面直径 36px，8 根竹骨，伞面米白半透，朱砂包边，中心一个红线结；整体八边形，不是简单圆环。
- **配色**：`#F4E8D0` 伞面，`#5A3B25` 竹骨，`#C53B2E` 包边/线结，`#3E7C74` 一点冷影。
- **剪影**：伞骨 + 八边形，40px 下区别于花灯光环和铜铃。
- **合规**：不做符咒、不做八卦、不写汉字；只是“油纸伞/竹篾护罩”的手艺道具。
- **禁止**：真实宗教符号、发光法阵、文字。

#### `fx/shield_ward.svg` — 128×128

- **构图**：以 `(64,64)` 为圆心、`r≈58` 的俯视油纸伞罩；8 根竹骨从中心向外；伞面米白 alpha 0.25，外缘朱砂 alpha 0.45；中心 44px 完全透明，玩家必须可见。
- **动态**：代码可随剩余护盾值调 alpha/scale；静态图即可。
- **层级**：玩家之上、UI 之下；不要盖住玩家脸和灯。
- **禁止**：满圆不透明、文字、法阵、霓虹。

#### `fx/shield_break.svg` — 96×96

- **构图**：中心向外 6–8 片纸伞碎片 + 4 根竹篾 + 1 段红线；径向散开，碎片边缘干净。
- **配色**：米白/竹褐/朱砂；不用玻璃高光、不用红血。
- **寿命**：0.35s；静态图 + 代码放大淡出。

### 4.5 浆壳兵（shelled）

> **决定：做 3 张整图变体，不做通用叠加层。** 这样纸屑/纸鸢/傀儡的剪影差异不会被同一张壳盖掉，也避免新增 Enemy 子节点。

#### `enemies/paper_scrap_shell.svg` — 48×48

- **底图**：直接以 `enemies/paper_scrap.svg` 为底，保留全部原图元、接触阴影、脚底锚点；只叠加“浆壳”组。
- **壳层**：覆盖上半身 60–70%；冷米白 `#D6C4A2` + 灰蓝 `#495468` 裂纹 + 深青 `#24524C` 湿浆阴影；壳缘 2px 不齐；3–4 条 1–2px 裂纹；少量稻草纤维。
- **可读性**：48px 下仍能看出“纸屑团”，壳不能把它变成白团；壳与未结壳版本必须一眼区分（颜色 + 硬边 + 裂纹）。
- **禁止**：暖金、大面积 `#F2A03D`、遮住脚底阴影。

#### `enemies/broken_kite_shell.svg` — 48×48

- **底图**：以 `enemies/broken_kite.svg` 为底，保留青蓝机身、断线拖尾、`#B8F6FF` 速度预警。
- **壳层**：只覆盖机身中段/翼根，**不盖青色尾迹和描边**；壳块偏薄、偏碎，像纸鸢骨架糊了一层浆。
- **可读性**：48px 下仍能读出“快速兵”的青尾；壳色冷，不能和灯花混淆。
- **禁止**：把整只风筝包成白壳、遮住青尾。

#### `enemies/broken_puppet_shell.svg` — 48×48

- **底图**：以 `enemies/broken_puppet.svg` 为底，保留提线、关节缝隙、木偶轮廓。
- **壳层**：覆盖躯干/大腿外侧，关节处留缝；壳块偏厚、偏块状，带稻草纤维；提线必须从壳外穿过。
- **可读性**：48px 下仍能读出“傀儡”的关节/提线；壳不能把它变成纸屑。
- **禁止**：遮住全部提线、改变脚底锚点、暖金。

### 4.6 更鼓（drum）

#### `ui/ui_geng_drum.svg` — 48×48

- **构图**：一只 28×24px 的桶形更鼓，朱砂鼓身、米白鼓面、金铜钉；下方两条短鼓架；右侧两根交叉鼓槌。
- **配色**：`#C53B2E` 鼓身，`#F4E8D0` 鼓面，`#D9A441` 钉/槌头，`#5A3B25` 木架。
- **剪影**：40px / 24px 下是“桶 + 架 + 交叉槌”，区别于铜锣（圆盘）和铜铃（窄钟）。
- **用途**：HUD 更鼓 buff 标识；代码可在每个更次 tint/脉冲，不要求做 4 张变体。
- **禁止**：文字“更”、真实鼓乐人物、复杂纹样。

#### `fx/drum_ripple.svg` — 256×256

- **构图**：以 `(128,128)` 为圆心，两道同心铜环：`r=70`（4px，alpha 0.45）、`r=110`（2px，alpha 0.25）；环上 8 个短缺口，像鼓面余震；中心完全透明。
- **配色**：`#D9A441` / `#A8781F` / 一点 `#C53B2E`。
- **动态**：0.6s 放大 + 淡出；静态图即可。
- **层级**：地面层，敌人之下；不要做成红色攻击预警。
- **禁止**：满圆填充、文字、爆炸感、红黑攻击圈。

---

## 5. P1 / P2 规格

### P1

| ID | 规格 |
|---|---|
| `gong_aura_evolved` | 在 `gong_aura` 几何上加金边、朱砂绳结、16 颗铜钉、4 道极简开市光芒；中心仍透明；整体亮度 +15–20%，不要纯白。 |
| `inkline_beam_evolved` | 在 `inkline_beam` 几何上把核心改成金褐“龙筋”编织线（4px），两侧保留墨黑边；不裁白、不加箭头；左中锚点不变。 |
| `regen_tick` | 32×32，2–3 片青绿/米白叶片 + 1 滴露珠，向上飘；alpha ≤0.6；不用金色，避免和灯花/金币混淆。 |
| `shell_crack` | 48×48，透明底，3–4 条米白/灰蓝裂纹，中心一点干浆碎屑；叠在浆壳兵受击帧上；代码不支持叠加时可不接。 |
| `ui_shield_pip` | 20×20，小油纸伞/护罩点，米白 + 青绿 + 朱砂边；用于 HUD 护盾余量；不做数字。 |

### P2

| ID | 规格 |
|---|---|
| `print_stamp_impact` | 64×64，年画中心小冲击：纸屑 + 朱砂/青绿套色点；不要盖过主落点。 |
| `evolve_gong_burst` | 96×96，铜环 + 金芒 + 朱绳；区别于 `kailian_burst`（傩面裂开）。 |
| `evolve_inkline_burst` | 96×96，墨龙盘绕 + 金褐龙筋；黑金为主，不要霓虹。 |
| `prop_drum_tower` | 160×240，夜市鼓楼剪影：木架 + 大鼓 + 灯笼；底边中心锚点；不参与碰撞，只做背景摆件。 |
| `shell_shatter` | 64×64，干浆片 + 纸屑 + 稻草纤维向外散；无血、无玻璃高光。 |

---

## 6. 代码落点与接线

> 本节只说明“新图会被谁读”，不要求本指令改代码；下一步实现时按此接线。

### 6.1 `scripts/Art.gd`

新增常量（路径统一走 `res://assets/art_shouyiren/...`）：

| 常量 | 路径 |
|---|---|
| `GONG_ICON` | `weapons/gong_icon.svg` |
| `GONG_AURA` | `weapons/gong_aura.svg` |
| `GONG_AURA_EVOLVED` | `weapons/gong_aura_evolved.svg` |
| `INKLINE_ICON` | `weapons/inkline_icon.svg` |
| `INKLINE_BEAM` | `weapons/inkline_beam.svg` |
| `INKLINE_IMPACT` | `weapons/inkline_impact.svg` |
| `INKLINE_BEAM_EVOLVED` | `weapons/inkline_beam_evolved.svg` |
| `PRINT_ICON` | `weapons/print_icon.svg` |
| `PRINT_ZONE_WARN` | `weapons/print_zone_warn.svg` |
| `PRINT_ZONE_STAMP` | `weapons/print_zone_stamp.svg` |
| `PASSIVE_REGEN` | `items/passive_regen.svg` |
| `PASSIVE_SHIELD` | `items/passive_shield.svg` |
| `SHIELD_WARD` | `fx/shield_ward.svg` |
| `SHIELD_BREAK` | `fx/shield_break.svg` |
| `REGEN_TICK` | `fx/regen_tick.svg` |
| `SHELL_PAPER` | `enemies/paper_scrap_shell.svg` |
| `SHELL_KITE` | `enemies/broken_kite_shell.svg` |
| `SHELL_PUPPET` | `enemies/broken_puppet_shell.svg` |
| `SHELL_CRACK` | `fx/shell_crack.svg` |
| `SHELL_SHATTER` | `fx/shell_shatter.svg` |
| `UI_GENG_DRUM` | `ui/ui_geng_drum.svg` |
| `FX_DRUM_RIPPLE` | `fx/drum_ripple.svg` |
| `UI_SHIELD_PIP` | `ui/ui_shield_pip.svg` |
| `PRINT_STAMP_IMPACT` | `weapons/print_stamp_impact.svg` |
| `EVOLVE_GONG_BURST` | `fx/evolve_gong_burst.svg` |
| `EVOLVE_INKLINE_BURST` | `fx/evolve_inkline_burst.svg` |
| `PROP_DRUM_TOWER` | `props/prop_drum_tower.svg` |

**必须**把这些路径加入 `Art.ALL_PATHS`，否则换图漏接不会被冒烟测试发现。

### 6.2 `WeaponDB` / `WeaponManager`

- `gong`：`svg` 用 `GONG_ICON`；世界光环**不要**复用 `svg`，新增 `aura_svg` 或用 `GONG_AURA` 单独建一个光环节点。
- `inkline`：`svg` 用 `INKLINE_ICON`；直线武器若走 Sprite2D，`beam_svg` 用 `INKLINE_BEAM`，并设左中锚点；若走 Line2D，仍保留 `INKLINE_IMPACT`。
- `print`：`svg` 用 `PRINT_ICON`；新增 `zone_warn_svg` / `zone_stamp_svg` 字段，不要用同一张图兼作预警和爆发。
- 进化：`gong` 进化后世界光环换 `GONG_AURA_EVOLVED`；`inkline` 进化后墨线换 `INKLINE_BEAM_EVOLVED`。HUD 图标仍用基础图标 + 现有金边/MAX 标识即可，**不需要**新增进化图标。
- 墨斗的 `shell_bonus=1.80` 是数值，不是美术；但视觉上要让“墨线打在壳上”有更明显的墨点/裂感，可复用 `inkline_impact` 加一次 `shell_crack`（P1）。

### 6.3 `HUD` / `LevelUpUI`

- `HUD.WEAPON_ICONS` 增加：
  - `"gong": Art.GONG_ICON`
  - `"inkline": Art.INKLINE_ICON`
  - `"print": Art.PRINT_ICON`
- `LevelUpUI._icons` 增加：
  - `"regen": Art.PASSIVE_REGEN`
  - `"shield": Art.PASSIVE_SHIELD`
- 更鼓：在顶部时间/更次旁加 `UI_GENG_DRUM` 小图标；跨更时脉冲 + 短横幅（文字由 Label 渲染，不用 SVG 文字）。护盾有余量时可在血条旁加 `UI_SHIELD_PIP`（P1）。
- 卡面图标显示 68×68，HUD 槽 40×40；图标必须在这两个尺寸都可读。

### 6.4 `Enemy` / `WaveTable`

- `Enemy._art_for(kind, elite, shelled)` 增加 `shelled` 分支：
  - `cup` → `SHELL_PAPER`
  - `fast` → `SHELL_KITE`
  - `bag` → `SHELL_PUPPET`
- 壳只换贴图，不改 `size` / `touch_radius` / `offset` / 接触阴影；3 张 48×48 与母图画布一致。
- 精英/Boss 不结壳（v4 只给杂兵上壳）；壳的 AoE 0.75 / 墨斗 1.80 是受击倍率，不是视觉状态，不要给壳加独立血条。
- `WaveTable` 8:00–17:00 满强度、17:00–20:00 渐散；渐散期可用 `modulate.a` 或壳层透明度，不需要额外贴图。

### 6.5 `Game` / `Stats`

- 更鼓：5/10/20/25min 触发；播 `FX_DRUM_RIPPLE` + HUD 图标脉冲 + 短横幅；不新增常驻节点。
- 结界：`shield` 生成时挂 `SHIELD_WARD` 到玩家，破盾播 `SHIELD_BREAK`；护盾余量可用罩子 alpha/scale 表示，HUD 点为 P1。
- 回春：每跳可播 `REGEN_TICK`（P1）；若不做，至少让血条有轻微上跳，避免“无声回血”。

### 6.6 资源落盘

- 新文件直接放 `assets/craftkeepers/art_shouyiren/`，同步复制到 `GameDemo/first-xi-xue-gui/assets/art_shouyiren/`。
- 更新 `assets/craftkeepers/manifest.json`：`file`、`size`、`tier`、`title`、`feature`、`kind`；`replaces` 留空（新增，不换皮）。
- **警告**：`assets/craftkeepers/generate.mjs` 的 `build()` 第一件事是 `rmSync(OUT)`。新增文件若未登记进 `sprites.mjs` / `build.mjs` 的导出数组，重跑生成器会被抹掉。**本轮不要重跑 `generate.mjs`**；必须重跑时先把 27 张登记进去。
- 不覆盖 `assets/art/` 旧目录；旧素材保留回退位。

---

## 7. 验收清单

### 7.1 全局

- [ ] 27 张文件全部存在，路径与本文/JSON 完全一致；无中文文件名、无空格。
- [ ] `width` / `height` / `viewBox` 与 §2.3 完全一致；无 `NaN` / `undefined`。
- [ ] 无 `<text>` / `<clipPath>` / `<mask>` / `<filter>` / `<image>` / `<style>` / `@keyframes`。
- [ ] 所有 `id` 唯一，所有 `url(#id)` 可解析；`radialGradient` 带 `userSpaceOnUse`。
- [ ] 背景透明；无满画布底色；无外链资源。
- [ ] 图标 40px / 68px 可读；敌人 48px 剪影可辨；世界 FX 在 720×1280 下不糊。
- [ ] 色彩只用 §2.2 色板及其明暗变体；浆壳兵无大面积暖金。
- [ ] 无血腥、无真实宗教/祭祀、无可读文字、无门神/神像。
- [ ] 新 FX 单张 alpha 峰值 ≤0.55；中心透明；不新增逐帧贴图。
- [ ] `Art.ALL_PATHS` 与 `manifest.json` 已登记；`SmokeTest` 资源齐备性断言全绿。

### 7.2 分项

| 资产 | 验收动作 | 通过标准 |
|---|---|---|
| `gong_icon` | 缩到 40px，纯黑填充 | 仍读成“宽圆盘 + 槌”，不误认铜铃/更鼓 |
| `gong_aura` | 按 300px 直径叠加在玩家脚下 | 环与 150 判定半径误差 ≤6px；中心不挡玩家；与花灯一眼区分 |
| `inkline_icon` | 40px 纯黑 | 矩形木斗 + 直线，不误认纸鹊 |
| `inkline_beam` | 拉伸到 520px 长度 | 核心线可见、不糊；左中锚点正确；命中点有 `inkline_impact` |
| `print_icon` | 40px 纯黑 | 木板 + 纸 + 印的叠层，不误认百工匣 |
| `print_zone_warn` | 210px 直径、0.45s 预警 | 外缘贴 105 半径；内部不遮敌人；能读出“将落” |
| `print_zone_stamp` | 210px 直径、命中帧 | 能读出“木版印画”；中心和边缘都不过曝；不遮血条 |
| `passive_regen` | 40px 纯黑 | 窄腰葫芦 + 芽，不误认糍粑/灯花 |
| `passive_shield` | 40px 纯黑 | 伞骨/八边形，不误认花灯/铜铃 |
| `shield_ward` | 罩在 64×80 玩家上 | 中心 44px 透明，玩家可见；边缘像纸伞/竹篾，不像法阵 |
| `shield_break` | 0.35s 播放 | 纸屑 + 竹篾 + 红线，无血/无玻璃 |
| 3 张浆壳兵 | 48px 并排、纯黑/彩色各看一次 | 三种类型仍可区分；壳与未结壳一眼区分；脚底不跳 |
| `ui_geng_drum` | 24px / 40px | 桶形 + 架 + 槌，不误认铜锣/铜铃 |
| `drum_ripple` | 跨更播放 | 像“时间余震”，不像红色攻击预警；中心透明 |

### 7.3 实机回归建议

1. `--import` 后跑 `SmokeTest.tscn`；新增路径进 `Art.ALL_PATHS`，确保资源齐备性断言覆盖。
2. 720×1280、同屏 300+ 敌人跑 10–17min 结壳期：三种浆壳兵在怪潮中可辨；墨线仍可见；年画预警不被怪盖死。
3. 5/10/20/25min 各看一次更鼓：波纹不遮 HUD，图标脉冲可读。
4. 护盾生成/破裂各看一次：玩家不被罩子挡脸；破罩能感知。
5. 用 `assets/craftkeepers/render_check` 光栅化新图，深/浅底各看一次，确认没有“径向渐变透明”“线性渐变方向反”“边缘裁白”。

---

## 8. 假设与待确认

本文为了让下一步能直接执行，先做了以下决定；如与实现冲突，以“不改判定尺寸”为第一优先，再回来改本文。

1. **墨斗长度**：v4 未给像素射程；本文按现有弹道武器量级假设 520px。墨线贴图按 256×32 设计，实际拉伸由代码决定，不影响资产。
2. **铜锣光环 256×256**：v4 只给半径 150；本文沿用现有光环 256 画布，按 `r*2/256` 映射。若后续改成 332 画布，环比例不变，只改画布。
3. **年画落点 256×256 → 210px**：v4 给 `radius=105`；本文按 256 画布缩到 210，外缘 `r=124–127`。
4. **浆壳兵用 3 张整图变体**：不做通用叠加层，保证纸屑/纸鸢/傀儡剪影不被同一张壳抹平；也避免给 Enemy 新增子节点。
5. **结界视觉 = 油纸伞/竹篾护罩**：这是美术决策，不是 v4 原文；目的是避开“法阵/符咒”的宗教感，同时和花灯光环区分。若美术总监否决，可换成“竹篾灯笼罩”，但必须保留八边形伞骨/罩骨轮廓。
6. **进化世界贴图为 P1**：v4 的进化先用基础图 + HUD 金边/MAX 标识即可跑通；P1 再让“开市锣/龙筋墨线”在世界里一眼不同。
7. **不做**：新 Boss、新地图、新摊位、新角色、音频、旧 34 张重绘、数值改动、UI 大改版。

---

## 9. 下一步生成指令（模板，不在本指令执行）

> 请按 `docs/design/art-requirements-v4.md` 只生成 **P0 的 17 张 SVG**，输出到 `assets/craftkeepers/art_shouyiren/` 对应子目录；不要覆盖旧文件，不要重跑 `generate.mjs`；生成后更新 `manifest.json`，并按 §7 验收。
> 生成顺序：① 6 张武器/被动图标 → ② 3 张武器世界贴图（光环/墨线/年画预警+成画）→ ③ 3 张结界/护盾特效 → ④ 3 张浆壳兵 → ⑤ 2 张更鼓。
> 每张图先过“48px/40px 剪影”再细化；所有 SVG 禁止文字、滤镜、外链；透明底；画布与锚点严格按 §2.3。
> P1/P2 暂不生成，等 P0 验收通过后再开。

---

## 10. 机器可读清单（JSON）

> 本 JSON 是资产清单的机器可读版本；与上文冲突时，以 JSON 的 `file` / `canvas` / `pivot` 为准。

```json
{
  "schema": "craftkeepers.art_requirements/v4",
  "version": 1,
  "date": "2026-10-28",
  "source_design": "docs/design/skills-and-midgame-v4.md",
  "output_root": "assets/craftkeepers/art_shouyiren",
  "runtime_root": "GameDemo/first-xi-xue-gui/assets/art_shouyiren",
  "format": "svg-preferred",
  "art_direction": "夜蓝底上的一盏暖灯；纸、木、铜、墨四种材质；木刻平涂 + 宣纸纤维；轮廓先于细节；敌人冷、玩家暖；无血腥、无真实宗教、无文字、无霓虹/科幻/3D。",
  "palette": {
    "night": "#0F1B2D",
    "nightDeep": "#08111E",
    "ink": "#1A1A1A",
    "inkSoft": "#2B2F3A",
    "cinnabar": "#C53B2E",
    "cinnabarDeep": "#8E2A20",
    "lantern": "#F2A03D",
    "amber": "#E8B04B",
    "gold": "#D9A441",
    "goldDeep": "#A8781F",
    "teal": "#3E7C74",
    "tealDeep": "#24524C",
    "cream": "#F4E8D0",
    "creamDim": "#D6C4A2",
    "gray": "#6B7A8F",
    "ash": "#495468",
    "wood": "#5A3B25",
    "woodDeep": "#3B2617",
    "cyan": "#B8F6FF"
  },
  "counts": {
    "P0": 17,
    "P1": 5,
    "P2": 5,
    "total": 27
  },
  "assets": [
    {
      "id": "gong_icon",
      "file": "weapons/gong_icon.svg",
      "tier": "P0",
      "kind": "icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "gong",
      "usage": ["weapon_card", "hud_slot"],
      "visual": "略 3/4 的铜锣圆盘，直径 36px，外圈 4px，中心鼓包 10px，8 颗铜钉，右上短木槌，顶部朱砂绳结。",
      "must": ["40px 剪影是宽圆盘 + 槌", "与 bronze_bell、更鼓图标可区分", "内容在 4-44px 内"],
      "avoid": ["文字", "霓虹", "真实神像", "复杂云纹"],
      "code": ["Art.GONG_ICON", "WeaponDB.svg(gong)", "HUD.WEAPON_ICONS"]
    },
    {
      "id": "gong_aura",
      "file": "weapons/gong_aura.svg",
      "tier": "P0",
      "kind": "aura",
      "canvas": "256x256",
      "viewBox": "0 0 256 256",
      "pivot": "center-128-128",
      "feature": "gong",
      "usage": ["world_aura", "radius_150"],
      "visual": "铜锣光环，主环中心线 r=122、环宽 10px、外缘 <=127；12 颗铜钉在 r=112；两道回声环 r=100/84，alpha 0.18/0.10。",
      "must": ["中心 r<40 完全透明", "主环 alpha <=0.55", "与 150 判定半径误差 <=6px", "与花灯纸瓣/暖橙区分"],
      "avoid": ["满圆填充", "文字", "纸瓣", "复杂光晕"],
      "code": ["Art.GONG_AURA", "GarlicRing/新光环节点"]
    },
    {
      "id": "inkline_icon",
      "file": "weapons/inkline_icon.svg",
      "tier": "P0",
      "kind": "icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "inkline",
      "usage": ["weapon_card", "hud_slot"],
      "visual": "左侧 28x18 木墨斗（斗身 + 线轮 + 摇柄），一条绷紧墨线斜向右上，末端小墨点。",
      "must": ["40px 剪影是矩形木斗 + 直线", "与 paper_cut_bird、糖画勺区分", "内容在 4-44px 内"],
      "avoid": ["红色", "发光", "箭头", "现代工具"],
      "code": ["Art.INKLINE_ICON", "WeaponDB.svg(inkline)", "HUD.WEAPON_ICONS"]
    },
    {
      "id": "inkline_beam",
      "file": "weapons/inkline_beam.svg",
      "tier": "P0",
      "kind": "beam",
      "canvas": "256x32",
      "viewBox": "0 0 256 32",
      "pivot": "left-center-0-16",
      "feature": "inkline",
      "usage": ["line_attack", "pierce"],
      "visual": "水平向右墨线，视觉 x=6..250、y=16；核心 3px 墨黑，外侧 10px 柔墨晕 alpha 0.35，两端 8px 渐隐，2-3 个纸纤维点。",
      "must": ["左中锚点", "X 拉伸 1-3 倍不糊", "2 倍时核心线 <=8px", "敌群之上可见"],
      "avoid": ["箭头", "白色高光", "霓虹", "彩虹渐变"],
      "code": ["Art.INKLINE_BEAM", "WeaponManager.fire_inkline"]
    },
    {
      "id": "inkline_impact",
      "file": "weapons/inkline_impact.svg",
      "tier": "P0",
      "kind": "fx",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "inkline",
      "usage": ["hit_feedback"],
      "visual": "中心 4px 墨核，3-5 个不规则墨点，外圈 1px 青黑晕；像墨落在纸上。",
      "must": ["0.2s 淡出可读", "不用红色", "不遮敌人轮廓"],
      "avoid": ["血", "火花", "白色闪光"],
      "code": ["Art.INKLINE_IMPACT", "WeaponManager.fire_inkline"]
    },
    {
      "id": "print_icon",
      "file": "weapons/print_icon.svg",
      "tier": "P0",
      "kind": "icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "print",
      "usage": ["weapon_card", "hud_slot"],
      "visual": "30x24 木刻版 + 斜压 26x20 米白纸 + 8x8 朱砂抽象方印，右下角刻刀/棕刷。",
      "must": ["40px 剪影是扁平叠层木板 + 纸 + 印", "与 craft_box 区分", "内容在 4-44px 内"],
      "avoid": ["门神", "真实神灵", "可读汉字", "复杂人物"],
      "code": ["Art.PRINT_ICON", "WeaponDB.svg(print)", "HUD.WEAPON_ICONS"]
    },
    {
      "id": "print_zone_warn",
      "file": "weapons/print_zone_warn.svg",
      "tier": "P0",
      "kind": "zone_warn",
      "canvas": "256x256",
      "viewBox": "0 0 256 256",
      "pivot": "center-128-128",
      "feature": "print",
      "usage": ["telegraph", "radius_105", "delay_0.45"],
      "visual": "r=124-127 的木刻圆/方框，4 个套色对位 marks，内部通用吉庆纹样（鱼/莲/回纹/水波）alpha <=0.15，中心 60% 留空。",
      "must": ["外缘贴 105 半径", "内部填充 alpha <=0.18", "地面层敌人之下", "能读出将落"],
      "avoid": ["文字", "门神", "满圆实心", "真实神灵"],
      "code": ["Art.PRINT_ZONE_WARN", "WeaponManager.fire_print"]
    },
    {
      "id": "print_zone_stamp",
      "file": "weapons/print_zone_stamp.svg",
      "tier": "P0",
      "kind": "zone_stamp",
      "canvas": "256x256",
      "viewBox": "0 0 256 256",
      "pivot": "center-128-128",
      "feature": "print",
      "usage": ["impact", "radius_105"],
      "visual": "与 warn 同几何的高对比套色印画：朱砂/青绿/米白，2px 套色错位，中心 35-45% 填充，外圈木刻框，纸纤维可见。",
      "must": ["中心填充 alpha <=0.45", "不遮血条", "0.18s 淡出", "能读出木版印画"],
      "avoid": ["可读文字", "真实门神", "纯白过曝", "满屏不透明"],
      "code": ["Art.PRINT_ZONE_STAMP", "WeaponManager.fire_print"]
    },
    {
      "id": "passive_regen",
      "file": "items/passive_regen.svg",
      "tier": "P0",
      "kind": "icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "regen",
      "usage": ["passive_card"],
      "visual": "窄腰药葫芦 20x30，口部 8px 新芽/两片叶，旁边一滴露珠，1-2 道米白高光。",
      "must": ["40px 剪影是窄腰葫芦 + 芽", "与 ciba、灯花区分", "内容在 4-44px 内"],
      "avoid": ["红十字", "现代药瓶", "文字", "大面积金色"],
      "code": ["Art.PASSIVE_REGEN", "LevelUpUI._icons.regen"]
    },
    {
      "id": "passive_shield",
      "file": "items/passive_shield.svg",
      "tier": "P0",
      "kind": "icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "shield",
      "usage": ["passive_card"],
      "visual": "俯视油纸伞/竹篾护罩，直径 36px，8 根竹骨，米白半透伞面，朱砂包边，中心红线结，八边形轮廓。",
      "must": ["40px 剪影是伞骨/八边形", "与花灯光环、铜铃区分", "无符咒/八卦"],
      "avoid": ["真实宗教符号", "发光法阵", "文字", "简单圆环"],
      "code": ["Art.PASSIVE_SHIELD", "LevelUpUI._icons.shield"]
    },
    {
      "id": "shield_ward",
      "file": "fx/shield_ward.svg",
      "tier": "P0",
      "kind": "ward",
      "canvas": "128x128",
      "viewBox": "0 0 128 128",
      "pivot": "center-64-64",
      "feature": "shield",
      "usage": ["player_aura", "absorb"],
      "visual": "以 (64,64) 为圆心、r≈58 的俯视油纸伞罩，8 根竹骨，伞面米白 alpha 0.25，外缘朱砂 alpha 0.45，中心 44px 透明。",
      "must": ["玩家 64x80 可见", "中心不挡脸/灯", "玩家之上 UI 之下", "alpha 可随护盾余量变化"],
      "avoid": ["满圆不透明", "文字", "法阵", "霓虹"],
      "code": ["Art.SHIELD_WARD", "Stats/Player shield"]
    },
    {
      "id": "shield_break",
      "file": "fx/shield_break.svg",
      "tier": "P0",
      "kind": "fx",
      "canvas": "96x96",
      "viewBox": "0 0 96 96",
      "pivot": "center",
      "feature": "shield",
      "usage": ["break_feedback"],
      "visual": "中心向外 6-8 片纸伞碎片 + 4 根竹篾 + 1 段红线，径向散开。",
      "must": ["0.35s 可读", "纸/竹材质", "无血"],
      "avoid": ["玻璃高光", "红色血", "爆炸火球"],
      "code": ["Art.SHIELD_BREAK", "Game/Stats shield break"]
    },
    {
      "id": "paper_scrap_shell",
      "file": "enemies/paper_scrap_shell.svg",
      "tier": "P0",
      "kind": "enemy_variant",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "foot-24-44",
      "feature": "shelled",
      "usage": ["mob_shelled", "cup"],
      "visual": "以 paper_scrap.svg 为底，叠加覆盖上半身 60-70% 的冷米白浆壳，灰蓝裂纹 3-4 条，少量稻草纤维；保留纸边和接触阴影。",
      "must": ["48px 仍读成纸屑", "壳/未壳一眼区分", "脚底锚点不变", "接触阴影逐字节一致"],
      "avoid": ["暖金", "大面积 #F2A03D", "遮住脚底", "改变碰撞尺寸"],
      "code": ["Art.SHELL_PAPER", "Enemy._art_for(shelled)"]
    },
    {
      "id": "broken_kite_shell",
      "file": "enemies/broken_kite_shell.svg",
      "tier": "P0",
      "kind": "enemy_variant",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "foot-24-44",
      "feature": "shelled",
      "usage": ["mob_shelled", "fast"],
      "visual": "以 broken_kite.svg 为底，壳只覆盖机身中段/翼根，偏薄偏碎；保留青蓝机身、断线拖尾、#B8F6FF 速度预警。",
      "must": ["48px 仍读出快速兵青尾", "壳/未壳一眼区分", "脚底锚点不变"],
      "avoid": ["把整只风筝包成白壳", "遮住青尾", "暖金", "改变碰撞尺寸"],
      "code": ["Art.SHELL_KITE", "Enemy._art_for(shelled)"]
    },
    {
      "id": "broken_puppet_shell",
      "file": "enemies/broken_puppet_shell.svg",
      "tier": "P0",
      "kind": "enemy_variant",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "foot-24-44",
      "feature": "shelled",
      "usage": ["mob_shelled", "bag"],
      "visual": "以 broken_puppet.svg 为底，壳覆盖躯干/大腿外侧，关节留缝，块状偏厚，带稻草纤维；提线从壳外穿过。",
      "must": ["48px 仍读出傀儡关节/提线", "壳/未壳一眼区分", "脚底锚点不变"],
      "avoid": ["遮住全部提线", "暖金", "改变碰撞尺寸", "变成纸屑"],
      "code": ["Art.SHELL_PUPPET", "Enemy._art_for(shelled)"]
    },
    {
      "id": "ui_geng_drum",
      "file": "ui/ui_geng_drum.svg",
      "tier": "P0",
      "kind": "ui_icon",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "drum",
      "usage": ["hud_buff_badge"],
      "visual": "28x24 桶形更鼓，朱砂鼓身、米白鼓面、金铜钉，两条短鼓架，右侧两根交叉鼓槌。",
      "must": ["24px 剪影是桶 + 架 + 交叉槌", "与铜锣/铜铃区分", "内容在 4-44px 内"],
      "avoid": ["文字 更", "真实鼓乐人物", "复杂纹样"],
      "code": ["Art.UI_GENG_DRUM", "HUD drum buff"]
    },
    {
      "id": "drum_ripple",
      "file": "fx/drum_ripple.svg",
      "tier": "P0",
      "kind": "fx",
      "canvas": "256x256",
      "viewBox": "0 0 256 256",
      "pivot": "center-128-128",
      "feature": "drum",
      "usage": ["time_threshold_fx"],
      "visual": "两道同心铜环 r=70（4px, alpha .45）/ r=110（2px, alpha .25），8 个短缺口，中心完全透明。",
      "must": ["像时间余震，不像红色攻击预警", "中心透明", "0.6s 放大淡出", "地面层敌人之下"],
      "avoid": ["满圆填充", "文字", "爆炸感", "红黑攻击圈"],
      "code": ["Art.FX_DRUM_RIPPLE", "Game drum timer"]
    },
    {
      "id": "gong_aura_evolved",
      "file": "weapons/gong_aura_evolved.svg",
      "tier": "P1",
      "kind": "aura",
      "canvas": "256x256",
      "viewBox": "0 0 256 256",
      "pivot": "center-128-128",
      "feature": "gong_evolved",
      "usage": ["world_aura", "kaishi_luo"],
      "visual": "在 gong_aura 几何上加金边、朱砂绳结、16 颗铜钉、4 道极简开市光芒；中心仍透明。",
      "must": ["与基础铜锣光环可区分", "亮度 +15-20% 不纯白", "中心透明"],
      "avoid": ["满圆填充", "文字", "过度光晕"],
      "code": ["Art.GONG_AURA_EVOLVED", "EvolutionDB/WeaponManager"]
    },
    {
      "id": "inkline_beam_evolved",
      "file": "weapons/inkline_beam_evolved.svg",
      "tier": "P1",
      "kind": "beam",
      "canvas": "256x32",
      "viewBox": "0 0 256 32",
      "pivot": "left-center-0-16",
      "feature": "inkline_evolved",
      "usage": ["line_attack", "longjin_moxian"],
      "visual": "在 inkline_beam 几何上把核心改成 4px 金褐龙筋编织线，两侧保留墨黑边；左中锚点不变。",
      "must": ["与基础墨线可区分", "不裁白", "X 拉伸 1-3 倍不糊"],
      "avoid": ["箭头", "纯白", "霓虹", "彩虹渐变"],
      "code": ["Art.INKLINE_BEAM_EVOLVED", "EvolutionDB/WeaponManager"]
    },
    {
      "id": "regen_tick",
      "file": "fx/regen_tick.svg",
      "tier": "P1",
      "kind": "fx",
      "canvas": "32x32",
      "viewBox": "0 0 32 32",
      "pivot": "center",
      "feature": "regen",
      "usage": ["heal_tick"],
      "visual": "2-3 片青绿/米白叶片 + 1 滴露珠，向上飘；alpha <=0.6。",
      "must": ["与灯花/金币区分", "不抢画面", "静态图 + 代码上飘"],
      "avoid": ["金色", "红十字", "文字"],
      "code": ["Art.REGEN_TICK", "Stats/Player regen"]
    },
    {
      "id": "shell_crack",
      "file": "fx/shell_crack.svg",
      "tier": "P1",
      "kind": "overlay",
      "canvas": "48x48",
      "viewBox": "0 0 48 48",
      "pivot": "center",
      "feature": "shelled",
      "usage": ["hit_overlay"],
      "visual": "透明底，3-4 条米白/灰蓝裂纹，中心一点干浆碎屑；叠在浆壳兵受击帧上。",
      "must": ["不改变敌人剪影", "低 alpha", "仅受击短时显示"],
      "avoid": ["血", "玻璃高光", "大面积白"],
      "code": ["Art.SHELL_CRACK", "Enemy hit feedback"]
    },
    {
      "id": "ui_shield_pip",
      "file": "ui/ui_shield_pip.svg",
      "tier": "P1",
      "kind": "ui_icon",
      "canvas": "20x20",
      "viewBox": "0 0 20 20",
      "pivot": "center",
      "feature": "shield",
      "usage": ["hud_shield_amount"],
      "visual": "小油纸伞/护罩点，米白 + 青绿 + 朱砂边，10-14px 内容。",
      "must": ["20px 可读", "与心形/盾牌图标区分", "无文字"],
      "avoid": ["红十字", "真实宗教符号", "复杂细节"],
      "code": ["Art.UI_SHIELD_PIP", "HUD shield"]
    },
    {
      "id": "print_stamp_impact",
      "file": "weapons/print_stamp_impact.svg",
      "tier": "P2",
      "kind": "fx",
      "canvas": "64x64",
      "viewBox": "0 0 64 64",
      "pivot": "center",
      "feature": "print",
      "usage": ["impact_center"],
      "visual": "年画中心小冲击：纸屑 + 朱砂/青绿套色点，径向散开。",
      "must": ["不盖过主落点", "0.2s 淡出", "纸/木刻材质"],
      "avoid": ["文字", "火焰", "血"],
      "code": ["Art.PRINT_STAMP_IMPACT", "WeaponManager.fire_print"]
    },
    {
      "id": "evolve_gong_burst",
      "file": "fx/evolve_gong_burst.svg",
      "tier": "P2",
      "kind": "fx",
      "canvas": "96x96",
      "viewBox": "0 0 96 96",
      "pivot": "center",
      "feature": "gong_evolved",
      "usage": ["evolution_burst"],
      "visual": "铜环 + 金芒 + 朱绳，像开市锣一响；区别于 kailian_burst 的傩面裂开。",
      "must": ["0.55s 可读", "与开脸爆发可区分", "不遮玩家"],
      "avoid": ["傩面", "文字", "满屏白"],
      "code": ["Art.EVOLVE_GONG_BURST", "WeaponManager.spawn_evolve"]
    },
    {
      "id": "evolve_inkline_burst",
      "file": "fx/evolve_inkline_burst.svg",
      "tier": "P2",
      "kind": "fx",
      "canvas": "96x96",
      "viewBox": "0 0 96 96",
      "pivot": "center",
      "feature": "inkline_evolved",
      "usage": ["evolution_burst"],
      "visual": "墨龙盘绕 + 金褐龙筋，黑金为主；区别于开脸爆发。",
      "must": ["0.55s 可读", "与开脸/开市锣可区分", "不裁白"],
      "avoid": ["真实龙神", "文字", "霓虹"],
      "code": ["Art.EVOLVE_INKLINE_BURST", "WeaponManager.spawn_evolve"]
    },
    {
      "id": "prop_drum_tower",
      "file": "props/prop_drum_tower.svg",
      "tier": "P2",
      "kind": "prop",
      "canvas": "160x240",
      "viewBox": "0 0 160 240",
      "pivot": "bottom-center-80-240",
      "feature": "drum",
      "usage": ["ambient_prop"],
      "visual": "夜市鼓楼剪影：木架 + 大鼓 + 灯笼，深木/朱砂/暖光，底边中心锚点。",
      "must": ["不参与碰撞", "不与玩家灯抢亮", "24px 远景可辨"],
      "avoid": ["文字", "真实人物", "复杂场景"],
      "code": ["Art.PROP_DRUM_TOWER", "PropField whitelist"]
    },
    {
      "id": "shell_shatter",
      "file": "fx/shell_shatter.svg",
      "tier": "P2",
      "kind": "fx",
      "canvas": "64x64",
      "viewBox": "0 0 64 64",
      "pivot": "center",
      "feature": "shelled",
      "usage": ["death_fx"],
      "visual": "干浆片 + 纸屑 + 稻草纤维向外散，无血无玻璃高光。",
      "must": ["0.35s 可读", "像干浆/纸", "不抢其他死亡反馈"],
      "avoid": ["血", "玻璃", "爆炸火球"],
      "code": ["Art.SHELL_SHATTER", "Enemy death fx"]
    }
  ]
}
```

---

> **一句话**：v4 的美术重点不是“再加三把武器”，而是让**铜锣的领域、墨斗的线、年画的落点、浆壳的厚度、更鼓的时间感**在 48px 怪潮里各自有一个不会认错的视觉符号。
