"""Build Shane #8's complete home-shirt color atlas from the supplied kit sheet.

Uses the supplied Beechlawn sheet for colors, badge, sponsor and manufacturer
artwork. A subtle high-frequency knit pattern from its fabric swatch is baked
into the atlas for a single glTF albedo material.
Run with Python 3 + Pillow before build_shane_denham_player.py.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
SHEET = ROOT / "games/beechlawn_rovers/references/source_uploads/drive_folder/file_000000000da0824386b7ef8edd3a9c79.png"
OUT = ROOT / "games/beechlawn_rovers/assets/characters/textures/beechlawn_home_shane_08_albedo.png"
FACE_SOURCE = ROOT / "games/beechlawn_rovers/references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg"
FACE_OUT = ROOT / "games/beechlawn_rovers/assets/characters/textures/shane_denham_face_reference.png"
FACE_UV_OUT = ROOT / "games/beechlawn_rovers/assets/characters/textures/shane_denham_head_albedo.png"
W = H = 1024
BLUE = (30, 92, 198)  # kit board swatch #1E5CC6
BLACK = (8, 11, 11)
WHITE = (244, 245, 242)


def font(size, condensed=False):
    paths = (["/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf",
              "/usr/share/fonts/truetype/liberation2/LiberationSansNarrow-Bold.ttf"] if condensed else
             ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"])
    for name in paths:
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def cut_brand_art(sheet):
    crest = sheet.crop((1198, 500, 1360, 680)).convert("RGBA")
    # The photographed crest is oval; the ellipse removes its display-board surround.
    mask = Image.new("L", crest.size, 0)
    ImageDraw.Draw(mask).ellipse((8, 5, crest.width - 8, crest.height - 5), fill=255)
    crest.putalpha(mask)
    crest.save(OUT.with_name("beechlawn_crest_from_kit_reference.png"))

    # Extract only the white manufacturer word from its black close-up tile.
    brand = sheet.crop((1028, 560, 1168, 633)).convert("RGB")
    pixels = brand.load()
    alpha = Image.new("L", brand.size, 0)
    ap = alpha.load()
    for y in range(brand.height):
        for x in range(brand.width):
            r, g, b = pixels[x, y]
            luminance = (r * 3 + g * 6 + b) // 10
            ap[x, y] = max(0, min(255, int((luminance - 92) * 3.0)))
    brand_rgba = Image.new("RGBA", brand.size, (255, 255, 255, 0))
    brand_rgba.putalpha(alpha)
    brand_rgba.save(OUT.with_name("uhlsport_wordmark_from_kit_reference.png"))

    # Sponsor typography is cropped from the supplied logo tile, preserving its
    # original condensed letterforms rather than re-typesetting the words.
    sponsor = sheet.crop((1345, 772, 1532, 864)).convert("RGBA")
    sp = sponsor.load()
    for y in range(sponsor.height):
        for x in range(sponsor.width):
            r, g, b, _a = sp[x, y]
            luminance = (r * 3 + g * 6 + b) // 10
            alpha_value = max(0, min(255, int((luminance - 58) * 2.1)))
            sp[x, y] = (255, 255, 255, alpha_value)
    sponsor.save(OUT.with_name("thomas_loomes_sponsor_from_kit_reference.png"))
    return OUT.with_name("beechlawn_crest_from_kit_reference.png"), \
        OUT.with_name("uhlsport_wordmark_from_kit_reference.png"), \
        OUT.with_name("thomas_loomes_sponsor_from_kit_reference.png")


def back_prints():
    """Condensed name and chamfered athletic eight, measured against the boards.

    The character turnaround's eight occupies ~40% of collar-to-hem height.
    The kit board supplies the uppercase name treatment; the owner explicitly
    selected S. DENHAM rather than the example MURRAY identity.
    """
    name = Image.new("RGBA", (1000, 180))
    ImageDraw.Draw(name).text((0, 0), "S. DENHAM", font=font(140, condensed=True),
                             fill=WHITE + (255,), anchor="lt")
    name = name.crop(name.getbbox()).resize((300, 65), Image.Resampling.LANCZOS)

    # Trace the angular eight from Shane's squad-number detail, rather than
    # using the rounded generic sans-serif glyph from the previous atlas.
    scale = 4
    mask = Image.new("L", (160 * scale, 365 * scale))
    pen = ImageDraw.Draw(mask)
    def polygon(points, value):
        pen.polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=value)
    polygon([(31, 0), (129, 0), (160, 31), (160, 151), (140, 176),
             (160, 199), (160, 334), (129, 365), (31, 365), (0, 334),
             (0, 199), (20, 176), (0, 151), (0, 31)], 255)
    for top, bottom in ((59, 144), (218, 306)):
        polygon([(61, top), (99, top), (108, top + 9), (108, bottom - 9),
                 (99, bottom), (61, bottom), (52, bottom - 9), (52, top + 9)], 0)
    # Compensate for the current torso projection's horizontal/vertical scale
    # so the rendered eight has the sheet's tall, narrow proportions.
    mask = mask.resize((130, 410), Image.Resampling.LANCZOS)
    eight = Image.new("RGBA", mask.size, WHITE + (0,))
    eight.putalpha(mask)
    return name, eight


def wrap_back_print(atlas, artwork, top):
    """Repeat across the back-centre UV seam without clipping either half."""
    for centre in (0, W):
        atlas.alpha_composite(artwork, (centre - artwork.width // 2, top))


def build_face_texture():
    """Crop Shane's actual front portrait and mask the sheet backdrop cleanly."""
    source = Image.open(FACE_SOURCE).convert("RGBA")
    crop = source.crop((20, 100, 260, 400))
    scale = 4
    mask = Image.new("L", (crop.width * scale, crop.height * scale), 0)
    silhouette = [
        (70, 0), (117, 0), (153, 4), (184, 14), (207, 32), (224, 56),
        (235, 87), (238, 119), (236, 145), (236, 166), (230, 191),
        (221, 215), (208, 239), (192, 261), (174, 278), (151, 291),
        (126, 299), (103, 298), (80, 291), (59, 278), (40, 260),
        (24, 238), (13, 211), (6, 185), (1, 158), (1, 135), (5, 112),
        (12, 87), (22, 62), (37, 39), (52, 18),
    ]
    ImageDraw.Draw(mask).polygon([(x * scale, y * scale) for x, y in silhouette], fill=255)
    mask = mask.resize(crop.size, Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(1.1))
    crop.putalpha(mask)
    crop.save(FACE_OUT)

    # A real head UV atlas: the portrait is registered to the front of a
    # cylindrical/lat-long head unwrap. This is a texture for the whole head
    # mesh, not a floating photo card. The soft cheek/jaw edge blends into a
    # neutral skin field so the spherical sides and back remain continuous.
    # Keep the atlas padding close to the photographed cheek tone so the
    # front-projection feather is unobtrusive at three-quarter angles.
    atlas = Image.new("RGB", (1024, 1024), (207, 140, 117))
    portrait = source.crop((20, 100, 260, 400)).convert("RGBA")
    face_mask = Image.new("L", portrait.size, 0)
    # Trace the hairline, temples, cheeks and chin from the supplied close-up.
    outline = [
        (75, 77), (98, 72), (122, 70), (148, 72), (172, 76), (193, 84),
        (207, 97), (218, 119), (224, 147), (225, 176), (220, 204),
        (210, 229), (195, 251), (177, 271), (154, 285), (132, 292),
        (108, 289), (86, 281), (66, 268), (48, 249), (33, 226),
        (22, 201), (16, 175), (16, 149), (21, 126), (31, 105),
        (44, 90), (59, 81),
    ]
    ImageDraw.Draw(face_mask).polygon(outline, fill=255)
    face_mask = face_mask.filter(ImageFilter.GaussianBlur(4.5))
    portrait.putalpha(face_mask)
    portrait = portrait.resize((548, 770), Image.Resampling.LANCZOS)
    # UV u=.5 is the front of the head; the texture's top maps to V=1.
    atlas_rgba = atlas.convert("RGBA")
    atlas_rgba.alpha_composite(portrait, (238, 112))
    atlas_rgba.convert("RGB").save(FACE_UV_OUT, optimize=True)


def main():
    sheet = Image.open(SHEET).convert("RGB")
    build_face_texture()
    crest_path, brand_path, sponsor_path = cut_brand_art(sheet)
    atlas = Image.new("RGB", (W, H), BLACK)
    draw = ImageDraw.Draw(atlas)

    # Twelve narrow knitted panels wrap the torso. Six appear across the front,
    # with a central black panel and alternating blue stripes from the kit.
    panel_count = 12
    for band in range(panel_count):
        if band % 2 == 1:
            x0 = round(band * W / panel_count)
            x1 = round((band + 1) * W / panel_count)
            draw.rectangle((x0, 0, x1, H), fill=BLUE)
    for band in range(panel_count + 1):
        x = round(band * W / panel_count)
        draw.line((x, 0, x, H), fill=(7, 10, 13), width=3)

    # Narrow black/blue ribbing at the neck. V points down the chest in the
    # image's upper area (UV v=1 corresponds to image y=0).
    draw.line([(430, 0), (512, 70), (594, 0)], fill=(2, 7, 14), width=22, joint="curve")
    draw.line([(438, 0), (512, 61), (586, 0)], fill=BLUE, width=7, joint="curve")
    draw.line((0, 90, W, 90), fill=(12, 15, 17), width=5)

    crest = Image.open(crest_path).convert("RGBA")
    crest.thumbnail((96, 112), Image.Resampling.LANCZOS)
    atlas_rgba = atlas.convert("RGBA")
    # Crest on the wearer's left chest (front is centered at U=.5).
    atlas_rgba.alpha_composite(crest, (552, 184))

    brand = Image.open(brand_path).convert("RGBA")
    brand.thumbnail((116, 48), Image.Resampling.LANCZOS)
    atlas_rgba.alpha_composite(brand, (454, 276))

    sponsor = Image.open(sponsor_path).convert("RGBA")
    # The shirt's front occupies roughly one half of this cylindrical atlas;
    # keep the real sponsor artwork inside that front-facing UV window so the
    # edge letters do not wrap under the arms.
    sponsor = sponsor.crop(sponsor.getbbox())
    sponsor = sponsor.resize((350, 121), Image.Resampling.LANCZOS)
    atlas_rgba.alpha_composite(sponsor, (337, 365))

    name, number = back_prints()
    wrap_back_print(atlas_rgba, name, 138)
    wrap_back_print(atlas_rgba, number, 260)

    atlas_rgba.convert("RGB").save(OUT, quality=95)
    # The supplied knit swatch is baked into the albedo as restrained fine
    # weave variation, preserving a single glTF base-color texture for the kit.
    fabric_path = OUT.with_name("beechlawn_jersey_fabric_reference.png")
    if fabric_path.exists():
        swatch = Image.open(fabric_path).convert("RGB").convert("L")
        tiled = Image.new("L", (swatch.width * 13, swatch.height * 6))
        for ty in range(6):
            for tx in range(13):
                tiled.paste(swatch, (tx * swatch.width, ty * swatch.height))
        weave = tiled.resize((W, H), Image.Resampling.LANCZOS)
        low_frequency = weave.filter(ImageFilter.GaussianBlur(7.0))
        base = Image.open(OUT).convert("RGB")
        src, hi, lo = base.load(), weave.load(), low_frequency.load()
        for y in range(H):
            for x in range(W):
                factor = 1.0 + (hi[x, y] - lo[x, y]) / 255.0 * 0.28
                r, g, b = src[x, y]
                src[x, y] = (max(0, min(255, round(r * factor))),
                             max(0, min(255, round(g * factor))),
                             max(0, min(255, round(b * factor))))
        base.save(OUT)
    print("SHANE_HOME_KIT_ATLAS", OUT)


if __name__ == "__main__":
    main()
