import re

with open(r'lib/api/youtube_v3_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_idx = text.find('_getCuratedFallbackVideos()')
end_idx = text.find('List<Video> _filterFallbackVideos')
sub = text[start_idx:end_idx]

# Find all section headers
headers = re.findall(r'// --- ([A-Z /&]+) ---', sub)
print("Sections found:", headers)

# Find each video's id, title, and which section it belongs to
for section in headers:
    tag = f"// --- {section} ---"
    s_idx = sub.find(tag)
    next_tags = [sub.find(f"// --- {h} ---") for h in headers if sub.find(f"// --- {h} ---") > s_idx]
    e_idx = min(next_tags) if next_tags else len(sub)
    sec_content = sub[s_idx:e_idx]
    vids = re.findall(r"id:\s*['\"]([^'\"]+)['\"]", sec_content)
    print(f"\n{section} ({len(vids)} videos):")
    for v in vids:
        print(f"  {v}")
