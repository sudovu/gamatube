<p align="center">
  <h1 align="center">GAMATUBE</h1>
  <p align="center"><em>Your Personal Clean Video Experience</em></p>
</p>

---

## 1. What is GAMATUBE?

**GAMATUBE** is a clean, modern, lightweight, privacy-conscious video platform client inspired by the usability and functionality of YouTube. 

GAMATUBE is engineered to deliver a focused, uncluttered video-watching experience **without advertising injected by GAMATUBE**, while operating in full compliance with official platform terms of service.

### Standalone Architectural Guarantees
GAMATUBE is a 100% standalone application. It strictly does **NOT** require:
- microG
- Modified Google Play Services
- Patched YouTube APKs
- Device Root / Magisk
- ReVanced or third-party binary patches
- Unofficial app hooks or modified system components

---

## 2. Core Features

- **Clean Video Discovery & Home Feed:** Beautiful, responsive feeds categorized by topics (Music, Gaming, Podcasts, Tech, News).
- **Smart "Continue Watching":** Tracks playback position down to the second, prompting you to resume seamlessly when reopening.
- **Fast Debounced Search:** Instant querying with local search history caching, suggestions, and relevance/date/views sort filters.
- **Privacy-First Playback Engine:** Official YouTube IFrame Player integration with play, pause, seek (+/- 10s), speed adjustment, captions, and responsive aspect scaling.
- **Local Collections & Offline Library:** Watch History, Watch Later queue, and custom user playlists persisted directly on device without requiring an account.
- **Google Account Sign-In (Optional):** "Continue with Google" via official OAuth 2.0 PKCE to sync channel subscriptions and account feeds.
- **Original Visual Identity:** Modern Material 3 aesthetic supporting Light, Dark (Slate), AMOLED Pure Black, and High Contrast themes.
- **Local AI Video Summaries:** Privacy-preserving extraction of video overviews, key takeaways, and action items.
- **Smart Caching:** Configurable LRU cache limits (100 MB, 250 MB, 500 MB, 1 GB) with TTL invalidation and instant cache purge.
- **First-Run Onboarding Wizard:** Intuitive step-by-step setup walkthrough for initial theme, account, and cache choices.

---

## 3. Technology Architecture

GAMATUBE is built with **Flutter & Dart**, utilizing clean layered architecture across all target platforms:

```
gamatube/
├── lib/
│   ├── api/           # VideoPlatformService, official YouTube v3, caching
│   ├── auth/          # Google OAuth PKCE service & session store
│   ├── core/          # Capabilities, error domain, logging, network monitoring
│   ├── home/          # Home feed, categories, continue watching
│   ├── models/        # Strongly typed data models (Video, Channel, Playlist)
│   ├── playback/      # Compliant video playback view & controls
│   ├── playlists/     # Local playlists, watch later, library view
│   ├── providers/     # Reactive state management (MultiProvider)
│   ├── repositories/  # Abstract persistence contracts & implementations
│   ├── search/        # Search screen with debouncing and history
│   ├── settings/      # Comprehensive user settings & setup wizard
│   ├── theme/         # Color palettes, typography, theme tokens
│   └── widgets/       # Responsive scaffold, video cards, logos
├── test/              # Comprehensive unit and widget tests
└── docs/              # In-depth architectural guides
```

---

## 4. Supported Platforms

| Platform | Status | Artifact |
| -------- | ------ | -------- |
| **Android** | Fully Supported | APK & Android App Bundle (AAB) |
| **Windows** | Fully Supported | Windows x64 Native Desktop Application |
| **Web** | Fully Supported | Responsive Single-Page Application (PWA) |
| **iOS / iPadOS**| Archive-Ready | Xcode Workspace ready for macOS compilation |
| **macOS** | Archive-Ready | Xcode macOS bundle |
| **Linux** | Archive-Ready | Linux GTK CMake build configuration |

---

## 5. Getting Started & Development

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.47+)
- Dart SDK (v3.13+)
- JDK 17 (for Android compilation)
- Visual Studio 2022+ with C++ desktop development (for Windows desktop)

### Installation
```bash
# Clone the repository
git clone https://github.com/sudovu/gamatube.git
cd gamatube

# Install dependencies
flutter pub get

# Verify static analysis & run test suite
flutter analyze
flutter test
```

### Running Locally
```bash
# Web
flutter run -d chrome  # or -d edge

# Windows Desktop
flutter run -d windows

# Android
flutter run -d android
```

---

## 6. Build Instructions

### Web Release
```bash
flutter build web --release
# Output: build/web/
```

### Android APK & App Bundle
```bash
flutter build apk --release
flutter build appbundle --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Windows Desktop
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### iOS & macOS Build
*(Requires macOS with Xcode installed)*
```bash
flutter build ipa --release
flutter build macos --release
```

---

## 7. Configuration & API Credentials

GAMATUBE is ready to use immediately out of the box with an offline-capable, curated catalog. To connect your personal Google Cloud quota:

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Set your optional Google Cloud API parameters:
   - `YOUTUBE_API_KEY`: Eliminates shared public quota constraints.
   - `GOOGLE_OAUTH_CLIENT_ID`: Enables Google Account subscription sync.

---

## 8. Legal Compliance & Platform Policy

GAMATUBE strictly observes legal and platform requirements:
- **No DRM Bypass:** Content is rendered using official, permitted playback mechanisms.
- **No Stream Scraping or Unauthorized Downloading:** Offline caching is limited to metadata and thumbnails. Stream piracy or unauthorized media saving is not supported.
- **Official Endpoints Only:** Integration relies on documented Google YouTube Data API endpoints.

---

## 9. Security & Privacy

- **Zero Hard-Coded Keys:** No client secrets, tokens, or credentials exist in Git.
- **Local-First Footprint:** Search history, watch history, and playlists stay on your device.
- **Opt-In Analytics:** Zero telemetry by default.
- See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md) for detailed policies.
