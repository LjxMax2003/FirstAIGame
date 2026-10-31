# 《守艺人·百工夜行》动画实施方案（走路 / 击败）

> 版本：v1.0 · 2026-10-27
> 适用范围：`GameDemo/first-xi-xue-gui`（Godot 4.7.2，Mobile，720×1280 竖屏）
> 本文只定**方案、参数与验收标准**。所有代码、SVG 帧图、测试与截图脚本均由 AI 实施；本文不产生任何构建产物，也不改动现有游戏数值。
> 文中路径均相对工作区根目录 `F:\AITemp\QoderGameFirst\`。

---

## 0. 一页结论

| 项目 | 推荐做法 | 新增图片 | 何时做 |
|---|---|---|---|
| 玩家走路 | 前后贴图切换 + 程序化步伐（起伏/侧摆/转向压扁） | **0**（`shouyiren_back.svg` 已存在但未使用） | 第一优先 |
| 杂兵/精英走路 | 按“纸 / 风筝 / 提线木偶 / 墨 / 傩面”五种材质语法做程序化运动 | **0** | 第一优先 |
| Boss 走路 | 三只 Boss 各自的动作签名（鼓的滚动、傩的操偶、灯的悬浮） | **0**（三张 Boss 图已生成） | 第二优先（需接图） |
| 击败效果 | 本体“对折上飘淡出” + 同图残影纸屑 + 精英/Boss 开炉爆发 | **0**（复用 `kailian_burst` 等现有 FX） | 第一优先（先修现有“看不见的死亡”） |
| 2~3 帧纸片抖动 | 仅作为 L1 精修，玩家 + 3 种杂兵共 10 张同画布 SVG | 10（可选） | 看第一版实机再决定 |

**一句话**：这套资产是单帧 SVG，最划算的不是先补帧，而是先把**已有的单帧做出“纸/墨/影/木偶”的运动语法**；击败效果则先修一个真 bug（现在死亡是瞬间全透明，玩家根本看不到动画）。

---

## 1. 交付边界（先说明白）

1. **本文 = 实施方案**。下面的 GDScript 片段是“实现草稿/接口约定”，不是已落地的代码；最终代码由 AI 按本文写入仓库。
2. **图片也由 AI 生成**。L1 帧图沿用现有程序化 SVG 生成器（`assets/craftkeepers/sprites.mjs`）扩展 `pose` 参数生成，**不允许**用图片模型重绘，避免画布尺寸、脚底锚点、配色漂移。**当前状态**：10 张帧图已交付，但是由母图逐元素派生（套 `<g transform>`）直接落盘的，`sprites.mjs` 的 `pose` 参数化仍待程序侧补——详见 §5.3 交付状态。
3. **不改战斗数值**：不改 `params.json`、不改 `WaveTable` 的血量/时间/速度/伤害/刷怪率/暴击等。两处例外都只影响表现：`CORPSE_TIME` 0.20→0.26 只改尸体回收节奏；3.3 节的 Boss 命中半径“钉死”是把旧值原样搬过去，目的仍是保持现状。
4. **不引入新依赖**：不引入粒子插件、不引入骨骼动画、不引入第三方 UI 库。
5. **不做“假动画”**：如果某个效果需要单独部件（例如提灯独立摆动），本轮不做；等确实需要时再加小图，而不是把整张人物图切碎。

---

## 2. 现状盘点：代码给了什么，卡在哪

### 2.1 事实与依据

| # | 事实 | 依据 | 对动画方案的影响 |
|---|---|---|---|
| 1 | 全项目只有 `Sprite2D`，没有 `AnimatedSprite2D` / `AnimationPlayer` / `GPUParticles2D` / `CPUParticles2D` / `Tween` / `hframes` | 全仓 grep 无命中；`scenes/Enemy.tscn`、`scenes/Player.tscn` 均为单 `Sprite2D` | 不能假设有动画管线；方案必须用“代码驱动 + Sprite2D 池” |
| 2 | 敌人走路只有一条正弦：`art.rotation = sin(_walk)*0.07`、`art.position.y = -abs(sin(_walk))*1.6` | `GameDemo/first-xi-xue-gui/scripts/Enemy.gd:163-165` | 所有敌人（含 Boss）共用同一种“抖”，没有材质差异 |
| 3 | 玩家走路只有上下 2.5px 起伏，且没有左右/背面切换 | `GameDemo/first-xi-xue-gui/scripts/Player.gd:187-193` | 玩家“走”的识别度最低；`PLAYER_BACK` 常量存在但无人使用（`scripts/Art.gd:9`） |
| 4 | **死亡动画实际不可见**：`_die()` 里把节点 alpha 直接设 0，`set_process(false)` 又让敌人不再更新 | `GameDemo/first-xi-xue-gui/scripts/Enemy.gd:203-217`（alpha 在 213 行） | 必须先把“淡出”改成“逐帧动画”，否则任何击败特效都缺少主体 |
| 5 | 尸体保留 0.20 秒后由池回收；回收逻辑在池里，不在敌人自己 | `Enemy.gd:13`（`CORPSE_TIME`）、`Enemy.gd:220-226`、`EnemyPool.gd:93-106` | 死亡动画必须由池驱动（`corpse_tick`），不能写在 `Enemy._process`，因为死亡时 process 已关 |
| 6 | 击杀只掉经验/掉落，**没有任何死亡特效调用** | `GameDemo/first-xi-xue-gui/scripts/Game.gd:248-252` | 新增 `KillFx` 节点并在这里接线 |
| 7 | 画布尺寸是硬契约：`size = max(tex.x, tex.y)`、`touch_radius = size*0.36`（Boss 固定 34）、`art.offset = -tex.y/2 + 4` | `Enemy.gd:69/72/74` | **禁止用 `hframes` 横向拼帧**：贴图宽度会翻倍，`size`、`touch_radius`、`offset`、血条位置全被带偏 |
| 8 | `scale` / `art.position` / `art.rotation` 已有多个写入方：出生弹缩、走路抖动、死亡放大 | 出生 `Enemy.gd:95-96,128-134`；走路 `163-165`；死亡 `203-217` | 必须收敛到**每帧从基准值重算的一个出口**，否则效果会互相累加、复用后残留 |
| 9 | 复用复位不完整：`setup()` 复位了 `art.rotation/position/modulate/flip_h`，但**没有复位 `art.scale`** | `Enemy.gd:83-96`、`EnemyPool.gd:81-85` | 一旦走路用 `art.scale`，必须在 `setup()` 补一行复位 |
| 10 | 同屏池上限 540，存活上限 400；特效池只有 64，且属于武器 | `EnemyPool.gd:9-15`、`scripts/weapons/WeaponManager.gd:16` | 击杀特效必须独立池、硬上限、可降级；不能和武器抢 64 个槽 |
| 11 | 现有 FX 已经有成熟的“取用/回收/缩放/淡出”模式 | `WeaponManager.gd:400-458`、`class Fx` 在 475 行 | `KillFx` 直接复制这套模式，不需要新抽象 |
| 12 | 三只 Boss 目前都传 `"reaper"`（同一张 80×112 图），三张新 Boss 图尚未接入 | `Game.gd:235-246`（244 行传 `"reaper"`）、`Enemy.gd:104-118`、`assets/craftkeepers/manifest.json:359-382` | Boss 动作签名要等“按 Boss 档接图”这一步；这一步会牵动命中半径，见 3.3 |
| 13 | 霓虹/摊位是 `_draw()` 批量绘制，没有可查询的“灯笼坐标” | `scripts/PropField.gd:4-6,29+` | “颜色飞回最近灯笼”首版落在**玩家手里的百工灯**上；不要为此虚构世界坐标 |

### 2.2 关键结论

- **不是“缺动画系统”，而是“缺运动语法”**。现有正弦已经证明程序化路线可行，只是所有敌人共用一条曲线。
- **死亡效果是 0，而不是弱**。`Game.gd:248-252` 只掉经验；`Enemy._die()` 的淡出因为 alpha 立即归零而肉眼不可见。修好这一条，收益比补 20 张帧图更大。
- **画布尺寸不能动**。因此“2~3 帧”必须走**独立同尺寸 SVG 文件**，不能走 `hframes` 图集；这条在 5.2 节会再强调一次。
- **三张 Boss 图是 160×160 / 128×160**，比旧的 80×112 大一截；`touch_radius` 因 Boss 分支固定 34 不受影响，但 `hit_radius()` 会用 `size*0.36` 从 40.3 涨到 57.6（面积约 +104%），必须在接图时钉死，见 3.3。

### 2.3 方案对比（为什么选 L0 优先）

| 方案 | 做法 | 图片成本 | 主要风险 | 结论 |
|---|---|---|---|---|
| A 全帧图集 | 每种敌人 8 帧，`hframes` 横向切 | 40+ 张 | 贴图宽度变 N 倍，`size/touch_radius/offset` 全错（`Enemy.gd:69/72/74`）；移动端内存和批处理都变差 | **否** |
| B 程序化 + 同图残影（L0） | 代码驱动 `Sprite2D` 变换；击杀复用敌人自己的贴图 | **0** | 单帧轮廓变化有限，需要调参 | **是，第一版** |
| C L0 + 2~3 帧（L1） | 同画布独立 SVG，贴图轮换 | 10（可选 20） | 风格漂移、切换开销 | **可选，实测后决定** |
| D 骨骼/Skeleton2D | 切分关节、绑定 | 高 | 素材是整张纸片，没有关节；与“纸片抖动”风格相悖 | **否** |

结论：**L0 是唯一能在不碰画布契约、不增加素材成本的前提下，把“走路 + 击败”同时做完的方案**；L1 只做“锦上添花”，不阻塞交付。

---

## 3. 走路方案

### 3.1 总原则：先材质，后帧数

设计文档把敌人材质限定为“纸、墨、影、木偶、褪色的糖/灯”，并明确“2~3 帧纸片抖动即可，不需要骨骼”（`docs/theme/craftkeepers/design.md:590`、`美术资产映射.md:232`）。因此走路不做统一曲线，而是给每种材质一条**可读的运动语法**：

| 材质 | 运动语法 | 玩家的眼睛读到什么 |
|---|---|---|
| 纸 | 轻、飘、被风翻面 | “这不是活物，是被风吹来的碎纸” |
| 风筝 | 高频颤、被线拽着走 | “它很快，而且不受控” |
| 木偶 | 顿挫、提线、关节滞后 | “有人在上面提着它” |
| 墨 | 缓慢呼吸、边缘涌动 | “它很厚，打不动” |
| 傩面 | 沉重踏步、面具先到 | “它有仪式感，也有重量” |
| 灯（Boss） | 悬浮、无脚、吸光 | “它不是走过来的，是飘过来的” |

### 3.2 玩家（0 新图，最高优先）

#### 3.2.1 现状问题

- 只有上下 2.5px 起伏（`Player.gd:187-193`）。
- 没有背面：`Art.PLAYER_BACK` 声明了但全仓无引用（`Art.gd:9`）；新素材 `characters/shouyiren_back.svg`（64×80，提灯）已经生成。
- 转向只做 `flip_h`，没有“转身”的重量感。

#### 3.2.2 推荐做法

1. **前后贴图切换（零新图）**
   - 条件：`dir.y < -0.55` 且 `abs(dir.y) > abs(dir.x) * 1.2`，持续 0.08s 后切到 `PLAYER_BACK`；否则回 `PLAYER_FRONT`。
   - 用 0.08s 迟滞，避免斜向走时来回闪。
   - 两张图同为 64×80，`art.offset = (0,-18)` 不变（`Player.tscn`），不会跳脚。
   - 在 `_ready()` 预取正面/背面两张贴图，避免第一次转身时 `load()` 卡一下。
   - 切换瞬间做 0.12s 的横向压扁 `art.scale.x = 1 - 0.12*sin(pi*t)`，把“换图”的突变藏在压扁里。

2. **步伐（在现有基础上加两个通道）**
   - 保留 `_walk_phase += delta * 11.0`，但频率乘 `speed` 倍率，速度被动加成时步频同步变快。
   - 上下：`y = -absf(sin(p)) * 2.5`（现有）。
   - 左右：`x = sin(p * 0.5) * 1.1`（半步周期的重心左右换脚）。
   - 前倾：`art.rotation = clampf(vel.x / 220.0, -1, 1) * 0.045`；向上走时 0（背面不倾）。
   - 落地压缩：在 `absf(sin(p))` 的谷底给 `art.scale = Vector2(1.04, 0.96)`，持续约 0.08s；幅度不超过 5%，避免 64px 角色“橡皮化”。

3. **待机**
   - 不移动时 `art.position.y = sin(t * 2.2) * 0.8`，呼吸感；不要停止所有表现，否则角色像贴纸。
   - 所有通道（`art.position.x/y`、`art.rotation`、`art.scale`）每帧从基准值重算，不做累加；松手时显式归零，避免角色“歪着停住”。

#### 3.2.3 为什么不做“提灯独立摆动”

提灯已经画在 `shouyiren_back.svg` 里，整张图无法只旋转灯。要独立摆动必须新做 `lantern_glow.svg` 子节点并处理手部锚点，属于 P2；本轮用整体 0.045 rad 的轻微侧倾代替，成本 0，视觉上已经“活”。

### 3.3 五种敌人 + 三只 Boss

> 说明：以下 `w = _walk`（现有相位，已随速度变化，`Enemy.gd:163`）；`k = clampf(48.0 / size, 0.4, 1.0)` 是**旋转幅度归一化**，让 96/160px 的精灵不会像橡皮一样甩。48px 杂兵旋转上限 0.18 rad、位移上限 4px；精英/Boss 因体型更大，位移上限放宽到 8~10px（悬浮），旋转仍不超过 0.18 rad。

| kind（现有键） | 新素材 | 材质 | 动作签名 | 程序化公式（草稿） |
|---|---|---|---|---|
| `cup` | `paper_scrap.svg` 48×48 | 纸屑 | 风吹翻滚、偶尔翻面 | `rot = (sin(w)*0.13 + sin(w*2.3)*0.04) * k`；`oy = -abs(sin(w*1.4))*2.6`；每约 0.9s `flip_h` 翻转一次 |
| `fast` | `broken_kite.svg` 48×48 | 断线纸鸢 | 高频颤 + 被线拽的倾斜 | `rot = lean*0.12 + sin(w*3.0)*0.045`；`oy = -abs(sin(w*2.0))*1.6`；`ox = sin(w*1.7)*1.2`；每 1.6s 一次衰减“顿拽”脉冲 |
| `bag` | `broken_puppet.svg` 48×48 | 断线傀儡 | 提线顿挫、关节滞后 | `step = floor(w/3.6)`；`f = fmod(w,3.6)/3.6`；`oy = -2.8*(1-pow(1-f,3))`；`rot = -0.04 + 0.08*(1-f)`；`art.scale = Vector2(1+0.05*f, 1-0.06*f)` |
| `box`（精英） | `ink_blob_elite.svg` 96×96 | 墨渍 | 缓慢呼吸、边缘涌动 | `b = 1 + 0.055*sin(w*0.55)`；`art.scale = Vector2(1/b, b)`；`rot = sin(w*0.4)*0.02` |
| `red`（精英） | `faceless_nuo_elite.svg` 96×96 | 残面傩 | 沉重踏步、面具先到 | `f = fmod(w,4.6)/4.6`；`oy = -3.0*(1-pow(1-f,3))`；`art.scale = Vector2(1+0.04*f, 1-0.07*f)`；`rot = sin(w*0.5)*0.03*k` |
| `reaper`（当前 Boss 基底） | `lost_visage.svg` 80×112 | 破面 | 失重漂浮 | `oy = -4.0 + sin(w*0.8)*4.0`；`rot = sin(w*0.5)*0.04*k`；alpha 0.92~1.0 轻微闪烁 |

**朝向规则（零成本、但能显著减少“滑行感”）**：
- `bag`、`red`、`reaper` 与三只 Boss 有人形正面，按 `to_player.x` 做 `art.flip_h`，带 0.15s 迟滞；
- `cup`、`fast` 是碎纸/风筝，不翻面（碎屑没有“正面”）；
- `setup()` 已经复位 `flip_h`（`Enemy.gd:93`），复用安全。

**Boss 三档（接图后）**：档位与贴图的对应来自 `美术资产映射.md:159-161`（15:00 哑鼓 / 25:00 无面傩 / 30:00 长夜灯），名字与时间来自 `策划案.md:446-448`。

| Boss | 素材/尺寸 | 动作签名 | 程序化公式（草稿） |
|---|---|---|---|
| 哑鼓（15:00） | `boss_drum.svg` 160×160 | 鼓身滚动、有拍点 | `rot = sin(w*0.6)*0.045`；`oy = -abs(sin(w*1.2))*4.0`；每拍把 `base` 乘 `1+0.03*sin(w*1.2)` |
| 无面傩（25:00） | `boss_faceless_nuo.svg` 128×160 | 操偶步、面具领先 | `f = fmod(w,5.2)/5.2`；`oy = -3.0*(1-pow(1-f,3))`；`rot = 0.02 + sin(w*0.7)*0.025`；呼吸 `scale.y 0.98~1.02` |
| 长夜灯（30:00） | `boss_long_night_lantern.svg` 160×160 | 悬浮、吞光 | `oy = -6.0 + sin(w*0.8)*4.0`；`rot = sin(w*0.5)*0.02`；可选挂 `boss_lantern_drain` 子节点缓慢旋转（alpha 0.30） |

> 长夜灯按设计文档目前是“压轴登场 + 立即判胜”的演出（`策划案.md:452`），不需要真打；但它的走路/悬浮仍会被玩家看到几秒，值得做对。

#### 3.3.1 Boss 接图必须同时钉死命中半径（否则平衡被动）

- 现状：`lost_visage` 是 80×112 → `size = 112` → `hit_radius() = 112*0.36 = 40.32`。
- 接图后：Boss 图 160×160 → `size = 160` → `hit_radius() = 57.6`，命中半径 +43%，**命中面积约 +104%**。
- 武器命中全部走 `e.hit_radius()`（`WeaponManager.gd:169/304/347`、`EnemyPool.gd:236`），Boss 血量是按“70% 火力 / 30 秒击杀”反推的（`WaveTable.gd:38-42`），命中面积翻倍会直接破坏这条校准。
- **方案**：在 `WaveTable` 增加 `BOSS_HIT_R := 40.0`（等价旧值），`Enemy.setup()` 里 Boss 分支写入 `hit_r`，`hit_radius()` 返回该值；`touch_radius` 仍为 34（`Enemy.gd:72`，`WaveTable.gd:50`），接触伤害逻辑完全不变。
- 这不是改数值，是**把旧命中半径原样搬过去**；验收时用 `SmokeTest` 里现有的 Boss 行为用例（`SmokeTest.gd:1069/1097`）确认回归。

### 3.4 统一出口：`_present()`

现状三个通道各有 2~3 个写入方（出生、走路、死亡）。推荐在 `Enemy.gd` 增加一个每帧出口，所有表现都从基准值重算：

```gdscript
# 草稿：AI 实施时按现有命名风格整理
func _present(delta: float) -> void:
    var base := Vector2.ONE * _spawn_scale   # 出生弹缩
    var rot := 0.0
    var ox := 0.0
    var oy := 0.0
    # 走路签名只写 rot/ox/oy，并把 base *= 缩放（不要直接覆盖 base）
    # ...
    scale = base
    art.rotation = rot
    art.position = Vector2(ox, oy)
```

要点：
- 出生弹缩仍用节点 `scale`（`Enemy.gd:95-96,128-134`），走路压缩用 `art.scale`，死亡用节点 `scale`；三者互不覆盖。
- 走路里所有缩放都必须**乘在 `base` 上**（`base *= Vector2(...)`），否则会覆盖出生弹缩；这是“先弹出来、再呼吸”能同时成立的前提。
- `art.scale` 必须在 `setup()` 补 `art.scale = Vector2.ONE`（当前缺，`Enemy.gd:83-96`）。
- `reaper` 的 alpha 闪烁走节点 `modulate.a`，受击闪红仍走 `art.modulate` 的 RGB；两者相乘，不会互相覆盖。
- 死亡时 `set_process(false)`，`_present()` 不再跑；死亡动画改由 `corpse_tick()` 驱动（见 4.1），避免两套逻辑抢同一通道。
- 每帧重算而不是累加，复用后的残留问题会自然消失。

---

## 4. 击败效果方案（0 新图，先修 bug）

### 4.1 第一步：让死亡“看得见”

#### 现状

`Enemy._die()`（`Enemy.gd:203-217`）：
- 立刻 `set_process(false)`；
- `scale = 1.25`；
- `modulate = Color(1,1,1,0)` —— **alpha 直接归零**；
- 尸体留 0.20s 后被池回收。

所以玩家看到的其实是“敌人瞬间消失”，没有放大、没有淡出。

#### 推荐：0.26s 三段时间轴，由池驱动

```gdscript
const CORPSE_TIME := 0.26   # 原 0.20；0.26 ≈ 60fps 下 16 帧，折叠 + 淡出都看得见

func _die() -> void:
    # ... 原有 alive/forget/emit 不动
    # 删除原来的 scale = 1.25 与 modulate.a = 0，并从 1.0/全不透明开始
    art.scale = Vector2.ONE
    art.position.x = 0.0
    _corpse_total = CORPSE_TIME * (1.6 if is_boss else (1.2 if is_elite else 1.0))
    _corpse_spin = randf_range(-0.42, 0.42)
    _corpse_left = _corpse_total

func corpse_tick(delta: float) -> bool:
    if alive:
        return false
    _corpse_left -= delta
    var p: float = 1.0 - clampf(_corpse_left / _corpse_total, 0.0, 1.0)  # 0→1
    var fold: float = clampf(p / 0.42, 0.0, 1.0)
    var fade: float = clampf((p - 0.30) / 0.70, 0.0, 1.0)
    scale = Vector2(1.0 + 0.22 * fold, 1.0 - 0.30 * fold)   # 纸片对折
    art.rotation = _corpse_spin * fold * fold
    art.position.y = -12.0 * p                              # 上飘
    modulate.a = pow(1.0 - fade, 1.3)
    return _corpse_left <= 0.0
```

调用点只有一处：`EnemyPool.gd:104` 的 `if e.corpse_expired(delta)` 改为 `if e.corpse_tick(delta)`。池的注释已经写明“死亡时 Enemy 的 process 已关，问不到它”（`EnemyPool.gd:93-106`），这条路径是现成的。

时间轴：

```
0 ms     死亡：本体开始对折；残影向外飞；经验宝石落地（现有 GemPool）
60 ms    残影达到最大位移；本体折叠约 50%
110 ms   本体折叠完成（scale.y ≈ 0.70），开始淡出
200 ms   残影消失
260 ms   本体回收进池（CORPSE_TIME）
```

**为什么是 0.26 而不是更长**：
- 0.20 只有 12 帧，折叠 + 淡出挤在一起；0.26 有 16 帧，足够读。
- 池容量 540、存活上限 400（`EnemyPool.gd:9-15`），30 kills/s 时多留 0.06s 只多占约 8 个槽；炸弹清屏 400 只同时死亡时最多晚 0.06s 回收，可接受。
- 精英/Boss 可单独把 `_corpse_total` 放宽到 0.32 / 0.42，体现重量；它们数量少，不占池。

复位：`setup()` 已复位 `modulate/art.modulate/art.rotation/art.position`（`Enemy.gd:83-96`），`EnemyPool.modulate_free()` 复位节点 `modulate/scale`（`EnemyPool.gd:81-85`）；只需补 `art.scale`。

### 4.2 第二步：三层击杀反馈

#### 4.2.1 为什么不做“每杀一个都飞一颗光点”

“归色”在现有代码里**已经实现了**：每次击杀 `Game._on_enemy_died` 都会 `gems.spawn(pos, xp)`（`Game.gd:248-252`），经验宝石就是 `light_bloom.svg`（`Gem.gd:19`），进入磁吸圈后会飞向玩家（`Gem.gd:34-58`）。再给每只怪额外加一颗“归色光点”，会和宝石重复，画面上是两颗一样的光点抢戏。

因此拆成两拍，叙事更清楚：
- **散**：死亡瞬间，同图残影像纸屑一样散开；
- **归**：经验宝石（现有）飞回玩家手里的百工灯。

设计文档的“颜色飞回最近灯笼”（`策划案.md:240/428`）首版落在玩家身上，因为摊位/灯笼是 `PropField._draw()` 的装饰绘制，没有可查询坐标（`PropField.gd:4-6,29+`）；等真有“灯位 API”再改目标，不在本轮虚构。

#### 4.2.2 三层参数

| 层级 | 触发 | 同图残影 | 爆发图 | 震屏 | 备注 |
|---|---|---|---|---|---|
| T0 杂兵 | 每次普通击杀 | 3 片，0.20s | 无 | 无 | 残影用敌人自己的贴图，天然同色同剪影 |
| T1 精英 | `elite_died` | 6 片，0.28s | `kailian_burst.svg` ×0.7，0.35s | 3px / 0.12s | 金/朱砂，符合“开炉/开脸” |
| T2 Boss | `boss_died` | 12 片，0.38s | `kailian_burst.svg` ×1.5，0.5s | 5px / 0.22s | 只放一次，不叠 |

- 残影行为：从死亡点向随机方向飞 20~50px，速度 70~180px/s，阻力 6/s，缩放 0.55→0.15，旋转 ±6rad/s，alpha 1→0（`pow(1-t,1.4)`）。
- 残影贴图 = 敌人自己的贴图（把 `Enemy._art_for` 改为公开的 `Enemy.art_for(kind, tier)`，Boss/精英按 tier 取图），因此纸屑就是纸的碎裂、墨渍就是墨的飞溅，**不需要新画碎屑**。
- `kailian_burst` 是现有 P0 资产（`assets/craftkeepers/manifest.json:255-262`，48×48），语义就是“开炉/进化爆发”，用作精英/Boss 死亡的开炉瞬间不违和。代码里走 `Art.FX_EVOLVE`（`Art.gd:47`），集成后自动指向新图，不硬编码文件名。
- 震屏只给 T1/T2；**不要每次命中都震**（设计文档的“轻微屏幕震动”在 `策划案.md:592`，但 20 次/秒的命中会让手机用户晕）。普通命中的“金火星”已经由 `WeaponManager.spawn_spark()` 实现（`WeaponManager.gd:400-408`）。玩家受击震屏可选，不阻塞本轮。

### 4.3 `KillFx` 节点与池

新增 `scripts/KillFx.gd`，挂在 `World/KillFx`（`scenes/Game.tscn` 的 `World` 下、`EnemyPool` 之后，`z_index = 0`；宝石在 `z_index = 1`、掉落物在 2，见 `Game.tscn:46-58`）。

接口：

```gdscript
const FX_CAP := 96          # 预分配，不在战斗里 new
const MAX_PER_FRAME := 24   # 炸弹清屏时的洪水闸门

func burst(pos: Vector2, kind: String, tier: int) -> void
func live_count() -> int    # 给 SmokeTest 用
```

要点：
- **预分配 96 个 `Sprite2D`**，`_ready()` 里一次性建好，全部 `visible=false`；每种 kind 的贴图在 `_ready()` 预取（`Art.tex()` 走 `load()`，首次调用可能卡帧）。残影 Sprite2D 沿用 `Art.sprite()` 的 `TEXTURE_FILTER_LINEAR`，避免和敌人本体的采样方式不一致。
- 一个 `_process` 驱动全部残影/爆发，不给每个特效挂脚本（与 `WeaponManager.update_fx` 同款，`WeaponManager.gd:440-458`）。
- 满了就丢 T0，**永远保留 T1/T2**（预留 24 个槽）；一次炸弹杀 400 只时最多 96 个特效，避免“一坨光”。
- `MAX_PER_FRAME` 用 `Engine.get_physics_frames()` 做帧戳，而不是在 `_process` 里清零——击杀发生在物理/武器更新阶段，`_process` 的先后顺序不保证。T1/T2 不受 `MAX_PER_FRAME` 限流。
- **距离剔除**：`pos` 离玩家超过 900px（约 `SPAWN_RING=760` 外一圈，`Game.gd:9`）时，T0/T1 直接不生成；T2 始终生成。这样炸弹在屏幕外清场时不会白烧特效预算。
- 与武器特效分开池：武器池 64 个（`scripts/weapons/WeaponManager.gd:16`），生命周期 0.14~0.55s；击杀特效 0.20~0.5s，硬混池会互相饿死。两套都短，暂不抽公共类，避免为省 40 行代码做一次有风险的共享池重构。

### 4.4 信号与接线（需要一处签名变更）

现状 `enemy_died(pos, xp, kind)` 不知道 tier；`elite_died` / `boss_died` 是另两条信号（`EnemyPool.gd:4-6,58-68`）。推荐给 `enemy_died` 加一个 `tier: int`：

```gdscript
signal enemy_died(pos: Vector2, xp: int, kind: String, tier: int)
# 0=普通 1=精英 2=Boss；EnemyPool 里按 e.is_elite / e.is_boss 填
```

`Game.gd:72` 的连接与 `_on_enemy_died`（248 行）同步改一行；`elite_died` / `boss_died` 继续只负责掉落/宝箱，不重复触发特效。全仓只有 `Game.gd` 连这条信号（grep 确认），改动面很小。

接线后：

```gdscript
func _on_enemy_died(pos: Vector2, xp: int, kind: String, tier: int) -> void:
    kills += 1
    gems.spawn(pos, xp)
    pickups.roll_drop(pos, self)
    killfx.burst(pos, kind, tier)
```

- 精英/Boss 的宝箱、6 颗大宝石、饭盒逻辑保持原样（`Game.gd:254-264`）。
- 炸弹清屏时，`PickupField` 的 `BOMB_DAMAGE = 99999`（`PickupField.gd:47-49`）会一次性杀掉大量敌人；`KillFx` 的 `MAX_PER_FRAME` 负责限流，画面反馈由炸弹本身承担。

---

## 5. 可选 L1：2~3 帧纸片抖动

### 5.1 什么时候才做

先做 L0（第 3、4 节），用真实窗口截图（`tools/WindowShot.tscn`）录 3~5 秒观察：
- 如果 48px 杂兵在密集同屏下已经能读出“纸在动”，**不做 L1**；
- 如果轮廓仍然太稳、像滑行的贴纸，再做 L1，且只做玩家 + 3 种杂兵（10 张），精英/Boss 暂缓。

### 5.2 硬约束：独立文件，不用 `hframes`

- `Enemy.setup()` 用 `art.texture.get_size()` 算 `size`、`touch_radius`、`art.offset`（`Enemy.gd:69/72/74`）。如果做成横向拼帧，`get_size().x` 会变成 3 倍，`size = max(x,y)` 直接翻倍，碰撞/血条/脚底锚点全错。
- 因此帧图必须是**同画布、同脚底锚点、独立 SVG 文件**：`paper_scrap_2.svg`、`paper_scrap_3.svg`（48×48），其余同理。
- `build.mjs` 的 `EXPECT` 尺寸表和校验器已经能拦住画布不一致（构建时逐张比对，见 `assets/craftkeepers/build.mjs`）；新增帧图必须补进 `EXPECT`。

### 5.3 帧表与切换

| 对象 | 帧数 | 文件 | 播放 |
|---|---|---|---|
| 玩家正面 | 3 | `shouyiren_front.svg` + `_2` + `_3`（64×80） | 10fps |
| 玩家背面 | 3 | `shouyiren_back.svg` + `_2` + `_3`（64×80） | 10fps |
| 纸屑 | 3 | `paper_scrap.svg` + `_2` + `_3`（48×48） | 8fps |
| 断线纸鸢 | 3 | `broken_kite.svg` + `_2` + `_3`（48×48） | 8fps |
| 断线傀儡 | 3 | `broken_puppet.svg` + `_2` + `_3`（48×48） | 8fps |

- 切换用全局时钟 + `_pool_index` 错峰：`idx = int(_walk * 1.2 + _pool_index) % 3`，不给每只怪建 Timer。
- 只对“屏幕上”的敌人切换；离屏的池对象不处理（可复用现有的 `_pool` 可见性判断或相机距离）。
- 帧图由 `sprites.mjs` 的 `pose` 参数生成（小幅改肢体/纸角，不改画布），**禁止**用图片模型重绘。
- 帧图同样要登记：`_2`/`_3` 逐张加进 `Art.ALL_PATHS`（`Art.gd:62-71`），并把后缀加进对应 `SLOT_ALIASES` 条目（`Art.gd:93-106`）；`is_slot()` 是精确比对，不补就会让槽位断言在切帧后误报。出生首帧仍必须是 `paper_scrap.svg` 这类无后缀文件，保证 `SmokeTest.gd:496-499` 在 spawn 后立即断言也能通过。
  > 玩家侧已按此条落地（`player_front_2/3`、`player_back_2/3` 各有独立槽位，另加 `Art.is_player_front()` / `is_player_back()` 做"帧组"判定）；敌人侧照抄即可。

**交付状态（2026-10-27）：上表 10 张帧图已产出；玩家 4 张已接入工程，敌人 6 张仍未接。**

- 玩家（已接）：`shouyiren_front_2/3`、`shouyiren_back_2/3` 四张已复制进 `GameDemo/first-xi-xue-gui/assets/art_shouyiren/characters/`，由 `Art.PLAYER_FRONT_FRAMES` / `PLAYER_BACK_FRAMES` 驱动，`Player.gd` 按四向朝向 + 步频轮播。见 `reports/EXECUTION_LOG.md` §5（玩家操作反应）。
- 敌人（未接）：`paper_scrap_2/3`、`broken_kite_2/3`、`broken_puppet_2/3` 仍只在 `assets/craftkeepers/` 里，未进工程。

- 落位：`assets/craftkeepers/art_shouyiren/` 下 `characters/shouyiren_front_2.svg`、`_3.svg`、`characters/shouyiren_back_2.svg`、`_3.svg`、`enemies/paper_scrap_2.svg`、`_3.svg`、`enemies/broken_kite_2.svg`、`_3.svg`、`enemies/broken_puppet_2.svg`、`_3.svg`。
- 做法：**未动 `sprites.mjs`**（本轮只交图）。10 张由已提交的 5 张母图逐元素派生——只在原图元外面套 `<g transform>`（平移/旋转/腿部 `x` 位移），图元数量、顺序、配色、`defs` 与母图一一对应；纸屑的轮廓用 `lib.mjs` 的 `blobPath`/`specks` 换种子重画，仍是同一生成器函数。
- 已验证：`build.mjs` 的 `validate()` 0 错误；Godot 4.7.2 headless 实测 10 张均为 64×80 / 48×48、无加载失败；接触阴影 `ellipse` 与母图逐字节相同（脚底锚点不漂）；帧间差异 36~70%。条带图见 `assets/craftkeepers/校核_L1帧图.png`，复现命令 `assets/craftkeepers/README.md` §4。
- **风险**：`build.mjs#build()` 第一句是 `rmSync(OUT, {recursive:true})`，重跑 `generate.mjs` 会连这 10 张一起删。程序侧接手时的第一件事，是把姿态参数并进 `sprites.mjs` 并补 `EXPECT`/manifest，否则这 10 张只是一次性产物。
- 若 `paper_scrap` 两帧在 8fps 下读成闪烁而不是飘动，去掉轮廓重画、只保留 `rotate(±4~5°)`。

### 5.4 收益/成本

- 收益：轮廓变化更明显，尤其纸屑和傀儡。
- 成本：10 张 SVG + 一套帧表 + 每次贴图切换的渲染脏标记。按 400 只同屏、8fps、错峰 1/6 计算，约 533 次切换/秒（≈9 次/帧），在 Intel UHD 630 上可接受；但要实测。
- 如果实测掉帧，直接退回 L0，不改任何玩法代码。

---

## 6. 参数总表（可直接照此实现）

### 6.1 走路

| 参数 | 值 | 说明 |
|---|---|---|
| 玩家步频 | `11.0 rad/s × speed_mul` | 现有基线，随移速加成同步 |
| 玩家起伏 | 2.5px | 现有，保留 |
| 玩家侧摆 | 1.1px | 半步周期 |
| 玩家前倾 | ≤0.045 rad | 按水平速度 |
| 玩家压缩 | 1.04 / 0.96，0.08s | 落地瞬间 |
| 玩家背面切换 | 0.08s 迟滞，0.12s 压扁 | 条件 `dir.y < -0.55` 且竖向占优 |
| 杂兵旋转上限 | 0.18 rad | 48px 剪影可读性红线 |
| 杂兵位移上限 | 4px | 同上 |
| 旋转归一化 | `k = clampf(48/size, 0.4, 1.0)` | 96/160px 不甩 |
| 纸屑翻面 | ~0.9s 一次 | `flip_h` |
| 纸鸢颤频 | 3× 基频 | 高频 |
| 傀儡踏步 | ~2.2 Hz | 顿挫 |
| 墨渍呼吸 | 0.55× 基频，±5.5% | 缓慢 |
| 傩面踏步 | ~1.8 Hz | 沉重 |
| Boss 悬浮 | 基准 4~6px + 振幅 4px（总位移 ≤10px） | 无脚感；比杂兵宽松 |

### 6.2 击败

| 参数 | 值 | 说明 |
|---|---|---|
| `CORPSE_TIME` | 0.26s（精英 0.32 / Boss 0.42） | 原 0.20 |
| 折叠窗口 | 前 42% | `scale.y 1→0.70`，`scale.x 1→1.22` |
| 淡出窗口 | 后 70% | `alpha 1→0` |
| 上飘 | 12px | 线性 |
| 死亡旋转 | ±0.42 rad | 随机方向 |
| T0 残影 | 3 片，0.20s，70~120px/s | 同图 |
| T1 残影 | 6 片，0.28s，90~150px/s | 同图 |
| T2 残影 | 12 片，0.38s，110~180px/s | 同图 |
| 爆发图 | `kailian_burst`，T1 ×0.7 / T2 ×1.5 | 现有 |
| 震屏 | T1 3px/0.12s；T2 5px/0.22s | 仅精英/Boss 死亡（玩家受击可选） |
| `KillFx` 池 | 96 预分配，T1/T2 预留 24 | 独立于武器池 |
| 单帧上限 | 24 个新特效 | 炸弹洪水闸门 |

---

## 7. 性能预算与硬规则

### 7.1 目标环境

- Godot 4.7.2 stable / D3D12 Forward Mobile / **Intel UHD 630** / 720×1280（`GameDemo/first-xi-xue-gui/docs/TEST_REPORT.md:3`）。
- 目标 60 FPS，同屏 300+ 敌人（`策划案.md:717`）。
- 特效必须走池/批量，粒子有硬上限（`策划案.md:594/719`、`美术资产映射.md:236`）。

### 7.2 规则

1. **战斗里不 `new` 节点**。`KillFx` 预分配 96 个，`Enemy` 预分配 540 个（`EnemyPool.gd:9`）。
2. **不给每只敌人挂 `AnimationPlayer`/`AnimatedSprite2D`**。540 个动画节点在移动端是纯浪费；程序化变换已经足够。
3. **不用 `GPUParticles2D` 做击杀**。一次 3~12 片残影用 Sprite2D 池更便宜、更可控、可测试；粒子只适合后续大场面，且必须限 1 个。
4. **旋转/位移有上限**。48px 剪影上，0.18 rad / 4px 是“看得出在动但不糊”的边界。
5. **贴图切换要错峰**。L1 的 8~10fps 切换按 `pool_index` 分桶，避免同一帧 400 个纹理赋值。
6. **不在 `_process` 里做 `load()`**。`KillFx._ready()` 预取全部贴图。
7. **震屏只给大事件**。T0 不震，避免高频命中导致晕动。
8. **帧时间验证**：用 `WindowShot`/新增 `AnimShot` 在真实窗口跑 10 秒，记录 FPS；不以无头数据代替 GPU 数据。

### 7.3 粗略并发估算

| 场景 | 并发特效 | 说明 |
|---|---|---|
| 30 kills/s 持续 | 3×0.20×30 ≈ 18 片 | 远低于 96 |
| 炸弹清屏 400 只 | 限流 24/帧，最多 96 | 靠 `MAX_PER_FRAME` 和池上限 |
| Boss 战 | 12 片 + 1 爆发 | 单只，忽略不计 |

---

## 8. 实施顺序（AI 执行清单）

> 每一步都可独立提交、独立回退；除 S7 外不改任何数值/信号语义。

| 步骤 | 内容 | 涉及文件 | 完成标志 |
|---|---|---|---|
| S0 | 基线：导入 + 284 项冒烟 + 真实窗口截图（2026-10-27 已实跑：`全部通过`、exit 0） | 无 | `284/284`、exit 0 |
| S1 | `Enemy` 收敛表现出口 `_present()`；补 `art.scale` 复位；行为不变 | `scripts/Enemy.gd` | 284 项仍全绿；走路视觉与现在一致 |
| S2 | 修死亡：`CORPSE_TIME=0.26`、`corpse_tick()`、池调用点 | `scripts/Enemy.gd`、`scripts/EnemyPool.gd` | 死亡可见折叠+淡出；池正常回收 |
| S3 | 五种杂兵/精英的走路签名 + 幅度归一化 | `scripts/Enemy.gd` | 5 种材质可区分；无越界 |
| S4 | 玩家走路：前后图切换 + 侧摆/前倾/压缩 | `scripts/Player.gd`、`scripts/Art.gd`（用 `PLAYER_BACK`） | 向上走切背面；松手静止 |
| S5 | 新增 `KillFx` 池与 `World/KillFx` 节点；T0 残影接线；把 `Enemy._art_for` 公开为 `art_for` | 新 `scripts/KillFx.gd`、`scenes/Game.tscn`、`scripts/Game.gd`、`scripts/Enemy.gd` | 普通击杀有 3 片残影；池不增长 |
| S6 | `enemy_died` 加 `tier`；T1/T2 爆发 + 震屏 | `scripts/EnemyPool.gd`、`scripts/Game.gd`、`scripts/KillFx.gd` | 精英/Boss 有开炉爆发与震屏 |
| S7 | 三只 Boss 接图：`kind` 入表、`Art` 常量 + `ALL_PATHS` + 三个 `SLOT_ALIASES` 槽位、`hit_radius` 钉 40、横幅文案 | `scripts/WaveTable.gd`、`scripts/Game.gd`、`scripts/Enemy.gd`、`scripts/Art.gd`、`tools/SmokeTest.gd`、`tools/StageThreeShot.gd` | 三档 Boss 各自贴图/动作；命中半径不变；资源守卫覆盖新图 |
| S8 | （可选）L1 帧图：**10 张同画布 SVG 已交付（2026-10-27）**，余下帧表 + `ALL_PATHS`/`SLOT_ALIASES` 登记 + `sprites.mjs` 参数化 | `assets/craftkeepers/sprites.mjs`、`build.mjs`、`scripts/Art.gd`、`scripts/Enemy.gd`、`tools/SmokeTest.gd` | 画布校验通过；切帧后槽位断言仍绿；实测不掉帧 |
| S9 | 验收：新增用例 + 截图 + 更新测试记录 | `tools/SmokeTest.gd`、新 `tools/AnimShot.gd`、`docs/TEST_REPORT.md` | 全绿 + 有截图证据 |

### 8.1 前置依赖：非遗素材尚未接入

`art_shouyiren/` 里的 60 张资产是生成好的成品，但 `GameDemo/first-xi-xue-gui/assets/art/` 仍是旧素材，`Art.gd` 的常量也指向旧路径（`scripts/Art.gd:8-121`）。因此：

- S1~S6 的动画代码可以在旧素材上先落地、先跑通；
- 第 3 节的“材质签名”要看到新素材的效果，需先按 `assets/craftkeepers/README.md` 的 6 步集成清单完成替换（复制 34 张 + 改 `Art.gd`/`WeaponDB.gd`/`EvolutionDB.gd`/`PickupField.gd` + 7 个 `.tscn` 的 `ext_resource`）；
- 集成后重跑 284 项，再拍视觉截图。**动画代码不依赖素材替换，顺序可交换**；
- `Art.gd` 现在还有两道登记口：`ALL_PATHS`（`Art.gd:62-71`，冒烟测试逐条 `load` 校验，`SmokeTest.gd:520-549`）和 `SLOT_ALIASES` / `is_slot()`（`Art.gd:93-115`，槽位断言按文件名主干精确比对，`SmokeTest.gd:472-478`）。S7 新增三张 Boss 图、S8 新增帧图时，除加路径常量外必须同步补进这两处，否则资源齐备性会漏检、槽位断言会误报。

---

## 9. 验收标准

### 9.1 自动化（新增，建议 12 条）

在 `tools/SmokeTest.gd` 新增 `_step13_animation()`：

| # | 断言 | 目的 |
|---|---|---|
| 1 | 击杀后 2 帧，尸体 `modulate.a ∈ (0,1)` 且 >0.2 | 死亡不是瞬间透明 |
| 2 | 0.35s 后尸体回收到 `inactive` | 池回收未被动画拖死 |
| 3 | 复用同一只敌人后 `art.rotation == 0`、`art.scale == ONE`、`modulate.a == 1` | 无残留 |
| 4 | `paper_scrap` 与 `broken_puppet` 在相同时长内旋转轨迹不同 | 材质签名生效 |
| 5 | 普通敌人 `abs(art.rotation) ≤ 0.18`、`abs(art.position.y) ≤ 4`；Boss 悬浮 `≤ 10` | 可读性红线 |
| 6 | 玩家向上移动时贴图为 `PLAYER_BACK`，向右时为 `PLAYER_FRONT` | 背面切换 |
| 7 | 玩家静止时 `_walk_phase == 0` 且 `art.position.y` 不漂移 | 待机/走路边界 |
| 8 | 连续击杀 100 只后 `KillFx.get_child_count() == 96` | 不在战斗里 `new` |
| 9 | 一次炸弹清屏后 `killfx.live_count() ≤ 96` | 洪水闸门 |
| 10 | 精英死亡触发 T1（残影数 ≥6 + 爆发 + 震屏） | 层级正确 |
| 11 | Boss 死亡触发 T2，且原有 6 宝石 + 宝箱 + 饭盒不变 | 不破坏掉落 |
| 12 | 三档 Boss 的 `Art` 路径分别命中三张新图；`hit_radius()` 仍为 40.0 | 接图不破坏平衡 |

现有 **284 项**（`docs/TEST_REPORT.md:8`）必须全部保持绿色；新增用例只加不改，除非 S7 的 Boss 接图必须动 `SmokeTest.gd:499` 这类“死神贴图”断言（改为“reaper 仍为基底，三档 Boss 各自命中新图”）。

登记类校验不必另写：`_art_paths_loadable()`（`SmokeTest.gd:520-549`）会遍历 `Art.ALL_PATHS` 与各 DB 路径，S7/S8 把新图补进 `ALL_PATHS` 即自动纳入。若做 L1，再加第 13 条“切帧 1 秒后贴图仍命中同槽位”。

### 9.2 命令

```bash
cd GameDemo/first-xi-xue-gui
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tools/SmokeTest.tscn
"/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe" --path . res://tools/WindowShot.tscn
```

- 期望：`fail=0 error=0`，`ok = 284 + 新增`。
- `WindowShot` 的输出在 `user://shot_window.png`，并打印平均亮度（`tools/WindowShot.gd:16-31`），用来排除“截到黑屏”的假成功。

### 9.3 视觉证据

新增 `tools/AnimShot.gd`（AI 写）：
- 生成 1 只玩家 + 5 种敌人 + 1 只 Boss；
- 每 0.12s 截 6 帧，拼成一张 6 列联系表；
- 至少覆盖：玩家向上/向右、纸屑翻滚、傀儡顿步、Boss 悬浮、普通击杀 0/100/200ms、精英死亡 0/150/300ms。
- 肉眼验收标准：48px 下能靠**运动**分辨纸/风筝/木偶；击杀能看出“先散后归”。

---

## 10. 风险与回退

| 风险 | 依据 | 对策 |
|---|---|---|
| `scale/position/rotation` 多写入方互相覆盖 | 出生 `Enemy.gd:128-134`、走路 `163-165`、死亡 `203-217` | 单一 `_present()`；死亡走 `corpse_tick()`，process 关闭后不跑 `_present()` |
| 死亡动画不推进 | `_die()` 里 `set_process(false)`（`Enemy.gd:207`） | 由 `EnemyPool` 每帧调 `corpse_tick()`（现成回收路径） |
| 复用残留 | `setup()` 没复位 `art.scale`（`Enemy.gd:83-96`） | 补 `art.scale = Vector2.ONE`；新增用例 3 |
| `hframes` 破坏画布契约 | `size/touch_radius/offset` 全由 `tex.get_size()` 推导（`Enemy.gd:69/72/74`） | 独立同尺寸 SVG；`build.mjs` 尺寸校验 |
| Boss 接图后命中面积翻倍 | `hit_radius = size*0.36`，160px → 57.6 vs 旧 40.3（`Enemy.gd:176-178`） | `WaveTable.BOSS_HIT_R = 40.0` 钉死；回归 Boss 用例 |
| 炸弹清屏时特效洪水 | `BOMB_DAMAGE = 99999`（`PickupField.gd:47-49`），池 540/上限 400 | `KillFx` 96 上限 + 单帧 24 + 丢 T0 保 T1/T2 |
| 每击震屏导致晕动 | 文档“命中反馈”含震屏（`策划案.md:592`） | 只在 T1/T2 与玩家受击震；T0 不震 |
| L1 贴图切换掉帧 | Intel UHD 630（`TEST_REPORT.md:3`）+ 400 只同屏 | 只做玩家 + 3 杂兵；错峰；实测不过就回退 L0 |
| 帧图风格漂移 | 60 张资产是程序化生成，配色/描边有统一 `lib.mjs` | 用 `sprites.mjs` 的 `pose` 参数生成，禁止模型重绘 |
| 素材未接入导致“看不出效果” | `Art.gd` 仍指旧路径（`Art.gd:8-121`） | 先跑 S1~S6，再接素材；视觉验收在集成后做 |
| 长夜灯 30:00 立刻判胜 | `策划案.md:452`、`Game.gd` 现有胜利逻辑 | 只做登场几秒的悬浮/吞光，不做 Boss 战改动 |

**回退开关**（建议常量）：
- `KillFx.ENABLED`：关掉后只保留本体折叠，不影响掉落；
- `Enemy.WALK_SIGNATURE`：按 kind 关闭签名，退回现有正弦；
- L1 帧表：删掉即回 L0；
- Boss 接图：独立提交，回退即回 `reaper` 单图。

---

## 11. 不做的事（明确边界）

1. **不做骨骼/Skeleton2D**：素材是整张纸片，没有可切分关节；成本高、风格不符。
2. **不做 8 帧全动画**：设计文档只要求 2~3 帧（`策划案.md:590`），且 34 张重绘已够重。
3. **不做真实粒子系统**：池化 Sprite2D 已能覆盖 3~12 片残影，且更可控。
4. **不改胜负/数值/掉落**：包括 Boss 血量 2800/6100/11000、900/1500/1800 秒、接触半径 34（`策划案.md:301/450`）。
5. **不做“颜色飞向世界灯笼”**：`PropField` 没有灯位 API；首版归色落在玩家手里的灯（经验宝石已实现）。
6. **不为了动画重切人物图**：提灯独立摆动留到 P2，本轮用整体侧倾替代。

---

## 12. 依据清单（本文每条判断的来源）

### 12.1 代码事实

| 依据 | 位置 | 证明什么 |
|---|---|---|
| 敌人走路正弦 | `GameDemo/first-xi-xue-gui/scripts/Enemy.gd:163-165` | 目前只有一种运动语法 |
| 敌人死亡 | `Enemy.gd:203-217`（alpha 213 行） | 死亡瞬间透明、动画不可见 |
| 尸体回收 | `Enemy.gd:220-226`、`EnemyPool.gd:93-106` | 死亡时 process 已关，必须由池驱动 |
| 画布契约 | `Enemy.gd:69/72/74` | `size/touch_radius/offset` 由贴图尺寸推导，禁止拼帧 |
| 命中半径 | `Enemy.gd:176-178`；消费者 `WeaponManager.gd:169/304/347`、`EnemyPool.gd:236` | Boss 换 160px 图会把命中面积翻倍 |
| 出生/走路/死亡争用 | `Enemy.gd:95-96,128-134,163-165,203-217` | 必须单一表现出口 |
| 复用复位缺口 | `Enemy.gd:83-96`、`EnemyPool.gd:81-85` | `art.scale` 没有复位 |
| 美术登记契约 | `Art.gd:60-71`（`ALL_PATHS`）、`Art.gd:73-115`（`KEY_*`/`SLOT_ALIASES`/`is_slot`）、`SmokeTest.gd:472-478,520-549` | 新图必须登记；槽位断言按文件名主干精确比对 |
| 无击杀特效 | `Game.gd:248-252` | 击败效果需要新接线 |
| 信号面 | `EnemyPool.gd:4-6,58-68`、`Game.gd:72-74` | 只有 Game 监听，加 `tier` 改动面小 |
| 池上限 | `EnemyPool.gd:9-15`；`WeaponManager.gd:16` | 540 敌人 / 400 存活 / 64 武器特效 |
| 现有 FX 模式 | `WeaponManager.gd:400-458,475` | `KillFx` 可直接复用模式 |
| Boss 仍用 `reaper` | `Game.gd:235-246`（244 行）、`Enemy.gd:104-118` | 三张新 Boss 图未接入 |
| 玩家只有上下起伏、背面图未用 | `Player.gd:187-193`、`Art.gd:9`、`Player.tscn` | 玩家走路可零新图升级 |
| 经验宝石即归色 | `Game.gd:250`、`Gem.gd:19,34-58` | 不再重复加“归色光点” |
| 摊位/灯笼无坐标 API | `PropField.gd:4-6,29+` | “飞向最近灯笼”首版落玩家 |
| 场景层级 | `Game.tscn:46-58` | `KillFx` 放 `World`、z=0，宝石 z=1、掉落 z=2 |
| 测试基线 | `docs/TEST_REPORT.md:3,8` | 284/284；Intel UHD 630 |
| Boss 数值/命中 | `WaveTable.gd:38-42,47,50` | 血量按 70% 火力/30 秒反推；接触半径 34 |
| 测试基线用例 | `SmokeTest.gd:472-501,940-959,1069,1097` | Boss 贴图/行为断言位置 |
| 截图工具 | `tools/WindowShot.gd:16-31`、`tools/StageThreeShot.gd` | 真实窗口视觉验收路径 |

### 12.2 素材事实

| 依据 | 位置 | 证明什么 |
|---|---|---|
| 60 张资产清单 | `assets/craftkeepers/manifest.json:16-21` | 34 重绘 + 17 P0 + 9 P1 |
| 玩家正/背面 64×80 | 同上 `manifest.json:23-39` | 背面图已存在 |
| 三只 Boss（160×160 / 128×160 / 160×160） | 同上 `manifest.json:359-382` | 可接三档 Boss |
| 击杀可用 FX | 同上 `manifest.json:248-262,480-502` | `gold_spark_fx`、`kailian_burst`、预警圈等 |
| 尺寸校验器 | `assets/craftkeepers/build.mjs`（`EXPECT` + validate） | 新增帧图必须同画布 |
| 风格统一 | `assets/craftkeepers/lib.mjs`（调色板/图元） | 帧图应由同一生成器产出 |
| 集成清单 | `assets/craftkeepers/README.md` | 素材尚未复制进游戏工程 |

### 12.3 设计文档

| 依据 | 位置 | 结论 |
|---|---|---|
| “战斗是归色” | `策划案.md:240` | 死亡散成纸屑/墨点/光尘，颜色归位 |
| 死亡表现 | `策划案.md:428` | 不喷血、不留尸体；颜色飞向灯笼 |
| Boss 表与时间 | `策划案.md:446-450` | 15/25/30 分钟三档，数值不动 |
| 终局 Boss 演出 | `策划案.md:452` | 长夜灯登场后立即判胜，只做演出 |
| 血条灯焰 | `策划案.md:579` | 受击抖动（本轮可选，不强制） |
| 2~3 帧纸片抖动 | `策划案.md:590`、`美术资产映射.md:232` | 不需要骨骼 |
| 命中反馈 | `策划案.md:592`、`美术资产映射.md:234` | 纸屑/金火星/轻微震屏，不喷血 |
| 粒子上限 | `策划案.md:594/719`、`美术资产映射.md:236` | 同屏 300+ 时硬限制，可降级为贴图动画 |
| 60 FPS 目标 | `策划案.md:717` | 池/距离判定/批量绘制 |

### 12.4 方法说明

- 本文的“幅度/时长”不是拍脑袋：旋转上限 0.18 rad ≈ 48px 贴图边缘 4.3px 位移，正好在“看得出、不糊”的区间；0.26s 对应 60fps 约 16 帧，覆盖“折叠 + 淡出”两个动作；这些值在实现时用 `AnimShot` 六帧联系表复核。
- 本文没有改动游戏代码；收尾时实跑过一次 headless 冒烟（`全部通过`、exit 0），用于核对 284 项基线与文中引用。所有“现状”仍为读代码得出，所有“建议”均标注了落点文件与验收方式。
- 视觉验证不使用浏览器：本机无无头浏览器，统一走 Godot 真实窗口截图（`WindowShot`/新增 `AnimShot`）。
- 2026-10-27 追加：L1 的 10 张帧图已按 §5.3 交付到 `assets/craftkeepers/art_shouyiren/`，并过了 `build.mjs#validate()`（0 错误）与 Godot headless 光栅化（尺寸全对、无加载失败）。本轮只交图，`Art.gd`/`Enemy.gd`/`SmokeTest.gd`/`sprites.mjs` 一行未改。

---

## 13. 最终交付物（AI 实施时）

1. 代码：`scripts/Enemy.gd`、`scripts/EnemyPool.gd`、`scripts/Player.gd`、`scripts/Game.gd`、`scripts/Art.gd`、`scripts/WaveTable.gd`、新 `scripts/KillFx.gd`、`scenes/Game.tscn`。
2. 图片（仅 L1 可选）：10 张同画布 SVG **已交付**；`manifest.json`/`EXPECT` 更新与 `sprites.mjs` 参数化仍待做（否则重跑 `generate.mjs` 会把这 10 张删掉）。
3. 测试：`tools/SmokeTest.gd` 新增 12 条；新 `tools/AnimShot.gd`；`docs/TEST_REPORT.md` 追加实跑记录。
4. 证据：`WindowShot` 截图 + `AnimShot` 六帧联系表；`284 + 新增` 全绿、exit 0。

> 结论再强调一次：**先把“纸/墨/影/木偶”的运动语法和“看得见的死亡”做出来，全部零新图；2~3 帧是精修，不是前提。**
