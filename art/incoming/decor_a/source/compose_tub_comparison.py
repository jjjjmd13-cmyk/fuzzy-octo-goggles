"""Label the true-scale rendered lineup without changing model proportions."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parents[1]
im=Image.open(OUT/'tubs_comparison.png').convert('RGB');d=ImageDraw.Draw(im)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
bold='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
title=ImageFont.truetype(bold,44);label=ImageFont.truetype(bold,29);body=ImageFont.truetype(font,25);small=ImageFont.truetype(font,22)
ink='#314D59';muted='#53737D'
d.text((75,48),'PET BATHS  /  DEEP BASIN REVISION',font=title,fill=ink)
d.text((78,116),'Same scale  ·  Interior floor 0.92 m  ·  Front rim 1.10 m  ·  Back rim 1.27 m / shell 1.50 m',font=body,fill=muted)
points=json.loads((OUT/'source/comparison_labels.json').read_text())
for key,name,desc in [('wood','1  /  tub_wood','Wood barrel + two blue hoops'),('claw','2  /  tub_claw','Four pink cat paws · 0.40 m legs'),('shell','3  /  tub_shell','Pearl shell fan + wave pedestal')]:
 x,y=points[key]
 for text,dy,f in [(name,35,label),(desc,80,small)]:
  w=d.textbbox((0,0),text,font=f)[2];d.text((x-w/2,y+dy),text,font=f,fill=ink if dy==35 else muted)
x,y=points['box'];bx=max(70,x-100);by=y-135
d.rounded_rectangle((bx-16,by-12,bx+250,by+76),radius=14,fill='#FFF3E3',outline='#CDAA7B',width=2)
d.text((bx,by),'DOG-SIZE BOX',font=small,fill=ink)
d.text((bx,by+37),'0.60 × 0.28 × 0.35 m',font=small,fill=muted)
d.line([(bx+115,by+78),(x,y-10)],fill='#AC8962',width=3)
d.text((78,1045),'Reference box height: 0.35 m. All three bath floors stay at Y = 0.92 m. Actual GLB render; studio lights only.',font=small,fill=muted)
im.save(OUT/'tubs_comparison.png',optimize=True)
