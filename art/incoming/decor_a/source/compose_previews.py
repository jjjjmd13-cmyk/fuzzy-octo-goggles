"""Contact sheets of the actual GLB renders and texture repeat previews."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
OUT=Path(__file__).resolve().parents[1]
GROUPS=[['wall_stripe','wall_bubble','wall_paw'],['floor_wood','floor_check','floor_star'],['tub_wood','tub_claw','tub_shell'],['shelf_wood','shelf_basket','shelf_cloud'],['counter_wood','counter_bone','counter_cake'],['sign_board','sign_paw','sign_rainbow'],['lamp_bulb','lamp_bubble','lamp_cloud'],['plant_round','plant_monstera','plant_lemon'],['rug_circle','rug_paw','rug_rainbow'],['art_dog','art_clock','art_bubble']]
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';regular=ImageFont.truetype(font,20);small=ImageFont.truetype(font,16);title=ImageFont.truetype(font,34);star=ImageFont.truetype(font,28)
geo=json.loads((OUT/'validation_geometry.json').read_text())
def sheet(groups,path):
 w=1440;ch=478;im=Image.new('RGB',(w,148+ch*len(groups)), '#EAF1F1');d=ImageDraw.Draw(im)
 d.text((28,20),'PAWS & BUBBLES  /  SHOP DECOR',font=title,fill='#2C4955')
 for col,text in enumerate(['★  Simple','★★  Cute','★★★  Special']):d.text((col*480+30,90),text,font=star,fill='#4D7582')
 for row,names in enumerate(groups):
  for col,name in enumerate(names):
   x=col*480+16;y=148+row*ch;d.rounded_rectangle((x,y,x+448,y+458),radius=18,fill='white')
   img=Image.open(OUT/(name+'_preview.png')).convert('RGB').resize((426,390),Image.Resampling.LANCZOS) if name.startswith(('wall_','floor_')) else Image.open(OUT/(name+'_preview.png')).convert('RGB').resize((390,390),Image.Resampling.LANCZOS)
   im.paste(img,(x+(448-img.width)//2,y+10));d.text((x+16,y+407),name+('.glb' if name in geo else '.png'),font=regular,fill='#2C4955')
   meta=f"{geo[name]['triangles']:,} triangles" if name in geo else '1024 x 1024  /  2 x 2 repeat preview'
   d.text((x+16,y+436),meta,font=small,fill='#6A7E85')
 im.save(OUT/path,quality=91,optimize=True)
sheet(GROUPS,'overview_all.jpg');sheet([GROUPS[i] for i in [2,3,4,5]],'overview_furniture.jpg');sheet([GROUPS[i] for i in [6,7,8,9]],'overview_accents.jpg');sheet(GROUPS[:2],'overview_surfaces.jpg')
