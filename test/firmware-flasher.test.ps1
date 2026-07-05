$ErrorActionPreference = "Stop"

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $TestDir
$FlasherScript = Join-Path $Root "hardware\arduino\flash-firmware.ps1"
$HardwareFlasherCmd = Join-Path $Root "hardware\arduino\flash-firmware.cmd"
$RootFlasherCmd = Join-Path $Root "flash-firmware.cmd"

function Assert-Equal {
  param($Actual, $Expected, [string]$Message)

  if ($Actual -ne $Expected) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function Assert-True {
  param([bool]$Condition, [string]$Message)

  if (!$Condition) {
    throw $Message
  }
}

. $FlasherScript -NoRun

Assert-True (Test-Path -LiteralPath $HardwareFlasherCmd) "Firmware double-click launcher should live under hardware\arduino."
Assert-True (!(Test-Path -LiteralPath $RootFlasherCmd)) "Repository root should stay minimal and should not contain flash-firmware.cmd."

$resolvedRoot = Get-ProjectRootFromArduinoScript -ArduinoScriptDir (Join-Path $Root "hardware\arduino")
Assert-Equal $resolvedRoot $Root "Arduino script directory should resolve to the repository root."

$cliPath = Get-ArduinoCliPath -RootDir $Root
Assert-Equal $cliPath (Join-Path $Root "tools\arduino-cli\arduino-cli.exe") "Arduino CLI should live under the local tools directory."

$boardFqbn = Get-BoardFqbn
Assert-Equal $boardFqbn "esp32:esp32:esp32c3:CDCOnBoot=cdc" "Firmware must enable USB CDC on boot so Serial reads from the selected COM port."

$arduinoDataDir = Get-ArduinoDataDir
Assert-Equal $arduinoDataDir (Join-Path $env:LOCALAPPDATA "Arduino15") "Arduino CLI data directory should match the Windows Arduino15 location."

$esp32IndexPath = Get-Esp32IndexPath
Assert-Equal $esp32IndexPath (Join-Path $env:LOCALAPPDATA "Arduino15\package_esp32_index.json") "ESP32 package index path should point to the Arduino15 cache."

$ports = Get-SerialPortsFromOutput -Output @("No serial ports found.", "COM3", "COM7", "not-a-port", " /dev/ttyUSB0 ")
Assert-Equal $ports.Count 2 "Only Windows COM ports should be kept."
Assert-Equal $ports[0] "COM3" "First COM port should be preserved."
Assert-Equal $ports[1] "COM7" "Second COM port should be preserved."

Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "2") "COM4" "Numeric selection should use one-based indexes."
Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "com7") "COM7" "COM name selection should be case-insensitive."
Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "4") $null "Out-of-range numeric selection should be rejected."
Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "COM9") $null "Unavailable COM name should be rejected."

$latestUrl = Get-ArduinoCliDownloadUrl -Version "latest"
Assert-Equal $latestUrl "https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip" "Latest download URL should use the official Arduino Windows 64-bit archive."

$manualMessage = Get-ArduinoCliManualInstallMessage -RootDir $Root
Assert-True ($manualMessage -like "*https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip*") "Manual install message should include the Arduino CLI download URL."
Assert-True ($manualMessage -like "*tools\arduino-cli\arduino-cli.exe*") "Manual install message should include the local Arduino CLI target path."
Assert-True ($manualMessage -like "*hardware\arduino\flash-firmware.cmd*") "Manual install message should tell the user to run the hardware flasher again."

$esp32Message = Get-Esp32CoreManualInstallMessage -ArduinoCli $cliPath
Assert-True ($esp32Message -like "*https://espressif.github.io/arduino-esp32/package_esp32_index.json*") "ESP32 fallback message should include the Espressif package index URL."
Assert-True ($esp32Message -like "*core update-index*") "ESP32 fallback message should include the update-index command."
Assert-True ($esp32Message -like "*core install esp32:esp32*") "ESP32 fallback message should include the ESP32 core install command."
Assert-True ($esp32Message -like "*lib install FastLED@3.9.4*") "ESP32 fallback message should include the pinned FastLED install command."

Assert-Equal (Get-FastLedLibrarySpec) "FastLED@3.9.4" "FastLED should be pinned to the verified smaller package."
Assert-Equal (Test-CoreListContainsPlatform -Output @("ID          Installed Latest Name", "esp32:esp32 3.3.10    3.3.10 esp32") -PlatformId "esp32:esp32") $true "ESP32 core list parser should detect an installed core."
Assert-Equal (Test-CoreListContainsPlatform -Output @("ID          Installed Latest Name", "arduino:avr 1.8.8 1.8.8 Arduino AVR Boards") -PlatformId "esp32:esp32") $false "ESP32 core list parser should reject missing core."
Assert-Equal (Test-LibListContainsLibrary -Output @("Name    Installed Available Location Description", "FastLED 3.9.4     3.10.5    user     LED library") -LibraryName "FastLED") $true "Library list parser should detect installed FastLED."
Assert-Equal (Test-LibListContainsLibrary -Output @("No libraries installed.") -LibraryName "FastLED") $false "Library list parser should reject missing FastLED."

Assert-Equal (Get-RetryAttemptMessage -Attempt 1 -Attempts 3) "" "First command attempt should not show a retry label."
Assert-Equal (Get-RetryAttemptMessage -Attempt 2 -Attempts 3) "Retry attempt 2/3" "Second command attempt should be labeled as a retry."
Assert-Equal (Get-RetryAttemptMessage -Attempt 3 -Attempts 3) "Retry attempt 3/3" "Third command attempt should be labeled as a retry."

$firmwareRoot = Get-FirmwareRootDir -RootDir $Root
Assert-Equal $firmwareRoot (Join-Path $Root "hardware\arduino\firmware") "Firmware discovery should use the shared Arduino firmware folder."

Assert-Equal (Convert-FirmwareIdToName -Id "StatusLightBaseV1") "Status Light Base V1" "Status firmware display names should include the version."
Assert-Equal (Convert-FirmwareIdToName -Id "StatusLightV2") "Status Light V2" "V2 status firmware display name should include the version."
Assert-Equal (Convert-FirmwareIdToName -Id "StatusLightV3") "Status Light V3" "V3 status firmware display name should include the version."
Assert-Equal (Convert-FirmwareIdToName -Id "StatusLightShowcase") "Status Light Showcase" "Showcase firmware display name should be human-readable."
Assert-Equal (Convert-FirmwareIdToName -Id "RainbowLight") "Rainbow Light" "Firmware display names should be readable for new firmware ids."

$firmwares = @(Get-FirmwareDefinitions -RootDir $Root)
Assert-True ($firmwares.Count -ge 2) "Firmware flasher should expose firmware sketches from the shared Arduino firmware folder."
$rainbowFirmware = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "RainbowLight"
Assert-Equal $rainbowFirmware.Id "RainbowLight" "Rainbow firmware should be discoverable."
Assert-Equal $rainbowFirmware.Name "Rainbow Light" "Rainbow firmware display name should be human-readable."
Assert-Equal $rainbowFirmware.RelativeSketchPath "hardware\arduino\firmware\RainbowLight\RainbowLight.ino" "Rainbow firmware sketch path should use a standard Arduino sketch folder."
Assert-True (Test-Path -LiteralPath $rainbowFirmware.SketchPath) "Rainbow firmware sketch path should exist on disk."
Assert-True (!(Test-Path -LiteralPath (Join-Path $Root "hardware\arduino\firmware\RainbowLight.ino"))) "Rainbow firmware should not live as a peer ino file."
$statusFirmware = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "StatusLightBaseV1"
Assert-Equal $statusFirmware.Id "StatusLightBaseV1" "Versioned base status firmware should be available."
Assert-Equal $statusFirmware.Name "Status Light Base V1" "Status firmware display name should include the version."
Assert-Equal $statusFirmware.RelativeSketchPath "hardware\arduino\firmware\StatusLightBaseV1\StatusLightBaseV1.ino" "Status firmware sketch path should use a versioned standard Arduino sketch folder."
Assert-True (Test-Path -LiteralPath $statusFirmware.SketchPath) "Status firmware sketch path should exist on disk."
Assert-True (!(Test-Path -LiteralPath (Join-Path $Root "hardware\arduino\firmware\StatusLightBaseV1.ino"))) "Status firmware should not live as a peer ino file."
Assert-True (!(Test-Path -LiteralPath (Join-Path $Root "hardware\arduino\SerialStatusLight"))) "Old SerialStatusLight firmware container should be removed."
$statusV2Firmware = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "StatusLightV2"
Assert-Equal $statusV2Firmware.Id "StatusLightV2" "V2 status firmware should be available."
Assert-Equal $statusV2Firmware.Name "Status Light V2" "V2 status firmware display name should include the version."
Assert-Equal $statusV2Firmware.RelativeSketchPath "hardware\arduino\firmware\StatusLightV2\StatusLightV2.ino" "V2 status firmware sketch path should use a versioned standard Arduino sketch folder."
Assert-True (Test-Path -LiteralPath $statusV2Firmware.SketchPath) "V2 status firmware sketch path should exist on disk."
Assert-True (!(Test-Path -LiteralPath (Join-Path $Root "hardware\arduino\firmware\StatusLightV2.ino"))) "V2 status firmware should not live as a peer ino file."

$statusV2Source = Get-Content -Raw -LiteralPath $statusV2Firmware.SketchPath
foreach ($stateName in @("idle", "thinking", "working", "waiting", "success", "error", "unknown")) {
  Assert-True ($statusV2Source -like "*`"$stateName`"*") "V2 firmware should support the '$stateName' state."
}
foreach ($aliasName in @("submitted", "tool_running", "waiting_user", "waiting_permission", "done", "complete", "failed", "failure", "attention")) {
  Assert-True ($statusV2Source -like "*`"$aliasName`"*") "V2 firmware should support the '$aliasName' compatibility alias."
}
foreach ($simpleHelper in @("IDLE_COLOR", "SUCCESS_COLOR", "WAITING_COLOR", "drawChase", "drawSingleScan", "drawWaitingCue")) {
  Assert-True ($statusV2Source -like "*$simpleHelper*") "V2 firmware should include the simple ring helper '$simpleHelper'."
}
foreach ($colorLiteral in @("CRGB(0, 220, 90)", "CRGB(0, 80, 55)", "CRGB(30, 110, 255)", "CRGB(255, 140, 0)", "CRGB(150, 45, 255)", "CRGB(45, 40, 140)")) {
  Assert-True ($statusV2Source -like "*$colorLiteral*") "V2 firmware should include the simplified color $colorLiteral."
}
foreach ($complexPattern in @("ENTER_PULSE_MS", "drawStatusAckPulse", "qadd8", "addPixelWrapped")) {
  Assert-True ($statusV2Source -cnotmatch [regex]::Escape($complexPattern)) "V2 firmware should avoid the complex additive effect '$complexPattern'."
}
Assert-True ($statusV2Source -cnotmatch '\bbeatsin8\b') "V2 firmware should avoid breathing effects in the interaction-focused profile."
Assert-True ($statusV2Source -cnotmatch '\bString\b') "V2 firmware should avoid Arduino String allocations in the serial parser."
Assert-True ($statusV2Source -cnotmatch '\bdelay\s*\(') "V2 firmware should keep the serial/render loop non-blocking."

$statusV3Firmware = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "StatusLightV3"
Assert-Equal $statusV3Firmware.Id "StatusLightV3" "V3 status firmware should be available."
Assert-Equal $statusV3Firmware.Name "Status Light V3" "V3 status firmware display name should include the version."
Assert-Equal $statusV3Firmware.RelativeSketchPath "hardware\arduino\firmware\StatusLightV3\StatusLightV3.ino" "V3 status firmware sketch path should use a versioned standard Arduino sketch folder."
Assert-True (Test-Path -LiteralPath $statusV3Firmware.SketchPath) "V3 status firmware sketch path should exist on disk."
$statusV3Source = Get-Content -Raw -LiteralPath $statusV3Firmware.SketchPath
foreach ($stateName in @("idle", "thinking", "working", "waiting", "success", "error", "unknown")) {
  Assert-True ($statusV3Source -like "*`"$stateName`"*") "V3 firmware should support the '$stateName' state."
}
foreach ($aliasName in @("submitted", "tool_running", "waiting_user", "waiting_permission", "done", "complete", "failed", "failure", "attention")) {
  Assert-True ($statusV3Source -like "*`"$aliasName`"*") "V3 firmware should support the '$aliasName' compatibility alias."
}
foreach ($robotHelper in @("drawBotEyes", "drawEye", "drawSmile", "drawTransitionSpark", "renderIdleBot", "renderWaitingBot")) {
  Assert-True ($statusV3Source -like "*$robotHelper*") "V3 firmware should include the robot-style helper '$robotHelper'."
}
Assert-True ($statusV3Source -cnotmatch '\bString\b') "V3 firmware should avoid Arduino String allocations in the serial parser."
Assert-True ($statusV3Source -cnotmatch '\bdelay\s*\(') "V3 firmware should keep the serial/render loop non-blocking."

$showcaseFirmware = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "StatusLightShowcase"
Assert-Equal $showcaseFirmware.Id "StatusLightShowcase" "Status light showcase firmware should be available."
Assert-Equal $showcaseFirmware.Name "Status Light Showcase" "Showcase firmware display name should be human-readable."
Assert-Equal $showcaseFirmware.RelativeSketchPath "hardware\arduino\firmware\StatusLightShowcase\StatusLightShowcase.ino" "Showcase firmware sketch path should use a standard Arduino sketch folder."
Assert-True (Test-Path -LiteralPath $showcaseFirmware.SketchPath) "Showcase firmware sketch path should exist on disk."
$showcaseSource = Get-Content -Raw -LiteralPath $showcaseFirmware.SketchPath
foreach ($stateName in @("idle", "thinking", "working", "waiting", "success", "error", "unknown")) {
  Assert-True ($showcaseSource -like "*`"$stateName`"*") "Showcase firmware should cycle the '$stateName' light effect."
}
Assert-True ($showcaseSource -like "*SHOWCASE_STEP_MS*") "Showcase firmware should use a named display duration."
Assert-True ($showcaseSource -like "*drawBotEyes*") "Showcase firmware should demonstrate the robot-style V3 effects."
Assert-True ($showcaseSource -cnotmatch '\bdelay\s*\(') "Showcase firmware should keep the animation loop non-blocking."

$selectedFirmwareByNumber = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "1"
Assert-Equal $selectedFirmwareByNumber.Id "RainbowLight" "Numeric firmware selection should use one-based indexes."
Assert-True (![string]::IsNullOrWhiteSpace($selectedFirmwareByNumber.SketchPath)) "Numeric firmware selection should return the full firmware object."
$selectedFirmwareByName = Resolve-FirmwareSelection -Firmwares $firmwares -Choice "statuslightbasev1"
Assert-Equal $selectedFirmwareByName.Id "StatusLightBaseV1" "Firmware id selection should be case-insensitive."
Assert-True (![string]::IsNullOrWhiteSpace($selectedFirmwareByName.SketchPath)) "Firmware id selection should return the full firmware object."
Assert-Equal (Resolve-FirmwareSelection -Firmwares $firmwares -Choice "999") $null "Out-of-range firmware selection should be rejected."
Assert-Equal (Resolve-FirmwareSelection -Firmwares $firmwares -Choice "OtherFirmware") $null "Unknown firmware id should be rejected."

$flasherSource = Get-Content -Raw -LiteralPath $FlasherScript
Assert-True ($flasherSource -notlike "*Copy-FirmwareToIsolatedSketch*") "Standard Arduino sketch folders should let the flasher compile selected firmware directly without temporary copying."

Assert-Equal (Move-MenuSelection -CurrentIndex 0 -ItemCount 3 -Key "DownArrow") 1 "DownArrow should move to the next firmware port menu item."
Assert-Equal (Move-MenuSelection -CurrentIndex 2 -ItemCount 3 -Key "DownArrow") 0 "DownArrow should wrap firmware port menu selection to the first item."
Assert-Equal (Move-MenuSelection -CurrentIndex 0 -ItemCount 3 -Key "UpArrow") 2 "UpArrow should wrap firmware port menu selection to the last item."
Assert-Equal (Move-MenuSelection -CurrentIndex 1 -ItemCount 0 -Key "DownArrow") 0 "Empty firmware menus should keep index zero."

Assert-Equal (Get-MenuKeyAction -Key "Enter") "confirm" "Enter should confirm the firmware port menu selection."
Assert-Equal (Get-MenuKeyAction -Key "Spacebar") "confirm" "Spacebar should confirm the firmware port menu selection."
Assert-Equal (Get-MenuKeyAction -Key "Escape") "cancel" "Escape should cancel the firmware port menu selection."
Assert-Equal (Get-MenuKeyAction -Key "A") "move" "Other keys should keep the firmware port menu active."
