# 《守艺人·百工夜行》v6 觉醒特效 + 美术资源策划案（给 AI 实施）

> **定位**：把 `skills-balance-v6.md` §6「满级觉醒」右列的特效钩子 + §4「打铁花铁水重做」翻译成**具体需要的 shader 与美术资源**。
> v6 §9 自己写明了「FX 本轮回图，仅留钩子，由美术/特效后续填充」——本文件就是那份"后续填充"的规格。
> **本文件只列资源需求与接入点，不写数值、不改游戏。** 数值真相源仍是 `docs/balance/v6_model.py`。
> 机器可读清单见同目录 `v6_fx_art_manifest.json`（字段与本文件逐条对应）。

---

## 0. 摘要（一句话 + 计数）

v6 的 9 把武器觉醒特效，**真正必须新写的是 1 个 shader（`molten_scatter` 铁水火星）+ 1 张美术（`awaken_badge` 觉醒徽记）**；其余 8 把全部靠**复用现有 13 个 shader + `art.modulate` 染色**，零新资源。另有 4 张美术为"推荐"（主题更准，不阻塞）。

| 类别 | 数量 | 清单 |
|---|---|---|
| 必须新写 shader | 1 | `molten_scatter` |
| 推荐新写 shader | 1 | `lantern_stream`（花灯走马灯，可复用 aura_field 替代） |
| 必须新画美术 | 1 | `awaken_badge.svg`（UI·Lv8 觉醒徽记） |
| 推荐新画美术 | 3 | `molten_blob.svg` / `ink_line_tex.svg` / `woodblock_seal.svg` |
| 复用 shader | 9 把武器全覆盖 | slash_arc / hurt_vignette / aura_field / area_ripple / projectile_trail / cast_burst / glow_aura / magic_circle / spawn_spark |
| 复用美术 | 0 新增 | 9 把武器本体 + 现有 fx/ui 贴图已齐 |

---

## 1. 范围与红线（先钉死，避免 AI 跑偏）

1. **本文件不碰数值**。Lv8 觉醒的"机制/数值拐点"由 v6 §6 左列和 `v6_model.py` 负责；本文件只管"觉醒长什么样"。
2. **不新增武器美术**。9 把武器（含 v5 的 gong/inkline/print）的世界贴图已存在于 `assets/art_shouyiren/weapons/`，且已登记 `Art.gd`。本次**零新武器贴图**。
3. **合批纪律是渲染红线**：同屏 50~200 的小怪（T0）**绝不挂独立 ShaderMaterial**。凡是"给敌人染色"（花灯减速暖色、糖画糖渍、糖色）一律用 `art.modulate`，**不写 shader**。只有个位数常驻节点（槽图标、光环圈、环绕体）才允许采样类 shader（`skill_rank_rim`/`aura_field` 等）。
4. **禁止 SCREEN_TEXTURE / DEPTH_TEXTURE**。全部 `canvas_item`，移动端 / Compatibility 通吃（沿用 `fx_manifest.json` 的选题红线）。
5. **径向/圆形 shader 按短边（720）归一化**，非正方形不会变椭圆。
6. **任何新 svg 必须登记 `Art.ALL_PATHS`**（冒烟测试的资源守卫依赖），否则漏接静默通过。

---

## 2. 总览表（9 武器 → 需要的特效 → 新/复用 → 新美术）

| 武器 | v6 §6 觉醒钩子 | 需要的特效 | 新/复用 | 需新美术 |
|---|---|---|---|---|
| 师刀 whip | 怒目傩面虚影双斩 + 暗红描边 | 双段 slash_arc + 全屏暗红描边 | **复用** slash_arc ×2 + hurt_vignette | 无 |
| 花灯 halo | 走马灯流光 + 减速敌染暖色 | 旋转光环（填充）+ 走马灯流光 | **复用** aura_field（改参数）+ **推荐** lantern_stream | 无 |
| 糖画 glowstick | 金色糖丝拉丝 + 糖晶迸裂 + 糖渍染色 | 金尾迹 + 命中迸裂 | **复用** projectile_trail + cast_burst | 无 |
| 皮影 phone | 剪影残像 + 撞击爆响 + Lv8 +1 环 | 暗色径向尾迹 + 小爆 | **复用** projectile_trail(暗) + spawn_spark | 无 |
| 剪纸 blade | 金粉尾迹 + 弹射纸花绽放 | 金尾迹 + 纸花色小爆 | **复用** projectile_trail + cast_burst | 无 |
| 打铁花 extinguisher | 漫天橙红火星 + 屏幕微光晕 + 二次溅射 | **径向火星爆发** + 屏幕光晕 | **新写** molten_scatter + **复用** glow_aura | `molten_blob.svg`（推荐弹体） |
| 铜锣 gong | 扩散金环 + 命中金属光 | 扩张金环 + 受击银白闪 | **复用** cast_burst(rays) + hit_flash | 无 |
| 墨斗 inkline | 龙筋纹理墨线 + 墨溅 | 龙筋平铺线 + 墨色小爆 | **复用** spawn_spark | `ink_line_tex.svg`（推荐） |
| 年画 print | 浮雕光印 + 金线描边 + 从天而降 | 法阵浮雕 + 印章动画 | **复用** magic_circle | `woodblock_seal.svg`（推荐） |
| **（全局）** | Lv8 卡面觉醒徽记 | 角标显示/隐藏 | — | **`awaken_badge.svg`（必须）** |

---

## 3. 必须新增（must）

### 3.1 shader：`molten_scatter`（打铁花 · 漫天火星）
- **为什么必须新写**：`cast_burst` 是单一干净环，表达不了"铁水撞地散成漫天火星"。v6 §4 的签名就是"撞一下 → 散成一大片小火花"，所以新写一个**径向火星爆发**，0 贴图、纯数学。
- **类型**：`canvas_item` / `blend_add` / 挂在碎裂点 ColorRect（边长 2×scatter_radius=300，z 低于本体）。
- **关键 uniform**（完整见 manifest）：`radius 0.95` / `sparks 5.0`(火星密度) / `spread 0.85` / `noise_scale 7.0` / `speed 1.4` / `scatter_color #FF7A1A` / `core_color #FFD16B` / `intensity 1.4`（未开 HDR2D 别超 1.6）。
- **接入**：`WeaponManager.fire_extinguisher` 铁水团首击碎裂处调用 `ShaderFX.molten_scatter(parent, center, 150.0, Color(1,0.48,0.10))`；`scatter_cap 16` 限制单发火星数，防同群叠炸（v6 §4 警告：每发只引爆一次，否则 +166% 双算）。
- **二次溅射（百子千花进化）**：在同一碎裂点二次调用 `molten_scatter`，`area ×1.40`。
- **坑**（渲染达红线）：① `blend_add` 下 src 再乘一次 `src.a` → `COLOR.a` 恒 1.0，亮度全算进 rgb；② 极坐标噪声接缝——角度转单位圆坐标再采，禁止 `(atan, 半径)` 直接采样（同 `aura_field`）；③ 半径 150 在 720 竖屏约占 0.42 屏宽，ColorRect 边长用 300，按短边归一化。
- **参考**：[explosion-shockwave](https://godotshaders.com/shader/explosion-shockwave/) / [particle-shockwave-ring](https://godotshaders.com/shader/particle-shockwave-ring/)

### 3.2 美术：`awaken_badge.svg`（UI · 觉醒徽记）—— 必须
- **为什么必须**：v6 §6 明写"卡面在 Lv8 显示「觉醒」徽记"。这是文档直接要求的卡面元素，没有就满足不了"满级有表现"。
- **规格**：约 64×32，描边型，纯色+描边，适配 `ui_paper_card` 剪纸风。朱红底 + 金边（与 `skill_rank_rim` 的 `high_color #FF5C38` 同族）。叠在卡面右上角，**非 Lv8（含进化）时隐藏**。
- **登记**：`Art.AWAKEN_BADGE` + `Art.ALL_PATHS`。

---

## 4. 推荐新增（recommended，不阻塞）

| id | 类型 | 用途 | 规格要点 |
|---|---|---|---|
| `lantern_stream` | shader | 花灯"走马灯流光"（§6 追加） | `canvas_item`/`blend_add`，沿圆周匀速流动的一道金亮带（`flow_speed 1.8`、`lantern_color #FFC752`）。**可替代方案**：直接把现有 `aura_field` 的 `swirl_speed` 调高 + 填充内部，已能读成旋转光环，不必新写。 |
| `molten_blob.svg` | 美术 fx | 打铁花铁水团弹体 | 约 24×24 橙红熔核+外晕。替代当前复用的 `sugar_thread.svg`，让弹体读得出"熔铁"而非"糖丝"。**可替代方案**：复用 `FX_SPARK` 染橙。 |
| `ink_line_tex.svg` | 美术 weapon | 墨斗"龙筋纹理"墨线 | 256×8 可平铺横向长条，墨色+暗青描边，中间龙筋结节。由墨斗沿 玩家→目标 拉伸平铺，Lv8 改 `scale.y` 加粗。 |
| `woodblock_seal.svg` | 美术 fx | 年画"雕版印记/浮雕光印" | 约 160×160 方形阴刻印（门神/莲花/回字边），金线描边。落地用 sprite 缩放+淡入"从天而降"，叠 `magic_circle` 金线。 |

---

## 5. 复用清单（逐武器，含具体 shader + 现有美术路径 + 接入点 + 护合批注记）

> 现有美术路径均已在 `Art.gd` 登记，无需新增。下列"染色"类一律 `art.modulate`，不破坏 T0 合批。

- **师刀 whip**：`slash_arc`（双段，`flip` 一次做双斩）+ `hurt_vignette`（暗红描边，复用默认 `hurt_color #850F0D`）。怒目傩面虚影 = 玩家 `front` sprite 半透明复制 + 两层 slash_arc。**美术：`nuo_blade_arc.svg`。**
- **花灯 halo**：`aura_field` 由"贴边窄带"改为**填充内部 + 提高 `swirl_speed` 转旋转光环**（参数调整，无新资源）；减速敌染暖色 = `Enemy.art.modulate` 暖色（**T0 不走 shader**）。**美术：`lantern_halo.svg`。**
- **糖画 glowstick**：`projectile_trail`（`trail_color #FFDB8C` 金色糖丝）+ `cast_burst`（小半径金色，命中糖晶迸裂）。糖渍减速视觉 = 糖色 `modulate`。**美术：`sugar_thread.svg`。**
- **皮影 phone**：`projectile_trail`（暗色径向版，剪影残像）+ `spawn_spark`（撞击剪纸爆响）。Lv8 +1 环绕 = 多挂一个 orbit sprite。**美术：`shadow_puppet.svg`。**
- **剪纸 blade**：`projectile_trail`（金粉尾迹）+ `cast_burst`（纸色小半径，弹射点小纸花绽放）。**美术：`paper_cut_bird.svg`。**
- **打铁花 extinguisher**：`molten_scatter`（新，漫天火星）+ `glow_aura`（屏幕微光晕，橙，短命全屏覆盖）。**美术：`iron_flower_ladle.svg`（武器）+ `molten_blob.svg`（推荐弹体）。**
- **铜锣 gong**：`cast_burst`（`gather=false`、金、`rays 8~12`，每脉冲周期外扩）+ `hit_flash`（`flash_color` 银白，命中泛金属光）。**美术：`gong.svg` / `gong_evolved.svg`。**
- **墨斗 inkline**：`spawn_spark`（墨色小爆发，命中墨溅）。墨线变粗 = 拉伸 sprite 改 `scale.y`；龙筋纹理用 `ink_line_tex.svg` 平铺。**美术：`inkline.svg` + 推荐 `ink_line_tex.svg`。**
- **年画 print**：`magic_circle`（浮雕光印 + 金线描边，`appear` 动画）。从天而降 = 印章 sprite 缩放+淡入（非 shader）。**美术：`woodblock_print.svg` + 推荐 `woodblock_seal.svg`。**

---

## 6. 渲染红线与约束（AI 落地必须遵守）

- **合批**：T0 小怪绝不挂独立 ShaderMaterial；敌人染色一律 `art.modulate`。
- **render_mode**：新增 `molten_scatter` / `lantern_stream` 走 `blend_add`，`COLOR.a` 恒 1.0，亮度全算进 rgb。
- **禁 SCREEN_TEXTURE / DEPTH_TEXTURE**：移动端 / Compatibility 通吃。
- **短边归一化**：径向/圆形 shader 按 720 短边归一化。
- **HUD**：觉醒徽记叠在 `ui_paper_card` 之上，不新开 Control 层。
- **美术登记**：任何新 svg 必须进 `Art.ALL_PATHS`（冒烟守卫依赖）。

---

## 7. 接入点文件映射（AI 落地对照）

| 文件 | 改什么 |
|---|---|
| `scripts/weapons/WeaponManager.gd` | `fire_extinguisher` 铁水团碎裂处调 `molten_scatter`；`fire_whip` 双段 slash_arc；`fire_halo`/`fire_projectile`/`_place_orbit_ring` 的 trail/cast 接入；墨线/年画纹理拉伸 |
| `scripts/GarlicRing.gd` | `aura_field` 填充+旋转（替代压边带）；可选 `lantern_stream` 建/resize/beat |
| `scripts/Enemy.gd` | 减速/糖渍用 `art.modulate` 暖色/糖色（T0 合批安全） |
| `scripts/EvolutionDB.gd` | `extinguisher→百子千花` 二次溅射（molten_scatter 二次调用） |
| `scripts/ui/HUD.gd` | 武器槽行 + 觉醒徽记（Lv8 显示）；`skill_rank_rim` 已接 |
| `scripts/Art.gd` | 新 svg 常量 + `ALL_PATHS` 登记（`AWAKEN_BADGE`/`MOLTEN_BLOB`/`INK_LINE_TEX`/`WOODBLOCK_SEAL`） |
| `scripts/ShaderFX.gd` | 新增 `molten_scatter()` / `lantern_stream()` API（含短边归一化与节点尺寸换算） |

---

## 8. 验收（回归命令 + 新检查）

**回归基线（不得回退）**：
```
godot --path GameDemo/first-xi-xue-gui res://tools/SmokeTest.tscn          # 299/0
godot --path GameDemo/first-xi-xue-gui res://tools/FxInGame.tscn           # 18/18
godot --path GameDemo/first-xi-xue-gui res://tools/SkillInGame.tscn        # 32/32
godot --path GameDemo/first-xi-xue-gui res://tools/SkillSheet.tscn         # 重渲 skill-preview.png
godot --path GameDemo/first-xi-xue-gui res://tools/FxSheet.tscn            # 重渲 fx-preview.png
```

**本任务新增检查**：
1. `molten_scatter` 在 150 半径下可见像素 >20% 且无纯白过曝（数值可见性断言，仿 §9.4）。
2. `awaken_badge` 仅在 Lv8（含进化）卡面显示，其余等级隐藏。
3. 4 张新 svg 全部被 `Art.ALL_PATHS` 覆盖（冒烟守卫通过）。
4. 花灯/皮影 Lv8 觉醒特效开启后，同屏小怪 draw call 数不回退（合批未破坏）。

---

## 9. 给 AI 的必读文件（按序）

1. `docs/design/skills-balance-v6.md`（§4 铁水重做 / §6 觉醒表 / §9 落地清单）
2. `docs/design/v6_fx_art_manifest.json`（本任务机器可读清单，字段最全）
3. `assets/shaders/fx/fx_manifest.json`（现有 13 shader 的参数/坑/接线点）
4. `scripts/ShaderFX.gd`（统一调用层，新增 API 落这里）
5. `scripts/Art.gd`（资源路径集中管理 + 合批守卫 `ALL_PATHS`）
6. `scripts/weapons/WeaponManager.gd` / `scripts/GarlicRing.gd` / `scripts/Enemy.gd`（接入点）

> 一句话交付意图：v6 的"满级有表现"靠这 1 个新 shader + 1 张徽记就够落地 9 把武器的觉醒视觉；其余全是复用与染色，没有不可控的新资源。
