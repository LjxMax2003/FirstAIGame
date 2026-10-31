# FirstXiXueGui

民俗手艺题材的竖屏生存肉鸽（survivors-like）原型 · Godot 4.7.2

> **这是一个 AI 协作完成的学习项目，仅供查看与学习，不是可发行产品。**
>
> - **AI 参与全流程**：策划、124 张美术、GDScript 代码、shader、测试工具、文档均由 AI 助手协作产出。详见 **[AI_USAGE.md](AI_USAGE.md)**。
> - **未完成**：无音频、无可分发构建、未做真人试玩、**文化合规未签字**（见 [docs/COMPLIANCE_CHECKLIST.md](docs/COMPLIANCE_CHECKLIST.md)）。
> - **用语红线**：合规签字前，对外一律称"民俗手艺题材"，**不使用"非遗"二字**。
> - **许可**：[MIT](LICENSE)。工程内不含任何第三方素材、真实照片、音频或传承人作品。
>
> 项目内部曾用名《守艺人·百工夜行》；「守艺人」为通用词且未做商标检索，故仓库标题使用工程名 `FirstXiXueGui`。

---

以下为**项目内部索引**（原本写给自己看的，保留原样以便追溯）。

> **数值口径看哪里（2026-10-30 对账）**：`docs/balance/` 整目录（`NUM_DESIGN.md` / `params.json` / `balance_model.py`）是 **v3.1 存档**，写的是 6 武器 × 8 级 + 7 被动的旧框架，**已不代表现行设计**。现行真值只有一处 —— 代码（`GameDemo/first-xi-xue-gui/scripts/WeaponDB.gd` / `EvolutionDB.gd` / `UpgradeDB.gd` / `Stats.gd`），并由 `tools/BalanceAudit.tscn` 与 `v7_result.json` 比对守门（差异 > ±3% 即红）。
>
> **想跑起来**：装 Godot **4.7.2**（本仓库不含引擎二进制，见 `.gitignore`），用编辑器打开 `GameDemo/first-xi-xue-gui/project.godot`，F5 运行。六套门禁的复现命令见 [`docs/design/v7-completion-and-release-plan.md` §9.8](docs/design/v7-completion-and-release-plan.md)。

## 目录结构

| 目录 | 内容 | 说明 |
|---|---|---|
| `GameDemo/` | Godot 4 游戏工程（`first-xi-xue-gui/`） | **独立工程，勿随意移动**；`_p1_backup/` `_p2_backup/` 为阶段回滚快照 |
| `docs/` | 策划与设计文档 | 全部 Markdown |
| `docs/theme/` | 题材策划（非遗换皮方向选型、实施方案、可行性评估） | |
| `docs/theme/craftkeepers/` | 《守艺人》题材细节：策划案、美术映射、动画方案、合规 | |
| `docs/balance/` | 数值平衡设计（`NUM_DESIGN.md` + `params.json` + 模型脚本） | **v3.1 存档**（6 武器 / 7 被动旧框架）。现行真值在代码，见顶部口径说明 |
| `docs/shaders/` | 视觉特效包说明（`fx-pack.md`）+ 两张对照图（`fx-preview.png` 战斗反馈 7 个 / `skill-preview.png` 技能向 5 个） | shader 本体在 `GameDemo/…/assets/shaders/fx/`，机器可读清单是该目录的 `fx_manifest.json` |
| `assets/` | 美术资产（现行产出） | |
| `assets/craftkeepers/` | 首版 SVG 71 张 + 生成器 + `manifest.json` + 预览 + Godot 光栅化校核工程 | 源库；**已部分接入** `GameDemo/…/assets/art_shouyiren/`（匠人立绘 5 / 摊位 5 + 牌楼戏台灯柱 / 敌人三帧 + 结壳 9 / `codex_bg` / `ui_seal` / `ui_wood_sign`），剩余未接的见文末 |
| `reports/` | 各阶段执行报告**压缩索引**（`EXECUTION_LOG.md`）| 原始逐份报告已移除，细节见 `MEMORY.md` |
| `tools/` | 外部工具（`godot.zip` = Godot 编辑器） | |

## 阅读顺序

1. `docs/core-gameplay-breakdown.md` — 原型玩法拆解（机制基线）
2. `docs/core-gameplay-roadmap.md` — 核心玩法完善步骤
3. `docs/theme/README.md` — 题材选型结论（推荐《守艺人·百工夜行》）
4. `docs/theme/craftkeepers/design.md` — 完整策划案
5. `docs/balance/NUM_DESIGN.md` — **v3.1 存档**（历史口径，可读方法与推导，不可当现行数值）；现行数值以代码为真值
6. `docs/theme/nonheritage-reskin-plan.md` — 换皮实施 5 阶段方案
7. `reports/EXECUTION_LOG.md` — 各阶段执行与验收压缩索引

## 路径约定

- 文档内路径一律以**项目根**为基准（如 `assets/craftkeepers/manifest.json`）。
- 文档互相链接使用**文档相对**路径（如 `craftkeepers/design.md`）。
- 新增文档用英文文件名 + 连字符，中文标题写在文件内。

## 整理前的旧路径映射

2026-10-27 做过一次目录重整，`reports/` 内报告保留原始路径写法，按此表换算：

| 旧路径 | 新路径 |
|---|---|
| `overview.md` | `docs/overview.md` |
| `吸血鬼幸存者核心玩法拆解.md` | `docs/core-gameplay-breakdown.md` |
| `核心玩法完善步骤.md` | `docs/core-gameplay-roadmap.md` |
| `题材策划/README.md` | `docs/theme/README.md` |
| `题材策划/非遗替换可行性评估.md` | `docs/theme/nonheritage-feasibility.md` |
| `题材策划/非遗换皮实施方案.md` | `docs/theme/nonheritage-reskin-plan.md` |
| `题材策划/守艺人_百工夜行/策划案.md` | `docs/theme/craftkeepers/design.md` |
| `题材策划/守艺人_百工夜行/美术资产映射.md` | `docs/theme/craftkeepers/art-mapping.md` |
| `题材策划/守艺人_百工夜行/动画实施方案.md` | `docs/theme/craftkeepers/animation-plan.md` |
| `题材策划/守艺人_百工夜行/非遗依据与合规.md` | `docs/theme/craftkeepers/compliance.md` |
| `题材策划/守艺人_百工夜行/美术资源/` | `assets/craftkeepers/` |
| `数值平衡设计/` | `docs/balance/` |
| `P1..P5_*.md`、`UI文案修正_执行报告.md`、`player-facing-implementation.md` | 已合并压缩为 `reports/EXECUTION_LOG.md` |
| `godot-editor/godot.zip` | `tools/godot.zip` |

## 视觉特效（shader）

`GameDemo/first-xi-xue-gui/assets/shaders/fx/` 下共 12 个 canvas_item 特效，统一通过 `scripts/ShaderFX.gd` 调用，不必自己管材质接管。

**战斗反馈 7 个**：受击闪、噪声溶解（出现/消失）、本体发光、光晕、扫光、受伤红边、法阵。

**技能表现 5 个**（`assets/shaders/fx/skill/`）：

| shader | 用途 |
|---|---|
| `slash_arc` | 挥砍弧光，遮罩式挂在现有弧光贴图上（不改画风） |
| `cast_burst` | 发动冲击环，扩散/收拢，可压成椭圆贴矩形判定 |
| `projectile_trail` | 弹道辉光尾 |
| `skill_rank_rim` | 技能等级外框，三档颜色+厚度+流动，余光可读 |
| `aura_field` | 领域能量场，命中 `beat()` 一跳 |

- 说明与调参速查：`docs/shaders/fx-pack.md`
- 机器可读清单（参数 / 默认值 / 互斥关系 / 坑点 / 来源）：`assets/shaders/fx/fx_manifest.json`
- 改完重渲对照图：
  `godot --path GameDemo/first-xi-xue-gui res://tools/FxSheet.tscn`（战斗反馈）
  `godot --path GameDemo/first-xi-xue-gui res://tools/SkillSheet.tscn`（技能向）

> 技能向 5 个 API 与 shader **已全部接线到武器与 UI**（`ShaderFX` 在 `scripts/` 下共 46 个调用点）：`slash` → 师刀横扫、`burst_ellipse` → 震吼/命中环、`set_trail` → 弹道拖尾、`set_rank` → HUD 武器等级框、`add_aura` → 护盾/领域。接入位置见 `fx-pack.md` §3.6~3.8，行为断言在 `tools/V6Fx.tscn`。

## P5 遗留项现状（2026-10-30 对账）

原「未完成的动作」三条**已全部闭环**，逐条给出代码落点，便于复核：

| P5 遗留项 | 状态 | 落点 |
|---|---|---|
| Boss 三档美术未接线 | **已完成**（T13 残面三现） | `Game.spawn_boss_visual(phase)` / `clear_boss_visual()` / `_update_boss_fx()`；三张 FX `boss_mask_glow` / `boss_lantern_drain` / `boss_warning_ring` 已登记 `Art.ALL_PATHS`，逐现加层（1/2/3 层），验收 `tools/V71Content.tscn` §[6]、截图 `shots/v71_boss_1~3.png` |
| 敌人走路帧未接 | **已完成**（T10） | `assets/art_shouyiren/enemies/` 12 张（3 杂兵 × 3 帧 + 3 结壳）；`Enemy` 走 `Art.ENEMY_FRAMES`，`ENEMY_FRAME_FPS = 7.0`、逐只相位错开、掉帧不快进；结壳直接换 `_shell` 图。300 同屏 P95 13.08 → 13.61~14.04ms（+4.7%） |
| 拖拽摇杆无视觉反馈 | **已完成** | `HUD._update_joystick()`：底盘跟随落点、摇杆头按 `offset.limit_length(JOY_MAX)` 位移，并按拖动幅度联动 alpha（0.45→0.95）与缩放（0.8→1.1） |

**现行待办**（不再维护在此处，避免二次漂移）：以 `docs/design/v7-completion-and-release-plan.md` §7 的 T1–T19 为唯一清单。截至本轮已完：T1 / T2 / T4 / T5 / T8 / T9 / T10 / T11 / T12 / T13 / **T14**；未做：T3（音频，明确跳过）、T6（构建，本机缺 4.7.2 导出模板，外部阻塞）、T15（清单已产出，等顾问签字）、T16–T19。

## 未接入的美术资产（剩余）

只有两项，且都是**故意不接**而非漏接：

| 资产 | 现状 | 原因 |
|---|---|---|
| `ui_paper_texture.svg` | 已拷入 `assets/art_shouyiren/ui/`，`Art.gd` **零引用** | 卡片底纹改用纯色 + 描边即可，叠纸纹在 720×1280 上有摩尔纹 |
| 12 面面具 | **文件不存在**（`ui/masks/` 目录未创建） | `art_assets_manifest.json` 标 `out_of_scope`；与角色选择功能重叠，等 T17 再产 |

其余全部已接入：`intro_01~03`（`IntroUI` 三页开场）、`codex_bg` / `ui_seal` / `ui_wood_sign`（图鉴）、`char_*` × 5（角色选择）、`stall_*` × 5 + 牌楼/戏台/灯柱（摊位置景）、`boss_mask_glow` / `boss_lantern_drain` / `boss_warning_ring`（残面三现）。
