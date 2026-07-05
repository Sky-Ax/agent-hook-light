$ErrorActionPreference = "Stop"

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $TestDir
$LauncherScript = Join-Path $Root "bin\agent-hook-light.ps1"
$Temp = Join-Path ([IO.Path]::GetTempPath()) ("agent-hook-light-launcher-" + [guid]::NewGuid())

function Assert-Equal {
  param($Actual, $Expected, [string]$Message)

  if ($Actual -ne $Expected) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function Assert-NullValue {
  param($Actual, [string]$Message)

  if ($null -ne $Actual) {
    throw "$Message Expected null, got '$Actual'."
  }
}

function Assert-True {
  param([bool]$Condition, [string]$Message)

  if (!$Condition) {
    throw $Message
  }
}

try {
  New-Item -ItemType Directory -Path $Temp | Out-Null

  . $LauncherScript -NoRun

  $launcherBytes = [IO.File]::ReadAllBytes($LauncherScript)
  Assert-True (
    $launcherBytes.Length -ge 3 -and
    $launcherBytes[0] -eq 0xEF -and
    $launcherBytes[1] -eq 0xBB -and
    $launcherBytes[2] -eq 0xBF
  ) "Launcher script should use UTF-8 with BOM so Windows PowerShell 5.1 reads emoji and arrows correctly."

  $configPath = Join-Path $Temp "agent-hook-light.config.json"
  Assert-NullValue (Get-SavedSerialPort -ConfigFile $configPath) "Missing config should not produce a saved port."

  Save-SelectedSerialPort -ConfigFile $configPath -Port "COM4"
  Assert-Equal (Get-SavedSerialPort -ConfigFile $configPath) "COM4" "Saved port should round-trip through JSON config."

  $legacyConfigPath = Join-Path $Temp "agent-status-light.config.json"
  Save-SelectedSerialPort -ConfigFile $legacyConfigPath -Port "COM5"
  Remove-Item -LiteralPath $configPath -Force
  Assert-Equal (Get-SavedSerialPort -ConfigFile $configPath -LegacyConfigFile $legacyConfigPath) "COM5" "Legacy config should migrate to the Agent Hook Light config path."
  Assert-Equal (Get-SavedSerialPort -ConfigFile $configPath) "COM5" "Migrated config should be readable from the new path."

  $statusPath = Join-Path $Temp "codex-status.json"
  Ensure-StatusFile -StatusFile $statusPath
  $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Equal $status.provider "codex" "Created status file should identify the Codex provider."
  Assert-Equal $status.state "idle" "Created status file should start in the idle state."

  $mockInstaller = Join-Path $Temp "mock-install.ps1"
  Set-Content -LiteralPath $mockInstaller -Encoding UTF8 -Value @'
param([switch]$Install, [switch]$Check)
Write-Output "mock installer output"
if ($Install) { exit 0 }
if ($Check) { exit 7 }
exit 9
'@
  $installExit = Invoke-InstallerMode -InstallScript $mockInstaller -Mode "-Install"
  Assert-Equal ($installExit -is [int]) $true "Installer helper should return a scalar integer exit code."
  Assert-Equal $installExit 0 "Installer helper should return zero when a noisy child installer succeeds."

  $checkExit = Invoke-InstallerMode -InstallScript $mockInstaller -Mode "-Check"
  Assert-Equal ($checkExit -is [int]) $true "Installer helper should return a scalar integer exit code for failures."
  Assert-Equal $checkExit 7 "Installer helper should preserve a noisy child installer failure exit code."

  $mockBridge = Join-Path $Temp "mock-bridge.ps1"
  Set-Content -LiteralPath $mockBridge -Encoding UTF8 -Value @'
Write-Output "mock bridge output"
exit 6
'@
  $bridgeExit = Invoke-ConsoleCommand `
    -FilePath "powershell.exe" `
    -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $mockBridge)
  Assert-Equal ($bridgeExit -is [int]) $true "Console helper should return a scalar integer exit code."
  Assert-Equal $bridgeExit 6 "Console helper should preserve the child process exit code while forwarding output."

  $mockBridgeError = Join-Path $Temp "mock-bridge-error.ps1"
  Set-Content -LiteralPath $mockBridgeError -Encoding UTF8 -Value @'
Write-Error "mock bridge error"
exit 8
'@
  try {
    $bridgeErrorExit = Invoke-ConsoleCommand `
      -FilePath "powershell.exe" `
      -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $mockBridgeError)
  } catch {
    throw "Console helper should not throw when a child process writes stderr: $($_.Exception.Message)"
  }
  Assert-Equal ($bridgeErrorExit -is [int]) $true "Console helper should return a scalar integer exit code when stderr is written."
  Assert-Equal $bridgeErrorExit 8 "Console helper should preserve the child process exit code when stderr is written."

  $mockRoot = Join-Path $Temp "mock-root"
  $mockBin = Join-Path $mockRoot "bin"
  $mockBridgeSource = Join-Path $mockRoot "bridge"
  New-Item -ItemType Directory -Path $mockBin | Out-Null
  New-Item -ItemType Directory -Path $mockBridgeSource | Out-Null
  $mockBridgeExe = Join-Path $mockBin "ai-hook-bridge.exe"
  $mockGo = Join-Path $Temp "mock-go.cmd"
  Set-Content -LiteralPath $mockGo -Encoding ASCII -Value @'
@echo off
if "%1"=="build" if "%2"=="-o" (
  echo mock bridge exe>"%3"
  exit /b 0
)
exit /b 9
'@
  Assert-Equal (Get-BridgeSourceDir -RootDir $mockRoot) $mockBridgeSource "Bridge source directory should live under the project root."
  Ensure-BridgeExecutable -RootDir $mockRoot -BridgeExe $mockBridgeExe -GoExe $mockGo
  Assert-True (Test-Path -LiteralPath $mockBridgeExe) "Missing bridge executable should be rebuilt automatically."

  $ports = Get-SerialPortsFromOutput -Output @("No serial ports found.", "COM3", "COM7", "not-a-port")
  Assert-Equal $ports.Count 2 "Only COM ports should be kept."
  Assert-Equal $ports[0] "COM3" "First COM port should be kept."
  Assert-Equal $ports[1] "COM7" "Second COM port should be kept."

  Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "2") "COM4" "Numeric selection should use one-based indexes."
  Assert-Equal (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "com7") "COM7" "COM name selection should be case-insensitive."
  Assert-NullValue (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "4") "Out-of-range numeric selection should be rejected."
  Assert-NullValue (Resolve-SerialPortSelection -Ports @("COM3", "COM4", "COM7") -Choice "COM9") "Unavailable COM name should be rejected."

  Assert-Equal (Move-MenuSelection -CurrentIndex 0 -ItemCount 3 -Key "DownArrow") 1 "DownArrow should move to the next menu item."
  Assert-Equal (Move-MenuSelection -CurrentIndex 2 -ItemCount 3 -Key "DownArrow") 0 "DownArrow should wrap to the first menu item."
  Assert-Equal (Move-MenuSelection -CurrentIndex 0 -ItemCount 3 -Key "UpArrow") 2 "UpArrow should wrap to the last menu item."
  Assert-Equal (Move-MenuSelection -CurrentIndex 1 -ItemCount 3 -Key "Spacebar") 1 "Spacebar should keep the selected item before confirmation."
  Assert-Equal (Move-MenuSelection -CurrentIndex 1 -ItemCount 3 -Key "Escape") 1 "Escape should keep the selected item before cancellation."
  Assert-Equal (Move-MenuSelection -CurrentIndex 1 -ItemCount 0 -Key "DownArrow") 0 "Empty menus should keep index zero."

  Assert-Equal (Get-MenuKeyAction -Key "Enter") "confirm" "Enter should confirm the menu selection."
  Assert-Equal (Get-MenuKeyAction -Key "Spacebar") "confirm" "Spacebar should confirm the menu selection."
  Assert-Equal (Get-MenuKeyAction -Key "Escape") "cancel" "Escape should cancel the menu selection."
  Assert-Equal (Get-MenuKeyAction -Key "A") "move" "Other keys should leave the menu active."

  $helpText = Get-MenuHelpText
  Assert-True ($helpText -like "*Space*") "Menu help should mention Space confirmation."
  Assert-True ($helpText -like "*Enter*") "Menu help should mention Enter confirmation."
  Assert-True ($helpText -like "*Esc*") "Menu help should mention Esc cancellation."

  $launcherSource = Get-Content -LiteralPath $LauncherScript -Raw -Encoding UTF8
  Assert-True (
    $launcherSource -match '(?s)Start serial bridge now\?".*?-DefaultYes\s+\$true'
  ) "Start bridge confirmation should default to Yes to reduce repeat-start keystrokes."
} finally {
  Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
}
