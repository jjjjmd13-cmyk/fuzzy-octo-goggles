"""After Blender render: Python + Pillow; adds labels only to actual GLB renders."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,os
HERE=Path(__file__).resolve().parent
fontpath=Path(os.environ.get('STYLE_B_FONT','C:/Windows/Fonts/malgun.ttf'))
def font(size):return ImageFont.truetype(str(fontpath),size)
bg='#F4F1EC';ink='#3E4748';muted='#65716F'
for mode,output,title,subtitle in [
    ('lineup','lineup_b.png','B 그림체 · 같은 규칙으로 만든 5종','실제 납품 GLB 재열기 렌더 · 원래 크기 비율 · 동일 조명 / 배경 / 노출'),
    ('compare','compare_a_b.png','A → B · 기존 도구와 나란히 비교','A: 저장소의 기존 파스텔 GLB / B: 새 규칙표의 GLB · 동일 조명 / 배경 / 배율')]:
    raw=Image.open(HERE/('_'+mode+'_raw.png')).convert('RGB').crop((0,150,2000,760))
    im=Image.new('RGB',(2000,850),bg);im.paste(raw,(0,115));draw=ImageDraw.Draw(im)
    draw.text((55,23),title,font=font(36),fill=ink);draw.text((57,76),subtitle,font=font(20),fill=muted)
    labels=json.loads((HERE/('_'+mode+'_labels.json')).read_text())
    local={'SHOWER':'샤워기','DRYER':'드라이기','OAK BRUSH':'원목 빗','BRUSH':'원목 빗','TOWEL':'손에 쥔 수건','SHIBA':'앉은 시바견'}
    sizes={'SHOWER':'길이 25 cm','DRYER':'길이 30 cm · 독립 Fan','OAK BRUSH':'길이 20 cm','TOWEL':'25 × 15 cm','SHIBA':'높이 35 cm'}
    for label,x in labels:
        style,kind=label.split(' / ');txt=style+' · '+local[kind]
        draw.text((x,754),txt,font=font(25),fill=ink,anchor='mt')
        detail=sizes.get(kind,'길이 20 cm') if mode=='lineup' else ('기존 파스텔 자산' if style=='A' else '표면 결 + PBR 재질')
        draw.text((x,792),detail,font=font(19),fill=muted,anchor='mt')
    im.save(HERE/output,optimize=True)
