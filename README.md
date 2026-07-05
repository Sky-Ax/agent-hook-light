# Agent Hook Light

Agent Hook Light 把 AI 编程 Agent 的 hook 状态变成桌面上的实体灯光信号。

当前支持 Codex：Codex hook 会写入本地状态文件，Go bridge 监听状态变化，并通过 USB 串口把状态发送给 ESP32-C3 + WS2812B 灯环。

## 你需要准备

- Windows
- ESP32-C3 开发板
- WS2812 / WS2812B 灯环
- 灯珠数量：24
- 数据引脚：GPIO10
- USB 数据线

## 快速使用

第一次使用建议按这个顺序：

1. 给 ESP32-C3 刷入灯环固件。
2. 双击根目录的 `start.cmd` 启动项目。
3. 在 Codex 里正常对话，灯环会跟随 hook 状态变化。

## 刷固件

双击或运行：

```powershell
.\hardware\arduino\flash-firmware.cmd
```

刷固件脚本会自动做这些事：

- 检查并下载本项目自带的 Arduino CLI 到 `tools\arduino-cli`
- 安装 ESP32 board support
- 安装固定版本 `FastLED@3.9.4`
- 列出可刷入的固件
- 让你选择 ESP32-C3 的 COM 口
- 编译并上传固件

正常使用请选择：

```text
Status Light V2
```

固件目录在：

```text
hardware\arduino\firmware
```

可选固件：

| 固件 | 用途 |
| --- | --- |
| `StatusLightV2` | 推荐使用。支持更丰富的状态和动画灯效。 |
| `StatusLightBaseV1` | 基础兼容固件，只支持旧版简单状态。 |
| `RainbowLight` | 彩虹测试固件，用来确认灯环硬件正常。 |

ESP32-C3 需要启用 USB CDC 串口。项目自带刷机脚本已经使用：

```text
esp32:esp32:esp32c3:CDCOnBoot=cdc
```

如果你不用脚本、改用 Arduino IDE 手动刷入，请把 **USB CDC On Boot** 设置为 `Enabled`。

## 启动项目

刷好固件后，双击根目录：

```powershell
.\start.cmd
```

启动器会自动做这些事：

- 检查 Codex hook 是否已经安装
- 如果 hook 缺失，提示你是否安装
- 检查 Go bridge 程序是否存在
- 如果 bridge 缺失，自动构建
- 列出可用 COM 口
- 让你选择 ESP32-C3 对应的 COM 口
- 保存 COM 口选择
- 启动状态桥接程序

菜单操作：

| 按键 | 作用 |
| --- | --- |
| `↑` / `↓` | 上下选择 |
| `Space` / `Enter` | 确认 |
| `Esc` | 取消 |
| `Ctrl+C` | 停止正在运行的 bridge |

启动成功后会看到类似输出：

```text
Starting bridge on COM5...
Press Ctrl+C to stop.

[2026-07-05 18:41:19] serial connected: COM5 @ 115200
[2026-07-05 18:41:20] sent idle -> COM5
```

保持这个窗口运行，Codex 状态变化时灯环才会同步变化。

## 灯光状态

`StatusLightV2` 支持这些状态和灯效：

| 状态 | 含义 | 灯光效果 |
| --- | --- | --- |
| `idle` | 空闲、没有正在执行的任务 | 绿色呼吸 |
| `thinking` | 已提交提示词，Agent 正在思考 | 蓝色移动脉冲 |
| `working` | 正在执行工具或处理任务 | 黄色/橙色追逐 |
| `waiting` | 等待用户输入或授权 | 紫色呼吸 |
| `success` | 任务成功完成 | 绿色 + 亮色扫光 |
| `error` | 出错或需要注意 | 红色闪烁 |
| `unknown` | 未识别或状态不明确 | 蓝色常亮 |

兼容别名：

| 输入状态 | 等同于 |
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

当前 Go bridge 仍然主要发送兼容状态：

```text
idle
working
attention
unknown
```

所以现在 Codex 对话中最常见的灯光是：

| Codex/Bridge 状态 | V2 显示效果 |
| --- | --- |
| `idle` | 绿色呼吸 |
| `working` | 黄色/橙色追逐 |
| `attention` | 红色闪烁 |
| `unknown` | 蓝色常亮 |

`thinking`、`waiting`、`success` 等状态已经在固件 V2 中预留，后续只需要扩展 Go hook 映射即可使用。

## 手动测试

可以用 dry-run 检查 bridge 是否能读取状态：

```powershell
.\bin\ai-hook-bridge.exe bridge -dry-run -once
```

也可以手动触发一次 hook：

```powershell
'{"hook_event_name":"UserPromptSubmit","session_id":"manual-test"}' | .\bin\ai-hook-bridge.exe hook
```

然后运行：

```powershell
.\start.cmd
```

## 常见问题

### 找不到 COM 口

检查 USB 线是否支持数据传输，重新插拔 ESP32-C3，然后重新运行 `start.cmd` 或 `flash-firmware.cmd`。

### 多个 COM 口不知道选哪个

先拔掉 ESP32-C3，运行一次观察列表；再插上 ESP32-C3，多出来的那个通常就是开发板。

### 串口写入超时

常见原因是固件没有启用 USB CDC，或者刷入了不读串口的 demo 固件。

建议重新运行：

```powershell
.\hardware\arduino\flash-firmware.cmd
```

并选择 `Status Light V2`。

### 灯不亮

依次检查：

- 是否刷入了 `Status Light V2`
- 灯环 DIN 是否接到 GPIO10
- 5V / GND 是否接好
- 灯珠数量是否是 24
- 是否选择了正确 COM 口

## 项目结构

```text
start.cmd                 新手双击启动入口
bin/
  agent-hook-light.ps1     启动器逻辑
  codex-hook.cmd           Codex hook 命令包装
  ai-hook-bridge.exe       Go bridge 可执行文件
  install.ps1              Codex hook 安装/检查脚本
bridge/
  main.go                  CLI 入口
  hook.go                  Codex hook 解析和状态写入
  bridge.go                状态文件监听和串口发送
data/
  .gitkeep                 运行时状态目录占位
hardware/
  arduino/
    flash-firmware.cmd     固件刷写入口
    flash-firmware.ps1     固件刷写逻辑
    firmware/
      StatusLightV2/
      StatusLightBaseV1/
      RainbowLight/
test/
  install.test.ps1
  launcher.test.ps1
  firmware-flasher.test.ps1
```

运行时状态和日志会写入 `data/`，不会提交到 Git。

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

## License

MIT
