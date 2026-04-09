@echo off
setlocal

title STM32 Local CI Launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-local-ci-wizard.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
  echo.
  echo [local-ci] Failed to launch the wizard. Please review the window above.
  echo [local-ci] Exit code: %EXIT_CODE%
  pause
  exit /b %EXIT_CODE%
)
exit /b 0
