# 定位 Godot 可执行文件。按 环境变量 → 常见安装位置 → PATH 的顺序查找。
# 其他脚本 dot-source 本文件后调用 Get-GodotPath。

function Get-GodotPath {
    param([switch]$Console)

    $candidates = @()
    if ($env:GODOT) { $candidates += $env:GODOT }
    $candidates += @(
        "D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe",
        "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe"
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) {
            if ($Console) {
                # 控制台版会把 print 输出到 stdout，跑测试时必须用它。
                $consoleExe = $c -replace '\.exe$', '_console.exe'
                if (Test-Path $consoleExe) { return $consoleExe }
            }
            return $c
        }
    }

    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    throw "找不到 Godot。请设置环境变量 GODOT 指向 Godot 4.7+ 的可执行文件。"
}
