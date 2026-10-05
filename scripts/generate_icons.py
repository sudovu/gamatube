import math
from PIL import Image, ImageDraw, ImageFilter
import os

def create_gamatube_icon(size=1024):
    # Master image with RGBA
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Dark sleek base squircle
    margin = int(size * 0.04)
    radius = int(size * 0.24)
    base_rect = [margin, margin, size - margin, size - margin]
    
    # Outer subtle drop glow
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.rounded_rectangle(base_rect, radius=radius, fill=(255, 0, 50, 45))
    glow = glow.filter(ImageFilter.GaussianBlur(int(size * 0.04)))
    img.paste(glow, (0, 0), glow)

    # Base background (Dark Obsidian #0F0F12)
    draw.rounded_rectangle(base_rect, radius=radius, fill=(15, 15, 18, 255))
    
    # Subtle inner border
    draw.rounded_rectangle(base_rect, radius=radius, outline=(45, 45, 55, 255), width=max(2, int(size * 0.006)))

    # 2. Central Iconic Crimson Red Play Pill (YouTube silhouette tribute)
    # The pill width is ~ 60% of size, height is ~ 42% of size
    pill_w = int(size * 0.62)
    pill_h = int(size * 0.44)
    pill_x0 = (size - pill_w) // 2
    pill_y0 = (size - pill_h) // 2
    pill_x1 = pill_x0 + pill_w
    pill_y1 = pill_y0 + pill_h
    pill_r = int(pill_h * 0.32)

    # Pill shadow
    pill_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ps_draw = ImageDraw.Draw(pill_shadow)
    ps_draw.rounded_rectangle([pill_x0, pill_y0 + int(size * 0.02), pill_x1, pill_y1 + int(size * 0.02)], radius=pill_r, fill=(255, 0, 50, 90))
    pill_shadow = pill_shadow.filter(ImageFilter.GaussianBlur(int(size * 0.03)))
    img.paste(pill_shadow, (0, 0), pill_shadow)

    # Red gradient pill (#FF0033 to #CC0029)
    pill_img = Image.new("RGBA", (pill_w, pill_h), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(pill_img)
    for y in range(pill_h):
        ratio = y / float(pill_h)
        r = int(255 - ratio * 45)
        g = int(5 - ratio * 5)
        b = int(45 - ratio * 20)
        p_draw.line([(0, y), (pill_w, y)], fill=(r, g, b, 255))
    
    # Mask with rounded rectangle
    mask = Image.new("L", (pill_w, pill_h), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle([0, 0, pill_w, pill_h], radius=pill_r, fill=255)
    
    # Highlight sheen on top half
    sheen = Image.new("RGBA", (pill_w, pill_h), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sheen)
    sh_draw.rounded_rectangle([0, 0, pill_w, pill_h // 2], radius=pill_r, fill=(255, 255, 255, 30))
    pill_img.paste(sheen, (0, 0), sheen)

    img.paste(pill_img, (pill_x0, pill_y0), mask)

    # 3. Crisp Pure White Play Triangle in Center
    # Triangle dimensions
    tri_h = int(pill_h * 0.52)
    tri_w = int(tri_h * 0.88)
    center_x = size // 2 + int(size * 0.012) # optical center adjustment
    center_y = size // 2

    x_left = center_x - tri_w // 2
    x_right = center_x + tri_w // 2
    y_top = center_y - tri_h // 2
    y_bottom = center_y + tri_h // 2

    # Draw rounded play triangle
    tri_points = [
        (x_left, y_top),
        (x_right, center_y),
        (x_left, y_bottom)
    ]
    draw.polygon(tri_points, fill=(255, 255, 255, 255))

    # 4. Subtle "G" notch / accent: clean white dot at top right of the play badge representing Gama
    dot_r = int(size * 0.024)
    dot_cx = pill_x1 - int(size * 0.055)
    dot_cy = pill_y0 + int(size * 0.055)
    draw.ellipse([dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r], fill=(255, 255, 255, 230))

    return img

def export_all_icons():
    master = create_gamatube_icon(1024)
    
    os.makedirs("assets/icon", exist_ok=True)
    master.save("assets/icon/app_icon.png", "PNG")
    print("Saved master icon: assets/icon/app_icon.png")

    # Android mipmaps
    android_res = "android/app/src/main/res"
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, s in sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = master.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(out_dir, "ic_launcher.png"), "PNG")
        print(f"Saved {folder}/ic_launcher.png ({s}x{s})")

    # Web icons
    web_icons = {
        "web/favicon.png": 32,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
    }
    for path, s in web_icons.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        resized = master.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(path, "PNG")
        print(f"Saved {path} ({s}x{s})")

if __name__ == "__main__":
    export_all_icons()
