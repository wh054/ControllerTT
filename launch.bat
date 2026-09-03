@echo off
cd /d "%~dp0"
if exist "D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe" (
    start "" "D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0"
) else (
    start "" "%~dp0build\ControllerTT.exe"
)
