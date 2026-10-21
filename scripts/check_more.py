import urllib.request
import json

candidates = [
    ("dcXpH3y1Aeg", "TypeScript in 100 Seconds", "Fireship"),
    ("rv3Yq-B8qp4", "Docker in 100 Seconds", "Fireship"),
    ("ifTF3ags0XI", "Git in 100 Seconds", "Fireship"),
    ("h6fcK_fRYaI", "The Last Human on Earth", "Kurzgesagt"),
    ("7Pq-S557XQU", "What if the Moon fell to Earth?", "Kurzgesagt"),
    ("4_aOIA-vyBo", "Loneliness", "Kurzgesagt"),
    ("082xauZX99o", "$456,000 Squid Game In Real Life!", "MrBeast"),
    ("zxYjTTXx-43", "$1 vs $1,000,000 Hotel Room!", "MrBeast"),
    ("C_3d6GteKKA", "Real Life Trick Shots | Dude Perfect", "Dude Perfect"),
    ("2zX5e7N03Tc", "Relaxing Campfire in the Woods", "Calm Nature"),
    ("5qap5aO4i9A", "lofi hip hop - beats to sleep/chill to", "Lofi Girl"),
    ("L_LUpnjgPso", "Fireplace Ambience 4K", "Relaxing"),
    ("Y4n0n9s7F18", "Python Full Course for Beginners", "Programming with Mosh"),
    ("rfscVS0vtbw", "Python Tutorial for Beginners [Full Course]", "Programming with Mosh"),
    ("kqtD5dpn9C8", "Python for Beginners - Full Course", "freeCodeCamp.org"),
    ("eIrMbAQSU34", "Java Tutorial for Beginners", "Programming with Mosh"),
    ("fBNz5xF-Kx4", "Node.js Tutorial for Beginners", "Programming with Mosh"),
    ("Oe421EPjeBE", "Node.js and Express.js - Full Course", "freeCodeCamp.org"),
    ("pQN-pnXPaVg", "HTML Full Course - Build a Website", "freeCodeCamp.org"),
    ("1Rs2ND1ryYc", "CSS Tutorial - Zero to Hero", "freeCodeCamp.org"),
    ("W6NZfCO5SIk", "JavaScript Tutorial for Beginners", "Programming with Mosh"),
    ("hdI2bqOjy3c", "JavaScript Crash Course For Beginners", "Traversy Media"),
    ("x7X9w_GIm1s", "Flutter Tutorial for Beginners", "The Net Ninja"),
    ("VPvVD8t02U8", "Flutter Course for Beginners - 37 Hours", "freeCodeCamp.org"),
]

verified = []
for vid, title, channel in candidates:
    url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={vid}&format=json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            d = json.loads(resp.read().decode('utf-8'))
            verified.append({"id": vid, "title": d.get("title", title), "channel": d.get("author_name", channel)})
            print(f"[OK] {vid} -> {d.get('title')[:45]}")
    except Exception as e:
        print(f"[FAIL] {vid} -> {e}")

print(f"Verified: {len(verified)}")
with open('scripts/more_verified.json', 'w', encoding='utf-8') as f:
    json.dump(verified, f, indent=2)
