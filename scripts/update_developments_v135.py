path = r'C:\Users\Sudo\gautambhuwan.com.np\developments.html'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update Schema JSON-LD
content = content.replace(
    '"https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v1.3.4-arm64.apk"',
    '"https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v1.3.5-arm64.apk"'
)
content = content.replace(
    '"softwareVersion": "1.3.4"',
    '"softwareVersion": "1.3.5"'
)

# Update metric card
content = content.replace(
    '<div class="dev-metric-val" style="color: #c084fc;">v1.3.4</div>',
    '<div class="dev-metric-val" style="color: #c084fc;">v1.3.5</div>'
)

# Update hero badge
content = content.replace(
    'PRODUCTION RELEASE // v1.3.4 LATEST',
    'PRODUCTION RELEASE // v1.3.5 LATEST'
)

# Update hero buttons
content = content.replace(
    'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.4-arm64.apk',
    'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.5-arm64.apk'
)
content = content.replace(
    'Download v1.3.4 APK (ARM64 • 19.0 MB)',
    'Download v1.3.5 APK (ARM64 • 19.1 MB)'
)
content = content.replace(
    'href="downloads/gamatube/GAMATUBE-v1.3.4-arm64.apk"',
    'href="downloads/gamatube/GAMATUBE-v1.3.5-arm64.apk"'
)

# Insert v1.3.5 table row right above v1.3.4
v135_row = '''              <!-- v1.3.5 ARM64 -->
              <tr style="border-bottom: 1px solid var(--border); background: rgba(255, 0, 0, 0.08);">
                <td style="padding: 18px 20px; vertical-align: top;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <strong style="color: var(--text-primary); font-size: 1rem;">v1.3.5</strong>
                    <span class="status-pill" style="font-size: 0.68rem; padding: 2px 6px; background: rgba(255, 255, 255, 0.1); color: var(--text-secondary);">STABLE • ARM64 • WEB</span>
                  </div>
                  <div style="color: var(--text-dim); font-size: 0.75rem; margin-top: 4px; font-family: var(--font-mono);">Recommended Multi-Platform Release</div>
                </td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top; white-space: nowrap;">October 2026</td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top;">
                  <strong>100% Playable Video Catalog, Interactive Playback Restriction Fallback &amp; Redesigned Ultra-Premium 3D App Icon:</strong>
                  Resolved unplayable video errors by auditing and replacing 41 invalid/404 catalog IDs with 100% verified, live, embeddable YouTube videos across all feeds (Music, Gaming, Tech, Science, Education, Podcasts, Documentaries, Shorts). Configured <code>origin: 'https://www.youtube.com'</code> and <code>playsInline</code> in the IFrame player to eliminate domain embedding blocks. Added an in-player error recovery panel with one-touch external playback on YouTube, next-video auto-skip, and quick reload. Redesigned the entire app launcher icon adhering to the Android Adaptive Icon standard (108dp canvas, 66dp safe zone) featuring a sculpted 3D ruby-crimson play crest, top glass specular sheen, diamond starlight gamma flare, and deep luxury obsidian background. 34/34 tests passing, 0 analyzer issues, deployed to connected Pixel device.
                </td>
                <td style="padding: 18px 20px; color: #10b981; font-family: var(--font-mono); font-size: 0.85rem; font-weight: 700; vertical-align: top; white-space: nowrap;">19.1 MB</td>
                <td style="padding: 18px 20px; text-align: right; vertical-align: top; white-space: nowrap;">
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.5-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    ARM64 APK
                  </a>
                </td>
              </tr>
'''

target_tag = '              <!-- v1.3.4 ARM64 -->'
if target_tag in content:
    content = content.replace(target_tag, v135_row + target_tag)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Updated developments.html to v1.3.5 successfully')
else:
    print('Target tag v1.3.4 not found!')
