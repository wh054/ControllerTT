# 生成各界面的截图，用于快速检查界面是否被改坏。
# 输出 shot_*.png 到项目根目录。
#
#   pwsh scripts/shots.ps1

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"

$godot = Get-GodotPath -Console
$root = Split-Path $PSScriptRoot -Parent

& $godot --path $root --resolution 1600x900 tools/shots.tscn
