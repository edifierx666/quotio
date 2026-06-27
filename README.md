# Edx

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="screenshots/menu_bar_dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="screenshots/menu_bar.png" />
    <img alt="Edx menu bar" src="screenshots/menu_bar.png" height="560" />
  </picture>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg?style=flat" alt="Platform macOS 14+" />
  <img src="https://img.shields.io/badge/language-Swift%206-orange.svg?style=flat" alt="Swift 6" />
  <img src="https://img.shields.io/badge/ui-SwiftUI-blue.svg?style=flat" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat" alt="MIT License" />
</p>

<p align="center">
  <strong>面向 AI 编程工具的 macOS 菜单栏控制台。</strong><br />
  管理本地代理、远端代理、AI 账号配额、CLI Agent 配置，以及你自己的常驻命令服务。
</p>

## 项目定位

Edx 是一款原生 macOS 应用，用来把日常 AI 编程工作流里的几个分散问题收口到一个控制台：

- 启动、停止和升级本机的 CLIProxyAPI 代理服务。
- 连接多个 AI Provider 账号，并在同一处查看状态与配额。
- 把 Claude Code、Codex CLI、Gemini CLI、OpenCode 等 CLI Agent 配到同一个代理入口。
- 在菜单栏快速查看代理状态、账号配额和自定义服务状态。
- 管理自定义长驻命令，例如本地 proxy、辅助 daemon、隧道进程或团队内部工具。

它不是聊天客户端，而是 AI Coding Agent 的本地运维面板：让代理、账号、配额、配置文件和后台服务都变得可见、可控、可恢复。

## 核心功能

### 代理控制台

- 自动下载并管理 CLIProxyAPI 二进制文件。
- 默认本地代理端口为 `8317`，对外提供 OpenAI 风格的 `/v1` 入口。
- 支持启动、停止、自动启动、健康检查、崩溃恢复和版本升级。
- 支持本地代理、远端代理和仅监控模式。
- 支持请求重试、上游代理、日志开关、远程管理密钥等运行参数。

### AI 账号与配额监控

- 将多个 Provider 的账号统一展示为可管理资源。
- 支持账号状态、禁用状态、冷却状态、错误信息和配额百分比展示。
- 支持按账号和模型查看用量，菜单栏可显示低配额提醒。
- 支持不启动代理的监控模式，适合只想看 Claude Code、Codex、Gemini、Cursor 等工具配额的用户。

### CLI Agent 一键配置

Edx 可以检测并配置常用 AI 编程 CLI，把它们指向统一的代理入口：

| Agent | 典型二进制 | 配置方式 |
| --- | --- | --- |
| Claude Code | `claude` | settings 与环境变量 |
| Codex CLI | `codex` | TOML 与 auth 配置 |
| Gemini CLI | `gemini` | 环境变量 |
| Amp CLI | `amp` | settings 与 secrets |
| OpenCode | `opencode` / `oc` | JSON 配置 |
| Factory Droid | `droid` / `factory-droid` / `fd` | JSON 配置 |

配置可以自动写入，也可以生成手动配置内容复制使用。应用会尽量保留已有配置，并提供备份与恢复入口。

### 自定义 Provider

除了内置 Provider，Edx 还支持将自有或第三方模型服务接入代理：

- OpenAI-compatible API，例如 OpenRouter、Ollama、LM Studio、vLLM。
- Claude-compatible API。
- Gemini-compatible API，可配置自定义 Header。
- Codex-compatible API。
- GLM / BigModel API Key 接入。
- 支持模型别名、模型白名单、API Key 列表和可选上游代理。

### 自定义长驻服务

Custom Services 是当前项目的重要扩展能力。你可以在 Edx 中添加任意长时间运行的命令：

- 配置服务名称、命令、工作目录和环境变量。
- 一键启动、停止，并查看实时 stdout / stderr 日志。
- 可选择是否显示在菜单栏。
- 可选择随 Edx 启动自动启动。
- 可绑定 GitHub 仓库，检查最新 Release 并跳转下载页面。
- 退出应用时会统一停止已管理的服务，避免后台残留。

适合管理类似 `headroom proxy ...`、Cloudflare tunnel、本地模型服务、团队内部网关等命令行进程。

### 菜单栏工作流

- 原生 macOS 菜单栏入口，随时查看代理运行状态。
- 可展示多个 Provider 的配额摘要和账号状态。
- 可展示自定义服务并进行快速启动/停止。
- 支持浅色、深色和跟随系统外观。
- 支持低配额、账号冷却、代理异常等通知。

### 远端与隧道

- 可以连接远端 CLIProxyAPI 管理端点，只在本机查看和管理远端账号状态。
- 支持 Cloudflare tunnel 相关配置，用于把本地代理安全暴露给远端设备或团队环境。
- 远端管理依赖管理密钥，请只在可信网络或 HTTPS 隧道下使用。

## 支持的生态

### Provider 与账号来源

| Provider / 工具 | 接入方式 | 主要用途 |
| --- | --- | --- |
| Gemini CLI | OAuth / 本地凭据 | 代理与配额 |
| Claude Code | OAuth / CLI 用量读取 | 代理与配额 |
| Codex / OpenAI | OAuth / CLI 凭据 | 代理与配额 |
| Qwen Code | OAuth | 代理账号管理 |
| iFlow | OAuth | 代理账号管理 |
| Antigravity | OAuth / 本地状态 | 代理、配额与账号切换 |
| Vertex AI | Service Account JSON | 代理账号管理 |
| Kiro | CLI 登录流程 | 代理与配额 |
| GitHub Copilot | Device Flow / CLI 登录流程 | 代理与配额 |
| Cursor | 本地应用会话检测 | 配额监控 |
| Trae | 本地应用会话检测 | 配额监控 |
| Warp | 本地凭据 / API Key | 配额监控 |
| GLM | API Key / Custom Provider | 自定义代理与配额 |

不同 Provider 的能力不完全一致：有些可以作为代理上游，有些只适合作为只读配额来源。Edx 会按当前模式和本机环境自动展示可用能力。

### 运行模式

| 模式 | 适合场景 | 可用能力 |
| --- | --- | --- |
| Monitor | 只想看账号和配额，不需要本地代理 | 读取本地凭据、刷新配额、菜单栏提醒 |
| Local Proxy | 在本机运行 CLIProxyAPI | 代理控制、账号认证、Agent 配置、API Key、日志与隧道 |
| Remote Proxy | 连接远端 CLIProxyAPI | 查看远端状态、管理账号、刷新远端数据 |

## 快速开始

### 系统要求

- macOS 14.0 或更新版本。
- Xcode 16 或更新版本用于源码构建。
- Swift 6。
- OAuth、Release 检查和代理二进制下载需要网络访问。

### 从源码运行

克隆本仓库后，用 Xcode 打开项目：

```bash
open Edx.xcodeproj
```

选择 `Edx` scheme，按 `Cmd + R` 构建并运行。

也可以使用命令行构建：

```bash
xcodebuild \
  -project Edx.xcodeproj \
  -scheme Edx \
  -configuration Debug \
  build
```

首次进入 Local Proxy 模式时，应用会根据当前平台下载或安装 CLIProxyAPI 二进制文件。

### 首次使用流程

1. 启动 Edx，选择运行模式。
2. 如果使用 Local Proxy，先安装并启动本地代理。
3. 添加 Provider 账号，或导入已有本地凭据。
4. 在 Dashboard 中检查账号状态和配额。
5. 按需配置 Claude Code、Codex CLI、Gemini CLI 等 Agent。
6. 如果有额外后台命令，进入 Custom Services 添加并启用菜单栏展示。

## 常见配置位置

| 路径 | 用途 |
| --- | --- |
| `~/Library/Application Support/Edx/` | Edx 应用支持目录、代理二进制与配置 |
| `~/.cli-proxy-api/` | CLIProxyAPI 账号凭据目录 |
| `~/.claude/settings.json` | Claude Code 配置 |
| `~/.codex/config.toml` | Codex CLI 配置 |
| `~/.config/opencode/opencode.json` | OpenCode 配置 |

应用会尽量通过 Keychain、UserDefaults 和对应工具的原生配置文件保存状态。涉及 API Key、OAuth Token、远端管理密钥时，请只在可信机器上使用。

## 截图

### Dashboard

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="screenshots/dashboard_dark.png" />
  <source media="(prefers-color-scheme: light)" srcset="screenshots/dashboard.png" />
  <img alt="Dashboard" src="screenshots/dashboard.png" />
</picture>

### Menu Bar

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="screenshots/menu_bar_dark.png" />
  <source media="(prefers-color-scheme: light)" srcset="screenshots/menu_bar.png" />
  <img alt="Menu Bar" src="screenshots/menu_bar.png" height="560" />
</picture>

### Settings

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="screenshots/settings_dark.png" />
  <source media="(prefers-color-scheme: light)" srcset="screenshots/settings.png" />
  <img alt="Settings" src="screenshots/settings.png" />
</picture>

## 开发者说明

项目主要由 SwiftUI、AppKit 和 Swift Concurrency 构成：

```text
Edx/
├── EdxApp.swift                 # 应用入口、窗口和菜单栏生命周期
├── Models/                      # Provider、运行模式、菜单栏、自定义服务等领域模型
├── Services/                    # 代理管理、API Client、Agent 配置、配额获取、状态栏、隧道
├── ViewModels/                  # Dashboard 与 Agent 配置状态
└── Views/                       # Dashboard、Custom Services、Settings、About 与通用组件
```

常用脚本位于 `scripts/`：

| 脚本 | 用途 |
| --- | --- |
| `scripts/build.sh` | Release 构建归档 |
| `scripts/package.sh` | 打包 DMG |
| `scripts/release.sh` | 发布流程编排 |
| `scripts/bump-version.sh` | 版本号更新 |
| `scripts/generate-appcast.sh` | Sparkle appcast 生成 |

## 安全提示

- 自定义服务会以当前 macOS 用户身份执行命令，请只添加可信命令。
- 远端代理管理密钥等同于管理权限，请不要公开提交或写入截图。
- 如果启用远端访问或隧道，请优先使用 HTTPS，并限制可访问范围。
- OAuth Token、API Key 和账号文件可能保存在本机配置目录或 Keychain 中，迁移设备前请自行确认备份策略。

## License

MIT License. See `LICENSE` for details.
