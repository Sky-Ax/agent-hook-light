# Agent Hook Light

> 将 AI 编程 Agent 的 hook / lifecycle 事件转成桌面实体状态灯。

[English](README.md)

[![Platform](https://img.shields.io/badge/platform-Windows-blue)](#2-快速开始)
[![Device](https://img.shields.io/badge/device-ESP32--C3-green)](#3-硬件与固件)
[![LED](https://img.shields.io/badge/led-WS2812B-orange)](#4-状态与灯效)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#许可证)

## 1. 简介与演示

Agent Hook Light 是一个连接 AI 编程 Agent 与实体氛围灯的本地桥接项目。它监听 Agent 的生命周期事件，将不同工具的事件统一成一套简单状态协议，再通过 ESP32-C3 + WS2812B 灯环展示当前状态。

当前版本以 Codex Hooks 作为第一个已实现后端：Codex hook 写入本地状态文件，Go bridge 监听状态变化，并通过 USB 串口把状态发送给 ESP32-C3。

这个项目不是只服务 Codex。长期目标是做成通用的 Agent 状态灯框架，后续可以扩展到 Claude Code、Gemini CLI、OpenCode、Cursor、Aider，以及任何能输出 hook 或 lifecycle event 的工具。

### 演示视频

```text
Coming soon.
```

建议演示视频覆盖：

| 场景 | 预期表现 |
| --- | --- |
| 提交任务 | 灯环从 `idle` 切换到 `thinking` |
| 工具执行 | 灯环进入 `working` |
| 等待授权 | 灯环进入 `waiting` |
| 任务完成 | 灯环进入 `success` |
| 设备重连 | 重新选择 COM 口并恢复同步 |

### 核心能力

| 能力 | 状态 |
| --- | --- |
| Codex Hooks 后端 | 已支持 |
| Go bridge 单文件可执行程序 | 已支持 |
| USB 串口传输 | 已支持 |
| ESP32-C3 固件 | 已支持 |
| Windows 一键启动器 | 已支持 |
| Arduino 一键烧录脚本 | 已支持 |
| 运行文件隔离到 `data/` | 已支持 |
| Wi-Fi / HTTP 传输 | 计划支持 |

## 2. 快速开始

### 环境要求

| 项目 | 要求 |
| --- | --- |
| 操作系统 | Windows |
| Agent | 支持 hooks 的 Codex |
| 硬件 | ESP32-C3 开发板 |
| 灯环 | WS2812 / WS2812B LED ring |
| 已测试灯珠数量 | `24` |
| 已测试数据引脚 | `GPIO10` |
| USB 线 | 需要支持数据传输 |

### 第一步：烧录固件

在项目根目录运行：

```powershell
.\hardware\arduino\flash-firmware.cmd
```

推荐固件：

```text
Status Light V3
```

烧录脚本会自动完成：

- 下载项目内置 Arduino CLI 到 `tools\arduino-cli`
- 安装 ESP32 开发板支持
- 安装固定版本 `FastLED@3.9.4`
- 列出可用固件
- 选择 ESP32-C3 对应 COM 口
- 编译并上传固件

### 第二步：启动桥接程序

运行：

```powershell
.\start.cmd
```

启动器会自动完成：

- 检查 Codex hooks 是否已安装
- 缺失时提示安装或更新 hooks
- 检查 `bin\ai-hook-bridge.exe` 是否存在
- 缺失时自动构建 Go bridge
- 列出可用 COM 口
- 选择 ESP32-C3 对应串口
- 保存所选串口到本地配置
- 启动 bridge 进程

启动器按键：

| 按键 | 操作 |
| --- | --- |
| `Up` / `Down` | 移动选项 |
| `Space` / `Enter` | 确认 |
| `Esc` | 取消 |
| `Ctrl+C` | 停止 bridge |

启动成功示例：

```text
Starting bridge on COM5...
Press Ctrl+C to stop.

[2026-07-05 18:41:19] serial connected: COM5 @ 115200
[2026-07-05 18:41:20] sent idle -> COM5
```

保持这个窗口运行。如果 bridge 停止，灯环就不会继续接收新的 Agent 状态。

### 第三步：正常使用 Codex

bridge 运行后，正常发起 Codex 对话或任务即可。Codex hook 会更新：

```text
data\codex-status.json
```

bridge 会监听该文件，并把统一后的状态发送给 ESP32。

## 3. 硬件与固件

### 接线

| ESP32-C3 | WS2812B 灯环 |
| --- | --- |
| `5V` / `VBUS` | `5V` |
| `GND` | `GND` |
| `GPIO10` | `DIN` |

默认固件参数：

| 参数 | 值 |
| --- | --- |
| 灯珠类型 | WS2812 / WS2812B |
| 灯珠数量 | `24` |
| 数据引脚 | `GPIO10` |
| 串口波特率 | `115200` |

如果你的灯环数量或数据引脚不同，需要先修改固件中的常量再烧录。

### 可用固件

固件目录：

```text
hardware\arduino\firmware
```

| 固件 | 用途 |
| --- | --- |
| `StatusLightV3` | 推荐固件。带眼睛、眨眼、扫描、等待提示和完成庆祝效果。 |
| `StatusLightV2` | 简化版 24 灯环固件。颜色清晰、动画克制，等待状态更明显。 |
| `StatusLightShowcase` | 演示固件。自动循环展示 V3 所有状态和动画。 |
| `StatusLightBaseV1` | 基础兼容固件，适合旧版最小状态协议。 |
| `RainbowLight` | 硬件测试固件，用于检查接线和灯珠颜色输出。 |

### 使用 Arduino IDE 手动上传

推荐使用项目自带烧录脚本。如果要用 Arduino IDE 手动上传：

| 选项 | 值 |
| --- | --- |
| 开发板包 | Espressif 官方 `esp32` |
| 开发板 | ESP32-C3 |
| USB CDC On Boot | Enabled |
| 依赖库 | `FastLED` |
| Sketch | `hardware\arduino\firmware\StatusLightV3\StatusLightV3.ino` |

项目烧录脚本使用：

```text
esp32:esp32:esp32c3:CDCOnBoot=cdc
```

必须启用 USB CDC，否则 Windows 可能能看到 COM 口，但固件无法正确接收 bridge 发来的状态。

## 4. 状态与灯效

### 状态协议

bridge 每次通过串口发送一行标准状态：

```text
idle
thinking
working
waiting
success
error
unknown
```

### StatusLightV3 灯效

`StatusLightV3` 是推荐固件。

| 状态 | 含义 | V3 灯效 |
| --- | --- | --- |
| `idle` | 当前没有任务 | 青绿色待机眼睛，偶尔眨眼和左右扫描 |
| `thinking` | 已提交提示词，Agent 正在思考 | 蓝色眼睛，带环绕思考光点 |
| `working` | Agent 正在执行工具或处理任务 | 黄橙色运转追逐灯效，表现忙碌状态 |
| `waiting` | 等待用户输入或授权 | 紫色注视，顶部白色提示灯 |
| `success` | 任务成功完成 | 绿色开心眼睛，白绿庆祝扫光 |
| `error` | 出错或需要注意 | 红色警戒窄眼，伴随闪烁提醒 |
| `unknown` | 状态不明确或暂不支持 | 蓝紫色不对称疑惑眼睛 |

### 状态别名

| 输入状态 | 统一状态 |
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

### Codex Hook 映射

| Codex Hook 事件 | Bridge 状态 | 含义 |
| --- | --- | --- |
| `UserPromptSubmit` | `thinking` | 用户提交提示词，Agent 开始思考 |
| `PreToolUse` | `working` | 工具即将执行 |
| `PostToolUse` | `thinking` | 工具返回，Agent 继续思考 |
| `PermissionRequest` | `waiting` | 需要用户授权 |
| `Stop` | `success` | 本轮任务完成 |
| `SubagentStop` | `thinking` | 子 Agent 完成，主 Agent 继续 |
| 解析错误 | `error` | hook 输入解析失败 |
| 未知事件 | `unknown` | 事件暂不支持或含义不明确 |

### StatusLightV2 灯效

`StatusLightV2` 使用相同状态协议，但灯效更简洁，适合普通 24 灯珠灯环。

默认亮度：`72/255`。

| 状态 | 颜色 | V2 灯效 |
| --- | --- | --- |
| `idle` | 绿色 `RGB(0, 220, 90)` | 绿色全环，带短扫描效果 |
| `thinking` | 蓝色 `RGB(30, 110, 255)` | 蓝色低亮全环，四个低亮运行光点 |
| `working` | 黄橙色 `RGB(255, 140, 0)` | 黄橙色低亮全环，两个对称移动光点 |
| `waiting` | 琥珀色 `RGB(140, 78, 0)` + 暗琥珀色 `RGB(18, 8, 0)` | 奇偶灯珠交替闪烁，用于提示需要确认 |
| `success` | 绿色 `RGB(0, 255, 0)` | 绿色低亮全环，一个慢速扫描点 |
| `error` | 红色 `RGB(255, 0, 0)` | 红色三次警告闪烁 |
| `unknown` | 冷灰色 `RGB(80, 90, 100)` | 极低亮度全环慢呼吸，表示断开或未知状态 |

### 演示模式

如果想不启动 bridge 就预览全部灯效，可以烧录：

```text
Status Light Showcase
```

它会自动循环：

```text
idle -> thinking -> working -> waiting -> success -> error -> unknown
```

每个状态展示约 3.5 秒。

## 架构

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

当前 Codex 流程：

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

## 支持的 Agent

Agent Hook Light 使用后端适配器模型。每个 Agent 后端只需要把自己的 hook 或 lifecycle event 映射到统一状态协议。

| Agent / Tool | 支持状态 | 适配方式 | 说明 |
| --- | --- | --- | --- |
| Codex | 已支持 | Codex Hooks | 当前第一个实现后端，写入 `data\codex-status.json` 并驱动 bridge。 |
| Claude Code | 计划支持 | Hook / lifecycle event adapter | 适配 Claude Code 风格 hook 工作流。 |
| Gemini CLI | 计划支持 | Local event / command lifecycle adapter | 取决于可用 hook 或生命周期信号。 |
| OpenCode | 计划支持 | Hook adapter | 面向 OpenCode 类 Agent 会话。 |
| Cursor | 调研中 | Local workflow/status adapter | 需要可靠本地状态来源。 |
| Aider | 调研中 | Terminal session adapter | 可考虑从终端会话状态映射。 |
| Custom Agent | 计划支持 | File / stdout / webhook adapter | 能输出标准状态即可接入。 |

## 控制模式

| 模式 | 状态 | 说明 |
| --- | --- | --- |
| Go Hook Adapter | 已支持 | `ai-hook-bridge.exe hook` 解析 Codex hook 并写入统一状态。 |
| File Watch Bridge | 已支持 | `ai-hook-bridge.exe bridge` 监听本地状态文件并推送到设备。 |
| USB Serial Control | 已支持 | 通过 `COM4` 这类串口向 ESP32 发送状态文本。 |
| ESP32-C3 LED Ring | 已支持 | 已测试 ESP32-C3 + 24 颗 WS2812B + GPIO10。 |
| Log Rotation | 已支持 | 支持 hook 日志轮转，避免日志无限增长。 |
| One-Click Launcher | 已支持 | `start.cmd` 一键检查、构建、选串口并启动 bridge。 |
| One-Click Firmware Flashing | 已支持 | `flash-firmware.cmd` 一键处理 Arduino CLI、依赖、编译和上传。 |
| Wi-Fi HTTP Control | 计划支持 | 通过局域网控制 ESP32。 |
| Tray App / Background Service | 计划支持 | 托盘或后台服务运行。 |
| Configurable Mapping | 计划支持 | 自定义状态、颜色、端口、URL 和灯效配置。 |

## 配置

启动器将本地运行配置保存到：

```text
data\agent-hook-light.config.json
```

运行状态和 hook 日志都会写入 `data/`，并被 Git 忽略。

关键运行文件：

| 文件 | 用途 |
| --- | --- |
| `data\codex-status.json` | 最新 Codex 统一状态 |
| `data\codex-hook-log.jsonl` | Codex hook 事件日志 |
| `data\codex-hook-wrapper.log` | Windows hook wrapper 启停日志 |
| `data\agent-hook-light.config.json` | 启动器本地配置 |

## 手动测试

列出串口：

```powershell
.\bin\ai-hook-bridge.exe bridge -list-ports
```

空跑 bridge，不打开串口：

```powershell
.\bin\ai-hook-bridge.exe bridge -dry-run -once
```

手动触发 hook：

```powershell
'{"hook_event_name":"UserPromptSubmit","session_id":"manual-test"}' | .\bin\ai-hook-bridge.exe hook
```

然后启动：

```powershell
.\start.cmd
```

## 常见问题

### 找不到 COM 口

确认 USB 线支持数据传输。重新插拔 ESP32-C3 后，再运行 `start.cmd` 或 `flash-firmware.cmd`。

### 出现多个 COM 口

先拔掉 ESP32-C3 看一次列表，再插回去，选择新增的 COM 口。

### 串口写入超时

常见原因：

- 固件上传时没有启用 USB CDC
- 当前烧录的是不读取串口的演示固件
- 其它程序占用了 COM 口

推荐修复：

```powershell
.\hardware\arduino\flash-firmware.cmd
```

选择：

```text
Status Light V3
```

### 灯环不亮

检查：

- 固件是否为 `StatusLightV3`
- LED 的 DIN 是否接到 GPIO10
- 5V 和 GND 是否正确连接
- 灯珠数量是否为 24
- 是否选择了正确 COM 口

### 打开历史 Codex 对话也会写日志

Codex hooks 是全局生效的。打开或恢复历史 Codex 会话时，即使你没有发起新任务，也可能触发生命周期事件。

推荐过滤策略：

- 完整保留 hook 日志用于排查问题
- 只有通过过滤的事件才允许更新灯光状态
- 忽略 Codex App 内部 `cwd`
- 对重复事件做 debounce
- 优先使用 `PreToolUse`、`PermissionRequest`、`Stop` 这类强状态事件驱动灯光

## 项目结构

```text
start.cmd                         新用户启动入口
bin/
  agent-hook-light.ps1             启动器逻辑
  codex-hook.cmd                   Codex hook 命令包装器
  ai-hook-bridge.exe               Go bridge 可执行文件
  install.ps1                      Codex hook 安装与检查脚本
bridge/
  main.go                          CLI 入口
  hook.go                          Codex hook 解析与状态写入
  bridge.go                        状态文件监听与串口发送
  log.go                           hook JSONL 日志轮转
  types.go                         共享状态与配置结构
  util.go                          工具函数
hardware/
  arduino/
    flash-firmware.cmd             固件烧录入口
    flash-firmware.ps1             固件烧录逻辑
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

## 开发

运行测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\launcher.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\firmware-flasher.test.ps1
cd bridge
go test ./...
```

修改 Go 代码后重新构建：

```powershell
cd bridge
go build -o ..\bin\ai-hook-bridge.exe .
```

## 路线图

- 添加演示视频和截图
- 发布包含预编译二进制的 release 包
- 增加 Wi-Fi HTTP 设备控制模式
- 增加状态到灯效的可配置映射
- 增加 Windows 托盘或后台服务
- 增加基于设备身份的自动串口识别
- 为长任务、授权等待和完成状态增加更丰富灯效
- 增加更多 Agent 工具适配器

## 贡献

适合贡献的方向：

- 新 Agent 后端
- 新固件灯效
- 更好的 Windows 启动体验
- Wi-Fi / HTTP 设备传输
- 文档、架构图和演示视频

## 许可证

MIT
