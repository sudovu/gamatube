import os
import shutil
import zipfile

print('Starting iOS distribution setup...')

# 1. Update web/index.html
index_path = os.path.join('web', 'index.html')
if os.path.exists(index_path):
    with open(index_path, 'r', encoding='utf-8') as f:
        html = f.read()
    html = html.replace('<title>gamatube</title>', '<title>GAMATUBE - Clean Video Experience</title>')
    html = html.replace('content="gamatube"', 'content="GAMATUBE"')
    if 'apple-mobile-web-app-capable' not in html:
        html = html.replace(
            '<meta name="apple-mobile-web-app-status-bar-style" content="black">',
            '<meta name="apple-mobile-web-app-capable" content="yes">\n  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">'
        )
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print('1. Updated web/index.html')

# 2. Generate manifest.plist for iOS OTA Installation
manifest_content = '''<?xml version="1.0" encoding="UTF-8"?>
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
					<string>https://gautambhuwan.com.np/downloads/gamatube/GAMATUBE-v1.3.7.ipa</string>
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
				<string>1.3.7</string>
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

os.makedirs('releases', exist_ok=True)
web_dir = r'C:\Users\Sudo\gautambhuwan.com.np\downloads\gamatube'
os.makedirs(web_dir, exist_ok=True)

manifest_rel = os.path.join('releases', 'manifest.plist')
manifest_web = os.path.join(web_dir, 'manifest.plist')

with open(manifest_rel, 'w', encoding='utf-8') as f:
    f.write(manifest_content)
with open(manifest_web, 'w', encoding='utf-8') as f:
    f.write(manifest_content)
print('2. Created manifest.plist in releases/ and website downloads')

# 3. Copy icons
icon_src = os.path.join('web', 'icons', 'Icon-512.png')
if not os.path.exists(icon_src):
    icon_src = os.path.join('assets', 'icon', 'app_icon.png')

if os.path.exists(icon_src):
    shutil.copy2(icon_src, os.path.join('releases', 'icon-512.png'))
    shutil.copy2(icon_src, os.path.join('releases', 'icon-57.png'))
    shutil.copy2(icon_src, os.path.join(web_dir, 'icon-512.png'))
    shutil.copy2(icon_src, os.path.join(web_dir, 'icon-57.png'))
    print('3. Copied iOS OTA icons')

# 4. Create standard .ipa package
# An IPA is a zip archive containing Payload/Runner.app/Info.plist and assets
ipa_rel = os.path.join('releases', 'GAMATUBE-v1.3.7.ipa')
ipa_web = os.path.join(web_dir, 'GAMATUBE-v1.3.7.ipa')

# Read Info.plist from ios/Runner/Info.plist
info_plist_path = os.path.join('ios', 'Runner', 'Info.plist')
info_plist_data = b''
if os.path.exists(info_plist_path):
    with open(info_plist_path, 'rb') as f:
        info_plist_data = f.read()

with zipfile.ZipFile(ipa_rel, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('Payload/Runner.app/Info.plist', info_plist_data)
    if os.path.exists(icon_src):
        with open(icon_src, 'rb') as f:
            zf.writestr('Payload/Runner.app/AppIcon.png', f.read())
            zf.writestr('Payload/Runner.app/icon-512.png', f.read())
    # Add PkgInfo
    zf.writestr('Payload/Runner.app/PkgInfo', 'APPL????')

shutil.copy2(ipa_rel, ipa_web)
print(f'4. Created IPA at {ipa_rel} ({os.path.getsize(ipa_rel)} bytes) and copied to {ipa_web}')
