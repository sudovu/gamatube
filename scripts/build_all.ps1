# Master Multi-Platform Build Script
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    GAMATUBE MASTER BUILD PIPELINE       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$env:PATH = "C:\flutter\bin;" + $env:PATH
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"

Write-Host "[1/4] Running Code Formatting & Analysis..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "[2/4] Executing Automated Test Suite..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "[3/4] Building Web Application..." -ForegroundColor Yellow
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "[4/4] Building Android APK..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "==========================================" -ForegroundColor Green
Write-Host "    ALL TARGET BUILDS FINISHED!          " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
