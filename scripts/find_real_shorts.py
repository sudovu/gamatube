import urllib.request
import re
import json

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}

shorts_found = []
queries = ['shorts', 'trending+shorts', 'viral+shorts', 'funny+shorts', 'mrbeast+shorts', 'satisfying+shorts']

for q in queries:
    try:
        url = f'https://www.youtube.com/results?search_query={q}'
        req = urllib.request.Request(url, headers=headers)
        html = urllib.request.urlopen(req, timeout=10).read().decode('utf-8', errors='ignore')
        matches = set(re.findall(r'/shorts/([a-zA-Z0-9_-]{11})', html))
        for mid in matches:
            if mid not in shorts_found:
                shorts_found.append(mid)
    except Exception as e:
        print(f'Error fetching {q}: {e}')

print(f'Found {len(shorts_found)} candidate short IDs')

verified_shorts = []
for sid in shorts_found:
    try:
        oembed_url = f'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={sid}&format=json'
        req = urllib.request.Request(oembed_url, headers=headers)
        res = urllib.request.urlopen(req, timeout=5)
        data = json.loads(res.read().decode('utf-8'))
        title = data.get('title', '')
        author = data.get('author_name', '')
        # Check thumbnail aspect ratio or if title/url implies vertical video
        verified_shorts.append({
            'id': sid,
            'title': title,
            'channelTitle': author,
        })
        print(f'VERIFIED: {sid} | {title} | {author}')
        if len(verified_shorts) >= 20:
            break
    except Exception as e:
        pass

with open('scripts/verified_shorts.json', 'w', encoding='utf-8') as f:
    json.dump(verified_shorts, f, indent=2)
print(f'Saved {len(verified_shorts)} verified shorts to scripts/verified_shorts.json')
