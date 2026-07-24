<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Design/AppIcon/Previews/v2bar-icon-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="Design/AppIcon/Previews/v2bar-icon-default.png">
    <img src="Design/AppIcon/Previews/v2bar-icon-default.png" width="160" height="160" alt="V2Bar App 图标">
  </picture>
</p>

<h1 align="center">V2Bar</h1>

<p align="center">一款原生 macOS 菜单栏工具，快速查看 V2EX 账户信息与最近通知。</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white">
  <img alt="Swift 5.9" src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0D96F6">
  <img alt="TCA" src="https://img.shields.io/badge/Architecture-TCA-7C3AED">
  <img alt="Xcode 26.5" src="https://img.shields.io/badge/Xcode-26.5-147EFB?logo=xcode&logoColor=white">
  <img alt="Universal Binary" src="https://img.shields.io/badge/Universal-Apple%20Silicon%20%2B%20Intel-555555">
  <a href="https://github.com/ygsgdbd/V2Bar/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/ygsgdbd/V2Bar?display_name=tag&sort=semver&label=Release"></a>
  <a href="https://github.com/ygsgdbd/homebrew-tap"><img alt="Homebrew" src="https://img.shields.io/badge/Homebrew-available-FBB040?logo=homebrew&logoColor=black"></a>
</p>

## 🖼️ 截图预览

![V2Bar 浅色模式菜单](Screenshots/preview-light.png#gh-light-mode-only)

![V2Bar 暗色模式菜单](Screenshots/preview-dark.png#gh-dark-mode-only)

## ✨ 功能亮点

- **连接 V2EX 账户。** 设置 Personal Access Token 后先验证有效性，再读取账户资料、Token 有效期和头像；Token 可随时更换或移除。
- **集中查看最近通知。** 将最近通知按主题聚合，区分回复、收藏、感谢和其他事件，并可直接打开相关主题或用户主页。
- **快速访问常用页面。** 从菜单栏直达 V2EX 首页、时间轴、创建主题、通知和个人设置。
- **按自己的节奏刷新。** 默认在打开菜单时刷新，也可选择每 5、15、30 分钟刷新或关闭自动刷新。
- **融入日常使用。** 支持登录时启动，并在菜单栏中显示账户刷新状态；项目已接入 Sparkle 更新入口，将在下一个包含 `appcast.xml` 的 Release 后用于应用内检查更新。

## 🪶 原生与轻量

- **原生菜单栏体验。** V2Bar 使用 Swift、SwiftUI 和 The Composable Architecture（TCA）构建，基于 `MenuBarExtra` 与 `LSUIElement` 运行，不包含 Electron 运行时或嵌入式 WebView。
- **只保留必要状态。** Token 和自动刷新设置通过 macOS 本地存储保存；账户、头像与通知数据从 V2EX 获取，不依赖本项目自建服务端。
- **跟随系统外观。** 界面使用原生 SwiftUI 菜单控件，自动适配 macOS 浅色与暗色模式。
- **同时支持新旧 Mac。** Release workflow 使用 Xcode 26.5 构建，并验证发布产物同时包含 `arm64` 与 `x86_64` 架构。

## 📦 安装

> [!IMPORTANT]
> 本 README 描述的是 `main` 分支当前正在开发的版本。GitHub Releases 与 Homebrew 目前仍提供较旧的 `v0.1.1`，其系统要求和功能与本文描述可能不同。通知聚合、自动刷新和登录时启动可从源码构建体验；Sparkle 检查更新需等待下一个包含 `appcast.xml` 的 Release。

### 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon 或 Intel Mac（Universal Binary）

### Homebrew

`brew trust` 命令首次随 Homebrew 5.1.15 发布。在 Homebrew 5.1.15–5.x 中，只有启用 `HOMEBREW_REQUIRE_TAP_TRUST=1` 时才会要求信任；从 Homebrew 6.0.0 开始，默认要求显式信任非官方 tap 中的 cask。

```bash
brew tap ygsgdbd/tap
brew trust --cask ygsgdbd/tap/v2bar
brew install --cask v2bar
```

上述 `brew trust` 命令只允许 Homebrew 加载第三方 `v2bar` cask，不会信任整个 tap；信任记录通常只需设置一次。对应 cask 的自定义 `postflight` 会在安装后移除 V2Bar 的 quarantine 属性，因此 Homebrew 安装版可直接启动。V2Bar 仍未使用 Apple Developer ID 签名且未经 notarization（公证）；`brew trust` 或移除 quarantine 都不代表获得 Apple 或 Gatekeeper 的认证。详情请参阅 Homebrew 官方的 [Tap Trust 文档](https://docs.brew.sh/Tap-Trust)。

Homebrew 5.1.14 及更早版本没有 `brew trust`，也不需要执行该命令：

```bash
brew tap ygsgdbd/tap
brew install --cask v2bar
```

如果执行 `brew trust` 时出现 `Unknown command: trust`，请跳过该命令，或先运行 `brew update` 升级 Homebrew。

更新 Homebrew 安装版：

```bash
brew upgrade v2bar
```

如果 Homebrew 提示 `Refusing to load cask ... from untrusted tap`，请先执行：

```bash
brew trust --cask ygsgdbd/tap/v2bar
```

然后重新运行安装或升级命令。如果已有安装在升级 Homebrew 后无法更新，也请先信任该 cask，再重试 `brew upgrade v2bar`。

### 手动安装

1. 从[最新 GitHub Release](https://github.com/ygsgdbd/V2Bar/releases/latest) 下载 `V2Bar.dmg`。
2. 打开 DMG，将 `V2Bar.app` 拖入“应用程序”文件夹。
3. 从“应用程序”文件夹启动 V2Bar。

### 手动安装版的首次启动与 Gatekeeper

以下步骤仅适用于从 GitHub Release 下载 DMG 的手动安装版。当前公开 Release **没有 Developer ID 签名，也没有经过 notarization（公证）**，macOS 可能阻止首次启动。

1. 在 Finder 中按住 Control 点击或右键点击 `V2Bar.app`，选择**打开**，然后再次确认**打开**。
2. 如果仍被阻止，请前往**系统设置 → 隐私与安全性**，找到 V2Bar 相关提示，点击**仍要打开**并确认。

仅当 App 来自本仓库的官方 GitHub Releases 且你信任该下载内容时，才应绕过 Gatekeeper。

### 发布产物验证

从下一次采用当前 Release workflow 的版本开始，Release 将提供 `V2Bar.dmg` 的 SHA-256、Sparkle `appcast.xml` 中的 EdDSA 签名，以及 GitHub Artifact Attestation。下载 DMG 后可验证其构建来源：

```bash
gh attestation verify V2Bar.dmg --repo ygsgdbd/V2Bar
```

Artifact Attestation 用于验证发布产物的构建来源，不等于 Developer ID 签名或 notarization（公证），也不代表通过 Apple 或 Gatekeeper 认证。

## 🚀 使用说明

1. 前往 V2EX 的 [Token 设置页面](https://www.v2ex.com/settings/tokens) 创建 Personal Access Token。
2. 启动 V2Bar，点击菜单栏中的 `V2`，选择“设置 Token”。
3. 输入 Token；验证通过后，菜单会加载账户资料与最近通知。
4. 从通知分组查看回复、收藏和感谢，点击通知或“打开主题”跳转到 V2EX。
5. 在“自动刷新”中选择打开菜单时刷新、每 5/15/30 分钟刷新或关闭。
6. 使用 `main` 源码构建时，可按需启用“登录时启动”；下一个包含 `appcast.xml` 的 Release 发布后，“检查更新…”才能用于获取后续版本。

> [!NOTE]
> Personal Access Token 会保存在当前 Mac 上。请妥善保管，不要将其粘贴到 Issue、日志或截图中。

## 🧪 开发与测试

项目使用 [Tuist](https://tuist.dev/) 管理 Xcode 工程，源码目标为 macOS 14.0+、Swift 5.9；Release workflow 使用 Xcode 26.5。

```bash
brew install tuist
git clone https://github.com/ygsgdbd/V2Bar.git
cd V2Bar
tuist generate --no-open
open V2Bar.xcworkspace
```

运行与发布 workflow 一致的测试：

```bash
xcodebuild test \
  -workspace V2Bar.xcworkspace \
  -scheme V2Bar \
  -destination "platform=macOS" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

测试覆盖账户刷新、Token 验证、通知聚合、自动刷新、登录项、系统操作、模型解析和 README 截图配置。

如需重新生成 README 截图，请先安装 ImageMagick 与 `rtk`，为终端授予“屏幕与系统音频录制”和“辅助功能”权限，退出其他 V2Bar 实例后执行：

```bash
./script/generate_readme_screenshots.sh
./script/validate_readme_screenshots.sh
```

## 💬 问题反馈

如果遇到问题或有功能建议，请提交 [Issue](https://github.com/ygsgdbd/V2Bar/issues)。反馈问题时请附上 macOS 版本、V2Bar 版本和可复现步骤，并注意移除 Token 等敏感信息。
