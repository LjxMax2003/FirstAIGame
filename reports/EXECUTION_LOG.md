# Execution Log — 各阶段执行报告压缩索引

> 本文件是 2026-10-26 ~ 10-30 全部「执行报告 / 实施记录」的**压缩索引**。
> 原始逐份报告已从工程根与 `reports/` 移除，细节沉淀在每日记忆（已并入 `MEMORY.md`）。
> 本文只保留：阶段 / 关键改动 / 回归基线 / 会复踩的坑。详细设计仍以 `docs/design/`、`docs/balance/`、`docs/theme/` 为准。

## 0. 工程定位
- 游戏本体：`GameDemo/first-xi-xue-gui/`（Godot 4.7.x，720×1280 竖屏 2D 幸存者-like，民俗手艺换皮）。
- 数值真值：代码（`WeaponDB` / `EvolutionDB` / `UpgradeDB` / `Stats`）+ `tools/BalanceAudit.tscn` 比对 `docs/balance/v7_result.json`；`docs/balance/` 下 v3.1 文档与 `params.json` 为旧框架存档，不可当现行数值。
- 合规：`docs/COMPLIANCE_CHECKLIST.md` 未签字，对外只写「民俗手艺题材」，不写「非遗」。

## 1. 数值平衡设计（10-26）
- 产出：`docs/balance/NUM_DESIGN.md`(v2→v3.0) + `params.json` + `balance_model.py`（解析式，闭式可逐行查）。
- 方法论：**双侧 DPS 平衡口径** `R(t)=供给侧/需求侧`，要求单峰（开局擦边→中期割草→末期顶压）。
- 定稿基线：`hp(t)=3×(1+t/1800)^1.70`；接触伤害 6.0；`xp_curve=5+n^2.25`，封顶 48；进化 `1.7/1.5/1.4`。
- R 峰值 ~0.74(20min)。收敛带约束 max≤163、min≈102。
- 命名全量替换（v3.1）：鞭→**鞭弧**(whip)/蒜环→**光环**(halo)/魔杖→**荧光棒**(glowstick)/圣经→**手机环**(phone)/飞刀→**美工刀**(blade)/斧头→**灭火器**(extinguisher)。改名后模型数字不变（R 峰 0.71）。
- 坑：① `X11<X1` 隐性约束（少拿武器去进化不能更优）；② 推离类机制=无声无敌挂（推离≥0.5s 前进距离则接触伤害恒 0）；③ AoE 命中数必须几何算；④ 逐帧模拟在纯调参阶段不可信（`balance_sim.py` 已废弃并移除）。

## 2. 阶段一~三：渲染 / Build / 压力曲线（10-26）
- 阶段一（59/59）：`z_index` 图层陷阱（BG 压住地面，设 z=-20）；地砖世界格翻转；血条乘法 tint 改运行时渐变；武器槽 `EXPAND_IGNORE_SIZE`。
- 阶段二（118/118）：架构红线 **被动→Stats→武器 单向管线**；`Stats.value_at` 唯一公式出口、`WeaponDB` 唯一武器表、`EvolutionDB` 唯一进化表；进化是武器上的标记不是新 id；宝箱 100% 掉。修正 `cooldown 1-0.08L→1-0.05L` / `area 1+0.10L→1+0.07L` / `might max(0.30)→max(0.50)`。
- 阶段三（229 ok）：新增 `WaveTable`/`PickupField`/`ResourceField`；真 bug=**敌池从不回收尸体**（active 只增不减，撑满后刷不出怪）；资源点走开少 6 个（相机滞后→锚点改玩家）；`SPAWN_RING 900→760`、`contact_dmg 10→6`、`hp 指数 1.5884→1.70`。

## 3. 阶段四：金币 Meta 商店（10-27，284/284）
- 新增 `MetaSave.gd`(autoload) + `ShopUI`；`Stats` 加 `meta_mult`/`effective_at`（Meta 是第二乘区，上限 1.35）。
- 约定：Meta 只乘不加；金币只 `Game._finish` 入账（banked 防双份）；商店只在结算界面开；复活无敌 3.0s。
- 新脚本带 `class_name` 后必须 `godot --headless --path . --editor --quit` 刷新全局类缓存，否则运行时 `Could not find type`。

## 4. 非遗换皮 P1~P5（10-27，285→286→287→299）
- P1 断言解耦（285）：`Art.gd` 加 12 语义键 + `ALL_PATHS`(34) + `SLOT_ALIASES`；`SmokeTest._art_check` 改槽位判定（子串误命中：`enemy_cup`⊂`enemy_cup_fast`）；路径可加载守卫。**反向验证**才认全绿。
- P2 资源补正（285）：刻度画在框(`texture_over`)不是填充图（满血时 under 被盖死）；快速兵描边；宣纸卡框浅底→文字墨色。
- P3 文案换皮（285）：232 处字面量，5 文件 40 字段；`might`(减伤)≠商店`damage`(加攻) 易串。
- P4 UI（286）：五更/结算/商店/暂停/终局 2s 演出；UI 文案可能在代码里被覆盖（`LevelUpUI.gd` 每帧写 title）；`_win_hold` 分支必须在 `if not started` 之前。
- P5 验收（286×3）：`Performance.TIME_PROCESS` headless 不可信→用墙钟帧间隔；400 是容量线不是满帧线，真实峰值 275；`PEAK_FROM_SOAK=275` 每轮长跑回填。
- UI 文案修正（287）：铜铃磁铁从「完全无效」修成真收全图（断言校验实现→改成打效果）；`CardText.gd` 连续量写百分比、离散量写「1→2」；卡面 desc 56px=3 行、印章占位、autowrap 先于 size。

## 5. 玩家操作反应（10-27，299）
- `Player` 四向朝向（上→背面帧）+ 3 帧走路 + 侧倾；斜切背面带迟滞（纵>横×1.25）；`Array[Texture2D]` 不能用三元。未接：敌人走路帧、Boss 三档、拖拽摇杆可视化。

## 6. 视觉特效包 shader（10-27）+ FX 接入（10-28）
- 7 战斗反馈 shader + `ShaderFX.gd` + `fx_manifest.json`；坑：fragment 内禁 `return`；`COLOR` 输出要先存 `varying node_tint` 保 modulate；未开 HDR 加法>1.0 裁白。
- 合批红线：**独立 ShaderMaterial 切断 CanvasItem 合批**，小怪(50~200)只用 `art.modulate` 换色，shader 只给精英/Boss/玩家/掉落(<10)。
- FX 接入 7/7（FxInGame 18/18）：`hit_flash`→Enemy 受击、`dissolve_spawn`→出现/消失、`hurt_vignette`→HUD、`sprite_glow`→Gem、`shine_sweep`→Pickup、`glow_aura`→宝箱、`magic_circle`→Boss。修 `ShaderFX.flash` 只 attach 不 detach（掉合批）；`hurt_vignette` 改短边归一化。

## 7. 技能向 5 shader 接线（10-28，SkillInGame 32/32）
- `slash_arc`(遮罩式)/`cast_burst`(squash 反向放大节点)/`skill_rank_rim`(三档色不靠贴图)/`aura_field`(极坐标接缝用单位圆坐标)/`projectile_trail`(blend_add 下 alpha 恒 1.0)。
- 修 4 真问题：`set_rank` rim 单位用纹素→加 `rim_px`；`burst_ellipse` 替代 squash；池化精灵带旧材质→取出 clear；`aura_field` 压贴边窄带。度量三坑：别拿被测反推期望、数点亮像素不取平均亮度、截图对准峰值帧。

## 8. v5 局内重写（10-28，SmokeTest 308/0）
- 重写 `skills-and-midgame-v4.md` + 新 `v5_model.py`(cur/v4/v5)；解 exp2.0 挂机（exp2.6/cap60/精炼）、Boss 11000→7000、主动技震吼(CD25s+0.7s 无敌冲刺)、周期潮涌、浆壳兵、更鼓 1.40。
- 收敛带 9 武器 Lv8 全 96–157。震吼做成 **Player 下 ActiveSkill 子组件 + 信号**，不硬塞 Game 全局态。
- 坑：`FxInGame` 绝对不能 `--headless`（`frame_post_draw` 在 dummy driver 不触发）；`params.json` 仍 v3.0 脱节（待决）。

## 9. 帧率优化（10-28，SmokeTest 312/0）
- 诊断：本机 165Hz 未限帧→2.4~2.75× 负载→降频卡顿。`project.godot max_fps=60` + `Engine.max_fps=60` + 保留 vsync；测试工具必须显式 `Engine.max_fps=0`（否则 P5Perf 失真）。
- `EnemyPool.separation()` 零分配重写（定长 PackedFloat32Array 插入排序）：先 Python 对拍 2 万组**完全等价**再谈提速；实机 2.3~3.8×，省 ~2.5ms/帧。P5Perf `MEASURE_SEC 1.2→2.5`（P95 同版本能差 40%）。

## 10. HUD 数值/护盾 + 敌人特效（10-28，HudFxGap 43/43）
- 零新 shader/美术：伤害飘字 `DamageNumbers`、HP/EXP 数字、护盾条+数字、小怪受击染色强化+池化火花、小怪死亡化墨（复用 `dissolve_spawn`）。
- 坑：本作**有 Camera2D**（文档误写无滚动）；无暴击系统→`big`=击杀那一击；飘字 0.22s 聚合；`add_theme_*_override` 重操作→样式只在 `_ready` 设一次（否则 400 同屏 P50 12.57→10.52ms）；火花令牌桶 30/s。

## 11. 开始界面 + 范围波纹（10-29，SmokeTest 312/0）
- `scenes/MainMenu.tscn` + `MainMenu.gd`、`project.godot` main_scene 改菜单；新 `area_ripple.gdshader`（Circular Waves 2D 改编，禁 SCREEN_TEXTURE）；`ShaderFX.ripple` 系列；皮影轨迹圈做成「整条轨迹一圈」而非逐只。
- 坑：`area_ripple` rings 越少可见弧越少（改 rings=3）；像素占比断言默认 31.5%、过曝 0；`ShopUI.tscn` 本就存在（文档「抽独立场景」过时）；置灰条件用「有无进度」非 `MetaSave.loaded`。

## 12. v6 觉醒特效 + 美术（10-29，V5InGame 148/0 / V6Fx 15/15）
- 核心结论：**仅 1 shader(molten_scatter 铁水火星) + 1 美术(awaken_badge Lv8 徽记) 必须新写**；其余 8 武器复用 13 现有 shader + `art.modulate`。
- 落地：`molten_scatter`/`lantern_stream` 两 shader + 4 美术接线（awaken_badge/molten_blob/ink_line_tex/woodblock_seal）；逐武器补缺。
- 坑：glow_aura outer>1.0 画成硬圆环；SubViewport 背景 z 必须<-2；molten_scatter center 是 global 坐标。

## 13. 铜锣/花灯区分 + 花灯核查 + 皮影去波纹（10-29）
- 根因：v5 把铜锣归「光环型」→只装铜锣也有和花灯一样的常驻橙圈（说谎）。改 `show_ring` 只跟 halo；铜锣视觉重做（`ShaderFX.shockwave` 冷白主环+内收回震 vs 花灯只外推）。
- 花灯核查：halo 是**以玩家为圆心的区域脉冲**（query_circle+0.44s 跳+减速），非环绕；真实缺口=减速零视觉反馈→加 `Enemy.SLOW_TINT` 琥珀染色（只在状态翻转沿赋值）。
- 皮影去波纹：删 `_orbit_ring*`（视觉语言撞车，与花灯分不清）；MenuRipple H 用例反向重写为「不许有波纹」。

## 14. T8 铁水散开 + v7（10-30，V5InGame 157/0）
- 打铁花从「引爆型」换「铁水散开型」：`hit_cap 4→1`（撞第一只即碎）、`scatter_radius 150 / ratio 0.28 / cap 4 + cap_per_level 2`；光晕 `r×3.6→min(r×2.4,360)`。
- 收敛：Lv1 42.4→Lv8 147.6，单体 13.9，跨度 1.55×。
- 铜铃磁铁缺陷修复：Gem 吸附纯累加→投影到径向再累加（`v·dir` 消除切向逃逸轨道）；连带修 `WeaponManager.clear_bullets()` 复位在飞弹体（V5InGame 随机红根因）。
- T14/T15 文档对账：`README.md` 三条「未完成」已全部做完；`compliance.md` 撞出傩面同时是武器/敌人、铜锣墨斗无合规依据、媒体包写「六门+非遗」过时。

## 15. 易复踩坑速查（跨阶段）
1. 新增 `class_name` 脚本后必须 `--editor --quit` 刷全局类缓存，否则运行时静默找不到类型、进程挂死不退出。
2. 屏幕坐标≠世界坐标（Camera2D 在玩家身上）；取样用 `get_global_transform_with_canvas().origin*(img_w/viewport_w)`。
3. `FxInGame`/`V6Fx`/`MenuRipple`/`HudFxGap`/`FramePace` **不能 `--headless`**（frame_post_draw / SubViewport 渲染依赖真实驱动）。
4. 测试工具要 `Engine.max_fps=0`；长测试 `run_in_background`（单次 ~60s，连跑超 120s 被 SIGTERM）。
5. 像素占比/可见性断言：数点亮像素不取区域平均；截图对准峰值帧；别拿被测对象反推期望值。
6. 池化 FX 精灵取出时 `clear()+material=null`，归还时还原，否则旧材质遮住下个使用者且不报错。
7. 小怪绝挂独立 ShaderMaterial（掉合批）；合批靠 `art.modulate` + 全场共用材质实例。
8. 文档不抄数值，只加指路牌；每个数要么自己跑出来要么不写（防止漂移 + 顾问质疑）。
