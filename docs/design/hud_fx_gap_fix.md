# HUD 数值显示 & 敌人受击/死亡特效 —— 实施规范（给 AI 看）

> 定位：本文件是**实施型 AI / 节点通专家**的动手规范，不是设计讨论。所有改动都要对着下面的
> `文件:行号` 落地，并遵守 §7 红线与 §8 验收。本文档由实读工程代码 + godotshaders.com 检索得出，
> 不靠猜。
>
> 上游设计口径：`docs/design/skills-and-midgame-v4.md`（v5 重写）、`docs/design/fx-pack.md`（特效包说明）、
> `docs/design/v5_ai_playbook.md`（通用实施纪律）。

---

## 0. 一句话结论

| 用户反馈 | 真实状态（实读） | 该怎么做 |
|---|---|---|
| 打击伤害没显示 | 全工程**没有任何伤害飘字系统** | 新建一个池化的 `DamageNumberLayer`（UI 任务，不是 shader） |
| 自身血量没显示 | 血条在，但**只有条没有数字** | HUD 加一个 HP 数字 Label（UI+脚本） |
| 经验值没显示 | 经验条在，但**只有条没有数字** | HUD 加一个 EXP 数字 Label（UI+脚本） |
| 护盾数值没显示 + 护盾效果没显示 | 护盾只有一条很弱的蓝色光环（`Player.gd:169`），无数字、无条 | 加护盾数字 + 血条下方护盾条 + 强化光环可见性 |
| 敌人受击效果没有 | 小怪只有 0.09s 染色（`Enemy.gd:309`），几乎看不出 | 小怪加**池化命中火花**（不破坏合批）+ 保留/强化染色；精英/Boss 用现有 `hit_flash` shader |
| 敌人击败消失效果没有 | 小怪只放大淡出（`Enemy.gd:333`），无溶解 | 小怪死亡也走现有 `dissolve_out`（in-house `dissolve_spawn.gdshader`） |

**关键认知**：受击闪、溶解这两个 shader 上一轮已经做好并校验过（`assets/shaders/fx/hit_flash.gdshader`、
`assets/shaders/fx/dissolve_spawn.gdshader`），本任务**优先复用，不要重写**。godotshaders 的同类效果列在 §3 作为"升级/换皮"备选。

---

## 1. 现状核查（带行号，实施前请先对一遍）

### 1.1 HUD 现有结构（`scripts/ui/HUD.gd`）
- `xp_bar: TextureProgressBar`（$Top/Col/XPBar）—— 经验条，已绑定 `$Top/Col/XPBar`，`_process` 里写 `value`/`max_value`（HUD.gd:156-157）。**无数字**。
- `hp_bar: TextureProgressBar`（$Top/Col/HPBar）—— 血条，已绑定，HUD.gd:158-159 写值。**无数字**。
- `level_label: Label` —— 显示 `Lv %d`（HUD.gd:160）。
- `_process` 已经能拿到 `_player.stats["hp"]`、`_player.stats["max_hp"]`（HUD.gd:158-159），所以加数字**不用改数据通路，只加 Label + 文本赋值**。
- 受伤红边已用 `ShaderFX.hurt_drive`（HUD.gd:180），与本次无关。

### 1.2 Player 现有结构（`scripts/Player.gd`）
- `shield_hp := 0.0`（Player.gd:48）—— 当前护盾吸收池（**当前值**）。
- `_shield_ring: ColorRect`（Player.gd:50）—— 蓝色光环（`ShaderFX.add_aura(art, 92.0, Color(0.55,0.78,1.0))`，Player.gd:169），可见性由 `_update_passives` 控制：仅当 `stats["shield"]>0` 时 `visible = shield_hp > 0.0`（Player.gd:158-171）。
- `take_damage`（Player.gd:301）—— 结界先吃伤害，破盾瞬间 `_flash_left = 0.22`（Player.gd:313-316）。**这里就是护盾"破/减"的钩子点，飘字可在此 emit。**
- `stats["shield"]` 是护盾**最大值**（来自 `Stats.STAT_KEYS` 的 `"shield"`，Stats.gd:38）—— HUD 读这个当护盾条 max。

### 1.3 Enemy 现有结构（`scripts/Enemy.gd`）
- `take_damage(dmg, weapon_type)`（Enemy.gd:293）—— 这里同时拥有 `amount`（实际伤害）和 `global_position`（世界坐标）。**这是伤害飘字 + 受击火花的唯一正确钩子点。**
- 小怪受击：`art.modulate = HIT_COLOR`（Enemy.gd:309），0.09s 后在 `_process` 复位（Enemy.gd:240-243）。弱。
- 精英/Boss 受击：`ShaderFX.flash(art, HIT_COLOR, FLASH_TIME)`（Enemy.gd:305）—— 已是 shader 闪。
- 小怪死亡：`scale = 1.25; modulate.a = 0`（Enemy.gd:333-337），无溶解。
- 精英/Boss 死亡：`ShaderFX.dissolve_out(art, ELITE_DISSOLVE, false)`（Enemy.gd:330）—— 已是溶解。
- 池回收纪律：`setup()` 里 `ShaderFX.clear(art)`（Enemy.gd:84）会在复用前清掉材质，**所以小怪死亡时临时挂 dissolve 材质是安全的**（回收即清）。

---

## 2. 任务拆分（6 个，按文件/专家/效果分）

### 任务 A — 伤害飘字（打击伤害数字）
- **类型**：UI + 脚本（**不是 shader**，godotshaders 没有"伤害数字"这种现成系统，它是 Label + Tween）。
- **专家**：节点通（主）+ UI 设计（数字排版/配色）。
- **做法**：
  1. 新建 `scripts/ui/DamageNumbers.gd` + 一个 `Node2D` 层（挂在 `Game` 场景根，名字 `DamageNumbers`，或做成 `CanvasLayer`）。提供 `pop(world_pos: Vector2, amount: float, is_crit: bool)`。
  2. **池化**：内部维护一组 `Label`（或 `RichTextLabel`），`pop()` 时取一个空闲的，赋值文本，Tween：`position.y -= 28`、`modulate.a` 1→0，约 0.6s 后回收（设 `visible=false` 待复用）。不要每次 `Label.new()`。
  3. 暴击（`is_crit`）走更大字号 + 朱红（`#FF5C38`），普通走暖白（`#FFE9C2`）。字体加描边（`add_theme_color_override("font_shadow_color")`），否则在深色敌人上读不出。
  4. **钩子**：在 `Enemy.take_damage`（Enemy.gd:299 之后、`_die()` 之前）emit 信号 `damage_dealt(global_position, amount, is_crit)`；`DamageNumbers` 订阅（Game 在 `_ready` 把二者连起来，用信号而非 `get_parent`）。
  5. 世界坐标→层坐标：因为本作无摄像机滚动（固定 720×1280），直接用 `world_pos` 即可；若挂在 `CanvasLayer` 需用 `get_viewport().canvas_transform` 换算，注意这点。
- **验收**：打中敌人头顶冒出数字并上飘淡出；同屏 50 只受击不卡（池化生效）；暴击明显更大更红。
- **godotshaders 参考**：无直接对应（属 UI），可参考通用 floating-combat-text 思路。

### 任务 B — 血条数字（自身血量）
- **类型**：UI + 脚本。
- **专家**：节点通（主）+ UI 设计。
- **做法**：在 `HUD.gd` 的 `hp_bar` 旁（用 `HBoxContainer` 或 `Label` 锚定到血条右侧/上方）加一个 `hp_label: Label`。在 `_process`（HUD.gd:159 之后）写 `hp_label.text = "%d / %d" % [ceil(hp), max_hp]`。
- **验收**：血条旁实时显示 `当前/最大`；数值随受击-3/s（HUD.gd:180 的 `hit_flash` 无关）与回血变化。

### 任务 C — 经验数字（经验值）
- **类型**：UI + 脚本。
- **专家**：节点通 + UI 设计。
- **做法**：在 `xp_bar` 旁加 `xp_label: Label`。在 `_process`（HUD.gd:156-157 之后）写 `xp_label.text = "%d / %d" % [xp, xp_next]`。Lv 已显示（HUD.gd:160），可顺手把等级数字和 EXP 数字排在一起。
- **验收**：经验条旁显示 `当前/升级所需`。

### 任务 D — 护盾数值 + 护盾条 + 强化可见性
- **类型**：UI + 脚本（+ 轻微 shader/视觉）。
- **专家**：节点通（主）+ UI 设计（条与数字样式）。
- **做法**：
  1. **护盾条**：在 HUD 的 `hp_bar` **下方**新增 `shield_bar`（复用 `TextureProgressBar`，与血条同款样式；或采用 §3 的 godotshaders Flexible Progress Bar 换皮）。`max_value = stats["shield"]`，`value = shield_hp`。**仅当 `stats["shield"] > 0` 时显示整条+数字**，否则 `visible=false`（避免没买结界时一块空条）。
  2. **护盾数字**：`shield_label.text = "%d / %d" % [ceil(shield_hp), stats["shield"]]`。在 `_process` 读取 `Player.shield_hp`（当前值）与 `_player.stats.get("shield", 0.0)`（最大值）。
  3. **强化可见性**：现有 `_shield_ring` 是细弱加法光环（Player.gd:169）。建议：把 `ShaderFX.add_aura` 的半径/强度调明显一点（如 `radius 0.5`、颜色更亮），或额外在玩家脚下加一圈更实的描边环；破盾瞬间（`Player.take_damage` 里 `shield_hp<=0` 分支，Player.gd:313）给环一次快速收缩/闪烁，读得出"盾没了"。
- **验收**：买了结界被动后，血条下方出现护盾条 + `当前/最大` 数字，随受击实时扣减、周期回满（Player.gd:163-166）；破盾有明显反馈。

### 任务 E — 敌人受击效果（小怪）
- **类型**：脚本 + 特效（**保留 in-house，不重写**）。
- **专家**：节点通（主）；着色器专家仅在要换 godotshaders 版本时介入。
- **做法**：
  1. **小怪命中火花（推荐，不破坏合批）**：在 `Enemy.take_damage`（Enemy.gd:299 之后）调用一个**池化的加法火花**——复用现有 `ShaderFX.spawn_spark` 或在世界层 `DamageNumbers` 旁加一个 `HitSparkLayer`，每次命中在 `global_position` 处 `pop` 一颗加法混合小星（0 采样、纯 rgb、`blend_add`）。这样**完全不碰敌人材质**，同屏上百只也不掉合批。
  2. **保留并强化小怪染色**：把 `Enemy.gd:309` 的 `art.modulate = HIT_COLOR` 保留（T0 策略），但把 `FLASH_TIME` 从 0.09 略升到 0.12、颜色更亮，让"被打中"更明确。
  3. **精英/Boss 不变**：继续用 `ShaderFX.flash`（Enemy.gd:305）。
  4. **可选升级（非必须）**：若想要 godotshaders 的"节奏闪"（连闪/频闪表现暴击），见 §3 的 Hit flash with rhythm patterns —— 只给精英/Boss（T1）用，不要给小怪（T0 会掉合批）。
- **验收**：小怪中弹时有"染色 + 火花"双重反馈；精英/Boss 有 shader 闪；同屏 150+ 怪物帧率不劣化（合批未被破坏）。

### 任务 F — 敌人死亡溶解（小怪）
- **类型**：脚本 + 特效（**复用 in-house `dissolve_spawn.gdshader`**）。
- **专家**：节点通（主）。
- **做法**：在 `Enemy._die()` 的小怪分支（Enemy.gd:332-337，当前是 `scale=1.25; modulate.a=0`）改为走溶解：
  ```gdscript
  else:
      # 小怪也化墨散去（复用 in-house 溶解，restore=false 与精英同款纪律）
      ShaderFX.dissolve_out(art, 0.30, false)
      _corpse_left = 0.30
  ```
  - 注意 `CORPSE_TIME`（Enemy.gd:13）目前 0.20，溶解需 ≥0.30，把小怪分支的 `_corpse_left` 设为与溶解同长（如上 0.30），避免"溶到一半被回收"的凭空消失。
  - 池回收纪律已就位（`setup()` 调 `ShaderFX.clear(art)`，Enemy.gd:84），复用安全。
  - 不必给小怪加发光边过曝：`dissolve_spawn` 的 `edge_boost` 默认 0.9 即可（未开 HDR 2D，超过 1.2 会被裁白，见 fx-pack.md §5）。
- **验收**：小怪死亡像精英一样"化墨散去"而非硬淡出；池复用后新怪不再带半透明（clear 已处理）。

---

## 3. godotshaders.com 推荐效果（补全/升级用，非必须重写）

| 需求 | godotshaders 链接 | 说明 | 本项目建议 |
|---|---|---|---|
| 血条/经验条/护盾条（换皮或要拖尾/分段） | [Flexible Progress Bar](https://godotshaders.com/shader/flexible-progress-bar/) | ColorRect 材质，支持 Health Bar 模式、分段、Pour 动画、Drain 闪光、段位信号 | **现有 `TextureProgressBar` 已能跑**，只有想要"掉血拖尾/分段"时才换它；护盾条可直接复用同款样式 |
| 血条带"受伤拖尾" | [Health Bar](https://godotshaders.com/shader/health-bar) | 伤害拖尾（掉血/回血不同色）+ 低血脉冲 | 同上，作为护盾条掉盾拖尾的可选效果 |
| 敌人受击（精英/Boss 升级闪） | [Hit flash with rhythm patterns](https://godotshaders.com/shader/hit-flash-with-rhythm-patterns/) | 5 种节奏（重击/连闪/频闪/脉冲），带 edge_glow 描边，兼容 Compatibility | **in-house `hit_flash.gdshader` 已实现同款**（amount/flash_color/active/boost/outline）。只给 T1 精英/Boss 用；小怪别用（掉合批） |
| 敌人死亡溶解（升级版带烧边） | [2D dissolve with burn edge](https://godotshaders.com/shader/2d-dissolve-with-burn-edge) | 噪声溶解 + 发光烧边 | **in-house `dissolve_spawn.gdshader` 已实现**（edge_color/edge_width/edge_boost/edge_tint），直接复用；只有想换噪声风格时才参考它 |
| 敌人死亡溶解（轻量版） | [Simple 2D dissolve](https://godotshaders.com/shader/simple-2d-dissolve) | 最简化溶解，无烧边 | 移动端更省，可作为小怪溶解的更轻替代 |
| 伤害飘字 | 无直接对应（属 UI） | — | 按 §2 任务 A 自建池化 Label，不依赖 shader |

**决策原则**：in-house 已有的 `hit_flash` / `dissolve_spawn` 已经过 Godot 4.6 实跑校验（见 fx-pack.md §9.4），
**优先复用**；godotshaders 链接只在"要换风格/加烧边强度/要拖尾"时作为升级参考，不要为换而换。

---

## 4. 专家分工建议

| 角色 | 专家 | 负责 |
|---|---|---|
| **主** | **节点通（Godot 游戏脚本工程师）** | 全部 6 个任务的 GDScript 落地：HUD 数字、DamageNumbers 池、护盾条、Enemy 受击/死亡接线、复用 in-house shader。最契合本作"强类型 GDScript + 冒烟测试 + 合批纪律"的文化 |
| 支 | **UI 设计专家** | 数字排版/配色（朱红/暖铜/靛蓝，匹配现有剪纸画风）、护盾条与血条下方布局、伤害飘字字号与描边，避免 720×1280 竖屏被数字挤爆 |
| 支（可选） | **着色器专家** | 仅在决定要把 in-house `hit_flash`/`dissolve_spawn` 换成 godotshaders 版本、或调整护盾光环着色时介入；通常不需要 |

> 为什么主专家是"节点通"而不是单独的 UI/着色器专家：本任务 80% 是 Godot `Control`/`Node2D` 接线 +
> 复用既有 shader，纯 UI 设计与纯 shader 工作都可被节点通覆盖；UI 设计专家只做"好不好看"的把关。

---

## 5. 给实施 AI 的必读文件清单

实施前**必须**读这些（路径相对工程根 `GameDemo/first-xi-xue-gui/`）：

- `scripts/ui/HUD.gd` —— 血条/经验条/等级已在此；新增数字与护盾条的位置
- `scripts/Player.gd` —— `shield_hp`（Player.gd:48）、`_shield_ring`（:169）、`take_damage`（:301）、`_update_passives`（:151）
- `scripts/Enemy.gd` —— `take_damage`（:293）、`_die`（:316）、`CORPSE_TIME`（:13）、`ShaderFX.clear`（:84）
- `scripts/Stats.gd` —— `STAT_KEYS`（:34，含 `"shield"`）、`make_base`（:122）、`effective_at`（:104）
- `scripts/ShaderFX.gd` —— `flash` / `dissolve_out` / `spawn_spark` / `add_aura` / `clear` 的调用约定
- `assets/shaders/fx/hit_flash.gdshader` + `dissolve_spawn.gdshader` —— 受击/溶解的 uniform（不要重写）
- `assets/shaders/fx/fx_manifest.json` —— 上述 shader 的参数/默认值/互斥
- `docs/design/fx-pack.md` —— §5 调参速查、`blend_add` 二次 alpha、竖屏按短边归一化、合批 T0/T1/T2 策略
- `docs/design/v5_ai_playbook.md` —— §4 工程红线、§8 回归命令

---

## 6. 实施流程（建议顺序）

```
Phase 0  先跑通读数（B+C）：HUD 加 HP/EXP 数字 Label，_process 里赋值。零风险，立刻可见。
   ↓
Phase 1  护盾（D）：HUD 加 shield_bar + shield_label，_process 读 Player.shield_hp / stats["shield"]；
          强化 _shield_ring 可见性；破盾反馈接 Player.take_damage。
   ↓
Phase 2  伤害飘字（A）：新建 DamageNumbers 池化层 + 信号；Enemy.take_damage emit damage_dealt；
          Game 连线（信号，不用 get_parent）。
   ↓
Phase 3  敌人效果（E+F）：小怪加池化命中火花（不碰材质）；小怪 _die 走 dissolve_out（复用 in-house）。
   ↓
Phase 4  UI 设计专家过一遍：数字字号/描边/配色/护盾条位置，确保竖屏不挤。
```

> E 与 F 都涉及"敌人表现"，但 F（小怪溶解）会改变死亡观感，建议和上一轮已做的"花灯加伤/打铁花引爆"
> 同批改意识：若同时动了命中结算，务必重跑 SmokeTest（见 §8）。

---

## 7. 红线（违反会让 PR 被打回）

1. **合批纪律（最关键）**：小怪（同屏 50~200）**绝不**给每只挂独立 `ShaderMaterial` 做受击闪——那等于每只多一次 draw call。小怪受击用"染色 + 池化火花"，只给精英/Boss 用 shader 闪。
2. **复用 in-house shader**：`hit_flash` / `dissolve_spawn` 已校验，不要重写；新 shader 一律先问"能不能复用"。
3. **池化**：伤害飘字、命中火花必须池化（`visible=false` 复用），禁止每次命中 `Label.new()` / `queue_free()`。
4. **blend_add 贴图**：加法混合的火花/光环 alpha 固定 1.0，亮度算进 rgb；`ColorRect.color` 必须纯白（见 fx-pack.md §9.2）。
5. **竖屏按短边归一化**：任何全屏/边缘效果按短边（720）归一化，别按 `screen_size.y`（1280）否则吃中线（hurt_vignette 踩过的坑）。
6. **ShaderFX.clear(art) 纪律**：池化敌人复用前必须 clear，`dissolve_out(..., false)` 的 restore=false 依赖它；谁改死亡表现谁负责这条。
7. **`@onready` 类型化、零 `get_parent`**：跨节点通信走信号（如 `damage_dealt`、`died`）；新场景能 F6 独立跑通。
8. **配色不引新画风**：数字/护盾条沿用 剪纸/朱红(#FF5C38)/暖铜/靛蓝(#59E6FF) 现有色板。

---

## 8. 验收（回归基线不得回退）

- `docs/balance` 数值模型不变（本任务不碰平衡数值，只加显示）。
- 回归命令（在 `GameDemo/first-xi-xue-gui/` 下用 Godot 4.6 console）：
  ```
  godot --path . res://tools/SmokeTest.tscn        # 必须 299/0
  godot --path . res://tools/FxInGame.tscn         # 必须 18/18
  godot --path . res://tools/SkillSheet.tscn       # 重渲技能对照图无异常
  ```
- 功能性验收：
  - 血条/经验条旁出现 `当前/最大` 数字，实时随战斗变化。
  - 打中敌人冒出上飘淡出数字；暴击更大更红；同屏 150+ 不卡。
  - 买结界被动后血条下方出现护盾条 + 数字，受击扣减、周期回满、破盾有反馈。
  - 小怪中弹有染色+火花；小怪死亡化墨散去而非硬淡出；池复用后无半透明残留。
- 性能：同屏 150 敌人时帧率不低于改动前（合批未被破坏）—— 用 HUD 的 `fps` 标签（HUD.gd:177）肉眼确认 + 冒烟不回退。
