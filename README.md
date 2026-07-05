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
Status Light V3
```

固件目录在：

```text
hardware\arduino\firmware
```

可选固件：

| 固件 | 用途 |
| --- | --- |
| `StatusLightV3` | 推荐使用。机器人拟人灯效，有眼神、眨眼、扫视、等待提示和完成庆祝。 |
| `StatusLightV2` | 24 颗圆环简化版。颜色更克制，`waiting` 有醒目的白紫提示灯。 |
| `StatusLightShowcase` | 灯光展示固件。自动循环展示 V3 的所有状态颜色和动画。 |
| `StatusLightBaseV1` | 基础兼容固件，只支持旧版简单状态。 |
| `RainbowLight` | 彩虹测试固件，用来确认灯环硬件正常。 |

ESP32-C3 需要启用 USB CDC 串口。项目自带刷机脚本已经使用：

```text
esp32:esp32:esp32c3:CDCOnBoot=cdc
```

如果你不用脚本、改用 Arduino IDE 手动刷入，请把 **USB CDC On Boot** 设置为 `Enabled`。

## 展示灯效

如果你只是想确认每种状态颜色和动画是否正常，可以刷入：

```text
Status Light Showcase
```

这个固件不需要运行 `start.cmd`，刷入后会自动循环展示 V3 的机器人灯效：

```text
idle -> thinking -> working -> waiting -> success -> error -> unknown
```

每个状态大约展示 3.5 秒，然后进入下一个状态。

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

`StatusLightV3` 支持这些状态和灯效：

| 状态 | 含义 | 灯光效果 |
| --- | --- | --- |
| `idle` | 空闲、没有正在执行的任务 | 青绿色双眼待机，偶尔眨眼和左右扫视 |
| `thinking` | 已提交提示词，Agent 正在思考 | 蓝色眼神 + 环绕思考光点 |
| `working` | 正在执行工具或处理任务 | 黄色/橙色马达追逐灯 + 忙碌眼神 |
| `waiting` | 等待用户输入或授权 | 紫色注视 + 顶部白色提示点 |
| `success` | 任务成功完成 | 绿色开心眼神 + 白绿庆祝扫光 |
| `error` | 出错或需要注意 | 红色窄眼抖动 + 警觉闪烁 |
| `unknown` | 未识别或状态不明确 | 蓝紫色不对称困惑眼神 |

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

Codex hook 会映射到完整状态，不再只压缩成旧版兼容状态：

| Codex hook 事件 | Bridge 状态 | 灯效 |
| --- | --- | --- |
| `UserPromptSubmit` | `thinking` | 开始思考 |
| `PreToolUse` | `working` | 正在执行工具 |
| `PostToolUse` | `thinking` | 工具返回后继续思考 |
| `PermissionRequest` | `waiting` | 等待用户确认 |
| `Stop` | `success` | 本轮完成 |
| 解析错误 | `error` | 错误/注意 |
| 未识别事件 | `unknown` | 状态不明确 |

旧状态 `attention` 仍然兼容，但会被 bridge 归一化为 `error`。

`StatusLightV2` 保留同一套状态协议，灯效定位是“24 颗圆环简化版”。这一版不做呼吸和复杂叠加，主要靠清晰颜色和小幅运动表达状态：

| 状态 | 颜色 | V2 灯效 |
| --- | --- | --- |
| `idle` | 绿色 `RGB(0, 220, 90)` | 低亮全环 + 单点慢速扫描 |
| `thinking` | 蓝色 `RGB(30, 110, 255)` | 低亮全环 + 对称双点慢速移动 |
| `working` | 黄橙色 `RGB(255, 140, 0)` | 低亮全环 + 4 点连续跑马 |
| `waiting` | 紫色 `RGB(150, 45, 255)` + 白色 | 紫色底光 + 顶部 3 颗白紫提示灯闪烁 |
| `success` | 深青色 `RGB(0, 80, 55)` | 深青色全环 + 短暂扫描 |
| `error` | 红色 `RGB(255, 0, 0)` | 红色三连闪 |
| `unknown` | 蓝紫色 `RGB(45, 40, 140)` | 低亮全环 + 单点慢速扫描 |

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

并选择 `Status Light V3`。

### 灯不亮

依次检查：

- 是否刷入了 `Status Light V3`
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
