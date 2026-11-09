# 守艺人 · 百工夜行 — 发布包（v2.0）

Godot 4.7.2（Mobile 渲染器，D3D12 / Vulkan）导出的可运行版本。竖屏 720×1280，60 FPS。

## 下载

三个文件都超过 GitHub 普通仓库的单文件上限（Windows 单文件 exe 约 117 MB > 100 MB），
因此**托管在本仓库的 Releases 页**，不从源码树分发：

> **下载地址**：<https://github.com/LjxMax2003/FirstXiXueGui/releases/tag/v2.0>

| 附件 | 平台 | 说明 |
| --- | --- | --- |
| `FirstXiXueGui.exe` | Windows 10/11 x86_64 | 单文件版，PCK 已内嵌，下载即可双击运行 |
| `FirstXiXueGui-Windows-x64-v2.0.zip` | Windows 10/11 x86_64 | 同上 exe 的压缩包，便于传输 |
| `FirstXiXueGui-2.0.apk` | Android 7.0+ arm64-v8a | 已签名（与 v1.0 同一发布密钥），可覆盖升级 |

## 校验值（SHA-256）

```
c24ef8dbc66e030f004f877038db4cec65c4d3775483aba899fc822fe79a56ab  FirstXiXueGui-Windows-x64-v2.0.zip
826dd23d92465a33b13c644cc7cf271aa86f3267c2daec49e13013d168cdfe9d  FirstXiXueGui.exe
97f33f3057fde95d032c7ff456e12b2344c4a7481dfae97614c85face7f4db6f  FirstXiXueGui-2.0.apk
```

Windows 校验：

```powershell
Get-FileHash .\FirstXiXueGui.exe -Algorithm SHA256
```

## v2.0 相对 v1.0 的主要变化

- 迭代 02：技能关联（三配方进化 / 满级卡三态 / 空箱反馈 / 术语收口 / 九把武器全覆盖）。
- 迭代 03：进化机制化（声明位、十字扫、门神镇守、糖水粘连、铜锣回响、墨线穿透累进、视觉分层）。
- 迭代 04：升级选卡界面重构（层级归位、双层墨幕、伪 3D 五线索、入场/出场动画、连升不重播标题）。
- 2026-11-09 复诊修复：花灯环受击后视觉残留/错位（受击位移改合成赋值不再累加）、
  判定圆心与视觉圆心统一到角色身体中心、光环底板方形亮边收口。

## Windows

- 要求：Windows 10/11 x86_64，支持 D3D12 的显卡。若启动时提示缺少 `MSVCP140.dll` / `VCRUNTIME140.dll`，请安装 [VC++ 2015-2022 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe)。
- 运行：双击 `FirstXiXueGui.exe`。
- 操作：WASD / 方向键移动，鼠标操作界面；触屏逻辑在桌面端也可用鼠标拖拽（模拟触摸）。
- 存档：`%APPDATA%\Godot\app_userdata\FirstXiXueGui\`（铜钱、传承、图鉴、设置）。

## Android

- 要求：Android 7.0（API 24）及以上，arm64-v8a 设备（近几年的手机基本都满足）。
- 包名：`com.qodergame.firstxixuegui`；版本：`2.0 (2)`；targetSdk 36。
- 升级：与 v1.0 使用同一发布密钥，可直接覆盖安装（存档保留）：
  ```
  adb install -r FirstXiXueGui-2.0.apk
  ```
  或把 APK 传到手机后用文件管理器打开。首次安装需允许"安装未知来源应用"。
- 操作：屏幕任意处按住拖动即出现虚拟摇杆；界面按钮直接点触。锁定竖屏。
- 存档：应用私有目录 `user://`（卸载即清除）。

签名说明：APK 使用自签名发布密钥（RSA 2048 / 30 年），仅用于侧载分发；上架应用商店前请替换为正式发布密钥。
**签名口令不入库** —— 仓库里的 `GameDemo/first-xi-xue-gui/export_presets.cfg` 已清空 `keystore/*` 字段，
重新导出请填回自己的密钥库路径与口令。

iOS 无法在 Windows 上构建，需要 macOS + Xcode + 对应版本的 iOS 导出模板。

## 重新导出

前置：Godot 4.7.2 stable、匹配版本的导出模板（`%APPDATA%\Godot\export_templates\4.7.2.stable`）。

```bash
GODOT="D:/GameEngine/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
PROJ="E:/AITemp/QoderGameFirst/GameDemo/first-xi-xue-gui"

# Windows（单文件，PCK 内嵌）
"$GODOT" --headless --path "$PROJ" --export-release "Windows Desktop" \
  "E:/AITemp/QoderGameFirst/release/windows/FirstXiXueGui.exe"

# Android（需要 JDK 17 + Android SDK build-tools + 发布密钥库）
"$GODOT" --headless --path "$PROJ" --export-release "Android" \
  "E:/AITemp/QoderGameFirst/release/android/FirstXiXueGui-2.0.apk"
```

> **注意（headless 导出的 keystore 坑）**：命令行导出时，编辑器设置里的
> `export/android/release_keystore` 回退不生效，必须在本次导出期间把
> `export_presets.cfg` 的 `keystore/release`、`keystore/release_user`、
> `keystore/release_password` 三项临时填上，导出完成后立即清空再提交，避免口令入库。
> JDK 路径 `E:/AITemp/_godot_cache/jdk17/jdk-17.0.2`，build-tools 36.0.0。

Android 导出依赖的项目设置（已写入 `project.godot`）：`rendering/textures/vram_compression/import_etc2_astc=true`、`display/window/handheld/orientation=1`（竖屏）。

## 发布新版本时

```bash
# 1. 先改 export_presets.cfg 的 version/code 与 version/name（当前 2 / "2.0"）
# 2. 导出到 release/（该目录下的二进制已被 .gitignore 排除，不会进仓库）
# 3. 上传为 Release 附件
gh release create v2.1 release/windows/FirstXiXueGui.exe release/*.apk release/*.zip \
  --title "v2.1" --notes "更新说明"
# 4. 同步更新本文件的校验值与下载链接
```
