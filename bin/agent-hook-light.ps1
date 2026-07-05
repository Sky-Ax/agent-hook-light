param(
  [switch]$NoRun
)

$ErrorActionPreference = "Stop"
try {
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {
}

function Write-LauncherHeader {
  Write-Host ""
  Write-Host "+----------------------------------------+"
  Write-Host "|  💡 Agent Hook Light                   |"
  Write-Host "|  Codex hook + ESP32 status bridge      |"
  Write-Host "+----------------------------------------+"
  Write-Host ""
}

function Write-LauncherStep {
  param([string]$Text)

  Write-Host "🔎 $Text" -ForegroundColor Cyan
}

function Write-LauncherSuccess {
  param([string]$Text)

  Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-LauncherWarning {
  param([string]$Text)

  Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Write-LauncherError {
  param([string]$Text)

  Write-Host "❌ $Text" -ForegroundColor Red
}

function Write-LauncherInfo {
  param([string]$Text)

  Write-Host "ℹ️  $Text" -ForegroundColor DarkCyan
}

function Get-SavedSerialPort {
  param(
    [string]$ConfigFile,
    [string]$LegacyConfigFile = ""
  )

  $configPath = $ConfigFile
  $shouldMigrate = $false
  if (!(Test-Path -LiteralPath $configPath)) {
    if (![string]::IsNullOrWhiteSpace($LegacyConfigFile) -and (Test-Path -LiteralPath $LegacyConfigFile)) {
      $configPath = $LegacyConfigFile
      $shouldMigrate = $true
    } else {
      return $null
    }
  }

  try {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$config.PSObject.Properties["saved_port"]) {
      return $null
    }

    $port = [string]$config.saved_port
    if ([string]::IsNullOrWhiteSpace($port)) {
      return $null
    }

    $normalizedPort = $port.Trim().ToUpperInvariant()
    if ($shouldMigrate) {
      Save-SelectedSerialPort -ConfigFile $ConfigFile -Port $normalizedPort
    }

    return $normalizedPort
  } catch {
    return $null
  }
}

function Save-SelectedSerialPort {
  param(
    [string]$ConfigFile,
    [string]$Port
  )

  $normalizedPort = $Port.Trim().ToUpperInvariant()
  $configDir = Split-Path -Parent $ConfigFile
  if (!(Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
  }

  $json = [pscustomobject]@{
    saved_port = $normalizedPort
  } | ConvertTo-Json

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($ConfigFile, $json + "`r`n", $encoding)
}

function Ensure-StatusFile {
  param([string]$StatusFile)

  if (Test-Path -LiteralPath $StatusFile) {
    return
  }

  $statusDir = Split-Path -Parent $StatusFile
  if (!(Test-Path -LiteralPath $statusDir)) {
    New-Item -ItemType Directory -Path $statusDir | Out-Null
  }

  $now = Get-Date
  $status = [pscustomobject]@{
    provider     = "codex"
    state        = "idle"
    color        = "green"
    reason       = "launcher_initial_status"
    event        = "LauncherStart"
    updatedAt    = $now.ToString("yyyy-MM-dd HH:mm:ss")
    updatedAtIso = $now.ToUniversalTime().ToString("o")
    sessions     = [pscustomobject]@{}
  }

  $json = $status | ConvertTo-Json -Depth 5
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($StatusFile, $json + "`r`n", $encoding)
}

function Get-SerialPortsFromOutput {
  param([string[]]$Output)

  $ports = @()
  foreach ($line in @($Output)) {
    $port = ([string]$line).Trim().ToUpperInvariant()
    if ($port -match '^COM[0-9]+$') {
      $ports += $port
    }
  }

  return $ports
}

function Resolve-SerialPortSelection {
  param(
    [string[]]$Ports,
    [string]$Choice
  )

  if ([string]::IsNullOrWhiteSpace($Choice)) {
    return $null
  }

  $normalizedPorts = @($Ports | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() })
  $trimmedChoice = $Choice.Trim()

  if ($trimmedChoice -match '^[0-9]+$') {
    $index = [int]$trimmedChoice - 1
    if ($index -ge 0 -and $index -lt $normalizedPorts.Count) {
      return $normalizedPorts[$index]
    }
    return $null
  }

  $portChoice = $trimmedChoice.ToUpperInvariant()
  if ($normalizedPorts -contains $portChoice) {
    return $portChoice
  }

  return $null
}

function Get-SerialPorts {
  param([string]$BridgeExe)

  $output = & $BridgeExe bridge -list-ports 2>&1
  return @(Get-SerialPortsFromOutput -Output $output)
}

function Get-MenuHelpText {
  return "Use ↑ / ↓ to choose, Space or Enter to confirm. Press Esc to cancel."
}

function Move-MenuSelection {
  param(
    [int]$CurrentIndex,
    [int]$ItemCount,
    [string]$Key
  )

  if ($ItemCount -le 0) {
    return 0
  }

  switch ($Key) {
    "DownArrow" { return (($CurrentIndex + 1) % $ItemCount) }
    "UpArrow" { return (($CurrentIndex - 1 + $ItemCount) % $ItemCount) }
    default { return $CurrentIndex }
  }
}

function Get-MenuKeyAction {
  param([string]$Key)

  switch ($Key) {
    "Enter" { return "confirm" }
    "Spacebar" { return "confirm" }
    "Escape" { return "cancel" }
    default { return "move" }
  }
}

function Show-KeyboardMenu {
  param(
    [string]$Title,
    [string[]]$Items,
    [int]$DefaultIndex = 0,
    [string[]]$Details = @()
  )

  if ($Items.Count -eq 0) {
    return -1
  }

  $selectedIndex = $DefaultIndex
  if ($selectedIndex -lt 0 -or $selectedIndex -ge $Items.Count) {
    $selectedIndex = 0
  }

  while ($true) {
    Clear-Host
    Write-LauncherHeader

    if (![string]::IsNullOrWhiteSpace($Title)) {
      Write-Host $Title -ForegroundColor Cyan
      Write-Host ""
    }

    foreach ($detail in @($Details)) {
      if (![string]::IsNullOrWhiteSpace($detail)) {
        Write-Host $detail
      }
    }
    if ($Details.Count -gt 0) {
      Write-Host ""
    }

    Write-LauncherInfo (Get-MenuHelpText)
    Write-Host ""

    for ($i = 0; $i -lt $Items.Count; $i++) {
      if ($i -eq $selectedIndex) {
        Write-Host ("  ▶ {0}" -f $Items[$i]) -ForegroundColor Green
      } else {
        Write-Host ("    {0}" -f $Items[$i])
      }
    }

    $keyInfo = [Console]::ReadKey($true)
    $key = $keyInfo.Key.ToString()
    $action = Get-MenuKeyAction -Key $key

    if ($action -eq "confirm") {
      return $selectedIndex
    }

    if ($action -eq "cancel") {
      return -1
    }

    $selectedIndex = Move-MenuSelection -CurrentIndex $selectedIndex -ItemCount $Items.Count -Key $key
  }
}

function Confirm-LauncherPrompt {
  param(
    [string]$Prompt,
    [bool]$DefaultYes = $false,
    [string]$YesLabel = "Yes",
    [string]$NoLabel = "No"
  )

  $items = @($YesLabel, $NoLabel)
  $defaultIndex = 1
  if ($DefaultYes) {
    $defaultIndex = 0
  }

  $selection = Show-KeyboardMenu -Title $Prompt -Items $items -DefaultIndex $defaultIndex
  return ($selection -eq 0)
}

function Invoke-ConsoleCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments = @()
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $FilePath @Arguments 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host $_.Exception.Message
      } else {
        Write-Host $_
      }
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  return [int]$exitCode
}

function Invoke-InstallerMode {
  param(
    [string]$InstallScript,
    [string]$Mode
  )

  $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallScript $Mode 2>&1
  $exitCode = $LASTEXITCODE
  foreach ($line in @($output)) {
    Write-Host $line
  }
  return [int]$exitCode
}

function Select-SerialPort {
  param(
    [string]$BridgeExe,
    [string]$ConfigFile,
    [string]$LegacyConfigFile = ""
  )

  $ports = @(Get-SerialPorts -BridgeExe $BridgeExe)
  if ($ports.Count -eq 0) {
    throw "No serial ports found. Connect the ESP32 device and try again."
  }

  $savedPort = Get-SavedSerialPort -ConfigFile $ConfigFile -LegacyConfigFile $LegacyConfigFile
  if ($savedPort) {
    if ($ports -contains $savedPort) {
      $selection = Show-KeyboardMenu `
        -Title "🔌 Saved serial port: $savedPort" `
        -Items @("Yes, use $savedPort", "Choose another port") `
        -DefaultIndex 0 `
        -Details @("Use the saved ESP32 port, or choose again if you moved the device.")
      if ($selection -eq 0) {
        return $savedPort
      }
    } else {
      Write-LauncherWarning "Saved serial port is not available: $savedPort"
    }
    Write-Host ""
  }

  while ($true) {
    $selection = Show-KeyboardMenu `
      -Title "🔌 Step 3/3  Select ESP32 serial port" `
      -Items $ports `
      -DefaultIndex 0 `
      -Details @("Tip: unplug/replug the ESP32 if you are not sure which COM port is correct.")
    if ($selection -ge 0) {
      $selectedPort = $ports[$selection]
      Save-SelectedSerialPort -ConfigFile $ConfigFile -Port $selectedPort
      Write-LauncherSuccess "Saved serial port: $selectedPort"
      return $selectedPort
    }

    throw "Serial port selection was cancelled."
  }
}

function Invoke-AgentStatusLightLauncher {
  $binDir = $PSScriptRoot
  $rootDir = Split-Path -Parent $binDir
  $dataDir = Join-Path $rootDir "data"
  $installScript = Join-Path $binDir "install.ps1"
  $bridgeExe = Join-Path $binDir "ai-hook-bridge.exe"
  $statusFile = Join-Path $dataDir "codex-status.json"
  $configFile = Join-Path $dataDir "agent-hook-light.config.json"
  $legacyConfigFile = Join-Path $dataDir "agent-status-light.config.json"

  Clear-Host
  Write-LauncherHeader

  if (!(Test-Path -LiteralPath $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
  }

  if (!(Test-Path -LiteralPath $installScript)) {
    throw "Missing installer: $installScript"
  }

  if (!(Test-Path -LiteralPath $bridgeExe)) {
    throw "Missing bridge executable: $bridgeExe"
  }

  Write-LauncherStep "Step 1/3  Checking Codex hook setup..."
  $checkCode = Invoke-InstallerMode -InstallScript $installScript -Mode "-Check"
  if ($checkCode -ne 0) {
    Write-Host ""
    Write-LauncherWarning "Codex hook is not installed or incomplete."
    if (!(Confirm-LauncherPrompt `
      -Prompt "🛠️  Install Codex hook now?" `
      -YesLabel "Yes, install/update hook" `
      -NoLabel "No, exit")) {
      Write-LauncherWarning "Cancelled."
      return 1
    }

    Write-Host ""
    Write-LauncherStep "Installing Codex hook..."
    $installCode = Invoke-InstallerMode -InstallScript $installScript -Mode "-Install"
    if ($installCode -ne 0) {
      return $installCode
    }

    Write-Host ""
    Write-LauncherStep "Rechecking setup..."
    $recheckCode = Invoke-InstallerMode -InstallScript $installScript -Mode "-Check"
    if ($recheckCode -ne 0) {
      return $recheckCode
    }
  }

  Write-Host ""
  Write-LauncherSuccess "Codex hook setup is ready."
  Write-Host ""

  if (!(Confirm-LauncherPrompt `
    -Prompt "🚀 Step 2/3  Start serial bridge now?" `
    -DefaultYes $true `
    -YesLabel "Yes, start bridge" `
    -NoLabel "No, exit")) {
    Write-LauncherWarning "Cancelled."
    return 0
  }

  $selectedPort = Select-SerialPort -BridgeExe $bridgeExe -ConfigFile $configFile -LegacyConfigFile $legacyConfigFile
  Ensure-StatusFile -StatusFile $statusFile

  Clear-Host
  Write-LauncherHeader
  Write-Host ""
  Write-LauncherSuccess "Saved serial port: $selectedPort"
  Write-Host "🚀 Starting bridge on $selectedPort..." -ForegroundColor Green
  Write-Host "Press Ctrl+C to stop."
  Write-Host ""

  return (Invoke-ConsoleCommand -FilePath $bridgeExe -Arguments @("bridge", "-status", $statusFile, "-port", $selectedPort))
}

if (!$NoRun) {
  try {
    exit (Invoke-AgentStatusLightLauncher)
  } catch {
    Write-Host ""
    Write-LauncherError $($_.Exception.Message)
    exit 1
  }
}
