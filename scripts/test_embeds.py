import urllib.request
import urllib.error
import json
import re

with open(r'lib/api/youtube_v3_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

matches = re.findall(r"Video\s*\(\s*id:\s*['\"]([^'\"]+)['\"].*?title:\s*['\"]([^'\"]+)['\"]", text, re.DOTALL)
print(f"Total curated videos to test: {len(matches)}")

unembeddable = []
ok_videos = []

for vid, title in matches:
    url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={vid}&format=json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                ok_videos.append((vid, title.encode('ascii', 'ignore').decode('ascii')))
    except urllib.error.HTTPError as e:
        unembeddable.append((vid, e.code, title.encode('ascii', 'ignore').decode('ascii')))
    except Exception as e:
        unembeddable.append((vid, str(e), title.encode('ascii', 'ignore').decode('ascii')))

print(f"\nTested {len(matches)} videos.")
print(f"OK ({len(ok_videos)}):")
for v, t in ok_videos[:10]:
    print(f"  OK: {v} - {t[:50]}")

print(f"\nUnembeddable / Restrictive / Dead ({len(unembeddable)}):")
for v, code, t in unembeddable:
    print(f"  FAIL [{code}]: {v} - {t[:50]}")
