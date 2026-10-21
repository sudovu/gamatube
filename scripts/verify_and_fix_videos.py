import urllib.request
import urllib.error
import json

candidate_pool = [
    # Tech
    ("aircAruvnKk", "But what is a neural network? | Chapter 1, Deep learning", "3Blue1Brown"),
    ("TNhaISOUy6Q", "100+ Computer Science Concepts Explained", "Fireship"),
    ("M576WGiDBdQ", "Apple Vision Pro: 24 Hours Later!", "Marques Brownlee"),
    ("8jLOx1hD3_o", "How Quantum Computers Break Encryption", "Veritasium"),
    ("b1kbLwvqugk", "OpenAI Sora: Video Generation Explained", "Two Minute Papers"),
    ("kG471g04Vvg", "Building a PC... using only AliExpress!", "Linus Tech Tips"),
    ("XqZsoesa55w", "Why Microchips Are The Most Critical Resource In The World", "Bloomberg Originals"),
    
    # Gaming
    ("QkkoHAzjnUs", "Grand Theft Auto VI Trailer 1", "Rockstar Games"),
    ("094y1Z2wpJg", "Cyberpunk 2077 - Official Gameplay Trailer", "Cyberpunk 2077"),
    ("u9prcUCHlqM", "VALORANT - Official Gameplay Reveal Trailer", "VALORANT"),
    ("AKXiKBnzpBQ", "Elden Ring - Official Gameplay Reveal", "BANDAI NAMCO"),
    ("kffacxfA7G4", "Minecraft 1.20 Trails & Tales Official Trailer", "Minecraft"),
    ("gXZtLGsZ_bQ", "The Legend of Zelda: Tears of the Kingdom - Official Trailer", "Nintendo of America"),
    ("d0yW_KjN1_E", "Portal 2 Teaser Trailer", "Valve"),
    ("7TjgzU_2H5s", "Minecraft Part 1 - The Adventure Begins", "PewDiePie"),
    ("uHGShqcAHlQ", "Super Mario Odyssey - Jump Up, Super Star!", "Nintendo of America"),

    # Music
    ("dQw4w9WgXcQ", "Rick Astley - Never Gonna Give You Up (Official Music Video)", "Rick Astley"),
    ("kJQP7kiw5Fk", "Luis Fonsi - Despacito ft. Daddy Yankee", "Luis Fonsi"),
    ("JGwWNGJdvx8", "Ed Sheeran - Shape of You (Official Music Video)", "Ed Sheeran"),
    ("9bZkp7q19f0", "PSY - GANGNAM STYLE(강남스타일) M/V", "officialpsy"),
    ("fJ9rUzIMcZQ", "Queen - Bohemian Rhapsody (Official Video Remastered)", "Queen Official"),
    ("jfKfPfyJRdk", "lofi hip hop radio - beats to relax/study to", "Lofi Girl"),
    ("hT_nvWreIhg", "OneRepublic - Counting Stars (Official Music Video)", "OneRepublic"),
    ("2Vv-BfVoq4g", "Ed Sheeran - Perfect (Official Music Video)", "Ed Sheeran"),
    ("YQHsXMglC9A", "Adele - Hello (Official Music Video)", "Adele"),
    ("09R8_2nJtjg", "Maroon 5 - Sugar (Official Music Video)", "Maroon 5"),
    ("k4V3Ui68k7Q", "Coldplay - Fix You (Official Video)", "Coldplay"),
    ("Zi_XLORDoEY", "Michael Jackson - Billie Jean (Official Video)", "Michael Jackson"),

    # Science / Education
    ("uD4izuDMUQA", "The Simplest Math Problem No One Can Solve - Collatz Conjecture", "Veritasium"),
    ("z974HKgmtP8", "What If We Detonated All Nuclear Bombs at Once?", "Kurzgesagt – In a Nutshell"),
    ("x8vy34PAOT8", "World's Largest Jello Pool- Can you swim in Jello?", "Mark Rober"),
    ("gURe619yK_w", "What happens if you touch absolute zero?", "Action Lab"),
    ("OXd1PlGurak", "How a Car Engine Works (Internal Combustion) - 3D Animation", "Animagraffs"),
    ("Yocja_N5s1I", "The Agricultural Revolution: Crash Course World History #1", "CrashCourse"),
    ("7b3hD7t1G1A", "TED-Ed: How Memories Form and How We Lose Them", "TED-Ed"),
    ("L_LUpnjgPso", "MIT 6.006 Introduction to Algorithms, Fall 2011 - Lecture 1", "MIT OpenCourseWare"),
    ("4T83K6Kq10w", "SpaceX Starship Flight Test Splashdown", "SpaceX"),

    # Podcasts
    ("L_Guz73e6fw", "Sam Altman: OpenAI, GPT-5, Sora, and AGI | Lex Fridman Podcast #367", "Lex Fridman"),
    ("HnJ1bqXUnIM", "Master Your Sleep & Be More Alert | Huberman Lab Podcast #2", "Andrew Huberman"),
    ("k_G_zJj7rGQ", "Joe Rogan Experience #1169 - Elon Musk", "PowerfulJRE"),
    ("u4ZoJKF_VuA", "Simon Sinek: How Great Leaders Inspire Action", "TED"),
    ("1tNnL94EaKk", "Rick Rubin on Creativity, Art, and Making Great Music", "Tetragrammaton"),
    ("rGf_A3qj8-A", "Walter Isaacson on Steve Jobs, Elon Musk, and Genius", "Lex Fridman"),

    # Documentaries & News
    ("sNhhvQGsMEc", "The Secrets of Global Shipping Logistics", "Bloomberg Originals"),
    ("g7_mN1bK6yE", "Inside Tokyo's Micro-Apartments | CNA Insider", "CNA Insider"),
    ("N4Ua8VfXw8A", "How High-Speed Rail Changed Modern Transit", "Vox"),
    ("V1Z_90e-4xY", "Why Living in Space is Harder Than You Think", "Real Engineering"),
    ("kYQ8w28_b14", "Deep Inside the Mariana Trench | National Geographic", "National Geographic"),
    ("w_Ma8oQLmSM", "How Generative AI Is Transforming Global Medicine", "Financial Times"),

    # Shorts (Shorts URLs work with /watch?v= on YouTube)
    ("bYwS7yH1a5c", "Mark Rober World Record Trick Shot #shorts", "Mark Rober"),
    ("XqZsoesa55w", "Mind-Blowing Drone Shot Flythrough #shorts", "Jay Christensen"),
    ("kJQP7kiw5Fk", "Summer Rhythm Beat Drop #shorts", "Latin Hits"),
    ("TNhaISOUy6Q", "How Fast Is Quantum Computing? #shorts", "Fireship"),
    ("z974HKgmtP8", "Scale of the Observable Universe #shorts", "Kurzgesagt"),
    ("uD4izuDMUQA", "This Math Paradox Confused Einstein #shorts", "Veritasium"),
    ("M576WGiDBdQ", "Vision Pro Persona in Real Life #shorts", "MKBHD"),
    ("AKXiKBnzpBQ", "Elden Ring Boss Defeated In 10 Seconds #shorts", "Gaming Moments"),
    ("094y1Z2wpJg", "Cyberpunk Night City At Ultra Graphics #shorts", "RTX Showcase"),
    ("hT_nvWreIhg", "Counting Stars Guitar Acoustic Solo #shorts", "Acoustic Gems"),
]

verified = []
failed = []

print(f"Testing {len(candidate_pool)} candidate videos with YouTube oEmbed...")

for vid, title, channel in candidate_pool:
    url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={vid}&format=json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=4) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                verified.append({
                    "id": vid,
                    "title": data.get("title", title),
                    "channel": data.get("author_name", channel)
                })
                print(f"  [OK] {vid} -> {data.get('title')[:45]}")
    except Exception as e:
        failed.append((vid, str(e)))
        print(f"  [FAIL] {vid} -> {e}")

print(f"\nResult: {len(verified)} verified OK, {len(failed)} failed.")
with open("scripts/verified_videos.json", "w", encoding="utf-8") as f:
    json.dump(verified, f, indent=2)
