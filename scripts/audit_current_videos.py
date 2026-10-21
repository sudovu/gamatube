import re
import urllib.request
import json

with open(r'lib/api/youtube_v3_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_idx = text.find('_getCuratedFallbackVideos()')
end_idx = text.find('List<Video> _filterFallbackVideos')
sub = text[start_idx:end_idx]

vids = re.findall(r"id:\s*['\"]([^'\"]+)['\"]", sub)
unique_vids = list(dict.fromkeys(vids))
print(f"Total unique IDs in file: {len(unique_vids)}")

valid_map = {}
invalid_list = []

for v in unique_vids:
    url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={v}&format=json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            valid_map[v] = data.get('title')
    except Exception as e:
        invalid_list.append((v, str(e)))

print(f"Valid: {len(valid_map)}, Invalid: {len(invalid_list)}")
print("\nInvalid IDs:")
for v, err in invalid_list:
    print(f"  {v} -> {err}")

with open('scripts/invalid_videos.json', 'w') as f:
    json.dump([v for v, _ in invalid_list], f, indent=2)
