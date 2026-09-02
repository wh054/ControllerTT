# 跑全部测试：core/ 的单元测试 + 整个游戏的集成冒烟测试。
# 两者都通过返回 0，否则返回 1。
#
#   powershell -File scripts\test.ps1

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"

$godot = Get-GodotPath -Console
$root = Split-Path $PSScriptRoot -Parent

& $godot --headless --path $root --script tests/run_tests.gd
$unit = $LASTEXITCODE

# 单元测试只覆盖纯函数，装配错误（信号没接、生命周期没清干净）要靠冒烟测试兜底。
& $godot --headless --path $root tools/smoke.tscn
$smoke = $LASTEXITCODE

if ($unit -ne 0 -or $smoke -ne 0) { exit 1 }
exit 0
