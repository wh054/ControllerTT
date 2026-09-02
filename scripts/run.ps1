# 启动训练器。
#
#   pwsh scripts/run.ps1            正常启动
#   pwsh scripts/run.ps1 -Editor    打开 Godot 编辑器

param([switch]$Editor)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"

$godot = Get-GodotPath
$root = Split-Path $PSScriptRoot -Parent

if ($Editor) {
    & $godot --editor --path $root
} else {
    & $godot --path $root
}
