"""Compose the three final GLB renders into the single requested preview PNG."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];TMP=ROOT/'art/render_work/cat'
def font(size):return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',size)
canvas=Image.new('RGB',(2180,1020),'#F3F5F3');d=ImageDraw.Draw(canvas)
d.text((42,24),'MEONGNYANG BATHHOUSE',font=font(19),fill='#6D7B80')
d.text((40,53),'Cat customer',font=font(38),fill='#33444C')
d.text((42,108),'Soft pastel toy  /  Clean coat  /  Neutral pose',font=font(19),fill='#738088')
for i,(name,label) in enumerate([('front','01   FRONT'),('side','02   SIDE'),('back','03   BACK')]):
    x=30+i*710;im=Image.open(TMP/(name+'.png')).convert('RGB');canvas.paste(im,(x,157))
    d.text((x+18,169),label,font=font(18),fill='#FBFEFD')
d.text((42,976),'0.50 m seated height   |   7,788 triangles   |   Y up   |   Front -Z   |   Actual GLB renders',font=font(19),fill='#5D717A')
canvas.save(ROOT/'art/incoming/cat/cat_preview.png',optimize=True)
