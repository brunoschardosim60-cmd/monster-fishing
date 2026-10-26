@echo off
cd /d "%~dp0"
set "MF_GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe"
"%MF_GODOT%" --headless --path . --script res://tests/fishing_test.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --path . --script res://tests/world_smoke.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/integration_test.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/docking_regression.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/water_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/ocean_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/archipelago_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/island_layout_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/locomotion_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/lighthouse_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/exploration_journey.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/living_world_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/expanded_routes.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/marine_world_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/harbor_renewal_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/flight_test.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/npc_look_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/fish_life_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/flora_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/seabed_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/fleet_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/town_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/island_life_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/searchlight_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/sea_life_contract.gd
if errorlevel 1 exit /b 1
"%MF_GODOT%" --headless --fixed-fps 60 --path . --script res://tests/upgrades_contract.gd
if errorlevel 1 exit /b 1
echo Testes concluidos.
pause
