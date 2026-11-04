extends RefCounted
class_name Art

# 资源路径集中管理：美术换图只改这里，脚本里不出现裸路径。
# 全部来自 assets/art_shouyiren/**.svg（守艺人·百工夜行），Godot 导入为纹理，按原尺寸 1:1 使用。
# 旧目录 assets/art/（奶茶题材）按换皮方案红线 3 原样保留，随时可切回。

# ---- 角色
const PLAYER := "res://assets/art_shouyiren/characters/shouyiren_front.svg"
const PLAYER_BACK := "res://assets/art_shouyiren/characters/shouyiren_back.svg"
# 走路帧：第 2/3 帧是同画布（64x80）的摆臂/移灯变体，由程序生成器产出，
# 换 style 时三帧必须一起换 —— 尺寸漂了脚底和碰撞体就对不上。
const PLAYER_FRONT_2 := "res://assets/art_shouyiren/characters/shouyiren_front_2.svg"
const PLAYER_FRONT_3 := "res://assets/art_shouyiren/characters/shouyiren_front_3.svg"
const PLAYER_BACK_2 := "res://assets/art_shouyiren/characters/shouyiren_back_2.svg"
const PLAYER_BACK_3 := "res://assets/art_shouyiren/characters/shouyiren_back_3.svg"

const PLAYER_FRONT_FRAMES: Array[String] = [PLAYER, PLAYER_FRONT_2, PLAYER_FRONT_3]
const PLAYER_BACK_FRAMES: Array[String] = [PLAYER_BACK, PLAYER_BACK_2, PLAYER_BACK_3]

# ---- 敌人
const ENEMY_CUP := "res://assets/art_shouyiren/enemies/paper_scrap.svg"
const ENEMY_CUP_FAST := "res://assets/art_shouyiren/enemies/broken_kite.svg"
const ENEMY_BAG := "res://assets/art_shouyiren/enemies/broken_puppet.svg"
const ELITE_BOX := "res://assets/art_shouyiren/enemies/ink_blob_elite.svg"
const ELITE_RED := "res://assets/art_shouyiren/enemies/faceless_nuo_elite.svg"
const REAPER := "res://assets/art_shouyiren/enemies/lost_visage.svg"
# ---- v5 浆壳兵：结壳层（overlay，锚点与 paper_scrap 对齐）
const SHELL_CRUST := "res://assets/art_shouyiren/enemies/shell_crust.svg"

# ---- v7.1 杂兵三帧行走 + 结壳变体（T10 / L-10）
# 12 张图全是 48x48 同画布（生成器保证），所以换帧既不改 size 也不改 touch_radius ——
# 这条很重要：换生成器时若三帧画布漂了，敌人会一边走一边"长大"。
const ENEMY_CUP_2 := "res://assets/art_shouyiren/enemies/paper_scrap_2.svg"
const ENEMY_CUP_3 := "res://assets/art_shouyiren/enemies/paper_scrap_3.svg"
const ENEMY_CUP_SHELL := "res://assets/art_shouyiren/enemies/paper_scrap_shell.svg"
const ENEMY_CUP_FAST_2 := "res://assets/art_shouyiren/enemies/broken_kite_2.svg"
const ENEMY_CUP_FAST_3 := "res://assets/art_shouyiren/enemies/broken_kite_3.svg"
const ENEMY_CUP_FAST_SHELL := "res://assets/art_shouyiren/enemies/broken_kite_shell.svg"
const ENEMY_BAG_2 := "res://assets/art_shouyiren/enemies/broken_puppet_2.svg"
const ENEMY_BAG_3 := "res://assets/art_shouyiren/enemies/broken_puppet_3.svg"
const ENEMY_BAG_SHELL := "res://assets/art_shouyiren/enemies/broken_puppet_shell.svg"

## kind → 三帧。**只有杂兵有行走帧**：精英与 Boss 一律单帧。
## 理由是性能红线（策划案 §6"行走帧破合批"）：同屏 300 只时，每只多换两次贴图
## 会把整批 Sprite2D 从 3 个合批桶打散成"每只一个桶"。精英同屏个位数，随便动。
const ENEMY_FRAMES: Dictionary = {
	"cup": [ENEMY_CUP, ENEMY_CUP_2, ENEMY_CUP_3],
	"fast": [ENEMY_CUP_FAST, ENEMY_CUP_FAST_2, ENEMY_CUP_FAST_3],
	"bag": [ENEMY_BAG, ENEMY_BAG_2, ENEMY_BAG_3],
}

## kind → 结壳变体。结壳时**直接换本体贴图**，不再叠一层 shell_crust。
## 叠加层的问题是它把本体压成一片暗色，"这只怪长什么样"直接消失了；
## 变体图是把壳画进角色里，减伤状态一眼可辨，同时还剩得下一个 Sprite2D。
const ENEMY_SHELL: Dictionary = {
	"cup": ENEMY_CUP_SHELL,
	"fast": ENEMY_CUP_FAST_SHELL,
	"bag": ENEMY_BAG_SHELL,
}

## 行走帧速率。6–8fps 是 L-10 给的口径：再快在 48px 上会读成抖动，
## 再慢会读成"卡住"。取 7 是因为 60fps 下每 8.57 帧切一次，
## 不和每帧都在跑的其它动画（旋转 / 上下浮动）同频，避免整屏敌人同拍。
const ENEMY_FRAME_FPS := 7.0
# ---- v5 三种小 Boss（12/18/24min 各刷一只）
const BOSS_DRUM := "res://assets/art_shouyiren/enemies/boss_drum.svg"
const BOSS_NUO := "res://assets/art_shouyiren/enemies/boss_faceless_nuo.svg"
const BOSS_LANTERN := "res://assets/art_shouyiren/enemies/boss_long_night_lantern.svg"

# ---- 武器（场景内特效 / 图标）
# 注意：manifest.json 里 paper_cut_bird/shadow_puppet 的 replaces 字段把这两个槽位写反了。
# 以换皮方案 T2.4 + P3 文案为准：飞刀(blade)=剪纸·纸鹊寻敌（会弹射），手机环(phone)=皮影·影人绕身。
const WHIP_ARC := "res://assets/art_shouyiren/weapons/nuo_blade_arc.svg"
const HALO_RING := "res://assets/art_shouyiren/weapons/lantern_halo.svg"
const BULLET_GLOWSTICK := "res://assets/art_shouyiren/weapons/sugar_thread.svg"
const WAND_GLOWSTICK := "res://assets/art_shouyiren/weapons/sugar_ladle.svg"
const AXE_EXTINGUISHER := "res://assets/art_shouyiren/weapons/iron_flower_ladle.svg"
const KNIFE_BOXCUTTER := "res://assets/art_shouyiren/weapons/paper_cut_bird.svg"
const PHONE_ORBIT := "res://assets/art_shouyiren/weapons/shadow_puppet.svg"
# ---- v5 新武器（Phase 5 美术已落地，本文件负责登记）
const GONG := "res://assets/art_shouyiren/weapons/gong.svg"
const INKLINE := "res://assets/art_shouyiren/weapons/inkline.svg"
const WOODBLOCK_PRINT := "res://assets/art_shouyiren/weapons/woodblock_print.svg"
# ---- v5 进化形态卡面/槽位图（没有独立图的进化回落到本体，见 EvolutionDB）
const GONG_EVOLVED := "res://assets/art_shouyiren/weapons/gong_evolved.svg"
const INKLINE_EVOLVED := "res://assets/art_shouyiren/weapons/inkline_evolved.svg"
const EXTINGUISHER_EVOLVED := "res://assets/art_shouyiren/weapons/extinguisher_evolved.svg"

# ---- 道具 / 掉落
const GEM_BLUE := "res://assets/art_shouyiren/items/light_bloom.svg"
const GEM_ORANGE := "res://assets/art_shouyiren/items/gold_spark.svg"
const CHEST := "res://assets/art_shouyiren/items/craft_box.svg"
const COIN := "res://assets/art_shouyiren/items/copper_coin.svg"
const PICKUP_BENTO := "res://assets/art_shouyiren/items/ciba.svg"
const PICKUP_BOMB := "res://assets/art_shouyiren/items/firecracker.svg"
const PICKUP_MAGNET := "res://assets/art_shouyiren/items/bronze_bell.svg"
# ---- v5 新被动图标
const PASSIVE_REGEN := "res://assets/art_shouyiren/items/passive_regen.svg"
const PASSIVE_SHIELD := "res://assets/art_shouyiren/items/passive_shield.svg"

## 9 条被动的图标。**升级卡与图鉴共用这一份** —— 它们是同一件东西的两个入口，
## 图标分家就会出现"升级卡上画的是爆竹、图鉴里画的是别的"，而两边都不会报错。
## 挑图规则：按"这件东西长什么样"选实物，不复用武器图（复用了玩家会误选）。
const STAT_ICON: Dictionary = {
	"damage": GEM_ORANGE,
	"cooldown": PICKUP_BOMB,
	"area": GEM_BLUE,
	"speed": ENEMY_CUP_FAST,
	"magnet": PICKUP_MAGNET,
	"max_hp": PICKUP_BENTO,
	"might": ENEMY_BAG,
	"regen": PASSIVE_REGEN,
	"shield": PASSIVE_SHIELD,
}

# ---- 场景
const GROUND_TILE := "res://assets/art_shouyiren/ground/stone_tile.svg"
# 可破坏物只有 PROP_HYDRANT / PROP_TRASH / PROP_VENDING 三张（ResourceField.gd），
# 所以这三张必须语义正确：灯笼架/竹筐/糖画摊都是"愿意被拆"的摊位物件。
const PROP_BIKE := "res://assets/art_shouyiren/props/goods_cart.svg"
const PROP_CONE := "res://assets/art_shouyiren/props/stone_lamp.svg"
const PROP_HYDRANT := "res://assets/art_shouyiren/props/lantern_stand.svg"
const PROP_TRASH := "res://assets/art_shouyiren/props/bamboo_basket.svg"
const PROP_VENDING := "res://assets/art_shouyiren/props/sugar_stall.svg"

# ---- 特效
const FX_SPARK := "res://assets/art_shouyiren/fx/gold_spark_fx.svg"
const FX_EVOLVE := "res://assets/art_shouyiren/fx/kailian_burst.svg"
# ---- v5 潮涌预警环（贴地，压 z_index < 0）
const FX_SURGE_RING := "res://assets/art_shouyiren/fx/surge_ring.svg"

# ---- UI
const UI_BAR_FILL := "res://assets/art_shouyiren/ui/ui_flame_fill.svg"
const UI_BAR_FRAME := "res://assets/art_shouyiren/ui/ui_lantern_frame.svg"
const UI_CARD_FRAME := "res://assets/art_shouyiren/ui/ui_paper_card.svg"
# 血条 4 段刻度：TextureProgressBar 的绘制顺序是 under → progress → over，
# 框上的刻度满血时会被填充整条盖死（实测：框上刻度色像素数 = 0），
# 所以真正可见的那份挂 texture_over。两份刻度的 x 必须同为 82/160/238。
const UI_BAR_TICKS := "res://assets/art_shouyiren/ui/ui_lantern_ticks.svg"
# ---- v5 UI：主动技按钮 / 精炼徽标
const UI_SKILL_ROAR := "res://assets/art_shouyiren/ui/skill_roar.svg"
const UI_REFINE_BADGE := "res://assets/art_shouyiren/ui/refine_badge.svg"

# ---- v6 满级觉醒美术（docs/design/v6_fx_art_plan.md §3.2 必须 + §4 推荐）
# 只登记资源，不做接线：调用点由工程一次性接（HUD 卡面角标 / extinguisher 弹体 /
# 墨斗墨线平铺 / 年画落点浮雕光印）。名字跟清单 new_art[].register 一致。
const AWAKEN_BADGE := "res://assets/art_shouyiren/ui/awaken_badge.svg"
const MOLTEN_BLOB := "res://assets/art_shouyiren/fx/molten_blob.svg"
const INK_LINE_TEX := "res://assets/art_shouyiren/weapons/ink_line_tex.svg"
const WOODBLOCK_SEAL := "res://assets/art_shouyiren/fx/woodblock_seal.svg"

# ---- 背景（场景里的 Control.texture 直接引用，不经 Art.tex，但路径仍要能 load）
const BG_CITY := "res://assets/art_shouyiren/ui/bg_night_market.svg"

# ---- v7 引导（L-07 / T5）
# 三页开场：师父与百工灯 / 夜市与忘影 / 阿满提灯走入（docs/theme/craftkeepers/art-mapping.md）
const INTRO_1 := "res://assets/art_shouyiren/ui/intro_01.svg"
const INTRO_2 := "res://assets/art_shouyiren/ui/intro_02.svg"
const INTRO_3 := "res://assets/art_shouyiren/ui/intro_03.svg"
# 木牌：局内一次性提示的底板。用木牌而不是弹窗，是因为它在夜市里"本来就长这样"，
# 不会像系统弹窗那样把玩家从场景里拽出来。
const UI_WOOD_SIGN := "res://assets/art_shouyiren/ui/ui_wood_sign.svg"

const PROP_LIST: Array[String] = [PROP_CONE, PROP_TRASH, PROP_HYDRANT, PROP_BIKE, PROP_VENDING]
const ENEMY_LIST: Array[String] = [ENEMY_CUP, ENEMY_BAG, ENEMY_CUP_FAST]

# ---- v7.1 夜市街区置景（T11 / L-12「内容资产闲置」）
# 五张摊位对应五门手艺，牌楼 / 戏台 / 灯柱做地标。坐标不写在这里 ——
# Art 只回答"图在哪"，"摆在哪"属于场景布局，归 PropField 的 LANDMARKS。
# 这八张之前一直躺在 assets 里没人引用，是 L-12 点名的闲置资产。
const STALL_FORGE := "res://assets/art_shouyiren/stalls/stall_forge.svg"
const STALL_LANTERN := "res://assets/art_shouyiren/stalls/stall_lantern.svg"
const STALL_PAPER := "res://assets/art_shouyiren/stalls/stall_paper.svg"
const STALL_SHADOW := "res://assets/art_shouyiren/stalls/stall_shadow.svg"
const STALL_SUGAR := "res://assets/art_shouyiren/stalls/stall_sugar.svg"
const ARCHWAY := "res://assets/art_shouyiren/stalls/archway.svg"
const OLD_STAGE := "res://assets/art_shouyiren/stalls/old_stage.svg"
const LANTERN_PILLAR := "res://assets/art_shouyiren/stalls/lantern_pillar.svg"

# ---- v7.1 角色立绘（T9）：五个匠人，只改开局不给属性
const CHAR_FORGE := "res://assets/art_shouyiren/characters/char_forge.svg"
const CHAR_LANTERN := "res://assets/art_shouyiren/characters/char_lantern.svg"
const CHAR_PAPER := "res://assets/art_shouyiren/characters/char_paper.svg"
const CHAR_SHADOW := "res://assets/art_shouyiren/characters/char_shadow.svg"
const CHAR_SUGAR := "res://assets/art_shouyiren/characters/char_sugar.svg"

# ---- v7.1 图鉴底板（T12）
const CODEX_BG := "res://assets/art_shouyiren/ui/codex_bg.svg"
const UI_SEAL := "res://assets/art_shouyiren/ui/ui_seal.svg"

# ---- v7.1 残面三现（T13 / L-09）
# 三张 FX 之前在库里但从未被引用，也未登记 ALL_PATHS —— 属于"有图等于没图"。
const BOSS_MASK_GLOW := "res://assets/art_shouyiren/fx/boss_mask_glow.svg"
const BOSS_LANTERN_DRAIN := "res://assets/art_shouyiren/fx/boss_lantern_drain.svg"
const BOSS_WARNING_RING := "res://assets/art_shouyiren/fx/boss_warning_ring.svg"

# ---- v8 长夜巡更（docs/design/v8-changye-plan.md §7.3 必须 + 推荐）
# 生成器 assets/craftkeepers/v8_build.py；只登记资源，不接线。
# 忘市地貌 / 摊位构件 / 新杂兵与新武器先落盘，等玩法侧开火与刷怪再接。
const TOMB_TILE := "res://assets/art_shouyiren/ground/tomb_tile.svg"
const OLD_AWNING := "res://assets/art_shouyiren/stalls/old_awning.svg"
const CLOTH_PILE := "res://assets/art_shouyiren/stalls/cloth_pile.svg"
const BRICK_PILE := "res://assets/art_shouyiren/stalls/brick_pile.svg"
const ENEMY_BRICK := "res://assets/art_shouyiren/enemies/enemy_brick.svg"
const BOSS_TOP := "res://assets/art_shouyiren/enemies/boss_top.svg"
const TONGCAO := "res://assets/art_shouyiren/weapons/tongcao.svg"
const TONGCAO_PETAL := "res://assets/art_shouyiren/weapons/tongcao_petal.svg"
const BANGZI := "res://assets/art_shouyiren/weapons/bangzi.svg"
const CHAR_WATCH := "res://assets/art_shouyiren/characters/char_watch.svg"

# ---- v8 推荐件（§7.3 同批交付）
# enemy_brick 只有 1 帧：**刻意不进 ENEMY_FRAMES / ENEMY_SHELL**。
# 案里 §4.2 明确"结壳层是视觉骗人的推荐件"，接线前先确认玩法要骗，
# 否则一只 48px 砖怪突然换贴图，玩家会读成"刷了只新的"。
const ENEMY_BRICK_SHELL := "res://assets/art_shouyiren/enemies/enemy_brick_shell.svg"
const TONGCAO_EVOLVED := "res://assets/art_shouyiren/weapons/tongcao_evolved.svg"
const BANGZI_EVOLVED := "res://assets/art_shouyiren/weapons/bangzi_evolved.svg"
const AWNING_ROLL := "res://assets/art_shouyiren/stalls/awning_roll.svg"
const OLD_STALL := "res://assets/art_shouyiren/stalls/old_stall.svg"
# 花瓣飘落的 SVG 原型：推荐方案是 shader 粒子，这张只做对照/兜底。
const FX_PETAL_DRIFT := "res://assets/art_shouyiren/fx/petal_drift.svg"

# ---- 全部路径清单（给冒烟测试的"资源齐备性"守卫用）
# 新增资源时**必须**在这里补一行，否则换图漏接不会被测试发现。
const ALL_PATHS: Array[String] = [
	PLAYER, PLAYER_BACK,
	PLAYER_FRONT_2, PLAYER_FRONT_3, PLAYER_BACK_2, PLAYER_BACK_3,
	ENEMY_CUP, ENEMY_CUP_FAST, ENEMY_BAG, ELITE_BOX, ELITE_RED, REAPER,
	SHELL_CRUST, BOSS_DRUM, BOSS_NUO, BOSS_LANTERN,
	WHIP_ARC, HALO_RING, BULLET_GLOWSTICK, WAND_GLOWSTICK,
	AXE_EXTINGUISHER, KNIFE_BOXCUTTER, PHONE_ORBIT,
	GONG, INKLINE, WOODBLOCK_PRINT,
	GONG_EVOLVED, INKLINE_EVOLVED, EXTINGUISHER_EVOLVED,
	GEM_BLUE, GEM_ORANGE, CHEST, COIN, PICKUP_BENTO, PICKUP_BOMB, PICKUP_MAGNET,
	PASSIVE_REGEN, PASSIVE_SHIELD,
	GROUND_TILE, PROP_BIKE, PROP_CONE, PROP_HYDRANT, PROP_TRASH, PROP_VENDING,
	FX_SPARK, FX_EVOLVE, FX_SURGE_RING,
	UI_BAR_FILL, UI_BAR_FRAME, UI_BAR_TICKS, UI_CARD_FRAME, BG_CITY,
	UI_SKILL_ROAR, UI_REFINE_BADGE,
	AWAKEN_BADGE, MOLTEN_BLOB, INK_LINE_TEX, WOODBLOCK_SEAL,
	INTRO_1, INTRO_2, INTRO_3, UI_WOOD_SIGN,
	# v7.1 内容纵深：置景八张 + 五张立绘 + 图鉴底板 + 三张 Boss FX
	STALL_FORGE, STALL_LANTERN, STALL_PAPER, STALL_SHADOW, STALL_SUGAR,
	ARCHWAY, OLD_STAGE, LANTERN_PILLAR,
	CHAR_FORGE, CHAR_LANTERN, CHAR_PAPER, CHAR_SHADOW, CHAR_SUGAR,
	CODEX_BG, UI_SEAL,
	BOSS_MASK_GLOW, BOSS_LANTERN_DRAIN, BOSS_WARNING_RING,
	# v7.1 杂兵行走帧与结壳变体
	ENEMY_CUP_2, ENEMY_CUP_3, ENEMY_CUP_SHELL,
	ENEMY_CUP_FAST_2, ENEMY_CUP_FAST_3, ENEMY_CUP_FAST_SHELL,
	ENEMY_BAG_2, ENEMY_BAG_3, ENEMY_BAG_SHELL,
	# v8 长夜巡更：10 张必须 + 6 张推荐
	TOMB_TILE, OLD_AWNING, CLOTH_PILE, BRICK_PILE,
	ENEMY_BRICK, BOSS_TOP, TONGCAO, TONGCAO_PETAL, BANGZI, CHAR_WATCH,
	ENEMY_BRICK_SHELL, TONGCAO_EVOLVED, BANGZI_EVOLVED,
	AWNING_ROLL, OLD_STALL, FX_PETAL_DRIFT,
]

# ---- 资源语义键（给测试用）
# 只描述"这个槽位应该是什么"，不描述"文件叫什么"。
# ⚠️ 值是**文件名主干**（不含目录与 .svg），断言用 get_file() 精确比对，
#    避免 "enemy_cup" 误命中 "enemy_cup_fast" 这类子串冲突。
const KEY_PLAYER_FRONT := "shouyiren_front"
const KEY_PLAYER_BACK := "shouyiren_back"
const KEY_PLAYER_FRONT_2 := "shouyiren_front_2"
const KEY_PLAYER_FRONT_3 := "shouyiren_front_3"
const KEY_PLAYER_BACK_2 := "shouyiren_back_2"
const KEY_PLAYER_BACK_3 := "shouyiren_back_3"
const KEY_MOB_BASE := "paper_scrap"             # 原 enemy_cup
const KEY_MOB_FAST := "broken_kite"             # 原 enemy_cup_fast
const KEY_MOB_HEAVY := "broken_puppet"          # 原 enemy_bag
const KEY_ELITE_BOX := "ink_blob_elite"         # 原 enemy_elite_box
const KEY_ELITE_RED := "faceless_nuo_elite"     # 原 enemy_elite_red
const KEY_BOSS_BASE := "lost_visage"            # 原 enemy_reaper
const KEY_GEM_SMALL := "light_bloom"            # 原 gem_blue
const KEY_GEM_BIG := "gold_spark"               # 原 gem_orange
const KEY_HALO_RING := "lantern_halo"           # 原 halo_ring
const KEY_CARD_FRAME := "ui_paper_card"         # 原 ui_card_frame
# ---- v5 新增槽位
const KEY_WEAPON_GONG := "gong"
const KEY_WEAPON_INKLINE := "inkline"
const KEY_WEAPON_PRINT := "woodblock_print"
const KEY_ENEMY_SHELL := "shell_crust"
const KEY_UI_SKILL_ROAR := "skill_roar"
const KEY_UI_REFINE_BADGE := "refine_badge"
const KEY_PASSIVE_REGEN := "passive_regen"
const KEY_PASSIVE_SHIELD := "passive_shield"
# ---- v7.1 T10：杂兵不再是"一张图"，是 3 帧行走 + 1 张结壳变体
# 文件主干就是本体主干 + 后缀，所以这里单独列出来，给 SLOT_ALIASES 组槽位用。
const KEY_MOB_BASE_2 := "paper_scrap_2"
const KEY_MOB_BASE_3 := "paper_scrap_3"
const KEY_MOB_BASE_SHELL := "paper_scrap_shell"
const KEY_MOB_FAST_2 := "broken_kite_2"
const KEY_MOB_FAST_3 := "broken_kite_3"
const KEY_MOB_FAST_SHELL := "broken_kite_shell"
const KEY_MOB_HEAVY_2 := "broken_puppet_2"
const KEY_MOB_HEAVY_3 := "broken_puppet_3"
const KEY_MOB_HEAVY_SHELL := "broken_puppet_shell"

# ---- 槽位 → 合法文件名主干
# P2 已换完图并**收口**：只保留新名。若这里还留旧名，就等于允许"漏接的那条路径"
# 静默通过断言（P1 过渡期的旧名已删除，见 P2 执行报告 §收口）。
const SLOT_ALIASES: Dictionary = {
	"player_front": [KEY_PLAYER_FRONT],
	"player_back": [KEY_PLAYER_BACK],
	"player_front_2": [KEY_PLAYER_FRONT_2],
	"player_front_3": [KEY_PLAYER_FRONT_3],
	"player_back_2": [KEY_PLAYER_BACK_2],
	"player_back_3": [KEY_PLAYER_BACK_3],
	# 【T10 起是"组槽位"】走路帧和结壳变体都还是这只怪，槽位问的是"长什么样"，
	# 不是"当前停在第几帧"。断言用 is_slot("mob_heavy") 时接受整组 ——
	# 和 is_player_front 把 player_front/_2/_3 算同组是同一个口径。
	# 仍然精确到主干：broken_kite 的帧不会误命中 mob_base。
	"mob_base": [KEY_MOB_BASE, KEY_MOB_BASE_2, KEY_MOB_BASE_3, KEY_MOB_BASE_SHELL],
	"mob_fast": [KEY_MOB_FAST, KEY_MOB_FAST_2, KEY_MOB_FAST_3, KEY_MOB_FAST_SHELL],
	"mob_heavy": [KEY_MOB_HEAVY, KEY_MOB_HEAVY_2, KEY_MOB_HEAVY_3, KEY_MOB_HEAVY_SHELL],
	"elite_box": [KEY_ELITE_BOX],
	"elite_red": [KEY_ELITE_RED],
	"boss_base": [KEY_BOSS_BASE],
	"gem_small": [KEY_GEM_SMALL],
	"gem_big": [KEY_GEM_BIG],
	"halo_ring": [KEY_HALO_RING],
	"card_frame": [KEY_CARD_FRAME],
	"weapon_gong": [KEY_WEAPON_GONG],
	"weapon_inkline": [KEY_WEAPON_INKLINE],
	"weapon_print": [KEY_WEAPON_PRINT],
	"enemy_shell": [KEY_ENEMY_SHELL],
	"ui_skill_roar": [KEY_UI_SKILL_ROAR],
	"ui_refine_badge": [KEY_UI_REFINE_BADGE],
	"passive_regen": [KEY_PASSIVE_REGEN],
	"passive_shield": [KEY_PASSIVE_SHIELD],
}

static func tex(path: String) -> Texture2D:
	return load(path) as Texture2D

## 这张图是否属于某个槽位（按文件名主干精确比对）。
static func is_slot(path: String, slot: String) -> bool:
	var stem := path.get_file().get_basename()
	var keys: Array = SLOT_ALIASES.get(slot, [])
	return stem in keys

## 角色帧组判定：正面组（下 / 左 / 右）与背面组（上）。走路帧算同组 ——
## 测"朝向对不对"时关心的是正/背，不是当前停在第几帧。
static func is_player_front(path: String) -> bool:
	return is_slot(path, "player_front") or is_slot(path, "player_front_2") or is_slot(path, "player_front_3")

static func is_player_back(path: String) -> bool:
	return is_slot(path, "player_back") or is_slot(path, "player_back_2") or is_slot(path, "player_back_3")

## 进化形态的专属贴图。没有独立图的进化返回空串（调用方回落到本体图）。
## 放在 Art 而不是 EvolutionDB：EvolutionDB 是纯数据表，不该知道美术换没换。
const EVOLVED_WEAPON_SVG: Dictionary = {
	"gong": GONG_EVOLVED,
	"inkline": INKLINE_EVOLVED,
	"extinguisher": EXTINGUISHER_EVOLVED,
	"tongcao": TONGCAO_EVOLVED,
	"bangzi": BANGZI_EVOLVED,
}

static func evolved_weapon_svg(weapon_id: String) -> String:
	return String(EVOLVED_WEAPON_SVG.get(weapon_id, ""))

static func sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s
