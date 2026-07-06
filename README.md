# Agent Hook Light

> Physical status light for AI coding agents.

[简体中文](README.zh-CN.md)

Agent Hook Light turns AI agent hook events into visible desk status colors. Codex is supported today through Codex Hooks. Other hook-capable agents can be added through the same status protocol.

## Demo

```text
Coming soon.
```

## Quick Start

Requirements:

- Windows
- Codex with hooks support
- ESP32-C3
- WS2812 / WS2812B LED ring
- USB data cable

Flash the device:

```powershell
.\hardware\arduino\flash-firmware.cmd
```

Start the bridge:

```powershell
.\start.cmd
```

Then use Codex normally. The light follows agent status changes.

Hardware and firmware details are in [hardware/arduino/README.md](hardware/arduino/README.md).

## Status Colors

| State | Color | Meaning |
| --- | --- | --- |
| `idle` | Green / gray | No active task |
| `thinking` | Blue | Agent is reasoning |
| `working` | Yellow / orange | Agent is running tools |
| `waiting` | Purple | Waiting for user input or permission |
| `success` | Green | Task completed |
| `error` | Red | Error or attention required |
| `unknown` | Blue / gray | Unsupported or unclear state |

## Agent Support

| Agent | Status |
| --- | --- |
| Codex | Supported |
| Claude Code | Planned |
| Gemini CLI | Planned |
| OpenCode | Planned |
| Cursor | Researching |
| Aider | Researching |
| Custom agent | Planned |

## Development

Run tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\launcher.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\firmware-flasher.test.ps1
cd bridge
go test ./...
```

Build the bridge:

```powershell
cd bridge
go build -o ..\bin\ai-hook-bridge.exe .
```

## License

MIT
