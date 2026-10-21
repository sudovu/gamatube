import os
import math
from PIL import Image, ImageDraw, ImageFilter

def draw_gamatube_badge(size, is_foreground_only=False):
    # Master high-res canvas with supersampling (1024x1024)
    canvas_size = 1024
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center_x = canvas_size / 2
    center_y = canvas_size / 2

    if not is_foreground_only:
        # 1. Background: Deep obsidian circle/squircle with subtle radial glow
        bg_radius = 490
        # Draw dark circular squircle background
        draw.rounded_rectangle(
            [(canvas_size - 920)/2, (canvas_size - 920)/2, (canvas_size + 920)/2, (canvas_size + 920)/2],
            radius=240,
            fill=(15, 15, 15, 255),
            outline=(45, 45, 45, 255),
            width=6
        )

        # Subtle dark ambient glow in center
        glow_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow_layer)
        glow_draw.ellipse(
            [center_x - 360, center_y - 280, center_x + 360, center_y + 280],
            fill=(255, 0, 50, 40)
        )
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(80))
        img = Image.alpha_composite(img, glow_layer)
        draw = ImageDraw.Draw(img)

    # 2. Outer Halo Neon Shadow for Badge
    halo_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo_layer)
    badge_w = 640
    badge_h = 440
    bx0 = center_x - badge_w / 2
    by0 = center_y - badge_h / 2
    bx1 = center_x + badge_w / 2
    by1 = center_y + badge_h / 2

    halo_draw.rounded_rectangle(
        [bx0 - 15, by0 - 10, bx1 + 15, by1 + 25],
        radius=140,
        fill=(255, 10, 50, 160)
    )
    halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(40))
    img = Image.alpha_composite(img, halo_layer)
    draw = ImageDraw.Draw(img)

    # 3. 3D Gradient Play Badge
    badge_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(badge_layer)

    # Multi-step gradient fill from Radiant Crimson to Dark Velvet Ruby
    gradient_img = Image.new("RGBA", (int(badge_w), int(badge_h)), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gradient_img)
    for y in range(int(badge_h)):
        factor = y / float(badge_h)
        # Interpolate from #FF2A55 -> #E50914 -> #880020
        if factor < 0.5:
            t = factor / 0.5
            r = int(255 * (1 - t) + 229 * t)
            g = int(42 * (1 - t) + 9 * t)
            b = int(85 * (1 - t) + 20 * t)
        else:
            t = (factor - 0.5) / 0.5
            r = int(229 * (1 - t) + 130 * t)
            g = int(9 * (1 - t) + 0 * t)
            b = int(20 * (1 - t) + 30 * t)
        gdraw.line([(0, y), (int(badge_w), y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new("L", (int(badge_w), int(badge_h)), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, int(badge_w), int(badge_h)], radius=130, fill=255)

    badge_layer.paste(gradient_img, (int(bx0), int(by0)), mask)

    # 4. Glass Specular Highlight (top gloss)
    gloss = Image.new("RGBA", (int(badge_w), int(badge_h * 0.45)), (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    for y in range(int(badge_h * 0.45)):
        alpha = int(75 * (1.0 - y / (badge_h * 0.45)))
        gloss_draw.line([(0, y), (int(badge_w), y)], fill=(255, 255, 255, alpha))

    gloss_mask = Image.new("L", (int(badge_w), int(badge_h * 0.45)), 0)
    gmdraw = ImageDraw.Draw(gloss_mask)
    gmdraw.rounded_rectangle([0, 0, int(badge_w), int(badge_h)], radius=130, fill=255)

    badge_layer.paste(gloss, (int(bx0), int(by0)), gloss_mask)

    # Badge subtle white border
    bdraw.rounded_rectangle(
        [bx0, by0, bx1, by1],
        radius=130,
        outline=(255, 255, 255, 70),
        width=4
    )

    img = Image.alpha_composite(img, badge_layer)
    draw = ImageDraw.Draw(img)

    # 5. Crisp White Play Triangle
    tri_w = 170
    tri_h = 200
    tx0 = center_x - tri_w / 3.2
    tx1 = tx0 + tri_w
    ty0 = center_y - tri_h / 2
    ty1 = center_y + tri_h / 2

    # Drop shadow for triangle
    draw.polygon([(tx0, ty0 + 6), (tx1, center_y + 6), (tx0, ty1 + 6)], fill=(0, 0, 0, 90))
    # Pure white triangle
    draw.polygon([(tx0, ty0), (tx1, center_y), (tx0, ty1)], fill=(255, 255, 255, 255))

    # 6. Gamma Golden Energy Spark (top right of badge)
    spark_cx = bx1 - 10
    spark_cy = by0 + 10
    spark_rad = 42

    # Outer golden glow
    spark_glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sg_draw = ImageDraw.Draw(spark_glow)
    sg_draw.ellipse(
        [spark_cx - 90, spark_cy - 90, spark_cx + 90, spark_cy + 90],
        fill=(255, 215, 0, 160)
    )
    spark_glow = spark_glow.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img, spark_glow)
    draw = ImageDraw.Draw(img)

    # Golden particle core
    draw.ellipse(
        [spark_cx - spark_rad, spark_cy - spark_rad, spark_cx + spark_rad, spark_cy + spark_rad],
        fill=(255, 220, 0, 255),
        outline=(15, 15, 15, 255) if not is_foreground_only else (255, 255, 255, 220),
        width=8
    )

    # Resize with high-quality Lanczos downsampling
    return img.resize((size, size), Image.Resampling.LANCZOS)

def main():
    root = r"D:\MY GIT\Gama-tube"
    res_dir = os.path.join(root, "android", "app", "src", "main", "res")

    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    # Generate standard launcher icons
    for folder, size in mipmap_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        icon = draw_gamatube_badge(size, is_foreground_only=False)
        icon.save(os.path.join(folder_path, "ic_launcher.png"), "PNG")
        print(f"Generated {folder}/ic_launcher.png ({size}x{size})")

    # Generate adaptive foreground icons
    for folder, size in mipmap_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        # Adaptive foreground is slightly larger with transparent padding
        fg_size = int(size * 1.5)
        fg_icon = draw_gamatube_badge(fg_size, is_foreground_only=True)
        fg_icon.save(os.path.join(folder_path, "ic_launcher_foreground.png"), "PNG")
        print(f"Generated {folder}/ic_launcher_foreground.png ({fg_size}x{fg_size})")

    # Generate adaptive icon XML
    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(xml_content)
    print("Generated mipmap-anydpi-v26/ic_launcher.xml")

    # Generate colors.xml
    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0F0F0F</color>
</resources>
"""
    with open(os.path.join(values_dir, "colors.xml"), "w", encoding="utf-8") as f:
        f.write(colors_xml)
    print("Generated values/colors.xml")

    # Generate Web Icons
    web_dir = os.path.join(root, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)

    draw_gamatube_badge(64).save(os.path.join(web_dir, "favicon.png"), "PNG")
    draw_gamatube_badge(192).save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
    draw_gamatube_badge(512).save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
    draw_gamatube_badge(192).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")
    draw_gamatube_badge(512).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")
    print("Generated web icons (favicon, 192, 512, maskable)")

if __name__ == "__main__":
    main()
