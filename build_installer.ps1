# Script untuk Build Aplikasi & Membuat Windows Setup Installer (.exe)
$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " MEMULAI BUILD WINDOWS INSTALLER" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Build Flutter Windows Release
Write-Host ""
Write-Host "[1/3] Mem-build Flutter Windows (Release)..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Gagal mem-build aplikasi Windows Flutter!" -ForegroundColor Red
    exit 1
}

# 2. Cek Inno Setup Compiler (iscc.exe)
Write-Host ""
Write-Host "[2/3] Memeriksa Inno Setup Compiler..." -ForegroundColor Yellow
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$isccExe = $null
foreach ($path in $isccPaths) {
    if (Test-Path $path) {
        $isccExe = $path
        break
    }
}

if ($isccExe) {
    Write-Host "Inno Setup ditemukan di: $isccExe" -ForegroundColor Green
    Write-Host ""
    Write-Host "[3/3] Mengompilasi Setup Installer (.exe)..." -ForegroundColor Yellow
    
    if (-not (Test-Path "dist")) {
        New-Item -ItemType Directory -Path "dist" | Out-Null
    }

    & $isccExe "windows\inno_setup.iss"

    if (Test-Path "dist\ApoteKu_Setup_v1.0.0.exe") {
        Write-Host ""
        Write-Host "SETUP INSTALLER BERHASIL DIBUAT!" -ForegroundColor Green
        Write-Host "File Installer: dist\ApoteKu_Setup_v1.0.0.exe" -ForegroundColor Cyan

        # Buat ZIP siap kirim
        $zipOutput = "dist\ApoteKu_POS_Installer.zip"
        if (Test-Path $zipOutput) { Remove-Item $zipOutput -Force }
        Compress-Archive -Path "dist\ApoteKu_Setup_v1.0.0.exe" -DestinationPath $zipOutput
        Write-Host "File ZIP Siap Bagikan: $zipOutput" -ForegroundColor Green
    }
} else {
    Write-Host "Inno Setup belum terpasang otomatis." -ForegroundColor Yellow
    Write-Host "Silakan download dan instal Inno Setup dari: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Selesai!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
