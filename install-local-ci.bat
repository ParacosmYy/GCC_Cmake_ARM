@echo off
setlocal

title STM32 Local CI Template Installer

echo =========================================
echo   STM32 Local CI Template Installer
echo =========================================
echo.
echo This launcher is intended for newcomers.
echo It will ask a few questions and then call install-local-ci.ps1.
echo.

set /p TARGET_PROJECT=Target STM32 project path: 
if not defined TARGET_PROJECT (
  echo.
  echo [error] Target project path is required.
  pause
  exit /b 1
)

set /p FORCE_CHOICE=Target project skeleton not ready yet? [y/N]: 
set "FORCE_ARG="
if /I "%FORCE_CHOICE%"=="Y" set "FORCE_ARG=-Force"
if /I "%FORCE_CHOICE%"=="YES" set "FORCE_ARG=-Force"

set "OPENOCD_TARGET=target/stm32h7x.cfg"
set /p OPENOCD_TARGET_INPUT=OpenOCD target cfg [target/stm32h7x.cfg]: 
if defined OPENOCD_TARGET_INPUT set "OPENOCD_TARGET=%OPENOCD_TARGET_INPUT%"

set "OPENOCD_INTERFACE=interface/cmsis-dap.cfg"
set /p OPENOCD_INTERFACE_INPUT=OpenOCD interface cfg [interface/cmsis-dap.cfg]: 
if defined OPENOCD_INTERFACE_INPUT set "OPENOCD_INTERFACE=%OPENOCD_INTERFACE_INPUT%"

echo.
echo [local-ci] Starting import...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-local-ci.ps1" ^
  -TargetProject "%TARGET_PROJECT%" ^
  -OpenOcdTargetCfg "%OPENOCD_TARGET%" ^
  -OpenOcdInterfaceCfg "%OPENOCD_INTERFACE%" ^
  %FORCE_ARG%

set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
  echo [error] Import failed with exit code %EXIT_CODE%.
  pause
  exit /b %EXIT_CODE%
)

echo [success] Import completed.
pause
exit /b 0
