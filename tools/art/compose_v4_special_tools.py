"""Contact sheets from the exact Blender renders; no image generation."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'art/incoming/special_tools'
f=ROOT/'assets/fonts/pretendard'
font=ImageFont.truetype(str(f/'Pretendard-SemiBold.otf'),23)
small=ImageFont.truetype(str(f/'Pretendard-Regular.otf'),16)
title=ImageFont.truetype(str(f/'Pretendard-SemiBold.otf'),36)
items=[('shower_massage','4단계 · 마사지 샤워기'),('shower_rainbow','5단계 · 무지개 샤워기'),('foam_sponge','3단계 · 거품 스펀지'),('foam_cloud','5단계 · 구름 대포'),('towel','1단계 · 수건'),('towel_thick','2단계 · 두꺼운 수건'),('towel_microfiber','3단계 · 극세사 수건'),('towel_mitt','4단계 · 흡수 장갑'),('towel_cloud','5단계 · 구름 타월'),('dryer_twin','3단계 · 이중 날개 드라이기'),('dryer_turbo','4단계 · 터보 드라이기'),('dryer_tornado','5단계 · 회오리 드라이기'),('brush_twin','3단계 · 쌍빗'),('brush_sparkle','5단계 · 반짝 전동 브러시')]
r=json.loads((P/'validation.json').read_text())
# Compact shareable PNGs: retain the render, palette encoding only.
for image_path in P.glob('*.png'):
 im=Image.open(image_path).convert('RGB')
 im.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).save(image_path,optimize=True)

def sheet(items,cols,file,heading,sub):
 cellw,cellh=375,426;rows=(len(items)+cols-1)//cols
 canvas=Image.new('RGB',(cols*cellw+32,rows*cellh+130),'#E9EDF2');d=ImageDraw.Draw(canvas)
 d.text((24,23),heading,font=title,fill='#293B50');d.text((26,76),sub,font=small,fill='#607085')
 for i,(name,label) in enumerate(items):
  x=16+i%cols*cellw;y=116+i//cols*cellh
  d.rounded_rectangle((x,y,x+cellw-12,y+cellh-12),radius=16,fill='white')
  im=Image.open(P/f'{name}.png').convert('RGB');im.thumbnail((343,343));canvas.paste(im,(x+10,y+9))
  d.text((x+14,y+358),label,font=font,fill='#293B50')
  d.text((x+14,y+393),f'{name}  ·  {r[name]["triangles"]:,} tris',font=small,fill='#607085')
 canvas.save(P/file,quality=92,optimize=True)
sheet(items,4,'overview.jpg','멍냥 목욕탕 · 새 손 도구 14종','실제 GLB 제작 장면의 Blender 렌더 · 파스텔 장난감풍 · 움직이는 부품 분리')
special=[items[i] for i in [1,3,8,11,13]]
sheet(special,3,'special_set.jpg','마지막 업그레이드 · 특별 세트','진주색 · 금색 · 무지개 포인트로 이어지는 5종')
