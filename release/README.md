# 守艺人 · 百工夜行 — 发布包（v1.0）

Godot 4.7.2（Mobile 渲染器，D3D12 / Vulkan）导出的可运行版本。竖屏 720×1280，60 FPS。

## 下载

三个文件都超过 GitHub 普通仓库的单文件上限（Windows 单文件 exe 110 MB > 100 MB），
因此**托管在本仓库的 Releases 页**，不从源码树分发：

> **下载地址**：<https://github.com/LjxMax2003/FirstXiXueGui/releases/tag/v1.0>

| 附件 | 平台 | 说明 |
| --- | --- | --- |
| `FirstXiXueGui.exe` | Windows 10/11 x86_64 | 单文件版，PCK 已内嵌，下载即可双击运行 |
| `FirstXiXueGui-Windows-x64-v1.0.zip` | Windows 10/11 x86_64 | 同上 exe 的压缩包，便于传输 |
| `FirstXiXueGui-1.0.apk` | Android 7.0+ arm64-v8a | 已签名，可侧载 |

## 校验值（SHA-256）

```
a9229107751912a796a8f104d9b13425d5cc7e69c623fe606377672dbd16f4b8  FirstXiXueGui-Windows-x64-v1.0.zip
570c281607aa51fe20d3fbb5fe2a45a4fe231069309abebd2dff37c5f60df8ba  FirstXiXueGui.exe
4bcffbcef448148dc4ed0517b659fa471977774148eeac683c6ac69d30fb1ae2  FirstXiXueGui-1.0.apk
```

Windows 校验：

```powershell
Get-FileHash .\FirstXiXueGui.exe -Algorithm SHA256
```

## Windows

- 要求：Windows 10/11 x86_64，支持 D3D12 的显卡。若启动时提示缺少 `MSVCP140.dll` / `VCRUNTIME140.dll`，请安装 [VC++ 2015-2022 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe)。
- 运行：双击 `FirstXiXueGui.exe`。
- 操作：WASD / 方向键移动，鼠标操作界面；触屏逻辑在桌面端也可用鼠标拖拽（模拟触摸）。
- 存档：`%APPDATA%\Godot\app_userdata\FirstXiXueGui\`（铜钱、传承、图鉴、设置）。

## Android

- 要求：Android 7.0（API 24）及以上，arm64-v8a 设备（近几年的手机基本都满足）。
- 包名：`com.qodergame.firstxixuegui`；版本：`1.0 (1)`；targetSdk 36。
- 安装：把 APK 传到手机后用文件管理器打开，或在电脑上执行
  ```
  adb install -r FirstXiXueGui-1.0.apk
  ```
  首次安装需允许"安装未知来源应用"。
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
  "E:/AITemp/QoderGameFirst/release/android/FirstXiXueGui-1.0.apk"
```

Android 导出依赖的项目设置（已写入 `project.godot`）：`rendering/textures/vram_compression/import_etc2_astc=true`、`display/window/handheld/orientation=1`（竖屏）。

## 发布新版本时

```bash
# 1. 导出到 release/（该目录下的二进制已被 .gitignore 排除，不会进仓库）
# 2. 上传为 Release 附件
gh release create v1.1 release/windows/FirstXiXueGui.exe release/*.apk \
  --title "v1.1" --notes "更新说明"
# 3. 同步更新本文件的校验值与下载链接
```
