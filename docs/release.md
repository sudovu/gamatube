# Release & Distribution Guide

## Building Release Packages

### 1. Web Release
```bash
flutter build web --release
```
The output is written to `build/web/`. It can be hosted on GitHub Pages, Cloudflare Pages, Firebase Hosting, or any static HTTP server.

### 2. Android APK & App Bundle
```bash
flutter build apk --release
flutter build appbundle --release
```
Artifacts:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### 3. Windows Desktop
```bash
flutter build windows --release
```
The output executable and supporting binaries will reside in `build/windows/x64/runner/Release/`.

### 4. iOS / macOS (Requires macOS Host)
```bash
flutter build ipa --release
flutter build macos --release
```
Open `ios/Runner.xcworkspace` or `macos/Runner.xcworkspace` in Xcode to configure code signing certificates and distribution provisioning profiles.
