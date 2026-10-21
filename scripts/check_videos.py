import os
import re

with open(r'lib/services/mock_video_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Extract all video definitions: id, title, channelTitle
pattern = re.compile(r"Video\s*\(\s*id:\s*['\"]([^'\"]+)['\"].*?title:\s*['\"]([^'\"]+)['\"]", re.DOTALL)
matches = pattern.findall(text)
print(f"Total videos in mock_video_service: {len(matches)}")
for vid, title in matches[:15]:
    print(f"{vid}: {title}")
