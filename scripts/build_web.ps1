# Build Script: Web PWA
$ErrorActionPreference = "Stop"

Write-Host "===> Building GAMATUBE for Web..." -ForegroundColor Cyan

$env:PATH = "C:\flutter\bin;" + $env:PATH

Write-Host "Running flutter analyze..."
flutter analyze

Write-Host "Running flutter test..."
flutter test

Write-Host "Building Web Release distribution..."
flutter build web --release

Write-Host "===> Web build completed successfully!" -ForegroundColor Green
Write-Host "Output: build\web\"
