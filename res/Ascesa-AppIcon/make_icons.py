from PIL import Image, ImageDraw

SS = 4  # supersampling factor for crisp antialiasing
SIZE = 1024
W = SIZE * SS

# Base geometry (1024 space)
LINE = [(163, 743), (326, 673), (465, 603), (605, 487), (745, 371), (884, 231)]
AREA = LINE + [(884, 836), (163, 836)]
SUN = (884, 231)
SUN_R = 65
LINE_W = 40

BG = (30, 42, 82)        # #1E2A52 deep indigo
AREA_FILL = (46, 66, 136)  # #2E4288
AMBER = (255, 184, 77)   # #FFB84D


def s(pts):
    return [(x * SS, y * SS) for x, y in pts]


def draw_motif(draw, area_fill, line_fill, line_w):
    # filled area under the ridge
    draw.polygon(s(AREA), fill=area_fill)
    # ridge line with rounded joins
    draw.line(s(LINE), fill=line_fill, width=line_w * SS, joint="curve")
    # round caps + joins
    r = (line_w * SS) // 2
    for x, y in s(LINE):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=line_fill)
    # sun
    cx, cy = SUN[0] * SS, SUN[1] * SS
    sr = SUN_R * SS
    draw.ellipse([cx - sr, cy - sr, cx + sr, cy + sr], fill=line_fill)


def finalize(img, name, has_alpha):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    if not has_alpha:
        img = img.convert("RGB")  # App Store icon must NOT have alpha
    img.save(name)
    print("wrote", name, img.mode, img.size)


# 1) Standard (light) — opaque indigo background, no alpha
img = Image.new("RGB", (W, W), BG)
d = ImageDraw.Draw(img)
draw_motif(d, AREA_FILL, AMBER, LINE_W)
finalize(img, "AppIcon.appiconset/AppIcon-1024.png", has_alpha=False)

# 2) Dark — transparent background, motif keeps brand colors
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img, "RGBA")
draw_motif(d, AREA_FILL + (150,), AMBER + (255,), LINE_W)
finalize(img, "AppIcon.appiconset/AppIcon-1024-Dark.png", has_alpha=True)

# 3) Tinted — grayscale motif on transparent; iOS applies the system tint
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img, "RGBA")
draw_motif(d, (110, 110, 110, 255), (240, 240, 240, 255), LINE_W)
finalize(img, "AppIcon.appiconset/AppIcon-1024-Tinted.png", has_alpha=True)
