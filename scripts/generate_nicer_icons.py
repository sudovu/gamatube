import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_master_icon(canvas_size=1024, is_foreground_only=False):
    # Master image with RGBA
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    center = canvas_size / 2.0

    if not is_foreground_only:
        # --- 1. Background Squircle for legacy/standalone icons ---
        bg_size = 900
        bg_rad = 220
        b_x0 = (canvas_size - bg_size) / 2
        b_y0 = (canvas_size - bg_size) / 2
        b_x1 = b_x0 + bg_size
        b_y1 = b_y0 + bg_size

        # Radial background gradient from dark graphite/crimson center to deep onyx
        bg = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        bg_draw = ImageDraw.Draw(bg)

        # Draw base dark rounded squircle
        bg_draw.rounded_rectangle([b_x0, b_y0, b_x1, b_y1], radius=bg_rad, fill=(13, 14, 18, 255))

        # Ambient inner glow
        glow_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        g_draw = ImageDraw.Draw(glow_layer)
        g_draw.ellipse([center - 320, center - 320, center + 320, center + 320], fill=(229, 9, 20, 45))
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(100))
        bg = Image.alpha_composite(bg, glow_layer)

        # Outer border rim
        bg_draw = ImageDraw.Draw(bg)
        bg_draw.rounded_rectangle([b_x0, b_y0, b_x1, b_y1], radius=bg_rad, outline=(255, 255, 255, 28), width=3)

        img = Image.alpha_composite(img, bg)

    # --- 2. Ambient Badge Neon Glow ---
    badge_w = 520
    badge_h = 370
    bx0 = center - badge_w / 2.0
    by0 = center - badge_h / 2.0
    bx1 = center + badge_w / 2.0
    by1 = center + badge_h / 2.0
    badge_rad = 110

    # Soft ambient drop shadow / ruby neon glow
    glow_badge = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    gb_draw = ImageDraw.Draw(glow_badge)
    gb_draw.rounded_rectangle([bx0 - 10, by0 + 8, bx1 + 10, by1 + 28], radius=badge_rad + 8, fill=(235, 10, 40, 140))
    glow_badge = glow_badge.filter(ImageFilter.GaussianBlur(36))
    img = Image.alpha_composite(img, glow_badge)

    # --- 3. 3D Beveled Ruby Badge ---
    badge_surf = Image.new("RGBA", (int(badge_w), int(badge_h)), (0, 0, 0, 0))
    bs_draw = ImageDraw.Draw(badge_surf)

    # Multi-stop linear gradient from Electric Coral to Deep Velvet Ruby
    for y in range(int(badge_h)):
        factor = y / float(badge_h)
        # Interpolate: (255, 45, 85) -> (229, 9, 20) -> (130, 0, 24)
        if factor < 0.5:
            t = factor / 0.5
            r = int(255 * (1 - t) + 229 * t)
            g = int(45 * (1 - t) + 9 * t)
            b = int(85 * (1 - t) + 20 * t)
        else:
            t = (factor - 0.5) / 0.5
            r = int(229 * (1 - t) + 125 * t)
            g = int(9 * (1 - t) + 0 * t)
            b = int(20 * (1 - t) + 22 * t)
        bs_draw.line([(0, y), (int(badge_w), y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new("L", (int(badge_w), int(badge_h)), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle([0, 0, int(badge_w), int(badge_h)], radius=badge_rad, fill=255)

    badge_composite = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    badge_composite.paste(badge_surf, (int(bx0), int(by0)), mask)

    # Top glass specular sheen
    gloss_h = int(badge_h * 0.48)
    gloss = Image.new("RGBA", (int(badge_w), gloss_h), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(gloss)
    for y in range(gloss_h):
        alpha = int(70 * (1.0 - (y / float(gloss_h)) ** 1.3))
        g_draw.line([(0, y), (int(badge_w), y)], fill=(255, 255, 255, alpha))

    gloss_mask = Image.new("L", (int(badge_w), gloss_h), 0)
    gm_draw = ImageDraw.Draw(gloss_mask)
    gm_draw.rounded_rectangle([0, 0, int(badge_w), int(badge_h)], radius=badge_rad, fill=255)

    badge_composite.paste(gloss, (int(bx0), int(by0)), gloss_mask)

    # Badge rim highlight (crisp top specular edge, subtle bottom shadow edge)
    b_edge = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    be_draw = ImageDraw.Draw(b_edge)
    be_draw.rounded_rectangle([bx0, by0, bx1, by1], radius=badge_rad, outline=(255, 255, 255, 80), width=3)
    badge_composite = Image.alpha_composite(badge_composite, b_edge)

    img = Image.alpha_composite(img, badge_composite)

    # --- 4. Central Crisp Equilateral Play Glyph ---
    draw = ImageDraw.Draw(img)
    tri_w = 145
    tri_h = 168
    # Shift slightly right for visual mass centering
    tx0 = center - tri_w * 0.38
    tx1 = tx0 + tri_w
    ty0 = center - tri_h / 2.0
    ty1 = center + tri_h / 2.0
    t_mid_y = center

    # Soft dimensional drop shadow beneath the play icon
    draw.polygon([(tx0, ty0 + 5), (tx1, t_mid_y + 5), (tx0, ty1 + 5)], fill=(0, 0, 0, 95))

    # Pristine white play triangle
    draw.polygon([(tx0, ty0), (tx1, t_mid_y), (tx0, ty1)], fill=(255, 255, 255, 255))

    # --- 5. Cosmic Gamma Energy Star (Top-Right of Badge) ---
    spark_cx = bx1 - 2
    spark_cy = by0 + 8
    spark_r = 38

    # Outer luminous amber halo
    spark_halo = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(spark_halo)
    sh_draw.ellipse(
        [spark_cx - 85, spark_cy - 85, spark_cx + 85, spark_cy + 85],
        fill=(255, 205, 0, 160)
    )
    spark_halo = spark_halo.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, spark_halo)

    draw = ImageDraw.Draw(img)

    # 4-point Diamond Star Flares
    flare_len = 54
    flare_w = 10
    # Horizontal flare
    draw.polygon([
        (spark_cx - flare_len, spark_cy),
        (spark_cx, spark_cy - flare_w),
        (spark_cx + flare_len, spark_cy),
        (spark_cx, spark_cy + flare_w)
    ], fill=(255, 245, 180, 220))
    # Vertical flare
    draw.polygon([
        (spark_cx, spark_cy - flare_len),
        (spark_cx + flare_w, spark_cy),
        (spark_cx, spark_cy + flare_len),
        (spark_cx - flare_w, spark_cy)
    ], fill=(255, 245, 180, 220))

    # Golden starlight core sphere with specular center
    draw.ellipse(
        [spark_cx - spark_r, spark_cy - spark_r, spark_cx + spark_r, spark_cy + spark_r],
        fill=(255, 215, 0, 255),
        outline=(255, 255, 255, 230),
        width=5
    )
    # Specular glint
    draw.ellipse(
        [spark_cx - 10, spark_cy - 10, spark_cx + 6, spark_cy + 6],
        fill=(255, 255, 255, 255)
    )

    return img

def main():
    root = r"D:\MY GIT\Gama-tube"
    res_dir = os.path.join(root, "android", "app", "src", "main", "res")

    # Android standard icon sizes:
    # mdpi: 48x48, hdpi: 72x72, xhdpi: 96x96, xxhdpi: 144x144, xxxhdpi: 192x192
    mipmap_sizes = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    # Render master canvas (1024x1024)
    print("Generating master 1024x1024 icons...")
    master_legacy = create_master_icon(1024, is_foreground_only=False)
    master_fg = create_master_icon(1024, is_foreground_only=True)

    for folder, (legacy_size, fg_size) in mipmap_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)

        # 1. Legacy icon (includes dark rounded-squircle base)
        legacy_icon = master_legacy.resize((legacy_size, legacy_size), Image.Resampling.LANCZOS)
        legacy_icon.save(os.path.join(folder_path, "ic_launcher.png"), "PNG")

        # 2. Adaptive Foreground (108dp canvas standard with 66dp safe zone)
        fg_icon = master_fg.resize((fg_size, fg_size), Image.Resampling.LANCZOS)
        fg_icon.save(os.path.join(folder_path, "ic_launcher_foreground.png"), "PNG")
        print(f"Generated {folder}: ic_launcher.png ({legacy_size}px), ic_launcher_foreground.png ({fg_size}px)")

    # Update values/colors.xml with deep dark luxury obsidian background
    values_dir = os.path.join(res_dir, "values")
    colors_xml = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0D0E12</color>
</resources>
"""
    with open(os.path.join(values_dir, "colors.xml"), "w", encoding="utf-8") as f:
        f.write(colors_xml)
    print("Updated values/colors.xml")

    # Update web icons
    web_dir = os.path.join(root, "web")
    web_icons = os.path.join(web_dir, "icons")
    os.makedirs(web_icons, exist_ok=True)

    master_legacy.resize((64, 64), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
    master_legacy.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-192.png"), "PNG")
    master_legacy.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-512.png"), "PNG")
    master_legacy.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-192.png"), "PNG")
    master_legacy.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-512.png"), "PNG")
    print("Generated web favicon & icons (192, 512, maskable).")

if __name__ == "__main__":
    main()
