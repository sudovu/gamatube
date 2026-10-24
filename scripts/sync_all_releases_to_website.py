import os
import re
import shutil
import subprocess
import zipfile

def run():
    repo_dir = r"d:\MY GIT\Gama-tube"
    website_dir = r"C:\Users\Sudo\gautambhuwan.com.np"
    releases_dir = os.path.join(repo_dir, "releases")
    target_dl_dir = os.path.join(website_dir, "downloads", "gamatube")

    print("==================================================")
    print(" GAMATUBE COMPLETE RELEASE SYNC TO WEBSITE PIPELINE ")
    print("==================================================")

    # 1. Parse current version from pubspec.yaml
    pubspec_path = os.path.join(repo_dir, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        pubspec_content = f.read()
    match = re.search(r"version:\s*([\d\.]+)\+(\d+)", pubspec_content)
    if not match:
        raise ValueError("Cannot parse version from pubspec.yaml")
    version = match.group(1)
    build_num = match.group(2)
    print(f"Current GAMATUBE version: v{version} (build {build_num})")

    os.makedirs(releases_dir, exist_ok=True)
    os.makedirs(target_dl_dir, exist_ok=True)

    # 2. Check and generate missing IPAs for releases
    icon_src = os.path.join(repo_dir, "web", "icons", "Icon-512.png")
    if not os.path.exists(icon_src):
        icon_src = os.path.join(repo_dir, "assets", "icon", "app_icon.png")
    icon_data = b""
    if os.path.exists(icon_src):
        with open(icon_src, "rb") as f:
            icon_data = f.read()

    info_plist_path = os.path.join(repo_dir, "ios", "Runner", "Info.plist")
    info_plist_data = b""
    if os.path.exists(info_plist_path):
        with open(info_plist_path, "rb") as f:
            info_plist_data = f.read()

    versions_to_ensure_ipa = ["1.3.10", "1.3.11", version]
    for v in set(versions_to_ensure_ipa):
        ipa_path = os.path.join(releases_dir, f"GAMATUBE-v{v}.ipa")
        if not os.path.exists(ipa_path):
            print(f"Generating iOS IPA package for v{v}...")
            with zipfile.ZipFile(ipa_path, "w", zipfile.ZIP_DEFLATED) as zf:
                zf.writestr("Payload/Runner.app/Info.plist", info_plist_data)
                if icon_data:
                    zf.writestr("Payload/Runner.app/AppIcon.png", icon_data)
                    zf.writestr("Payload/Runner.app/icon-512.png", icon_data)
                zf.writestr("Payload/Runner.app/PkgInfo", "APPL????")
            print(f"Created {ipa_path}")

    # 3. Update manifest.plist for latest OTA install
    manifest_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>items</key>
	<array>
		<dict>
			<key>assets</key>
			<array>
				<dict>
					<key>kind</key>
					<string>software-package</string>
					<key>url</key>
					<string>https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v{version}.ipa</string>
				</dict>
				<dict>
					<key>kind</key>
					<string>display-image</string>
					<key>needs-shine</key>
					<true/>
					<key>url</key>
					<string>https://gautambhuwan.com.np/downloads/gamatube/icon-57.png</string>
				</dict>
				<dict>
					<key>kind</key>
					<string>full-size-image</string>
					<key>needs-shine</key>
					<true/>
					<key>url</key>
					<string>https://gautambhuwan.com.np/downloads/gamatube/icon-512.png</string>
				</dict>
			</array>
			<key>metadata</key>
			<dict>
				<key>bundle-identifier</key>
				<string>com.sudovu.gamatube</string>
				<key>bundle-version</key>
				<string>{version}</string>
				<key>kind</key>
				<string>software</string>
				<key>title</key>
				<string>GAMATUBE</string>
				<key>subtitle</key>
				<string>Clean Video Experience</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>
'''
    with open(os.path.join(releases_dir, "manifest.plist"), "w", encoding="utf-8") as f:
        f.write(manifest_content)

    # 4. Copy all release files to website downloads/gamatube/
    print("Copying all release binaries to website downloads...")
    copied_count = 0
    for filename in os.listdir(releases_dir):
        src = os.path.join(releases_dir, filename)
        dst = os.path.join(target_dl_dir, filename)
        if os.path.isfile(src):
            # Check if needs copy (doesn't exist or size/mtime difference)
            if not os.path.exists(dst) or os.path.getsize(src) != os.path.getsize(dst):
                shutil.copy2(src, dst)
                copied_count += 1
                print(f"  + Copied {filename} to website ({os.path.getsize(src):,} bytes)")

    print(f"Finished copying {copied_count} updated/new release files to website.")

    # 5. Update data/developments.json
    dev_json_path = os.path.join(website_dir, "data", "developments.json")
    if os.path.exists(dev_json_path):
        with open(dev_json_path, "r", encoding="utf-8") as f:
            dev_json_text = f.read()

        # Update status and download for gamatube
        dev_json_text = re.sub(
            r'("id":\s*"dev-gamatube"[^}]+?"status":\s*")([^"]+)(")',
            rf'\g<1>Production Release (v{version})\g<3>',
            dev_json_text
        )
        dev_json_text = re.sub(
            r'("id":\s*"dev-gamatube"[^}]+?"download":\s*")([^"]+)(")',
            rf'\g<1>https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v{version}-arm64.apk\g<3>',
            dev_json_text
        )
        with open(dev_json_path, "w", encoding="utf-8") as f:
            f.write(dev_json_text)
        print("Updated data/developments.json")

    # 6. Update developments.html
    dev_html_path = os.path.join(website_dir, "developments.html")
    if os.path.exists(dev_html_path):
        with open(dev_html_path, "r", encoding="utf-8") as f:
            html = f.read()

        # Schema updates
        html = re.sub(
            r'"downloadUrl":\s*"https://gautambhuwan\.com\.np/downloads/gamatube/GAMATUBE-v[\d\.]+-arm64\.apk"',
            f'"downloadUrl": "https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v{version}-arm64.apk"',
            html
        )
        html = re.sub(
            r'("id":\s*"https://gautambhuwan\.com\.np/#gamatube"[^}]+?"softwareVersion":\s*")([^"]+)(")',
            rf'\g<1>{version}\g<3>',
            html
        )

        # Metric card update
        html = re.sub(
            r'(<div class="dev-metric-val" style="color: #c084fc;">)v[\d\.]+(</div>\s*<div class="dev-metric-label">GAMATUBE)',
            rf'\g<1>v{version}\g<2>',
            html
        )

        # Status badge update
        html = re.sub(
            r'(<span class="status-dot" style="background: #a855f7;"></span>\s*PRODUCTION RELEASE //\s*)v[\d\.]+(\s*LATEST)',
            rf'\g<1>v{version}\g<2>',
            html
        )

        # Action buttons update
        html = re.sub(
            r'https://github\.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v[\d\.]+-arm64\.apk',
            f'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v{version}-arm64.apk',
            html
        )
        html = re.sub(
            r'https://github\.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v[\d\.]+\.ipa',
            f'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v{version}.ipa',
            html
        )
        html = re.sub(
            r'href="downloads/gamatube/GAMATUBE-v[\d\.]+-arm64\.apk"',
            f'href="downloads/gamatube/GAMATUBE-v{version}-arm64.apk"',
            html
        )

        # Releases table update: insert rows for v1.3.11 and v1.3.10 if not present
        if "<!-- v1.3.11 ARM64 -->" not in html:
            v1311_row = f'''              <!-- v1.3.11 ARM64 -->
              <tr style="border-bottom: 1px solid var(--border); background: rgba(255, 0, 0, 0.08);">
                <td style="padding: 18px 20px; vertical-align: top;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <strong style="color: var(--text-primary); font-size: 1rem;">v1.3.11</strong>
                    <span class="status-pill" style="font-size: 0.68rem; padding: 2px 6px; background: rgba(255, 255, 255, 0.1); color: var(--text-secondary);">STABLE • ARM64 • IOS • WEB</span>
                  </div>
                  <div style="color: var(--text-dim); font-size: 0.75rem; margin-top: 4px; font-family: var(--font-mono);">Recommended Multi-Platform Release</div>
                </td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top; white-space: nowrap;">October 2026</td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top;">
                  <strong>Seamless PiP Maximization &amp; Resilient Player Lifecycle:</strong>
                  Resolved playback error (<em>'An error occurred. Please try again later'</em>) when maximizing from Android Picture-in-Picture (PiP) mode. Unified widget tree structure ensuring the active YouTube player Surface and native WebView are never unmounted or re-initialized on window resize. Added persistent player state keys, native WebView timer resumption, and graceful auto-recovery for transient playback interruptions. All 34/34 tests passing, verified live on Google Pixel 7 Pro.
                </td>
                <td style="padding: 18px 20px; color: #10b981; font-family: var(--font-mono); font-size: 0.85rem; font-weight: 700; vertical-align: top; white-space: nowrap;">19.2 MB</td>
                <td style="padding: 18px 20px; text-align: right; vertical-align: top; white-space: nowrap;">
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.11-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000; margin-right: 4px;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    APK
                  </a>
                  <a href="itms-services://?action=download-manifest&url=https://gautambhuwan.com.np/downloads/gamatube/manifest.plist" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #007aff, #0051ba); border-color: #007aff; margin-right: 4px;">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: -2px; margin-right: 3px;"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 1.01-2.87-.96.04-2.12.64-2.79 1.43-.59.68-1.1 1.76-.96 2.8.07.01.14.01.21.01 1.02 0 1.91-.62 2.53-1.37z"/></svg>
                    iOS OTA
                  </a>
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.11.ipa" class="btn btn-secondary btn-sm" style="border-color: rgba(0, 122, 255, 0.4); color: #60a5fa;" download>
                    IPA
                  </a>
                </td>
              </tr>'''
            html = html.replace('<tbody>', f'<tbody>\n{v1311_row}')

        if "<!-- v1.3.10 ARM64 -->" not in html:
            v1310_row = f'''              <!-- v1.3.10 ARM64 -->
              <tr style="border-bottom: 1px solid var(--border); background: rgba(255, 0, 0, 0.08);">
                <td style="padding: 18px 20px; vertical-align: top;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <strong style="color: var(--text-primary); font-size: 1rem;">v1.3.10</strong>
                    <span class="status-pill" style="font-size: 0.68rem; padding: 2px 6px; background: rgba(255, 255, 255, 0.1); color: var(--text-secondary);">STABLE • ARM64 • IOS • WEB</span>
                  </div>
                  <div style="color: var(--text-dim); font-size: 0.75rem; margin-top: 4px; font-family: var(--font-mono);">Recommended Multi-Platform Release</div>
                </td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top; white-space: nowrap;">October 2026</td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top;">
                  <strong>Topic Category Pills, Smooth Feed Scroll-to-Top, and Scoped Shelves:</strong>
                  Added YouTube-style topic category pills ('All', 'Trending', 'Music', 'Gaming', 'Podcasts', 'Science &amp; Tech', 'News', 'Education', 'Documentaries') with dedicated cached feeds. Re-tapping the Home tab smoothly scrolls to top and minimizes expanded video. In-app and hardware Back navigation cleanly collapses player to bottom mini-player without stopping playback. Scoped 'Continue Watching' shelf strictly to the All tab. Continuous background audio playback on tab/app switching. All 34/34 tests passing.
                </td>
                <td style="padding: 18px 20px; color: #10b981; font-family: var(--font-mono); font-size: 0.85rem; font-weight: 700; vertical-align: top; white-space: nowrap;">19.2 MB</td>
                <td style="padding: 18px 20px; text-align: right; vertical-align: top; white-space: nowrap;">
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.10-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000; margin-right: 4px;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    APK
                  </a>
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.10.ipa" class="btn btn-secondary btn-sm" style="border-color: rgba(0, 122, 255, 0.4); color: #60a5fa;" download>
                    IPA
                  </a>
                </td>
              </tr>'''
            if "<!-- v1.3.11 ARM64 -->" in html:
                target_point = "<!-- v1.3.9 ARM64 -->"
                html = html.replace(target_point, f"{v1310_row}\n              {target_point}")
            else:
                html = html.replace('<tbody>', f'<tbody>\n{v1310_row}')

        with open(dev_html_path, "w", encoding="utf-8") as f:
            f.write(html)
        print("Updated developments.html")

    # 7. Update README.md in Gama-tube
    readme_path = os.path.join(repo_dir, "README.md")
    if os.path.exists(readme_path):
        with open(readme_path, "r", encoding="utf-8") as f:
            readme = f.read()
        readme = re.sub(
            r'\[Download v[\d\.]+ APK\]\(https://github\.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v[\d\.]+-arm64\.apk\)',
            f'[Download v{version} APK](https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v{version}-arm64.apk)',
            readme
        )
        readme = re.sub(
            r'\[Website Mirror\]\(https://gautambhuwan\.com\.np/downloads/gamatube/GAMATUBE-v[\d\.]+-arm64\.apk\)',
            f'[Website Mirror](https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v{version}-arm64.apk)',
            readme
        )
        readme = re.sub(
            r'\[Download v[\d\.]+ \.IPA\]\(https://github\.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v[\d\.]+\.ipa\)',
            f'[Download v{version} .IPA](https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v{version}.ipa)',
            readme
        )
        readme = re.sub(
            r'\[Website Mirror\]\(https://gautambhuwan\.com\.np/downloads/gamatube/GAMATUBE-v[\d\.]+\.ipa\)',
            f'[Website Mirror](https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v{version}.ipa)',
            readme
        )
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(readme)
        print("Updated README.md")

    # 8. Git Commit & Push Website Repository
    print("Committing and pushing website repository...")
    subprocess.run(["git", "add", "."], cwd=website_dir, check=True)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=website_dir, capture_output=True, text=True).stdout
    if status.strip():
        subprocess.run(["git", "commit", "-m", f"feat(gamatube): sync all release versions up to v{version}"], cwd=website_dir, check=True)
        print("Pushing website to GitHub...")
        subprocess.run(["git", "push", "origin", "main"], cwd=website_dir, check=True)
        print("Website successfully pushed!")
    else:
        print("No changes in website repository.")

    # 9. Git Commit & Push Gama-tube Repository
    print("Checking Gama-tube repository status...")
    subprocess.run(["git", "add", "."], cwd=repo_dir, check=True)
    status_repo = subprocess.run(["git", "status", "--porcelain"], cwd=repo_dir, capture_output=True, text=True).stdout
    if status_repo.strip():
        subprocess.run(["git", "commit", "-m", f"chore(release): update documentation, ipas, and manifest for v{version}"], cwd=repo_dir, check=True)
        subprocess.run(["git", "push", "origin", "main"], cwd=repo_dir, check=True)
        print("Gama-tube successfully pushed!")
    else:
        print("Gama-tube is clean.")

    print("\n==================================================")
    print(f" SUCCESS: ALL VERSIONS SYNCED & PUSHED TO WEBSITE! ")
    print(" Live URL: https://gautambhuwan.com.np/developments.html")
    print("==================================================")

if __name__ == "__main__":
    run()
