@echo off
cd /d "%~dp0"
set "MF_GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe"
"%MF_GODOT%" --path . --script res://tests/archipelago_visual.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --path . --script res://tests/visual_smoke.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --path . --script res://tests/living_visual.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --path . --script res://tests/world_art_visual.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --path . --script res://tests/render_benchmark.gd
if errorlevel 1 exit /b 1
echo Capturas e metricas em tests\output\archipelago e tests\output\visual.
pause
