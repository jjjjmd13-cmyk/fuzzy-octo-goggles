"""Contact sheets from final exported GLB renders; Pillow, no generated stand-ins."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json
OUT=Path(__file__).resolve().parents[1]
NAMES=['shop_front','sign_outside','open_sign','paving','road','road_line','box_small','box_medium','box_large','truck','cart','mailbox','street_lamp','fence','flower_bed','delivery_mat']
f='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';title=ImageFont.truetype(f,32);normal=ImageFont.truetype(f,19);small=ImageFont.truetype(f,16)
geo=json.loads((OUT/'validation_geometry.json').read_text())
def sheet(entries,cols,path,heading):
 rows=(len(entries)+cols-1)//cols;im=Image.new('RGB',(400*cols,100+410*rows),'#EAF1F1');d=ImageDraw.Draw(im);d.text((24,25),heading,font=title,fill='#2C4955')
 for i,(name,file,detail) in enumerate(entries):
  x=i%cols*400+12;y=100+i//cols*410;d.rounded_rectangle((x,y,x+376,y+392),radius=16,fill='white');src=Image.open(OUT/file).convert('RGB');src=ImageOps.contain(src,(360,310),Image.Resampling.LANCZOS);im.paste(src,(x+(376-src.width)//2,y+8+(310-src.height)//2));d.text((x+14,y+330),name,font=normal,fill='#2C4955');d.text((x+14,y+361),detail,font=small,fill='#667D86')
 im.save(OUT/path,quality=92,optimize=True)
entries=[]
for i,n in enumerate(NAMES,1):entries.append((f'{i:02}  {n}',n+'_preview.png',f"{geo[n]['triangles']:,} triangles" if n in geo else '1024px / 1m / 2 x 2 repeat'))
sheet(entries,4,'overview_all.jpg','PAWS & BUBBLES  /  OUTSIDE + DELIVERY')
poses=['shop_front','box_large','truck','open_sign','mailbox'];sheet([(n,'qa/'+n+'_open.png','Actual separated-node rotation') for n in poses],3,'overview_motion.jpg','ARTICULATION  /  EXPORTED GLB JOINTS')
