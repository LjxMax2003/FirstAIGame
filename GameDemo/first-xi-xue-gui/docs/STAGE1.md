# 阶段一交付报告：最小可玩回路

> 工程：`GameDemo/first-xi-xue-gui`  
> 引擎：Godot **4.7.2 stable**（`4.7.2.stable.official.ed1daf0bf`）  
> 验收日期：2026-10-26  
> 结论：**阶段一 5 个步骤 + 暂停/重开闭环 + 美术接入，自动化检查 59/59 通过，连续 3 次复跑全绿**

---

## 一、这一版做了什么

阶段一的目标是"跑得起来、打得动、捡得到、升得了级"的最小闭环。本次在原有骨架上补齐了这些内容：

| 步骤     | 内容                                                      | 状态 |
| ------ | ------------------------------------------------------- | -- |
| Step 1 | 单指相对拖拽移动 + 键盘 WASD/方向键，相机平滑跟随，无限地面                      | 完成 |
| Step 2 | 对象池敌人（预分配 540 / 同屏上限 420），直线追踪 + 网格分离，距离判定伤害，HUD 显示 FPS | 完成 |
| Step 3 | 三把自动武器：鞭子（左右交替扇形）、蒜环（范围脉冲）、魔杖（锁定最近敌人，穿透 1）              | 完成 |
| Step 4 | 敌人掉落蓝色菱形宝石，进入磁吸半径后加速飞向玩家并自动拾取                           | 完成 |
| Step 5 | 升级三选一，`next = 5 + level²`，全树暂停，武器上限 6 格                 | 完成 |
| 闭环     | 暂停菜单、死亡结算、重开（`Ctrl+R` / 结算页按钮），优先级 结算 > 升级 > 暂停         | 完成 |
| 美术     | 34 张 SVG 全部接入（角色/敌人/武器/道具/地面/道具/UI）                     | 完成 |



---

## 二、操作方式

| 操作      | 输入                         |
| ------- | -------------------------- |
| 移动      | 单指拖拽屏幕任意位置（相对位移，手指不用压在角色上） |
| 移动（桌面）  | `WASD` 或方向键                |
| 暂停 / 继续 | 右上角 `II` 按钮，或 `Esc`        |
| 选择升级卡   | 点卡片，或按 `1` `2` `3`         |
| 重开      | `Ctrl+R`，或死亡结算页的「重开」按钮     |
| 结算页确认   | `Enter` / `Space`          |

设计约定：**玩家全程只有"移动"一个主动输入**，攻击、拾取、升级全部自动。这是吸血鬼幸存者类玩法的核心手感前提。

---

## 三、怎么运行

```bash
GODOT="/c/Users/Administrator/Desktop/Godot_v4.7.2-stable_win64_console.exe"
cd GameDemo/first-xi-xue-gui

# 1. 首次或改过场景后，先导入（生成 .godot 缓存与脚本类注册）
"$GODOT" --headless --path . --import

# 2. 跑游戏（720x1280 竖屏窗口）
"$GODOT" --path . --resolution 720x1280
```

也可以直接用 Godot 编辑器打开 `project.godot`，按 `F5` 运行。

---

## 四、实际做过的检查

### 4.1 自动化逻辑验收（headless）

```bash
"$GODOT" --headless --path . res://tools/SmokeTest.tscn
```

结果：`EXIT=0`，**59 项全通过**，连续复跑 3 次均 `EXIT=0`。关键数据：

- 单指拖拽位移 99.0 px；键盘位移 66.0 px；相机中心偏差 24.9 px
- 同屏敌人 300 只 / 上限 420，用时 654 帧
- 同点堆叠 15 只后平均散开 17.4 px
- 敌人追踪 400 → 346 px
- 贴脸接触扣血 100 → 90
- 池复用敌人位移 35.6 px（验证 `set_process(true)` 复位）
- 鞭子身前/身后都能命中；蒜环可视化半径 86 px 与判定一致；魔杖命中 300 px 外目标
- 站桩不动 6 秒击杀 +6（自动攻击成立）
- 宝石磁吸：90 px 外不吸、进圈自动拾取、贴脸 0.2s 内吃掉
- 升级 Lv3→Lv4，弹出 3 张卡，选卡后 `{whip:2, halo:1, wand:1}` 生效
- 重开后计时 0.18s / 击杀 0 / 武器回到 `["whip"]` / 无残留暂停锁

### 4.2 真实窗口渲染检查（非 headless）

```bash
"$GODOT" --path . --resolution 720x1280 res://tools/WindowShot.tscn
```

结果：窗口 720×881（受本机 1600×900 屏幕高度限制），截图 `shots/stage1_final.png`，中心区平均亮度 `AVG_LUMA 0.2187`（证明不是黑屏）。

**注意边界**：这一步证明的是"渲染管线 + 场景装配在真实窗口下不崩溃、画面正确"，**不等于人工试玩验收**。本机没有做手指触摸实机试玩。

### 4.3 本轮修复的实际缺陷

| 缺陷                | 根因                                                                            | 修法                                   |
| ----------------- | ----------------------------------------------------------------------------- | ------------------------------------ |
| 右下角露出城市背景、地面"缺一块" | `BG` 的 `z_index = 0` 高于 `Ground` 的 `-10`，背景盖在了地面之上                            | `BG` 改为 `z_index = -20`              |
| 宽屏下地面铺不满          | `Ground`/`PropField` 写死 720×1280，但 `stretch/aspect="expand"` 下实际视口是 1046×1280 | 抽出 `Ground.view_size()` 统一读实时视口，两处共用 |
| 地砖重复感重（井盖排成网格）    | 单张 256px 砖无限平铺，图案不对称                                                          | 按世界格坐标做翻转 + 双档明暗，滚动时映射稳定不闪           |
| HUD 文字与地砖纹理糊在一起   | 顶部无背景层                                                                        | 加 `GradientTexture2D` 渐变压暗 + 文字投影    |
| 武器槽图标溢出槽位         | `TextureRect` 受父级 `Control` 影响按贴图原尺寸（96px）撑开                                  | 显式 `set_size` + `EXPAND_IGNORE_SIZE` |
| 血条颜色发脏（蓝紫）        | `ui_bar_fill.svg` 主色是 `#6FD8FF`，tint 相乘只会越乘越暗，红色出不来                           | 血条改用运行时生成的纯红纵向渐变，保留圆柱高光              |
| 测试偶发"敌人不追踪"       | 300 只敌人时从 `active[0]` 里挑一只瞬移，空间网格里旧位置记录导致吃"幽灵邻居"分离力                           | 调整顺序：先测分离（需高密度），清场后再单独测追踪            |

---

## 五、美术资源与许可

全部图形为**项目内原创 SVG**，位于 `assets/art/`，未使用任何第三方或网络素材。

| 目录            | 文件                                                                                                                                        | 用途        |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| `characters/` | `player_front.svg` (64×80)、`player_back.svg`                                                                                              | 玩家        |
| `enemies/`    | `enemy_cup.svg`、`enemy_cup_fast.svg`、`enemy_bag.svg` (48px)                                                                               | 普通敌人      |
|               | `enemy_elite_box.svg`、`enemy_elite_red.svg` (96px)、`enemy_reaper.svg` (80×112)                                                            | 精英 / Boss |
| `weapons/`    | `whip_arc.svg`、`halo_ring.svg`、`wand_glowstick.svg`、`bullet_glowstick.svg`、`axe_extinguisher.svg`、`knife_boxcutter.svg`、`phone_orbit.svg` | 武器特效与图标   |
| `items/`      | `gem_blue.svg`、`gem_orange.svg`、`chest.svg`、`coin.svg`、`pickup_bento.svg`、`pickup_bomb.svg`、`pickup_magnet.svg`                           | 掉落物       |
| `ground/`     | `ground_tile.svg` (256×256 无缝)                                                                                                            | 无限地面      |
| `props/`      | `prop_cone.svg`、`prop_trash.svg`、`prop_hydrant.svg`、`prop_bike.svg`、`prop_vending.svg`                                                    | 场景装饰      |
| `fx/`         | `fx_spark.svg`、`fx_evolve_star.svg`                                                                                                       | 打击 / 进化特效 |
| `ui/`         | `bg_city_dusk.svg` (720×1280)、`ui_bar_frame.svg` (320×20)、`ui_bar_fill.svg` (312×12)、`ui_card_frame.svg` (200×280)                        | 界面        |

引擎本体遵循 Godot 的 MIT 许可，与项目作品版权无关。

---

## 六、已知问题与未验证项

### 已知问题

1. **地砖仍能看出重复**：256px 的砖在 1046px 宽视口横向重复 4 次。已用翻转和明暗打散，但美术本身是不对称图案，近距离仍可辨认规律。彻底解决需要一张更大的地表图或 2–3 张变体拼图。
2. **暂停按钮视觉偏弱**：默认主题的深色 `Button`，在深色遮罩上对比度不高（功能正常，`Esc` 也能用）。
3. **未做手感调优**：移动速度、相机平滑、磁吸加速度目前是首版数值，没有经过真人长时间试玩迭代。

### 明确未验证

- **Android / iOS 导出**：未尝试，本机无对应导出模板与设备。
- **真机触摸手感**：只在桌面用模拟触摸事件跑通逻辑，没有在手机上用手指实际玩过。
- **长局难度曲线**：自动化只跑到 8 分钟（480 秒）的密度压力点，没有完整打到 30 分钟看后期平衡。
- **Windows 独立可执行文件**：**未构建**。本机 `%APPDATA%\Godot\export_templates` 下没有 4.7.2 导出模板，无法产出真实的 `.exe`。需要先在 Godot 编辑器里安装导出模板，再执行 `--export-release`。

---

## 七、文件清单

```
GameDemo/first-xi-xue-gui/
├── project.godot                  # 720x1280 / canvas_items / expand / Mobile 渲染器
├── scenes/
│   ├── Game.tscn                  # 主场景：BG(z=-20) → World → UI
│   ├── Player.tscn
│   ├── weapons/WeaponManager.tscn
│   └── ui/{HUD,LevelUpUI,PauseUI,DeathUI}.tscn
├── scripts/
│   ├── GameManager.gd             # autoload，唯一数值管线
│   ├── Game.gd                    # 生成、难度、暂停优先级、重开
│   ├── Player.gd                  # 移动、受伤、经验
│   ├── Enemy.gd / EnemyPool.gd    # 追踪、分离、对象池
│   ├── GemPool.gd                 # 宝石磁吸
│   ├── WeaponManager.gd           # 三武器 + 子弹池 + 特效池
│   ├── Ground.gd                  # 无限地面（视口自适应 + 翻转去重复）
│   ├── PropField.gd               # 场景道具（视口自适应裁剪）
│   └── ui/{HUD,LevelUpUI,PauseUI,DeathUI,JoyRing}.gd
├── tools/
│   ├── SmokeTest.tscn / .gd       # 59 项自动化验收
│   └── WindowShot.tscn / .gd      # 真实窗口渲染冒烟
└── shots/
    └── stage1_final.png           # 最终验收截图
```
