import os

path = r'C:\Users\Sudo\gautambhuwan.com.np\developments.html'
with open(path, 'r', encoding='utf-8', newline='') as f:
    content = f.read()

# 1. Schema
content = content.replace(
    '"downloadUrl": "https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v1.3.5-arm64.apk",',
    '"downloadUrl": "https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v1.3.6-arm64.apk",'
)
content = content.replace(
    '"softwareVersion": "1.3.5"',
    '"softwareVersion": "1.3.6"'
)

# 2. Metric card
content = content.replace(
    '<div class="dev-metric-val" style="color: #c084fc;">v1.3.5</div>',
    '<div class="dev-metric-val" style="color: #c084fc;">v1.3.6</div>'
)

# 3. Pill badge
content = content.replace(
    '<span class="status-dot" style="background: #a855f7;"></span> PRODUCTION RELEASE // v1.3.5 LATEST',
    '<span class="status-dot" style="background: #a855f7;"></span> PRODUCTION RELEASE // v1.3.6 LATEST'
)

# 4. Action buttons
content = content.replace(
    'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.5-arm64.apk',
    'https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.6-arm64.apk'
)
content = content.replace(
    'Download v1.3.5 APK (ARM64 • 19.1 MB)',
    'Download v1.3.6 APK (ARM64 • 19.2 MB)'
)
content = content.replace(
    'href="downloads/gamatube/GAMATUBE-v1.3.5-arm64.apk"',
    'href="downloads/gamatube/GAMATUBE-v1.3.6-arm64.apk"'
)
content = content.replace(
    'Direct Mirror APK (19.0 MB)',
    'Direct Mirror APK (19.2 MB)'
)

# 5. Table row
table_marker = '<tbody>\r\n                            <!-- v1.3.5 ARM64 -->'
new_row = '''<tbody>
              <!-- v1.3.6 ARM64 -->
              <tr style="border-bottom: 1px solid var(--border); background: rgba(255, 0, 0, 0.08);">
                <td style="padding: 18px 20px; vertical-align: top;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <strong style="color: var(--text-primary); font-size: 1rem;">v1.3.6</strong>
                    <span class="status-pill" style="font-size: 0.68rem; padding: 2px 6px; background: rgba(255, 255, 255, 0.1); color: var(--text-secondary);">STABLE • ARM64 • WEB</span>
                  </div>
                  <div style="color: var(--text-dim); font-size: 0.75rem; margin-top: 4px; font-family: var(--font-mono);">Recommended Multi-Platform Release</div>
                </td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top; white-space: nowrap;">October 2026</td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top;">
                  <strong>Zero-Friction Playback &amp; Autoplay Policy Breakthrough:</strong>
                  Resolved embedded playback deadlock where the loading overlay thumbnail intercepted touch gestures before reaching the WebView. Fixed IFrame origin conflict by removing mismatched cross-origin headers. Introduced proactive background audio playback triggers on <code>cued</code> and <code>unStarted</code> states. Streamlined continuous streaming across feed videos, background miniplayer, and vertical Shorts shelf. All 34/34 tests passing, verified live on Google Pixel 7 Pro hardware.
                </td>
                <td style="padding: 18px 20px; color: #10b981; font-family: var(--font-mono); font-size: 0.85rem; font-weight: 700; vertical-align: top; white-space: nowrap;">19.2 MB</td>
                <td style="padding: 18px 20px; text-align: right; vertical-align: top; white-space: nowrap;">
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.6-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    ARM64 APK
                  </a>
                </td>
              </tr>
              <!-- v1.3.5 ARM64 -->'''

content = content.replace(table_marker, new_row.replace('\n', '\r\n'))

with open(path, 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print('Updated developments.html!')
