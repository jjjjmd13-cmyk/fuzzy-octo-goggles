"""Inspect delivered GLB bytes, bounds, UV colour cells, texture embedding and names."""
import json,struct,io,math
from pathlib import Path
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parents[1]
COL=['floor','butter','wood','sky','red','pink','mint','blue','white','gold','blush','grain','dark','leaf','lavender','peach','pearl','ice','glass']
TEX=['wall_stripe','wall_bubble','wall_paw','floor_wood','floor_check','floor_star']
def readglb(p):
 b=p.read_bytes();magic,ver,length=struct.unpack_from('<III',b);assert magic==0x46546c67 and ver==2 and length==len(b)
 n,typ=struct.unpack_from('<II',b,12);assert typ==0x4e4f534a
 j=json.loads(b[20:20+n]);bl,bt=struct.unpack_from('<II',b,20+n);assert bt==0x004e4942;return j,b[28+n:28+n+bl]
def accessor(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];types={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'};n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];t=types[a['componentType']];return np.ndarray((a['count'],n),dtype=t,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(t).itemsize*n),np.dtype(t).itemsize))
def matrix(n):
 if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
 x,y,z,w=n.get('rotation',[0,0,0,1]);r=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
 m=np.eye(4);m[:3,:3]=r@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
report={};geom=json.loads((OUT/'validation_geometry.json').read_text());assert len(geom)==24
for p in sorted(OUT.glob('*.glb')):
 j,b=readglb(p);assert all('uri' not in v for v in j['buffers']);assert 'cameras' not in j and 'animations' not in j
 for im in j['images']:
  assert im['mimeType']=='image/png' and 'uri' not in im;v=j['bufferViews'][im['bufferView']];png=Image.open(io.BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
  assert max(png.size)<=1024
 for m in j['materials']:assert not any(k in m for k in ['normalTexture','occlusionTexture','emissiveTexture']);assert 'metallicRoughnessTexture' not in m['pbrMetallicRoughness']
 tri=0;uvchecked=0
 for me in j['meshes']:
  for pr in me['primitives']:
   assert pr.get('mode',4)==4;tri+=j['accessors'][pr['indices']]['count']//3
   at=pr['attributes'];assert 'TEXCOORD_0' in at and 'TEXCOORD_1' not in at
   uv=accessor(j,b,at['TEXCOORD_0']);m=j['materials'][pr['material']];col=next(c for c in COL if m['name'].startswith('Pastel_'+c));i=COL.index(col)
   # glTF texture V is PNG top-to-bottom. Every primitive samples its named colour.
   assert np.all((uv[:,0]>(i%8)/8)&(uv[:,0]<(i%8+1)/8)),(p,col,'u')
   assert np.all((uv[:,1]>(i//8)/4)&(uv[:,1]<(i//8+1)/4)),(p,col,'v')
   uvchecked+=len(uv)
 assert tri==geom[p.stem]['triangles'] and tri<=geom[p.stem]['budget']
 points=[];world={}
 def visit(i,parent):
  n=j['nodes'][i];m=parent@matrix(n);world[n['name']]=m
  if 'mesh' in n:
   for pr in j['meshes'][n['mesh']]['primitives']:
    pos=accessor(j,b,pr['attributes']['POSITION']);points.extend((m@np.c_[pos,np.ones(len(pos))].T).T[:,:3])
  for c in n.get('children',[]):visit(c,m)
 for i in j['scenes'][j.get('scene',0)]['nodes']:visit(i,np.eye(4))
 pts=np.array(points);lo=pts.min(0);hi=pts.max(0);dim=hi-lo
 if p.stem.startswith(('sign_','art_')):
  assert abs(hi[2])<1e-5 and np.linalg.norm((lo+hi)[:2])<1e-5
  target=[1.6,.5,.08] if p.stem.startswith('sign_') else [.6,.5,.05];assert np.allclose(dim,target,atol=1e-4)
 elif p.stem.startswith('lamp_'):assert abs(hi[1])<1e-5 and 'Bulb' in world
 else:assert abs(lo[1])<1e-5
 if p.stem.startswith('tub_'):
  for name in ['Stand','Tub','Plug']:assert name in world
 if p.stem=='art_clock':
  for n in ['Hand_H','Hand_M']:assert n in world and np.linalg.norm(world[n][:2,3])<1e-5 and np.allclose(world[n][:3,:3],np.eye(3),atol=1e-5)
 report[p.name]={'status':'PASS','triangles':tri,'dimensions_m':dim.round(5).tolist(),'checked_uv_vertices':uvchecked,'embedded_png_sizes':[list(png.size)],'parts':list(world)}
for name in TEX:
 im=Image.open(OUT/(name+'.png'));assert im.size==(1024,1024) and im.mode=='RGB';assert (OUT/(name+'_preview.png')).exists();report[name+'.png']={'status':'PASS','pixels':[1024,1024],'metres_per_tile':1,'colour_only':True}
assert len(report)==30
for p in OUT.glob('*.glb'):assert (OUT/(p.stem+'_preview.png')).exists(),p.name
(OUT/'validation_contract.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS: 30 assets; dimensions/origins, triangle limits, embedded PNGs, UV colour cells, named parts and 30 previews')
