# Arduino Firmware

This folder contains the ESP32-C3 + WS2812B firmware for Agent Hook Light.

Firmware sketches live under `firmware`:

- `firmware/StatusLightV2/StatusLightV2.ino`: richer animated status firmware for the expanded state protocol; recommended for new installs
- `firmware/StatusLightBaseV1/StatusLightBaseV1.ino`: base compatibility firmware for the current Go bridge
- `firmware/RainbowLight/RainbowLight.ino`: standalone rainbow light demo firmware

Shared hardware settings:

- Board: ESP32-C3
- LED type: WS2812B
- LED count: 24
- Data pin: GPIO10
- Color order: GRB
- Serial baud rate: 115200

The compatibility V1 firmware reads one status line from USB serial:

```text
idle
working
attention
unknown
```

Default color mapping:

| State | Color |
| --- | --- |
| `idle` | Green |
| `working` | Yellow |
| `attention` | Red |
| `unknown` | Blue |

The V2 firmware accepts the expanded status vocabulary:

```text
idle
thinking
working
waiting
success
error
unknown
```

Compatibility aliases accepted by V2:

| Alias | V2 state |
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

V2 default effects:

| State | Effect |
| --- | --- |
| `idle` | Green breathing |
| `thinking` | Blue moving pulse |
| `working` | Yellow/orange chase |
| `waiting` | Purple breathing |
| `success` | Green with bright sweep |
| `error` | Red flash |
| `unknown` | Solid blue |

The included flasher enables USB CDC on boot automatically so the firmware reads status lines from the selected COM port. When flashing from Arduino IDE, enable USB CDC on boot for ESP32-C3 serial access.

## Double-Click Flashing

From the repository root, run:

```powershell
.\hardware\arduino\flash-firmware.cmd
```

The flasher downloads a local Arduino CLI into `tools/arduino-cli` if needed, installs ESP32 board support and FastLED, asks which firmware to flash, asks for the ESP32-C3 COM port, then compiles and uploads the firmware. For normal Agent Hook Light use, choose `Status Light V2`.

Each firmware uses a standard Arduino sketch folder. The flasher lists sketch folders under `firmware` first so you can choose which firmware to upload.

If automatic download fails or you do not want the script to download tools, download Arduino CLI manually:

```text
https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip
```

Extract `arduino-cli.exe` to `tools\arduino-cli\arduino-cli.exe`, then run `hardware\arduino\flash-firmware.cmd` again.

If ESP32 board support download fails, the flasher retries Arduino CLI network commands and then prints manual commands for:

- `core update-index --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json`
- `core install esp32:esp32 --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json`
- `lib install FastLED@3.9.4`

The flasher pins FastLED to `3.9.4` because it compiles this firmware successfully and avoids the much larger latest FastLED package.

For unattended local setup, pass `-Yes` to the PowerShell script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hardware\arduino\flash-firmware.ps1 -Yes -Port COM4
```
