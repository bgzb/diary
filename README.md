# Diary

A Typora-like markdown diary app built with SwiftUI.

## 安装

### 下载

从 [Releases](../../releases) 页面下载最新的 `Diary.dmg`。

### 首次打开（重要）

由于 Diary 未使用 Apple Developer ID 签名，macOS Gatekeeper 会阻止运行。首次打开需要：

**方法 1 - 右键打开（推荐）**
1. 双击 DMG 挂载
2. 将 `Diary.app` 拖入 `Applications` 文件夹
3. 在 Applications 中**右键点击** Diary.app → **打开**
4. 在弹出的对话框中点击 **仍要打开**

**方法 2 - 终端命令**
```bash
# 移除隔离属性
xattr -cr /Applications/Diary.app
```
之后就可以正常双击打开了。

> 💡 **为什么会出现 "已损坏" 提示？**  
> Apple 要求所有在 App Store 外分发的应用进行公证（notarization），需要 $99/年的 Apple Developer Program 会员。Diary 是开源项目，目前使用 ad-hoc 签名。应用本身没有问题，只是 macOS 的安全策略拦截了未公证的应用。

## 开发

```bash
# 构建
./build.sh

# 打包 DMG
./make_dmg.sh

# 运行
open Diary.app
```

## 系统要求

- macOS 14.0+
- Apple Silicon (M1/M2/M3/M4) 或 Intel Mac
