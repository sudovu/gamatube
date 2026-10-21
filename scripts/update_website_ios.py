import os

path = r'C:\Users\Sudo\gautambhuwan.com.np\developments.html'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Target the hero download buttons block
target_apk_btn = '''          <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7-arm64.apk" class="btn btn-primary" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000; font-weight: 700; padding: 12px 24px;" download>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -3px; margin-right: 6px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
            Download v1.3.7 APK (ARM64 • 19.2 MB)
          </a>'''

if target_apk_btn.replace('\n', '\r\n') in text:
    target_apk_btn = target_apk_btn.replace('\n', '\r\n')
    is_crlf = True
else:
    is_crlf = False

replacement_btns = '''          <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7-arm64.apk" class="btn btn-primary" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000; font-weight: 700; padding: 12px 22px;" download>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -3px; margin-right: 6px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
            Download APK (Android • 19.2 MB)
          </a>
          <!-- iOS Direct OTA Install -->
          <a href="itms-services://?action=download-manifest&url=https://gautambhuwan.com.np/downloads/gamatube/manifest.plist" class="btn btn-primary" style="background: linear-gradient(135deg, #007aff, #0051ba); border-color: #007aff; font-weight: 700; padding: 12px 22px;">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: -2px; margin-right: 6px;"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 1.01-2.87-.96.04-2.12.64-2.79 1.43-.59.68-1.1 1.76-.96 2.8.07.01.14.01.21.01 1.02 0 1.91-.62 2.53-1.37z"/></svg>
            Install on iOS (Direct OTA)
          </a>
          <!-- iOS Direct IPA Download -->
          <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7.ipa" class="btn btn-secondary" style="border-color: rgba(0, 122, 255, 0.4); color: #60a5fa; font-weight: 600; padding: 12px 20px;" download>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 5px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
            Download iOS .IPA (Sideload)
          </a>'''

if is_crlf:
    replacement_btns = replacement_btns.replace('\n', '\r\n')

if target_apk_btn in text:
    text = text.replace(target_apk_btn, replacement_btns, 1)
    print('Replaced hero buttons!')
else:
    print('target_apk_btn not matched directly, searching partial...')
    idx = text.find('Download v1.3.7 APK')
    if idx != -1:
        # find enclosing <a> tag
        a_start = text.rfind('<a href=', 0, idx)
        a_end = text.find('</a>', idx) + 4
        text = text[:a_start] + replacement_btns + text[a_end:]
        print('Replaced via index!')

# Add iOS installation guide card right below hero action group if not already present
if 'Direct iOS Installation Methods:' not in text:
    guide_card = '''        <!-- iOS Direct Installation Methods Card -->
        <div style="margin-top: 24px; padding: 18px 22px; background: rgba(0, 122, 255, 0.08); border: 1px solid rgba(0, 122, 255, 0.25); border-radius: 12px; text-align: left;">
          <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="#60a5fa"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 1.01-2.87-.96.04-2.12.64-2.79 1.43-.59.68-1.1 1.76-.96 2.8.07.01.14.01.21.01 1.02 0 1.91-.62 2.53-1.37z"/></svg>
            <strong style="color: #93c5fd; font-size: 1.05rem;">Direct iOS Installation Options:</strong>
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; font-size: 0.86rem; color: var(--text-secondary); line-height: 1.55;">
            <div style="background: rgba(0,0,0,0.3); padding: 14px 16px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.06);">
              <span style="color: #60a5fa; font-weight: 700; font-size: 0.92rem;">1. Instant Safari Web App (Recommended)</span><br>
              Open <a href="https://gautambhuwan.com.np/gamatube/" target="_blank" style="color: #ff8585; font-weight: 600; text-decoration: underline;">GAMATUBE Web</a> in iOS Safari, tap the <strong>Share</strong> icon, and select <strong>"Add to Home Screen"</strong>. Launches full-screen natively with offline caching, zero certificate expirations, and no computer needed!
            </div>
            <div style="background: rgba(0,0,0,0.3); padding: 14px 16px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.06);">
              <span style="color: #60a5fa; font-weight: 700; font-size: 0.92rem;">2. One-Tap Over-The-Air (OTA)</span><br>
              Tap the <strong>"Install on iOS (Direct OTA)"</strong> button above in Safari. iOS will automatically prompt to install GAMATUBE wirelessly directly onto your device via Apple itms-services.
            </div>
            <div style="background: rgba(0,0,0,0.3); padding: 14px 16px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.06);">
              <span style="color: #60a5fa; font-weight: 700; font-size: 0.92rem;">3. Direct .IPA Sideloading</span><br>
              Download the <strong>.IPA package</strong> and install it using <a href="https://altstore.io" target="_blank" style="color: #93c5fd; text-decoration: underline;">AltStore</a>, <a href="https://sideloadly.io" target="_blank" style="color: #93c5fd; text-decoration: underline;">Sideloadly</a>, <a href="https://usescarlet.com" target="_blank" style="color: #93c5fd; text-decoration: underline;">Scarlet</a>, TrollStore, or Esign with your Apple ID.
            </div>
          </div>
        </div>
'''
    if is_crlf:
        guide_card = guide_card.replace('\n', '\r\n')
    
    # insert after the hero button group (look for </div> after the buttons)
    ref_idx = text.find('GitHub (@sudovu/gamatube)')
    if ref_idx != -1:
        div_end = text.find('</div>', ref_idx) + 6
        text = text[:div_end] + (b'\r\n'.decode() if is_crlf else '\n') + guide_card + text[div_end:]
        print('Added iOS installation guide card!')

# Also update the releases table status pill and action column for v1.3.7
text = text.replace('STABLE • ARM64 • WEB</span>', 'STABLE • ARM64 • IOS • WEB</span>')

# Update table row binary button for v1.3.7 to include IPA
table_target = '''<a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    APK
                  </a>'''

table_replacement = '''<a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7-arm64.apk" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #e50914, #ff0000); border-color: #ff0000; margin-right: 4px;" download>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="vertical-align: -2px; margin-right: 3px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    APK
                  </a>
                  <a href="itms-services://?action=download-manifest&url=https://gautambhuwan.com.np/downloads/gamatube/manifest.plist" class="btn btn-primary btn-sm" style="background: linear-gradient(135deg, #007aff, #0051ba); border-color: #007aff; margin-right: 4px;">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: -2px; margin-right: 3px;"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 1.01-2.87-.96.04-2.12.64-2.79 1.43-.59.68-1.1 1.76-.96 2.8.07.01.14.01.21.01 1.02 0 1.91-.62 2.53-1.37z"/></svg>
                    iOS OTA
                  </a>
                  <a href="https://github.com/sudovu/gamatube/raw/main/releases/GAMATUBE-v1.3.7.ipa" class="btn btn-secondary btn-sm" style="border-color: rgba(0, 122, 255, 0.4); color: #60a5fa;" download>
                    IPA
                  </a>'''

if is_crlf:
    table_target = table_target.replace('\n', '\r\n')
    table_replacement = table_replacement.replace('\n', '\r\n')

if table_target in text:
    text = text.replace(table_target, table_replacement, 1)
    print('Updated table row binary buttons!')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)

print('Updated developments.html for iOS!')
