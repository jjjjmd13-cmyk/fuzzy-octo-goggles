"""Lossless PNG filtering + deduplication of embedded images. Pixels/geometry unchanged.
Usage: python optimize_glb.py test_b_dog.glb
"""
from pathlib import Path
import sys,struct,json,io,hashlib
from PIL import Image

def optimize(path):
    raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
    g=json.loads(raw[20:20+length]);binary=raw[28+length:];views=g['bufferViews']
    replacements={};image_map={};seen={};unique=[];removed=set()
    for i,im in enumerate(g.get('images',[])):
        vi=im['bufferView'];v=views[vi];off=v.get('byteOffset',0);data=binary[off:off+v['byteLength']]
        digest=hashlib.sha256(data).digest()
        if digest in seen:
            image_map[i]=seen[digest];removed.add(vi);continue
        image_map[i]=len(unique);seen[digest]=len(unique);unique.append(im)
        original=Image.open(io.BytesIO(data));pixels=original.convert('RGBA').tobytes()
        out=io.BytesIO();original.save(out,format='PNG',optimize=True)
        filtered=out.getvalue()
        assert Image.open(io.BytesIO(filtered)).convert('RGBA').tobytes()==pixels
        replacements[vi]=filtered
    for texture in g.get('textures',[]):texture['source']=image_map[texture['source']]
    g['images']=unique
    new_binary=bytearray();new_views=[];view_map={}
    for i,v in enumerate(views):
        if i in removed:continue
        while len(new_binary)%4:new_binary.append(0)
        off=v.get('byteOffset',0);data=replacements.get(i,binary[off:off+v['byteLength']])
        view_map[i]=len(new_views);nv=dict(v,byteOffset=len(new_binary),byteLength=len(data));new_views.append(nv);new_binary.extend(data)
    g['bufferViews']=new_views
    def remap(obj):
        if isinstance(obj,dict):
            for key,val in obj.items():
                if key=='bufferView':obj[key]=view_map[val]
                else:remap(val)
        elif isinstance(obj,list):
            for val in obj:remap(val)
    remap(g)
    while len(new_binary)%4:new_binary.append(0)
    g['buffers'][0]['byteLength']=len(new_binary)
    data=json.dumps(g,separators=(',',':'),ensure_ascii=False).encode()
    data+=b' '*((-len(data))%4)
    final=struct.pack('<III',0x46546c67,2,28+len(data)+len(new_binary))+struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',len(new_binary),0x004e4942)+new_binary
    path.write_bytes(final);print(path.name,len(raw),'->',len(final),'bytes; identical pixels and geometry')

if __name__=='__main__':
    for arg in sys.argv[1:]:optimize(Path(arg))
