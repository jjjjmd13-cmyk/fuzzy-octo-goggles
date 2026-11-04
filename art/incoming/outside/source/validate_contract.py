"""Read final GLB bytes, validate actual dimensions, colour maps, separate joints and openings."""
import json,struct,io,math
from pathlib import Path
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parents[1]
COL=['floor','butter','wood','sky','red','pink','mint','blue','white','gold','blush','grain','dark','leaf','lavender','peach','pearl','ice','glass','cardboard','asphalt','tire','cream']
def readglb(p):
 b=p.read_bytes();magic,ver,length=struct.unpack_from('<III',b);assert magic==0x46546c67 and ver==2 and length==len(b)
 n,typ=struct.unpack_from('<II',b,12);assert typ==0x4e4f534a
 j=json.loads(b[20:20+n]);bl,bt=struct.unpack_from('<II',b,20+n);assert bt==0x004e4942;return j,b[28+n:28+n+bl]
def accessor(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];t={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];return np.ndarray((a['count'],n),dtype=t,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(t).itemsize*n),np.dtype(t).itemsize))
def matrix(n):
 if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
 x,y,z,w=n.get('rotation',[0,0,0,1]);r=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
 m=np.eye(4);m[:3,:3]=r@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
LIMITS={'box_small':500,'box_medium':500,'box_large':500,'truck':6000,'cart':2000,'mailbox':1000,'street_lamp':1500,'fence':800,'flower_bed':2000,'delivery_mat':300}
EXPECTED={'shop_front':['Door','Bell'],'open_sign':['Plate'],'truck':['Wheel_FL','Wheel_FR','Wheel_BL','Wheel_BR','Door_Back'],'cart':['Wheel_L','Wheel_R'],'mailbox':['Flag']}
report={};spec=json.loads((OUT/'validation_geometry.json').read_text());assert len(spec)==13
for p in sorted(OUT.glob('*.glb')):
 name=p.stem;j,b=readglb(p);assert all('uri' not in v for v in j['buffers']);assert not any(k in j for k in ['cameras','animations','skins'])
 images=[]
 for im in j['images']:
  assert im['mimeType']=='image/png' and 'uri' not in im;v=j['bufferViews'][im['bufferView']];png=Image.open(io.BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
  assert max(png.size)<=1024;images.append(list(png.size))
 for m in j['materials']:assert not any(k in m for k in ['normalTexture','occlusionTexture','emissiveTexture']);assert 'metallicRoughnessTexture' not in m['pbrMetallicRoughness']
 tri=0
 for me in j['meshes']:
  for pr in me['primitives']:
   assert pr.get('mode',4)==4;tri+=j['accessors'][pr['indices']]['count']//3
   at=pr['attributes'];assert 'TEXCOORD_0' in at and 'TEXCOORD_1' not in at
   m=j['materials'][pr['material']]
   if m['name'].startswith('Pastel_'):
    i=COL.index(next(c for c in COL if m['name'].startswith('Pastel_'+c)));uv=accessor(j,b,at['TEXCOORD_0']);assert np.all((uv[:,0]>i%8/8)&(uv[:,0]<(i%8+1)/8));assert np.all((uv[:,1]>i//8/4)&(uv[:,1]<(i//8+1)/4))
 assert tri==spec[name]['triangles'] and tri<=LIMITS.get(name,spec[name]['budget'])
 world={};node_by_name={};points=[];pernode={};walltri=[]
 def visit(i,parent):
  n=j['nodes'][i];m=parent@matrix(n);world[n['name']]=m;node_by_name[n['name']]=n
  if 'mesh' in n:
   out=[]
   for pr in j['meshes'][n['mesh']]['primitives']:
    pos=accessor(j,b,pr['attributes']['POSITION']);pp=(m@np.c_[pos,np.ones(len(pos))].T).T[:,:3];points.extend(pp);out.extend(pp)
    if name=='shop_front' and j['materials'][pr['material']]['name'].startswith('Pastel_butter'):walltri.extend(pp[accessor(j,b,pr['indices']).reshape(-1,3)])
   pernode[n['name']]=np.array(out)
  for c in n.get('children',[]):visit(c,m)
 for i in j['scenes'][j.get('scene',0)]['nodes']:visit(i,np.eye(4))
 pts=np.array(points);lo=pts.min(0);hi=pts.max(0);dim=hi-lo;assert np.allclose(dim,spec[name]['dimensions_m'],atol=1e-4)
 if name=='sign_outside':assert abs(hi[2])<1e-5 and np.allclose(dim,[2,.6,.1],atol=1e-4)
 elif name=='open_sign':assert abs(hi[1])<1e-5 and np.allclose(dim[:2],[.35,.25],atol=1e-4)
 else:assert abs(lo[1])<1e-5,(name,lo)
 for joint in EXPECTED.get(name,[]):assert joint in world and 'mesh' in node_by_name[joint]
 if name.startswith('box_'):
  for n in ['Lid_L','Lid_R']:assert n in world and 'mesh' in node_by_name[n]
  want={'box_small':[.3,.25,.25],'box_medium':[.5,.4,.4],'box_large':[.9,.6,.6]}[name];assert np.allclose(dim,want,atol=.0004)
 for n,s in spec[name]['joints'].items():
  assert n in world;assert np.allclose(world[n][:3,3],s['pivot'],atol=1e-5);assert np.allclose(world[n][:3,:3],np.eye(3),atol=1e-5)
  assert node_by_name[n].get('extras',{}).get('rotation_axis')==s['axis']
 if name=='street_lamp':assert 'Bulb' in world and 'mesh' not in node_by_name['Bulb'];assert abs(dim[1]-3)<1e-4
 if name=='truck':assert np.allclose(dim,[1.8,2,3.5],atol=1e-4)
 if name=='delivery_mat':assert np.allclose(dim,[1.6,.02,1],atol=1e-4)
 if name=='flower_bed':assert np.allclose(dim,[2,.4,.6],atol=1e-4)
 if name=='fence':
  assert np.allclose(dim[:2],[2,.8],atol=1e-4)
  ends=[sorted(set(tuple(q.round(5)) for q in pts[np.isclose(pts[:,0],x,atol=1e-5)][:,1:])) for x in [-1,1]];assert ends[0]==ends[1]
 if name=='shop_front':
  w=np.array(walltri);wp=w.reshape(-1,3);assert np.allclose(wp.max(0)-wp.min(0),[7,3,.2],atol=1e-4)
  # Project triangles to XY; no fixed wall triangle may cover the opening samples.
  def covers(t,x,y):
   a=t[0,:2];v=t[1,:2]-a;u=t[2,:2]-a;den=v[0]*u[1]-v[1]*u[0]
   if abs(den)<1e-9:return False
   q=np.array([x,y])-a;s=(q[0]*u[1]-q[1]*u[0])/den;r=(v[0]*q[1]-v[1]*q[0])/den;return s>=-1e-6 and r>=-1e-6 and s+r<=1.000001
  for x in [2.02,2.6,3.18]:
   for y in [.03,1.05,2.08]:assert not any(covers(t,x,y) for t in w),(x,y,'blocked doorway')
  for x in [-2,.25]:assert not any(covers(t,x,1.5) for t in w),'blocked window'
 assert (OUT/(name+'_preview.png')).exists()
 report[p.name]={'status':'PASS','triangles':tri,'dimensions_m':dim.round(5).tolist(),'embedded_pngs':images,'joints':spec[name]['joints'],'empty_nodes':spec[name]['empty_nodes']}
for name in ['paving','road','road_line']:
 im=Image.open(OUT/(name+'.png'));assert im.mode=='RGB' and im.size==(1024,1024);assert (OUT/(name+'_preview.png')).exists();report[name+'.png']={'status':'PASS','pixels':[1024,1024],'metres_per_tile':1}
assert len(report)==16
(OUT/'validation_contract.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS 16 assets: limits, exact parts/pivots/axes, passable facade openings, repeat fence ends, UV cells, embedded colour PNGs, dimensions and previews')
