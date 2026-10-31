# 测试记录（阶段一 ~ 阶段四）

> 环境：Windows x86_64 / Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`) / D3D12 Forward Mobile / Intel UHD 630
> 记录时间：2026-10-26（阶段四追加于 2026-10-27）

本文件只记录**实际执行过**的命令与结果。没有执行的项一律标注"未验证"，不做推测性描述。

**当前状态：284 / 284 通过**（阶段一~三 229 + 阶段四 55），连续 4 次复跑全绿。

---

## 1. 导入校验

```bash
cd GameDemo/first-xi-xue-gui
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
```

- 退出码：`0`
- stderr：空
- 结论：所有 `.tscn` / `.gd` 解析通过，无缺失资源

---

## 2. 逻辑验收（headless）

```bash
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --headless --path . res://tools/SmokeTest.tscn
```

### 结果

| 轮次 | 退出码 | 通过 | 失败 |
|---|---|---|---|
| 阶段一（第 1 轮） | 0 | 59 | 0 |
| 阶段一（第 2 轮） | 0 | 59 | 0 |
| 阶段一（第 3 轮） | 0 | 59 | 0 |
| 阶段二接入后（第 1 轮） | 1 | 114 | 4 |
| 阶段二接入后（第 2 轮） | 1 | 115 | 3 |
| 阶段二接入后（第 3 轮） | 0 | **118** | **0** |
| 阶段二渲染修复后回归 | 0 | **118** | **0** |

### 全部检查项与实测值

**Step 1 移动与相机**
- 单指拖拽移动生效，位移 99.0 px
- 相机跟随玩家，屏幕中心偏差 24.9 px
- 相机平滑跟随已开启
- 键盘方向键移动生效，位移 66.0 px
- 远离原点（50k px）仍正常运行 = 无限地面

**Step 2 敌人生成与追踪**
- 清场后存活敌人数 = 0
- 同屏敌人达到 300 / 上限 420（文档目标 300~500，654 帧）
- 同点堆叠后平均散开 17.4 px（轻量分离生效）
- 敌人直线追踪玩家：400 → 346 px
- 贴脸接触扣血：100 → 90（距离判定，无物理体）
- 池复用的敌人恢复处理：位移 35.6 px
- 复用时贴图随种类切换（enemy_bag.svg）

**Step 3 自动攻击武器**
- 初始武器 = 鞭子（whip）
- 鞭子命中身前敌人（剩余 99989）
- 鞭子左右交替，背面也被扫到（剩余 99989）
- 光环灼烧贴身敌人
- 光环范围可视化显示（半径 86 px 与判定一致）
- 魔杖自动锁定并命中 300px 外敌人
- 站桩不动也能击杀（击杀 +6）

**Step 4 经验宝石与吸附拾取**
- 磁吸半径（90 px）外的宝石不会被吸
- 进入磁吸圈自动飞向玩家并拾取
- 贴脸宝石 0.2s 内被吃掉（吸附手感）
- 磁力被动生效：1.25 → 2.00 倍

**Step 5 升级三选一**
- 经验满后升级（Lv 3 → 4）
- 升级瞬间全树暂停
- 弹出 3 张卡（目标 3）
- 遮罩与卡片同时可见
- 卡片可点击
- 选卡后恢复游戏
- 选卡后确实生效（武器 `{whip:2, halo:1, wand:1}` / 被动 `{}`）
- 经验曲线 next = 5 + level²（Lv1 → 6）
- 一次大量经验可连升（Lv 4 → 6）
- 连续升级排队全部选完后自动恢复（2 轮）

**Step 6 暂停与重开闭环**
- 暂停菜单打开且全树暂停
- 暂停时 HUD 按钮切换为继续图标
- 暂停菜单期间不叠加升级卡（避免双重暂停锁）
- 再次点击恢复游戏
- 恢复后 HUD 按钮切回暂停图标
- 升级卡正常弹出
- 升级卡期间按暂停无效（升级优先级更高）
- 选完卡后恢复运行
- 重开生成新的游戏实例
- 重开后计时/击杀归零（0.18s / 0）
- 重开后武器重置为初始鞭子（`["whip"]`）
- 重开后没有残留暂停锁
- 死亡后弹出结算界面
- 死亡后停止游戏逻辑
- 结算界面重开后满血回到场上

**美术 SVG 接入**
- 玩家使用 player_front.svg
- 袋子敌人用 enemy_bag.svg
- 杯子敌人用 enemy_cup.svg
- 精英怪用 enemy_elite_box.svg（96px）
- 死神精英用 enemy_reaper.svg
- 精英体型 96 > 普通 48
- 精英血条默认显示
- 普通宝石用 gem_blue.svg
- 大宝石用 gem_orange.svg
- 蒜环用 halo_ring.svg
- 升级卡框用 ui_card_frame.svg

---

## 2.5 阶段二用例（Step 6 / 7 / 8，共 59 项）

**Step 6 统一数值管线（16 项）**

```
ok   伤害公式 1+0.10L：Lv0=1.00 / Lv5=1.50
ok   冷却公式 1-0.05L：Lv5=0.75（不是文档旧的 -8%）
ok   范围公式 1+0.07L：Lv5=1.35（不是文档旧的 +10%）
ok   生命公式 100+20L：Lv0=100 / Lv5=200
ok   力量公式 1-0.07L：Lv5=0.65（受击伤害 ×0.65）
ok   冷却等级钳制：Lv99 被压回 Lv5 的 0.75（地板 0.40 要到 Lv12 才触发）
ok   冷却地板 0.40 在 Lv12 生效（Lv5 内用不到，但公式必须写死）
ok   力量地板 0.50 在 Lv8 生效
ok   力量等级钳制：Lv99 被压回 Lv5 的 0.65
ok   等级上限 5：Lv6 不再超过 Lv5
ok   点生命上限 100→160 并补血 40→100（不是只涨上限）
ok   满级伤害被动让鞭弧伤害 10.0 → 15.0（+50%）
ok   满级冷却被动让鞭弧冷却 1.30s → 0.98s
ok   复位被动不改武器等级（whip 仍 Lv1）—— 两边解耦
ok   被动卡数量 = 7（目标 7）
ok   旧武器 id 'wand' 已改名为 'glowstick'
```

**Step 7 数据驱动武器（20 项）**

```
ok   WeaponDB 收录 6 把武器（鞭弧/光环/荧光棒/手机环/美工刀/灭火器）
ok   武器 whip / halo / glowstick / phone / blade / extinguisher 各有完整定义（6 项）
ok   whip        的 8 级伤害曲线单调不减（Lv8=17.0）
ok   halo        的 8 级伤害曲线单调不减（Lv8=9.6）
ok   glowstick   的 8 级伤害曲线单调不减（Lv8=33.0）
ok   phone       的 8 级伤害曲线单调不减（Lv8=13.6）
ok   blade       的 8 级伤害曲线单调不减（Lv8=19.5）
ok   extinguisher 的 8 级伤害曲线单调不减（Lv8=30.0）
ok   荧光棒 Lv8 伤害 33.0 > 鞭弧 Lv1 10.0（NUM_DESIGN §4.2 硬约束）
ok   whip（鞭弧）能造成伤害
ok   glowstick（荧光棒）能造成伤害
ok   phone（手机环）能造成伤害
ok   blade（美工刀）能造成伤害
ok   extinguisher（灭火器）能造成伤害
ok   光环给敌人上了减速状态（不是推开）
ok   被减速的敌人仍贴在玩家身边（位移 0.0 px，没有被推走＝没变成无声无敌）
ok   武器槽满 6 后不再抽新武器卡
```

**Step 8 进化配方（23 项）**

```
ok   配方表 3 条（鞭弧/荧光棒/光环）
ok   前置：力量被动 Lv0
ok   鞭弧 Lv8 但缺被动时不进化
ok   配方不满足时 candidates 为空
ok   血鞭倍率 dps×1.70 / area×1.50
ok   圣魔杖倍率 dps×1.50 / area×1.00
ok   圣蒜倍率 dps×1.40 / area×1.60
ok   三条配方分别绑定 伤害 / 冷却 / 范围 被动
ok   鞭弧 Lv8 + 力量 Lv1 满足配方
ok   满足配方后 candidates 非空
ok   开箱后鞭弧进化为 血鞭
ok   进化不占新武器槽（仍 1 把）
ok   进化后鞭弧伤害 17.0 → 28.9
ok   精英存活（等待期间没被武器顺手打死）
ok   精英死亡掉落宝箱（场上 1 只）
ok   走到宝箱上自动开箱并进化
ok   宝箱拾取后清场
ok   普通敌人死亡不掉宝箱
ok   X11 < X1 量级校验：6 把全进化 439.9 < 6 把未进化 354.7 × 3
ok   最强进化武器 dps/R 117.2 < 六把未进化之和 354.7
ok   已进化的武器不再出现在升级三选一里
```

### 阶段二排查记录：4 项首轮失败

**① `Member "level_up" is not a function`（Parse Error）**

`Player.level_up` 是 signal，不是方法。开箱失败补偿时误写成 `player.level_up()`。
改为 `player.gain_xp(player.xp_next)` —— 走真实升级路径，和玩家吃宝石触发的是同一条链。

**② 三个旧用例用了 `acquire("wand")`**

武器 id 已按美术口径改名为 `glowstick`，`acquire("wand")` 被 `WeaponDB.has_weapon()` 静默拒绝，
所以"魔杖命中 300px 外敌人"失败。改为 `glowstick` 后通过。

**③ 地板断言写错了被测对象**

我最初写 `Stats.value_at("cooldown", 99) == 0.40`，但 `value_at` 内部 `clampi(lv, 0, 5)`，
Lv99 被钳成 Lv5，结果是 0.75 —— **测试写错了，不是代码错了**。
改为直接核对公式下限 `maxf(FLOOR, 1 - 0.05*12)`，并额外验证"等级钳制确实生效"。

**④ 宝箱用例的精英在等待期间被打死了**

`_enemies.spawn(..., hp=1.0, ..., elite=true)` 之后 `_wait(0.1)`，
鞭弧在这 0.1s 内把它顺手打死 —— 于是"手动击杀"变成了"被武器打死"。
现象是 `chests_before=1`（宝箱已掉）、`elite.alive=false`（精英已死），
断言 `chest_count == before + 1` 自然失败。
改为给精英 99999 血量并先断言 `elite.alive`，再手动 `take_damage`。

> 这一类"TEST BUG 而非 CODE BUG"要单独标记。前 3 轮失败里有 3 项是测试自身问题，
> 只有 ① 是真代码错误。不做区分就会去改本来正确的逻辑。

---

## 2.6 阶段二窗口渲染证据

```bash
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --path . --resolution 720x1280 res://tools/StageTwoShot.tscn
```

- 退出码：`0`
- 输出：
  ```
  SHOT .../FirstXiXueGui/shot_stage2.png err=0 size=(720, 881)
  AVG_LUMA 0.2447 over 4712 samples
  WEAPONS ["whip", "halo", "glowstick", "phone", "blade", "extinguisher"]
  ALIVE 48  CHESTS 1
  ```
- 截图：`shots/stage2_final.png`

### 渲染修复记录：手机环 / 弹道被遮

**现象**：六把武器都装上了，HUD 六个槽位都在，但画面里看不到手机环，也看不到飞行中的美工刀。

**根因 1（看不见手机环）**

`_ensure_orbit_sprites()` 把精灵 `add_child` 到 `WeaponManager` 下，
而 `_update_orbits()` 写的是 `s.position = 世界坐标`。
`WeaponManager` 自己带父节点变换，于是手机被整体偏移到玩家视野外。
→ 改为 `s.global_position = pos`。

**根因 2（弹道被敌人盖住）**

荧光棒/美工刀/灭火器的精灵默认 `z_index = 0`，和敌人同层。
穿过 40 只敌人时会被完全遮挡，视觉上等于"武器没发射"。
→ 改为 `z_index = 3`（敌人之上，特效之下）。

**顺带修的手感问题**：美工刀的 `node.rotation += delta * 6.0` 让它每帧高速自转，
在弹射时看起来像一条模糊线。改为跟随速度方向 `rotation = b.vel.angle()`，
刀刃朝向正确，"甩出去"的手感出来了。

修完后重跑 SmokeTest：**118 / 118 通过**，无回归。

---

## 3. 真实窗口渲染冒烟（阶段一，保留）

```bash
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --path . --resolution 720x1280 res://tools/WindowShot.tscn
```

- 退出码：`0`
- 输出：
  ```
  Godot Engine v4.7.2.stable.official.ed1daf0bf
  D3D12 12_0 - Forward Mobile - Using Device #0: Intel - Intel(R) UHD Graphics 630
  SHOT .../FirstXiXueGui/shot_window.png err=0 size=(720, 881)
  AVG_LUMA 0.2187 over 4712 samples
  ```
- 截图：`shots/stage1_final.png`

### 这个检查能证明什么

- 渲染管线在真实窗口（非 headless）下正常工作
- 场景装配无缺失节点、无脚本运行时报错
- 画面不是黑屏（中心区平均亮度 0.2187）

### 这个检查不能证明什么

- **不等于人工试玩**。脚本只看一帧，没有真人操作验证手感
- **不等于手机触摸可用**。桌面 `emulate_touch_from_mouse` 与真机多点触控行为不同
- 窗口实际尺寸 720×881 是被本机 1600×900 屏幕高度截断的结果，不是设计分辨率

---

## 4. 本轮排查记录：地面"缺一块"

这是本轮花时间最多的问题，记录完整推理链供后续参考。

### 现象

截图中画面右下角露出大块城市背景（青绿天空 + 米色云），地面只铺了左上部分。

### 排查过程

1. 打印几何参数：视口 `1046×1280`、相机中心 `(0,-18)`、`canvas_transform` 缩放 `0.688`
2. 手算 `Ground` 的铺砖范围：`origin=(-1280,-1280)`、`cols=rows=10`，覆盖 `[-1280,1280]`，远超可视 `[-523,523]` → **算法是对的**
3. 把铺砖改成纯色 `draw_rect`：**满屏覆盖（96.8%）** → 铺砖循环没问题
4. 把铺砖改成同样 100 次 `draw_texture_rect`：**也满屏** → 贴图绘制没问题
5. 检查贴图：`ground_tile.svg` 256×256、不透明、四角色 `(0.15,0.20,0.30)` 与截图中"地面色"一致
6. 对比背景图：`bg_city_dusk.svg` 顶部色 `(0.106,0.165,0.290)`，与截图中"露出的部分"一致

### 根因

`scenes/Game.tscn` 里 `BG` 节点没有设 `z_index`（默认 0），而 `Ground` 是 `z_index = -10`。
**`BG` 这个 720×1280 的 `TextureRect` 画在了地面之上**，把地面盖住了右半边。

### 修复

```diff
 [node name="BG" type="TextureRect" parent="."]
+z_index = -20
 texture_filter = 1
```

### 顺带修的同类问题

`Ground` / `PropField` 都写死 `720×1280`，但 `project.godot` 用 `stretch/aspect="expand"`，
在非 9:16 窗口下实际视口会变宽（本例 1046×1280）。已抽出 `Ground.view_size(node)` 供两处共用。

---

## 5. 阶段三用例（Step 9 / 10 / 11，共 103 项）

全套累计 **229 项，0 失败 0 报错，退出码 0**。连续多次重跑稳定。

```
$ godot --headless --path . res://tools/SmokeTest.tscn
exit=0   ok=229  fail=0  error=0
========== 阶段一 + 二 + 三 验收 ==========
全部通过 OK
```

### Step 9a —— 时间波次表（25 项）

纯函数直对 params.json v3.1。

| 断言 | 实测 |
|---|---|
| 刷怪间隔 t=0 / 300 / 600 / 1800 | 1.100 / 0.775 / 0.450 / 0.450（600 后封底） |
| 单批数量 t=0 / 600 / 1800 / 5000 | 6 / 12 / 24 / 30（封顶） |
| 血量 t=0 / 900 / 1800 | 3.00 / 6.0 / 9.7（=3×(1+t/1800)^1.70） |
| 血量 37 点采样单调性 | 全程递增 |
| 5 段精英占比 | 0% → 6% → 10% → 14% → 18%，单调不降 |
| 杂兵血量倍率均值 | 1.1333（已计入 R 曲线） |
| 种类分布 | 30s 前纯杯子；120s 前不出快速兵；之后三色齐全 |
| 精英种类 | 10 分钟前只出蓝箱；之后红精英出现 |

### Step 9b —— Boss（25 项）

| 断言 | 实测 |
|---|---|
| 三档时间/血量 | 900s/2800、1500s/6100、1800s/11000 |
| 跨越判定 | 899→900 触发；900→901 不重复；1799→1800 触发（`>=` 边界） |
| 大步跨越 | 899→1900 **只返回最早一档**（t=900），不会一帧塞 3 只 |
| 实际生成 | is_boss=true、血量 2800、is_elite=true（复用血条/宝箱通路） |
| 接触伤害 | 18（=6×3.0），判定半径 34（params 钉死，不套 `size*0.36`） |
| 血条 | 常显 |
| 击杀 | boss_kills+1、必掉宝箱、has_boss() 归 false |
| 尸体回收 | 0.2s 内回收，池子有可复用对象 |

### Step 10a —— 掉落物（21 项）

| 断言 | 实测 |
|---|---|
| 三种掉率 | magnet 0.0005 / bomb 0.0002 / bento 0.0003 |
| 三张贴图存在 | `pickup_magnet` / `pickup_bomb` / `pickup_bento` 全部 `ResourceLoader.exists` |
| 炸弹每局上限 | 实际掉落 ≤ 4，超出 roll 转宝石（overflow 命中） |
| Boss 在场炸弹 | **6000 次掷点掉落 0 次** |
| 磁铁 | 12 颗远处宝石全部 age=999 |
| 炸弹清屏 | 屏内杂兵死、700px 外不死、**Boss 免疫** |
| 烤鸡回血 | 10 → 40（30% × 100），不超上限 |
| 重开清残留 | `clear_all` 后计数 0 |

### Step 10b —— 资源点（12 项）

| 断言 | 实测 |
|---|---|
| 视野内生成 | 56 个 |
| 确定性 | 走开 9000px 再回来，**56/56 原位恢复** |
| 受击扣血 | 一次半血 30 → 15，资源点仍在 |
| 归零拆除 | 从 `_alive` 移除 |
| 拆掉给金币 | coins_earned +1 |
| 空地不误判 | 远处命中返回 false |
| 武器接线 | `WeaponManager.resources` 已绑定 |

### Step 11 —— 结算（20 项）

| 断言 | 实测 |
|---|---|
| 空局金币 | 0 |
| 1000 杀 + 10min | 170（=120 + 50） |
| 精英 3 + Boss 1 | +58（=18 + 40） |
| 资源点金币 | +25 直加，不进乘数 |
| 胜利 ×1.5 | 253 → 367（只放大击杀/时长部分） |
| 失败版面 | 标题「你被淹没了」、金币行「◆ 253」、明细含 10:12 |
| 胜利版面 | 标题「撑到天亮了」、30:00、含 Boss/进化、标题为金色 |
| 真实死亡通路 | `take_damage` → 结算面板；`started=false` |
| 真实胜利通路 | elapsed 推到 1800 前 1 帧 → `won=true` + 结算 |

### Step 12 —— 25 分钟档长跑（7 项）

```
frames=400  wall=6665ms  alive=290  active=290  inactive=230  gems=13  pickups=0  res=33
```

- [x] 400 帧内刷出敌人（同屏 290）
- [x] 池总量 ≤ CAP 540 + Boss 预留 3（无泄漏）
- [x] 有可复用对象 230 个（击杀确实回收了）
- [x] 掉落物 / 宝石不超上限
- [x] 6665ms 未卡死（阈值 30s）

### 阶段三窗口渲染证据

```
$ godot --path . res://tools/StageThreeShot.tscn
exit=0  errors=0

SHOT [Boss 在场]  shots/stage3_boss.png  AVG_LUMA 0.2358  BOSS_HP 3965/6100
SHOT [失败结算]   shots/stage3_lose.png  AVG_LUMA 0.1062  LOSE_COINS 369
SHOT [胜利结算]   shots/stage3_win.png   AVG_LUMA 0.1065  WIN_COINS 1337
```

三张图均为真实窗口截图（非 headless），亮度采样排除了"截到纯黑图"的假成功。
**注意：这只证明渲染不崩、元素可见，不替代真人试玩。**

---

## 6. 阶段三排查记录（两个真 Bug）

### 6.1 `EnemyPool` 尸体泄漏（严重）

`Enemy._die()` 只置 `alive=false` + `forget()`，**没有任何地方把它搬回 `inactive`**。

后果：`active` 只增不减 —— 撑满上限后再也刷不出怪，Boss 也永远 `spawn` 失败。
这个 bug 阶段一/二没暴露，是因为当时没跑满池；阶段三的 Boss 需要预留池位时才撞上。

修复：
- `Enemy` 加 `_corpse_left` + `corpse_expired(delta)`，死亡后保留 0.2s 播淡出
- `EnemyPool._process()` 每帧回收过期尸体
- `alive_count()` 改为只统计 `alive == true`

**测试写法注意**：不能断言"对象不在 `active` 里" —— 池子会立刻把同一个实例复用成下一只怪，
`active.has(boss)` 又会变回 true。正确口径是"这只 Boss 已经死了，且池子没泄漏"。

### 6.2 `ResourceField` 走开再回来少几个资源点

生成用 `RADIUS+1`、回收用 `RADIUS+3`，中间留了一圈"回收了却不会再生成"的环；
再叠加相机 `position_smoothing` 的追尾滞后，实测走回来少 6 个（正好是 `cy=-3` 那一行）。

修复：
- 生成与回收用**同一个半径**（`reach = RADIUS + 1`）
- 锚点从**相机位置**改为**玩家位置**（相机有平滑滞后，玩家位置才是权威值）

修复后 56/56 原位恢复。

### 6.3 顺带修的

| 问题 | 修法 |
|---|---|
| `_flash_later` lambda 捕获已释放节点 → `Lambda capture at index 0 was freed` | 改传 `key` 字符串，回调时重查 `_alive` |
| `bind(Sprite2D)` 传 null 时抛 `Cannot convert argument 1 from Object to Object` | 同上，绕开节点引用 |
| `Enemy.boss_index` 从未被赋值 | 删除 |
| `EnemyPool.max_alive` 420 | → 400（对齐 params.json `spawn.max_alive`） |
| `_side` 跨用例残留导致鞭弧用例随机失败 | 用例开头显式复位 `_side = 1` 与冷却 |

---

## 7. 未执行 / 未验证

| 项目 | 状态 | 原因 |
|---|---|---|
| Windows `.exe` release 导出 | **失败（模板缺失）** | 见下方日志 |
| Android / iOS 导出 | **未执行** | 无模板、无设备 |
| 真机手指触控试玩 | **未执行** | 无移动设备 |
| 多人 / 联网 | **不适用** | 超出范围 |
| **阶段三：真人完整试玩一局（30 分钟）** | **未执行** | 只跑了自动化 + 快进长跑。不能证明"前期割草→后期擦边求生"的体感 |
| **阶段三：同屏 300~500 只** | **未达成** | 8 分钟档 138 只、25 分钟档长跑 290 只。阶段三改为"刷怪率 − 击杀率"平衡后，同期玩家火力撑不到 300。**是平衡问题不是性能问题**，需真人试玩校准 |
| **阶段三：窗口 720×1280 全尺寸** | **受限** | 本机屏幕高度不足，窗口实际 720×881；逻辑分辨率仍 1280 |
| **阶段四：Meta 加成的操作体感** | **未验证** | 数值上确实更强（有断言），但单线满级只 +15%，是否"明显变强"必须真人试玩 |
| **阶段四：经济节奏实测** | **部分验证** | 刷怪量与金币已用 `EconomyProbe` 实测（见 §8.5）；但其中的击杀比例 R 仍取自数值模型 0.42~0.74，真人落在哪一档未验证 |
| **阶段四：复活在 Boss 战中的体验** | **未验证** | 只给 3 秒无敌、不清场，"复活即被围"的观感未测 |

### Windows 导出失败的真实日志

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
1. 创建 `export_presets.cfg`（preset `Windows Desktop`、x86_64、未嵌 pck、排除 `tools/ shots/ docs/ build/`）
2. 全盘搜索 `windows_release_x86_64.exe` 与 `*.tpz`：**均未找到**
3. `export_templates/` 目录存在但为空

**在模板安装前没有 `.exe` / `.pck`，也没有 SHA-256** —— 不提供伪造的构建产物。

下一步（需要人工）：
1. Godot 4.7.2 → 菜单「编辑器 → 管理导出模板」→ 下载安装 4.7.2 模板（约 1GB）
2. 重跑上面的导出命令


---

## 8. 阶段四用例（Step 12，共 55 项）

### 执行命令

```bash
cd GameDemo/first-xi-xue-gui
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --headless --path . res://tools/SmokeTest.tscn
```

### 结果

| 轮次 | 退出码 | 通过 | 失败 |
|---|---|---|---|
| 阶段四接入后（第 1 轮） | 0 | **284** | **0** |
| 复跑 2 | 0 | **284** | **0** |
| 复跑 3 | 0 | **284** | **0** |
| 复跑 4 | 0 | **284** | **0** |

`284 = 阶段一~三 229 + 阶段四 55`。

### 检查项与实测值（`[Step12] 金币 Meta 商店`）

**数据表对齐**
- 商店 5 条成长线（攻击/生命/冷却/磁力/复活）
- 成长线顺序 `["damage", "max_hp", "cooldown", "magnet", "revive"]`
- 攻击价格曲线照抄 params.json（`[200, 500, 1200, 3000, 7000]`）
- 复活价格 2500/8000
- 等级上限：磁力 3 / 复活 2（不是全都 5）

**购买闸门**
- 0 金币时攻击买不起
- 买不起时 `buy()` 返回 false，金币与等级都不变
- 买满后 `price_of()` 返回 −1（不是 0，否则 UI 会显示成"0 元可买"）
- 满级后再买不扣钱（仍 9500）

**入账与落盘**
- 结算入账 500 金币
- 重新读盘后仍是 400 金币 / 磁力 Lv1（真落盘）
- 存档文件 `user://save.json` 存在

**乘数**
- 攻击满级 ×1.15（+3% × 5）
- 冷却满级 ×0.85（−3% × 5）
- meta 满级总伤害乘数 ×1.353 ≈ params `_note` 的 1.35
- 升级卡池仍是 7 条被动（meta 不往局内塞卡）

**变强生效**
- 开局 `damage` 基线 = 1.15
- 开局 `cooldown` 基线 = 0.85
- 没买生命时 `max_hp` 仍是 100（乘数不串线）
- 伤害 Lv5 × meta：1.50 → **1.725**（乘算；加算会是 1.650）
- 冷却 Lv5 × meta：0.75 → **0.637**
- 生命满级：开局 150 血

**复活**
- 开局携带 2 次；两次都能消耗；用完后返回 false
- 有复活时不进结算界面，`started` 仍为 true
- 复活后满血 100%、带 3.0s 无敌
- 复活用完后再次死亡 → 正常进入结算

**结算入账与防重复**
- 构造局 +202 金币 → 246 → 448
- 持有总额显示「持有 ◆ 448」
- 商店入口显示「金币商店 · 4 项买得起」
- 重复调用 `_finish` 不会二次入账（仍 448）

**商店 UI**
- 默认关闭 → 打开后全树暂停 → 列出 5 行
- 1000 金币时磁力按钮可点 → 点后 Lv1、1000 → 900
- 0 金币时攻击按钮禁用
- 顶栏余额同步「◆ 0」
- 关店后隐藏，且**仍保持暂停**（不会让游戏在结算面板后面偷跑）
- 关店后结算界面仍在

**跨局持久**
- 重开一局后金币 300 / 磁力 Lv2 都还在
- 新局 `magnet` 基线 ×1.20、`max_hp` 基线 110
- 新局复活次数按等级重置

### 阶段四排查记录：两处"陈年"假失败

这两条都不是 Step 12 引入的产品 bug，而是**测量方法本身有问题**，被本轮改动放大后暴露。

**① 同屏密度断言会飘（实测 73 / 94 / 111 / 146 / 155 / 164 / 165）**

原因：同屏数 = 刷怪率 − 击杀率，击杀率取决于 `_auto_pick` 抽到了什么卡。一边自动选卡一边测密度，等于让断言赌抽卡运气。
`seed(20261026)` 无效 —— `randf` 调用次数受帧时序影响，同一颗种子两次跑仍得到 164 / 111。
修法：`_pin_probe_build()` 固定构筑（鞭弧 Lv2 + 光环 Lv1、被动全 0）后再测。修复后稳定 146~165。

**② 升级弹窗抢暂停锁 → "再次点击恢复游戏"假失败**

升级优先级高于暂停菜单（Step 5 的设计，正确）。任何用例只要在等待期间"恰好攒够经验"，整树就暂停，后续"武器还开火吗""恢复游戏了吗"全部假失败。
修法：`_prep()` 统一冻结经验条（`xp_next = 2^30`），要测升级本身的 Step 5 显式传 `freeze_xp = false`。

### 阶段四窗口渲染证据

```bash
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --path . res://tools/StageFourShot.tscn
```

| 文件 | 内容 | AVG_LUMA |
|---|---|---|
| `shots/shot_stage4_settle.png` | 结算面板：`◆ +369` / `持有 ◆ 1799` / `金币商店 · 2 项买得起` | 0.1037 |
| `shots/shot_stage4_shop.png` | 商店：2 满级（绿点 + 已满级）/ 2 买得起 / 1 买不起（红色价格） | 0.1245 |
| `shots/shot_stage4_bought.png` | 买冷却 Lv1→Lv2：`×0.97 → ×0.94` 变 `×0.94 → ×0.91`，余额 1799 → 1099 | 0.1244 |

亮度采样用于排除"截到一张纯黑图"的假成功。截图脚本退出前会把存档恢复成初始值，不污染玩家进度。

### 8.5 局外经济测算（`EconomyProbe`，非通过/失败型）

这不是用例，是**测量工具**：它不判断对错，只把数字打出来，让定价有据可依。

```bash
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
  --headless --path . res://tools/EconomyProbe.tscn
```

数据源刻意都指向游戏本身，不另写公式：刷怪量用 `WaveTable` 逐 `DT=0.05` 积分（复刻 `Game._process` 的计时器）、
金币直接调 `Game.coin_reward()`、价格直接读 `MetaSave.TRACKS`。

```
刷怪积分 0~1800s：入场 49,083 只 → Boss 战压制扣减 2,600 只 → 实际 46,483 只
精英 174 只 / Boss 3 只 / 全表买满 49,250 金币

击杀比例   胜局击杀   金币    单线买满(攻击)  全表买满
0.42      19,522    4,575    2.60 局       10.77 局
0.62      28,819    6,555    1.82 局        7.51 局
0.74      34,397    7,747    1.54 局        6.36 局

存活 5:00  击杀 1,381   金币 190    → 首局即可买 生命/磁力
存活 25:00 击杀 21,280  金币 3,202  → 加 复活 Lv1
```

结论写在 `STAGE4.md §3`（含 `coins_per_kill` 0.05 vs 0.12 的口径对照与"不改"的依据）。
