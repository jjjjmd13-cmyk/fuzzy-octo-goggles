"""Package imagegen originals: exact PNG sizes, isolated alpha, and common frame aperture.
No artwork is drawn here; 9-slice preserves the generated frame borders and ornaments.
Intermediate source manifest is art/render_work/album/image_sources.json.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/incoming/album_ui';OUT.mkdir(parents=True,exist_ok=True)

def cleanup(im):
    arr=np.array(im.convert('RGBA'));a=arr[:,:,3];lab,count=ndimage.label(a>64);sizes=np.bincount(lab.ravel());keep=np.flatnonzero(sizes>max(24,im.width*im.height*.0008));keep=keep[keep!=0]
    mask=ndimage.binary_dilation(np.isin(lab,keep),iterations=2);arr[~mask,3]=0;arr[arr[:,:,3]<8,3]=0;return Image.fromarray(arr)

def frame(im):
    arr=np.array(im);a=arr[:,:,3];ys,xs=np.nonzero(a>128);outer=(xs.min(),ys.min(),xs.max()+1,ys.max()+1)
    holes,num=ndimage.label(a<96);hole=holes[im.height//3,im.width//2];assert hole!=0
    yy,xx=np.nonzero(holes==hole);inner=(xx.min(),yy.min(),xx.max()+1,yy.max()+1)
    sx=[outer[0],inner[0],inner[2],outer[2]];sy=[outer[1],inner[1],inner[3],outer[3]];dx=[24,64,448,488];dy=[24,64,448,576]
    assert all(sx[i+1]>sx[i] for i in range(3)) and all(sy[i+1]>sy[i] for i in range(3)),(outer,inner)
    target=Image.new('RGBA',(512,600))
    for row in range(3):
        for col in range(3):
            if col==row==1:continue
            tile=im.crop((sx[col],sy[row],sx[col+1],sy[row+1]));tile=tile.resize((dx[col+1]-dx[col],dy[row+1]-dy[row]),Image.Resampling.LANCZOS);target.paste(tile,(dx[col],dy[row]))
    # The full common square is guaranteed alpha zero, including the boundary.
    a=np.array(target);a[64:448,64:448]=0;return Image.fromarray(a)

report={}
for name,path in json.loads((ROOT/'art/render_work/album/image_sources.json').read_text()).items():
    im=cleanup(Image.open(path))
    size=(1024,1280) if name=='album_page' else ((512,600) if name.startswith('photo_frame') else ((512,512) if name=='photo_unknown' else (128,128)))
    if name.startswith('photo_frame'):im=frame(im)
    else:
        im.thumbnail(size,Image.Resampling.LANCZOS);canvas=Image.new('RGBA',size);canvas.paste(im,((size[0]-im.width)//2,(size[1]-im.height)//2));im=canvas
    im.save(OUT/(name+'.png'),optimize=True);report[name]={'size':list(size),'mode':'RGBA','source':'Built-in image_gen','alpha_preparation':'Isolated specks removed; resized with alpha; frames use 9-slice to a common transparent square'}
(ROOT/'docs/art/ALBUM_UI_MANIFEST.json').write_text(json.dumps(report,indent=2)+'\n')
print('Prepared',len(report),'RGBA PNGs')
