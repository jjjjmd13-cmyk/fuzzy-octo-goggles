"""Original seamless albedo textures. Python 3 + Pillow. No baked lighting."""
from pathlib import Path
from PIL import Image, ImageDraw
import math,json
OUT=Path(__file__).resolve().parents[1]
S=2048
P=dict(mint='#DFF5EC',butter='#FFF1C9',wood='#E8C9A0',sky='#8FD3F4',red='#FF6B6B',pink='#FF9EC4',green='#B8E3D3',blue='#5BC0EB',white='#FFFFFF',gold='#E9BE61',ice='#DEF1FB')
def star(d,x,y,r,col):
 pts=[(x+(r if k%2==0 else r*.48)*math.cos(-math.pi/2+k*math.pi/5),y+(r if k%2==0 else r*.48)*math.sin(-math.pi/2+k*math.pi/5)) for k in range(10)]
 d.polygon(pts,fill=col)
def paw(d,x,y,s,col):
 d.ellipse((x-s*.29,y-s*.04,x+s*.29,y+s*.35),fill=col)
 for dx,dy in [(-.36,-.15),(-.13,-.36),(.13,-.36),(.36,-.15)]:
  d.ellipse((x+(dx-.105)*s,y+(dy-.14)*s,x+(dx+.105)*s,y+(dy+.14)*s),fill=col)
def save(im,name):
 im=im.resize((1024,1024),Image.Resampling.LANCZOS)
 # Motifs are periodic; checker and plank cell boundaries continue on the next tile.
 im.save(OUT/(name+'.png'),optimize=True)
 preview=Image.new('RGB',(1024,1024))
 sm=im.resize((512,512),Image.Resampling.LANCZOS)
 for x in [0,512]:
  for y in [0,512]:preview.paste(sm,(x,y))
 preview.save(OUT/(name+'_preview.png'),optimize=True)
im=Image.new('RGB',(S,S),P['butter']);d=ImageDraw.Draw(im)
for k in range(4):d.rectangle((k*S/4+S/16,0,k*S/4+3*S/16,S),fill=P['sky'])
save(im,'wall_stripe')
im=Image.new('RGB',(S,S),P['ice']);d=ImageDraw.Draw(im)
for ix in range(-1,5):
 for iy in range(-1,5):
  x=ix*S/4+S*.105;y=iy*S/4+S*.11
  for dx,dy,r in [(0,0,.065),(.092,.075,.025),(-.05,.095,.017)]:
   d.ellipse((x+(dx-r)*S,y+(dy-r)*S,x+(dx+r)*S,y+(dy+r)*S),outline=P['white'],width=12)
save(im,'wall_bubble')
im=Image.new('RGB',(S,S),'#FFE7F1');d=ImageDraw.Draw(im)
for ix in range(4):
 for iy in range(4):paw(d,(ix+.5)*S/4,(iy+.5)*S/4,S*.125,P['pink'])
d.rectangle((0,S*.75,S,S*.756),fill=P['gold']);d.rectangle((0,S*.78,S,S*.783),fill=P['gold'])
save(im,'wall_paw')
im=Image.new('RGB',(S,S),P['wood']);d=ImageDraw.Draw(im)
for k,col in enumerate(['#E8C9A0','#EFD2AE','#E8C9A0','#E4C498']):
 x=k*S/4;d.rectangle((x,0,x+S/4,S),fill=col);d.rectangle((x,0,x+6,S),fill='#D6B78E')
 for y in [((k%2)*.25+.125)*S,((k%2)*.25+.625)*S]:d.line((x,y,x+S/4,y),fill='#D6B78E',width=6)
 # Flat-colour grain marks; no directional shading.
 for j in range(3):
  xx=x+(j+1)*S/16;yy=(.1+j*.22+k*.08)%1*S
  d.rounded_rectangle((xx,yy,xx+4,yy+S*.08),radius=2,fill='#DDBD94')
save(im,'floor_wood')
im=Image.new('RGB',(S,S),P['white']);d=ImageDraw.Draw(im)
for x in range(4):
 for y in range(4):
  if (x+y)%2==0:d.rectangle((x*S/4,y*S/4,(x+1)*S/4,(y+1)*S/4),fill=P['mint'])
save(im,'floor_check')
im=Image.new('RGB',(S,S),P['sky']);d=ImageDraw.Draw(im)
for x in range(4):
 for y in range(4):
  d.rectangle((x*S/4,y*S/4,(x+1)*S/4,(y+1)*S/4),outline='#D8EEF9',width=8)
  star(d,(x+.5)*S/4,(y+.5)*S/4,S*.045,P['butter'])
save(im,'floor_star')
# Shared exact sRGB palette, all models pack this PNG.
colors=['DFF5EC','FFF1C9','E8C9A0','8FD3F4','FF6B6B','FF9EC4','B8E3D3','5BC0EB','FFFFFF','E9BE61','F9D9E7','D4AF85','42576A','B9E7A2','CAA6EB','FFAB8A','F3EDF8','DEF1FB','8FD3F4']
im=Image.new('RGBA',(128,64),'white');d=ImageDraw.Draw(im)
for i,col in enumerate(colors):d.rectangle(((i%8)*16,(i//8)*16,(i%8+1)*16-1,(i//8+1)*16-1),fill=tuple(bytes.fromhex(col))+(64 if i==18 else 255,))
im.save(OUT/'source/palette.png',optimize=True)
print('6 seamless 1024px textures + 6 repeat previews + palette')
