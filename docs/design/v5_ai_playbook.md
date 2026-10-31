# v5 局内重写 — AI 实施总纲（Playbook）

> 本文件是给**实施型 AI / 节点通专家**看的"怎么动手"总纲。
> 它不是设计文档，也不是资源清单——这两样分别在 `skills-and-midgame-v4.md`（设计口径）和 `art_assets_manifest.json` / `v5_implementation_brief.json`（任务拆分）里。本文件把三者串成一条**可执行的、有验收、有红线**的动作链。
>
> **本轮只写这份指南，不落地任何游戏代码。** 下面所有步骤是给"下一步真正动手的 AI"照着做的。

---

## 0. 一句话定位

把 `skills-and-midgame-v4.md`（v5 重写方案）里的玩法机制，按本工程的强类型数据表 + 冒烟测试文化，落到 8 个 `.gd` 文件里，**全程以 `docs/balance/v5_model.py` 的数值模型为唯一真相源**，并保证既有回归（`SmokeTest 299/0`、`FxInGame 18/18`）不回退。

---

## 1. 目标与边界（动手前先背下来）

### 1.1 要做的（解决实机三大痛点）
| 痛点 | 机制应答 | 落到哪 |
|---|---|---|
| 10min 后挂机太轻松 | 中期墙（浆壳兵）+ 周期潮涌 + 小 Boss + 主动技·震吼 | `Enemy` / `WaveTable` / `Game` |
| 技能 10min 升满 | 拉慢早期 XP、抬高 cap、精炼系统 | `UpgradeDB` / `Stats` |
| 无局外无法通关 | Boss 血 11000→7000、更鼓→1.40、精炼抬终局 DPS | `Game` / `WeaponDB` |

### 1.2 不要做的（硬边界，违反即偏离方案）
- ❌ **不要再新增武器**。v5 方案已定 3 把新武器（gong/inkline/print），加完是 9 可选 / 6 槽位，池子够。再加只会稀释出场率，不增决策深度。
- ❌ **不要在本重写里动手面具系统**。`skills-and-midgame-v4.md` §12 明确"面具架（局外构筑）本重写不覆盖"。面具 12 面是 `art_assets_manifest.json` 里的 `out_of_scope_referenced`，留给局外系统单独一轮。
- ❌ **不要改中期难度的"方向"**（该难要难、该逼操作要逼），只能按模型微调强度。
- ❌ **不要重产已有的 6 把武器美术**（见 §5 红线）。
- ❌ **不要把震吼硬塞进 `Game.gd` 全局态**（见 §6.5）。

---

## 2. 动手前必读文件（按顺序）

| 顺序 | 文件 | 读它的目的 |
|---|---|---|
| 1 | `docs/design/skills-and-midgame-v4.md` | 设计口径、机制定义、§4.1 收敛带、§9 R 曲线、§10 验收门槛。**这是需求源头。** |
| 2 | `docs/balance/v5_model.py` + `v5_result.json` | 数值唯一真相源。改任何数之前先跑它、读它的 `band/shell/drum/surges/boss/curve/prog`。 |
| 3 | `docs/design/v5_implementation_brief.json` | 12 个文件级任务（T0–T11）的拆分、依赖、风险。本 Playbook 的 §6 是它的"动作化"。 |
| 4 | `docs/design/art_assets_manifest.json` | 哪些美术必须新建（6 missing）、哪些是既有复用、哪些 FX 无新贴图需求。 |
| 5 | `assets/shaders/fx/fx_manifest.json` + `scripts/ShaderFX.gd` | 引爆/冲击环/进化辉光**全部复用既有 shader**，不要新建 shader。 |

---

## 3. 关键代码事实（实现前必须确认，禁止凭印象猜）

以下符号是真实存在的，"下一步 AI"改代码时直接对号入座：

| 文件 | 真实符号 | 用法 |
|---|---|---|
| `scripts/WeaponDB.gd` | `DEFS: Dictionary`、`ORDER: Array[String]`、`MAX_LEVEL := 8`、`count_at(id, lv)` | 加新武器 = `DEFS` 加一条 + `ORDER` 追加；穿透里程碑改 `count_at` |
| `scripts/EvolutionDB.gd` | `FORMS: Dictionary`、`has_form/form/form_id_for`、`REQUIRE_WEAPON_LEVEL := 8`、`REQUIRE_PASSIVE_LEVEL := 1` | 进化只在原武器上打标记（不占新槽位） |
| `scripts/UpgradeDB.gd` | `STAT_DEFS`、`refines`（精炼，≤3 级，每级 +6%） | 新被动 regen/shield 进 `STAT_DEFS` |
| `scripts/Stats.gd` | `STAT_KEYS: Array[String]`、`value_at(key, lv)`、`meta_mult(key)`、`effective_at(key, lv)` | `effective_at = value_at × meta_mult`，**纯净公式不要污染** |
| `scripts/weapons/WeaponManager.gd` | `fire_whip/fire_halo/fire_projectile/fire_extinguisher`、`update_bullets(delta)`、`class Bullet`（含 `hit_cap`）、`_take_fx`/`_push_fx` | 新武器加 `fire_xxx`；引爆分支进 `update_bullets` |
| `scripts/Enemy.gd` | 受击结算入口 | 加 `shelled` 标志 + `damage_multiplier(weapon_type)` 分支 |
| `scripts/WaveTable.gd` | `MOB_SPAWN_DURING_BOSS` / `BOSSES` 等常量 | 扩展时间窗 / 潮涌 / 小 Boss 调度 |
| `scripts/Game.gd` | `_check_boss`、`enemy_hp/enemy_speed/spawn_interval`（难度缩放）、`_pick_kind` | 更鼓计时器、Boss 血、震吼入口；**震吼建议做成 Player 下子组件** |
| `scripts/Art.gd` | `ALL_PATHS`、`SLOT_ALIASES`、`Art.tex(path)` | 任何新贴图落地必须登记（冒烟测试资源守卫依赖） |
| `scripts/ShaderFX.gd` | `burst()`、`spawn_circle()` 等 API | 引爆冲击环用 `ShaderFX.burst()`，火花用现有命中火花逻辑 |

> 验证命令（在本工程根 `GameDemo/first-xi-xue-gui` 下跑）：
> `grep -n "ORDER\|count_at" scripts/WeaponDB.gd`
> `grep -n "STAT_KEYS\|effective_at" scripts/Stats.gd`
> `grep -n "func fire_\|class Bullet" scripts/weapons/WeaponManager.gd`

---

## 4. 工程红线（违反会静默失败或破坏合批）

这些是从前两轮 FX 工作与本工程文化里提炼的"不变量"，写进代码时逐条对照：

1. **新贴图落地必须登记 `Art.gd` 的 `ALL_PATHS` + `SLOT_ALIASES`**。漏接不会被测试发现，但运行时 `Art.tex()` 找不到图 → 卡面/世界贴图空白。
2. **`blend_add` 的 FX 贴图 alpha 必须固定 1.0**，亮度全算进 rgb，否则未开 HDR 2D 时被裁成纯白。
3. **竖屏特效归一化按短边（720），不要按 `screen_size.y`**，否则边缘放大吃掉中线（前轮 `hurt_vignette` 踩过）。
4. **CanvasItem 合批红线**：独立 `ShaderMaterial` 切断合批。分级策略继续有效——T0 群体用 `modulate`、T1 个体用 shader、T2 演出叠加。
5. **`fragment()` 里不能 `return`**（Godot 着色语言限制）——本重写不新建 shader，但改既有 shader 时要记着。
6. **节点通原则**：`@onready` 类型化取节点、`queue_free` 不 `free`、`get_parent` 上行通信改为信号、用信号而非 `_process` 轮询状态、`_ready` 后对象才有效。
7. **数值改动必须先回填模型**：任何 `damage/pierce/radius/cooldown/HP/密度` 变化，跑 `v5_model.py` 确认收敛带与曲线不变（见 §5）。

---

## 5. 数值真相源（务必先跑模型，不要手工拍数）

> **状态更正**：`v5_implementation_brief.json` 里 `T0_model` 曾报"模型缺失"——**该 blocker 已被补齐**。`docs/balance/v5_model.py` 与 `v5_result.json` 现已存在（含 `cur/v4/v5` 三变体、v5 的 shell/surge/drum/refine/explode/double_sweep 全机制），`v5_result.json` 顶层键为 `band/shell/drum/surges/boss/curve/prog`。所以 T0 不是"建模型"，而是**用模型**。

**T0（必做，最先做）**：
- 运行：`cd docs/balance && python v5_model.py`（默认输出 `v5_result.json`；`--json` 可改输出名）。
- 读 `v5_result.json`：
  - `band` = §4.1 收敛带，9 把武器 Lv8 总 DPS 必须全落在 **96–157**（跨度 <2×，无一把通吃；墨斗单体 100 独占单点头牌）。
  - `shell` = 浆壳兵墙（10–17min 纯 AoE 流 R≈0.53–0.63，带墨斗翻墙）。
  - `surges` = 潮涌尖峰 R（**0.17–0.33**，不是崩，是逼操作）。
  - `boss` = 5 种构筑 Boss 击杀 5–9s（局内可独立通关）。
  - `curve` / `prog` = §9 曲线与进程延展。
- **在改任何 `WeaponDB`/`Stats`/`WaveTable`/`Game` 数值之前，先跑一遍存基线；每次改完再跑一遍，diff `band/surges/boss` 不应劣化。**

---

## 6. 分阶段实施（动作化）

> 每阶段都标了：目标 / 改哪些文件 / 具体动作 / 依赖 / 验收。阶段内按任务顺序做。

### Phase 0 — 数值基线（§5 已述）
先跑模型、读 `v5_result.json`、存基线。未完成不进 Phase 1。

### Phase 1 — 纯数据层（无场景，可单测）
**文件**：`WeaponDB.gd` → `EvolutionDB.gd` → `UpgradeDB.gd` → `Stats.gd`
**动作**：
- `WeaponDB`：① `DEFS` 加 `gong/inkline/print` 三条（参数严格取自 `v5_model.py` 的武器定义，不要拍）；② `ORDER` 追加三把；③ `extinguisher` 加 `explode_radius=76`、`explode_ratio=0.65`；④ `halo` 减速 `0.15→0.22` + `slow_dmg=0.20`；⑤ `glowstick` 穿透里程碑（Lv4/Lv8 各 +1，在 `count_at` 实现）；⑥ `phone` 加 `knock=0.15`；⑦ `blade` 加 `bounce_falloff`（同目标第2跳后 -30%）；⑧ `whip` 加 `double_sweep`（Lv7/Lv8 扫两次，各 60%）。
- `EvolutionDB`：`FORMS` 加 `evolve_gong`(开市锣, dps×1.50, area×1.50, req_passive=火候)、`evolve_inkline`(龙筋墨线, dps×1.55, area×1.10, req=匠心)、`evolve_extinguisher`(百子千花, dps×1.50, area×1.40, **每2命中引爆**, req=火候)。沿用 `meets_recipe`/`candidates` 框架。
- `UpgradeDB`：`STAT_DEFS` 加 `regen`（每秒回血 +1.5×lv）、`shield`（每12s 护盾 30+15×lv）；精炼在"已满级武器再 pick"时写回 `refines`（≤3 级，每级该武器 +6%，不占新卡位）。
- `Stats`：`STAT_KEYS` 7→9（`regen/shield`）；`value_at` 覆盖；精炼作为**武器级乘区**（在武器最终伤害结算处乘，不要进全局 `effective_at`）。
**依赖**：Phase 0。
**验收**：`test_evolution_dps_constraint` 仍过（三新进化 `dps_mult×area_mult` 不破既有上界）；三新武器出现在 `ORDER` 且 `has_weapon/def` 能命中；`STAT_KEYS` 长度 9；regen 满级每秒回 7.5、shield 满级每12s 105 护盾的断言通过。

### Phase 2 — 武器发射与机制 + FX 接线
**文件**：`WeaponManager.gd`（新增 `fire_gong/fire_inkline/fire_print`；`update_bullets` 加引爆分支与各机制分支）
**动作**：
- 新武器：`fire_gong`（aura 半径150/满级8目标/amp=0.12 破壳微增益）、`fire_inkline`（直线穿透单点/单体100/shell_bonus=1.80）、`fire_print`（延迟0.45s 落点范围爆发/半径105/focus=1.8）。参考现有 `fire_whip` 的 typed 方法签名。
- 引爆分支（打铁花）：命中第 1 个敌人时落点炸 `explode_radius/explode_ratio`，**每发只引爆一次**（用 `Bullet` 上的 bool 标记）；进化百子千花改为每 2 命中引爆。
- 各机制分支：halo 对减速敌 +`slow_dmg`；glowstick 穿透里程碑（读 `count_at`）；phone 命中给 `knock` 击退；blade 同目标第2跳后 `bounce_falloff`；whip Lv7/Lv8 双扫。
- FX：**复用 `ShaderFX.burst()` 做冲击环 + 现有命中火花逻辑**。无新 shader、无新贴图。
**依赖**：Phase 1 + FX 已就绪（`art_assets_manifest.json` 的 `fx_texture_notes` 已确认无新贴图）。
**验收**：三新武器能发射/命中/结算；打铁花单挑 vs 扎堆伤害差落在 §3.4 的 **-19% / +35~47%**；**被直接命中的怪不吃自己触发的爆炸**（防双算，Brotato 规则）——写断言；与既有 6 把互不干扰。

### Phase 3 — 敌人与刷怪调度
**文件**：`Enemy.gd` → `WaveTable.gd`
**动作**：
- `Enemy`：加 `shelled` 标志 + 受击倍率分支（血×1.40、吃 AoE×0.75、吃单点×1.0、吃墨斗×1.80）；加 `shield` 护盾吸收分支（与 Phase 1 的 shield 联动）；`damage_multiplier(weapon_type: StringName) -> float` 抽成 typed 函数，不要散写 if。
- `WaveTable`：① 浆壳时间窗 8–17min 满上壳、17–20min 线性溃散、20:00 消失（驱动 `Enemy.shelled`）；② 周期潮涌 10/15/20/25/30min 各一波（持续 22–45s，刷新 lam_mult 1.35→1.55、精英 +0.08→0.16，只做尖峰）；③ 小 Boss 12/18/24min 各刷（复用 `boss_drum/boss_faceless_nuo/boss_long_night_lantern`）。
**依赖**：Phase 1（`shelled` 倍率需读武器类型）、Phase 2（`inkline` 的 `shell_bonus` 需 `Enemy` 受击分支配合）。
**验收**：8–20min 杂兵壳状态正确；潮涌尖峰 R 砸到 §9.1 的 0.17–0.33 且中位死亡率 ≤60%；壳状态与 `WaveTable` 时间窗一致。

### Phase 4 — 局内全局（更鼓 / Boss / 主动技）
**文件**：`Game.gd`
**动作**：
- 更鼓：加 30min 一更 → 1.40（沿用 `DRUM_TIMES` 时间轴，`drum_mult(t)` 已含）。
- Boss 血：`BOSS_HP` 11000→7000（在 `_check_boss`/`enemy_hp` 传入处改）。
- 主动技·震吼：**建议做成 Player 下的 `ActiveSkill` 子组件（Node）**，通过信号 `active_skill_used` 上行给 `Game` 管 CD（25s）；触发时半径220爆发（**250% 当前单体 DPS，读动态构筑，不写死绝对值**）+ 0.7s 无敌向摇杆方向冲刺；无敌帧用短时标记 + 计时器，到期自动复位（严格 ≤0.7s）。输入检测用 `InputEvent`，不要 `_process` 轮询。
**依赖**：Phase 2（震吼读单体 DPS 需武器系统）。
**验收**：更鼓 30min 达 1.40；Boss=7000 时 5 构筑击杀 5–9s；震吼 CD 实测 25s、无敌 ≤0.7s、冲刺脱围可行。

### Phase 5 — 美术与 UI（并行，独立专家，不阻塞玩法）
**文件**：`assets/art_shouyiren/**` + `scripts/Art.gd`
**动作**：按 `art_assets_manifest.json` 产 6 missing + 5 recommended（SVG，剪纸/朱红/暖铜/靛蓝语言）；每个新贴图落地后**必须在 `Art.gd` 的 `ALL_PATHS` + `SLOT_ALIASES` 登记**。面具 12 面按 §12 局外另议排期。
**依赖**：Phase 1（武器 id 定了才能出对应贴图）、Phase 4（震吼按钮、精炼徽标）。
**验收**：`Art.ALL_PATHS` 含全部新路径；F6 各含新资源的场景不报缺图。

---

## 7. 不要做的事（回归红线清单）

- 🚫 **只做引爆不做 halo 加伤**（或反过来）。打铁花引爆与花灯加伤会加剧"远程抢光环击杀"，`v5` 方案 §3.4 要求**必须同批改**，只做一半会让花灯更没人用。
- 🚫 **污染 `Stats.effective_at` 的纯净公式**。精炼必须独立乘区，不要和 `meta_mult` 串味。
- 🚫 **给面具加任何局内逻辑**。本重写不覆盖面具（§12）。
- 🚫 **新增 shader**。FX 全部复用既有 `cast_burst`/`spawn_spark`/`kailian_burst`。
- 🚫 **漏登记 `Art.gd`**。
- 🚫 **写死震吼"250% DPS"的绝对值**。必须读当前构筑的单体 DPS（glowstick/inkline/blade 权重）。

---

## 8. 验收与回归（命令 + 期望）

> 动手前先跑一遍存基线；每个 Phase 完成后跑一遍；全做完跑最终回归。

**命令（在本工程 `GameDemo/first-xi-xue-gui` 下；Godot 用 4.6 stable 控制台二进制）**：
```bash
# 数值模型（Phase 0 / 每次改数后）
cd docs/balance && python v5_model.py

# 既有回归（不得回退）
Godot --headless --path GameDemo/first-xi-xue-gui res://tools/SmokeTest.tscn     # 299/0 现状
Godot --headless --path GameDemo/first-xi-xue-gui res://tools/FxInGame.tscn       # 18/18 现状

# FX 对照图重渲（确认无"编译过但全黑/被裁白"）
Godot --path GameDemo/first-xi-xue-gui res://tools/SkillSheet.tscn               # 产出 shot_skill_sheet.png
```

**§10 机枢采纳门槛（六字段齐全才算 pass）**：
- 稳态 R 在 10–17min 落 0.45–0.75（墙但不秒杀）
- 潮涌尖峰 R 不导致中位死亡率 >60%
- 5 种构筑 Boss 击杀 ≤12s（局内可通关）
- 10min 满级武器数 ≤2

**Rollback 阈值（触发即回调）**：
- 潮涌中位死亡率 >60% → 下调 `SURGES` 的 `lam_mult`/`dur`
- 10min 满级 >2 或大量 pick 闲置 → 回调 `exp` 至 2.7 / `cap` 至 54
- Boss 击杀 >12s → 回调 `BOSS_HP` 至 8000

**信号状态**：`pass` / `fail` / `confounded`（同时动潮涌强度与精炼倍率→作废重测）/ `stop`（潮涌尖峰放震吼仍必死→先降尖峰）。

**回归基线**：`FxInGame 18/18`、`SmokeTest 299/0` 现状**不得回退**。

---

## 9. 并行专家分工（不阻塞玩法落地）

| 角色 | 谁做 | 范围 | 阻塞关系 |
|---|---|---|---|
| **主：玩法逻辑** | 节点通（godot-game-script-engineer） | §6 的 Phase 1–4 全部 `.gd` | 不依赖美术即可跑通（新武器先用占位 SVG） |
| 支：美术 SVG | 图像生成 / AI 美术管线 | 6 missing + 5 recommended（见 manifest） | 与 Phase 1–4 并行；落地后登记 `Art.gd` |
| 支：UI / HUD | UI 设计专家 | 震吼按钮（竖屏单摇杆输入）、精炼徽标、潮涌 HUD 提示 | 依赖 Phase 4 的震吼入口 |
| 支：数值模型 | 数值分析师（或节点通兼任） | 维护 `v5_model.py`、把 §10 验收写成可跑断言 | 先于所有数值改动（Phase 0） |

---

## 10. 任务索引（与 `v5_implementation_brief.json` 对应）

| 任务 | 文件 | 阶段 |
|---|---|---|
| T0 模型基线 | `docs/balance/v5_model.py` | Phase 0 |
| T1 WeaponDB | `scripts/WeaponDB.gd` | Phase 1 |
| T2 EvolutionDB | `scripts/EvolutionDB.gd` | Phase 1 |
| T3 UpgradeDB | `scripts/UpgradeDB.gd` | Phase 1 |
| T4 Stats | `scripts/Stats.gd` | Phase 1 |
| T5 新武器发射 | `scripts/weapons/WeaponManager.gd` | Phase 2 |
| T6 机制分支 + 引爆 | `scripts/weapons/WeaponManager.gd` | Phase 2 |
| T7 Enemy | `scripts/Enemy.gd` | Phase 3 |
| T8 FX 接线 | `assets/shaders/fx/` + `ShaderFX.gd` | Phase 2（复用，无新） |
| T9 WaveTable | `scripts/WaveTable.gd` | Phase 3 |
| T10 Game | `scripts/Game.gd` | Phase 4 |
| T11 美术与登记 | `assets/art_shouyiren/**` + `Art.gd` | Phase 5 |

---

## 11. 收尾

完成 Phase 1–4 后，跑 §8 的全部回归命令，确认 `SmokeTest 299/0`、`FxInGame 18/18` 不回退、`v5_model.py` 的 `band/surges/boss` 与基线一致。美术（Phase 5）可与玩法并行，但每个新贴图**必须**登记 `Art.gd` 才能算"接入完成"。

**本重写不改面具、不新增武器（除 v5 既定 3 把）、不新建 shader。** 任何偏离 §1.2 边界的改动都需先回到 `skills-and-midgame-v4.md` 确认方案，不要擅自扩 scope。
