# GAMATUBE -> Website Deployment & Version Sync Script
# Target Website: https://gautambhuwan.com.np/ (Repository: C:\Users\Sudo\gautambhuwan.com.np)
param(
    [string]$Version = "",
    [string]$CommitMessage = "feat: update GAMATUBE code and release",
    [string]$ReleaseNotes = "Performance optimizations and feature updates."
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  GAMATUBE AUTOMATED RELEASE & WEBSITE PUBLISHING PIPELINE" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$RepoDir = "d:\MY GIT\Gama-tube"
$WebsiteDir = "C:\Users\Sudo\gautambhuwan.com.np"

# 1. Verification of paths
if (-not (Test-Path $WebsiteDir)) {
    Write-Error "Website directory not found at $WebsiteDir"
}

# 2. Run comprehensive synchronization and publication python script
Push-Location $RepoDir
python scripts\sync_all_releases_to_website.py
Pop-Location
