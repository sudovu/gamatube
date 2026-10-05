# GAMATUBE -> Website Deployment & Version Sync Script
# Target Website: https://gautambhuwan.com.np/ (Repository: C:\Users\Sudo\gautambhuwan.com.np)
param(
    [string]$Version = "1.0.0",
    [string]$CommitMessage = "feat: update GAMATUBE code and release",
    [string]$ReleaseNotes = "Performance optimizations and feature updates."
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  GAMATUBE AUTOMATED RELEASE & WEBSITE PUBLISHING PIPELINE" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$RepoDir = "d:\MY GIT\Gama-tube"
$WebsiteDir = "C:\Users\Sudo\gautambhuwan.com.np"
$ApkSource = "$RepoDir\build\app\outputs\flutter-apk\app-release.apk"
$TargetDir = "$WebsiteDir\downloads\gamatube"

# 1. Verification of paths
if (-not (Test-Path $WebsiteDir)) {
    Write-Error "Website directory not found at $WebsiteDir"
}

# 2. Check if build artifact exists
if (-not (Test-Path $ApkSource)) {
    Write-Host "Release APK not found. Building APK now..." -ForegroundColor Yellow
    $env:PATH = "C:\flutter\bin;" + $env:PATH
    Push-Location $RepoDir
    flutter build apk --release
    Pop-Location
}

# 3. Commit and push GAMATUBE repository
Write-Host "`n[Step 1/4] Committing and pushing GAMATUBE repository..." -ForegroundColor Green
Push-Location $RepoDir
git add .
$status = git status --porcelain
if ($status) {
    git commit -m "$CommitMessage (v$Version)"
}
git push origin main
Pop-Location

# 4. Copy binary artifacts to website
Write-Host "`n[Step 2/4] Syncing binary artifacts to website..." -ForegroundColor Green
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}
Copy-Item $ApkSource "$TargetDir\GAMATUBE-v$Version.apk" -Force
Copy-Item $ApkSource "$TargetDir\GAMATUBE-latest.apk" -Force
Write-Host "Copied GAMATUBE-v$Version.apk and GAMATUBE-latest.apk to $TargetDir" -ForegroundColor Cyan

# 5. Commit and push Website repository
Write-Host "`n[Step 3/4] Committing and pushing to website repository (gautambhuwan.com.np)..." -ForegroundColor Green
Push-Location $WebsiteDir
git add data/developments.json developments.html downloads/gamatube/
$webStatus = git status --porcelain
if ($webStatus) {
    git commit -m "feat(developments): publish GAMATUBE v$Version ($ReleaseNotes)"
    git push origin main
    Write-Host "Website repository successfully updated and pushed!" -ForegroundColor Green
} else {
    Write-Host "No changes detected in website repository." -ForegroundColor Yellow
}
Pop-Location

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  GAMATUBE v$Version PUBLISHED SUCCESSFULLY TO WEBSITE! " -ForegroundColor Green
Write-Host "  Live URL: https://gautambhuwan.com.np/developments.html" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
