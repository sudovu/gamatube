# Build Script: Android APK & AAB
$ErrorActionPreference = "Stop"

Write-Host "===> Building GAMATUBE for Android..." -ForegroundColor Cyan

$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
$env:PATH = "C:\flutter\bin;" + $env:PATH

Write-Host "Running flutter analyze..."
flutter analyze

Write-Host "Running flutter test..."
flutter test

Write-Host "Building release APK..."
flutter build apk --release

Write-Host "Building release App Bundle (AAB)..."
flutter build appbundle --release

Write-Host "===> Android builds completed successfully!" -ForegroundColor Green
Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
