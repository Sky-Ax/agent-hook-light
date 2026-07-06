# Arduino Firmware

This folder contains the ESP32-C3 + WS2812B firmware for Agent Hook Light.

Firmware sketches live under `firmware`:

- `firmware/StatusLightV3/StatusLightV3.ino`: robot-style animated status firmware with expressive eyes and richer state motion; recommended for new installs
- `firmware/StatusLightV2/StatusLightV2.ino`: simplified 24-LED ring status firmware with clear colors, small motion, and a stronger waiting prompt
- `firmware/StatusLightShowcase/StatusLightShowcase.ino`: standalone showcase firmware that cycles every V3 status light effect
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

The V2 and V3 firmware accept the expanded status vocabulary:

```text
idle
thinking
working
waiting
success
error
unknown
```

Compatibility aliases accepted by V2 and V3:

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

V3 default effects:

| State | Effect |
| --- | --- |
| `idle` | Teal robot eyes with occasional blink and glance |
| `thinking` | Blue eyes with orbiting thought dots |
| `working` | Amber motor chase with busy eyes |
| `waiting` | Purple attentive eyes with a white prompt ping |
| `success` | Green happy eyes with white/green celebration sweep |
| `error` | Red narrow eyes with jitter and alert flash |
| `unknown` | Blue/purple asymmetrical confused eyes |

V2 default effects:

V2 uses a global brightness of `72/255` by default so bare WS2812B LEDs are less harsh without a diffuser. Lower `BRIGHTNESS` in the sketch if the ring is still too bright.

| State | Color | Effect |
| --- | --- | --- |
| `idle` | Green `RGB(0, 220, 90)` | Bright full ring with a short scan |
| `thinking` | Blue `RGB(30, 110, 255)` | Very dim full ring with a low-brightness four-dot chase |
| `working` | Amber `RGB(255, 140, 0)` | Low full ring with two opposite moving dots |
| `waiting` | Low amber `RGB(140, 78, 0)` / dark amber `RGB(18, 8, 0)` | Even/odd alternating flash for confirmation required |
| `success` | Pure green `RGB(0, 255, 0)` | Low full ring with one slow scanning dot |
| `error` | Red `RGB(255, 0, 0)` | Red triple flash |
| `unknown` | Cool gray `RGB(80, 90, 100)` | Very dim full-ring slow breathing for disconnected state |

`StatusLightShowcase` does not read status from serial. It automatically cycles through `idle`, `thinking`, `working`, `waiting`, `success`, `error`, and `unknown`, holding each V3 effect for about 3.5 seconds. Use it when you want to preview every status color and animation without running the Go bridge.

The included flasher enables USB CDC on boot automatically so the firmware reads status lines from the selected COM port. When flashing from Arduino IDE, enable USB CDC on boot for ESP32-C3 serial access.

## Double-Click Flashing

From the repository root, run:

```powershell
.\hardware\arduino\flash-firmware.cmd
```

The flasher downloads a local Arduino CLI into `tools/arduino-cli` if needed, installs ESP32 board support and FastLED, asks which firmware to flash, asks for the ESP32-C3 COM port, then compiles and uploads the firmware. For normal Agent Hook Light use, choose `Status Light V3`. To preview every status effect, choose `Status Light Showcase`.

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
