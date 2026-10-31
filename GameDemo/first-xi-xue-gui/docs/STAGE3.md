# 阶段三：压力曲线与单局节奏

> 对应《核心玩法完善步骤.md》Step 9 / 10 / 11。
> 数值全部对齐 `数值平衡设计/params.json` v3.1 与 `NUM_DESIGN.md`。

---

## 一、完成了什么

| Step | 内容 | 新增/改动文件 |
| --- | --- | --- |
| **9** 时间驱动波次脚本 | 5 段事件表 + 3 档 Boss 表，替换原 lerp 插值 | `scripts/WaveTable.gd`（新）、`scripts/Game.gd`、`scripts/Enemy.gd`、`scripts/EnemyPool.gd` |
| **10** 场景资源点 | 可破坏物（拆了给金币、有概率掉物）+ 磁铁/炸弹/烤鸡 | `scripts/ResourceField.gd`（新）、`scripts/PickupField.gd`（新）、`scripts/weapons/WeaponManager.gd` |
| **11** 死亡/胜利结算 | 撑满 30 分钟判胜；胜负两种版面 + 金币结算 | `scripts/ui/DeathUI.gd`、`scripts/ui/HUD.gd` |

---

## 二、Step 9：时间驱动波次

### 2.1 波次表（`WaveTable.WAVES`）

| 时段 | 精英占比 | 设计意图 |
| --- | --- | --- |
| 0~5 min | 0% | 杂兵熟悉期，只出杯子 |
| 5~10 min | 6% | 密度爬升，开始出肉盾 |
| 10~20 min | 10% | 精英 + 大波，红精英登场 |
| 20~25 min | 14% | 精英压制 |
| 25~30 min | 18% | 精英 18% + Boss 终局 |

### 2.2 三档 Boss（`WaveTable.BOSSES`）

| 时间 | 血量 | 定位 |
| --- | --- | --- |
| 15 min | 2800 | 检验玩家是否已有单体输出 |
| 25 min | 6100 | 中期战力检验 |
| 30 min | 11000 | 终局 |

Boss 是**真打的敌人**（`enemy_reaper.svg`），不是脚本演出。相关常量：
- `BOSS_SPEED = 52.0`（杂兵的 0.55~0.87 倍，必须比杂兵慢才能"拉开再回头打"）
- `BOSS_DAMAGE_MULT = 3.0` → 实际接触伤害 18（= 杂兵 6 × 3.0）
- `BOSS_CONTACT_R = 34.0`（贴图 80×112，取身体宽度一半，**不套 `size*0.36`**）
- `MOB_SPAWN_DURING_BOSS = 0.35` → Boss 战期间刷怪间隔 ×2.86

### 2.3 数值公式（全部来自 params.json）

```
enemy.hp(t)        = 3 × (1 + t/1800)^1.70
spawn.interval(t)  = lerp(1.1, 0.45, min(1, t/600))
spawn.batch(t)     = min(6 + 0.01t, 30)
world.spawn_ring   = 760.0
enemy.contact_damage = 6.0
```

### 2.4 ⚠️ 本阶段修正的两处数值偏差

阶段一/二遗留，本阶段已对齐 params.json：

1. **`SPAWN_RING` 900 → 760**。原值会让敌人从进圈到贴身需 11 秒，而鞭弧射程只有 110~260px —— "武器永远打不到新进场的敌人"。760 是竖屏可视边缘外一圈（半宽 360 / 半高 640）。
2. **`contact_damage` 10.0 → 6.0**。params.json `enemy._fixed_contact` 明确推翻原设：10 伤 × 0.6s 节奏 × 100HP × 0.5s 无敌 → 1 敌 6 秒死、2 敌 3 秒死，满级最多撑 9 秒，与"擦边求生、30 分钟一局"直接冲突。改 6 之后：1 敌 10 秒、2 敌 5 秒。
3. **`enemy.hp` 指数 1.5884 → 1.70**。ref=1250 会让 R 曲线变双峰且全程 <0.6，割草期消失。

---

## 三、Step 10：资源点与掉落物

### 3.1 可破坏物（`ResourceField.gd`）

用现有摆件贴图当可拆物（项目没有墓碑/树）：消防栓 / 垃圾桶 / 自动售货机。

- **确定性生成**：世界格哈希 `_hash(cx,cy,salt)`，走回去还是同一批
- **命中判定**：纯距离，`HIT_R = 26`，`HP = 30`（一把鞭弧能拆掉）
- **拆掉收益**：+1 金币，18% 概率掉一个掉落物
- **重生成**：25~45 秒后在**别的格子**重新出现
- **武器接线**：鞭弧/光环/手机环/子弹全部可拆，且**判定顺序在敌人之后**（资源点不该抢敌人伤害）

### 3.2 三种掉落物（`PickupField.gd`）

| 掉落物 | 掉率 | 效果 |
| --- | --- | --- |
| 磁铁 | 0.0005/击杀（≈25 个/局） | 全图吸宝石 |
| 炸弹 | 0.0002/击杀 | 清屏（700px 内非 Boss） |
| 烤鸡 | 0.0003/击杀（≈15 个/局） | 回血 30% max_hp |

**炸弹必须限流**（两条同时上）：
1. Boss 战期间**不掉**——否则 Boss 战变成"重开一颗"，节奏断点失效
2. 每局上限 **4 个**，超出转成 1 颗橙色宝石（不浪费判定）

**炸弹对 Boss 免疫**是有意设计。`磁铁` 单独计数 `magnets_dropped`，因为一局 25 个会把等级从 Lv45 推到 Lv47。

---

## 四、Step 11：结算

### 4.1 金币公式

```gdscript
base = int(kills * 0.12) + int(elapsed / 12.0)
base += elite_kills * 6 + boss_kills * 40
if won: base = int(base * 1.5)
return maxi(base + coins_earned, 0)
```

设计取舍：
- **击杀为主、时长兜底**。纯击杀会让"挂机不动"和"猛冲"收益相同；纯时长又让"苟着不打"最优
- **资源点金币不进 1.5 倍乘数**——否则"想刷金币就拆箱子"会盖过"活到最后"这个主目标

### 4.2 胜负两种版面

| | 标题 | 颜色 |
| --- | --- | --- |
| 胜利 | 撑到天亮了 | 暖金 `(1.0, 0.86, 0.42)` |
| 失败 | 你被淹没了 | 暗红 `(0.95, 0.42, 0.40)` |

金币行（`◆ N`）插在标题下方——玩家结算时只扫标题和金币，明细是给记录用的。

---

## 五、顺手修掉的两个真 Bug

### 5.1 `EnemyPool` 尸体泄漏（严重）

`Enemy._die()` 只置 `alive=false` + `forget()`，**没有任何地方把它搬回 `inactive`**。后果：`active` 只增不减，撑满 420/400 只后**再也刷不出怪，Boss 也永远 spawn 失败**。

修复：
- `Enemy` 增加 `_corpse_left` + `corpse_expired(delta)`，死亡后保留 0.2s 让淡出动画播完
- `EnemyPool._process()` 每帧回收过期尸体
- `alive_count()` 改为只统计 `alive == true` 的

### 5.2 `ResourceField` 走开再回来少几个资源点

生成用 `RADIUS+1` 半径、回收用 `RADIUS+3`，中间留了一圈"回收了却不会再生成"的环；再叠加相机 `position_smoothing` 的追尾滞后，实测走回来少 6 个（正好是 `cy=-3` 那一行）。

修复：
- 生成与回收用**同一个半径**（`reach = RADIUS + 1`）
- 锚点从**相机位置**改为**玩家位置**（相机有平滑滞后，玩家位置才是权威值）

修复后：走开再回来 56/56 原位恢复。

### 5.3 顺带

- `ResourceField._flash_later` 的 lambda 捕获已释放节点 → 改传 `key` 字符串，回调时重查 `_alive`
- `Enemy.boss_index` 从未被赋值 → 删除
- `EnemyPool.max_alive` 420 → 400（对齐 params.json `spawn.max_alive`）

---

## 六、验收结果

```
godot --headless --path . res://tools/SmokeTest.tscn
→ exit=0   229 ok / 0 fail / 0 error
```

阶段三贡献 **103** 条检查，覆盖：

- [x] 刷怪间隔 1.1→0.45 封底、单批 6→30 封顶
- [x] 血量函数全程单调递增（37 个采样点）
- [x] 5 段波次、精英占比单调不降、逐段值校验
- [x] 杂兵血量倍率均值 1.1333（R 曲线输入）
- [x] 30s 前纯杯子、120s 前不出快速兵、之后三色齐全
- [x] 10 分钟前只出蓝箱精英、之后红精英出现
- [x] Boss 三档时间/血量、跨越判定不重复触发、大步跨越只取最早一档
- [x] Boss 实际生成：is_boss / 血量 2800 / 伤害 18 / 半径 34 / 血条常显
- [x] Boss 必掉宝箱、击杀计数、死后 has_boss() 归 false
- [x] 尸体 0.2s 内回收、池子无泄漏
- [x] 三种掉落物掉率、贴图存在
- [x] 炸弹每局上限 4、超出转宝石、Boss 在场掉落为 0
- [x] 磁铁全图吸、炸弹清屏内不打屏外、炸弹对 Boss 无效
- [x] 烤鸡回血 30% 且不超上限
- [x] 资源点确定性生成（56/56 原位恢复）
- [x] 资源点受击扣血、归零拆除、给金币、空地不误判
- [x] `WeaponManager.resources` 已绑定
- [x] 金币公式逐项（空局 0 / 1000杀+10min=170 / 精英Boss加成 / 资源点直加 / 胜利×1.5 不放大资源点金币）
- [x] 结算面板胜负两版、金币行、明细含时长与 Boss/进化
- [x] 真实死亡通路触发结算、真实满 1800s 触发胜利
- [x] 25 分钟档 400 帧长跑：无泄漏、无卡死（6665ms）

### 渲染证据（真实窗口，非 headless）

```
godot --path . res://tools/StageThreeShot.tscn
→ exit=0  errors=0
shots/stage3_boss.png   AVG_LUMA 0.2358   Boss 在场 + 掉落物 + 资源点
shots/stage3_lose.png   AVG_LUMA 0.1062   失败结算 ◆369
shots/stage3_win.png    AVG_LUMA 0.1065   胜利结算 ◆1337
```

---

## 七、⚠️ 未完成：Windows 导出构建

**导出失败，不是"没做"，是缺少导出模板。**

实际命令与返回码：

```
$ godot --headless --path . --export-release "Windows Desktop" build/first-xi-xue-gui.exe
ERROR: Cannot export project with preset "Windows Desktop" due to configuration errors:
  在预期路径处未找到导出模板：
  C:/Users/Administrator/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_debug_x86_64.exe
  在预期路径处未找到导出模板：
  C:/Users/Administrator/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe
ERROR: Project export for preset "Windows Desktop" failed.
EXIT=1
```

已做的补救：
- 创建 `export_presets.cfg`（preset 名 `Windows Desktop`，x86_64，未嵌 pck，排除 `tools/ shots/ docs/ build/`）
- 全盘搜索 `windows_release_x86_64.exe` 与 `*.tpz`：**均未找到**
- `export_templates/` 目录存在但为空

**安全下一步**（需要你操作）：
1. 打开 Godot 4.7.2 → 菜单「编辑器 → 管理导出模板」
2. 下载并安装 4.7.2 的导出模板（约 1GB）
3. 重跑：`godot --headless --path . --export-release "Windows Desktop" build/first-xi-xue-gui.exe`

在模板安装前，**没有 `.exe` / `.pck`，也没有 SHA-256** —— 这里不提供任何伪造的构建产物或成功状态。

---

## 八、其他未验证项

| 项目 | 状态 |
| --- | --- |
| 真人完整试玩（30 分钟一局） | **未做**。SmokeTest 是自动化，快进 25 分钟档只能证明不宕机，不能证明"前期割草→后期擦边求生"的体感 |
| 同屏 300~500 只 | 未达成。8 分钟档实测 138 只、25 分钟档长跑 290 只。原因是阶段三改为"刷怪率 − 击杀率"平衡后，同期玩家火力（whip+1~2 把）撑不到 300；这是平衡问题不是性能问题，需要真人试玩校准 |
| Android / iOS / Web / 主机 | 完全未验证，本专家不承诺 |
| 3D / 多人 / 联网 | 范围外 |

---

## 九、文件清单

**新增**
```
scripts/WaveTable.gd              177 行  波次表 / Boss 表 / 公式（纯 static）
scripts/PickupField.gd            195 行  三种掉落物 + 炸弹限流
scripts/ResourceField.gd          176 行  确定性可破坏物
tools/StageThreeShot.gd           118 行  三张渲染证据（Boss/败/胜）
tools/StageThreeShot.tscn
export_presets.cfg                        Windows Desktop preset（模板缺失，未成功导出）
shots/stage3_boss.png
shots/stage3_lose.png
shots/stage3_win.png
```

**改动**
```
scripts/Game.gd          重写难度段；新增 pickups/resources 接线、Boss 生成、胜利判定、金币公式
scripts/Enemy.gd         Boss 支持、contact_damage 6.0、_corpse_left 回收、删 boss_index
scripts/EnemyPool.gd     Boss 预留池位、boss_died 信号、尸体回收、max_alive 400、crowding()
scripts/weapons/WeaponManager.gd   4 处资源点判定（鞭弧/光环/手机环/子弹）
scripts/ui/HUD.gd        flash_boss()、倒计时、金币显示、BOSS 在场提示
scripts/ui/DeathUI.gd    胜负双版面 + 金币行 + 8 参数签名
scenes/Game.tscn         新增 Pickups / Resources 节点
tools/SmokeTest.gd       新增 103 条阶段三检查
```
