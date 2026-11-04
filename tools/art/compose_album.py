"""Compose exported GLB renders and delivered UI PNGs; no drawn product artwork."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];TMP=ROOT/'art/render_work/album';OUT=ROOT/'art/incoming/album';UI=ROOT/'art/incoming/album_ui'
book=Image.new('RGB',(1600,720),'#EDF0EA')
for i,pose in enumerate(['closed','open']):
    im=Image.open(TMP/('album_book_'+pose+'.png')).convert('RGB');im.thumbnail((800,720),Image.Resampling.LANCZOS);book.paste(im,(i*800+(800-im.width)//2,(720-im.height)//2))
book.save(OUT/'album_book_preview.png',optimize=True)
Image.open(TMP/'photo_board_closed.png').save(OUT/'photo_board_preview.png',optimize=True)
canvas=Image.new('RGB',(1600,1360),'#EDF0EA');d=ImageDraw.Draw(canvas)
for y in range(660,1360,20):
    for x in range(0,1600,20):d.rectangle((x,y,x+19,y+19),fill='#EFF1EE' if (x//20+y//20)%2 else '#E2E7E3')
def paste(path,box):
    im=Image.open(path).convert('RGBA');im.thumbnail((box[2],box[3]),Image.Resampling.LANCZOS);canvas.paste(im,(box[0]+(box[2]-im.width)//2,box[1]+(box[3]-im.height)//2),im)
paste(TMP/'album_book_closed.png',(0,0,800,650));paste(TMP/'photo_board_closed.png',(800,0,800,650))
paste(UI/'album_page.png',(20,690,360,540))
for i,color in enumerate(['grey','white','pink','gold']):paste(UI/('photo_frame_'+color+'.png'),(420+i*290,700,260,305))
paste(UI/'photo_unknown.png',(440,1030,270,270))
for i,spot in enumerate(['chin','ear_back','back','rump']):paste(UI/('fav_spot_'+spot+'.png'),(760+i*155,1090,128,128))
paste(UI/'new_photo_badge.png',(1410,1090,128,128))
p=ROOT/'docs/art/screenshots/album_delivery_preview.png';p.parent.mkdir(parents=True,exist_ok=True);canvas.save(p,optimize=True)
print('Composed 2 prop previews and 1 delivery overview')
