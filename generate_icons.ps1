Add-Type -AssemblyName System.Drawing

function Create-PharmacyIcon([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $scale = $size / 512.0

    # 1. Background Squircle
    $radius = 110.0 * $scale
    $rect = New-Object System.Drawing.RectangleF (16.0 * $scale), (16.0 * $scale), (480.0 * $scale), (480.0 * $scale)
    
    $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $bgPath.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $bgPath.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $bgPath.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $bgPath.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $bgPath.CloseFigure()

    # Rich Emerald-Teal Gradient
    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF ($rect.X, $rect.Y)),
        (New-Object System.Drawing.PointF ($rect.Right, $rect.Bottom)),
        [System.Drawing.Color]::FromArgb(255, 0, 77, 64),      # Deep Teal #004D40
        [System.Drawing.Color]::FromArgb(255, 0, 137, 123)     # Vibrant Teal #00897B
    )
    $g.FillPath($gradBrush, $bgPath)
    $gradBrush.Dispose()

    # Inner Glow Border
    $innerPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 255, 255, 255), (3.0 * $scale))
    $g.DrawPath($innerPen, $bgPath)
    $innerPen.Dispose()

    # Ambient subtle light ring inside
    $ringRect = New-Object System.Drawing.RectangleF (50.0 * $scale), (50.0 * $scale), (412.0 * $scale), (412.0 * $scale)
    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(25, 255, 255, 255), (2.0 * $scale))
    $g.DrawEllipse($ringPen, $ringRect)
    $ringPen.Dispose()

    # 2. Modern Medical Cross (White with gentle rounded edges)
    # Cross specs: Width 240, Bar thickness 72, Corner radius 20
    $cx = 256.0 * $scale
    $cy = 246.0 * $scale
    $barLen = 220.0 * $scale
    $barThick = 68.0 * $scale
    $cr = 16.0 * $scale

    # Helper function to create rounded rect path
    function Get-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $dia = $r * 2
        $path.AddArc($x, $y, $dia, $dia, 180, 90)
        $path.AddArc($x + $w - $dia, $y, $dia, $dia, 270, 90)
        $path.AddArc($x + $w - $dia, $y + $h - $dia, $dia, $dia, 0, 90)
        $path.AddArc($x, $y + $h - $dia, $dia, $dia, 90, 90)
        $path.CloseFigure()
        return $path
    }

    # Soft Drop Shadow under Cross
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 0, 30, 25))
    $hShadow = Get-RoundedRectPath ($cx - $barLen / 2) ($cy - $barThick / 2 + (6.0 * $scale)) $barLen $barThick $cr
    $vShadow = Get-RoundedRectPath ($cx - $barThick / 2) ($cy - $barLen / 2 + (6.0 * $scale)) $barThick $barLen $cr
    $g.FillPath($shadowBrush, $hShadow)
    $g.FillPath($shadowBrush, $vShadow)
    $hShadow.Dispose()
    $vShadow.Dispose()
    $shadowBrush.Dispose()

    # White Pure Cross Bars
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $hBar = Get-RoundedRectPath ($cx - $barLen / 2) ($cy - $barThick / 2) $barLen $barThick $cr
    $vBar = Get-RoundedRectPath ($cx - $barThick / 2) ($cy - $barLen / 2) $barThick $barLen $cr
    $g.FillPath($whiteBrush, $hBar)
    $g.FillPath($whiteBrush, $vBar)
    $hBar.Dispose()
    $vBar.Dispose()
    $whiteBrush.Dispose()

    # 3. Vibrant Mint / Herbal Leaf Accent at upper-right corner of cross
    # Leaf path curving dynamically
    $leafPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $lx0 = ($cx + 36.0 * $scale)
    $ly0 = ($cy - 36.0 * $scale)
    $lx1 = ($cx + 124.0 * $scale)
    $ly1 = ($cy - 124.0 * $scale)
    
    # Elegant bezier leaf shape
    $leafPath.AddBezier($lx0, $ly0, ($cx + 40.0 * $scale), ($cy - 110.0 * $scale), ($cx + 90.0 * $scale), ($cy - 130.0 * $scale), $lx1, $ly1)
    $leafPath.AddBezier($lx1, $ly1, ($cx + 130.0 * $scale), ($cy - 75.0 * $scale), ($cx + 105.0 * $scale), ($cy - 35.0 * $scale), $lx0, $ly0)
    $leafPath.CloseFigure()

    # Leaf Gradient: Mint Green #00E676 to Teal #00BFA5
    $leafGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF $lx0, $ly0),
        (New-Object System.Drawing.PointF $lx1, $ly1),
        [System.Drawing.Color]::FromArgb(255, 0, 230, 118),   # #00E676
        [System.Drawing.Color]::FromArgb(255, 0, 191, 165)    # #00BFA5
    )
    $g.FillPath($leafGrad, $leafPath)
    $leafGrad.Dispose()

    # Leaf Central Vein (crisp white line)
    $veinPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 255, 255, 255), (3.0 * $scale))
    $veinPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $veinPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawBezier($veinPen, $lx0, $ly0, ($cx + 60.0 * $scale), ($cy - 65.0 * $scale), ($cx + 90.0 * $scale), ($cy - 95.0 * $scale), ($lx1 - 10.0 * $scale), ($ly1 + 10.0 * $scale))
    $veinPen.Dispose()
    $leafPath.Dispose()

    # 4. Subtle Capsule / Pill Dots in Lower Section (Refined Pharmacy Motif)
    $dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(160, 255, 255, 255))
    $g.FillEllipse($dotBrush, ($cx - 30.0 * $scale), (395.0 * $scale), (10.0 * $scale), (10.0 * $scale))
    $g.FillEllipse($dotBrush, ($cx - 5.0 * $scale), (393.0 * $scale), (12.0 * $scale), (12.0 * $scale))
    $g.FillEllipse($dotBrush, ($cx + 22.0 * $scale), (395.0 * $scale), (10.0 * $scale), (10.0 * $scale))
    $dotBrush.Dispose()

    $bgPath.Dispose()
    $g.Dispose()

    return $bmp
}

# Output locations
$baseDir = "c:\laragon\www\apotek\mobile"

# 1. 512x512 Asset Logo
$logo512 = Create-PharmacyIcon 512
$logoPath = Join-Path $baseDir "assets\images\apotek-logo.png"
$logo512.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)
$logo512.Dispose()
Write-Host "Generated: $logoPath (512x512)"

# 2. Android Launcher Mipmaps
$densities = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($entry in $densities.GetEnumerator()) {
    $folder = Join-Path $baseDir "android\app\src\main\res\$($entry.Key)"
    if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    
    $iconBmp = Create-PharmacyIcon $entry.Value
    $destSquare = Join-Path $folder "ic_launcher.png"
    $iconBmp.Save($destSquare, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Also save ic_launcher_round.png for Android round icon support
    $destRound = Join-Path $folder "ic_launcher_round.png"
    $iconBmp.Save($destRound, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $iconBmp.Dispose()
    Write-Host "Generated: $destSquare ($($entry.Value)x$($entry.Value))"
}

Write-Host "All icons generated successfully!"
