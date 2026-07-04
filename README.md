# Agent Status Light

**Agent Status Light** turns AI coding agent activity into a physical ambient signal.

It connects agent hooks, a local Go bridge, and an ESP32-C3 + WS2812 LED ring so your AI coding workflow is no longer only text on a screen. Idle, working, waiting for approval, and unknown states can be reflected as light, color, and eventually richer device behaviors.

**Agent Status Light** 是一个把 AI 编程 Agent 状态转成实体灯光反馈的开源项目。

它通过 Agent Hooks 捕获会话事件，由本地 Go 桥接程序转发到 ESP32-C3 + WS2812 灯环，让 AI 编程状态从屏幕里的文本变成桌面上的环境信号。空闲、工作中、需要注意、未知状态，都可以被映射成颜色、灯效或后续更复杂的硬件行为。

Codex is the first supported backend. The project is designed to grow into a generic status output layer for hook-capable AI agent tools.

Codex 是当前第一个支持的后端。项目目标是逐步扩展成一个通用的 Agent 状态输出层，适配更多支持 hooks、events 或本地状态输出的 AI 工具。

## Why

AI coding agents are becoming long-running collaborators. They think, run tools, wait for approval, finish, fail, and recover. A physical status indicator makes those state changes visible without constantly watching the terminal or app window.

This project is designed as a small but extensible bridge between:

- AI agent events
- local status files
- serial / network device control
- microcontroller-driven ambient hardware

目标不是只做一个“会亮的灯”，而是做一个可扩展的 **AI Agent 状态输出层**。

## Current Architecture

Generic model:

```text
Agent Hooks / Events
    ↓
Backend Adapter
    ↓
Normalized Status File
    ↓
Go Bridge
    ↓
Serial / future transports
    ↓
ESP32-C3 + WS2812 LED Ring
```

Current Codex backend:

```text
Codex Hooks
    ↓
bin/codex-hook.cmd
    ↓
bin/ai-hook-bridge.exe hook
    ↓
data/codex-status.json
    ↓
bin/ai-hook-bridge.exe bridge
    ↓
COM4 / USB Serial
    ↓
ESP32-C3 + WS2812 LED Ring
```

## Supported Agents

Agent Status Light uses a backend adapter model. Each agent backend only needs to normalize its own hook/event format into the shared status protocol:

```text
idle
working
attention
unknown
```

### Supported Now

| Agent / Tool | Status | Notes |
| --- | --- | --- |
| Codex | Supported | First backend. Uses Codex Hooks and writes `data/codex-status.json`. |

### Planned Agent Backends

| Agent / Tool | Planned Integration |
| --- | --- |
| Claude Code | Hook/event adapter for Claude Code style workflows. |
| Gemini CLI | Local event/status adapter when hook or command lifecycle signals are available. |
| OpenCode | Hook adapter for OpenCode-style agent sessions. |
| Cursor | Local workflow/status adapter if a reliable event source is available. |
| Aider | Command/session status adapter for terminal-based coding workflows. |
| Custom Agent | Generic file/stdout/webhook adapter for tools that can emit status events. |

The long-term goal is not to be tied to one agent runtime. Codex is simply the first implemented backend.

## Control Modes

### Supported Now

| Mode | Status | Description |
| --- | --- | --- |
| Go Hook Adapter | Supported | `ai-hook-bridge.exe hook` parses Codex hook input and writes normalized status. |
| File Watch Bridge | Supported | `ai-hook-bridge.exe bridge` watches the local status file and sends changes to the device. |
| USB Serial Control | Supported | Sends status text to ESP32 over a COM port such as `COM4`. |
| ESP32-C3 LED Ring | Supported | Tested with ESP32-C3 and a 24 LED WS2812B ring on GPIO10. |
| Log Rotation | Supported | Rotates Codex hook JSONL logs to avoid unbounded runtime log growth. |
| Install / Uninstall Scripts | Supported | Installs, checks, uninstalls hooks, and can purge local runtime data. |

### Planned / Experimental Direction

| Mode | Goal |
| --- | --- |
| Wi-Fi HTTP Control | Send status to ESP32 over LAN instead of USB serial. |
| Auto Device Discovery | Detect available ESP32 status devices automatically. |
| Multi-Agent Status | Represent multiple agent sessions or tools at the same time. |
| Rich LED Effects | Breathing, spinning, pulsing, error flash, approval alert, completion animation. |
| Tray App / Background Service | Run the bridge quietly without keeping a console window open. |
| Configurable Mapping | Let users customize states, colors, ports, URLs, and effect profiles. |
| Multi-Backend Support | Extend beyond Codex Hooks to Claude Code, Gemini CLI, OpenCode, Cursor-style workflows, or any tool that can emit hooks/events. |

## Status Protocol

The bridge sends one normalized state per line:

```text
idle
working
attention
unknown
```

Default LED mapping:

| State | Meaning | Default Color |
| --- | --- | --- |
| `idle` | Agent is stopped or waiting | Green |
| `working` | Agent is processing, running tools, or handling a prompt | Yellow |
| `attention` | User approval or attention is required | Red |
| `unknown` | No reliable state is available | Blue |

## Hardware

Reference hardware used during development:

- ESP32-C3 board
- WS2812 / WS2812B LED ring
- 24 LEDs
- Data pin: GPIO10
- USB serial connection on Windows

For ESP32-C3 USB serial, enable **USB CDC On Boot** when uploading the Arduino sketch.

## Quick Start

Install or update the Codex hook:

```powershell
.\install.cmd
```

Check the setup:

```powershell
.\check.cmd
```

Start the serial bridge:

```powershell
.\bin\start-bridge.cmd -port COM4
```

Build the Go executable after changing `bridge/*.go`:

```powershell
.\bin\build-bridge.cmd
```

Uninstall hooks only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bin\install.ps1 -Uninstall
```

Uninstall hooks, stop the local bridge process, and remove runtime status/log files:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bin\install.ps1 -Uninstall -StopBridge -PurgeData
```

Run the hook path manually:

```powershell
'{"hook_event_name":"UserPromptSubmit","session_id":"manual-test"}' | .\bin\ai-hook-bridge.exe hook
```

## Log Rotation

Hook logs are written to `data/codex-hook-log.jsonl`. The Go hook rotates this log by default:

- Maximum active log size: `10MB`
- Rotated files kept: `5`
- Rotated file names: `codex-hook-log.jsonl.1`, `codex-hook-log.jsonl.2`, ...

Optional environment variables:

| Variable | Description |
| --- | --- |
| `AI_HOOK_LOG_MAX_BYTES` | Maximum active log size before rotation. |
| `AI_HOOK_LOG_BACKUPS` | Number of rotated log files to keep. |
| `AI_HOOK_DISABLE_LOG=1` | Disable hook JSONL logging. |
| `CODEX_HOOK_LOG_RAW=1` | Debug only. Include the raw hook event in logs. This may contain sensitive content. |

## Project Structure

```text
bin/
  codex-hook.cmd       Codex hook command wrapper
  ai-hook-bridge.exe   Built Go executable
  build-bridge.cmd     Build the Go executable
  start-bridge.cmd     Start the serial bridge
  install.ps1          Hook installer/checker
bridge/
  main.go              CLI entrypoint and mode dispatch
  bridge.go            Status-file watcher and serial bridge
  hook.go              Codex hook event parser and status writer
  log.go               Rotating hook JSONL log writer
  types.go             Shared status and config structs
  util.go              Project root, env, time, and console helpers
  main_test.go         Go tests
data/
  .gitkeep             Runtime data directory placeholder
test/
  install.test.ps1
install.cmd            Interactive installer
check.cmd              Setup checker
```

Runtime status and logs are written under `data/` and ignored by Git.

## Development

Run tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
cd bridge
go test ./...
```

## Design Notes

- The hook layer stays lightweight and only records normalized state.
- The Go bridge is responsible for transport and device output.
- The device firmware should avoid blocking serial writes back to the host unless the host explicitly reads responses.
- Serial bridge mode is intentionally simple and reliable before adding Wi-Fi or discovery.
- Codex support is implemented first; other agent backends should adapt their events into the same normalized state protocol.

## Roadmap

- [ ] Add bundled ESP32 Arduino firmware examples.
- [ ] Add Wi-Fi HTTP device mode.
- [ ] Add configurable status-to-effect mapping.
- [ ] Add Windows background service or tray launcher.
- [ ] Add automatic COM port detection with device identity checks.
- [ ] Add richer visual effects for long-running work, approval requests, and completion.
- [ ] Add adapters for more hook-capable AI agent tools.

## License

MIT
