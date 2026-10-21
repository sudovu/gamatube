import re

replacements = {
    'e_E9W2vsRbA': ('AKXiKBnzpBQ', 'ELDEN RING Official Launch Trailer', 'BANDAI NAMCO Europe'),
    'd1_JBMrrYw8': ('kffacxfA7G4', 'Justin Bieber - Baby ft. Ludacris', 'Justin Bieber'),
    'b005i19Q7i8': ('M576WGiDBdQ', 'Solidity, Blockchain, and Smart Contract Course', 'freeCodeCamp.org'),
    'ER3jW1U5V8w': ('TNhaISOUy6Q', '10 React Hooks Explained // Plus Build your own', 'Fireship'),
    'h3Mn1eP3zC8': ('4_aOIA-vyBo', 'Three Ways to Destroy the Universe', 'Kurzgesagt – In a Nutshell'),
    '4p0Mv3N_t-8': ('L_Guz73e6fw', 'Sam Altman: OpenAI CEO on GPT-4, ChatGPT, and AGI', 'Lex Fridman'),
    '1tNnL94EaKk': ('HnJ1bqXUnIM', 'What is Critical Thinking? | Huberman Lab', 'Andrew Huberman'),
    'KxgU3vF3fvg': ('8jLOx1hD3_o', 'C++ Programming Course - Beginner to Advanced', 'freeCodeCamp.org'),
    'xMv4UuU7H0U': ('rv3Yq-B8qp4', 'Svelte in 100 Seconds', 'Fireship'),
    'w_Ma8oQLmSM': ('x7X9w_GIm1s', 'Python in 100 Seconds', 'Fireship'),
    '_8V7_W9lqC8': ('sNhhvQGsMEc', 'The Fermi Paradox — Where Are All The Aliens?', 'Kurzgesagt – In a Nutshell'),
    'aZ_mPqC5f1Y': ('h6fcK_fRYaI', 'The Egg - A Short Story', 'Kurzgesagt – In a Nutshell'),
    'N4Ua8VfXw8A': ('7Pq-S557XQU', 'What Happened to Horses Is Happening to Us', 'Kurzgesagt – In a Nutshell'),
    '4Tnk4e861d8': ('rfscVS0vtbw', 'Learn Python - Full Course for Beginners [Tutorial]', 'Programming with Mosh'),
    'k4V3Ui68k7Q': ('hT_nvWreIhg', 'OneRepublic - Counting Stars (Official Music Video)', 'OneRepublic'),
    'OPf0YbXq864': ('2Vv-BfVoq4g', 'Ed Sheeran - Perfect (Official Music Video)', 'Ed Sheeran'),
    'Zi_XLORDoEY': ('5qap5aO4i9A', 'lofi hip hop radio - beats to relax/study to', 'Lofi Girl'),
    'olEGtoYs_hg': ('QkkoHAzjnUs', 'Grand Theft Auto V Trailer', 'Rockstar Games'),
    'oP3f9_Gj5l0': ('094y1Z2wpJg', 'Cyberpunk 2077 - Official Gameplay Trailer', 'Cyberpunk 2077'),
    'tax4gWst28o': ('u9prcUCHlqM', 'Photography Tutorial: Essential Photo Skills', 'Peter McKinnon'),
    'e97b39Y4K4A': ('uHGShqcAHlQ', 'The Legend of Zelda: Tears of the Kingdom – Official Trailer', 'Nintendo of America'),
    '921VbEMAwwY': ('uD4izuDMUQA', 'TIMELAPSE OF THE FUTURE: A Journey to the End of Time', 'melodysheep'),
    'bC_X4rQ14m4': ('L_LUpnjgPso', 'Fireplace Ambience – Cozy Fire for Relaxation', 'Fireplace Ambience'),
    'W6BfV6k_3c4': ('kqtD5dpn9C8', 'Python for Beginners - Learn Coding with Python', 'Programming with Mosh'),
    'fTauz_r9L_U': ('pQN-pnXPaVg', 'HTML Full Course - Build a Website Tutorial', 'freeCodeCamp.org'),
    'jW-uVnZ7tq0': ('eIrMbAQSU34', 'Java Full Course for Beginners', 'Programming with Mosh'),
    'xS3f8Gj1eE0': ('fBNz5xF-Kx4', 'Node.js Crash Course', 'Traversy Media'),
    'pC3_93q1eE4': ('1Rs2ND1ryYc', 'CSS Tutorial - Zero to Hero (Complete Course)', 'freeCodeCamp.org'),
    'g7_mN1bK6yE': ('W6NZfCO5SIk', 'JavaScript Course for Beginners – Your First Web App', 'Programming with Mosh'),
    'NLKQERkatR8': ('hdI2bqOjy3c', 'JavaScript Crash Course For Beginners', 'Traversy Media'),
    'yOgAbKJGrPE': ('Oe421EPjeBE', 'Node.js and Express.js - Full Course', 'freeCodeCamp.org'),
    '2v8W1V2E7nQ': ('XqZsoesa55w', 'Baby Shark Dance | Most Viewed Video #shorts', 'Pinkfong Baby Shark'),
    '8y09Kx1qEwA': ('rv3Yq-B8qp4', 'Svelte in 100 Seconds #shorts', 'Fireship'),
    'k7n4V3x9P1I': ('x7X9w_GIm1s', 'Python in 100 Seconds #shorts', 'Fireship'),
    '5bY8W_1j9rM': ('TNhaISOUy6Q', '10 React Hooks Explained in 100s #shorts', 'Fireship'),
    '1q2W3e4R5tY': ('dQw4w9WgXcQ', 'Never Gonna Give You Up #shorts', 'Rick Astley'),
    '9a8b7c6d5eF': ('kJQP7kiw5Fk', 'Despacito Rhythm Beats #shorts', 'Latin Hits'),
    '3z4y5x6w7vU': ('JGwWNGJdvx8', 'Shape of You Acoustic Loop #shorts', 'Ed Sheeran'),
    '7q8w9e0r1tY': ('hT_nvWreIhg', 'Counting Stars Live Chorus #shorts', 'OneRepublic'),
    'uI_9q8w7e6r': ('fJ9rUzIMcZQ', 'Bohemian Rhapsody Operatic Section #shorts', 'Queen Official'),
    '5v6b7n8m9aK': ('2Vv-BfVoq4g', 'Ed Sheeran Perfect Solo #shorts', 'Ed Sheeran'),
}

# 1. Update youtube_v3_service.dart
with open(r'lib/api/youtube_v3_service.dart', 'r', encoding='utf-8') as f:
    code = f.read()

for old_id, (new_id, new_title, new_ch) in replacements.items():
    code = code.replace(f"'{old_id}'", f"'{new_id}'")
    code = code.replace(f'"{old_id}"', f'"{new_id}"')
    code = code.replace(f"/{old_id}/", f"/{new_id}/")

with open(r'lib/api/youtube_v3_service.dart', 'w', encoding='utf-8') as f:
    code = f.write(code)

print("Updated lib/api/youtube_v3_service.dart successfully.")

# 2. Update library_provider.dart
with open(r'lib/providers/library_provider.dart', 'r', encoding='utf-8') as f:
    lib_code = f.read()

for old_id, (new_id, new_title, new_ch) in replacements.items():
    lib_code = lib_code.replace(f"'{old_id}'", f"'{new_id}'")
    lib_code = lib_code.replace(f'"{old_id}"', f'"{new_id}"')
    lib_code = lib_code.replace(f"/{old_id}/", f"/{new_id}/")

with open(r'lib/providers/library_provider.dart', 'w', encoding='utf-8') as f:
    lib_code = f.write(lib_code)

print("Updated lib/providers/library_provider.dart successfully.")
