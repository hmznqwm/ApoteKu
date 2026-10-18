$ErrorActionPreference = "Stop"

$downloadsDir = "$env:USERPROFILE\Downloads"
$isccExe = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccExe)) {
    $isccExe = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $isccExe)) {
    $isccExe = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " APOTEKU POS - BUILD ANDROID DAN WINDOWS INSTALLER" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Compile Inno Setup Installer if Windows release is built
if (Test-Path "build\windows\x64\runner\Release\apotek_app.exe") {
    Write-Host ""
    Write-Host "[1/2] Mengompilasi Windows Setup Installer (.exe)..." -ForegroundColor Yellow
    if (Test-Path $isccExe) {
        & $isccExe "installer.iss"
        Write-Host "SUKSES: Windows Installer berhasil dibuat di: $downloadsDir\ApoteKu_Windows_Setup_v1.0.0.exe" -ForegroundColor Green
    } else {
        Write-Host "ERROR: ISCC.exe tidak ditemukan." -ForegroundColor Red
    }
}

# 2. Build Android Release APK (Lightweight split-per-abi)
Write-Host ""
Write-Host "[2/2] Mem-build Android APK Ringan (split-per-abi)..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi

# Copy ARM64-v8a (Lightweight for modern smartphones)
$arm64Apk = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
$armeabiApk = "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk"

if (Test-Path $arm64Apk) {
    Copy-Item $arm64Apk -Destination "$downloadsDir\ApoteKu_Android_ARM64_v1.0.0.apk" -Force
    $arm64Item = Get-Item "$downloadsDir\ApoteKu_Android_ARM64_v1.0.0.apk"
    $sizeMb = [math]::Round($arm64Item.Length / 1MB, 2)
    Write-Host "SUKSES: Android APK Ringan (ARM64) berhasil disimpan di:" -ForegroundColor Green
    Write-Host "$downloadsDir\ApoteKu_Android_ARM64_v1.0.0.apk (Ukuran: $sizeMb MB)" -ForegroundColor Cyan
}

if (Test-Path $armeabiApk) {
    Copy-Item $armeabiApk -Destination "$downloadsDir\ApoteKu_Android_ARMv7_v1.0.0.apk" -Force
    $armv7Item = Get-Item "$downloadsDir\ApoteKu_Android_ARMv7_v1.0.0.apk"
    $sizeMb7 = [math]::Round($armv7Item.Length / 1MB, 2)
    Write-Host "SUKSES: Android APK (ARMv7) berhasil disimpan di:" -ForegroundColor Green
    Write-Host "$downloadsDir\ApoteKu_Android_ARMv7_v1.0.0.apk (Ukuran: $sizeMb7 MB)" -ForegroundColor Cyan
}

# Build Universal APK
Write-Host ""
Write-Host "Mem-build Android APK Universal..." -ForegroundColor Yellow
flutter build apk --release

$universalApk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $universalApk) {
    Copy-Item $universalApk -Destination "$downloadsDir\ApoteKu_Android_Universal_v1.0.0.apk" -Force
    $univItem = Get-Item "$downloadsDir\ApoteKu_Android_Universal_v1.0.0.apk"
    $sizeMbUniv = [math]::Round($univItem.Length / 1MB, 2)
    Write-Host "SUKSES: Android APK Universal berhasil disimpan di:" -ForegroundColor Green
    Write-Host "$downloadsDir\ApoteKu_Android_Universal_v1.0.0.apk (Ukuran: $sizeMbUniv MB)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " SEMUA FILE TELAH BERHASIL DIBUAT DI FOLDER DOWNLOADS!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
