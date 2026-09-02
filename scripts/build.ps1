# 打包成可直接双击运行的单文件 exe，输出到 build\ControllerTT.exe。
#
#   powershell -File scripts\build.ps1          发行版（无控制台窗口）
#   powershell -File scripts\build.ps1 -Debug   调试版（附带控制台，能看到 print 与报错）
#   powershell -File scripts\build.ps1 -SkipTests
#
# 需要先装好与 Godot 同版本的导出模板，缺了会有明确提示。

param(
    [switch]$Debug,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\godot.ps1"

$godot = Get-GodotPath -Console
$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "build"
$outFile = Join-Path $outDir "ControllerTT.exe"

# 默认先跑测试再打包。打出一个手感数学是坏的包，比打包失败更糟：
# 它不会报错，只会让人觉得"这工具怎么怪怪的"。
if (-not $SkipTests) {
    Write-Host "== 打包前先跑测试 ==" -ForegroundColor Cyan
    & "$PSScriptRoot\test.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "测试未通过，已中止打包。要跳过请加 -SkipTests。" -ForegroundColor Red
        exit 1
    }
}

# 校验导出模板。Godot 在缺模板时的报错很不显眼，容易被当成别的问题。
$version = "4.7.2.stable"
$templateDir = Join-Path $env:APPDATA "Godot\export_templates\$version"
$templateFile = Join-Path $templateDir "windows_release_x86_64.exe"
if (-not (Test-Path $templateFile)) {
    Write-Host "找不到导出模板：$templateFile" -ForegroundColor Red
    Write-Host "请下载 Godot_v$version 的 export_templates.tpz，" -ForegroundColor Yellow
    Write-Host "解压后把 templates\ 里的内容放到 $templateDir\ 下。" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Remove-Item $outFile -ErrorAction SilentlyContinue

$mode = if ($Debug) { "--export-debug" } else { "--export-release" }
Write-Host "== 导出 $(if ($Debug) { '调试版' } else { '发行版' }) ==" -ForegroundColor Cyan
& $godot --headless --path $root $mode "Windows Desktop" $outFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outFile)) {
    Write-Host "导出失败。" -ForegroundColor Red
    exit 1
}

# 根目录再放一份硬链接，打开项目文件夹就能直接双击，不必钻进 build\。
# 硬链接不占第二份磁盘：删掉其中任意一个，另一个还在。
$rootExe = Join-Path $root "ControllerTT.exe"
if (Test-Path $rootExe) { Remove-Item $rootExe -Force }
New-Item -ItemType HardLink -Path $rootExe -Target $outFile | Out-Null

$icon = Join-Path $root "icon.ico"
if (-not (Test-Path $icon)) { $icon = $outFile }

# 快捷方式：项目里一份方便从资源管理器点，桌面一份方便日常开。
$projectLnk = Join-Path $root "启动 ControllerTT.lnk"
$desktop = [Environment]::GetFolderPath("Desktop")
$desktopLnk = Join-Path $desktop "ControllerTT.lnk"
foreach ($lnk in @($projectLnk, $desktopLnk)) {
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnk)
    $s.TargetPath = $outFile
    $s.WorkingDirectory = $outDir
    $s.IconLocation = "$icon,0"
    $s.Description = "ControllerTT 手柄摇杆训练器"
    $s.Save()
}

$mb = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
Write-Host ""
Write-Host "完成：$outFile （$mb MB）" -ForegroundColor Green
Write-Host "入口：$rootExe"
Write-Host "快捷方式：$projectLnk"
if (Test-Path $desktopLnk) {
    Write-Host "桌面：$desktopLnk"
}
Write-Host "双击即可运行，不需要另外安装 Godot。"
