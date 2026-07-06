# Agent Hook Light

> Turn AI agent hook events into a physical ESP32 status light.

[简体中文](README.zh-CN.md)

[![Platform](https://img.shields.io/badge/platform-Windows-blue)](#2-quick-start)
[![Device](https://img.shields.io/badge/device-ESP32--C3-green)](#3-hardware-and-firmware)
[![LED](https://img.shields.io/badge/led-WS2812B-orange)](#4-status-and-light-effects)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#license)

## 1. Overview And Demo

Agent Hook Light is a local bridge between AI coding agents and a physical ambient light. It listens to agent lifecycle events, normalizes them into a small status protocol, and sends the current state to an ESP32-C3 + WS2812B LED ring.

The current version ships with Codex Hooks as the first supported backend. Codex writes hook events into a local status file, the Go bridge watches that file, and the bridge sends status changes to the ESP32-C3 over USB serial.

This project is not intended to be Codex-only. The long-term goal is a generic agent status light framework for Codex, Claude Code, Gemini CLI, OpenCode, Cursor, Aider, and any tool that can emit hook or lifecycle events.

### Demo Video

```text
Coming soon.
```

Recommended demo scenes:

| Scene | What should happen |
| --- | --- |
| Prompt submitted | Ring switches from `idle` to `thinking` |
| Tool running | Ring enters `working` |
| Permission required | Ring enters `waiting` |
| Task completed | Ring enters `success` |
| Device reconnect | Re-select COM port and resume sync |

### Core Capabilities

| Capability | Status |
| --- | --- |
| Codex Hooks backend | Supported |
| Go bridge executable | Supported |
| USB serial transport | Supported |
| ESP32-C3 firmware | Supported |
| Windows launcher | Supported |
| Arduino firmware flasher | Supported |
| Isolated runtime files under `data/` | Supported |
| Wi-Fi / HTTP transport | Planned |

## 2. Quick Start

### Requirements

| Item | Requirement |
| --- | --- |
| OS | Windows |
| Agent | Codex with hooks support |
| Hardware | ESP32-C3 development board |
| LED | WS2812 / WS2812B LED ring |
| Tested LED count | `24` |
| Tested data pin | `GPIO10` |
| Cable | USB data cable |

### Step 1: Flash Firmware

Run from the project root:

```powershell
.\hardware\arduino\flash-firmware.cmd
```

Recommended firmware:

```text
Status Light V3
```

The firmware flasher will:

- Download project-managed Arduino CLI to `tools\arduino-cli`
- Install ESP32 board support
- Install pinned `FastLED@3.9.4`
- List available firmware sketches
- Ask you to choose the ESP32-C3 COM port
- Compile and upload the selected firmware

### Step 2: Start The Bridge

Run:

```powershell
.\start.cmd
```

The launcher will:

- Check whether Codex hooks are installed
- Offer to install or update missing hooks
- Check whether `bin\ai-hook-bridge.exe` exists
- Build the Go bridge if needed
- List available COM ports
- Ask you to choose the ESP32-C3 port
- Save the selected port to local config
- Start the bridge process

Launcher controls:

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move selection |
| `Space` / `Enter` | Confirm |
| `Esc` | Cancel |
| `Ctrl+C` | Stop the running bridge |

Successful startup looks like:

```text
Starting bridge on COM5...
Press Ctrl+C to stop.

[2026-07-05 18:41:19] serial connected: COM5 @ 115200
[2026-07-05 18:41:20] sent idle -> COM5
```

Keep this window running. If the bridge is stopped, the light will no longer receive new agent states.

### Step 3: Use Codex Normally

After the bridge is running, start a Codex conversation or execute a task. Codex hook events will update:

```text
data\codex-status.json
```

The bridge watches that file and sends normalized states to the ESP32.

## 3. Hardware And Firmware

### Wiring

| ESP32-C3 | WS2812B Ring |
| --- | --- |
| `5V` / `VBUS` | `5V` |
| `GND` | `GND` |
| `GPIO10` | `DIN` |

Default firmware assumptions:

| Setting | Value |
| --- | --- |
| LED chipset | WS2812 / WS2812B |
| LED count | `24` |
| Data pin | `GPIO10` |
| Serial baud | `115200` |

If your ring uses a different LED count or data pin, update the firmware constants before uploading.

### Available Firmware

Firmware directory:

```text
hardware\arduino\firmware
```

| Firmware | Purpose |
| --- | --- |
| `StatusLightV3` | Recommended. Robot-like status light with eyes, blink, scan, waiting cue, and success celebration. |
| `StatusLightV2` | Simplified 24 LED ring version. Clear colors, restrained motion, stronger waiting indicator. |
| `StatusLightShowcase` | Demo firmware. Automatically cycles through all V3 states and animations. |
| `StatusLightBaseV1` | Basic compatibility firmware for the older minimal status protocol. |
| `RainbowLight` | Hardware test firmware for checking LED wiring and color output. |

### Manual Arduino IDE Upload

The included flasher is recommended. If you upload manually with Arduino IDE:

| Option | Value |
| --- | --- |
| Board package | `esp32` by Espressif |
| Board | ESP32-C3 |
| USB CDC On Boot | Enabled |
| Library | `FastLED` |
| Sketch | `hardware\arduino\firmware\StatusLightV3\StatusLightV3.ino` |

The project flasher uses this FQBN:

```text
esp32:esp32:esp32c3:CDCOnBoot=cdc
```

USB CDC must be enabled, otherwise Windows may show a COM port but the firmware may not receive bridge messages correctly.

## 4. Status And Light Effects

### Status Protocol

The bridge sends one normalized state per line:

```text
idle
thinking
working
waiting
success
error
unknown
```

### StatusLightV3 Effects

`StatusLightV3` is the recommended firmware.

| State | Meaning | V3 Light Effect |
| --- | --- | --- |
| `idle` | No active task | Cyan-green idle eyes, occasional blink and left-right scan |
| `thinking` | Prompt submitted, agent is reasoning | Blue eyes with orbiting thinking pixels |
| `working` | Agent is running tools or processing work | Yellow/orange motor chase with busy eyes |
| `waiting` | Waiting for user input or permission | Purple gaze with a white top attention cue |
| `success` | Task completed successfully | Green happy eyes with white-green celebration sweep |
| `error` | Error or attention required | Red narrow-eye jitter with alert flashes |
| `unknown` | State is unclear or unsupported | Blue-purple asymmetric confused eyes |

### State Aliases

| Input State | Normalized State |
| --- | --- |
| `submitted` | `thinking` |
| `tool_running` | `working` |
| `waiting_user` | `waiting` |
| `waiting_permission` | `waiting` |
| `done` | `success` |
| `complete` | `success` |
| `failed` | `error` |
| `failure` | `error` |
| `attention` | `error` |

### Codex Hook Mapping

| Codex Hook Event | Bridge State | Meaning |
| --- | --- | --- |
| `UserPromptSubmit` | `thinking` | Prompt submitted, agent begins reasoning |
| `PreToolUse` | `working` | Tool execution is starting |
| `PostToolUse` | `thinking` | Tool returned, agent continues reasoning |
| `PermissionRequest` | `waiting` | User approval is required |
| `Stop` | `success` | Turn completed |
| `SubagentStop` | `thinking` | Subagent completed, main agent continues |
| Parse error | `error` | Hook input could not be parsed |
| Unknown event | `unknown` | Event is unsupported or unclear |

### StatusLightV2 Effects

`StatusLightV2` uses the same protocol with a simpler 24 LED ring style.

Default brightness: `72/255`.

| State | Color | V2 Light Effect |
| --- | --- | --- |
| `idle` | Green `RGB(0, 220, 90)` | Bright full ring with short scan |
| `thinking` | Blue `RGB(30, 110, 255)` | Dim full ring with four low-brightness running pixels |
| `working` | Yellow-orange `RGB(255, 140, 0)` | Dim full ring with two symmetric moving pixels |
| `waiting` | Low amber `RGB(140, 78, 0)` / dark amber `RGB(18, 8, 0)` | Even/odd alternating flash for confirmation required |
| `success` | Green `RGB(0, 255, 0)` | Dim full ring with one slow scanning pixel |
| `error` | Red `RGB(255, 0, 0)` | Three red alert flashes |
| `unknown` | Cool gray `RGB(80, 90, 100)` | Very dim full-ring slow breathing for disconnected state |

### Showcase Mode

To preview all effects without running the bridge, flash:

```text
Status Light Showcase
```

It cycles automatically:

```text
idle -> thinking -> working -> waiting -> success -> error -> unknown
```

Each state is displayed for about 3.5 seconds.

## Architecture

```text
Agent Hook Event
    |
    v
Backend Adapter
    |
    v
Normalized Status File
    |
    v
Go Bridge
    |
    v
Transport: Serial today, Wi-Fi / HTTP later
    |
    v
ESP32-C3 Firmware
    |
    v
WS2812B LED Ring
```

Current Codex flow:

```text
Codex Hooks
    |
    v
bin/codex-hook.cmd
    |
    v
bin/ai-hook-bridge.exe hook
    |
    v
data/codex-status.json
    |
    v
bin/ai-hook-bridge.exe bridge
    |
    v
COM port, for example COM4
    |
    v
ESP32-C3 + WS2812B
```

## Supported Agents

Agent Hook Light uses a backend adapter model. Each backend only needs to map its own hook or lifecycle format into the shared status protocol.

| Agent / Tool | Support Level | Adapter Type | Notes |
| --- | --- | --- | --- |
| Codex | Supported | Codex Hooks | First implemented backend. Writes `data\codex-status.json` and drives the bridge today. |
| Claude Code | Planned | Hook / lifecycle event adapter | Target backend for Claude Code style hook workflows. |
| Gemini CLI | Planned | Local event / command lifecycle adapter | Depends on available hook or lifecycle signals. |
| OpenCode | Planned | Hook adapter | Intended for OpenCode-style agent sessions. |
| Cursor | Researching | Local workflow/status adapter | Requires a reliable local event source. |
| Aider | Researching | Terminal session adapter | Could map command/session state into the shared protocol. |
| Custom Agent | Planned | File / stdout / webhook adapter | Any tool that can emit normalized states can integrate. |

## Control Modes

| Mode | Status | Description |
| --- | --- | --- |
| Go Hook Adapter | Supported | `ai-hook-bridge.exe hook` parses Codex hook input and writes normalized status. |
| File Watch Bridge | Supported | `ai-hook-bridge.exe bridge` watches the local status file and sends changes to the device. |
| USB Serial Control | Supported | Sends status text to ESP32 over a COM port such as `COM4`. |
| ESP32-C3 LED Ring | Supported | Tested with ESP32-C3 and a 24 LED WS2812B ring on GPIO10. |
| Log Rotation | Supported | Rotates Codex hook JSONL logs to avoid unbounded runtime log growth. |
| One-Click Launcher | Supported | `start.cmd` checks setup, builds if needed, selects COM port, and starts the bridge. |
| One-Click Firmware Flashing | Supported | `hardware\arduino\flash-firmware.cmd` manages Arduino CLI, libraries, build, and upload. |
| Wi-Fi HTTP Control | Planned | Send status to ESP32 over LAN instead of USB serial. |
| Tray App / Background Service | Planned | Run the bridge quietly without keeping a console window open. |
| Configurable Mapping | Planned | Customize states, colors, ports, URLs, and effect profiles. |

## Configuration

The launcher stores local runtime configuration under:

```text
data\agent-hook-light.config.json
```

Runtime status and hook logs are written under `data/` and ignored by Git.

Important runtime files:

| File | Purpose |
| --- | --- |
| `data\codex-status.json` | Latest normalized Codex status |
| `data\codex-hook-log.jsonl` | JSONL hook event log |
| `data\codex-hook-wrapper.log` | Windows wrapper start/exit log |
| `data\agent-hook-light.config.json` | Local launcher configuration |

## Manual Testing

List serial ports:

```powershell
.\bin\ai-hook-bridge.exe bridge -list-ports
```

Dry-run the bridge:

```powershell
.\bin\ai-hook-bridge.exe bridge -dry-run -once
```

Trigger the hook manually:

```powershell
'{"hook_event_name":"UserPromptSubmit","session_id":"manual-test"}' | .\bin\ai-hook-bridge.exe hook
```

Then start the launcher:

```powershell
.\start.cmd
```

## Troubleshooting

### No COM Port Found

Check that the USB cable supports data transfer. Replug the ESP32-C3 and rerun `start.cmd` or `flash-firmware.cmd`.

### Multiple COM Ports

Unplug the ESP32-C3 and check the list once. Plug it back in and select the newly added COM port.

### Serial Write Timeout

Common causes:

- Firmware was uploaded without USB CDC enabled
- A demo firmware that does not read serial is currently flashed
- Another process is holding the COM port

Recommended fix:

```powershell
.\hardware\arduino\flash-firmware.cmd
```

Select:

```text
Status Light V3
```

### LED Ring Does Not Light Up

Check:

- Firmware is `StatusLightV3`
- LED DIN is connected to GPIO10
- 5V and GND are connected correctly
- LED count is 24
- Correct COM port was selected

### Hook Logs Update When Opening Old Codex Threads

Codex hooks are global. Opening or restoring a historical Codex thread can trigger lifecycle events even if you did not start a new task.

Recommended filtering strategy:

- Keep full hook logs for debugging
- Only let filtered events update the light status
- Ignore Codex app internal `cwd` values
- Debounce repeated events
- Prefer `PreToolUse`, `PermissionRequest`, and `Stop` as strong light-driving events

## Project Structure

```text
start.cmd                         New-user launcher
bin/
  agent-hook-light.ps1             Launcher logic
  codex-hook.cmd                   Codex hook command wrapper
  ai-hook-bridge.exe               Go bridge executable
  install.ps1                      Codex hook install/check script
bridge/
  main.go                          CLI entrypoint
  hook.go                          Codex hook parser and status writer
  bridge.go                        Status-file watcher and serial sender
  log.go                           Rotating hook JSONL log writer
  types.go                         Shared status and config structs
  util.go                          Project root, env, time, and console helpers
hardware/
  arduino/
    flash-firmware.cmd             Firmware flashing entrypoint
    flash-firmware.ps1             Firmware flashing logic
    firmware/
      StatusLightV3/
      StatusLightV2/
      StatusLightShowcase/
      StatusLightBaseV1/
      RainbowLight/
test/
  install.test.ps1
  launcher.test.ps1
  firmware-flasher.test.ps1
```

## Development

Run tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\launcher.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\firmware-flasher.test.ps1
cd bridge
go test ./...
```

Rebuild after changing Go code:

```powershell
cd bridge
go build -o ..\bin\ai-hook-bridge.exe .
```

## Roadmap

- Add demo video and screenshots
- Add release packages with prebuilt binaries
- Add Wi-Fi HTTP device mode
- Add configurable status-to-effect mapping
- Add Windows tray app or background service
- Add automatic COM port detection with device identity checks
- Add richer effects for long-running work, approval requests, and completion
- Add adapters for more hook-capable AI agent tools

## Contributing

Useful contribution areas:

- New agent backends
- New firmware effects
- Better Windows launcher UX
- Wi-Fi / HTTP device transport
- Documentation, diagrams, and demo videos

## License

MIT
