"""Check the actual exported bath bytes and game-critical standing surfaces."""
import json,struct,io,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parents[1]
def accessor(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']]
 dt=np.dtype({5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']]);n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
 return np.ndarray((a['count'],n),dtype=dt,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*n),dt.itemsize))
def matrix(n):
 if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
 x,y,z,w=n.get('rotation',[0,0,0,1]);r=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
 m=np.eye(4);m[:3,:3]=r@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
def surface_hits(tris,x,z):
 hits=[]
 for t in tris:
  a=t[0,[0,2]];v=t[1,[0,2]]-a;u=t[2,[0,2]]-a;den=v[0]*u[1]-v[1]*u[0]
  if abs(den)<1e-10:continue
  q=np.array([x,z])-a;s=(q[0]*u[1]-q[1]*u[0])/den;r=(v[0]*q[1]-v[1]*q[0])/den
  if s>=-1e-6 and r>=-1e-6 and s+r<=1.000001:hits.append(float(t[0,1]+s*(t[1,1]-t[0,1])+r*(t[2,1]-t[0,1])))
 return hits
reports={}
for kind in ['wood','claw','shell']:
 name='tub_'+kind;p=OUT/(name+'.glb');raw=p.read_bytes()
 magic,version,length=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and length==len(raw)
 size=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+size]);b=raw[28+size:]
 assert not any(k in j for k in ['skins','animations','cameras'])
 assert all('uri' not in v for v in j['buffers'])
 sizes=[]
 for im in j['images']:
  assert im['mimeType']=='image/png' and 'uri' not in im
  v=j['bufferViews'][im['bufferView']];png=Image.open(io.BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
  assert max(png.size)<=1024;sizes.append(list(png.size))
 for mat in j['materials']:
  assert all(k not in mat for k in ['normalTexture','occlusionTexture','emissiveTexture'])
  assert 'metallicRoughnessTexture' not in mat['pbrMetallicRoughness']
  assert 'baseColorTexture' in mat['pbrMetallicRoughness']
 parts={};world={};tri_count=0
 def visit(i,parent):
  global tri_count
  node=j['nodes'][i];m=parent@matrix(node);world[node['name']]=m
  if 'mesh' in node:
   triangles=[]
   for pr in j['meshes'][node['mesh']]['primitives']:
    assert pr.get('mode',4)==4
    pos=accessor(j,b,pr['attributes']['POSITION']);pos=(m@np.c_[pos,np.ones(len(pos))].T).T[:,:3]
    ix=accessor(j,b,pr['indices']).reshape(-1,3);tri_count+=len(ix);triangles.extend(pos[ix])
   parts[node['name']]=np.array(triangles)
  for c in node.get('children',[]):visit(c,m)
 for i in j['scenes'][j.get('scene',0)]['nodes']:visit(i,np.eye(4))
 assert set(parts)=={'Stand','Tub','Plug'},parts.keys()
 assert np.allclose(world[name][:3,3],0,atol=1e-6)
 assert tri_count<=4000,(name,tri_count)
 allpts=np.concatenate(list(parts.values())).reshape(-1,3);lo=allpts.min(0);hi=allpts.max(0)
 assert hi[0]-lo[0]<=1.6+1e-5 and hi[2]-lo[2]<=1.1+1e-5
 assert np.allclose([lo[0]+hi[0],lo[2]+hi[2],lo[1]],[0,0,0],atol=1e-4),(name,lo,hi)
 tub=parts['Tub'];points=tub.reshape(-1,3)
 floor=points[np.isclose(points[:,1],.92,atol=1e-5)]
 assert len(floor)>24
 floor_size=np.ptp(floor[:,[0,2]],axis=0);assert floor_size[0]>=1.05 and floor_size[1]>=.949
 # Nine locations under a 0.60m dog must see the .92m flat floor as the top surface.
 for x in [-.28,0,.28]:
  for z in [-.11,0,.11]:
   hits=surface_hits(tub,x,z);assert hits and abs(max(hits)-.92)<1e-5,(name,x,z,hits)
 front=points[np.abs(points[:,0])<.055];front=front[front[:,2]<-.46]
 assert abs(front[:,1].max()-1.10)<.008,(name,'front',front[:,1].max())
 rear=points[np.abs(points[:,0])<.055];rear=rear[rear[:,2]>.46]
 expected_rear=1.5 if kind=='shell' else 1.27
 assert abs(rear[:,1].max()-expected_rear)<.008
 side=points[np.abs(points[:,2])<.025];assert abs(side[:,1].max()-1.27)<.03
 plug=parts['Plug'].reshape(-1,3);center=(plug.min(0)+plug.max(0))/2
 assert np.allclose(world['Plug'][:3,3],center,atol=2e-5),(name,'Plug center',center)
 plug_node=next(n for n in j['nodes'] if n['name']=='Plug')
 assert any(j['materials'][pr['material']]['name'].startswith('Pastel_red') for pr in j['meshes'][plug_node['mesh']]['primitives'])
 if kind=='claw':
  stand=parts['Stand'].reshape(-1,3)
  assert abs(stand[:,1].max()-.40)<1e-5
  assert np.all(np.abs(stand[:,0])>.30) # no central box, column or connecting panel
  assert all(np.any((stand[:,0]*sx>0)&(stand[:,2]*sz>0)) for sx in [-1,1] for sz in [-1,1])
 reports[name+'.glb']={'status':'PASS','triangles':tri_count,'footprint_xz_m':np.ptp(allpts[:,[0,2]],axis=0).round(5).tolist(),
  'floor_y':.92,'floor_clear_xz_m':floor_size.round(5).tolist(),'floor_samples_checked':9,
  'front_rim_y':round(float(front[:,1].max()),5),'rear_rim_y':round(float(rear[:,1].max()),5),
  'parts':list(parts),'plug_origin':world['Plug'][:3,3].round(5).tolist(),'embedded_png_sizes':sizes,
  'sha256':hashlib.sha256(raw).hexdigest()}
(OUT/'validation_tubs.json').write_text(json.dumps(reports,indent=2)+'\n')
print(json.dumps(reports,indent=2))
