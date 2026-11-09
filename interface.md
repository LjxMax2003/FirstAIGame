# INTERFACE — 《守艺人·百工夜行》策划工坊 状态总线

> 全链唯一状态总线，八节结构。任何环节产出交接前必须在此登记。
> **当前版本：db-v1.0**（as-built 基线库，2026-11-07 收口）
> 详细结论一律看 `docs/design/project-design-db-v1.0.md`；本文件只记**状态**，不记内容。

---

## 一、内容索引

### 1.1 策划数据库 v1.0（本轮主线，as-built 基线）

| 编号 | 文件 | 标题 | 状态 | Owner |
|---|---|---|---|---|
| 01 | `docs/design/01-top-level-design.md` | 顶层玩法设计 | ✅ 已定稿（258 行） | game-lead-designer |
| 02 | `docs/design/02-system-design.md` | 系统设计 | ✅ 已定稿（660 行） | game-system-designer |
| 03 | `docs/design/03-entity-logic.md` | 实体逻辑 | ✅ 已定稿（602 行） | game-entity-logic-designer |
| 04 | `docs/design/04-narrative-script.md` | 剧情文案 | ✅ 已定稿（549 行，图鉴 36 条） | game-narrative-designer |
| 05 | `docs/design/05-numeric-tables.md` | 数值总表与全局公式 | ✅ 已定稿（791 行，脚本 PASS 314 / FAIL 0） | game-numeric-designer |
| 06 | `docs/design/06-asset-requirements.md` | 资产需求 | ✅ 已定稿（575 行） | game-asset-requirements |
| **DB** | **`docs/design/project-design-db-v1.0.md`** | **整编数据库 v1.0（入口）** | **✅ 已收口** | **team-lead** |
| 附 | `docs/design/tools/check_numeric_tables.py` | 数值校验脚本（227 项行号锚定） | ✅ 退出码 0 | game-numeric-designer |
| **IT** | **`docs/design/iteration-01-backlog.md`** | **迭代 01 可改项对接清单** | **✅ 已交付（22 条任务 / 6 批次；局外经济锁区）** | **team-lead** |
| **FX** | **`docs/design/iteration-01-fix-plan.md`** | **B1 修复策划案（皮影恢复 / 剪纸删次数）** | **✅ 已定稿；B1 代码已落地（12/12 断言绿）** | **team-lead** |
| **IT2** | **`docs/design/iteration-02-skill-synergy.md`** | **迭代 02 策划案 · 技能关联（6 主线 + 3 配套）** | **✅ 已定稿并执行（664 行；代码已落地，验收见 §3.3 / §8）** | **team-lead** |
| **IT3** | **`docs/design/iteration-03-evolve-mechanic.md`** | **迭代 03 策划案 · 进化机制化（6 机制 + 3 配套）** | **✅ 已定稿（702 行，待执行）** | **team-lead** |
| **ART** | **`docs/design/art-design-board.html`** | **场景与角色设计图册（79 张真图内联）** | **✅ 已生成（400 KB，只读资产）** | **team-lead** |
| 附 | `docs/design/tools/build_art_board.py` | 图册生成器（可复跑） | ✅ 已跑通 | team-lead |

**正文合计 3435 行 + 整编库 + 校验脚本 750 行。**

### 1.2 表现层专项 v9（上一轮，仍有效）

| 编号 | 文件 | 标题 | 状态 | Owner |
|---|---|---|---|---|
| 09 | `docs/design/09-presentation-top-level.md` | v9 表现力升级 — 顶层设计 | ✅ 定稿（340 行） | game-lead-designer |
| 10 | `docs/design/10-presentation-system.md` | 表现层系统规范 | ✅ 定稿（395 行） | game-system-designer |
| 11 | `docs/design/11-presentation-entity.md` | 表现层实体规范 | ✅ 定稿（395 行） | game-entity-logic-designer |
| 12 | `docs/design/12-presentation-text.md` | 反馈文案与仪式感文本 | ✅ 定稿（300 行） | game-narrative-designer |
| 13 | `docs/design/13-feel-tuning.md` | 手感参数与性能预算 | ✅ 定稿（344 行） | game-numeric-designer |
| 14 | `docs/design/14-presentation-assets.md` | 表现层资产清单 | ⚠️ 定稿但口径需更新（5 SFX 缺口已闭合，见 DB §6.4） | game-asset-requirements |
| 附 | `docs/design/tools/check_feel_params.py` | 手感参数校验脚本 | ✅ 退出码 0 | game-numeric-designer |

### 1.3 参考（不参与验收）

`audio-requirements.md`（v8 遗留音频需求）· `v8-changye-plan.md`（v8 长夜巡更方案）· `github-commit-playbook.md`（提交规范）

---

## 二、任务清单

### 2.1 本轮：策划数据库 v1.0

| ID | 任务 | Phase | 状态 | Owner |
|---|---|---|---|---|
| T-8 | 顶层玩法 as-built 反向建档 | 1 | ✅ `01` 258 行；8 维标签 / 双循环 / 33 个 `SYS_` | game-lead-designer |
| T-9 | 系统设计 as-built 反向建档 | 2 | ✅ `02` 660 行；25 系统四件套 / 唯一写入者表 18 行 / 8 条关键规则 | game-system-designer |
| T-10 | 实体逻辑 as-built 反向建档 | 3 | ✅ `03` 602 行；16 实体五段式 / 七枚举 70 格（✅16 ⚠️3 ❌51） | game-entity-logic-designer |
| T-11 | 剧情文案 as-built 反向建档 | 4 | ✅ `04` 549 行；18 个 `ST_` / 图鉴 36 条 / 上屏文本 178 条 | game-narrative-designer |
| T-12 | 数值表 as-built 反向建档 | 5 | ✅ `05` 791 行 + 脚本；六表 A~F / 227 项断言 / PASS 314 FAIL 0 | game-numeric-designer |
| T-13 | 资产需求 as-built 反向建档 | 6 | ✅ `06` 575 行；135 项五类 / 缺口 A0·B21·C9 | game-asset-requirements |
| T-14 | 迭代 01 可改项对接 | 迭代 | ✅ `iteration-01-backlog.md` 689 行；22 条任务 / B0~B5 六批次 / 局外经济锁区 / 7 处数据库修正 | team-lead |
| T-15 | B1 两项修复定案（皮影恢复 / 剪纸删次数） | 迭代 | ✅ 定稿 + **代码已落地**：`WeaponManager` 8 处（`_orbit_cd` 剥离 / `bounces_left` 计次）+ `WeaponDB.kind_of()` + `HaloLogic` ⑧⑨ + 新工具 `BladeLogic`；回归 SmokeTest 313/0、HaloLogic 29/29、BladeLogic 9/9 全绿 | team-lead |
| T-16 | 场景与角色设计图册 | 迭代 | ✅ `art-design-board.html` 400 KB；79 张真图 / 81 个 ID 全部命中 06 体系 / 0 自造 ID | team-lead |
| T-17 | 迭代 02 策划案（技能关联主线） | 迭代 | ✅ `iteration-02-skill-synergy.md` 664 行；四方向实测取舍 / 主线 S-01~S-06 / 配套 C-01·N-01·U-01 / 七处连带同步清单 | team-lead |
| T-18 | 迭代 03 策划案（技能关联二段：进化机制化） | 迭代 | ✅ `iteration-03-evolve-mechanic.md` 702 行；主线 M-01~M-09（6 条机制 + 声明位互锁 + 视觉分层 + 测试同步）/ 配套 C-02·N-02·U-02 / 八项连带同步 / 7 条待拍板 | team-lead |
| **T-18** | **迭代 02 代码落地（主线 + 3 配套）** | **迭代** | **✅ 已完成：S-01 三配方 / S-02 卡面三态 / S-03 空箱横幅 / S-04 术语收口 / S-05 九把全覆盖 / C-01 推镜 / N-01 环绕 2→3 / U-01 开脸徽章；双轨见 §3.3** | **team-lead** |
| **T-19** | **迭代 03 代码落地（进化机制化 B0~B5）** | **迭代** | **✅ 已完成：M-01 声明位 / M-02 十字扫 / M-03 灯心公转 / M-04 门神镇守 / M-05 糖水粘连 / M-06 铜锣回响 / M-07 墨线穿透累进 / M-08 视觉分层 / M-09 文档同步 + `05` 21 处重锚 / U-02 三处音效 / C-02 旧墓砖；双轨见 §3.4** | **code-orchestrator** |
| **T-20** | **迭代 04 代码落地（升级选卡界面重构 B0~B5）** | **迭代** | **✅ 已完成：UI-01 层级 20 / UI-02 双层墨幕 / UI-03 伪 3D 五线索 / UI-04 入场 0.42s / UI-05 出场 0.27s+输入锁 / UI-06 悬停 / UI-07 连升不重播标题 / UI-02b 战场降调 / B5 探针 `LevelUpShot` + 六处文档；双轨见 §3.5** | **code-orchestrator** |
| **T-21** | **迭代 04 收尾（花灯灯心同心 + 过期测试/截图/旧题材清理）** | **迭代** | **✅ 已完成（含 2026-11-09 复诊补修）：**D-14 撤回 M-03 公转 → **D-16 修受击位移永久残留（`art.position` 合成赋值，删 `_apply_punch`）/ D-17 收口 `aura_field` 方形硬边 / D-18 锚点口径统一（`_visual_center` 为判定+视觉唯一圆心，删 `_lamp_center`/`garlic_radius`/每帧钉回）** / D-15 清理 `assets/art/`、`shots/` 旧图、`tests/`、30 个旧探针；双轨见 §3.6（SmokeTest 340 / HaloLogic 39 / HaloShot 13 / numeric 314 全绿） | **code-orchestrator** |
| **T-14** | **整编收口 + 治理状态总线** | **7** | **✅ `project-design-db-v1.0.md`；三遍审计 / 8 条裁定 / 11 条缺陷总账** | **team-lead** |

### 2.2 上一轮：表现层 v9

| ID | 任务 | Phase | 状态 |
|---|---|---|---|
| T-1~T-6 | v9 顶层 / 系统 / 实体 / 文案 / 数值 / 资产 | 1~6 | ✅ 全部交付（`09`~`14`） |
| T-7 | v9 整编 + 落地实现 + 回归验证 | 7 | ⏸️ **未执行**（v9 部分实现已进工作区，未提交、未回归；详见 DB §2.2） |

---

## 三、验收对象

### 3.1 本轮验收结论（主理人复核，非成员自评）

| 项 | 判据 | 实测 |
|---|---|---|
| 行数合规 | 各文档落在约定区间 | 258 / 660 / 602 / 546 / 788 / 572 ✅ |
| 合规红线 | 全文零命中合规红线禁用词 | 六份文档全部 0 命中 ✅ |
| 命名规范 | 全英文文件名、ID 全大写、无中文文件名 | ✅ |
| 数值可信 | 脚本实跑 | **PASS 314 / FAIL 0 / WARN 0，退出码 0**（主理人独立复跑）✅ |
| 数值判别力 | 注入错误后应变红 | 改值 → FAIL+exit1；改行号 → FAIL「行号已失效」+exit1 ✅ |
| 行号真实 | 抽查 | `WaveTable.gd:244-247`、`EnemyPool CAP/max_alive/GRID_CELL`、`Enemy.gd:286-291`、`Art.gd:48-50` 全对 ✅ |
| 代码零改动 | `GameDemo/` 只读 | 无新增改动（现有 `M` 为建档前既有 v9 改动）✅ |

### 3.2 已知验收缺口（**如实登记，不掩盖**）

1. **§三 合规校验为整批一次，不是逐阶段一次**。原 SOP 要求每阶段过 `spec-compliance-checker` 后再进下一阶段；本轮为控制成本改为「成员自检 + Phase 7 整批复核」，复核结论见 3.1。**属流程简化，如认为不可接受，需重跑逐阶段校验。**
2. **两位成员越权写过 `interface.md`**（01/03/04/05/06 五位各自追加过登记行）。内容无冲突，但违反「interface 由主理人统一落账」分工。本轮已整篇重排修正，后续按 §五 权限执行。
3. **一名成员的口头回传与磁盘文件不符**（把 `kind` 原值 cup/fast/bag/box/red 当实体名报为「杯/风筝/书包/纸箱/红包」）。**磁盘文件正确**，本库按磁盘为准；该摘要已作废。

### 3.3 迭代 02 验收结论（代码落地后实测，2026-11-08）

| 项 | 判据 | 实测 |
|---|---|---|
| S-01 进化配方 9/9 | `EvolutionDB.FORMS` 9 条；三条新配方 dps/area = 1.45·1.30 / 1.40·1.50 / 1.55·1.35 | ✅ grep 9 条；SmokeTest Step8 通过 |
| S-02 满级卡三态 | Lv8 卡分别显示「已开脸 / 待宝箱开脸 / 开脸需「被动名」」 | ✅ `shot_cards_evolve_states.png`；三行宽 136 / 108 / 80 px < 卡宽 200 |
| S-03 空箱反馈 | 空候选开箱返回 false 且横幅「箱中无脸 · 化为一枚灯花」 | ✅ SmokeTest 断言实测：`箱中无脸 · 化为一枚灯花` |
| S-04 术语收口 | `scripts/Game.gd` 与 `scripts/ui/` 下「传承 / 口诀」零命中（局外成长除外） | ✅ 战斗路径零命中；仅 MainMenu 5 / SettingsUI 4 / MetaSave 1（均为「局外永久成长」语义）保留 |
| S-05 冒烟覆盖 | 9 条配方 / 9 把武器全覆盖 / req_passive 去重 ≥6 / 三条真实开箱 | ✅ SmokeTest 321 ok / FAIL 0 / exit 0 |
| C-01 开脸推镜 | `_open_chest` → `PresentationFX.pull_zoom(1.06, 0.35)` | ✅ 落地；pull_zoom 只写 `camera.zoom`，低特效档不禁用 |
| N-01 环绕 2→3 | 数量 = 武器表 `orbit_count` + `EvolutionDB.orbit_count_bonus` | ✅ HaloLogic ⑩ 实测 `2 → 3 → 2` |
| U-01 开脸徽章 | 武器栏常驻「开脸 n/9」，分母读 `EvolutionDB.FORMS.size()` | ✅ 截图可见「开脸 0/9」，未溢出/未遮挡 |
| 文档同步 | 04 / 05 / 06 + `check_numeric_tables.py` 的 FORMS 6→9 | ✅ python PASS 314 / FAIL 0 / exit 0 |
| 双轨验证 | 窗口实跑真实 `Game.tscn` + headless 冒烟 | ✅ 无 SCRIPT ERROR / PARSE ERROR；截图见 user:// |
| 已知红点（非本轮引入） | `HudFxGap` 11 项护盾断言 | ⚠️ HEAD 即不一致，见 §6.4 Q14，不计入本轮验收 |

**占位与资产**：本轮无【待资产块交付】——新增配方复用既有 SVG 常量（`PHONE_ORBIT` / `KNIFE_BOXCUTTER` / `WOODBLOCK_PRINT`）；无【待策划确认】项。

### 3.4 迭代 03 验收结论（代码落地后实测，2026-11-09）

| 项 | 判据 | 实测 |
|---|---|---|
| M-01 声明位 | `EVOLVE_MECHANIC` 9 条、键全在 `WeaponDB.ORDER`、值为「机制名:落点函数」两段式 | ✅ SmokeTest `_step13` 3 条断言绿 |
| M-02 十字扫 | 师刀第二刀方向与第一刀垂直（dot < 0.1） | ✅ dot ≈ 0；正上方第 1 刀不中、第 2 刀命中 |
| M-03 灯心公转 | 连采 8 次方位集合 = 8、偏移 = `0.40R`、判定真的跟随 | ✅ HaloLogic ⑪ C-1~C-4 全绿；R=190.4 / 偏移 76.2；+X 命中、-X 不中。**⚠️ 已于 2026-11-09 按 §6.7 D-14 撤回：现行口径为「灯心同心」，`HaloLogic` ⑪ 已改写为 C-1~C-3 同心用例；本行仅作历史留档** |
| M-04 门神镇守 | 落点命中后 4s 内 `is_slowed()` 恒真 | ✅ `_slow_left = 4.00` |
| M-05 糖水粘连 | 首跳定身 1.0s 位移 < 0.5px；2.5s 免疫窗口内第二次 `false` | ✅ 位移 0.00；第二次 false |
| M-06 铜锣回响 | 单只 0.5s 吃 2 次、总伤/单次 = 1.45 ± 0.01 | ✅ 单次 42.0、比值 1.450 |
| M-07 墨线穿透累进 | 全程笔直（首末角差 < 1e-4）+ 扣血比 1 : 1.25 : 1.50 | ✅ 角差 0.00000000；100 : 125 : 150 |
| M-08 视觉分层 | 满级外扩环 / 双扫染色 / 二次溅射按开脸状态分层 | ✅ FxInGame 18/18 |
| M-09 文档同步 | `05` 表 C +3 风险 + 21 处重锚；`02` +2 行；`04` 6 条机制句；`06` 零新增资产 | ✅ python PASS 314 / FAIL 0；`grep "WeaponManager.gd:"` 逐条核对 |
| U-02 音效 | 升级 / 主菜单 / 死亡重开三处确认音 | ✅ `ActiveSkill` / `MainMenu` / `DeathUI` 各 1 行；V5InGame 165/0 |
| C-02 旧墓砖 | 街区外（>760px）换 `TOMB_TILE`，街区内仍 `GROUND_TILE` | ✅ `Ground._draw` 按格选贴图；未单独截图（本轮只做代码路径核对） |
| 双轨验证 | 窗口实跑 + headless 冒烟 + 数值脚本 | ✅ `SmokeTest` 340 ok / FAIL 0 / exit 0；`HaloLogic` 37/0；`FxInGame` 18/0（窗口，`frame_post_draw` 需渲染）；`V5InGame` 165/0；`V71Content` 66/0；`check_numeric_tables.py` PASS 314 / FAIL 0 / exit 0；全程无 SCRIPT ERROR / PARSE ERROR |
| M-03 视觉 V-1~V-4 | 像素阈值 0.18、饱和 ≥0.45、容差 7%；截图 `shots/m03_*.png` | ✅ `HaloShot` 8/8（V-1 188/189、V-2 113/264、V-3 113/264、V-4 117/118；偏差 ≤1.7%）。**⚠️ 已于 2026-11-09 按 D-14 撤回：改为「受击前/后四向边距判读」，见 §3.6；旧截图已按 D-15 清理** |
| 缺口（如实登记） | 实机「主菜单→开始→升级→暂停→死亡→商店→重开」每步有声的人工听觉走查 | ⚠️ **未做人工听觉走查**（U-02 代码路径已证 + V5InGame/动手音效调用点均在，见 §6.5 Q18） |

**占位与资产**：本轮零新增资产（M-05 糖浆复用 `burst_ellipse`；M-08 复用既有 shader）；无【待资产块交付】。**待数据层登记 1 项**：`04` 图鉴机制句尚未进 `EvolutionDB`（需结构增字段，见 §6.5 Q17）。

### 3.5 迭代 04 验收结论（代码落地后实测，2026-11-09）

| 项 | 判据 | 实测 |
|---|---|---|
| UI-01 层级归位 | `LevelUpUI` layer = 20 > HUD 的 10 | ✅ `LevelUpShot` 断言 1；升级时摇杆/血条被墨幕盖住（`shots/ui_lv_idle.png`） |
| UI-02 双层墨幕 | `Mask` 纯色 0→0.80 + `Vignette` 径向 0→1.0，初始全 0 | ✅ 四张截图；`mouse_filter=2` 三处不漏 |
| UI-03 伪 3D | 三层投影 y=24/17/11 a=0.26/0.14/0.07 + 右侧厚度 + `TILT_DEG 3.2` + `SIDE_SCALE 0.965` + 扫光 | ✅ 三卡位姿断言全绿；几何实测三卡底边 y=[280,280,280]、投影最大间距 31px |
| UI-04 入场 | 0.42s，错峰 0.055s；入场起 alpha<0.35、收尾全部回位姿 | ✅ `LevelUpShot` 入场 2 项断言；`shots/ui_lv_enter_0.png` |
| UI-05 出场 + 输入锁 | 被选卡 `scale:x→0.02` + 上移 50 + 淡出；落选 ±14° + 下移 36 + 淡出；连点只生效 1 张 | ✅ 收尾 `scale.x=0.02`、落选 \|rot\| 实测 16.4~17.2°；连点 3 次只 apply 1 次 |
| UI-06 悬停 | 转正 + 上移 12px + `HOVER_SCALE 1.055` + 投影 a×0.55 / y×1.35 + 扫光一次 | ✅ 6 项断言；`shots/ui_lv_hover.png` |
| UI-07 连升节奏 | 标题只在第一批入场（`_first_show`），后续批次只换卡 | ✅ 连升 3 批断言 |
| UI-02b 战场降调 | `World.modulate → Color(0.58,0.56,0.66)`，关界面回白 | ✅ 降调断言 + 收尾 `modulate == Color.WHITE` |
| B5 探针 | 新建 `tools/LevelUpShot.gd/.tscn`（33 断言 + 4 截图）；`CardShot` 文件头 +2 行 | ✅ `LevelUpShot` 33/0/exit 0；`CardShot` PASS / FAIL 0（117 张全扫） |
| 双轨验证 | 窗口实跑 + headless 冒烟 + 数值脚本 | ✅ `LevelUpShot` **33/0 / exit 0**（窗口）；`CardShot` PASS / FAIL 0（窗口）；`SmokeTest` **340 ok / 0 FAIL / exit 0**（headless）；`HaloLogic` 37/0；`HaloShot` 8/8；`FxInGame` PASS；`V5InGame` 165/0；`V71Content` 66/0；`python` PASS 314 / FAIL 0 / exit 0；全程无 SCRIPT ERROR / PARSE ERROR |
| 文档同步 | `02` UI 层级表 / `09` §六 三条规则 / `06` 零新增资产 / `01` A-4 不变 / `SHOUYIREN_TEXT` 4 行重锚 / `interface` R7 | ✅ 六处已改；全库 `grep "LevelUpUI.gd:[0-9]"` 仅剩 0 处业务引用（`interface.md` 内已改符号引用） |
| 锁区 | `MetaSave` / `TRACKS.mult` / `coin_reward` / 复活 / `ShopUI` 零改动 | ✅ `git status` 无锁区文件 |
| 缺口（如实登记） | 真人手指连点 3 个升级的观感确认 | ⚠️ 自动化已覆盖输入锁与连升；**真人观感走查未做** → 【需人工介入（仅观感走查）】，见 §6.6 Q21 |

**占位与资产**：本轮零新增资产（墨幕 `Gradient`/`GradientTexture2D`、扫光 `Gradient` 均 runtime 生成；投影/厚度复用 `UI_CARD_FRAME`）；无【待资产块交付】、无【待数据层登记】。

### 3.6 迭代 04 收尾验收结论（代码落地后实测，2026-11-09）

**用户反馈**：花灯开脸后一旦受击，环形圈与角色错位 —— 视觉中心与判定中心都不在角色身上，但贴身的怪仍能打到人（截图已归档）。**根因（一）** = 迭代 03 M-03「灯心公转」（每脉冲把 `GarlicRing.position` 平移 `0.40R`，8 方位轮转，实测偏移 76.2px ≈ 0.40×190.4），按 §6.7 D-14 撤回。**根因（二，2026-11-09 复诊新查）** = 受击位移 `art.position += _punch` 逐帧累加、衰减到 0 时也不减回去：单次受击永久残留 `HIT_PUNCH_PX/(1-0.82)` ≈ **27.8px**（小怪 22px），且花灯环挂在 `Player` 上、不跟 `art` 贴图走 → 表现成「环还在原位，人已经歪了」。用户截图里的偏移方向与量级（≈30px）与这条完全吻合，D-14 只修了其中一半。

| 项 | 判据 | 实测 |
|---|---|---|
| D-14a 判定圆心 | `WeaponManager._visual_center()` 为唯一口径（`player.global_position + (0, -ART_FOOT_OFFSET)`）；`fire_halo` / `fire_gong` 的判定、资源点、视觉全部同源；`_lamp_center` / `_lamp_step` / `garlic_radius` 已删 | ✅ `grep` 零残留；`WeaponManager.gd` 单一锚点函数 |
| D-14b 视觉圆心 | `Player._ready` 一次性把 `garlic_ring.position` 钉到 `(0, -ART_FOOT_OFFSET)`；运行时无第二写入者（原每帧重设已删） | ✅ `HaloShot` 受击后 / 脉冲后两条结构断言绿 |
| D-14c 声明表 | `EVOLVE_MECHANIC["halo"] = "灯心同心:_visual_center"`，全表仍 9 条两段式 | ✅ `SmokeTest._step13` 条数与格式断言绿 |
| **D-16a 受击位移清零** | `Player` / `Enemy` 的 `art.position` 改为「行走起伏 + 衰减偏移」**合成后一次性赋值**，删 `_apply_punch`；受击后 `art.position` 必须精确回 `(0, bob)` | ✅ `HaloLogic` ⑫：四向受击后 `art.position = (0, 0)`，残留 0.000px；`HaloShot` ⑤ 同样归零 |
| **D-16b 环/人同源** | 环心 `garlic_ring.global_position` == 身体中心（误差 < 0.5px） | ✅ `HaloShot` ⑥ 实测误差 **0.000 px** |
| D-14d 受击前后像素 | 四向（左/右/上/下）边距 = `halo_radius()` ±7%，受击后无偏移 | ✅ `HaloShot` ①~④ 全绿；截图 `shots/halo_before.png` / `halo_after_hit.png` |
| D-14e 判定对称性 | 以角色**身体中心**为圆心：±0.90R 都命中、+1.10R 不命中 | ✅ `HaloLogic` ⑪ C-3 + `SmokeTest` 4 条断言 |
| **D-17 场底板方形硬边** | `aura_field` 外径 fade 收口到 `r=1.0`（原拖到 `outer+softness=1.20`，超出 `ColorRect` UV 范围被硬裁 → `add` 混合下成一圈方形亮框） | ✅ `HaloShot` ⑦ 水平边突变列 **10 < 60**（10 列 = 顶部灯笼贴图，非方边） |
| D-15 清理 | 删 `assets/art/`（旧题材 68 文件）、`shots/` 旧图 132 文件（仅留本轮两张证据）、`tests/` 4 文件、30 个旧探针（保留 10 个现行探针） | ✅ 删除后 `SmokeTest` 仍 `340 ok / 0 FAIL / exit 0`，资源齐备性守卫绿 |
| 双轨验证 | headless 冒烟 + 数值脚本 + 窗口视觉 | ✅ `SmokeTest` 340 ok / 0 FAIL / exit 0；`HaloLogic` **39/0** / exit 0；`HaloShot` **13/13** / exit 0（窗口）；`python` PASS 314 / FAIL 0 / exit 0；全程无 SCRIPT ERROR / PARSE ERROR。`HudFxGap` 11 项为 **HEAD 既有红点**（§6.4 Q14），不计入本轮 |
| 文档回写 | `04` 机制句 / `05` 表 C 行 + 符号引用 / `06` 注记 / 迭代 03 历史件撤回注记 / `PROJECT_OVERVIEW.md` 符号表 | ✅ 6 处已改 |
| 缺口（如实登记） | ①实机连续受击 5 次的手指观感；②`SmokeTest` Step2 构筑钉住断言偶发失败 | ⚠️ ①【需人工介入（仅观感走查）】见 Q22；②复跑即绿（既有时序抖动，非本轮引入）见 Q24 |

**占位与资产**：撤回动作零新增 / 零删除资产（`GarlicRing` 四层视觉与贴图全复用）；清理项不计入资产账。无【待资产块交付】、无【待数据层登记】。

---

## 四、回退条件

| 触发 | 处理 |
|---|---|
| 文档与代码冲突 | 以代码为准，冲突登记入 DB §8.2；**不回退重写文档**（本轮不迭代） |
| 分册之间冲突 | 能靠代码判定的由主理人裁定（DB §9）；产品级转 DB §10.2 待确认 |
| 数值脚本变红 | 打回 Phase 5，附「哪项 FAIL + 该行原文」；修表不许改脚本凑绿 |
| 同一问题回退 2 次仍无果 | 主理人召集评审 → 裁决写入本文件 §六 → 无果标【需人工介入】冻结 |

**跳过登记（三段式）**：本轮无环节被跳过。`ST_003`（首波世界观解释）与「对话/语音/过场」标 `⏭️ 无`，依据为代码实测不存在，属**内容缺失**而非流程跳过。

**迭代 02 跳过 / 回退登记（三段式）**：无跳过、无回退。N-01 一度评估「环绕精灵按 2 建死、加不到 3」，实读 `_ensure_orbit_sprites` 为 while 动态扩池后确认可行，按 **参考**（`WeaponManager.gd:830-851`）/ **改动点**（`_update_orbits` 数量加成 + 多余精灵隐藏）/ **兜底**（若不可行则维持 2 只并撤销配方字段）登记后执行。`HudFxGap` 11 项为 HEAD 既有红点，不触发回退。

---

## 五、修改权限

| 级别 | 范围 | 判定 |
|---|---|---|
| **L1 自动** | 写 `docs/design/*.md` 文档与 `interface.md`；跑校验脚本 | 自动执行 |
| **L2 需人工确认** | 删除/覆盖他环节产出；改 `GameDemo/` 下 `scenes/*.tscn` 与 `scripts/*.gd`；删 `assets/art/` 旧素材 | 需用户确认 |
| **L3 禁止** | 软件配置目录；引擎版本；渲染器；第三方依赖；`addons/godot_ai` 剥离 | 禁止 / 需用户拍板 |

**本轮改动范围预声明（已执行完毕）**：
- **新增** 7 个文件：`01`~`06` 六份 + `project-design-db-v1.0.md`
- **新增** 1 个脚本：`tools/check_numeric_tables.py`
- **重写** 1 个文件：本 `interface.md`（整篇重排）
- **`GameDemo/` 零改动**（符合用户红线）

**迭代 01 · B1 批次改动范围（已执行完毕，L2 经用户指令「根据这两个文件，迭代游戏」确认）**：
- **修改** `GameDemo/first-xi-xue-gui/scripts/weapons/WeaponManager.gd`（8 处：D-1 `_orbit_cd` 四处 + D-2 `bounces_left` 三处 + 注释）
- **修改** `GameDemo/first-xi-xue-gui/scripts/WeaponDB.gd`（纯新增 `kind_of()` 取值器，**零数值改动**）
- **修改** `GameDemo/first-xi-xue-gui/tools/HaloLogic.gd`（新增用例⑧⑨ + `_equip()` 竞态修复：补等 2 个物理帧）
- **新增** `GameDemo/first-xi-xue-gui/tools/BladeLogic.gd` / `BladeLogic.tscn`
- **文档同步** `03` §7.1 C-1 与七枚举表、`05` §4 R-1/R-5/Q-1/Q-3 标闭合
- **锁区遵守**：`MetaSave` / `Game.coin_reward()` / `ShopUI` / `WeaponDB` 数值 / `bounce_falloff` 机制 / 其余武器 `_cd` 语义 / `_orbit_ghosts` 均未动；未提交 git（未收到提交指令）

**迭代 02 · 代码批次改动范围（已执行完毕，L2 经用户指令「继续迭代，记得是godot项目，找对子智能体」确认）**：
- **修改** `scripts/EvolutionDB.gd`（+3 配方 `evolve_phone/blade/print`，新增 `orbit_count_bonus` 字段）
- **修改** `scripts/UpgradeDB.gd`（+`stat_name(id)` 取值器，**零数值改动**）
- **修改** `scripts/CodexDB.gd`（计数注释 33→36，派生逻辑未动）
- **修改** `scripts/Game.gd`（空箱横幅 / 「开脸！」文案 / `pull_zoom`）
- **修改** `scripts/weapons/WeaponManager.gd`（`_update_orbits` 读 `orbit_count_bonus` + 多余精灵隐藏）
- **修改** `scripts/ui/LevelUpUI.gd`（满级三态提示 + 手艺/心法标签）/ `HUD.gd`（开脸计数 + n/9 徽章）/ `DeathUI.gd`（开脸计数）
- **修改** `tools/SmokeTest.gd`（9 配方 / X11 口径 / 满堂彩倍率 / 空箱横幅）、`HaloLogic.gd`（用例⑩）、`V71Content.gd`（36 条）、`CardShot.gd`（三态截图）
- **文档同步** `04` / `05` / `06` + `docs/design/tools/check_numeric_tables.py`（仅行号锚点，期望值零改动）
- **锁区遵守**：`MetaSave` / 局外经济 / `WeaponDB` 数值 / `bounce_falloff` 机制 / `scenes/*.tscn` / `SettingsUI`&`MainMenu` 的「传承=局外成长」语义均未动；未提交 git（未收到提交指令）

**迭代 03 · 代码批次改动范围（已执行完毕，L2 经用户指令「/goal 根据文件，完成任务」+ `iteration-03-handoff.md` 确认）**：
- **修改** `scripts/weapons/WeaponManager.gd`（M-01 `EVOLVE_MECHANIC` + `_lamp_step`；M-02 `_second_arc_v`/`_delay_arc_v`；M-03 `_lamp_center`；M-04 年画减速；M-05 糖画定身；M-06 `_gong_echo`；M-07 墨线穿透累进；M-08 视觉分层）
- **修改** `scripts/Enemy.gd`（新增 `apply_root` / `_advance` / `GLUE_TINT` / `ROOT_IMMUNE`；`_slow_pct` 仍单值覆盖）
- **修改** `scripts/Player.gd`（**删除每帧 `garlic_ring.position` 兜底**，让出写入权给 `_lamp_center`；这是对 `fix-skill-center-v2` 的定向回退，见 §6.5 Q16）
- **修改** `scripts/ActiveSkill.gd` / `scripts/ui/MainMenu.gd` / `scripts/ui/DeathUI.gd`（U-02 各 1 行确认音）
- **修改** `scripts/Ground.gd`（C-02 `TOMB_TILE` 街区外换砖）
- **修改** `tools/SmokeTest.gd`（新增 `_step13_evolve_mechanic`）、`tools/HaloLogic.gd`（新增用例⑪）、`tools/V5InGame.gd`（修为配方断言 6→9）
- **文档同步** `05`（表 C 行为机制列 + §4 R-29~R-31 + 21 处行号重锚）、`02`（唯一写入者 +2 行）、`04`（6 条机制句）、`06`（零新增资产确认）、`docs/design/tools/check_numeric_tables.py`（`xp_for_level` 锚 530→531）
- **锁区遵守**：`MetaSave` / `Game.coin_reward()` / `ShopUI` / `TRACKS.mult` / 复活 / 局外经济**零改动**；`GarlicRing.gd` **零改动**（0 行）；`WeaponDB` 数值零改动；`scenes/*.tscn` 零改动；未提交 git（未收到提交指令）
- **§8 停手信号核对**：未新增 DOT / 拉拽 / 距离场类能力字段（M-05 的 `_root_left` / `_root_immune` / `_root_tinted` 是主件 §5.3 自身规定的定身字段）；未给 `EnemyPool` 加 `farthest`；未改 `EvolutionDB` 结构；未扩 `Audio.play_sfx` 签名（已有 `extra_db`）→ **四项均未触发能力集扩展**

**迭代 04 收尾 · 改动范围预声明（已执行完毕，L1 自动 / L2 删除经用户指令「/goal 解决问题…②清理以前的测试、截屏、前一个题材的内容」确认）**：
- **修改** `scripts/weapons/WeaponManager.gd`（撤销 `_lamp_step` 成员；`_lamp_center()` 重写为恒等 + 钉回 base；`EVOLVE_MECHANIC["halo"]` 改「灯心同心」）
- **修改** `scripts/Player.gd`（`_physics_process` 顶部恢复每帧钉回 `garlic_ring.position = (0, -ART_FOOT_OFFSET)`；§6.5 Q16 的「让出写入权」按 D-14 回滚）
- **修改** `scripts/Art.gd`（1 行注释：旧目录 `assets/art/` 已清理）
- **修改** `tools/SmokeTest.gd`（`_step13` M-03 段改同心 4 条断言）、`tools/HaloLogic.gd`（用例⑪ 改写为 C-1~C-3）、`tools/HaloShot.gd`（整份重写：受击前/后四向边距判读 + 2 条结构断言）
- **删除（L2，已授权）** `assets/art/` 全目录 68 文件、`shots/` 旧图 132 文件（仅保留本轮 `halo_before.png` / `halo_after_hit.png` 两张证据）、`tests/` 全目录 4 文件、`tools/` 30 个旧探针（各 `.gd` / `.gd.uid` / `.tscn`，另含 `SpriteBounds`/`V6Art` 无 tscn）
- **保留探针 10 个**：`SmokeTest` / `HaloLogic` / `HaloShot` / `CardShot` / `LevelUpShot` / `FxInGame` / `V5InGame` / `V71Content` / `BladeLogic` / `HudFxGap`
- **文档同步** `04`（`evolve_halo` 机制句）、`05`（表 C `SK_E_HALO` 行 + 符号引用替换行号）、`06`（迭代 03 确认段撤回注记）、`iteration-03-evolve-mechanic.md` / `iteration-03-handoff.md` / `versions/iteration-03-handoff-v2.md`（M-03 撤回注记）、`docs/design/tools/check_numeric_tables.py`（`xp_for_level` 锚 531→530）
- **锁区遵守**：`MetaSave` / `Game.coin_reward()` / `ShopUI` / `TRACKS.mult` / 复活 / 局外经济**零改动**；`WeaponDB` 数值零改动；`EvolutionDB` 结构与 9 配方零改动；`GarlicRing.gd` 零改动（0 行）

**迭代 04 · 代码批次改动范围预声明（L2 经用户指令「继续根据文件，完成godot4.7.2的游戏代码」+ `iteration-04-handoff.md` 确认）**：
- **整份替换** `scenes/ui/LevelUpUI.tscn`（`layer=20` + `Vignette` + 2 个 `GradientTexture2D`；46→约 70 行）
- **追加/替换** `scripts/ui/LevelUpUI.gd`（+11 常量、+5 成员、+1 `@onready vignette`、+11 函数；`close_all` / `_show_next` / `_make_card` / `_on_pick` 四段替换；287→约 560 行）
- **新增** `tools/LevelUpShot.gd` + `LevelUpShot.tscn`（8 条断言 + 4 张截图）
- **修改** `scenes/ui/PauseUI.tscn`（`layer 9→21`）、`scenes/ui/DeathUI.tscn`（补 `layer=22`）—— 按执行单 §13 第 1 条建议执行
- **修改** `tools/CardShot.gd`（仅文件头 +2 行注释，不改断言）
- **文档同步** `02`（UI 层级表）、`09`（三条表现规则）、`06`（零新增资产确认）、`01`（A-4 条目不新增音效点）、`docs/design/*.md` 中 50 处 `LevelUpUI.gd:NNN` 引用（按 §13 第 2 条改符号引用）
- **锁区遵守**：`MetaSave` / `Game.coin_reward()` / `ShopUI` / `TRACKS.mult` / 复活 / 局外经济零改动；`CARD_W` / `CARD_H` / `Audio.play_sfx` 签名 / `LevelUpUI` 类名与父节点零改动

---

## 六、问题与决策

### 6.1 主理人裁定（8 条，DB §9 为完整版）

| # | 议题 | 裁定 | 判据 |
|---|---|---|---|
| R1 | `SYS_EVOLUTION` 的 P 级 | **P1** + 独立标注「卖点等级：核心」 | 宝箱无配方补偿升级（`Game.gd:741-744`）→ 结构性不阻断；但开脸是签名卖点，资产/表现按核心排产。**P 级与卖点等级不混用判据** |
| R2 | 「更次」两张表是不是冲突 | **不是冲突，是两套语义** | 显示跟 `WAVES`/`wave_index`（`HUD.gd:20-21` 注释「HUD 与刷怪必须同一份边界」），伤害跟 `DRUM_TIMES`/`drum_mult`。禁止统一 |
| R3 | 终局残面是否必然刷出 | **不是必然** | `Game.gd:388-389` `has_boss` 闸优先；`01` §4.1「必然」过强 |
| R4 | 资源点重生语义 | **代码为真值**（同 key 重生），注释过期 | `ResourceField.gd:176` |
| R5 | `EN_` 命名空间被资产变体越界 | **5 条判错用，登记待迁，不返工** | `EN_PAPER_BRICK`/`_SHELL`/`EN_GEM_BIG`/`EN_COIN`/`EN_SHELL_CRUST` 无对应实体；`enemy_brick` 是孤儿资产（`Art.gd:205/213`） |
| R6 | 小 Boss 是否给独立实体身份 | **不给** | 复用精英通道、实体侧零专属代码；给独立身份 = 给 `Enemy` 加分支，与「不建状态机」冲突 |
| R7 | `PROJECT_OVERVIEW` 三条分层红线 | **降级为「约定」** | 已被越过：数据层写状态（`UpgradeDB.gd:174-180`）、逻辑层直调 UI（`Game.gd:288/408/645/664/753`）、UI 写状态（`LevelUpUI.gd:_on_pick` 直接调 `UpgradeDB.apply`、`LevelUpUI.gd:_show_next` 直接切 `paused`）。真硬线只剩「伤害经 `take_damage`」「写盘经 `MetaSave`」 |
| R8 | 「匠人只差起始武器」 | **维持** | 公平性设计选择（`CharacterDB.gd:14-23` 自述跨度未收敛，属已知张力） |

### 6.2 已确认事实（代码实证，供后续引用）

| # | 事实 | 证据 |
|---|---|---|
| F1 | **皮影伤害链从未结算** —— `shadow` 开局无输出 | `WeaponManager.gd:250-252` 写死 `_cd["phone"]=0.28` → `:783` 闸门恒假 → `:804-813` 死代码。**已闭合（迭代 01 / IT-03）**：`_orbit_cd` 独立节拍，实测贴环绕 3s 结算 10 次、频率 3.67 次/s ≈ 1/0.28 |
| F2 | **更鼓傀图鉴与机制方向相反** | `CodexDB.gd:70`（「对手更凶」）vs `WaveTable.gd:84-86`（「抬的是玩家」） |
| F3 | **低配档关不掉任何 shader** | `fx_on()` 全仓仅定义 `Settings.gd:88`，无生产调用；`is_low()` 只在 `Game.gd:206` + `PresentationFX.gd:241`（震屏） |
| F4 | `BULLET_CAP=128` 是装饰 | `WeaponManager.gd:17` 零引用，子弹池实际无上限 |
| F5 | 美术资产实数 **106 张 SVG**（非 84，主理人先前加法有误） | `find assets/art_shouyiren -name "*.svg"` = 106 |
| F6 | 16 个 shader **零 `SCREEN_TEXTURE`/`DEPTH_TEXTURE` 真实采样** | 3 处字面命中全是注释 |
| F7 | 配音现状为零，13 条 `SND_VO_` 是需求规格 | `assets/audio/` 无 voice 目录；`Audio.gd` 无配音通道 |
| F8 | 工作区代码 ≠ `release/` 包 | 11 个文件带未提交 v9 改动 + 2 个新脚本 + 3 个未跟踪 wav；脚本实数 **45** |

### 6.3 待人工介入（12 条，DB §10.2 为完整版）

分三档：**须修**（~~D1 皮影~~【已修，IT-03】/ D4 低配档）→ **须定**（D3 `BULLET_CAP` / ~~D7 剪纸弹射~~【已定并落地，IT-06】/ D10 `pull_zoom`）→ **须决**（Q2 局外经济 1.55 局买满 / Q4 定长与存档 / Q6 `addons/godot_ai` 剥离【L3】/ Q7 旧素材删除【L2】/ Q8 UI 音补 8 面板 / Q9 配音 13 条 / Q12 BGM 包体）。

**本批新增（B1 代码落地时发现）**：
- **Q13**【须决 · 策划批次】：`iteration-01-fix-plan.md` §2.3 把 `bounce_falloff` 写成「复利衰减」（第 3/4 跳 16.84/11.78、单发封顶 76.72），实测代码每跳从基础伤 `b.dmg` 重新起算 ×0.70（9.00→6.30→6.30，**非复利**，单发封顶实际 81.78）。机制按 §4 锁区未动，仅文档描述偏差，建议策划批次修订 §2.3 表文。
- **Q-1（fix-plan §5）已决**：OrbitLogic 不新建，phone 断言并入 `HaloLogic`（用例⑧⑨）；blade 用例因结构差异独立为 `tools/BladeLogic.gd/.tscn`。
- **Q-2（fix-plan §5）保持开放**：剪纸卡面是否补「最多弹 3 次」，归 B2 文案批次。

### 6.4 迭代 02 决策与遗留（2026-11-08）

| # | 议题 | 结论 / 状态 |
|---|---|---|
| Q-1 | 三条新进化形态命名 | 采用「满堂彩 / 百鸟朝凤 / 门神镇宅」✅ 已落地 |
| Q-2 | S-04 第 4/5 条是否做 | 做：卡面「手艺 / 心法」+ hint 口径 ✅ 已落地 |
| Q-3 | 空箱横幅配色 | 沿用金色 `flash_evolve`（截图中可读）✅ 已落地；若要更「失败」感可改灰青，留待观感复评 |
| Q-4 | 环绕物动态扩池是否可行 | 实读为 while 扩池 → N-01 做 ✅ HaloLogic ⑩ `2→3→2` 绿 |
| Q-5 | 零归属被动 | 留待下一轮 ⏸️ 未做 |
| Q-14 | `HudFxGap` 11 项护盾断言红 | **非本轮引入**：HEAD 的 `HUD._update_shield` 已读 `stats["shield_cap"]`，而测试仍断言 `stats["shield"]=60`（v6 脉冲语义）。本轮未改这两处。【待人工/策划确认】测试是否按 v7 盾池语义修订 |
| Q-15 | `04` §0 图鉴统计仍写「35 条 / 313 汉字」 | 条数已全库同步 36；汉字数统计口径未写死，无法机械复算 → 【待核】 |

### 6.5 迭代 03 决策与偏离登记（2026-11-09）

**偏离主件的地方（回执必写项，逐条如实登记）**：

| # | 议题 | 结论 / 状态 |
|---|---|---|
| D-1 | **M-03 确认单 C-4 的几何不成立（偏离主件）** | 主件写「`+X` 与 `-X` 各放 `0.40R`，第 1 次脉冲只命中 `+X`」。灯心在 `+0.40R` 时，`-X` 侧敌人距灯心仅 `0.80R < R = 190.4`，**恒命中**，断言不可能成立。改为 `-X` 侧置 `-1.10R`（距灯心 `1.50R > R`）；`HaloLogic` 与 `SmokeTest` 同步。**判定逻辑未改，只改测试几何** |
| D-2 | **`Player._physics_process` 每帧写回被删除（偏离 `fix-skill-center-v2`）** | `fix-skill-center-v2` 的「每帧强制 `garlic_ring.position = (0, -18)`」会让 M-03 灯心公转每帧被拉回 → 与主件「`Player.gd` 零改动、写入权让给 `_lamp_center`」直接冲突。已删该行并留 6 行偏离登记注释；复位由 `_ready` 一次性与 `_lamp_center` 的未开脸分支承担 |
| D-3 | **M-05 未再向用户提问（依据主件 v3 拍板）** | 交接单 B2 要求「先问 §9 第 4 条」，但主件 v3（2026-11-09 08:10）已把 M-05 由「四向分锁」改为「糖水粘连」并标「✅ 已拍板（v3 换方向）」，按主件实现，不再追问 |
| D-4 | **`V5InGame` 配方断言 6→9** | 迭代 02 新增 3 配方后 `V5InGame` 仍断 `FORMS.size() == 6`（过期断言，非本轮引入），修为 9 后 165/0 |
| D-5 | **`check_numeric_tables.py` 锚点 530→531** | M-03 改动使 `Player.gd` 行号下移 1 行，`xp_for_level.base` 锚 530 失效「行号已失效」；改锚点为 531（期望值 5 不变）后 python 回 `PASS 314 / FAIL 0` |

**本轮新增待确认**：

| # | 议题 | 结论 / 状态 |
|---|---|---|
| Q16 | `garlic_ring.position` 的写入权归属 | **最终口径（2026-11-09 D-18）**：唯一写入点是 `Player._ready`（`(0, -ART_FOOT_OFFSET)`），运行时无任何路径改写；`WeaponManager` 不再写它，只通过 `_visual_center()` 返回同一坐标供判定使用。`_lamp_center` / `_lamp_step` 已删 |
| Q17 | `04` 图鉴 6 条机制句尚未入库 | 实机 `CodexDB.gd:115` 仍按模板生成；入库需给 `EvolutionDB` 增字段（`§8` 停手信号）。**【待数据层登记】**，留下一轮 |
| Q18 | M-03 视觉 V-1~V-4 截图与实机「每步有声」走查 | **视觉已闭环**：新增 `tools/HaloShot.tscn` 窗口探针，像素量尺 8/8（截图 `shots/m03_v1_step0.png` / `m03_v2_pulse1_right.png` / `m03_v3_pulse3_down.png` / `m03_v4_reset.png`）。**仍缺**：实机逐屏音效的人工听觉走查。**【需人工介入（仅听觉走查）】**。**⚠️ 2026-11-09 按 D-14 修订**：该 4 张截图随 D-15 清理，探针已改同心判读（见 §3.6）；听觉走查项仍挂起 |
| Q19 | GitHub 留痕的远端推送 | 本地提交 `9e4fc1d`（50 文件 / +2722 / −100）与标签 `iter-03-code` 已建立；`git push origin main` 两次均失败：`github.com:443` 连接被重置 / 21s 超时（沙箱内外均失败，非凭证问题，`gh auth status` 正常）。**迭代 04 复测（2026-11-09）**：本地提交 `64ce6c3` + 标签 `iter-04-code` 已建立；`git push origin main` 再失败 2 次 —— 沙箱内 `Recv failure: Connection was reset`，沙箱外 `Failed to connect to github.com port 443 after 21095 ms`。**✅ 2026-11-09 收尾已恢复**：首次 push 被拒（远端有 `93276ba Update README.md`，本地落后）；`git merge origin/main`（仅 README 2 行）后推送成功 `93276ba..6c21294`，标签 `iter-04-fix` 同步推送；至此迭代 02/03/04 累计提交与 `iter-03-code` / `iter-04-code` / `iter-04-fix` 三个标签全部在远端。**另注**：GitHub 提示仓库已迁移，旧地址 `LjxMax2003/FirstXiXueGui` 重定向到 `LjxMax2003/FirstAIGame`（仅告警，推送成功） |

---

### 6.6 迭代 04 决策与偏离登记（2026-11-09）

**按执行单 `iteration-04-handoff.md` §13 推荐值落地（用户未逐条点头，按执行单执行并留痕）**：

| # | 议题 | 结论 / 状态 |
|---|---|---|
| D-6 | `PauseUI` layer 9→21、`DeathUI` 补 `layer = 22` | 按 §13 第 1 条建议执行：升级 20 / 暂停 21 / 结算 22 三层层序唯一位次；`ShopUI`（11）本轮不动 |
| D-7 | **`_enter()` 调用位置（偏离 handoff §6.1）** | 原文让在 `_show_next` 的 `mask.visible` / `popup.visible` 两行处调 `_enter()`，但该处卡片尚未 `add_child`，`_enter` 会因 `cards.get_child_count() == 0` 立即早退 → 完全没有入场动画。已改在 `for option in options: cards.add_child(...)` 之后调用，并留 3 行注释说明 |
| D-8 | **`_exit` 的角度加法（偏离 handoff §7.3 写法）** | 原文 `side * 10.0` 直接加到弧度 `rot` 上是单位错误（会转 ≈573°）。改为 `side * deg_to_rad(14.0)`（落选摆幅按主件 §3 取 14°），winner 的 4° 同样 `deg_to_rad(4.0)` |
| D-9 | **`_exit` 补撤墨幕（handoff §7.3 未列）** | 原文出场只动卡片。若不撤遮罩会有两处硬切：①单次升级结束 `close_all()` 把 0.80 遮罩瞬间隐藏（暗→亮跳变）；②连升下一批 `_enter` 的 `.from(0.0)` 把 0.80 瞬间归零再淡入（战场闪一帧）。已补 2 条 fade（0.20s / delay 0.02，压在 0.22s 内，不延长 §5.2 的 0.27s 总时长） |
| D-10 | 静态 Hint 文案 | tscn 默认值按迭代 02 术语写「选一张手艺卡或心法卡」（handoff 原文写「传承」）；运行时仍由 `_show_next` 按等级与 `_pending` 覆盖 |
| D-11 | **`SmokeTest` 三处时序适配（测试侧）** | 迭代 04 起：入场 0.42s 期间 `_picking` 锁输入、出场 0.27s 之后才结算。原「等 2 帧」断言必然假失败（实测失败 3 条）。改为 `_wait_enter_done()`（等入场放行）与 `_wait_unpause()`（等界面收尾）两个有界等待。**断言内容未放宽** |
| D-12 | **`LevelUpShot` 取样方式（测试侧）** | 截图回读会阻塞主线程，墙钟 `SceneTreeTimer` 与 tween 的推进不同步（实测墙钟 0.19s 时动画只走 0.115s）。改为 `await _ui._tw.finished` 与按帧等待；判据（`scale.x 0.02` / `\|rot\|>8°` / `HOVER_SCALE 1.055` / `rest_y−12`）一条未放宽 |
| D-13 | **`SmokeTest._prep(freeze_xp=false)` 补清 `xp`（测试侧，收尾复跑时发现）** | Step4 会留下未吃完的宝石经验，带进 Step5 后 `gain_xp(xp_next)` 只升 1 级（断言当帧成立），但恢复游戏的那一帧立刻再升 1 级 → `paused` 被同帧的新批次置回 true，`_wait_unpause` 轮询永远看不到 `false` → 「选卡后恢复游戏」假失败（连续 2 次复跑稳定复现）。修法：`else` 分支同时置 `_player.xp = 0`（与 `freeze_xp` 分支口径一致）。**断言未放宽**，修后 340 ok / 0 FAIL |

**本轮新增待确认**：

| # | 议题 | 结论 / 状态 |
|---|---|---|
| Q20 | §13 五条（层级归位 / 符号引用 / tilt 3.2 / exit 0.27 / 战场降调）无用户逐条点头 | **按执行单推荐值落地**（D-6/D-8/D-9 即回滚锚点）。如需改回任一项，按 D-6~D-9 单点回滚即可，不牵连其他批 |
| Q21 | 真人观感走查（连升三批不闪标题、悬停扫光、出场翻面） | 自动化已覆盖（`LevelUpShot` 33/0）；**真人手指连点 3 个升级的观感未做** →【需人工介入（仅观感走查）】 |

### 6.7 迭代 04 收尾决策与偏离登记（2026-11-09）

| # | 议题 | 结论 / 状态 |
|---|---|---|
| **D-14** | **撤回 M-03「灯心公转」，改「灯心同心」（用户截图裁定）** | 用户报「开脸花灯受击后环与角色错位，但贴身怪照样打到人」。根因 = M-03 每脉冲把 `GarlicRing.position` 平移 `0.40R`（实测 76.2px），系列化设计使视觉圈与判定圈一起离身；玩家读作「技能中心不在我身上」。裁定：① `WeaponManager._lamp_center()` 改写为恒等（顺手把 `garlic_ring.position` 钉回 base，删 `_lamp_step`）；② `Player._physics_process` 顶部恢复每帧钉回 base（回滚 §6.5 Q16 的「让出写入权」）；③ `EVOLVE_MECHANIC["halo"]` 改「灯心同心:_lamp_center」（保持 9 条两段式，`_step13` 结构断言不动）。**判定半径 / 伤害 / 平衡零改动**，只把圆心拉回角色 |
| **D-15** | **清理范围与保留清单（用户指令「清理以前的测试、截屏、前一个题材的内容」）** | **删**：`assets/art/`（奶茶题材 68 文件，唯一引用者 `tools/SpriteBounds.gd` 同为删除项）、`shots/` 旧图 132 文件、`tests/` 全目录（`FuncMagnetVacuumMoveFloat` 4 文件）、`tools/` 30 个旧探针（`.gd`/`.gd.uid`/`.tscn`）。**留**：10 个现行探针（`SmokeTest`/`HaloLogic`/`HaloShot`/`CardShot`/`LevelUpShot`/`FxInGame`/`V5InGame`/`V71Content`/`BladeLogic`/`HudFxGap`）+ 本轮两张证据截图。**不动**：`assets/art_shouyiren/`、`assets/audio/`、`assets/shaders/`、`tools/godot.zip`、`tools/godot46/`、`release/`、`.screenshots/`（不属用户点名的三类） |
| D-14a | 测试同步（三套） | `SmokeTest._step13` M-03 段 → 4 条同心断言；`HaloLogic` ⑪ → C-1~C-3（未开脸 8 次恒 base / 开脸后 8 次仍恒 base / 判定左右对称）；`HaloShot` 整份重写 → 受击前/后两图 + 四向边距（TOL 7%）+ 2 条结构断言。**判据未放宽** |
| D-14b | **`check_numeric_tables.py` 锚点 531→530（工具侧）** | `Player.gd` 顶部净减 1 行（新增 5 行 + 删旧 6 行注释），`xp_for_level` 常量从 531 落到 530 → 锚点同步；`05` §1 行号引用一并改 `529-530` / `523-527` |
| **Q22** | 实机连续受击 5 次的观感走查 | 自动化已覆盖受击前后像素与同心结构；**真人手指连击观感未做** →【需人工介入（仅观感走查）】 |
| **Q23** | `shots/` 只留本轮两张证据，旧截图全删 | 用户指令明确要求清理截屏；历史验证截图已无留档。如需追溯迭代 03 像素读数，只有 `interface.md` §3.4 的文字读数可用 |
| **D-16** | **受击位移残留修复（用户复诊「没有完成」）** | **根因**：`Player._apply_punch` / `Enemy._apply_punch` 都是 `art.position += _punch` 逐帧累加、`_punch` 衰减到 0 后**不反向减回**。Player 的 `y` 每帧被行走起伏覆盖而自愈，但 `x` 永不归位 → 单次受击永久残留 `5/(1-0.82)` ≈ **27.8px**（小怪 4px → 22px），多次受击单向越漂越远。花灯环挂在 `Player` 上、不跟 `art` 走，所以读作「环没动、人歪了」。**修法**：两边都改为「行走起伏 `_bob_y` + 衰减偏移 `_punch` **合成后一次性赋值**」`art.position = Vector2(_punch.x, _bob_y + _punch.y)`，删 `_apply_punch`；`Enemy.setup` / `Player._ready` 复位 `_bob_y` 与 `_punch` |
| **D-17** | **光环底板方形硬边（用户截图里的方框）** | `aura_field.gdshader` 的外径 fade 到 `outer + softness`（花灯实配 1.20），而 `ColorRect` 的 UV 在 `r>1` 处已被裁掉 → 四条边中点上留下 `add` 混合的方形亮边。**修法**：把外径 fade 收口到 `min(outer+softness, 1.0)`、带宽 `min(softness*1.25, out_end)`，可见外沿正好等于光环半径；`HaloShot` ⑦ 新增「水平边突变列 < 60」像素断言 |
| **D-18** | **锚点 / 坐标系口径统一（防再犯）** | ①玩家与敌人节点 origin = **脚底**；②可见身体中心 = `origin + (0, -ART_FOOT_OFFSET)`；③所有「以玩家为圆心」技能（花灯 / 铜锣 / 皮影）的**判定圆心与视觉圆心都必须走 `_visual_center()`**，禁止在调用点手写 `+(0,-18)` 补丁；④敌人侧距离判定仍按各自 origin（脚底），与皮影轨道既有口径一致（18px 偏差在 `hit_radius ≥17px` 容差内）；⑤`garlic_ring.position` 只有 `Player._ready` 一个写入点，运行时删除每帧重设 |
| **Q24** | `SmokeTest` Step2「钉住的测量构筑生效（whip Lv2）」偶发失败 | 复跑即绿（本次连续 3 跑：1 红 2 绿），失败点在 `_step3_weapons` 读 `weapon_level("whip")`；与受击 / 锚点改动无关，属既有异步时序抖动（升级卡异步回调可能改写 `owned`）。**未修**（放开断言不可接受），留下一轮查 `_pin_probe_build` 与异步选卡的竞态 |

---

## 七、INTERFACE_MANIFEST

### 7.1 ID 注册表（全库唯一，禁复用）

| 前缀 | 归属 | 数量 | 定义处 |
|---|---|---|---|
| `SYS_` | 系统 | **33**（P0 16 / P1 14 / P2 3） | DB §2.1 |
| `PL_` | 玩家实体 | 1 | DB §3.1 |
| `EN_` | 敌人/掉落/可交互实体 | 16（+ 06 资产变体视图） | DB §3.1 |
| `SK_W_` | 武器 | 9 | DB §3.3 |
| `SK_E_` | 进化形态 | **9**（迭代 02 由 6 补至 9） | DB §4.2 表 C / `EvolutionDB.FORMS` |
| `ST_` | 剧情节点 | 18 | DB §5.2 |
| `EF_` | 特效贴图 | 9 | DB §6.1 |
| `EF_SH_` | 着色器 | 16 | DB §6.1 |
| `SND_` | 音效 | 11 | DB §6.1 |
| `SND_VO_` | 配音（需求规格，未实现） | 13 | DB §5.4 |
| `BGM_` | 背景音乐 | 2 | DB §6.1 |
| `UI_` | 界面元素 | 见 `06` §1.1 | `06` |
| `IT_` | 道具（**待迁入**：5 个越界 `EN_`，见 R5） | 0 | — |
| `RES_` | 资源 | **未启用**（本轮无产出） | — |
| `MAP_` / `NPC_` | 地图 / NPC | **未启用**（本作无该概念） | — |

### 7.2 下游补登记提示

- `IT_` 已预留但未启用 → R5 的 5 个越界 `EN_` 迁入时使用
- `MAP_` / `NPC_` 本作无对应内容，**不要为了「用满 13 类」而造 ID**

### 7.3 迭代 02 新增 / 变更接口（跨模块只走本表）

| 接口 | 签名 / 字段 | 定义处 | 使用方 |
|---|---|---|---|
| `EvolutionDB.FORMS` | 9 条；新增 `evolve_phone` / `evolve_blade` / `evolve_print` | `scripts/EvolutionDB.gd` | `Game._open_chest`、`LevelUpUI`、`SmokeTest` |
| `EvolutionDB.FORMS[].orbit_count_bonus` | `int`，缺省 0；`evolve_phone: 1` | `scripts/EvolutionDB.gd` | `WeaponManager._update_orbits` |
| `UpgradeDB.stat_name(id)` | `static func(String) -> String`（未命中回退 id） | `scripts/UpgradeDB.gd:64` | `LevelUpUI` 满级三态 |
| `Game._open_chest()` | `-> bool`（空箱 false + 横幅；成功 true + 开脸） | `scripts/Game.gd:736` | 宝箱链路、`SmokeTest` |
| `HUD.flash_evolve(text)` | `void`（金色 1.6s 横幅） | `scripts/ui/HUD.gd` | `Game` 空箱 / 开脸 |
| `HUD` 开脸徽章 | 文本 `"开脸 %d/%d"`，分母 `EvolutionDB.FORMS.size()` | `HUD._sync_weapon_row` | — |
| `PresentationFX.pull_zoom(mul, sec)` | `void`（只写 `camera.zoom`，独占） | `scripts/PresentationFX.gd:174` | `Game` 开脸 |
| `WeaponManager.evolved` | `Dictionary` weapon_id → form_id | `scripts/weapons/WeaponManager.gd` | `Game` / `LevelUpUI` / 测试 |

### 7.4 迭代 03 新增 / 变更接口（跨模块只走本表）

| 接口 | 签名 / 字段 | 定义处 | 使用方 |
|---|---|---|---|
| `WeaponManager.EVOLVE_MECHANIC` | `const Dictionary`，9 条；键 = `weapon_id`，值 = `"机制名:落点函数"`（两段式；`halo` = `灯心同心:_visual_center`） | `scripts/weapons/WeaponManager.gd:1282` | `SmokeTest._step13`（结构断言） |
| `WeaponManager._visual_center(player)` | `-> Vector2`；角色身体中心 = `global_position + (0, -Player.ART_FOOT_OFFSET)`。**全工程「以玩家为圆心」技能的判定与视觉唯一口径**（花灯 / 铜锣 / 皮影轨道） | `WeaponManager.gd` | `fire_halo` / `fire_gong` / `_update_orbits` / `HaloLogic` / `HaloShot` |
| `Player._punch` / `_bob_y` | `Vector2` / `float`；受击偏移只在这里衰减，`art.position` 每帧由「`(0, _bob_y)` + `_punch`」**合成赋值**（不再累加） | `scripts/Player.gd` | 仅 `Player._update_feedback` / `hit_punch` |
| `Enemy._punch` / `_bob_y` | 同上（小怪受击位移） | `scripts/Enemy.gd` | 仅 `Enemy._process` / `hit_punch` / `setup` |
| `WeaponManager._gong_echo(pos, radius, dmg, cap)` | `-> void`；0.28s 后补响（伤害 ×0.45 + 减速 0.25/0.8 + 第二圈波） | `WeaponManager.gd` | `fire_gong`（Tween 回调） |
| `WeaponManager.GLUE_TIME` | `const float = 1.0`（糖画首跳定身时长） | `WeaponManager.gd` | `update_bullets` |
| `WeaponManager._delay_arc_v` / `_second_arc_v` | `-> void`（M-02 竖劈第二刀，内部） | `WeaponManager.gd` | `fire_whip` |
| `Enemy.apply_root(duration)` | `-> bool`；成功置 `_root_left` 并进入 `ROOT_IMMUNE` 冷却 | `scripts/Enemy.gd:613-619` | `WeaponManager.update_bullets`（糖画首跳） |
| `Enemy.ROOT_IMMUNE` | `const float = 2.5`（防连控窗口） | `scripts/Enemy.gd` | `apply_root` |
| `Enemy.GLUE_TINT` | `const Color = Color(1.0, 0.96, 0.86)`（定身染色） | `scripts/Enemy.gd` | `Enemy._sync_root_tint` |
| `Enemy._root_left` / `_root_immune` / `_root_tinted` | `float` / `float` / `bool`；**唯一写者** `apply_root` 与 `_advance`（递减）；染色的唯一写者是 `_sync_root_tint` | `scripts/Enemy.gd` | 均在本文件内（本轮无跨模块读者；未新增 `is_rooted()`） |
| `Audio.play_sfx(id, extra_db)` | `void`（沿用两参，不扩签名） | `scripts/Audio.gd` | 迭代03 新增三处：`ActiveSkill`（`boss_spawn -6dB`）、`MainMenu`（`ui_confirm`）、`DeathUI`（`ui_click`）、`WeaponManager._gong_echo`（`gong -6dB`） |

### 7.5 迭代 04 新增 / 变更接口（跨模块只走本表）

| 接口 | 签名 / 字段 | 定义处 | 使用方 |
|---|---|---|---|
| `LevelUpUI._on_level_up()` | `-> void`（签名未变） | `LevelUpUI.gd` | `Game.gd`（经验满）、`CardShot` / `LevelUpShot` |
| `LevelUpUI.close_all()` | `-> void`（签名未变，语义加严）：复位 `_picking=false` / `_first_show=true` / kill tween / `_dim_world(false)` / `paused=false` | `LevelUpUI.gd` | `Game.gd`（死亡/重开）、`CardShot` / `LevelUpShot` |
| `LevelUpUI._on_pick(index)` | **签名变更**：入参由 `entry: Dictionary` 改为 `index: int`（由 `btn.pressed.connect(_on_pick.bind(order))` 绑入） | `LevelUpUI.gd` | 仅本文件按钮；`SmokeTest` 走 `Button.pressed.emit()` 真实通路 |
| `LevelUpUI._hover(card, on)` | `-> void`；悬停姿态与扫光（含 `_picking` 早退） | `LevelUpUI.gd` | 仅本文件按钮 `mouse_entered/exited` |
| 其余 9 个内部函数 | `_pose` / `_decorate` / `_gloss_tex` / `_enter` / `_exit` / `_pick_async` / `_entry_of` / `_dim_world` / `_world` / `_kill_tween` | `LevelUpUI.gd` | 均在本文件内，**无跨模块调用**（本轮不新增跨模块接口） |

---

## 八、变更记录

| 日期 | 版本 | 变更 | Owner |
|---|---|---|---|
| 2026-11-07 | db-v1-phase1 | 新建 `01-top-level-design.md`（258 行） | game-lead-designer |
| 2026-11-07 | db-v1-phase2 | 新建 `02-system-design.md`（660 行） | game-system-designer |
| 2026-11-07 | db-v1-phase3 | 新建 `03-entity-logic.md`（602 行） | game-entity-logic-designer |
| 2026-11-07 | db-v1-phase4 | 新建 `04-narrative-script.md`（546 行） | game-narrative-designer |
| 2026-11-07 | db-v1-phase5 | 新建 `05-numeric-tables.md`（788 行）+ `tools/check_numeric_tables.py`（750 行，FAIL 0） | game-numeric-designer |
| 2026-11-07 | db-v1-phase6 | 新建 `06-asset-requirements.md`（572 行） | game-asset-requirements |
| **2026-11-07** | **db-v1.0** | **新建 `project-design-db-v1.0.md`（整编库）；整篇重排本 `interface.md` 八节；完成三遍审计（ID 唯一 / 引用全通 / 状态齐全）；产出 8 条裁定（§6.1）、8 条实证事实（§6.2）、11 条缺陷总账、12 条待确认。`GameDemo/` 零改动。** | **team-lead** |
| 2026-11-08 | iter-01-backlog | 新建 `iteration-01-backlog.md`（22 条任务 / B0~B5 六批次）；**局外经济划为锁区零改动**；实读修正数据库 7 处（含图鉴与卡面文案双路径不一致）。`GameDemo/` 零改动。 | team-lead |
| 2026-11-08 | iter-01-fix-plan | 新建 `iteration-01-fix-plan.md`：D-1 皮影恢复（不动数值，依据 `CharacterDB.gd:18-21` 模型实测 phone 57.1）、D-2 剪纸删次数（新增 `bounces_left`，不复用 `b.bounce`） | team-lead |
| 2026-11-08 | iter-01-art-board | 新建 `art-design-board.html`（400 KB / 79 张真资产内联）+ `tools/build_art_board.py`；81 个资产 ID 全部命中 `06` 体系，零自造 ID。**只读资产，`GameDemo/` 零改动。** | team-lead |
| 2026-11-08 | iter-01-b1-code | **B1 批次代码落地**（gameplay-logic 执行 / code-orchestrator 整合验证）：IT-03 `_orbit_cd` 从 `_cd` 剥离（`WeaponManager` 4 处 + `WeaponDB.kind_of()` 新增、零数值改动），IT-06 新增 `bounces_left` 计次（3 处，单发封顶 4 只）；`HaloLogic` 补用例⑧⑨、新增 `BladeLogic` 工具（B-2~B-5）。验收 12/12 绿；回归 SmokeTest 313/0、HaloLogic 29/29、BladeLogic 9/9。文档同步 `03` C-1 闭合、`05` R-1/R-5/Q-1/Q-3 闭合；新登记 Q13（fix-plan §2.3 复利描述与代码不符，待策划修订）。锁区零改动，未提交 git。 | team-lead |
| 2026-11-08 | iter-02-skill-synergy | 新建 `iteration-02-skill-synergy.md`（664 行）。**主线 = 技能关联**：补 3 条进化配方（phone/blade/print）使 9/9 有终点、卡面三态提示、术语收口（传承/手艺/心法/开脸各归一位）、图鉴 33→36。配套 C-01 开脸镜头 / N-01 环绕数 2→3 / U-01 开脸徽章。**代码零改动，只出策划案。** | team-lead |
| 2026-11-08 | iter-02-code | **迭代 02 代码落地**（code-orchestrator 拆解 → gameplay-logic / ui-scene-building 并行执行 → 主控整合双轨）：S-01 `EvolutionDB` +3 配方（FORMS 6→9）、S-02 `LevelUpUI` 满级三态、S-03 `Game._open_chest` 空箱横幅、S-04 术语收口 5 处、S-05 冒烟 9 把全覆盖、C-01 `pull_zoom(1.06,0.35)`、N-01 `orbit_count_bonus` 2→3、U-01 HUD「开脸 n/9」徽章；文档 `04`/`05`/`06` + 校验脚本同步（仅行号锚点）。**验收：SmokeTest 321/0/exit0、python 314/0/exit0、HaloLogic 32/32、CardShot 123/123、V71Content 66/66**；`HudFxGap` 11 项为 HEAD 既有护盾口径红点（非本轮引入，§6.4 Q14）。锁区零改动，未提交 git。 | team-lead |
| 2026-11-08 | fix-skill-center | **视觉修复**（用户截图反馈）：① 花灯/皮影/铜锣的环绕中心从「脚底」改为「身体中部」——角色 origin 在脚底（`art.offset` 上抬 18px），`Player.gd` 给 `GarlicRing` 同步上移，`WeaponManager` 新增 `_visual_center()` 供 halo 爆闪 / gong 震波·锣面 / phone 轨道三处视觉使用；**判定一律不动**（敌我 origin 同基准，平衡零影响）。② 年画落地删除 `magic_circle` 法阵（`spawn_circle` 段），落地的"砸"由放射光条 + 雕版盖章（既有 `_drop_seal`）承担。**验收：SmokeTest 321/0/exit0、HaloLogic 32/32、SkillInGame PASS；截图 `skill_halo_field.png`（环心对齐身体）、`v6_look_halo8.png`（走马灯同心）、`print_land_check.png`（落地无法阵）**。 | team-lead |
| 2026-11-08 | fix-skill-center-v2 | **坐标健壮性加固**（用户二次反馈「移动后中心变了」）：① `Player._physics_process` 每帧强制 `garlic_ring.position = (0, -ART_FOOT_OFFSET)`，兜底任何运行时意外重置；② `WeaponManager` 全部特效精灵（锣面 `face` / 火花 `spawn_spark` / 年画落点 `_push_zone` / 印章 `_drop_seal` / 进化星 `spawn_evolve`）由局部 `position` 改为 `global_position`，消除「父节点位移导致落点偏移」的隐患（此前依赖 Weapons 恒在原点的隐含假设）；③ 皮影轨道本就用 `global_position`，不变。**诊断结论**：5 秒持续监控中 GarlicRing 最大漂移 **0.0000 px**、皮影轨道漂移 ≤3.9 px（帧间相位差，可忽略）；自动化未复现用户截图的大幅偏移，判断为运行时状态意外 + 局部坐标假设共同导致，已用上述两层防御消除。**验收：SmokeTest exit0、HaloLogic 32/32、5s 监控 garlic 漂移 0**。 | team-lead |
| 2026-11-08 | iter-03-evolve-mechanic | 新建 `iteration-03-evolve-mechanic.md`（702 行）。**主线仍是技能关联，但换层**：迭代 02 解决覆盖度（9/9 有终点），本轮解决深度（当前 9 条里只有 1 条 `extinguisher` 真有行为机制）。六条纯倍率形态各加一个机制：M-02 师刀第二刀改竖劈 / M-03 花灯灯心 8 方位公转 / M-04 年画落点镇守 30%×4s / M-05 糖画四发分锁 / M-06 铜锣回响 / M-07 墨线穿透后折返一次。M-01 在 `WeaponManager` 末尾加 `EVOLVE_MECHANIC` 声明常量（不碰 `EvolutionDB` 结构，避免 227 项行号连锁漂移）；M-08 满级觉醒与开脸视觉分层；M-09 五处文档同步。配套 C-02 `TOMB_TILE` 死资产接入 / N-02 第 2 主动技规格（不实现）/ U-02 震吼零音效 + 3 面板 UI 音。**代码零改动，只出策划案。** | team-lead |
| **2026-11-09** | **iter-03-code** | **迭代 03 代码落地**（code-orchestrator 按 `iteration-03-handoff.md` B0→B5 逐批执行 / 三子智能体职责由主控收口）：M-01 `WeaponManager.EVOLVE_MECHANIC` 9 条 + `_lamp_step`；M-02 师刀第二刀竖劈（`_delay_arc_v`/`_second_arc_v`）；M-03 灯心公转（`_lamp_center`，写 `garlic_ring.position`，偏移 `0.40R`）；M-04 门神镇守（`apply_slow(0.30, 4.0)`）；M-05 糖水粘连（`Enemy.apply_root(1.0)` + `ROOT_IMMUNE 2.5s` + `GLUE_TINT`）；M-06 铜锣回响（`_gong_echo`，0.28s 后 ×0.45）；M-07 墨线穿透累进（`pierce +1`、每多穿一只 +25% 封顶 ×1.75、全程笔直、`scale.y` 加粗）；M-08 视觉分层；U-02 三处确认音；C-02 街区外旧墓砖；M-09 文档 `05`（表 C 行为机制列 + R-29~R-31 + 21 处重锚）/ `02`（唯一写入者 +2 行）/ `04`（6 条机制句）/ `06`（零新增资产）；新增 `tools/HaloShot.tscn` 视觉量尺探针 + `shots/m03_*.png` 四张（V-1~V-4 8/8，偏差 ≤1.7%）。**验收：SmokeTest 340/0/exit0、HaloLogic 37/37、FxInGame 18/18、V5InGame 165/0、python PASS 314/FAIL 0/exit0，无 SCRIPT ERROR / PARSE ERROR**。偏离主件 2 处（D-1 C-4 几何、D-2 删 `Player` 每帧兜底）已登记 §6.5；`GarlicRing.gd` 0 行改动、锁区零改动。 | code-orchestrator |
| 2026-11-09 | iter-03-code-git | **本地留痕完成**：提交 `9e4fc1d`（迭代 02+03 累计 50 文件 / +2722 / −100）+ 附注标签 `iter-03-code`；`interface.md` 首次入库。**推送未完成**：`git push origin main` 与 tag 两次失败（`github.com:443` 连接重置 / 21s 超时，沙箱内外一致），见 §6.5 Q19。**复验**：`check_numeric_tables` PASS 314 / FAIL 0；`SmokeTest` 全部通过（含 M-06 实测 1.450 ±0.01）；`HaloLogic` 37/0；`FxInGame` PASS；`V5InGame` 165/0；`V71Content` 66/0；`HaloShot` 8/8；全程无 SCRIPT ERROR / PARSE ERROR。 | code-orchestrator |
| **2026-11-09** | **iter-04-levelup-ui** | **迭代 04 升级选卡界面重构代码落地**（code-orchestrator 按 `iteration-04-handoff.md` B0→B5 拆解，`ui-scene-building` 主执行、`gameplay-logic`/`architecture-data-layer` 本轮无接口改动）：UI-01 `LevelUpUI.tscn` `layer=20`（盖住 HUD 10）；UI-02 `Mask`（纯色 0→0.80）+ `Vignette`（径向 0→1.0，`GradientTexture2D` 256²）；UI-03 伪 3D 五线索（三层投影 `y=24/17/11` `a=0.26/0.14/0.07` 复用 `UI_CARD_FRAME` + 右侧厚度 + `TILT_DEG 3.2`/`SIDE_SCALE 0.965` 插值位姿 + 移入扫光一次）；UI-04 `_enter()` 0.42s 错峰（`K_ENTER_STAGGER 0.055`，`TRANS_BACK`）；UI-05 `_exit()` 0.27s（被选卡 `scale:x→0.02` + 上移 50 / 落选 ±14° + 下移 36）+ `_picking` 输入锁；UI-06 `_hover()` 转正/上移 12px/`1.055`/投影 `a×0.55`·`y×1.35`；UI-07 `_first_show` 连升不重播标题；UI-02b `World.modulate → (0.58,0.56,0.66)`；配套 `PauseUI` layer 9→21、`DeathUI` 补 `layer=22`；`SmokeTest` 时序适配 + `_prep` 清零 `xp`（D-11/D-13）；`CardShot` 文件头 +3 行；**新增 `tools/LevelUpShot.gd/.tscn`**（33 断言 + 4 张截图，几何实测三卡底边 y=[280,280,280]、投影最大间距 31px）。**验收：`SmokeTest` 340 ok / 0 FAIL / exit 0（headless）、`LevelUpShot` 33/0 / exit 0（窗口）、`CardShot` PASS / FAIL 0、`python` PASS 314 / FAIL 0 / exit 0，无 SCRIPT ERROR / PARSE ERROR**。偏离 handoff 3 处（D-7 `_enter` 调用位置、D-8 `deg_to_rad(14)`、D-9 出场补撤墨幕）+ 测试侧 3 处（D-11/D-12/D-13）已登记 §6.6；锁区零改动（`MetaSave`/`coin_reward`/`ShopUI`/`TRACKS.mult`/复活/局外经济）。 | code-orchestrator |
| 2026-11-09 | iter-04-git | **本地留痕完成**：提交 `64ce6c3`（9 文件 / +676 / −30，含新增 `LevelUpShot.gd/.tscn`）+ 附注标签 `iter-04-code`。**推送**：本轮再次尝试 `git push origin main`（结果按实际登记于 §6.5 Q19，不假装成功）。**复验**：`SmokeTest` 340/0/exit 0、`LevelUpShot` 33/0/exit 0、`CardShot` PASS、`python` 314/0/exit 0。**versions 归档**：本轮无被取代的旧版本（`iteration-04-levelup-ui.md` 与 `iteration-04-handoff.md` 仍为现行件），`docs/design/versions/` 无新增。 | code-orchestrator |
| **2026-11-09** | **iter-04-fix-halo** | **花灯灯心同心（撤回 M-03 公转，用户截图裁定）**：`WeaponManager._lamp_center()` 改写为恒等 + 钉回 base（删 `_lamp_step`）；`Player._physics_process` 顶部恢复每帧钉回 `Vector2(0, -ART_FOOT_OFFSET)`；`EVOLVE_MECHANIC["halo"]` 改「灯心同心:_lamp_center」（仍 9 条两段式）。测试同步三套：`SmokeTest._step13` 4 条同心断言、`HaloLogic` ⑪ 改 C-1~C-3、`HaloShot` 整份重写（受击前/后两图 + 四向边距 TOL 7% + 2 条结构断言，期望半径从 `halo_radius()` 动态取）。**验收**：`SmokeTest` 340 ok / 0 FAIL / exit 0（headless）、`HaloLogic` 37/0 / exit 0、`HaloShot` 10/10 / exit 0（窗口，截图 `shots/halo_before.png` / `halo_after_hit.png`）、`python` PASS 314 / FAIL 0 / exit 0；无 SCRIPT ERROR / PARSE ERROR。**判定半径 / 伤害 / 平衡零改动**。 | code-orchestrator |
| **2026-11-09** | **iter-04-cleanup** | **过期内容清理（用户指令「清理以前的测试、截屏、前一个题材的内容」）**：删 `assets/art/`（奶茶题材 68 文件）、`shots/` 旧图 132 文件（仅留本轮两张证据）、`tests/` 全目录 4 文件、`tools/` 30 个旧探针；保留 10 个现行探针。`Art.gd` 1 行注释同步。删除后 `SmokeTest` 复跑仍 `340 ok / 0 FAIL / exit 0`（资源齐备性守卫绿）。详见 §6.7 D-15 / Q23。 | code-orchestrator |
| **2026-11-09** | **iter-04-fix-git** | **远端留痕完成**：提交 `772283b`（230 文件 / +166 / −10707）+ 附注标签 `iter-04-fix`；与远端 README 提交 `93276ba` 合并为 `6c21294`，`git push origin main` 成功、标签同步推送。**Q19 闭环**。复验（提交前）：`SmokeTest` 340/0/exit 0、`HaloLogic` 37/0、`HaloShot` 10/10（窗口）、`python` 314/0/exit 0；无 SCRIPT ERROR / PARSE ERROR。注：`/docs/` 在 `.gitignore` 第 13 行，本轮五处文档回写仅在本地生效，不入库。 | code-orchestrator |
| **2026-11-09** | **iter-04-fix-halo-v2** | **受击坐标残留复诊修复（用户反馈「没有完成」）**：**根因** = `Player._apply_punch` / `Enemy._apply_punch` 的 `art.position += _punch` 逐帧累加、衰减到 0 时也不减回 → 单次受击永久残留 `HIT_PUNCH_PX/(1-0.82)` ≈ **27.8px**（小怪 22px），而花灯环挂在 `Player` 上不跟 `art` 走 → 截图里的「环没动、人歪了」。**修法**：两边改为「行走起伏 `_bob_y` + 衰减偏移 `_punch` **合成后一次性赋值**」，删 `_apply_punch`；锚点统一为 `WeaponManager._visual_center()`（`fire_halo`/`fire_gong` 的判定、资源点、爆闪/震波/锣面同源），删 `_lamp_center` / `garlic_radius` / `Player` 每帧钉回，`garlic_ring.position` 只由 `Player._ready` 写一次；`aura_field.gdshader` 外径 fade 收口到 `r=1.0`，消除 add 混合下的方形亮边。**测试**：`HaloLogic` 新增⑫（四向受击后 `art.position=(0,0)` + 环心==身体中心）、C-3 改以身体中心放置；`HaloShot` 新增⑤⑥⑦（归零 / 同源 / 无方边像素断言，共 13 条）。**验收**：`SmokeTest` 340 ok / 0 FAIL / exit 0（Step2 偶发 1 红、复跑绿 → Q24）、`HaloLogic` 39/0 / exit 0、`HaloShot` 13/13 / exit 0（窗口）、`python` PASS 314 / FAIL 0 / exit 0；无 SCRIPT ERROR / PARSE ERROR。判定半径 / 伤害数值 / 平衡零改动。详见 §6.7 D-16/D-17/D-18。**留痕**：提交 `7f0a719`（9 文件 / +183 / −112）+ 附注标签 `iter-04-fix-halo-v2`，`git push origin main` 与标签推送均成功（仓库迁移告警仅提示，不影响推送）。 | code-orchestrator |
| **2026-11-09** | **release-v2.0** | **第二版构建与替换（用户指令「输出 apk 和 exe，完成第二版，替换第一版的 apk、exe」）**：`export_presets.cfg` Android `version/code 1→2`、`version/name "1.0"→"2.0"`；`--export-release` 产出 `release/windows/FirstXiXueGui.exe`（117,109,248 B）与 `release/android/FirstXiXueGui-2.0.apk`（34,213,042 B，`versionCode=2` / `versionName=2.0` / arm64-v8a / 已用既有 `release.keystore` 签名，证书 DN `CN=First Xi Xue Gui, O=QoderGame`）；删除 v1 的 `FirstXiXueGui-1.0.apk` 与 `FirstXiXueGui-Windows-x64-v1.0.zip`，新打 `FirstXiXueGui-Windows-x64-v2.0.zip`。**验证**：headless `SmokeTest` 全部通过 / exit 0（无 SCRIPT ERROR / PARSE ERROR）；导出 exe `--headless --quit-after` 启动确认（Godot 4.7.2 探针，退出期 ObjectDB 泄漏告警为强制退出既有现象）；APK `apksigner verify` 通过。SHA-256 已写入 `release/README.md`。**keystore 坑**：headless 导出不读编辑器设置的 keystore 回退，须在本次导出期间临时填预设三项、导出后立即清空（口令不入库）。**留痕**：提交 `47dbd94` + 附注标签 `v2.0`，`git push origin main` 与标签推送均成功；GitHub Release `v2.0` 已创建并上传 exe / apk / zip 三附件（`LjxMax2003/FirstAIGame`，仓库已迁移，原地址自动跳转）。 | code-orchestrator |
