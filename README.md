# V2Bar

<div align="center">
    <img src="Screenshots/icon.png" width="160" height="160" alt="V2Bar Icon">
</div>

<div align="center">

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-brightgreen)](https://github.com/ysgdbd/V2Bar/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://github.com/ysgdbd/V2Bar)
[![Tuist](https://img.shields.io/badge/Powered%20by-Tuist-blue)](https://tuist.io)
[![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue)](https://developer.apple.com/xcode/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-blue)](https://developer.apple.com/xcode/swiftui/)

</div>

V2Bar 是一个简洁优雅的 macOS 菜单栏应用，为你提供快捷的 V2EX 访问体验。

## 预览

<div align="center">
    <img src="Screenshots/preview.png" width="375" alt="V2Bar Preview">
</div>

## 功能特点

- 🚀 原生 SwiftUI 开发
- 🔔 暗黑模式支持
- ⚡️ 便捷的菜单栏操作
- 💬 消息中心查看
- 👤 快速获取个人信息
- 🔗 快速访问 V2EX 各种链接
- ✍️ 创建新主题

## 系统要求

- macOS 13.0 或更高版本
- 支持 Apple Silicon 和 Intel 芯片

## 安装

### 使用 Homebrew 安装

```bash
# 添加 tap
brew tap ysgdbd/tap
# 安装应用
brew install v2bar
```

### 手动安装

1. 从 [Releases](https://github.com/ysgdbd/V2Bar/releases) 页面下载最新版本的 DMG 文件
2. 打开 DMG 文件并将 V2Bar 拖入 Applications 文件夹
3. 从 Applications 文件夹启动 V2Bar

## 开发

本项目使用 [Tuist](https://tuist.io) 管理，确保你已安装了以下依赖：

```bash
brew install tuist
```

然后克隆项目并生成 Xcode 工程：

```bash
git clone https://github.com/ysgdbd/V2Bar.git
cd V2Bar
tuist generate
```

## 反馈

如果你发现了 bug 或有新功能建议，欢迎提交 [Issue](https://github.com/ysgdbd/V2Bar/issues)。

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件 