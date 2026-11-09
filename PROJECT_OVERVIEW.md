# 《守艺人 · 百工夜行》项目内容总览

> 本文档说明当前 Godot 游戏项目的**目录结构**与**代码分层逻辑**：每个脚本挂在哪个场景/节点、属于哪一层、对外提供什么参数与方法、修改了什么数据、触发/响应什么事件。
>
> - 引擎：Godot **4.7.2**（Mobile 渲染器 / D3D12 / Jolt 物理）
> - 项目根：`GameDemo/first-xi-xue-gui/`
> - 分辨率：720 × 1280 竖屏，`canvas_items + expand`，60 FPS 上限
> - 主场景：`res://scenes/MainMenu.tscn`
> - 玩法：竖屏「吸血鬼幸存者」式 30 分钟生存 —— 自动武器、击杀掉灯花经验、升级三选一、精英掉宝箱进化、三档 Boss + 小 Boss、潮涌、暂停/结算、局外铜钱与永久传承
>
> 项目内部曾用名《守艺人·百工夜行》；仓库与工程名统一为 `FirstXiXueGui`。对外口径为「民俗手艺题材」（合规红线：不使用"非遗"二字，见工作区 `README.md`）。

---

## 0. 阅读指南

| 想看什么 | 直接跳到 |
| --- | --- |
| 仓库里都有什么、各目录放什么 | §1 工作区结构、§2 项目结构与资源目录 |
| 每个场景由哪些节点组成、脚本挂在哪 | §3 场景挂载总表 |
| 代码怎么分层、各脚本职责 | §4 分层模型、§5～§8 逐脚本说明 |
| 一条玩法事件经过哪些代码 | §9 信号与事件链 |
| 数值在哪、单局节奏 | §10 时间轴与数值真值 |
| 音频怎么接的 | §11 音频系统 |
| 全部脚本速查 | 附录 A |

---

## 1. 工作区结构

工作区根 `e:\AITemp\QoderGameFirst`：

```
QoderGameFirst/
├─ GameDemo/
│  └─ first-xi-xue-gui/          ← Godot 项目根（用 Godot 打开这一层）
├─ assets/                       ← 工作区级素材（与游戏项目内 assets 不同）
├─ docs/                         ← 工作区级文档
├─ reports/                      ← 报告/产出
├─ tools/                        ← 工作区级工具
├─ release/                      ← 发布包（Windows 单文件 exe、Android APK、README 与校验值）
├─ PROJECT_OVERVIEW.md           ← 本文
├─ README.md
├─ AI_USAGE.md
├─ iron_flower_reference.md      ← 打铁花题材参考资料
└─ .git/  .gitignore  LICENSE
```

> 注意区分：**工作区**根目录下的 `assets/ docs/ reports/ tools/` 是资料与工具区（**不纳入公开仓库**，见 `.gitignore`）；游戏真正加载的资源全部在 `GameDemo/first-xi-xue-gui/assets/` 下，代码在 `scripts/` 下。公开仓库只含 `GameDemo/` 与 `release/`。

---

## 2. 项目结构与资源目录

### 2.1 项目根目录树

```
GameDemo/first-xi-xue-gui/
├─ project.godot            引擎配置（autoload / 输入 / 分辨率 / 渲染）
├─ export_presets.cfg       导出预设
├─ icon.svg
│
├─ scenes/                  场景（可复用场景与 UI 场景）
│  ├─ MainMenu.tscn          开始界面
│  ├─ Game.tscn              单局主场景（World + UI）
│  ├─ Player.tscn            玩家
│  ├─ Enemy.tscn             敌人（池化模板）
│  ├─ Gem.tscn               灯花经验（池化模板）
│  ├─ weapons/
│  │  └─ WeaponManager.tscn  武器管理器（无子节点，纯逻辑）
│  └─ ui/
│     ├─ HUD.tscn            战斗 HUD
│     ├─ LevelUpUI.tscn      升级三选一
│     ├─ PauseUI.tscn        暂停菜单
│     ├─ DeathUI.tscn        结算面板
│     └─ ShopUI.tscn         局外商店
│
├─ scripts/                 全部 GDScript（43 个 .gd）
│  ├─ *.gd                   28 个顶层脚本（autoload / 数据表 / 世界逻辑）
│  ├─ ui/*.gd                14 个界面脚本
│  └─ weapons/
│     └─ WeaponManager.gd    武器逻辑（约 1170 行，最大的逻辑脚本）
│
├─ assets/
│  ├─ art_shouyiren/        ★ 现行美术（守艺人题材，全部 SVG）
│  │  ├─ characters/  enemies/  fx/  ground/  items/
│  │  ├─ props/  stalls/  ui/  weapons/
│  ├─ art/                 旧美术（更早的奶茶题材换皮前素材，当前不再引用）
│  ├─ audio/               音频（见 §11）
│  │  ├─ bgm/               main_menu.wav、combat.wav
│  │  └─ sfx/               enemy/ event/ player/ ui/ weapon/
│  └─ shaders/             16 个着色器（.gdshader）+ fx_manifest.json
│     └─ fx/  fx/skill/    程序化特效与领域/流光类效果
│
├─ docs/                    项目文档：overview.md、STAGE1~4.md、
│                           SHOUYIREN_TEXT.md、TEST_REPORT.md
├─ tools/                   37 个 headless 验收/截图脚本（35 个 .tscn）
├─ tests/                   单个功能测试（func_magnet_vacuum_move_float）
├─ shots/                   截图输出
└─ .godot/                  Godot 导入缓存（重新打开工程时自动生成，勿手改）
```

### 2.2 资源目录职责

| 目录 | 存放内容 | 谁在用 |
| --- | --- | --- |
| `assets/art_shouyiren/characters/` | 玩家正/背向行走帧 | `Art.gd` → `Player.gd` |
| `assets/art_shouyiren/enemies/` | 杂兵/精英/Boss/小 Boss 立绘 | `Art.gd` → `Enemy.gd` |
| `assets/art_shouyiren/weapons/` | 9 把武器的刀光/环/符/弹 | `Art.gd` → `WeaponManager.gd` |
| `assets/art_shouyiren/fx/` | 爆炸、火花、法阵、潮涌环、Boss 三层光效 | `ShaderFX.gd` / `Art.gd` |
| `assets/art_shouyiren/ground/` | 地砖 | `Ground.gd` |
| `assets/art_shouyiren/items/` | 灯花、掉落物、宝箱、摇杆头 | `Gem.gd` / `PickupField.gd` / `HUD.tscn` |
| `assets/art_shouyiren/props/`、`stalls/` | 牌楼、灯柱、戏台、五个摊位 | `PropField.gd`（`Art.gd` 常量） |
| `assets/art_shouyiren/ui/` | 灯笼框、火焰条、纸卡、夜景远景 | 各 UI 场景 |
| `assets/art/` | 旧题材素材（奶盖/奶茶） | 当前代码不再引用，仅作备份保留 |
| `assets/audio/bgm/` | 主菜单、战斗 BGM | `Audio.play_bgm()` |
| `assets/audio/sfx/` | 击杀/受击/拾取/升级/铜锣/Boss 登场 | `Audio.play_sfx()` |
| `assets/shaders/fx/`、`fx/skill/` | 领域、波纹、流光、溶解、屏幕效果 | `ShaderFX.gd` |

**美术路径唯一入口**：所有贴图路径集中在 `scripts/Art.gd` 的常量里，其他脚本不写裸路径；`Art.tex(path)` 带缓存，`Art.sprite(path)` 直接建精灵。

### 2.3 工程配置要点（`project.godot`）

| 配置 | 值 | 影响 |
| --- | --- | --- |
| `run/main_scene` | `res://scenes/MainMenu.tscn` | 启动进主菜单，由玩家点“新游戏”进单局 |
| `[autoload]` | `MetaSave → GameManager → Settings → Audio` | 四个全局单例，跨场景存活 |
| `display/window/size` | 720 × 1280，`canvas_items + expand` | 竖屏基准；不同比例设备横向/纵向扩展 |
| `[input]` | `move_left / move_right / move_up / move_down`（WASD + 方向键，deadzone 0.5） | 键盘移动；触摸拖动由 `Player` 直接读屏 |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` | 桌面用鼠标即可模拟单指拖动（方便无手机调试） |
| `rendering` | `mobile` + `d3d12`（Windows） | 移动端渲染器，低配设备优先 |
| `physics/3d/physics_engine` | `Jolt Physics` | 3D 物理后端（本作 2D 为主，保留配置） |
| `run/max_fps` | 60 | 帧率上限 |

---

## 3. 场景挂载总表

### 3.1 `Game.tscn`（单局主场景）

根节点 `Game`（Node2D，脚本 [Game.gd](GameDemo/first-xi-xue-gui/scripts/Game.gd)，`class_name GameScene`）。

```
Game (Node2D, Game.gd)
├─ BG (TextureRect, z=-20)              夜景远景，铺满视口，不随相机滚动
├─ World (Node2D)                       ← 世界层（会随相机移动）
│  ├─ Ground (Node2D, z=-10)  ← Ground.gd      无限地砖
│  ├─ Props  (Node2D, z=-5)   ← PropField.gd   牌楼/戏台/灯柱/五摊
│  ├─ Resources (Node2D, z=-3)← ResourceField.gd 可拆资源点
│  ├─ Player                  ← Player.tscn    玩家（内含相机）
│  ├─ EnemyPool (Node2D)      ← EnemyPool.gd   敌人对象池（540 容量）
│  ├─ GemPool (Node2D, z=1)   ← GemPool.gd     灯花经验池（400 容量）
│  ├─ Pickups (Node2D, z=2)   ← PickupField.gd 磁铁/爆竹/糍粑掉落
│  ├─ Weapons                 ← WeaponManager.tscn  武器与弹药/FX 池
│  └─ DamageNumbers (z=7)     ← DamageNumbers.gd 飘字池
└─ UI (CanvasLayer, layer=10)            ← 界面层（不随相机移动）
   ├─ HUD          ← HUD.tscn      战斗 HUD（含摇杆、技能键、血条）
   ├─ PauseUI      ← PauseUI.tscn  暂停菜单（自建 layer=9）
   ├─ LevelUpUI    ← LevelUpUI.tscn 升级三选一
   ├─ DeathUI      ← DeathUI.tscn  结算面板
   └─ ShopUI       ← ShopUI.tscn   商店（自建 layer=11）
```

`Game._ready()` 用 `@onready` 抓取上述全部节点，并完成依赖注入（详见 §6.1）。

### 3.2 `MainMenu.tscn`（开始界面）

```
MainMenu (Control, MainMenu.gd)
├─ BG / Shade
└─ Col (VBoxContainer)
   ├─ Head (Emblem / Title / Sub / Rule / Blurb)
   ├─ Stats                    ← 铜钱与传承摘要，refresh() 刷新
   ├─ BtnNew   "新游戏"        → 三页开场 / 直接进 Game.tscn
   ├─ BtnLoad  "载入存档"      → 有进度才可点（本作不保存单局）
   ├─ BtnShop  "打开商店"      → 实例化 ShopUI.tscn 挂在菜单上
   ├─ BtnChars "匠人 · X"      → 代码内 new CharacterUI
   ├─ BtnCodex "图鉴 · 进度"   → 代码内 new CodexUI
   ├─ BtnSettings "设置"       → 代码内 new SettingsUI
   ├─ BtnQuit  "退出游戏"
   └─ Hint
```

菜单里 `CharacterUI / CodexUI / SettingsUI` 都是**代码内创建**（常驻一份，反复 new 会叠遮罩），`ShopUI` 是**场景实例**且关店即销毁（[MainMenu.gd](GameDemo/first-xi-xue-gui/scripts/ui/MainMenu.gd)）。

### 3.3 `Player.tscn`

```
Player (CharacterBody2D, groups=["player"], Player.gd)
├─ Col (CollisionShape2D, CircleShape2D r=12, position y=-22)
├─ GarlicRing (Node2D, z=-1, GarlicRing.gd)   ← 花灯领域显示
│  └─ Ring (Sprite2D)                          ← 用 lantern_halo.svg
├─ Art (Sprite2D, offset y=-18)                ← 角色贴图（运行时换帧）
└─ Camera (Camera2D, position y=-18)
```

运行时还会在 `Player._ready()` 里**动态添加**两个节点：

- `ActiveSkill`（[ActiveSkill.gd](GameDemo/first-xi-xue-gui/scripts/ActiveSkill.gd)，Node）—— 主动技，依赖由 `Game` 注入；
- `Shadow2D.make()` 生成的椭圆影子（Polygon2D）。

### 3.4 `Enemy.tscn`

```
Enemy (Node2D, Enemy.gd)
├─ Art (Sprite2D, offset y=-20)
└─ HpBar (Node2D, y=-52, HpBar.gd)
```

敌人是**池化对象**：`EnemyPool` 预建、`setup()` 复用，不从场景树反复 instance。

### 3.5 `Gem.tscn`

```
Gem (Sprite2D, Gem.gd)   ← 无子节点；贴图在 setup() 时按经验大小切换
```

### 3.6 `weapons/WeaponManager.tscn`

```
Weapons (Node2D, groups=["weapons"], WeaponManager.gd)   ← 无子节点
```

子弹、区域、FX 全部由 `WeaponManager` 在运行时从**内部对象池**取用，不挂在场景里。

### 3.7 UI 场景

| 场景 | 根节点 | 关键子节点 | 显式 layer |
| --- | --- | --- | --- |
| `ui/HUD.tscn` | Control（全屏，`mouse_filter=2`） | TopShade / Hurt / Top(`Col`: Row[Pause,Level,Timer,TimerSmall]、XPBar+XPNum、HPBar+HPNum、ShieldBar+ShieldNum、Info、Weapons[HBox]) / FPS / Joystick(`Ring`+`Knob`) | 继承 `UI` 的 10 |
| `ui/LevelUpUI.tscn` | CanvasLayer | Mask / Popup(`VB`: Title「手艺精进」、Cards[HBox]、Hint) | 默认 |
| `ui/PauseUI.tscn` | CanvasLayer | Mask / Popup(`VB`: Card「II」、Title、Resume/Restart/Settings/Menu、Tip) | 9 |
| `ui/DeathUI.tscn` | CanvasLayer | Mask / Popup(`Panel/VB`: Reaper、Title、Info、Restart/Shop/Quit，运行时插入 Coins/Total) | 默认 |
| `ui/ShopUI.tscn` | CanvasLayer | Mask / Center(`Panel` → Head[Coins] / Rows / Hint / Close) | 11 |

**代码内创建、无独立 .tscn 的界面**（都自建 `CanvasLayer` 并自己设 `layer`）：

| 脚本 | layer | 打开方式 | 职责 |
| --- | --- | --- | --- |
| `ui/CharacterUI.gd` | 28 | `MainMenu` new | 5 位匠人选择 |
| `ui/CodexUI.gd` | 28 | `MainMenu` new | 33 条图鉴（4 页签） |
| `ui/SettingsUI.gd` | 30 | `MainMenu` / `PauseUI` new | 特效档、震屏、提示、音乐/音效音量、清存档 |
| `ui/IntroUI.gd` | 35 | `MainMenu` new | 三页开场，播完写 `MetaSave.intro_done` |
| `ui/ConfirmLayer.gd` | 40 | 被 `SettingsUI` 使用 | 通用二次确认（`confirmed/cancelled`） |
| `ui/TipUI.gd` | 5 | `Game._ready` new | 5 条一次性情境提示（木牌） |
| `ui/DamageNumbers.gd` | 世界节点（`Game/World/DamageNumbers`） | — | 伤害飘字池 |

---

## 4. 代码分层模型

项目按四层组织，分层红线是**「下层不知道上层」**：

| 层 | 判定标准 | 脚本 | 特征 |
| --- | --- | --- | --- |
| **数据层** | `RefCounted + class_name`，只有静态常量/静态函数，不进场景树 | WeaponDB、Stats、WaveTable、UpgradeDB、EvolutionDB、CharacterDB、CodexDB、CardText、Art | 只出数据与纯计算，绝不改运行时状态、不播放声音、不建节点 |
| **服务层** | `[autoload]` 单例，全局唯一、跨场景存活 | MetaSave、GameManager、Settings、Audio | 存档、本局全局变量、配置、音频总线 |
| **逻辑层** | 挂在 `Game/World` 下的 Node/Node2D，持有运行时状态 | Game、Player、Enemy、EnemyPool、Gem、GemPool、WeaponManager、ActiveSkill、PickupField、ResourceField、PropField、Ground、GarlicRing、ShaderFX、Shadow2D、HpBar | 负责判定、刷怪、伤害、掉落、时间轴；**不排版文字** |
| **显示层** | `CanvasLayer` / `Control` / 纯视觉 Node2D | MainMenu、HUD、LevelUpUI、PauseUI、DeathUI、ShopUI、CharacterUI、CodexUI、SettingsUI、IntroUI、ConfirmLayer、TipUI、DamageNumbers、JoyRing、GarlicRing（显示部分）、HpBar | 只读状态并显示、把点击转发成调用；**不改数值、不写存档** |

三条关键约定：

1. **数据层单向依赖**：数据表可以 `引用 MetaSave/GameManager` 读取“当前局”的加成（如 `Stats.effective_at` 乘 `MetaSave.mult`），但不反过来被它们修改。
2. **逻辑层不写 UI**：逻辑层发出信号，`Game` 转发给 HUD/UI；UI 只调用逻辑层公开方法（如 `game.toggle_pause()`）。
3. **显示层不写存档**：金币入账只在 `Game._finish()` 里做一次（`banked` 闸），`DeathUI` 只负责展示与转发。

---

## 5. 数据层（静态表）

> 这些脚本**没有挂载节点**，通过 `class_name` 全局访问（如 `WeaponDB.damage_at(...)`）。

### 5.1 `WeaponDB.gd` —— 9 把武器定义

- **挂载**：无（RefCounted 静态类）。
- **数据**：`MAX_LEVEL = 8`；`DEFS` 9 条；`ORDER` 固定展示顺序。
- **武器 id → 名字**：

| id | 名字 | 机制 |
| --- | --- | --- |
| `whip` | 傩面 · 师刀 | 玩家左右挥砍弧形 |
| `halo` | 花灯 | 环形领域持续伤害 |
| `glowstick` | 糖画 | 环绕身体的糖丝/光环 |
| `phone` | 皮影 | 指向最近敌人的弹幕 |
| `blade` | 剪纸 | 直线穿透飞刃 |
| `extinguisher` | 打铁花 | 扇形喷溅 |
| `gong` | 铜锣 | 全屏/大范围冲击波 |
| `inkline` | 墨斗 | 延迟落点/封印式范围 |
| `print` | 木版年画 | 多枚印记延迟落点 |

- **对外 API**：`has_weapon(id)`、`def(id)`、`display_name(id)`、`svg(id)`、`dmg_kind(id)`、`aim_at(id)`、`cooldown_at(id, lv, cooldown_mult)`、`damage_at(id, lv, damage_mult)`、`count_at(id, lv)`、`pierce_at(id, lv)`、`scatter_cap_at(id, lv)`、`first_delay(id)`。
- **修改什么**：无。只查表、只做纯函数换算。

### 5.2 `Stats.gd` —— 局内属性基线与换算式

- **挂载**：无。
- **数据**：`STAT_MAX = 5`；`STAT_KEYS = [damage, cooldown, area, speed, magnet, max_hp, might, regen, shield]`；
  下限：`COOLDOWN_FLOOR=0.40`、`COOLDOWN_ABS_FLOOR=0.35`、`MIGHT_FLOOR=0.50`；
  回春 `REGEN_PER_LV=0.6`（上限 3.0）；结界 `SHIELD_BASE=5`、每级 +3、周期 8s、上限 30+6/级；精炼 `REFINE_MAX=3`、每层 6%。
- **对外 API**：
  - `make_base()` —— 生成一局的属性字典（含 `max_hp=BASE_HP`、`hp`），并乘入 `MetaSave` 永久成长；
  - `value_at(key, level)` —— 局内纯公式（等级 → 数值）；
  - `effective_at(key, level)` —— `value_at × MetaSave.mult(key)`；
  - `apply_to(stats, key, level)` —— 把某条属性写回字典；
  - `regen_cap()` / `shield_cap(level)` / `refine_mult(tier)`。
- **修改什么**：只改传入的字典（由 `GameManager.reset()` 调用），自身无状态。

### 5.3 `WaveTable.gd` —— 单局时间轴与刷怪参数

- **挂载**：无。
- **数据（现行真值）**：
  - `RUN_LENGTH = 1800`（30 分钟）；
  - `WAVES` 5 段：0 / 300 / 600 / 1200 / 1500 秒起，精英占比 0% / 6% / 10% / 14% / 18%；
  - `BOSSES`：900s / 2800hp、1500s / 6100hp、1800s / 7000hp，kind 恒为 `reaper`；
  - `BOSS_SPEED=52`、`BOSS_DAMAGE_MULT=3.0`、`BOSS_XP_MULT=100`；
  - Boss 战期间杂兵刷出率 `MOB_SPAWN_DURING_BOSS=0.35`；
  - 结壳：`SHELL_ON=480`、`FADE0=1020`、`OFF=1200`，壳血 ×1.40、受 AoE ×0.75；
  - 更鼓：`DRUM_STEP=0.08`（每过一更全场手艺伤害 +8%），时间点 `[300, 600, 1200, 1500, 1800]` → `drum_mult(t)`（乘在武器最终伤害上，30min 收 1.40）；
  - `SURGES` 5 条：600 / 900 / 1200 / 1500 / 1740 秒，刷怪倍率 1.35~1.55，精英额外 +0.08~0.16（封顶 0.45）；
  - `MINI_BOSSES`：720s / 900hp、1080s / 1600hp、1440s / 2400hp；
  - `CONTACT_DAMAGE=6.0`；
  - `spawn_interval(t)`：1.1 → 0.45 秒（前 600 秒）；
  - `batch_size(t)`：`6 + 0.01t`，封顶 30；
  - `enemy_hp(t)`：`3 × (1 + t/1800)^1.70`；
  - `MOB_DEFS`：`cup`（纸屑）/ `fast`（快兵）/ `bag`（袋怪）；`ELITE_DEFS`：`box`（箱）/ `red`（红伞），血 ×18、伤害 ×1.6/2.2、经验 ×12；
  - 小 Boss 伤害倍率、经验常量同表。
- **对外 API**：`spawn_interval / batch_size / enemy_hp / mob_def / pick_mob / pick_elite / elite_def / elite_share / wave_index / boss_due / mini_boss_due / surge_due / surge_mult / surge_elite_add / surge_at / shelled_now / shell_w / drum_mult / wave_note / boss_count`。
- **修改什么**：无；`Game` 每帧把 `elapsed` 传进来询问。

### 5.4 `UpgradeDB.gd` —— 升级卡池与写回

- **挂载**：无。
- **数据**：`WEAPON_MAX=8`、`STAT_MAX=5`、`WEAPON_SLOTS=6`、`CARD_COUNT=3`、`REFINE_MAX=3`；`STAT_DEFS` 9 张被动卡（匠心 / 巧手 / 火候 / 夜行 / 听风 / 底气 / 护身 / 回春 / 结界）。
- **对外 API**：
  - `all_defs()`、`draw(count)` —— 抽卡（去重、满级武器转“精炼卡”、6 槽限制、起始武器保底换位）；
  - `current_level(id)`、`max_level(id)`、`display_name(id)`、`is_weapon(id)`；
  - `refine_tier(id)`；
  - `apply(entry)` —— **写回**：武器卡只改 `WeaponManager.owned[id]`（或 `refines[id]`），被动卡只改 `GameManager.stats` / `Player.level_upgrades`，两边互不越界。
- **修改什么**：通过 `apply()` 修改武器等级/精炼层数/玩家属性；同时 `CodexDB.unlock(id)`（图鉴“心法”解锁；战斗中只记内存，结算时统一落盘）。

### 5.5 `EvolutionDB.gd` —— 进化（开脸）配方

- **挂载**：无。
- **数据**：`FORMS` 6 条配方：武器 id + 指定被动达到等级 → 进化形态 id。示例：`whip + damage → 火神开脸`、`glowstick + cooldown → 龙凤呈祥`、`halo + area → 走马灯`、`gong → 开市锣` 等。
- **对外 API**：`has_form / form / form_id_for / can_evolve / req_passive / meets_recipe / candidates(owned, upgrades, evolved)`。
- **修改什么**：无。`Game._open_chest()` 用它求候选，再把结果写进 `WeaponManager.evolved`。

### 5.6 `CharacterDB.gd` —— 5 位匠人

- **挂载**：无。
- **数据**：`DEFAULT_ID="forge"`；`ENTRIES` 5 条，**只差起始武器，无属性差**（策划红线）：

| id | 匠人 | 起始武器 | 起始等级 |
| --- | --- | --- | --- |
| `forge` | 铁花匠 | `extinguisher` 打铁花 | 1 |
| `lantern` | 灯彩匠 | `halo` 花灯 | 2 |
| `paper` | 剪纸婆婆 | `blade` 剪纸 | 1 |
| `shadow` | 皮影班主 | `phone` 皮影 | 2 |
| `sugar` | 糖画师 | `glowstick` 糖画 | 1 |

- **对外 API**：`all / entry / current_id / current / starting_weapon / start_level / is_unlocked / progress_text`。
- **修改什么**：无（选择写入 `MetaSave.char_id` 由 `CharacterUI` 完成）。

### 5.7 `CodexDB.gd` —— 33 条图鉴

- **挂载**：无。
- **数据**：9 手艺 + 6 开脸 + 9 心法 + 9 对手 = 33；`KIND_*`、`KIND_ORDER`；`FOES` 9 条（cup / fast / bag / box / red / drum / nuo / lantern / reaper）。
- **解锁口径**：拿到过（武器）、进化过（开脸）、点过卡（心法）、杀过（对手）；收录状态存 `MetaSave.codex_seen`。
- **对外 API**：`entries / of_kind / entry / stat_line / total / total_of / is_seen / unlock / seen_count / seen_in / progress_line / fresh_count / clear_fresh`。
- **修改什么**：`unlock(id)` 改 `MetaSave.codex_seen`（战斗中只记内存，`Game._finish()` 统一 `flush_codex()` 落盘）。

### 5.8 `CardText.gd` —— 卡面文案生成

- **挂载**：无。
- **职责**：把数值翻译成中文描述（`weapon_desc / refine_desc / stat_desc / weapon_delta_lines / weapon_base_lines / stat_lines`），保证「文案 = 数值」。
- **修改什么**：无。

### 5.9 `Art.gd` —— 美术路径唯一入口

- **挂载**：无。
- **数据**：玩家正/背 3 帧、敌人 `CUP/FAST/BAG + _2/_3/_SHELL`、精英 `BOX/RED`、`REAPER`、`SHELL_CRUST`、`GEM/PICKUP/CHEST/PROP/BOSS/UI` 等全部路径常量；`HALO_RING`、`FX_SURGE_RING`、`BOSS_MASK_GLOW / BOSS_LANTERN_DRAIN / BOSS_WARNING_RING`。
- **对外 API**：`tex(path)`（缓存加载）、`sprite(path)`、`evolved_weapon_svg(id)`、`is_slot / is_player_front / is_player_back`。
- **修改什么**：无（只缓存 Texture2D）。

---

## 6. 服务层（autoload 单例）

`project.godot` 的 `[autoload]` 顺序：

```
MetaSave     → scripts/MetaSave.gd
GameManager  → scripts/GameManager.gd
Settings     → scripts/Settings.gd
Audio        → scripts/Audio.gd
```

它们**跨场景存活**，在任意脚本里直接用名字访问。

### 6.1 `GameManager.gd` —— 本局全局状态

- **挂载**：autoload 根（无场景节点）。
- **数据**：`BASE_HP=100.0`、`MAX_FPS=60`；`stats: Dictionary`、`player`、`weapons`、`started`、`start_weapon`、`pity_left`。
- **方法**：
  - `reset()` —— 用 `Stats.make_base()` 重置 `stats`，清空本局标记；
  - `on_started()` —— 回满血并置 `started = true`。
- **被谁用**：`Game._ready()` 调 reset/on_started；`Player`、`Enemy`、`GemPool` 注册/读取自身引用；`Stats.effective_at` 读 `MetaSave`；`UpgradeDB.current_level` 读 `weapons/player`。
- **修改什么**：本局属性、开始状态、起始武器、保底计数。

### 6.2 `MetaSave.gd` —— 局外存档

- **挂载**：autoload；文件 `user://save.json`。
- **数据**：`coins`、`levels`、`revive_left`、`loaded`、`intro_done`、`seen_tips`、`won_runs`、`best_time`、`mini_boss_kills`、`coins_total`、`char_id`、`codex_seen`；`REVIVE_INVULN=3.0`。
- **永久成长 `TRACKS` 5 条**：

| id | 名称 | 效果 | 上限 |
| --- | --- | --- | --- |
| `damage` | 匠心 | 伤害 +3%/级 | 5 级 |
| `max_hp` | 底气 | 最大生命 +10%/级 | 5 级 |
| `cooldown` | 巧手 | 冷却 −3%/级 | 5 级 |
| `magnet` | 听风 | 拾取范围 +10%/级 | 3 级 |
| `revive` | 灯不灭 | 每局复活次数 | 2 次 |

- **对外 API**：`load_save / save / add_coins / record_run / note_mini_boss_kill / set_character / buy / begin_run / consume_revive / mark_tip / has_tip / note_codex / flush_codex / has_codex / reset_intro / reset_progress / reload_from_disk / save_exists / mult / mult_at / price_of / can_afford / track_ids / level_of`。
- **修改什么**：铜钱、永久等级、复活次数、角色 id、图鉴收录、标记类状态；**唯一允许写盘的一层**。

### 6.3 `Settings.gd` —— 配置

- **挂载**：autoload；文件 `user://settings.cfg`（手写 key=value）。
- **数据**：`enum Fx { FULL, LOW }`、`LOW_OFF=["phone_ghost","lantern_stream","molten_scatter","stall_props"]`、`fx_level`、`shake`、`tips`、`music_volume=0.8`、`sfx_volume=0.9`。
- **对外 API**：`load_cfg / save_cfg / fx_on(id) / is_low / set_fx_level / set_shake / set_tips / set_music_volume / set_sfx_volume / reset_defaults / debug_set`。
- **被谁用**：`SettingsUI`（滑条与开关）、`ShaderFX`（低特效档跳过重特效）、`Game`（震屏/提示开关）。
- **修改什么**：设置项并写 `user://settings.cfg`；音量同时推给 `Audio.apply_volumes()`。

### 6.4 `Audio.gd` —— 音频服务

- **挂载**：autoload（不挂场景）。
- **职责**：运行时确保 `Music` / `SFX` 两条总线存在；`Master` 挂 `AudioEffectHardLimiter`（ceiling −1 dB）；BGM 用两个播放器做 0.75s 交叉淡入；SFX 走 10 个播放器池，按 `gap / voices / pitch` 限流并抢占最早；检测 `get_tree().paused` 时整体 duck −10 dB。
- **对外 API**：
  - `play_bgm(id)` —— `"menu"` / `"combat"`；
  - `play_sfx(id, extra_db=0.0)` —— `gem / hurt / levelup / enemy_die / boss_spawn / gong`；
  - `apply_volumes()` —— 把 `Settings.music_volume / sfx_volume` 推到总线。
- **修改什么**：只改音频播放状态与总线音量，不碰游戏数据。

---

## 7. 逻辑层（挂在 World 下的脚本）

### 7.1 `Game.gd` —— 单局流程总编排（`Game/Game`，`class_name GameScene`）

- **挂载**：`Game.tscn` 根节点 `Game`（Node2D），**场景总控**。
- **持有的运行时状态**：`elapsed`、`kills`、`elite_kills`、`boss_kills`、`evolutions`、`won`、`banked`、`_win_hold`、`chests_opened`、`coins_earned`、`_chests`（场上宝箱）、`_boss_fx`（残面三层光效）、`_spark_tokens`（火花令牌桶）、`tips`。
- **`_ready()` 做了什么**：
  1. 相机平滑（speed 9.0），`ground.bind(camera)`、`props.bind(camera)`，背景铺满；
  2. `GameManager.reset()` + `on_started()`；`MetaSave.begin_run()`；
  3. 把 `GameManager.stats` 分发给 `player.stats`、`weapons.stats`；
  4. `CharacterDB.starting_weapon()` → `weapons.acquire(starter)`；辅助档补到 Lv2；`GameManager.pity_left = 3`；
  5. `weapons.resources = resources`；`player.active_skill.bind(player, enemies, weapons)`；
  6. 连接信号：`enemy_died / enemy_damage / elite_died / boss_died / player.died`；
  7. 绑定 UI：`hud.bind(player, self)`、`level_up_ui.bind(player)`、`pause_ui.bind(self)`、`death_ui.bind_restart(self)` + `bind_shop(shop_ui)`、`pickups.bind(self)`、`resources.bind(self, camera)`；
  8. 代码内创建 `TipUI` 并 bind；
  9. `_spawn_burst(4)` 开局给一小波；`Audio.play_bgm("combat")`。
- **`_process()` 每帧顺序**：`_update_boss_fx` → 判胜演出倒计时（`_win_hold`，2 秒后 `_finish(true)`）→ 若未开始/暂停/已胜则 return → `weapons.run_time = elapsed` → `_check_boss / _check_mini_boss / _check_surge` → 满 1800s `_win()` → 按 `spawn_interval` 刷 batch（×潮涌倍率；Boss 在场时刷率压到 35%）→ 每秒按 `elite_share + surge_elite_add` 概率刷精英 → `_update_chests()`。
- **公开方法**：`toggle_pause()`、`is_paused_by_player()`、`restart()`、`spawn_interval()`、`enemy_hp()`、`enemy_speed()`、`batch_size()`、`elite_share()`、`wave_note()`、`death_cause()`、`coin_reward()`、`can_evolve_any()`、`chest_count()`、`alive_enemies()`、`gem_count()`、`spawn_boss_visual(phase)`、`clear_boss_visual()`。
- **修改什么**：计时、击杀计数、刷怪、Boss/潮涌触发、宝箱、胜负与金币入账（`MetaSave` 只在 `_finish` 写一次）。
- **信号/事件**：接收 5 条来自敌人池与玩家的信号；自身不定义信号，靠 UI 轮询（HUD `_process`）与直接方法调用。

### 7.2 `Player.gd` —— 玩家（`World/Player`，`CharacterBody2D`）

- **挂载**：`Player.tscn` 根节点，组 `player`。
- **信号**：`level_up`（升级，触发三选一）、`died`（血尽，由 `Game` 决定复活/结算）。
- **数据**：`BASE_SPEED=220`、触摸拖动阈值 8 / 满速 70、朝向锁定 0.45、纵向偏置 1.25、6 帧行走（正/背各 3）、受击无敌 0.5s；`stats`、`level_upgrades`、`level/xp/xp_total/xp_next`、`invuln_left`、`shield_hp/_shield_cd/_shield_break`（护盾环直径 116）、`active_skill`、`_dash_left/_dash_dir`、`facing_dir`、`last_hit_source`。
- **方法**：
  - `gain_xp(amount)` —— 加经验，够阈值则升级并 `emit_signal("level_up")`；
  - `take_damage(amount, source)` —— 先扣护盾，再扣血；受击无敌 + 闪白 + `Audio.play_sfx("hurt", ...)`；归零发 `died`；
  - `start_dash(dir, seconds)` —— 主动技冲刺；
  - `input_dir()` / `drag_origin()` / `touch_offset()` / `is_dragging()` / `hp_ratio()` / `is_alive()` / `xp_for_level(lv)`。
- **修改什么**：自身移动、朝向、血量、护盾、经验、等级、无敌计时。
- **挂载依赖**：`GarlicRing`（显示领域）、`Art`（贴图）、`Camera`、运行时 `ActiveSkill` 与影子。

### 7.3 `Enemy.gd` —— 敌人个体（池化模板）

- **挂载**：`Enemy.tscn` 根节点；由 `EnemyPool.spawn()` 复用。
- **信号**：`died(pos, xp, kind)`、`damage_dealt(pos, amount, big)`。
- **数据**：`HIT_COLOR`、`SLOW_TINT`、`FLASH_TIME=0.12`、`STOP_DIST=10`、`CORPSE_TIME=0.20`、`ELITE_DISSOLVE=0.45`、`MOB_DISSOLVE=0.30`、`DMG_POP_INTERVAL=0.22`（伤害聚合）；`hp/max_hp/speed/contact_damage/touch_radius/xp_value/kind/is_elite/is_boss/shelled/_frames`。
- **`setup()` 参数**：`pool_index, spawn_pos, hp, speed, xp, kind, elite, damage=WaveTable.CONTACT_DAMAGE, boss=false, shelled=false`；结壳时血 ×1.40（仅非精英/Boss）。
- **公开方法**：`take_damage(dmg, weapon_type)`、`damage_multiplier(weapon_type)`、`knock_back()`、`apply_slow()`、`corpse_expired()`。
- **修改什么**：自身 HP、受击闪白、击退、减速、死亡后的尸体计时。
- **事件**：死亡时发 `died`（被 `EnemyPool` 转成池级信号）；受击按 0.22s 聚合发 `damage_dealt`（供飘字与火花）。

### 7.4 `EnemyPool.gd` —— 敌人对象池与空间查询（`World/EnemyPool`）

- **挂载**：`Game.tscn` 的 `World/EnemyPool`（Node2D）。
- **信号（对外唯一出口）**：`enemy_died(pos, xp, kind)`、`elite_died(pos, kind)`、`boss_died(pos)`、`enemy_damage(pos, amount, big)`。
- **数据**：`CAP=540`、`max_alive=400`、空间哈希 `GRID_CELL=40`、`MAX_NEIGHBORS=5`、`BOSS_RESERVE=3`（为 Boss 预留名额）。
- **方法**：
  - `spawn(pos, hp, speed, xp, kind, elite=false, damage=…, boss=false, shelled=false)` → `Enemy`；
  - `boss()` / `has_boss()`；
  - `deactivate(e)` / `modulate_free(e)` / `clear_all()` / `alive_count()`；
  - 空间查询：`cell_of / report / forget / crowding / separation / nearest / nearest_except / nearest_n / query_circle`。
- **修改什么**：池内 active/inactive 列表、空间哈希、Boss 标记。
- **事件转换**：`_on_enemy_died()` 先发 `enemy_died`，并 `CodexDB.unlock(kind)`（对手图鉴统一在这里收录）；再按 `is_boss / is_elite` 补发 `boss_died` / `elite_died`，随后回收节点。

### 7.5 `Gem.gd` —— 单颗灯花经验

- **挂载**：`Gem.tscn` 根节点（Sprite2D）；由 `GemPool` 复用。
- **数据**：`MAGNET_DELAY=0.12`、`FLIGHT_ACCEL=2600`、`MAX_FLIGHT_SPEED=1100`、`PICKUP_R=22`、`BIG_THRESHOLD=5`。
- **方法**：`setup(pos, xp)`（按大小选蓝/橙贴图）、`tick(delta, player_pos, magnet_r) -> bool`（返回 true = 已被拾取；吸附用径向投影，`forced` 时忽略半径）。
- **修改什么**：自身位置/飞行速度/拾取状态。

### 7.6 `GemPool.gd` —— 灯花池（`World/GemPool`，z=1）

- **挂载**：`Game.tscn` 的 `World/GemPool`。
- **数据**：`CAP=400`、`MAGNET_BASE=90`。
- **方法**：`spawn(pos, value)`、`_process` 读 `GameManager.stats["magnet"]` 驱动 `Gem.tick`、`_collect(gem)` 播 `Audio.play_sfx("gem")` 并 `player.gain_xp()`；`clear_all()`、`vacuum_all()`（磁铁/清场吸走）、`count()`。
- **修改什么**：池子占用与玩家经验（通过 `Player.gain_xp`）。

### 7.7 `WeaponManager.gd` —— 武器系统（`World/Weapons`，最大逻辑脚本）

- **挂载**：`scenes/weapons/WeaponManager.tscn` 根节点（组 `weapons`，无子节点）。
- **数据**：`FX_CAP=64`、`BULLET_CAP=128`；`owned`（id→等级）、`evolved`（id→形态 id）、`refines`（id→精炼层）、`stats`、`run_time`、`resources`、内部 `_cd` 冷却表、`_bullets/_zones/_fx` 池。
- **`_ready()`**：注册 `GameManager.weapons = self`，预建 FX 池。
- **`_process()`**：未开始/暂停直接 return；按 `Game` 写入的 `run_time` tick 冷却，更新环绕物、子弹、区域、FX；各武器到点调用 `fire(id, player)`。
- **公开 API**：
  - 构建：`acquire(id)`（首次拿到时 `CodexDB.unlock(id)`）、`level_of(id)`、`has_weapon(id)`、`weapon_level(id)`、`is_evolved(id)`、`evolution_of(id)`；
  - 数值：`stat(key)`、`weapon_damage(id, lv)`（`WeaponDB.damage_at × stats.damage × 形态倍率 × 精炼倍率 × 更鼓倍率`）、`refine_tier(id)`、`set_refine(id, tier)`、`refine_mult(id)`、`drum_mult()`；
  - 范围：`halo_radius()` / `gong_radius()`；锚点：`_visual_center(player)`（角色身体中心，判定与视觉同源）；
  - 输出：`single_dps()` / `total_dps()` / `display_name(id)`；
  - 开火：`fire(id, player)` 分派到 `fire_whip / fire_halo / fire_projectile / fire_extinguisher / fire_gong / fire_inkline / fire_print`；
  - 表现：`spawn_spark(pos, size_mul, color)`、`spawn_evolve(pos)`、`update_fx`、`clear_bullets`、`fx_active_count`。
- **修改什么**：武器等级/进化/精炼、冷却表、子弹与区域、FX 池；**伤害通过 `Enemy.take_damage` 施加**。
- **事件**：没有自定义信号，命中由 `Enemy.damage_dealt` 汇总到 `EnemyPool` → `Game`。

### 7.8 `ActiveSkill.gd` —— 主动技（运行时挂在 `Player` 下）

- **挂载**：由 `Player._ready()` `ActiveSkill.new()` 挂为子节点；**依赖注入**：`bind(player, enemies, weapons)`。
- **数据**：`COOLDOWN=25`、`RADIUS=220`、`DASH_TIME=0.7`、`DASH_SPEED=620`、`DAMAGE_RATIO=2.5`、`AOE_FALLBACK=0.30`。
- **信号**：`cast`（供 HUD 刷新按钮/播 FX）。
- **方法**：`burst_damage()`（单体 DPS×2.5；无单体武器则总 DPS×0.3）、`try_cast()`（范围打击 + 朝输入方向冲刺）。
- **修改什么**：冷却、范围伤害、玩家冲刺状态。

### 7.9 `PickupField.gd` —— 地图掉落（`World/Pickups`，z=2）

- **挂载**：`Game.tscn` 的 `World/Pickups`。
- **数据**：`CAP=40`、`PICKUP_R=30`、`MAX_LIFE=24`、`POP_TIME=0.18`；`DEFS`：`magnet` 铜铃（掉率 0.0005）、`bomb` 爆竹（0.0002）、`bento` 糍粑（0.0003）；`BOMB_PER_RUN_CAP=4`、`BENTO_HEAL_PCT=0.30`、`BOMB_DAMAGE=99999`。
- **方法**：`bind(game)`、`roll_drop(pos, game)`（每次击杀掷一次）、`spawn(pos, kind)`、`clear_all()`。
- **修改什么**：掉落物列表；拾取后调用 `game` 方法：磁铁吸取全部灯花、爆竹清屏、糍粑回 30% 血。

### 7.10 `ResourceField.gd` —— 可拆资源点（`World/Resources`，z=-3）

- **挂载**：`Game.tscn` 的 `World/Resources`。
- **数据**：`CELL=520`、`RADIUS=2`、`PER_CELL=2`、`HIT_R=26`、`HP=30`、`COIN=1`、`DROP_CHANCE=0.18`。
- **方法**：`bind(game, camera)`；按世界格哈希确定性生成（消防栓/垃圾桶/售货机贴图）；被武器拆掉后计时重生。
- **修改什么**：资源点生命、金币累加（写 `game.coins_earned`）、掉落。

### 7.11 `PropField.gd` —— 固定场景装饰（`World/Props`，z=-5）

- **挂载**：`Game.tscn` 的 `World/Props`。
- **数据**：`CELL=400`、`RADIUS=2`；`LANDMARKS` 固定世界坐标：牌楼(0,-430)、戏台(0,545)、灯柱 ×4(±310,-300/+380)、五摊（铁花/灯彩/皮影在左街 x=-235；剪纸/糖画在右街 x=235）。
- **方法**：`bind(camera)`；只做视觉，不参与碰撞/伤害。

### 7.12 `Ground.gd` —— 无限地砖（`World/Ground`，z=-10）

- **挂载**：`Game.tscn` 的 `World/Ground`。
- **数据**：`TILE=256`。
- **方法**：`bind(camera)`；`_draw()` 以视口尺寸铺砖并按哈希翻转/明暗；静态 `view_size(node)`。
- **修改什么**：只重绘背景。

### 7.13 `ShaderFX.gd` —— 程序化特效工厂（无挂载点）

- **挂载**：无节点；被 `GarlicRing`、`Game`、`WeaponManager` 调用。
- **职责**：封装 `assets/shaders/fx` 下的材质，创建领域场、水波纹、走马灯流光、光晕、Boss 法阵、潮涌环、爆炸等。
- **常用静态 API**：`field / field_resize / field_beat`、`ripple / ripple_resize / ripple_pulse`、`lantern_stream / lantern_stream_resize / lantern_stream_beat`、`add_aura`、`spawn_circle`、`sweep`（掉落物扫光）、`clear`（清材质复用）、`set_group_glow`、`burst_ellipse`。
- **修改什么**：只改材质参数与临时节点，不碰玩法数值；低特效档由 `Settings.fx_on()` 控制。

### 7.14 `GarlicRing.gd` —— 花灯领域显示（`Player/GarlicRing`）

- **挂载**：`Player.tscn` 的 `GarlicRing`（Node2D，z=-1）。
- **数据**：`TEX_DIAMETER=256`、`BEAT_TIME=0.32`、`RIPPLE_INTERVAL=0.60`。
- **方法**：`set_radius(r)`（同步贴图、能量场、波纹、流光的尺寸）、`set_awakened(on)`（Lv8 才开走马灯流光）、`beat()`（命中时脉冲一次）、`radius`、`pulse`。
- **修改什么**：自身缩放与材质参数；**实际判定半径在 `WeaponManager.halo_radius()`**，这里只保证“看得见的圈 = 判定圈”。

### 7.15 `Shadow2D.gd` / `HpBar.gd`

- `Shadow2D.make()` —— 静态工厂，生成椭圆影子（玩家脚下）。
- `HpBar.gd` —— 挂在 `Enemy/HpBar`（场景初始 y=-52，`setup()` 再按敌人体型上移到头顶），画敌人血条；只读 `Enemy` 的 hp，不参与逻辑。

---

## 8. 显示层（UI 与纯视觉）

> 显示层的共同约束：**不改玩法数值、不写存档**；需要改变游戏时调用逻辑层/服务层公开方法。

### 8.1 `MainMenu.gd` —— 开始界面（`MainMenu` 根节点）

- **挂载**：`MainMenu.tscn` 根 `Control`。
- **数据**：`GAME_SCENE`、`SHOP_SCENE`、`intent_hook`（自动化验收钩子）；常驻 `_settings/_chars/_codex/_intro`，临时 `_shop`。
- **方法**：`refresh()`（刷新摘要、载入按钮置灰、匠人按钮文案、图鉴进度）、`has_progress()`、`progress_text()`、`_leave(kind, arg)`（切场景/退出前先解除暂停）、`chars_instance()`、`codex_instance()`、`shop_instance()`。
- **事件**：`BtnNew` → 三页开场或直接 `Game.tscn`；`BtnLoad` → 有进度才进；`BtnShop` → 实例化 `ShopUI.tscn`；`BtnChars/Codex/Settings` → 代码内开面板；`BtnQuit` → 退出。
- **改动**：只切场景/开关面板；`_ready` 播 `Audio.play_bgm("menu")`。

### 8.2 `HUD.gd` —— 战斗 HUD（`UI/HUD`）

- **挂载**：`HUD.tscn` 根 `Control`（全屏，`mouse_filter=2`）。
- **数据**：`JOY_MAX=56`、`HURT_ALPHA=0.62`、`LOW_HP_RATIO=0.30`、五更名 `GENG_NAMES`、`WEAPON_ICONS`。
- **方法**：`bind(player, game)`、`flash_evolve(text)`、`flash_boss(text)`、`flash_dawn(text)`、`flash_revive(text)`、`set_paused(paused)`。
- **`_process` 刷新**：经验条/等级、血条（低血变红 + 受击红屏）、护盾条、计时（“一更·戌时” + `mm:ss · 剩 xx:xx`）、击杀/同屏/灯花/铜钱、FPS、摇杆（触摸拖动时显示）、主动技按钮冷却、武器槽（`_sync_weapon_row` 按签名增量重建）。
- **交互**：`Pause` 按钮 → `game.toggle_pause()`；摇杆只是**显示**触摸起点/偏移，移动由 `Player` 自己读输入。

### 8.3 `LevelUpUI.gd` —— 升级三选一（`UI/LevelUpUI`）

- **挂载**：`LevelUpUI.tscn` 根 `CanvasLayer`。
- **数据**：`CARD_W/H/GAP=200/280/12`；三种卡面强调色；`_pending`（待处理升级次数）。
- **方法**：`bind(player)`、`is_open()`、`pending()`、`close_all()`；内部 `_on_level_up()` → `_show_next()` → `_make_card()`；`_on_pick(entry)` 调 `UpgradeDB.apply(entry)`，关闭后若 `_pending>0` 继续弹。
- **事件**：`player.level_up` → 打开；选卡写回武器/被动；`close_all()` 在死亡/暂停/判胜时兜底。
- **表现**：弹窗时 `Audio.play_sfx("levelup")`；键盘 1/2/3 可选卡。

### 8.4 `PauseUI.gd` —— 暂停菜单（`UI/PauseUI`，layer=9）

- **挂载**：`PauseUI.tscn` 根 `CanvasLayer`。
- **方法**：`bind(game)`、`open()`、`close()`、`is_open()`；按钮 `接着守 / 重守一夜 / 设置 / 回主菜单`；设置按钮代码内开 `SettingsUI`；回主菜单用 `MENU_SCENE`。
- **事件**：`Game.toggle_pause()` 是唯一入口；ESC 由 `Game._unhandled_key_input` 处理。

### 8.5 `DeathUI.gd` —— 结算面板（`UI/DeathUI`）

- **挂载**：`DeathUI.tscn` 根 `CanvasLayer`。
- **方法**：`bind_restart(game)`、`bind_shop(shop_ui)`、`show_result(kills, elapsed, level, victory, coins, elite_kills, boss_kills, evolutions, banked, cause)`、`is_open()`。
- **职责**：展示胜负、击杀/时长/等级/精英/Boss/进化次数、本局金币与累计金币（数字滚动）、武器总结；按钮 `再守一夜 / 百工谱 / 回主菜单`；`Esc` 关闭/退出。
- **改动**：只显示与转发；金币已由 `Game._finish()` 入账。

### 8.6 `ShopUI.gd` —— 商店（`UI/ShopUI`，layer=11；也在 `MainMenu` 里实例化）

- **挂载**：`ShopUI.tscn` 根 `CanvasLayer`。
- **信号**：`closed`。
- **数据**：`ROW_H=88`；5 条永久成长行。
- **方法**：`open()` / `close()` / `is_open()` / `refresh()`；内部 `_make_row()`、`_refresh_cell()`、`_effect_text()`、`_on_buy(id)`。
- **事件**：`_on_buy` → `MetaSave.buy(id)`（扣铜钱、升永久等级）→ 刷新行与铜钱；关店发 `closed`。
- **改动**：只通过 `MetaSave` 改局外进度，不碰本局。

### 8.7 `CharacterUI.gd` —— 匠人选择（layer=28，代码创建）

- **挂载**：`MainMenu` 内 `CharacterUI.new()`。
- **数据**：`PANEL_W=660`、`CARD_H=168`。
- **方法**：`open()` / `close()` / `refresh()`；选人 `_on_pick(id)` → `MetaSave.set_character(id)`。
- **事件**：`closed` 信号让 `MainMenu.refresh()` 更新按钮文案。

### 8.8 `CodexUI.gd` —— 图鉴（layer=28，代码创建）

- **挂载**：`MainMenu` 内 `CodexUI.new()`。
- **数据**：`PANEL_W=668`、`COLS=3`；4 个页签（手艺/开脸/心法/对手）。
- **方法**：`open(kind)` / `close()` / `refresh()` / `_paint()` / `_on_tab()`；关闭时 `CodexDB.clear_fresh()`。

### 8.9 `SettingsUI.gd` —— 设置（layer=30，代码创建）

- **挂载**：`MainMenu` / `PauseUI` 内 new。
- **方法**：`open()` / `close()`；`_build()`；`_vol_row()` + `_on_volume(value)`（写 `Settings` 并 `Audio.apply_volumes()`）；`_on_clear_save()` → `ConfirmLayer.ask()` → `_on_clear_confirmed()`。
- **内容**：特效档（全/低）、震屏开关、提示开关、音乐/音效音量滑条、重看开场、清除存档。

### 8.10 `IntroUI.gd` / `ConfirmLayer.gd` / `TipUI.gd`

- `IntroUI`（layer=35）：三页开场文案，`open()/next()/skip_all()`，播完 `_finish()` 写 `MetaSave.intro_done`。
- `ConfirmLayer`（layer=40）：通用二次确认，`ask(text, yes_text)`、`dismiss()`、`is_showing()`，信号 `confirmed/cancelled`。
- `TipUI`（layer=5，由 `Game._ready` 创建）：`bind(game, player)`、`scan()` 轮询 5 条情境提示条件（首次移动、首次拾取灯花、首次升级、半血以下、首次开箱），`_enqueue/advance` 播放木牌；`MetaSave.mark_tip(id)` 保证一生只播一次；`clear()` 在结算/判胜时收掉。

### 8.11 `DamageNumbers.gd` / `JoyRing.gd`

- `DamageNumbers`（`World/DamageNumbers`，z=7）：`POOL_SMALL=44`、`POOL_BIG=16`、`LIFE=0.52`、`RISE=30`；`pop(world_pos, amount, big)` 从池里取标签上浮淡出。
- `JoyRing`（`HUD/Joystick/Ring`）：`RADIUS=56`、`SEGMENTS=32`，`_draw()` 画摇杆环；只在触摸拖动时可见。

---

## 9. 信号与事件链

### 9.1 信号总表

| 发出者 | 信号 | 参数 | 接收者 | 结果 |
| --- | --- | --- | --- | --- |
| `Player` | `level_up` | — | `LevelUpUI._on_level_up` | 暂停并弹三张卡 |
| `Player` | `died` | — | `Game._on_player_died` | 尝试局外复活，否则结算 |
| `Enemy` | `died` | `pos, xp, kind` | `EnemyPool._on_enemy_died` | 计数/区分精英/Boss，回收节点，转发池信号 |
| `Enemy` | `damage_dealt` | `pos, amount, big` | `EnemyPool._on_enemy_damage` | 转发为 `enemy_damage` |
| `EnemyPool` | `enemy_died` | `pos, xp, kind` | `Game._on_enemy_died` | 击杀 +1、击杀音、掉灯花、掷掉落 |
| `EnemyPool` | `elite_died` | `pos, kind` | `Game._on_elite_died` | 精英 +1、小 Boss 计数、掉宝箱 |
| `EnemyPool` | `boss_died` | `pos` | `Game._on_boss_killed` | Boss +1、宝箱、6 颗大灯花、糍粑 |
| `EnemyPool` | `enemy_damage` | `pos, amount, big` | `Game._on_enemy_damage` | 伤害飘字 + 火花（令牌桶） |
| `ShopUI` | `closed` | — | `MainMenu._on_shop_closed` / `DeathUI._refresh_shop_hint` | 销毁实例 / 刷新摘要 |
| `ActiveSkill` | `cast` | — | （当前未连接） | HUD 直接调 `try_cast()` 并读 `cd_left`，该信号暂未使用 |
| `CharacterUI/CodexUI/SettingsUI/IntroUI` | `closed` / `finished` | — | `MainMenu` | 刷新菜单文案 |

### 9.2 开局

```
MainMenu.BtnNew
  → 首次：IntroUI 三页 → finished
  → change_scene_to_file("res://scenes/Game.tscn")
  → Game._ready()
      camera 平滑 / Ground.bind / Props.bind / 背景铺满
      GameManager.reset() → Stats.make_base()（含 MetaSave 永久成长）
      GameManager.on_started() / MetaSave.begin_run()
      CharacterDB.starting_weapon() → WeaponManager.acquire()
      pity_left = 3；weapons.resources = resources
      ActiveSkill.bind(player, enemies, weapons)
      连接 5 条信号；绑定 HUD/LevelUp/Pause/Death/Shop/Pickups/Resources
      new TipUI；_spawn_burst(4)；Audio.play_bgm("combat")
```

### 9.3 击杀 → 经验 → 升级三选一

```
WeaponManager 命中 → Enemy.take_damage()
  → Enemy.damage_dealt（每 0.22s 聚合）→ EnemyPool.enemy_damage
  → Game._on_enemy_damage → DamageNumbers.pop + 火花（30/s 令牌桶）
Enemy._die()
  → Enemy.died → EnemyPool._on_enemy_died
      CodexDB.unlock(kind)（对手图鉴）
      EnemyPool.enemy_died → Game._on_enemy_died
        kills++ · Audio.play_sfx("enemy_die") · GemPool.spawn(pos, xp) · PickupField.roll_drop()
GemPool._process（读 stats.magnet）→ Gem.tick 吸附
  → 进 PICKUP_R → GemPool._collect → Audio.play_sfx("gem") → Player.gain_xp()
  → xp >= xp_next → level++ · level_up.emit()
  → LevelUpUI._on_level_up → UpgradeDB.draw(3)
  → 选卡 → UpgradeDB.apply()
      ├ 武器卡：WeaponManager.owned[id]++（6 槽上限；首次 acquire 收录手艺图鉴）
      ├ 精炼卡：WeaponManager.set_refine(id, tier)
      └ 被动卡：Player.level_upgrades[id]++ / Stats.apply_to(stats) → CodexDB.unlock(id)
```

### 9.4 精英 → 宝箱 → 进化

```
Enemy.is_elite 死亡 → EnemyPool.elite_died → Game._on_elite_died
  → elite_kills++；若是 WaveTable.MINI_BOSSES 的 kind → MetaSave.note_mini_boss_kill()
  → Game._drop_chest(pos)（Sprite2D + ShaderFX.add_aura，同屏上限 6）
玩家走近（< CHEST_PICKUP_R + 16）→ Game._open_chest()
  → EvolutionDB.candidates(owned, level_upgrades, evolved)
      ├ 无候选：player.gain_xp(xp_next) 补偿一次升级
      └ 有候选：weapons.evolved[pick] = form_id
                evolutions++ · CodexDB.unlock(form_id)
                WeaponManager.spawn_evolve() · HUD.flash_evolve()
                Audio.play_sfx("levelup", +2 dB)
```

### 9.5 Boss / 小 Boss / 潮涌

```
Game._check_boss()（跨越 900 / 1500 / 1800s）
  → ShaderFX.spawn_circle（傩阵，z=-4）
  → EnemyPool.spawn(reaper, boss=true)
  → Game.spawn_boss_visual(idx)（一现/二现/三现叠层，z=-3/-3/-4）
  → HUD.flash_boss() · Audio.play_sfx("boss_spawn")
  → Boss 在场时刷怪间隔 ÷0.35（压刷率）
Game._check_mini_boss()（720 / 1080 / 1440s）
  → 冷色小法阵 → EnemyPool.spawn(elite 通道，boss=false)
  → HUD.flash_boss() · Audio.play_sfx("boss_spawn", -8 dB)
Game._check_surge()（600 / 900 / 1200 / 1500 / 1740s）
  → HUD.flash_boss() · 潮涌环演出
  → 后续刷怪 batch × surge_mult；精英概率 + surge_elite_add
```

### 9.6 受击 / 死亡 / 复活 / 判胜

```
Enemy 接触/冲刺 → Player.take_damage(amount, source)
  → 护盾优先扣 shield_hp；受击无敌 0.5s；红屏 + 闪白
  → Audio.play_sfx("hurt", -6 dB if 有盾)
  → hp <= 0 → Player.died
  → Game._on_player_died：close_all 升级卡 / close 暂停
      → MetaSave.consume_revive() 成功：回满血、3s 无敌、HUD.flash_revive()
      → 否则 _finish(false, death_cause())

elapsed >= 1800 → Game._win()
  → won=true · started=false · HUD.flash_dawn("五更鸡鸣") · _win_hold=2.0
  → 2s 后 _finish(true)
  → coin_reward() = kills×0.12 + elapsed/12 + elite×6 + boss×40（胜利 ×1.5）+ coins_earned
  → MetaSave.add_coins() / record_run() → DeathUI.show_result()
```

### 9.7 暂停与重开

```
ESC：商店开着 → 关店；否则 toggle_pause()
暂停优先级：ShopUI > DeathUI > LevelUpUI > PauseUI（避免叠层卡死）
Ctrl+R → Game.restart()
  → get_tree().paused=false
  → 重新 instantiate Game.tscn，替换当前场景（不保留上一局任何节点状态）
```

---

## 10. 单局时间轴与数值真值

| 时间（秒） | 事件 | 代码位置 |
| --- | --- | --- |
| 0 | 开局 4 只杂兵；一更·戌时 | `Game._ready` / `WaveTable.WAVES[0]` |
| 300 | 波次 2；更鼓 | `WaveTable.DRUM_TIMES` |
| 480 | 杂兵开始结壳（血 ×1.40，AoE ×0.75） | `WaveTable.SHELL_ON` |
| 600 | 波次 3；潮涌 1 | `WAVES` / `SURGES` |
| 720 | 小 Boss 1「更鼓傀」（900 hp） | `MINI_BOSSES` |
| 900 | 残面 **一现**（2800 hp）；潮涌 2 | `BOSSES[0]` / `SURGES` |
| 1020~1200 | 结壳概率衰减到关闭 | `SHELL_FADE0 / SHELL_OFF` |
| 1080 | 小 Boss 2「无面傩」（1600 hp） | `MINI_BOSSES` |
| 1200 | 波次 4；潮涌 3 | `WAVES` / `SURGES` |
| 1440 | 小 Boss 3「长夜灯」（2400 hp） | `MINI_BOSSES` |
| 1500 | 波次 5；残面 **二现**（6100 hp）；潮涌 4 | `WAVES/BOSSES/SURGES` |
| 1740 | 潮涌 5（终局前压力峰） | `SURGES` |
| 1800 | 残面 **三现**（7000 hp）同帧判胜 | `BOSSES[2]` / `RUN_LENGTH` |
| 1800 + 2 | 五更鸡鸣过场结束 → 结算 | `Game.WIN_HOLD` |

**数值真值在哪**：旧参数表 `params.json` 已归档，**现行真值以代码常量为准** ——
`WaveTable.gd`（刷怪/波次/Boss/潮涌）、`WeaponDB.gd`（武器每级数值）、`Stats.gd`（属性公式）、`UpgradeDB.gd`（卡池与上限）、`EvolutionDB.gd`（配方）、`MetaSave.gd`（永久成长价格）。

---

## 11. 音频系统（已接入）

### 11.1 结构

```
Master ── HardLimiter (ceiling -1 dB)
  ├─ Music    ← BGM 两个播放器交叉淡入
  └─ SFX      ← 10 个播放器池（gap / voices / pitch 限流，抢最早）
```

总线由 `Audio._ensure_buses()` 在运行时补齐（项目未存 bus layout 文件时也能工作）；音量由 `Settings` 滑条 → `Audio.apply_volumes()` 推向总线。

### 11.2 素材与触发点

| 文件 | 用途 | 触发位置 |
| --- | --- | --- |
| `assets/audio/bgm/main_menu.wav`（57.7s，循环） | 主菜单 BGM | `MainMenu._ready()` → `Audio.play_bgm("menu")` |
| `assets/audio/bgm/combat.wav`（90s，循环） | 战斗 BGM | `Game._ready()` → `Audio.play_bgm("combat")` |
| `sfx/enemy/die.wav` | 击杀 | `Game._on_enemy_died()` |
| `sfx/event/boss_spawn.wav` | Boss 登场（小 Boss −8 dB） | `Game._check_boss / _check_mini_boss` |
| `sfx/player/gem.wav` | 拾取灯花 | `GemPool._collect()` |
| `sfx/player/hurt.wav` | 玩家受击（有盾 −6 dB） | `Player.take_damage()` |
| `sfx/player/levelup.wav` | 升级弹窗（0 dB）/ 进化（+2 dB） | `LevelUpUI._show_next()` / `Game._open_chest()` |
| `sfx/weapon/gong.wav` | 铜锣武器 | `WeaponManager.fire_gong()` |

### 11.3 约定

- 战斗音不需要“每发都响”：击杀/拾取靠 `Audio` 的 `gap` 与 `voices` 上限节流；
- 暂停时自动 duck −10 dB（`Audio._process` 检测 `get_tree().paused`）；
- `assets/audio/sfx/ui/` 目前为空（没有按钮点击音素材），UI 交互暂无声。

---

## 12. 测试与工具

- `tools/`：37 个 headless 验收/截图脚本（35 个 `.tscn` 场景，如 `SmokeTest`、`V5InGame`、`V6Look`、`V7Shell`、`BalanceAudit`、`P5Perf`、`StageTwoShot` 等）。
- `tests/func_magnet_vacuum_move_float`：磁铁吸附/移动/浮点功能的单点测试。
- `shots/`：截图产物；项目根的历史 `*.log` 已于 2026-11-02 清理。
- 常用运行方式（Windows）：

```powershell
& "D:\GameEngine\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --path "e:\AITemp\QoderGameFirst\GameDemo\first-xi-xue-gui"
```

- headless 脚本验收时用 `--headless --path <项目根> <场景路径>`；注意 `--script` 模式下 autoload 不参与解析，需用“场景 + Node 脚本”的探针方式。

---

## 13. 已知缺口与注意事项

1. **发布包已构建（2026-11-02）**：工作区 `release/` 下有 Windows 单文件 exe（PCK 内嵌）、Windows 分发 zip 与 Android arm64-v8a APK（自签名），详见 `release/README.md`。iOS 需 macOS + Xcode，Windows 上无法构建。
2. **未做真人长时间试玩**：平衡以自动化数值审计为主；30 分钟完整流程的真人手感仍需验证。
3. **旧美术保留**：`assets/art/` 是换皮前素材，仅作备份；`Art.gd` 已无旧路径引用，当前全部指向 `art_shouyiren/`。
4. **UI 点击音缺失**：`assets/audio/sfx/ui/` 为空。
5. **单局不存档**：没有 mid-run save；“载入存档”只带局外传承（铜钱/永久等级/复活次数）。
6. **HUD 与弹窗层值**：`PauseUI` 自建 layer 9、`ShopUI` 11，`LevelUpUI/DeathUI` 用默认层；调整遮挡关系时先看各自 `.tscn` 的 `layer`，不要只看 `Game/UI` 的 10。

---

## 附录 A：全部脚本速查表（43 个）

| 脚本 | 挂载 / 形态 | 层 | 一句话职责 |
| --- | --- | --- | --- |
| `scripts/WeaponDB.gd` | 无（RefCounted） | 数据 | 9 把武器的等级数值表 |
| `scripts/Stats.gd` | 无 | 数据 | 9 条属性公式与永久加成换算 |
| `scripts/WaveTable.gd` | 无 | 数据 | 30 分钟波次/刷怪/Boss/潮涌表 |
| `scripts/UpgradeDB.gd` | 无 | 数据 | 三选一卡池与写回 |
| `scripts/EvolutionDB.gd` | 无 | 数据 | 6 条进化配方 |
| `scripts/CharacterDB.gd` | 无 | 数据 | 5 位匠人（仅起始武器不同） |
| `scripts/CodexDB.gd` | 无 | 数据 | 33 条图鉴与解锁口径 |
| `scripts/CardText.gd` | 无 | 数据 | 卡面文案生成 |
| `scripts/Art.gd` | 无 | 数据 | 全部美术路径与纹理缓存 |
| `scripts/MetaSave.gd` | autoload | 服务 | 铜钱/永久成长/复活/图鉴存档 |
| `scripts/GameManager.gd` | autoload | 服务 | 本局全局 stats 与开始状态 |
| `scripts/Settings.gd` | autoload | 服务 | 特效档/震屏/提示/音量配置 |
| `scripts/Audio.gd` | autoload | 服务 | 总线、BGM 交叉淡入、SFX 限流 |
| `scripts/Game.gd` | `Game` 根节点 | 逻辑 | 单局流程、刷怪、Boss、胜负、金币 |
| `scripts/Player.gd` | `World/Player` | 逻辑 | 移动、受击、经验升级、护盾、冲刺 |
| `scripts/Enemy.gd` | `Enemy.tscn` 根（池化） | 逻辑 | 敌人个体血量/受击/死亡 |
| `scripts/EnemyPool.gd` | `World/EnemyPool` | 逻辑 | 敌人池、空间哈希与四个信号 |
| `scripts/Gem.gd` | `Gem.tscn` 根（池化） | 逻辑 | 单颗灯花的吸附与拾取 |
| `scripts/GemPool.gd` | `World/GemPool` | 逻辑 | 灯花池与经验结算 |
| `scripts/weapons/WeaponManager.gd` | `World/Weapons` | 逻辑 | 武器开火、伤害、子弹/区域/FX 池 |
| `scripts/ActiveSkill.gd` | `Player` 运行时子节点 | 逻辑 | 25s 主动技：范围伤害 + 冲刺 |
| `scripts/PickupField.gd` | `World/Pickups` | 逻辑 | 磁铁/爆竹/糍粑掉落与效果 |
| `scripts/ResourceField.gd` | `World/Resources` | 逻辑 | 可拆资源点与金币/掉落 |
| `scripts/PropField.gd` | `World/Props` | 逻辑 | 牌楼/戏台/灯柱/五摊布景 |
| `scripts/Ground.gd` | `World/Ground` | 逻辑 | 无限地砖绘制 |
| `scripts/ShaderFX.gd` | 无（静态工厂） | 逻辑 | 程序化领域/波纹/流光/法阵 |
| `scripts/GarlicRing.gd` | `Player/GarlicRing` | 逻辑/显示 | 花灯范围的可视化，与判定同尺寸 |
| `scripts/Shadow2D.gd` | 无（静态工厂） | 逻辑 | 椭圆影子 |
| `scripts/HpBar.gd` | `Enemy/HpBar` | 显示 | 敌人血条 |
| `scripts/ui/MainMenu.gd` | `MainMenu.tscn` 根 | 显示 | 开始界面与入口分发 |
| `scripts/ui/HUD.gd` | `UI/HUD` | 显示 | 血/经验/护盾/计时/武器槽/摇杆/技能键 |
| `scripts/ui/LevelUpUI.gd` | `UI/LevelUpUI` | 显示 | 三选一弹窗与选卡 |
| `scripts/ui/PauseUI.gd` | `UI/PauseUI` | 显示 | 暂停菜单（重开/设置/回菜单） |
| `scripts/ui/DeathUI.gd` | `UI/DeathUI` | 显示 | 结算面板 |
| `scripts/ui/ShopUI.gd` | `UI/ShopUI` | 显示 | 5 条永久成长购买 |
| `scripts/ui/CharacterUI.gd` | 代码创建（layer 28） | 显示 | 匠人选择 |
| `scripts/ui/CodexUI.gd` | 代码创建（layer 28） | 显示 | 4 页签图鉴 |
| `scripts/ui/SettingsUI.gd` | 代码创建（layer 30） | 显示 | 特效/震屏/提示/音量/清档 |
| `scripts/ui/IntroUI.gd` | 代码创建（layer 35） | 显示 | 三页开场 |
| `scripts/ui/ConfirmLayer.gd` | 代码创建（layer 40） | 显示 | 通用二次确认 |
| `scripts/ui/TipUI.gd` | `Game` 运行时子节点（layer 5） | 显示 | 5 条一次性情境提示 |
| `scripts/ui/DamageNumbers.gd` | `World/DamageNumbers` | 显示 | 伤害飘字池 |
| `scripts/ui/JoyRing.gd` | `HUD/Joystick/Ring` | 显示 | 摇杆环绘制 |

---

*本文档基于当前仓库代码与场景文件整理。数值以代码常量为准；若与 `docs/` 下的阶段文档不一致，以 `scripts/` 中的常量与注释为准。*
