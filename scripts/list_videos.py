import re

with open(r'lib/api/youtube_v3_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Extract videos from _getCuratedFallbackVideos
matches = re.findall(r"Video\s*\(\s*id:\s*['\"]([^'\"]+)['\"].*?title:\s*['\"]([^'\"]+)['\"]", text, re.DOTALL)
print(f"Total curated videos: {len(matches)}")
for i, (vid, title) in enumerate(matches):
    print(f"{i+1:2d}. [{vid}] {title[:60]}")
