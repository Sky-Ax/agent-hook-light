@echo off
setlocal

set "BIN_DIR=%~dp0"
for %%I in ("%BIN_DIR%..") do set "ROOT_DIR=%%~fI"
set "DATA_DIR=%ROOT_DIR%\data"
set "BRIDGE_EXE=%BIN_DIR%ai-hook-bridge.exe"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

if not exist "%BRIDGE_EXE%" (
  echo %DATE% %TIME% bridge-not-found "%BRIDGE_EXE%" >> "%DATA_DIR%\codex-hook-wrapper.log"
  exit /b 1
)

echo %DATE% %TIME% hook-wrapper-start >> "%DATA_DIR%\codex-hook-wrapper.log"
"%BRIDGE_EXE%" hook
set "EXIT_CODE=%ERRORLEVEL%"
echo %DATE% %TIME% hook-wrapper-exit %EXIT_CODE% >> "%DATA_DIR%\codex-hook-wrapper.log"

exit /b %EXIT_CODE%
