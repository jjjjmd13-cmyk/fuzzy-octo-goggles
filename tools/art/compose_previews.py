"""Create the requested one PNG per slot from exact GLB renders; no font assets."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
TMP=ROOT/'art/render_work'
BG=(237,239,238)
def get(name):return Image.open(TMP/name).convert('RGB')
def paste(canvas,im,box):
    x,y,w,h=box;im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS);canvas.paste(im,(x+(w-im.width)//2,y+(h-im.height)//2))
# One clean, unlabelled three-view PNG for the dog.
im=Image.new('RGB',(1392,924),BG)
paste(im,get('dog_dog_hero.png'),(12,12,900,900))
paste(im,get('dog_dog_front.png'),(924,12,456,444))
paste(im,get('dog_dog_back.png'),(924,468,456,444))
im.save(ROOT/'art/incoming/dog/dog_preview.png')
for slot in ['owner','tub','turntable','chair']:
    get(f'{slot}_{slot}_hero.png').save(ROOT/f'art/incoming/{slot}/{slot}_preview.png')
tiles=Image.new('RGB',(1812,900),BG)
paste(tiles,get('tiles_floor_hero.png'),(0,0,900,900));paste(tiles,get('tiles_wall_hero.png'),(912,0,900,900))
tiles.save(ROOT/'art/incoming/tiles/tiles_preview.png')
# Ordered like the requested task: dog, owner, tub / turntable, chair, tiles.
all_im=Image.new('RGB',(1836,1228),BG)
for k,slot in enumerate(['dog','owner','tub','turntable','chair','tiles']):
    img=get(f'{slot}_{slot}_hero.png') if slot!='tiles' else tiles
    paste(all_im,img,(12+(k%3)*608,12+(k//3)*608,596,596))
all_im.save(ROOT/'docs/art/slots_overview.png')
