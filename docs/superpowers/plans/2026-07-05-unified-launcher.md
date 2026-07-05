# Unified Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a root-level double-click launcher that checks Codex hook setup, installs when needed, and starts the serial bridge only after the user explicitly selects or confirms a COM port.

**Architecture:** Keep `bin` as the internal implementation directory and expose `start.cmd` as the user-facing entry point. The launcher calls the existing PowerShell installer for check/install/uninstall work, calls the Go bridge executable for port listing and bridge mode, and stores the selected serial port in `data\agent-hook-light.config.json`.

**Tech Stack:** Windows batch, PowerShell, existing Go bridge executable, existing installer script.

---

### Task 1: Root Launcher

**Files:**
- Create: `start.cmd`
- Modify: none
- Test: manual launcher commands plus existing installer test

- [ ] **Step 1: Create the launcher script**

Create `start.cmd` with these behaviors:

```bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=%~dp0"
for %%I in ("%ROOT_DIR%.") do set "ROOT_DIR=%%~fI"
set "BIN_DIR=%ROOT_DIR%\bin"
set "DATA_DIR=%ROOT_DIR%\data"
set "INSTALL_PS1=%BIN_DIR%\install.ps1"
set "BRIDGE_EXE=%BIN_DIR%\ai-hook-bridge.exe"
set "STATUS_FILE=%DATA_DIR%\codex-status.json"
set "CONFIG_FILE=%DATA_DIR%\agent-hook-light.config.json"

echo.
echo Agent Hook Light
echo ==================
echo.

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

if not exist "%INSTALL_PS1%" (
  echo ERROR: missing installer: %INSTALL_PS1%
  goto end_failed
)

if not exist "%BRIDGE_EXE%" (
  echo ERROR: missing bridge executable: %BRIDGE_EXE%
  goto end_failed
)

echo Checking Codex hook setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" -Check
if errorlevel 1 (
  echo.
  choice /C YN /N /M "Codex hook is not installed or incomplete. Install now? [Y/N] "
  if errorlevel 2 goto end_cancelled
  echo.
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" -Install
  if errorlevel 1 goto end_failed
  echo.
  echo Rechecking setup...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" -Check
  if errorlevel 1 goto end_failed
)

echo.
echo Codex hook setup is ready.
echo.
choice /C YN /N /M "Start serial bridge now? [Y/N] "
if errorlevel 2 goto end_cancelled

call :select_port
if errorlevel 1 goto end_failed

echo.
echo Starting bridge on %SELECTED_PORT%...
echo Press Ctrl+C to stop.
echo.
"%BRIDGE_EXE%" bridge -status "%STATUS_FILE%" -port "%SELECTED_PORT%"
goto end
```

- [ ] **Step 2: Add saved-port and manual selection helpers**

Append helper labels to `start.cmd`:

```bat
:select_port
set "SAVED_PORT="
if exist "%CONFIG_FILE%" (
  for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$path=$env:CONFIG_FILE; try { $cfg=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json; if ($cfg.saved_port) { $cfg.saved_port } } catch { }"`) do set "SAVED_PORT=%%P"
)

if defined SAVED_PORT (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ports = & $env:BRIDGE_EXE bridge -list-ports; if ($ports -contains $env:SAVED_PORT) { exit 0 } exit 1"
  if not errorlevel 1 (
    echo Saved serial port: %SAVED_PORT%
    choice /C YN /N /M "Use this port? [Y/N] "
    if errorlevel 2 goto choose_port
    set "SELECTED_PORT=%SAVED_PORT%"
    exit /b 0
  )
  echo Saved serial port is not available: %SAVED_PORT%
)

:choose_port
for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ports = & $env:BRIDGE_EXE bridge -list-ports | Where-Object { $_ -match '^COM[0-9]+$' }; if (!$ports) { exit 2 }; for ($i=0; $i -lt $ports.Count; $i++) { Write-Output ('[{0}] {1}' -f ($i + 1), $ports[$i]) }"`) do echo %%P
if errorlevel 2 (
  echo ERROR: no serial ports found. Connect the ESP32 device and try again.
  exit /b 1
)

set /p "PORT_CHOICE=Select ESP32 serial port number or COM name: "
if not defined PORT_CHOICE goto choose_port

for /f "usebackq delims=" %%P in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ports = & $env:BRIDGE_EXE bridge -list-ports | Where-Object { $_ -match '^COM[0-9]+$' }; $choice=$env:PORT_CHOICE.Trim(); $selected=$null; if ($choice -match '^[0-9]+$') { $index=[int]$choice - 1; if ($index -ge 0 -and $index -lt $ports.Count) { $selected=$ports[$index] } } elseif ($ports -contains $choice.ToUpperInvariant()) { $selected=$choice.ToUpperInvariant() }; if (!$selected) { exit 1 }; $dir=Split-Path -Parent $env:CONFIG_FILE; if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }; [pscustomobject]@{ saved_port=$selected } | ConvertTo-Json | Set-Content -LiteralPath $env:CONFIG_FILE -Encoding UTF8; Write-Output $selected"`) do set "SELECTED_PORT=%%P"
if not defined SELECTED_PORT (
  echo Invalid port selection.
  goto choose_port
)

echo Saved serial port: %SELECTED_PORT%
exit /b 0

:end_cancelled
echo Cancelled.
goto end

:end_failed
echo.
echo Agent Hook Light could not continue.
echo Check the messages above, then try again.

:end
echo.
pause
exit /b
```

- [ ] **Step 3: Run a syntax smoke check**

Run:

```powershell
cmd.exe /c start.cmd
```

Expected: The script opens, runs check, and either prompts for install or bridge start without batch syntax errors.

### Task 2: Retire Old Entrypoints

**Files:**
- Delete: `install.cmd`
- Delete: `check.cmd`
- Delete: `bin/start-bridge.cmd`
- Delete: `bin/build-bridge.cmd`
- Delete: `bin/ai-hook-bridge.exe~`

- [ ] **Step 1: Delete old user-facing wrapper scripts**

Remove the old wrappers because `start.cmd` now owns the beginner workflow.

- [ ] **Step 2: Keep internal runtime files**

Keep:

```text
bin\ai-hook-bridge.exe
bin\codex-hook.cmd
bin\install.ps1
```

### Task 3: Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Quick Start**

Replace the separate install/check/start commands with:

```powershell
.\start.cmd
```

Document that the launcher checks setup, installs missing Codex hook configuration after confirmation, asks the user to select a serial port, saves that port, and starts the bridge.

- [ ] **Step 2: Update Project Structure**

Document the new root launcher and remove retired command wrappers from the structure list.

### Task 4: Verification

**Files:**
- Test: `test\install.test.ps1`
- Test: `bridge\main_test.go`

- [ ] **Step 1: Run installer tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
```

Expected: exit code `0`.

- [ ] **Step 2: Run Go tests**

Run:

```powershell
cd bridge
go test ./...
```

Expected: all tests pass.

- [ ] **Step 3: Check git status**

Run:

```powershell
git status --short
```

Expected: new launcher and README changes are visible, retired wrappers are deleted, and pre-existing binary/go.mod dirtiness is not hidden.
