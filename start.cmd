@echo off
setlocal
chcp 65001 >nul

set "SCRIPT=%~dp0bin\agent-status-light.ps1"

if not exist "%SCRIPT%" (
  echo ERROR: missing launcher script: %SCRIPT%
  echo.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
  echo Agent Status Light exited with code %EXIT_CODE%.
)
pause
exit /b %EXIT_CODE%
