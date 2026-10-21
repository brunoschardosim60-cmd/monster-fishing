@echo off
cd /d "%~dp0"
set "MF_GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe"
"%MF_GODOT%" --headless --path . --script res://tests/fishing_test.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --path . --script res://tests/world_smoke.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --path . --script res://tests/integration_test.gd
if errorlevel 1 exit /b 1
echo Testes concluidos.
pause
