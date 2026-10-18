Add-Type -AssemblyName System.Drawing

$srcPath = "c:\laragon\www\apotek\_backup_website\assets\images\apotek-logo.png"
if (!(Test-Path $srcPath)) {
    Write-Error "Source image not found: $srcPath"
    exit 1
}

$srcBmp = [System.Drawing.Bitmap]::FromFile($srcPath)
$baseDir = "c:\laragon\www\apotek\mobile"

# Copy original logo to mobile assets
$assetLogo = Join-Path $baseDir "assets\images\apotek-logo.png"
Copy-Item -Path $srcPath -Destination $assetLogo -Force

# Density map for legacy square/round icon (48, 72, 96, 144, 192)
# and adaptive foreground icon (108, 162, 216, 324, 432)
$densities = @(
    @{ Name = "mipmap-mdpi";    LegacySize = 48;  AdaptiveSize = 108 },
    @{ Name = "mipmap-hdpi";    LegacySize = 72;  AdaptiveSize = 162 },
    @{ Name = "mipmap-xhdpi";   LegacySize = 96;  AdaptiveSize = 216 },
    @{ Name = "mipmap-xxhdpi";  LegacySize = 144; AdaptiveSize = 324 },
    @{ Name = "mipmap-xxxhdpi"; LegacySize = 192; AdaptiveSize = 432 }
)

foreach ($d in $densities) {
    $dir = Join-Path $baseDir "android\app\src\main\res\$($d.Name)"
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # 1. Create Legacy ic_launcher.png (with white background + centered logo with 12% padding)
    $lSize = $d.LegacySize
    $legBmp = New-Object System.Drawing.Bitmap($lSize, $lSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($legBmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::White)

    $pad = [int]($lSize * 0.12)
    $drawW = $lSize - ($pad * 2)
    $drawH = $lSize - ($pad * 2)
    $g.DrawImage($srcBmp, $pad, $pad, $drawW, $drawH)
    $g.Dispose()

    $legPath = Join-Path $dir "ic_launcher.png"
    $legBmp.Save($legPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $legPathRound = Join-Path $dir "ic_launcher_round.png"
    $legBmp.Save($legPathRound, [System.Drawing.Imaging.ImageFormat]::Png)
    $legBmp.Dispose()

    # 2. Create Adaptive ic_launcher_foreground.png (108dp canvas, logo scaled to 58% safe zone centered on transparent canvas)
    $aSize = $d.AdaptiveSize
    $adBmp = New-Object System.Drawing.Bitmap($aSize, $aSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($adBmp)
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.Clear([System.Drawing.Color]::Transparent)

    $aLogoSize = [int]($aSize * 0.58)
    $aOffset = [int](($aSize - $aLogoSize) / 2)
    $g2.DrawImage($srcBmp, $aOffset, $aOffset, $aLogoSize, $aLogoSize)
    $g2.Dispose()

    $adPath = Join-Path $dir "ic_launcher_foreground.png"
    $adBmp.Save($adPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $adBmp.Dispose()

    Write-Host "Generated launcher icon for $($d.Name)"
}

$srcBmp.Dispose()
Write-Host "All launcher icons successfully generated with proper safe-zone padding!"
