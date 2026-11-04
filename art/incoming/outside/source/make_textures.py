"""Original flat albedos; Python 3 + Pillow. No external artwork or baked light."""
from PIL import Image,ImageDraw
from pathlib import Path
import math
OUT=Path(__file__).resolve().parents[1]
COLORS=['DFF5EC','FFF1C9','E8C9A0','8FD3F4','FF6B6B','FF9EC4','B8E3D3','5BC0EB','FFFFFF','E9BE61','F9D9E7','D4AF85','42576A','B9E7A2','CAA6EB','FFAB8A','F3EDF8','DEF1FB','8FD3F4','D9B48A','8595A8','556777','FFF8E7']
pal=Image.new('RGBA',(128,64),'white');d=ImageDraw.Draw(pal)
for i,col in enumerate(COLORS):d.rectangle((i%8*16,i//8*16,i%8*16+15,i//8*16+15),fill=tuple(bytes.fromhex(col))+(80 if i==18 else 255,))
pal.save(OUT/'source/palette.png')
def paw(d,x,y,r,col):
 d.ellipse((x-r*.31,y-r*.02,x+r*.31,y+r*.37),fill=col)
 for dx,dy in [(-.38,-.15),(-.14,-.36),(.14,-.36),(.38,-.15)]:d.ellipse((x+(dx-.11)*r,y+(dy-.14)*r,x+(dx+.11)*r,y+(dy+.14)*r),fill=col)
def save_tile(im,name):
 im=im.resize((1024,1024),Image.Resampling.LANCZOS);im.save(OUT/(name+'.png'),optimize=True)
 sheet=Image.new('RGB',(1024,1024));tile=im.resize((512,512),Image.Resampling.LANCZOS)
 for x in [0,512]:
  for y in [0,512]:sheet.paste(tile,(x,y))
 sheet.save(OUT/(name+'_preview.png'),optimize=True)
S=2048;im=Image.new('RGB',(S,S),'#F2E9D9');d=ImageDraw.Draw(im)
for row in range(-1,5):
 for col in range(-1,5):
  x=col*S/4+(row%2)*S/8;y=row*S/4
  d.rounded_rectangle((x+7,y+7,x+S/4-7,y+S/4-7),radius=40,fill=['#DFF5EC','#FFF8E7'][(row+col)%2])
save_tile(im,'paving')
# Uniform flat grey-blue asphalt; repeat does not introduce noise or lighting seams.
im=Image.new('RGB',(S,S),'#8595A8');save_tile(im,'road')
d=ImageDraw.Draw(im)
for y in range(2):d.rounded_rectangle((S*.455,(y*.5+.08)*S,S*.545,(y*.5+.40)*S),radius=S*.018,fill='white')
save_tile(im,'road_line')
# Transparent stamps for carton's side and the truck's painted side.
im=Image.new('RGBA',(256,256),(0,0,0,0));d=ImageDraw.Draw(im);paw(d,128,128,195,'#FF9EC4');im.save(OUT/'source/paw_stamp.png')
im=Image.new('RGB',(512,512),'#FFF8E7');d=ImageDraw.Draw(im)
d.polygon([(80,190),(215,135),(355,195),(217,250)],fill='#E8C9A0');d.polygon([(80,190),(217,250),(217,390),(80,326)],fill='#D9B48A');d.polygon([(217,250),(355,195),(355,334),(217,390)],fill='#D4AF85')
d.polygon([(139,165),(166,154),(306,216),(278,228)],fill='#8FD3F4');d.rectangle((262,226,283,308),fill='#8FD3F4');paw(d,405,372,105,'#FF9EC4');im.save(OUT/'source/truck_side.png')
# Reversible board decals have the same wood-colour background as the plaque.
for face in ['sun','moon']:
 im=Image.new('RGB',(512,256),'#E8C9A0');d=ImageDraw.Draw(im)
 if face=='sun':
  for k in range(12):
   a=2*math.pi*k/12;x=256+90*math.cos(a);y=128+90*math.sin(a);xx=256+108*math.cos(a);yy=128+108*math.sin(a);d.line((x,y,xx,yy),fill='#FFF1C9',width=12)
  d.ellipse((180,52,332,204),fill='#FFF1C9')
  for x in [230,282]:d.ellipse((x-6,112,x+6,130),fill='#42576A')
  d.arc((230,125,282,165),0,180,fill='#42576A',width=6)
 else:
  d.ellipse((185,47,345,207),fill='#FFF1C9');d.ellipse((230,25,370,170),fill='#E8C9A0')
  d.arc((199,127,239,155),0,160,fill='#42576A',width=5);d.line((214,170,239,175),fill='#42576A',width=5)
  for x,y in [(130,82),(370,184),(376,65)]:d.ellipse((x-6,y-6,x+6,y+6),fill='white')
 im.save(OUT/('source/plate_'+face+'.png'))
im=Image.new('RGB',(1024,640),'#FFF8E7');d=ImageDraw.Draw(im)
for x in range(8):
 for y in [54,586]:paw(d,64+x*128,y,65,'#FF9EC4')
for y in range(1,4):
 for x in [52,972]:paw(d,x,100+y*110,65,'#B8E3D3')
d.polygon([(340,245),(501,178),(674,246),(510,314)],fill='#E8C9A0');d.polygon([(340,245),(510,314),(510,470),(340,396)],fill='#D9B48A');d.polygon([(510,314),(674,246),(674,399),(510,470)],fill='#D4AF85');d.polygon([(409,216),(439,203),(609,273),(579,285)],fill='#8FD3F4')
im.save(OUT/'source/mat_albedo.png')
print('3 seamless 1024px tiles, repeat previews and original embedded decal albedos')
