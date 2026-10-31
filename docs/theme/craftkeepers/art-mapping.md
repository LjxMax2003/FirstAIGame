# 《守艺人：百工夜行》美术资产映射表

> 目标：把现有 34 张“现代都市夜行”SVG，逐张替换为“非遗百工夜市”皮肤；**画布尺寸、碰撞尺寸、脚本判定全部不变**，只换贴图、文件名与显示名。
>
> 配套：[策划案.md](design.md) · [非遗依据与合规.md](compliance.md)
>
> 适用工程：`GameDemo/first-xi-xue-gui`（Godot 4.7.2）

---

## 1. 替换原则

1. **画布不变**：敌我贴图的 `viewBox`/尺寸尽量保持原值，避免 `Enemy.contact_r`、武器判定、锚点跟着改。
2. **剪影优先**：48px 下先看轮廓，再看颜色；忘影统一“无脸/破边/纸墨木偶”材质。
3. **色彩克制**：夜蓝底 + 暖光点；普通敌人低饱和，精英金/朱砂描边，Boss 单一高饱和重点色。
4. **不血腥**：所有死亡表现是纸屑、墨点、光尘、断线；不出现血肉、骨骼、真实人脸。
5. **SVG 友好**：平涂、少渐变、少半透明叠层；2~4 层即可；文字转路径。
6. **不换 id**：`whip/halo/glowstick/phone/blade/extinguisher` 等代码 id 不动，只换 `name` / `desc` / `svg`。

---

## 2. 路径策略

### 2.1 新目录

建议新建：

```
assets/art_shouyiren/
├── characters/
├── enemies/
├── fx/
├── ground/
├── items/
├── props/
├── stalls/        # 新增：摊位/地标
├── ui/
└── weapons/
```

旧 `assets/art/` 保留不删，作为换皮前后对照；确认稳定后再清理。

### 2.2 两种接入方式

| 方式 | 做法 | 优点 | 缺点 | 建议 |
|---|---|---|---|---|
| A. 同文件名覆盖 | 新目录沿用旧文件名，只改 `Art.gd` 根路径 | 改动最小 | 文件名语义错位（`enemy_cup.svg` 里是纸屑） | 不推荐 |
| B. 语义化新文件名 | 新目录用新名字，逐处更新路径 | 可读、可维护 | 需要改 4 个脚本 + 10 个场景引用 | **推荐** |

### 2.3 需要改路径的位置（已核对）

| 文件 | 引用 |
|---|---|
| `scripts/Art.gd` | 全部 34 个 `const` 路径 |
| `scripts/WeaponDB.gd` | `svg`、`bullet_svg` 字段（6 把武器） |
| `scripts/EvolutionDB.gd` | 3 条进化的 `svg` 字段 |
| `scripts/PickupField.gd` | 磁铁/炸弹/糍粑的 `svg` 字段 |
| `scenes/Player.tscn` | `player_front.svg`、`halo_ring.svg` |
| `scenes/Enemy.tscn` | `enemy_cup.svg`（默认贴图） |
| `scenes/Gem.tscn` | `gem_blue.svg` |
| `scenes/Game.tscn` | `bg_city_dusk.svg` |
| `scenes/ui/HUD.tscn` | `ui_bar_fill.svg`、`ui_bar_frame.svg`、`gem_blue.svg` |
| `scenes/ui/PauseUI.tscn` | `ui_card_frame.svg` |
| `scenes/ui/DeathUI.tscn` | `enemy_reaper.svg` |

> `LevelUpUI` 的卡框如果由 `Art.UI_CARD_FRAME` 运行时读取，改 `Art.gd` 即可；如果场景里也有引用，按上表同样处理。

---

## 3. 现有 34 张 SVG 逐张映射

> “原尺寸”以现有 `viewBox` 为准；未标注的保持原文件尺寸。`P0` = 首版必须，`P1` = 首版尽量，`P2` = 第二版。

### 3.1 角色（2）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 尺寸 | 说明 |
|---|---|---|---|---|---|---|
| P0 | `characters/player_front.svg` | 玩家正面 | `characters/shouyiren_front.svg` | 守艺人阿满正面：斗笠/围裙/提灯，暖色轮廓光 | 64×80 | 保留原锚点；灯在身侧，不挡脸 |
| P0 | `characters/player_back.svg` | 玩家背面 | `characters/shouyiren_back.svg` | 背面：灯在身后形成暖光边 | 64×80 | 与正面同一轮廓，转身不跳 |

### 3.2 敌人（6）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 尺寸 | 说明 |
|---|---|---|---|---|---|---|
| P0 | `enemies/enemy_cup.svg` | 奶茶杯杂兵 | `enemies/paper_scrap.svg` | 纸屑团：撕裂纸边、米白、两点墨 | 48×48 | 最基础；轮廓要小、密、快 |
| P0 | `enemies/enemy_cup_fast.svg` | 快速杯兵 | `enemies/broken_kite.svg` | 断线纸鸢：青蓝破风筝、断线拖尾 | 48×48 | 保留“快速怪亮青描边/拖尾”预警 |
| P0 | `enemies/enemy_bag.svg` | 外卖袋兵 | `enemies/broken_puppet.svg` | 断线傀儡：木偶关节、断线垂落 | 48×48 | 中速厚血；关节形状要区别于纸屑 |
| P0 | `enemies/enemy_elite_box.svg` | 纸箱精英 | `enemies/ink_blob_elite.svg` | 墨渍精英：黑墨团、纸纤维、金边 | 96×96 | Phase 2 死亡留墨池；首版只换皮 |
| P0 | `enemies/enemy_elite_red.svg` | 红色精英 | `enemies/faceless_nuo_elite.svg` | 残面傩精英：朱砂傩面、面部留白 | 96×96 | 与 Boss“无面傩”同源但更小；避免混淆 |
| P0 | `enemies/enemy_reaper.svg` | 死神 Boss | `enemies/lost_visage.svg` | 失传之相基底：高大人形、破面具/断线 | 80×112 | 可作为“无面傩”Boss 基底；哑鼓/长夜灯另做 |

### 3.3 武器（7）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 说明 |
|---|---|---|---|---|---|
| P0 | `weapons/whip_arc.svg` | 鞭弧 | `weapons/nuo_blade_arc.svg` | 傩面·师刀弧光：朱砂红、木刻边、怒目 | 保留矩形横扫的视觉长度/宽度 |
| P0 | `weapons/halo_ring.svg` | 光环 | `weapons/lantern_halo.svg` | 花灯灯晕：暖橙、纸罩、呼吸光 | 保留现有半径视觉；注意 332×332 缩放方案 |
| P0 | `weapons/wand_glowstick.svg` | 荧光棒武器图标 | `weapons/sugar_ladle.svg` | 糖画铜勺：琥珀糖丝、石板 | 图标 48px 可辨 |
| P0 | `weapons/bullet_glowstick.svg` | 荧光棒子弹 | `weapons/sugar_thread.svg` | 糖丝：细长琥珀线、糖点 | 弹道命中点要清晰 |
| P0 | `weapons/phone_orbit.svg` | 手机环绕物 | `weapons/shadow_puppet.svg` | 皮影武将：青绿、竹签、关节 | 环绕时朝向/旋转可读 |
| P0 | `weapons/knife_boxcutter.svg` | 美工刀/飞刀 | `weapons/paper_cut_bird.svg` | 纸鹊/纸刀：朱红、锯齿边 | 弹射时轮廓要尖 |
| P0 | `weapons/axe_extinguisher.svg` | 灭火器/斧 | `weapons/iron_flower_ladle.svg` | 打铁花铁勺 + 铁花 | 扇形喷射的视觉方向要明确 |

### 3.4 掉落/道具（7）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 说明 |
|---|---|---|---|---|---|
| P0 | `items/gem_blue.svg` | 蓝宝石 | `items/light_bloom.svg` | 灯花：蓝白纸灯花 | 经验普通掉落；保持小尺寸可读 |
| P0 | `items/gem_orange.svg` | 橙宝石 | `items/gold_spark.svg` | 金火星：金色火星 | 高价值；scale 1.6 + 脉动 |
| P0 | `items/chest.svg` | 宝箱 | `items/craft_box.svg` | 百工匣：木匣、铜扣、红纸封 | 进化宝箱；开箱金光 |
| P0 | `items/coin.svg` | 金币 | `items/copper_coin.svg` | 铜钱：方孔、铜绿 | 结算/HUD |
| P0 | `items/pickup_bento.svg` | 饭盒 | `items/ciba.svg` | 糍粑/糖瓜：米白、芝麻 | 回血；暖色 |
| P0 | `items/pickup_bomb.svg` | 炸弹 | `items/firecracker.svg` | 爆竹：红纸、金引线 | 清屏；保留限流 |
| P0 | `items/pickup_magnet.svg` | 磁铁 | `items/bronze_bell.svg` | 铜铃：铜绿、红绳 | 全图吸灯花 |

### 3.5 场景/道具（6）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 尺寸 | 说明 |
|---|---|---|---|---|---|---|
| P0 | `ground/ground_tile.svg` | 城市地砖 | `ground/stone_tile.svg` | 青石板 + 夜市拼砖，无缝 | 256×256 | 保持无缝；用世界格翻转/明暗去重复 |
| P1 | `props/prop_cone.svg` | 路锥 | `props/lantern_stand.svg` | 灯笼架/路引 | 原尺寸 | 可破坏物；掉铜钱/灯花 |
| P1 | `props/prop_trash.svg` | 垃圾桶 | `props/bamboo_basket.svg` | 竹篓 | 原尺寸 | 低风险资源 |
| P1 | `props/prop_hydrant.svg` | 消防栓 | `props/stone_lamp.svg` | 石灯 | 原尺寸 | 地标/装饰 |
| P1 | `props/prop_bike.svg` | 自行车 | `props/goods_cart.svg` | 货担/独轮车 | 原尺寸 | 可破坏物 |
| P1 | `props/prop_vending.svg` | 自动售货机 | `props/sugar_stall.svg` | 糖画摊/摊位柜 | 原尺寸 | 可破坏物；首版只掉铜钱 |

### 3.6 特效（2）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 说明 |
|---|---|---|---|---|---|
| P0 | `fx/fx_spark.svg` | 打击火花 | `fx/gold_spark_fx.svg` | 金火星/纸屑爆点 | 命中反馈；不血腥 |
| P0 | `fx/fx_evolve_star.svg` | 进化星芒 | `fx/kailian_burst.svg` | 开脸金光：面具裂开、朱砂/金 | 进化瞬间的屏幕中心 |

### 3.7 UI（4）

| 优先级 | 现有路径 | 现有内容 | 新文件 | 新内容 | 尺寸 | 说明 |
|---|---|---|---|---|---|---|
| P0 | `ui/bg_city_dusk.svg` | 城市黄昏背景 | `ui/bg_night_market.svg` | 夜市灯笼长街：夜蓝、暖灯、摊位剪影 | 720×1280 | 保留竖屏构图；不要抢 HUD 对比 |
| P0 | `ui/ui_bar_frame.svg` | 血条框 | `ui/ui_lantern_frame.svg` | 灯架/木牌框 | 320×20 | 与灯焰填充配套 |
| P0 | `ui/ui_bar_fill.svg` | 血条填充 | `ui/ui_flame_fill.svg` | 灯焰渐变：暖橙红 | 312×12 | 现有代码用运行时渐变；贴图作为底/高光 |
| P0 | `ui/ui_card_frame.svg` | 升级卡框 | `ui/ui_paper_card.svg` | 红纸/木刻传承卡框 | 200×280 | 三张卡并排时边框可读 |

---

## 4. 新增资产清单

### 4.1 P0：首版必须

| 文件 | 内容 | 尺寸建议 | 用途 |
|---|---|---|---|
| `stalls/stall_sugar.svg` | 糖画摊：铜勺、石板、糖画架 | 180×140 | 地图摊位/可破坏物 |
| `stalls/stall_shadow.svg` | 皮影戏台：白幕、竹架、灯 | 180×140 | 地图摊位/地标 |
| `stalls/stall_lantern.svg` | 灯彩摊：宫灯、走马灯 | 180×140 | 地图摊位 |
| `stalls/stall_paper.svg` | 剪纸摊：红纸、剪刀、窗花 | 180×140 | 地图摊位 |
| `stalls/stall_forge.svg` | 铁花摊：火炉、铁勺、柳棚 | 180×140 | 地图摊位 |
| `stalls/lantern_pillar.svg` | 百工灯柱 | 80×200 | 四角地标 |
| `stalls/archway.svg` | 夜市牌坊 | 320×200 | 入口/构图 |
| `stalls/old_stage.svg` | 老戏台 | 400×220 | 中央地标/Boss 登场 |
| `enemies/boss_drum.svg` | 哑鼓 Boss | 160×160 | 15:00 Boss |
| `enemies/boss_faceless_nuo.svg` | 无面傩 Boss | 128×160 | 25:00 Boss（可与 `lost_visage` 共用基底） |
| `enemies/boss_long_night_lantern.svg` | 长夜灯 Boss | 160×160 | 30:00 Boss |
| `ui/ui_paper_texture.svg` | 可平铺纸纹 | 256×256 | UI/卡牌底纹 |
| `ui/ui_wood_sign.svg` | 木牌 | 240×80 | 暂停/按钮/提示 |
| `ui/ui_seal.svg` | 朱印 | 64×64 | 卡牌分类/结算 |
| `ui/intro_01.svg` | 开场：师父与百工灯 | 720×1280 | 开场插画 |
| `ui/intro_02.svg` | 开场：夜市与忘影 | 720×1280 | 开场插画 |
| `ui/intro_03.svg` | 开场：阿满提灯走入 | 720×1280 | 开场插画 |

### 4.2 P1：首版尽量

| 文件 | 内容 | 用途 |
|---|---|---|
| `characters/char_sugar.svg` | 糖画师立绘/头像 | 后续角色 |
| `characters/char_shadow.svg` | 皮影班主 | 后续角色 |
| `characters/char_paper.svg` | 剪纸婆婆 | 后续角色 |
| `characters/char_lantern.svg` | 灯彩匠 | 后续角色 |
| `characters/char_forge.svg` | 铁花匠 | 后续角色 |
| `ui/codex_bg.svg` | 百工图鉴背景 | 图鉴 |
| `fx/boss_warning_ring.svg` | 哑鼓地面预警圈 | Boss 预警 |
| `fx/boss_mask_glow.svg` | 无面傩面具发光 | Boss 预警 |
| `fx/boss_lantern_drain.svg` | 长夜灯吸光 | Boss 预警 |

### 4.3 P2：第二版

| 文件 | 内容 |
|---|---|
| `ui/bg_ancestral_hall.svg` | 祠堂前坪地图 |
| `ui/bg_river_dock.svg` | 河灯渡口地图 |
| `ui/bg_back_alley.svg` | 工坊后巷地图 |
| `stalls/seasonal_*.svg` | 节日活动摊位 |

---

## 5. 美术规范

### 5.1 画布与锚点

- 角色/敌人保持原画布与脚底锚点；Boss 可以放大画布，但**碰撞半径与判定用原参数**，视觉缩放单独处理。
- 武器特效保持原判定长度/宽度；贴图可以更华丽，但不要改变玩家对范围的预期。
- 地面 256×256 无缝；用世界格坐标做翻转/明暗，避免相机移动时跳变。

### 5.2 剪影测试

每张敌人图必须通过：

1. 缩到 48×48；
2. 填充纯黑；
3. 能区分：纸屑 / 纸鸢 / 傀儡 / 墨渍 / 残面傩 / Boss。

如果黑白剪影分不出，靠颜色也不行——移动端怪潮里颜色会被特效盖住。

### 5.3 配色

| 色 | 值 | 用途 |
|---|---|---|
| 夜蓝 | `#0F1B2D` | 背景/暗部 |
| 墨黑 | `#1A1A1A` | 忘影剪影 |
| 朱砂 | `#C53B2E` | 傩面/剪纸/印章 |
| 灯笼橙 | `#F2A03D` | 玩家灯焰/花灯 |
| 琥珀 | `#E8B04B` | 糖画/金火星 |
| 青绿 | `#3E7C74` | 皮影/纸鸢 |
| 米白 | `#F4E8D0` | 纸/灯罩 |
| 金 | `#D9A441` | 精英/进化/宝箱 |
| 冷灰 | `#6B7A8F` | 被遗忘物 |

- 玩家永远有暖色轮廓光；敌人不要用大面积暖色，避免和玩家/掉落混淆。
- 精英用金/朱砂描边，不要只靠体型。
- 快速怪保留亮青描边/拖尾；色盲玩家靠形状+描边识别。

### 5.4 动画

- 2~3 帧纸片抖动即可；不需要骨骼。
- 皮影武器用 2~3 段竹签旋转，做出“操偶”感。
- 命中：纸屑/墨点/金火星 + 轻微屏幕震动；不喷血。
- Boss 预警：地面圈、面具发光、灯光被吸暗；提前 0.4 秒。
- 粒子上限：同屏 300+ 敌人时，Boss/打铁花特效要能降级为贴图动画。

### 5.5 字体与 UI

- 标题/卡牌：思源宋体；数字/HUD：思源黑体；均为开源字体，需遵守 SIL OFL。
- 卡牌描述 2 行内；字号 ≥22px（720 宽逻辑分辨率）。
- UI 底纹用纸纹 + 木牌 + 朱印，但不要每张卡都堆纹理；保持对比度。
- 血条=灯焰（暖橙红）；经验条=归色（米白→彩色）；计时=更次。

---

## 6. 首版实施顺序

| 顺序 | 工作 | 验收 |
|---|---|---|
| 1 | 定色板/剪影规范/三张概念图（阿满、傩面、花灯） | 5 人盲测能说出“夜市/手艺/纸” |
| 2 | 玩家 + 3 杂兵 + 2 精英 + 1 Boss 基底 | 48px 剪影可辨；300 怪中玩家可见 |
| 3 | 6 武器 + 7 掉落 + 2 特效 | 每把武器一眼能区分；命中不糊 |
| 4 | 地面 + 5 摊位 + 灯柱 + 牌坊 + 戏台 | 无限地图不重复、不迷路 |
| 5 | UI（HUD/升级/暂停/结算/商店） | 720 宽可读；灯焰/归色/更次成立 |
| 6 | 3 张开场插画 + 3 个 Boss 完整立绘 | 商店页/预告片可用 |
| 7 | 全量替换 + 回归测试 | 229 项全绿；30 分钟长跑无异常 |

---

## 7. 验收清单

- [ ] 34 张旧资产均有新文件对应，无缺失路径。
- [ ] `Art.gd`、`WeaponDB.gd`、`EvolutionDB.gd`、`PickupField.gd` 路径全部更新。
- [ ] 10 个 `.tscn` 的 `ext_resource` 路径全部更新。
- [ ] 所有敌人 48px 黑白剪影可区分。
- [ ] 玩家在 300 怪中可一眼找到（暖色轮廓光）。
- [ ] 6 把武器的特效/图标在 48px 下可区分。
- [ ] 血条/经验条/计时/武器槽在 720 宽下可读。
- [ ] 无血腥、无真实人脸、无真实祭祀/神灵形象。
- [ ] 同屏敌人数量与帧率不低于换皮前。
- [ ] 229 项自动化检查全部通过。
- [ ] 文化顾问对玩家/敌人/Boss/UI 概念图签字。

---

## 8. 首版资产生成状态（2026-10-27）

**位置**：`assets/craftkeepers/`（生成器 + 产物 + 校核证据）
**产物**：60 张 SVG = 34 张换皮 + 17 张 P0 新增 + 9 张 P1 新增；另有 `manifest.json`、`预览.html`、3 张 Godot 光栅化校核拼版。

| 本文档条目 | 状态 |
|---|---|
| §2 的 34 张换皮（含新文件名与尺寸） | **全部产出**，画布与原素材逐一对齐，Godot 实测宽高一致 |
| §3 的 P0 新增 17 张 | **全部产出**（5 摊位 / 灯柱 / 牌坊 / 戏台 / 3 Boss / 3 UI / 3 过场） |
| §3 的 P1 新增 9 张 | **全部产出**（5 立绘 / 图鉴底 / 3 个 Boss 特效） |
| §3 的 P2（3 张地图背景） | **未做**——属于场景美术，需先定无限地图的分区方案 |
| 光环 332×332 放大版（§冲突方案 1） | **未做**，仍是 256×256；需要单独出一版 |
| §4 落地清单（改 `Art.gd` 等 4 脚本 + 7 场景） | **未执行**，本次只准备资源，不动工程 |

**校核方式**：本机无可用无头浏览器，改用工程同款 Godot 4.7.2 `--headless` 导入并光栅化（`render_check/tools/Dump.gd`），
以原生像素尺寸拼版后逐张看。60 张全部加载成功，实测尺寸与声明一致。

**校核中修掉的 6 个问题**（详见 `assets/craftkeepers/README.md` §4）：
径向渐变缺 `userSpaceOnUse`（光晕全透明）、线性渐变默认横向（明暗方向反）、
血条填充底色过暗（与 tint 相乘发脏）、升级卡用撕纸多边形读成"一团纸"、
月亮用暗圆压亮圆读成日食、远景屋顶与夜空色差不足（背景糊成一块）。

**下一轮手绘重点**：5 个摊位需要各自独占的轮廓符号；5 张立绘目前几乎同一张脸；
快速兵的亮青描边仍需在 `Enemy.gd` 侧实现，不能只靠贴图。

---

> **一句话**：这次不是“画一套国风素材”，而是把现有的 34 个功能槽位，换成 34 个能讲同一个故事的视觉符号。功能不变，符号全换。
