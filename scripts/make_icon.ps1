# 生成应用图标 icon.png（Godot 项目图标）与 icon.ico（Windows 可执行文件图标）。
#
#   powershell -File scripts\make_icon.ps1
#
# 图标是脚本画出来的而不是塞一张二进制图进仓库，这样改配色时不用去找源文件。
# 只有换设计时才需要重跑，产物本身是提交进仓库的。
#
# 注意：本文件里一律用 [Type]::new(...) 构造对象。写成 New-Object Type(a, b - 1)
# 时 PowerShell 会先把括号里的内容当成数组，再去做减法，报出很难懂的 op_Subtraction 错误。

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$size = 256
$center = [float]($size / 2)

$bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# 圆角底板，配色取自界面主题 UITheme.PANEL。
$edge = $size - 1
$d = 104.0
$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$path.AddArc(0.0, 0.0, $d, $d, 180, 90)
$path.AddArc($edge - $d, 0.0, $d, $d, 270, 90)
$path.AddArc($edge - $d, $edge - $d, $d, $d, 0, 90)
$path.AddArc(0.0, $edge - $d, $d, $d, 90, 90)
$path.CloseFigure()
$g.FillPath([System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 26, 30, 38)), $path)

# 外圈代表摇杆行程边界，内圈代表死区——图标本身就点明了这个工具在调什么。
$gate = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 87, 194, 255), 9.0)
$g.DrawEllipse($gate, $center - 88, $center - 88, 176.0, 176.0)

$dead = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 255, 158, 77), 6.0)
$g.DrawEllipse($dead, $center - 30, $center - 30, 60.0, 60.0)

# 准星
$cross = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 232, 238, 248), 13.0)
$cross.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$cross.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
foreach ($dir in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
    $g.DrawLine($cross,
        [float]($center + $dir[0] * 44), [float]($center + $dir[1] * 44),
        [float]($center + $dir[0] * 74), [float]($center + $dir[1] * 74))
}

$dot = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 107, 240, 140))
$g.FillEllipse($dot, $center - 9, $center - 9, 18.0, 18.0)
$g.Dispose()

$pngPath = Join-Path $root "icon.png"
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
"icon.png  -> $pngPath"

# Windows 资源管理器和 Godot 的 exe 资源修改都要求 16/32/48/64/128/256 六档。
# 只塞一张 256 的 PNG 时，Godot 会警告缺尺寸，任务栏小图标也会糊成一团。
$sizes = @(16, 32, 48, 64, 128, 256)
$pngs = @()
foreach ($s in $sizes) {
    $scaled = [System.Drawing.Bitmap]::new($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $sg = [System.Drawing.Graphics]::FromImage($scaled)
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $sg.Clear([System.Drawing.Color]::Transparent)
    $sg.DrawImage($bmp, 0, 0, $s, $s)
    $sg.Dispose()
    $ms = [System.IO.MemoryStream]::new()
    $scaled.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,$ms.ToArray()
    $ms.Dispose()
    $scaled.Dispose()
}
$bmp.Dispose()

# Vista 之后的 ICO 允许每条目直接内嵌 PNG，不必再转 BMP。
$header = 6
$dirEntry = 16
$dirBytes = $header + $dirEntry * $sizes.Count
$ico = [System.IO.MemoryStream]::new()
$w = [System.IO.BinaryWriter]::new($ico)
$w.Write([uint16]0)
$w.Write([uint16]1)
$w.Write([uint16]$sizes.Count)
$offset = $dirBytes
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = $sizes[$i]
    $w.Write([byte]$(if ($dim -ge 256) { 0 } else { $dim }))
    $w.Write([byte]$(if ($dim -ge 256) { 0 } else { $dim }))
    $w.Write([byte]0)
    $w.Write([byte]0)
    $w.Write([uint16]1)
    $w.Write([uint16]32)
    $w.Write([uint32]$pngs[$i].Length)
    $w.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($png in $pngs) { $w.Write($png) }
$w.Flush()

$icoPath = Join-Path $root "icon.ico"
[System.IO.File]::WriteAllBytes($icoPath, $ico.ToArray())
$w.Dispose()
"icon.ico  -> $icoPath  （$($sizes -join '/')）"
