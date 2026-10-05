# GAMATUBE Deployment & Website Publication Protocol

## Core Directive
Whenever code is updated, refactored, or fixed in GAMATUBE:
1. **Version Tracking:** Keep track of semantic versions in `pubspec.yaml`, `CHANGELOG.md`, and release notes.
2. **Build Generation:** Build the release APK (`flutter build apk --release`).
3. **Commit & Push GAMATUBE:** Commit changes with an informative message and push to `https://github.com/sudovu/gamatube.git` (`origin main`).
4. **Publish to Website:**
   - Website repository path: `C:\Users\Sudo\gautambhuwan.com.np`
   - Live URL: `https://gautambhuwan.com.np/developments.html`
   - Copy binary artifacts to `downloads/gamatube/GAMATUBE-v<version>.apk` and `downloads/gamatube/GAMATUBE-latest.apk`.
   - Update `developments.html` and `data/developments.json` with the new version number, release date, and changelog highlights.
   - Commit and push website repository (`git push origin main` to `git@github.com:sudovu/gautambhuwan.com.np.git`).

## Automated Command
To execute this whole sequence with a single command, run:
```powershell
.\scripts\sync_to_website.ps1 -Version "1.0.0" -CommitMessage "feat: description of changes" -ReleaseNotes "Release notes"
```
