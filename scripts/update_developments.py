import os

path = r'C:\Users\Sudo\gautambhuwan.com.np\developments.html'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace header/schema/metric/hero references
text = text.replace('GAMATUBE-v1.3.6-arm64.apk', 'GAMATUBE-v1.3.7-arm64.apk')
text = text.replace('"softwareVersion": "1.3.6"', '"softwareVersion": "1.3.7"')
text = text.replace('>v1.3.6</div>\n          <div class="dev-metric-label">GAMATUBE', '>v1.3.7</div>\n          <div class="dev-metric-label">GAMATUBE')
text = text.replace('>v1.3.6</div>\r\n          <div class="dev-metric-label">GAMATUBE', '>v1.3.7</div>\r\n          <div class="dev-metric-label">GAMATUBE')
text = text.replace('PRODUCTION RELEASE // v1.3.6 LATEST', 'PRODUCTION RELEASE // v1.3.7 LATEST')
text = text.replace('Download v1.3.6 APK', 'Download v1.3.7 APK')

v137_row = '''              <!-- v1.3.7 ARM64 -->
              <tr style="border-bottom: 1px solid var(--border); background: rgba(255, 0, 0, 0.08);">
                <td style="padding: 18px 20px; vertical-align: top;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <strong style="color: var(--text-primary); font-size: 1rem;">v1.3.7</strong>
                    <span class="status-pill" style="font-size: 0.68rem; padding: 2px 6px; background: rgba(255, 255, 255, 0.1); color: var(--text-secondary);">STABLE • ARM64 • WEB</span>
                  </div>
                  <div style="color: var(--text-dim); font-size: 0.75rem; margin-top: 4px; font-family: var(--font-mono);">Recommended Multi-Platform Release</div>
                </td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top; white-space: nowrap;">October 2026</td>
                <td style="padding: 18px 20px; color: var(--text-secondary); vertical-align: top;">
                  <strong>Verified Shorts-Only Isolation &amp; Dedicated Vertical Player:</strong>
                  Completely eliminated full-length videos from appearing in the Shorts player and Home feed carousel. Implemented strict duration boundaries (&le;60s) with genuine vertical content (Zach King, Habflex, DennisASMR, Lurking Facts, Triple Charm). Tapping any carousel short now seamlessly opens the dedicated vertical ShortsScreen with swipe controls and instant back navigation. All 34/34 tests passing, verified live on Google Pixel 7 Pro hardware.
                </td>
                <td style="padding: 18px 20px; color: #10b981; font-family: var(--font-mono); font-size: 0.85rem; font-weight: 700; vertical-align: top; white-space: nowrap;">19.2 MB</td>
                <td style="padding: 18px 20px; text-align: right; vertical-align: top; white-space: nowrap;">
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    APK
                  </a>
                </td>
              </tr>
'''

tbody_marker = '<tbody>\n'
if tbody_marker in text:
    text = text.replace(tbody_marker, tbody_marker + v137_row, 1)
else:
    tbody_marker = '<tbody>\r\n'
    text = text.replace(tbody_marker, tbody_marker + v137_row.replace('\n', '\r\n'), 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)

print('Updated developments.html to v1.3.7 successfully!')
