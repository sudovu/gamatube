# Build Script: Windows Desktop
$ErrorActionPreference = "Stop"

Write-Host "===> Building GAMATUBE for Windows Desktop..." -ForegroundColor Cyan

$env:PATH = "C:\flutter\bin;" + $env:PATH

Write-Host "Running flutter analyze..."
flutter analyze

Write-Host "Running flutter test..."
flutter test

Write-Host "Building Windows Release executable..."
Write-Host "Note: Flutter Windows builds with plugins require Developer Mode enabled in Windows Settings." -ForegroundColor Yellow
flutter build windows --release

Write-Host "===> Windows build completed successfully!" -ForegroundColor Green
Write-Host "Output: build\windows\x64\runner\Release\"
