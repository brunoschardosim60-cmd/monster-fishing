@echo off
cd /d "%~dp0"
set "MF_GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe"
"%MF_GODOT%" --path . --audio-driver Dummy --max-fps 60 --script res://tests/ocean_scenarios.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --path . --audio-driver Dummy --fixed-fps 60 --script res://tests/ocean_contract.gd
pause
