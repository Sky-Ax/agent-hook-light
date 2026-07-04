param(
  [switch]$Check,
  [switch]$Install,
  [switch]$Uninstall,
  [switch]$Interactive,
  [switch]$PurgeData,
  [switch]$StopBridge,
  [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
  [string]$DataDir = ""
)

$ErrorActionPreference = "Stop"

$Events = @("UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop")
$BinDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $BinDir
$HookCommand = Join-Path $BinDir "codex-hook.cmd"
$BridgeExe = Join-Path $BinDir "ai-hook-bridge.exe"
if ([string]::IsNullOrWhiteSpace($DataDir)) {
  $DataDir = Join-Path $Root "data"
}
$LegacyHookCommands = @(
  (Join-Path $Root "codex-hook.cmd")
)
$HooksPath = Join-Path $CodexHome "hooks.json"
$StatusMessage = "Recording Codex status"
$RuntimeDataPatterns = @(
  "codex-status.json",
  "codex-hook-log.jsonl",
  "codex-hook-log.jsonl.*",
  "codex-hook-wrapper.log",
  "codex-hook-wrapper.log.*"
)

function Count-Modes {
  $count = 0
  foreach ($value in @($Check, $Install, $Uninstall, $Interactive)) {
    if ($value) { $count++ }
  }
  return $count
}

function Add-Or-SetProperty {
  param($Object, [string]$Name, $Value)

  if ($Object.PSObject.Properties[$Name]) {
    $Object.$Name = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

function Read-HooksFile {
  if (!(Test-Path -LiteralPath $HooksPath)) {
    return [pscustomobject]@{ hooks = [pscustomobject]@{} }
  }

  $raw = Get-Content -LiteralPath $HooksPath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [pscustomobject]@{ hooks = [pscustomobject]@{} }
  }

  $data = $raw | ConvertFrom-Json
  if (!$data.PSObject.Properties["hooks"]) {
    Add-Or-SetProperty $data "hooks" ([pscustomobject]@{})
  }
  return $data
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Text)

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Backup-HooksFile {
  if (Test-Path -LiteralPath $HooksPath) {
    $backup = "$HooksPath.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $HooksPath -Destination $backup
    Write-Host "Backup: $backup"
  }
}

function Save-HooksFile {
  param($Data)

  if (!(Test-Path -LiteralPath $CodexHome)) {
    New-Item -ItemType Directory -Path $CodexHome | Out-Null
  }

  Backup-HooksFile
  $json = $Data | ConvertTo-Json -Depth 20
  Write-Utf8NoBom $HooksPath ($json + "`r`n")
}

function New-HookEntry {
  return [pscustomobject]@{
    type = "command"
    command = $HookCommand
    timeout = 5
    statusMessage = $StatusMessage
  }
}

function Ensure-EventGroup {
  param($Hooks, [string]$Event)

  if (!$Hooks.PSObject.Properties[$Event]) {
    Add-Or-SetProperty $Hooks $Event @([pscustomobject]@{ hooks = @() })
  }

  $groups = @($Hooks.$Event)
  if ($groups.Count -eq 0) {
    $groups = @([pscustomobject]@{ hooks = @() })
  }

  foreach ($group in $groups) {
    if (!$group.PSObject.Properties["hooks"]) {
      Add-Or-SetProperty $group "hooks" @()
    }
  }

  return $groups
}

function Remove-OurHookFromGroups {
  param($Groups)

  foreach ($group in $Groups) {
    $kept = @($group.hooks) | Where-Object {
      $command = $_.command
      if ($command -ieq $HookCommand) {
        return $false
      }

      foreach ($legacyCommand in $LegacyHookCommands) {
        if ($command -ieq $legacyCommand) {
          return $false
        }
      }

      return $true
    }
    Add-Or-SetProperty $group "hooks" @($kept)
  }
}

function Install-Hooks {
  $data = Read-HooksFile

  foreach ($event in $Events) {
    $groups = Ensure-EventGroup $data.hooks $event
    Remove-OurHookFromGroups $groups

    $items = @($groups[0].hooks)
    $items += New-HookEntry
    Add-Or-SetProperty $groups[0] "hooks" @($items)
    Add-Or-SetProperty $data.hooks $event @($groups)
  }

  Save-HooksFile $data
  Write-Host "Installed: $HookCommand"
}

function Uninstall-Hooks {
  $data = Read-HooksFile

  foreach ($event in $Events) {
    if ($data.hooks.PSObject.Properties[$event]) {
      $groups = @($data.hooks.$event)
      Remove-OurHookFromGroups $groups
      Add-Or-SetProperty $data.hooks $event @($groups)
    }
  }

  Save-HooksFile $data
  Write-Host "Uninstalled: $HookCommand"
}

function Stop-BridgeProcess {
  if (!(Test-Path -LiteralPath $BridgeExe)) {
    return
  }

  $bridgePath = [IO.Path]::GetFullPath($BridgeExe)
  $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'ai-hook-bridge.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $_.ExecutablePath -and ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $bridgePath)
  })

  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
      Write-Host "Stopped bridge process: $($process.ProcessId)"
    } catch {
      Write-Host "WARNING: failed to stop bridge process $($process.ProcessId): $($_.Exception.Message)"
    }
  }
}

function Remove-RuntimeData {
  if (!(Test-Path -LiteralPath $DataDir)) {
    return
  }

  foreach ($pattern in $RuntimeDataPatterns) {
    $files = @(Get-ChildItem -LiteralPath $DataDir -Filter $pattern -File -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
      Remove-Item -LiteralPath $file.FullName -Force
      Write-Host "Removed: $($file.FullName)"
    }
  }
}

function Test-HookInstalled {
  param($Data, [string]$Event)

  if (!$Data.hooks.PSObject.Properties[$Event]) {
    return $false
  }

  foreach ($group in @($Data.hooks.$Event)) {
    foreach ($hook in @($group.hooks)) {
      if ($hook.command -ieq $HookCommand) {
        return $true
      }
    }
  }

  return $false
}

function Check-Setup {
  $errors = @()

  if (!(Test-Path -LiteralPath $HookCommand)) {
    $errors += "Missing hook command: $HookCommand"
  }

  if (!(Test-Path -LiteralPath $BridgeExe)) {
    $errors += "Missing bridge executable: $BridgeExe"
  } else {
    Write-Host "Bridge: $BridgeExe"
  }

  if (!(Test-Path -LiteralPath $HooksPath)) {
    $errors += "Missing Codex hooks file: $HooksPath"
  } else {
    $data = Read-HooksFile
    foreach ($event in $Events) {
      if (!(Test-HookInstalled $data $event)) {
        $errors += "Missing $event hook."
      }
    }
  }

  if ($errors.Count -gt 0) {
    foreach ($errorText in $errors) {
      Write-Host "ERROR: $errorText"
    }
    return $false
  }

  Write-Host "OK: Codex status hook is installed."
  return $true
}

function Start-Interactive {
  Write-Host "Codex status hook installer"
  Write-Host "Hooks file: $HooksPath"
  Write-Host "Hook command: $HookCommand"

  $choice = Read-Host "Choose action: [I]nstall/update, [C]heck, [U]ninstall hooks, uninstall [A]ll runtime, [Q]uit"
  switch -Regex ($choice) {
    "^[Aa]" {
      Stop-BridgeProcess
      Uninstall-Hooks
      Remove-RuntimeData
      return
    }
    "^[Uu]" { Uninstall-Hooks; return }
    "^[Cc]" {
      if (Check-Setup) { exit 0 } else { exit 1 }
    }
    "^[Qq]" { return }
    default { Install-Hooks; return }
  }
}

$modeCount = Count-Modes
if ($modeCount -eq 0) {
  $Check = $true
} elseif ($modeCount -gt 1) {
  Write-Host "ERROR: use only one mode: -Check, -Install, -Uninstall, or -Interactive."
  exit 1
}

if ($Interactive) {
  Start-Interactive
  exit 0
}

if ($Install) {
  Install-Hooks
  exit 0
}

if ($Uninstall) {
  if ($StopBridge) {
    Stop-BridgeProcess
  }
  Uninstall-Hooks
  if ($PurgeData) {
    Remove-RuntimeData
  }
  exit 0
}

if ($Check) {
  if (Check-Setup) { exit 0 } else { exit 1 }
}
