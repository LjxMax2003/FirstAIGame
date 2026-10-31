# 开始界面 + 范围伤害水波纹特效 实施规范（AI 可读）

> 定位：给实施型 AI / 专家照着动手的总纲。本轮只写规范，不落地任何游戏代码。
> 配套阅读：`v5_ai_playbook.md`（红线与回归基线）、`hud_fx_gap_fix.md`（HUD 数值与敌人受击/死亡，与本文件互补）。

---

## 0. 两个问题的真实现状（实读代码结论，纠正直觉）

### 0.1 问题①：没有开始界面

- `project.godot:14` → `run/main_scene="res://scenes/Game.tscn"`。**游戏一启动就直接进战斗**，没有任何菜单场景。
- 全局只有 `GameManager`（autoload，`scripts/GameManager.gd`），没有 `MainMenu` 节点/场景。
- 暂停靠 `Game.gd:179 toggle_pause()` + `PauseUI`；ESC 处理在 `Game.gd:197 _unhandled_key_input`（商店开着时 ESC=关店，否则暂停）。
- 商店 `ShopUI`（`scripts/ui/ShopUI.gd`，`extends CanvasLayer`）**当前只是 `Game.tscn` 里 `$UI/ShopUI` 的一个子节点**，由 `Game.gd:50` 注入、`DeathUI.gd:155` 在结算界面打开。**菜单里"打开商店"目前做不到**——它没有独立场景，且依赖一棵正在跑的 Game 树。
- **没有 mid-run 存档系统**（全局搜 `save_game/load_game/resume` 无结果）。持久化只有 `MetaSave`（`user://save.json`），在 `MetaSave.gd:76 _ready()` 里 `load_save()` 自动载入。所以"载入存档"对一款幸存者类游戏是歧义项——见 §3.4。

### 0.2 问题②：范围伤害没有攻击特效

- `花灯`(halo) 是游戏里**唯一的持续范围伤害武器**；`皮影`(phone) 是环绕体（"影人绕身"），也算"持续在场"的伤害来源。用户说的"剪影"= 皮影（`Art.gd:44 PHONE_ORBIT = shadow_puppet.svg`）。
- `花灯` 的可见范围由 `GarlicRing.gd` 负责：已有 `aura_field` 能量场，但被压成**只贴边圈的一条窄亮带**（`inner 0.80 / outer 1.00`，`GarlicRing.gd:29-39`）——内部是空的，玩家读不出"这里在持续烧"。
- `fire_halo`（`WeaponManager.gd:310`）只在**真的命中敌人**时才 `ShaderFX.burst_ellipse(...)`（灯晕跳一下）。没命中时整圈静默，没有"持续攻击"的视觉。
- `皮影` 环绕体（`_update_orbits`，`WeaponManager.gd:64`）只有贴图在转，**没有任何范围/攻击视觉**。
- 好消息：**`aura_field.gdshader` / `magic_circle.gdshader` 上一轮已写好并校验**，本任务优先"增强/叠加"，不是从零写着色器。

---

## 1. 推荐专家

| 角色 | 专家 | 负责范围 | 理由 |
|---|---|---|---|
| **主** | **节点通（Godot 游戏脚本工程师）** | 主菜单场景 + 场景切换 + 四按钮接线 + 商店独立化 + 范围特效接入 | 本任务 80% 是 `Control`/`Node2D` 场景与 GDScript 接线，契合本作"强类型数据表 + 冒烟测试 + 合批纪律" |
| 支 | **UI 设计专家** | 菜单版式（720×1280 竖屏）、按钮样式、剪影/水波纹视觉语言 | 别把竖屏挤爆；配色沿用朱红·暖铜·靛蓝剪纸风 |
| 支 | **着色器专家** | 新 `area_ripple.gdshader`（水波纹，godotshaders 改编） | 仅在要新写/改 shader 时介入；需守移动端后端、禁 SCREEN_TEXTURE、短边归一化、加法混合 alpha=1.0 |

> 美术资源：**本任务不新增任何贴图**。菜单可用现有 `Art` 里的傩面/灯笼/铜钱 SVG 或纯色+文字占位；水波纹是纯程序化 shader。

---

## 2. 给 AI 看的文件清单（必读 + 可选）

**必读（动手前按顺序读）：**
1. 本文件 `docs/design/main_menu_and_area_fx_spec.md`
2. `project.godot`（第 14 行 `main_scene`，第 19-22 行 `autoload`）
3. `scripts/GameManager.gd`（autoload；`started` 标志；`reset()` / `on_started()`）
4. `scripts/Game.gd`（ShopUI 注入 `:50`、暂停/ESC `:179-207`、场景重载 `:216-227`）
5. `scripts/ui/ShopUI.gd`（`open()/close()/refresh()`，只依赖 `MetaSave` + `Art`）
6. `scripts/MetaSave.gd`（`SAVE_PATH` `:29`、`load_save()` `:82`、金币与成长线）
7. `scripts/ui/DeathUI.gd`（`:74-78 bind_shop`、`:155` 开商店——复用范式）
8. `scripts/GarlicRing.gd`（`aura_field` 边带 `:18-40`、`beat()`、`set_radius()`）
9. `scripts/weapons/WeaponManager.gd`（`fire_halo` `:310`、`_update_orbits` `:64`、phone 环绕）
10. `scripts/ShaderFX.gd`（`field()`/`field_resize()`/`burst_ellipse()` 现有 API）
11. `scripts/Art.gd`（`HALO_RING` / `PHONE_ORBIT` / 资源路径与 `ALL_PATHS`/`SLOT_ALIASES` 守卫）
12. `assets/shaders/fx/fx_manifest.json` + `docs/shaders/fx-pack.md`（shader 编写红线与调参）

**可选：** `docs/design/v5_ai_playbook.md`（§4 红线、§8 回归基线）、`tools/SkillSheet.tscn`（改完重渲对照图）。

---

## 3. 任务拆分（每条含：文件 / 动作 / 红线 / 验收）

### T1 主菜单场景（节点通 + UI）
- **文件**：新建 `scenes/MainMenu.tscn` + `scripts/ui/MainMenu.gd`（`extends Control`）；改 `project.godot:14` → `main_scene="res://scenes/MainMenu.tscn"`。
- **动作**：菜单含四个按钮：新游戏 / 载入存档 / 打开商店 / 退出游戏。竖屏布局，顶部游戏名（守艺人·百工夜行），底部四个按钮竖排。
- **红线**：菜单是 `Control` 全屏锚定（`anchors_preset=15`，`anchor_right/bottom=1.0`）；不引入新美术，用现有 `Art` SVG 或纯色+文字；配色沿用朱红·暖铜·靛蓝。
- **验收**：F6 独立运行 `MainMenu.tscn` 能跑通（不依赖 Game 树）；四个按钮可见可点。

### T2 四个按钮接线（节点通）
- **新游戏**：`get_tree().change_scene_to_file("res://scenes/Game.tscn")`。进入前确保 `GameManager.reset()` 已跑（autoload `_ready` 已生成 `stats`，但重开路径要确认 `started=false` 后由 Game 置真）。
- **载入存档**：见 §3.4 语义；默认 `MetaSave` 已自动载入，按钮置灰当 `MetaSave.loaded == false`。
- **打开商店**：见 T3。
- **退出游戏**：`get_tree().quit()`。
- **红线**：场景切换用 `change_scene_to_file`（与 `Game.gd:216-227` 既有重载范式一致）；菜单里**不要** `get_tree().paused` 卡死输入。
- **验收**：四按钮各自触发对应行为，无报错；退出真的关进程。

### T3 商店可独立打开（节点通）
- **文件**：把 `ShopUI` 抽成独立场景 `scenes/ui/ShopUI.tscn`（封装现有 `ShopUI.gd`），`Game.tscn` 与菜单各自 `preload`+`instance()` 一份（避免同棵树多实例冲突）。
- **动作**：菜单"打开商店"→ `add_child(shop_scene)` + `shop.open()`；商店内加"返回"按钮 → `shop.close()` + `queue_free()`（或回到菜单）。结算界面的既有 `DeathUI.bind_shop` 路径保持不变。
- **红线**：`ShopUI` 只依赖 `MetaSave`(autoload)+`Art`(autoload)，**不要**反向依赖 `Game` 实例；金币变动写回 `MetaSave.save()`。
- **验收**：从菜单开商店能买、能关、能回菜单；从结算界面开商店的旧路径不受影响。

### T3.4 载入存档语义（需用户确认，先给默认）
- **现状**：无 mid-run 存档，只有 `MetaSave` 自动载入。
- **默认实现（推荐）**：菜单显示"继续"（当 `MetaSave.loaded` 且有等级/金币）与"新游戏"；两者都进 `Game.tscn`，差别仅是文案与存档存在提示。"载入存档"按钮在首次运行（`MetaSave.loaded==false`）时置灰。
- **可选扩展（不阻塞）**：若用户真要"接着上一局"，需新建 run-save 系统（序列化 `GameManager.stats`、敌人池、武器等级到 `user://run.json`，并在 `Game._ready` 提供 resume 分支）——属大改，单列一轮。
- **动作**：把上述语义写进 `MainMenu.gd`；按钮文案随 `MetaSave` 状态变化。

### T4 范围伤害水波纹 shader（着色器 + 节点通）
- **文件**：新建 `assets/shaders/fx/skill/area_ripple.gdshader`（与 `aura_field`/`magic_circle` 同级）；`ShaderFX.gd` 加 `ripple(node, diameter, color)` / `ripple_resize()` / `ripple_pulse()`（仿现有 `field()`/`field_resize()` API）。
- **来源**：改编自 godotshaders **Circular Waves 2D**（见 §4），**去掉**它依赖的 `SCREEN_TEXTURE` 扭曲（本作禁 SCREEN_TEXTURE，移动端后端不支持），只保留同心环 `sin(dist*freq - TIME*rate)` 的发光环。
- **动作**：`render_mode blend_add`；`COLOR.a` 固定 `1.0`，亮度算进 rgb；按**短边**归一化（别像 `hurt_vignette` 初版按 `screen_size.y` 翻车）；`frequency`/`rate`/`intensity` 可调。
- **红线**：加法混合下 src 会被再乘一次 `src.a` → alpha 一律 1.0，亮全算 rgb；`modulate`(节点色) 必须纯白否则叠脏；竖屏短边归一化；进 `fx_manifest.json` 登记。
- **验收**：`SkillSheet` 重渲出现水波纹格；默认参数下可见像素 15%~55%（无全黑/无全白）。

### T5 接入花灯 / 皮影（节点通）
- **花灯**：在 `GarlicRing.gd` 里把 `area_ripple` 作为 `aura_field` 之上的第二层（不替换现有边带，边带保留作"边界=走位依据"）；让波纹**周期性发射**（如每 0.6s 一圈扩散）且与 `beat()`（命中时）叠加，使"持续烧"与"打中一下"两种语义都有视觉。
- **皮影**：在 `_update_orbits`（`WeaponManager.gd:64`）里给环绕体挂一圈小型 `area_ripple`（或沿轨拖尾），半径=环绕半径，颜色随武器配色。
- **红线**：花灯是**常驻 T1 节点**（单例，不破坏合批，与现有 `aura_field` 同策略）；**不要**给每个敌人挂独立 ShaderMaterial；波纹/边带都走 `ShaderFX` 的 `clear()` 复位（池化/重开不残留）。
- **验收**：花灯圈内有持续水波纹、命中时额外一跳；皮影环绕体有可见范围环；SmokeTest/FxInGame 不回退。

---

## 4. godotshaders 推荐效果（补全/升级用）

| 用途 | 链接 | 适配说明 |
|---|---|---|
| **范围伤害水波纹（主推）** | [Circular Waves 2D](https://godotshaders.com/shader/circular-waves-2d) | `canvas_item`、MIT、**不含 SCREEN_TEXTURE**，同心环 `sin(dist*freq - TIME*rate)`。直接改编为 `area_ripple.gdshader` 的底子。 |
| 水波纹（参考，需去 SCREEN_TEXTURE） | [Transparent Ripples](https://godotshaders.com/?p=8416/) | 同心环数学可借鉴，但它用 `SCREEN_TEXTURE` 扭曲背景——**本作禁用**，必须删掉那段，只留环。 |
| 静态装饰同心环（可选） | [Circular Pattern Shader](https://godotshaders.com/?p=9502) | CC0，两色交替同心环，可做"持久领域"的静态填充，但无动画；优先级低于 Circular Waves。 |
| **不适用** | [Water Ripples](https://godotshaders.com/shader/water-ripples/) | 这是 **spatial（3D）** 着色器，本作 2D `canvas_item` 用不了。明确排除。 |

**决策原则**：in-house 已有的 `aura_field`/`magic_circle` 优先复用；新水波纹只在"要同心扩散环"时新建 `area_ripple`，且**必须**过 §5 红线（禁 SCREEN_TEXTURE、短边归一化、additive alpha=1.0）。

---

## 5. 工程红线（与 v5_ai_playbook 一致）

- 新资源/新 shader **必须**登记 `Art.gd` 的 `ALL_PATHS` / `SLOT_ALIASES`（冒烟测试资源守卫依赖），否则 `SmokeTest` 报缺资源。
- 竖屏 720×1280：**所有"全屏/径向"shader 按短边归一化**，避免红边/波纹吃中线（历史坑：`hurt_vignette` 初版按 `screen_size.y` 整屏泛红）。
- 加法混合（`blend_add`）：`COLOR.a` 固定 1.0，亮度算进 rgb；节点 `modulate` 纯白。
- 合批纪律：花灯/皮影是单例节点，走既有 `aura_field` 策略；**绝不**给同屏 50~200 的小怪每只挂独立 ShaderMaterial（掉合批）。
- 配色沿用现有剪纸风：朱红 `#C8442E`、暖铜 `#C8923A`、靛蓝 `#2E5A8C`；不引入新画风。
- 场景切换用 `change_scene_to_file`；`queue_free` 不 `free`；`@onready` 类型化取节点；零 `get_parent` 上行通信（用信号）。

---

## 6. 验收命令与门槛（改完必须跑）

```bash
# 回归基线（不得回退）
godot --headless --path GameDemo/first-xi-xue-gui res://tools/SmokeTest.tscn   # 299/0
godot --path GameDemo/first-xi-xue-gui res://tools/FxInGame.tscn              # 18/18
godot --path GameDemo/first-xi-xue-gui res://tools/SkillSheet.tscn            # 重渲 skill-preview.png，确认水波纹格正常

# 新内容单独验收
godot --path GameDemo/first-xi-xue-gui res://scenes/MainMenu.tscn             # F6 独立跑通，四按钮可见可点
```

---

## 7. 建议实施顺序

```
T1 主菜单场景 + 改 main_scene        （解"开局即战斗"）
   ↓
T2 四按钮接线（新游戏/退出先通）      （最快可见成果）
   ↓
T3 商店独立化 + 菜单开商店           （复用 DeathUI 范式，不动旧路径）
   ↓
T3.4 载入存档语义（先默认，确认后可选扩展）
   ↓
T4 area_ripple.gdshader + ShaderFX API  （着色器专家介入）
   ↓
T5 接入花灯 / 皮影                    （节点通接线，复用 ShaderFX.clear 复位）
   ↓
回归：SmokeTest 299/0 · FxInGame 18/18 · SkillSheet 重渲
```

---

## 8. 任务索引（一句话）

| ID | 域 | 文件 | 一句话 |
|---|---|---|---|
| T1 | UI/场景 | `scenes/MainMenu.tscn` + `project.godot:14` | 建菜单场景并设为入口 |
| T2 | 脚本 | `scripts/ui/MainMenu.gd` | 四按钮接线 |
| T3 | 脚本/UI | `scenes/ui/ShopUI.tscn` | 商店独立化，菜单可开 |
| T3.4 | 脚本 | `scripts/ui/MainMenu.gd` | 载入存档语义（默认实现） |
| T4 | 着色器 | `assets/shaders/fx/skill/area_ripple.gdshader` | 水波纹（Circular Waves 改编） |
| T5 | 脚本 | `scripts/GarlicRing.gd` + `WeaponManager.gd:64` | 花灯/皮影接入波纹 |
