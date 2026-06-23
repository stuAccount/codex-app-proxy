# codex-app-proxy

**English** | [中文](./README.md)

Codex App 的本地代理管理器。单个二进制文件即可启动管理器 + 工作器 + TUI。

## 架构

```
Codex App / CLI
      │
      ▼
┌──────────┐
│  Worker  │  ← Listens on a local port, forwards requests to upstream
│  (proxy) │  ← Filters image_generation, Chat Completions translation, etc.
└──────────┘
      │
      ▼
┌──────────┐
│ Upstream │  ← Upstream API service (OpenAI, OpenRouter, Groq, etc.)
└──────────┘

┌──────────┐
│ Manager  │  ← Manages Worker lifecycle, exposes HTTP API + SSE event stream
│          │  ← TUI communicates with Manager via API
└──────────┘
      │
      ▼
┌──────────┐
│   TUI    │  ← OpenTUI (SolidJS) terminal interface
│(OpenTUI) │  ← Conversational interaction, type / to trigger commands
└──────────┘
```

### 核心概念

| 概念 | 描述 |
|---------|-------------|
| <strong>管理器</strong> | 中心管理器 — 启动/停止工作器，提供 HTTP API，TUI 连接到它 |
| <strong>工作器</strong> | 在端口上监听的本地代理进程，将请求转发到指定的上游 |
| <strong>上游</strong> | 上游 API 服务配置 (base_url、api_key、api_format) |
| <strong>模块</strong> | 工作器功能模块 (参见下面的[模块](#模块)) |

每个工作器绑定到一个上游。你可以同时在不同的端口上运行多个工作器，分别指向不同的上游。

### 模块

| 模块 | 描述 |
|--------|-------------|
| `config_patch` | 自动修改 `~/.codex/config.toml` 以将 Codex 指向工作器 |
| `image_filter` | 过滤 `image_generation` 工具调用 |
| `api_translate` | 聊天补全 ↔ 响应 API 翻译 |
| `model_override` | 通过 `params.model` 覆盖请求中的 `model` 字段 |
| `request_log` | 将请求方法和路径记录到 stderr |
| `debug_sse` | 将 SSE 块统计信息记录到 stderr |

## 构建与运行

### 前提条件

- Go 1.26+
- Bun 1.2+ (用于 TUI)

### 构建

```bash

# 安装TUI依赖项
bun install

# 构建Go二进制文件
go build -o codex-proxy .

```

### 配置

```bash
mkdir -p ${HOME}/.codex-proxy

cp config.example.yaml ${HOME}/.codex-proxy/config.yaml
# 编辑 ${HOME}/.codex-proxy/config.yaml 来设置工作线程和上游节点
```

### 运行

```bash
./codex-proxy
```

这个单一命令会启动管理器 → 启动所有工作器 → 启动 TUI。

### 开发模式 (前后端分离)

```bash
# 终端1：仅后端（默认管理器端口为9090）
./codex-proxy --config-dir ${HOME}/.codex-proxy --manager-port 9090 &

# 终端2：支持热重载的TUI
bun install  # 从项目根目录安装依赖（首次需要）
cd tui && CODEX_PROXY_URL=http://localhost:9090 bun run dev
```

## TUI 操作

启动后，你会看到一个空白屏幕，底部有一个输入栏。输入 `/` 即可打开带有模糊搜索功能的命令选择器。

### 命令列表

| 命令 | 别名 | 描述 |
|---------|-------|-------------|
| `/help` | | 显示所有命令 |
| `/settings` | `/config` | 编辑运行时设置并查看配置保存状态 |
| `/workers` | | 管理工作器 (创建、检查、编辑字段/模块、查看日志、重启/停止) |
| `/upstream` | | 管理上游 (创建、编辑 base_url/api_key/api_format) |
| `/logs` | | 查看工作器日志 |
| `/launch` | | 通过 cli 角色工作器启动 Codex CLI |
| `/exit` | `/quit` `/q` | 退出 |

### 键盘快捷键

| 键 | 操作 |
|-----|--------|
| `Ctrl+C` | 清除输入；按两次退出 |
| `Shift+Enter` | 在输入中换行 |
| `↑` `↓` | 列表导航 |
| `Enter` | 确认选择 |
| `Esc` | 取消/返回 |

## 配置文件格式

```yaml
# Runtime settings
settings:
  state_dir: ~/.codex-proxy
  log_dir: ~/.codex-proxy/logs
  launch:
    default_mode: hosted-terminal
  terminal:
    host: tmux
    opener: terminal_app
    tmux:
      socket_name: cap
      host_session: cap-host

# Worker definitions
workers:
  codex-app:              # Worker name
    port: 6767            # Local listen port
    upstream: joycode     # Bound Upstream
    role: cli             # "cli" (default) or "app"
    log_level: simple     # "simple" or "detail"
    modules:
      config_patch:       # Auto-modify ~/.codex/config.toml
        enabled: true
        config_path: ~/.codex/config.toml
      image_filter:       # Filter image_generation tool
        enabled: true
      api_translate:      # Chat Completions ↔ Responses API translation
        enabled: true

# Upstream definitions
upstreams:
  joycode:
    base_url: https://api.joycode.dev/v1
    api_key: sk-...                   # Plain key in config is supported
    api_format: chat_completions       # Requires Chat Completions translation

  openrouter:
    base_url: https://openrouter.ai/api/v1
    api_key: sk-...
    api_format: chat_completions

  openai:
    base_url: https://api.openai.com/v1
    api_key: sk-...                    # Plain key is supported
    # <UPSTREAM_NAME>_API_KEY env var wins over config if set (e.g. OPENAI_API_KEY)
    # No api_format = native Responses API passthrough
```

将 `api_format` 留空或未设置 = 原生直通，不进行翻译。

`role` 默认为 `"cli"`；`role: app` 的工作器会在 `/launch` 选择器中过滤掉。`log_level` 默认为 `"simple"`；

`settings.state_dir` 存储 CAP 运行时状态，例如托管的终端会话。`settings.log_dir` 存储工作器日志。

### API 密钥解析

对于每个名为 `<NAME>` 的上游，首先检查环境变量 `<NAME>_API_KEY` (例如 `JOYCODE_API_KEY`、`OPENAI_API_KEY`、`OPENROUTER_API_KEY`)。如果环境变量已设置且非空，它将覆盖配置文件中的 `api_key`。

## 测试

```bash
# Go 后端
go test ./...

# TUI 界面
cd tui && bun test --timeout 30000

# 类型检查
cd tui && bun run typecheck
```

## 子命令

```bash
./codex-proxy version           # 显示版本
./codex-proxy worker ...        # 工作进程（由管理器自动启动，无需手动运行）
./codex-proxy launch --config-dir <dir> --worker <port> [--profile <name>] [--cd <dir>] [--add-dir <dir>] [--model <model>] [--mode <external-window|hosted-terminal>]
                                # 启动连接到工作进程的 Codex CLI
                                # --mode hosted-terminal 在 CAP 拥有的 tmux 主机内运行 Codex（需要 tmux）
```

## 待办事项

- [ ] `/status`: 在 `/workers` 接管主要工作器管理流程后，重新引入专用的工作器状态视图
- [x] 托管终端 (实验性): `/launch` 可以在 CAP 拥有的 `tmux -L cap` 主机内运行 Codex CLI；CAP 处理 `create` / `switch` / `attach`
- [ ] 嵌入式终端: CAP 内置的 PTY 会话，支持直接会话切换

## 许可证

本项目根据 MIT 许可证授权 — 有关详细信息，请参阅 [LICENSE](../../LICENSE) 文件。

## 归属

本项目是 [anomalyco](https://github.com/anomalyco) 的 [opencode](https://github.com/anomalyco/opencode) 的一个定制化分支，根据 [MIT 许可证](https://github.com/anomalyco/opencode/blob/main/LICENSE) 使用。

原始的 opencode 源代码已被修改，以作为 Codex App 的本地代理管理器。

---

<!-- CO-OP TRANSLATOR DISCLAIMER START -->
**免责声明**：
本文件由 AI 翻译服务 [Co-op Translator](https://github.com/Azure/co-op-translator) 翻译完成。尽管我们力求准确，但请注意，自动翻译可能包含错误或不准确之处。原始语言版文件应视为权威来源。对于重要信息，建议使用专业人工翻译。我们对因使用本翻译而产生的任何误解或误释不承担责任。
<!-- CO-OP TRANSLATOR DISCLAIMER END -->