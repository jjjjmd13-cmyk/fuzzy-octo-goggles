"""Compose exact Blender previews; Pillow, existing OFL Pretendard font."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[2]
root=ROOT/'art/incoming/tool_upgrades'
report=json.loads((root/'validation.json').read_text())
f=ROOT/'assets/fonts/pretendard'
font=ImageFont.truetype(str(f/'Pretendard-SemiBold.otf'),26)
small=ImageFont.truetype(str(f/'Pretendard-Regular.otf'),17)
title=ImageFont.truetype(str(f/'Pretendard-SemiBold.otf'),36)
canvas=Image.new('RGB',(1416,1604),'#ECF0F3');d=ImageDraw.Draw(canvas)
d.text((36,27),'멍냥 목욕탕 · 파스텔 손 도구 9종',font=title,fill='#243B4B')
d.text((38,79),'원본 GLB의 Blender 렌더 · 별도 오브젝트 피벗 · 내장 PNG 알베도',font=small,fill='#5E7182')
labels=['일반 빗','슬리커 브러시','전동 브러시','넓은 샤워기','레인 샤워기','거품 펌프','거품 대포','큰 송풍 드라이기','미용 가위']
for i,((name,r),label) in enumerate(zip(report.items(),labels)):
 x=24+i%3*464;y=123+i//3*489
 d.rounded_rectangle((x,y,x+440,y+470),radius=15,fill='white')
 im=Image.open(root/f'{name}.png').convert('RGB');im.thumbnail((420,390));canvas.paste(im,(x+10+(420-im.width)//2,y+9))
 d.text((x+18,y+404),f'{i+1:02}  {label}',font=font,fill='#243B4B')
 d.text((x+18,y+442),f'{name}.glb  |  {r["triangles"]:,} tris  |  {r["target_size_m"]:.2f} m',font=small,fill='#5E7182')
canvas.save(root/'overview.jpg',quality=91,optimize=True)
