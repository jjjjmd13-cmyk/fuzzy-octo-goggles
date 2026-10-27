"""Compose actual runtime frames, without changing the rendered game content."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'docs/dev/screenshots/retail'
font = ImageFont.truetype(str(ROOT / 'assets/fonts/pretendard/Pretendard-SemiBold.otf'), 26)
canvas = Image.new('RGB', (1600, 1080), '#202831')
draw = ImageDraw.Draw(canvas)
for i, (file, label) in enumerate([
    ('game_dirty', '오염 · 목욕 전'), ('game_foam', '샴푸 · 거품'),
    ('game_wet', '헹군 뒤 · 젖은 털'), ('game_clean', '드라이 완료 · 깨끗한 털'),
]):
    x, y = (i % 2) * 800, (i // 2) * 540
    draw.text((x + 16, y + 10), label, font=font, fill='white')
    with Image.open(DEST / (file + '.png')) as source:
        canvas.paste(source.convert('RGB').resize((800, 500), Image.Resampling.LANCZOS), (x, y + 40))
out = DEST / 'runtime_overview.png'
tmp = out.with_suffix('.png.tmp')
canvas.save(tmp, format='PNG')
with Image.open(tmp) as check:
    check.load()
tmp.replace(out)
