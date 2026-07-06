# Agent Hook Light

> 面向 AI 编程 Agent 的实体状态灯。

[English](README.md)

Agent Hook Light 将 AI Agent 的 hook 事件转成桌面可见的状态颜色。当前通过 Codex Hooks 支持 Codex，后续其它支持 hook 的 Agent 可以复用同一套状态协议接入。

## 演示

```text
Coming soon.
```

## 快速开始

需要准备：

- Windows
- 支持 hooks 的 Codex
- ESP32-C3
- WS2812 / WS2812B 灯环
- USB 数据线

烧录设备：

```powershell
.\hardware\arduino\flash-firmware.cmd
```

启动桥接程序：

```powershell
.\start.cmd
```

然后正常使用 Codex，灯光会跟随 Agent 状态变化。

硬件和固件细节放在 [hardware/arduino/README.md](hardware/arduino/README.md)。

## 状态颜色

| 状态 | 颜色 | 含义 |
| --- | --- | --- |
| `idle` | 绿色 / 灰色 | 当前没有任务 |
| `thinking` | 蓝色 | Agent 正在思考 |
| `working` | 黄色 / 橙色 | Agent 正在执行工具 |
| `waiting` | 紫色 | 等待用户输入或授权 |
| `success` | 绿色 | 任务完成 |
| `error` | 红色 | 出错或需要注意 |
| `unknown` | 蓝色 / 灰色 | 状态不明确或暂不支持 |

## Agent 支持

| Agent | 状态 |
| --- | --- |
| Codex | 已支持 |
| Claude Code | 计划支持 |
| Gemini CLI | 计划支持 |
| OpenCode | 计划支持 |
| Cursor | 调研中 |
| Aider | 调研中 |
| 自定义 Agent | 计划支持 |

## 开发

运行测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\launcher.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\firmware-flasher.test.ps1
cd bridge
go test ./...
```

构建 bridge：

```powershell
cd bridge
go build -o ..\bin\ai-hook-bridge.exe .
```

## 许可证

MIT
