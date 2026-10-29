"""Tile actual GuideOverlay captures and make a loop from captured frames.

No illustrated assets or game pixels are redrawn. Pillow is required.
Usage: python3 tools/art/compose_bath_hints.py /tmp/bath-hint-captures
"""
from pathlib import Path
import shutil
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(sys.argv[1])
DEST = ROOT / "docs/dev/screenshots/bath-hints"
NAMES = ("wet", "squeeze", "scrub", "rinse", "towel", "dry")
DEST.mkdir(parents=True, exist_ok=True)
cards = Image.new("RGB", (848, 540), "#fffaf0")
frames = []
for index, name in enumerate(NAMES):
    source = SOURCE / f"game_{name}.png"
    shutil.copy2(source, DEST / source.name)
    with Image.open(source) as rendered:
        assert rendered.size == (1280, 800)
        cards.paste(rendered.crop((428, 72, 852, 252)).convert("RGB"),
                    ((index % 2) * 424, (index // 2) * 180))
    for file in sorted((SOURCE / "frames").glob(f"{name}_*.png")):
        with Image.open(file) as frame:
            assert frame.size == (424, 180)
            frames.append(frame.convert("RGB"))
assert len(frames) == 72
cards.save(DEST / "cards_overview.png")
frames[0].save(DEST / "motion_preview.gif", save_all=True,
               append_images=frames[1:], duration=160, loop=0, disposal=2)
shutil.copy2(SOURCE / "game_fallback_scrub.png", DEST / "game_fallback_scrub.png")
print(f"Saved six runtime screenshots, overview and 72-frame GIF: {DEST}")
