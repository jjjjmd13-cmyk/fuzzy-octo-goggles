"""Make one front/side/detail PNG per model and a tier-order overview."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/incoming/accessory"
TMP = ROOT / "art/render_work/accessory"
GROUPS = [
    ("Ribbons", ("ribbon_pink", "ribbon_polka", "ribbon_gold")),
    ("Hats", ("hat_party", "hat_beret", "hat_crown")),
    ("Scarves", ("scarf_mint", "scarf_bandana", "scarf_cape")),
    ("Pins", ("pin_daisy", "pin_star", "pin_rainbow")),
]
BASE = "#F8F3EC"


def place(canvas, name, view, x, y, size):
    im = Image.open(TMP / f"{name}_{view}.png").convert("RGBA")
    im.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas.paste(im, (x + (size - im.width) // 2, y + (size - im.height) // 2), im)


names = [n for _, group in GROUPS for n in group] + ["acc_basket"]
for name in names:
    strip = Image.new("RGB", (1152, 384), BASE)
    for i, view in enumerate(("front", "side", "detail")):
        place(strip, name, view, i * 384, 0, 384)
    strip.save(OUT / f"{name}_preview.png", optimize=True)

overview = Image.new("RGB", (1080, 1330), BASE)
draw = ImageDraw.Draw(overview)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
for col in range(3):
    draw.text(
        (190 + col * 350, 24), "★" * (col + 1), font=font, fill="#896E5C", anchor="mm"
    )
for row, (label, group) in enumerate(GROUPS):
    y = 52 + row * 249
    for col, name in enumerate(group):
        x = 39 + col * 350
        draw.rounded_rectangle((x, y, x + 302, y + 231), radius=22, fill="#FFFCF7")
        place(overview, name, "detail", x + 41, y + 3, 220)
y = 1055
draw.rounded_rectangle((39, y, 1041, y + 250), radius=22, fill="#FFFCF7")
for i, view in enumerate(("front", "side", "detail")):
    place(overview, "acc_basket", view, 75 + i * 350, y + 9, 230)
path = ROOT / "docs/art/screenshots/accessories_preview.png"
path.parent.mkdir(parents=True, exist_ok=True)
overview.save(path, optimize=True)
