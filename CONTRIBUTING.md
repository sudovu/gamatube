# Contributing to GAMATUBE

Thank you for your interest in contributing to **GAMATUBE**! We welcome bug reports, feature suggestions, documentation updates, and pull requests.

---

## Code of Conduct & Legal Rules

1. **Strictly Official APIs Only:** Do not submit code that attempts to scrape private endpoints, bypass DRM, circumvent provider advertisements, or use reverse-engineered authentication.
2. **No Hard-Coded Secrets:** Never commit personal API keys, credentials, client secrets, or tokens.
3. **Stand-Alone Architecture:** GAMATUBE does not require microG, root, Magisk, or modified APKs. Contributions must preserve standalone operation.

---

## Development Setup

1. **Prerequisites:**
   - Flutter SDK `^3.47.0` (with Dart `^3.13.0`)
   - Android Studio / Android SDK (for Android development)
   - Visual Studio 2022+ C++ Tools (for Windows desktop development)
   - Chrome or Edge (for Web development)

2. **Clone and Install:**
   ```bash
   git clone https://github.com/sudovu/gamatube.git
   cd gamatube
   flutter pub get
   ```

3. **Run Code Verification:**
   ```bash
   flutter analyze
   flutter test
   ```

---

## Submitting Pull Requests

1. Create a feature branch: `git checkout -b feature/your-feature-name`.
2. Ensure static analysis and tests pass with 0 errors.
3. Keep commits atomic and descriptive.
4. Submit your pull request to the `main` branch.
