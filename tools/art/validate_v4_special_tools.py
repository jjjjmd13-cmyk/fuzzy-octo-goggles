"""Contract checks on the actual 14 exported GLBs, independent of Blender state."""
import sys,json,io,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parent))
from validate_slots import GLB
ROOT=Path(__file__).resolve().parents[2]
PREVIEW=ROOT/'art/incoming/special_tools'
SPECS={
'shower_massage':('y',.30,{'Dial':('Z','rotate')}),
'shower_rainbow':('y',.35,{'Ring':('Z','rotate')}),
'foam_sponge':('x',.15,{}),'foam_cloud':('z',.40,{'Bubbles':('XYZ','float')}),
'towel':('x',.25,{}),'towel_thick':('x',.28,{}),'towel_microfiber':('x',.28,{}),
'towel_mitt':('y',.20,{}),'towel_cloud':('x',.30,{}),
'dryer_twin':('z',.40,{'Fan_L':('Z','rotate'),'Fan_R':('Z','rotate')}),
'dryer_turbo':('z',.42,{'Fan':('Z','rotate')}),'dryer_tornado':('z',.45,{'Spiral':('Z','rotate')}),
'brush_twin':('y',.22,{}),'brush_sparkle':('y',.25,{'Head':('Z','rotate')})}

def validate(name,spec):
 axis,size,joints=spec;path=ROOT/'assets/models/tools'/f'{name}.glb';f=GLB(path);g=f.g
 assert g['asset']['version']=='2.0'
 assert not any(g.get(k) for k in ['skins','animations','cameras','extensionsRequired'])
 roots=g['scenes'][g.get('scene',0)]['nodes'];assert len(roots)==1
 root=roots[0];n=g['nodes'][root]
 assert n['name']==name and np.allclose(f.world(root),np.eye(4))
 assert n['extras']['units']=='metres' and n['extras']['forward']=='-Z'
 assert all('uri' not in item for item in g['buffers']+g['images'])
 tris=0
 for _,node,p in f.meshes():
  assert p.get('mode',4)==4 and 'TEXCOORD_0' in p['attributes']
  ids=f.acc(p['indices']).reshape(-1,3);v=f.acc(p['attributes']['POSITION']);tris+=len(ids)
  assert ids.min()>=0 and ids.max()<len(v)
  t=v[ids];area=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)/2
  assert np.all(area>1e-12),(name,node['name'],'degenerate triangles')
  ns=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(ns,axis=1)-1))<.001
  uv=f.acc(p['attributes']['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1
 assert 0<tris<=3000,(name,tris)
 assert len(g['images'])==1
 im=g['images'][0];assert im['mimeType']=='image/png' and 'bufferView' in im
 view=g['bufferViews'][im['bufferView']];off=view.get('byteOffset',0)
 image=Image.open(io.BytesIO(f.bin[off:off+view['byteLength']]))
 assert image.format=='PNG' and image.size==(128,128)
 # Verify the shipped palette bytes and every vertex UV's selected swatch.
 expected={'sky':'8FD3F4','red':'FF6B6B','pink':'FF9EC4','mint':'B8E3D3','wood':'E8C9A0','silver':'DDE5EA','cream':'FFF1D8','dark':'42576A','white':'FFFFFF','slate':'759AB0','wood_edge':'D4AF85','blush':'F9C3D8','pearl':'F2EEE9','gold':'E9BE61','peach':'FFAB8A','lemon':'FFE58C','lime':'B9E7A2','aqua':'A2DCEB','periwinkle':'A8BAF0','lavender':'CAA6EB','rose':'F2B5DB','ice':'D6ECFA','seam':'D4F2E9','glass':'8FD3F4'}
 rgba=np.asarray(image.convert('RGBA'))
 for _,node,p in f.meshes():
  mat=g['materials'][p['material']];color=mat['name'].removeprefix('Pastel_').split('.')[0]
  uv=f.acc(p['attributes']['TEXCOORD_0']);xy=np.floor(uv*128).astype(int)
  assert np.all(xy>=0) and np.all(xy<128),(name,color,'unmapped UV')
  samples=rgba[xy[:,1],xy[:,0]];rgb=np.array(list(bytes.fromhex(expected[color])))
  assert np.all(samples[:,:3]==rgb),(name,color,'wrong pigment')
  assert np.all(samples[:,3]==(51 if color=='glass' else 255))
 for m in g['materials']:
  assert not any(k in m for k in ['normalTexture','occlusionTexture','emissiveTexture'])
  assert np.allclose(m.get('emissiveFactor',[0,0,0]),[0,0,0])
  pb=m['pbrMetallicRoughness'];assert 'baseColorTexture' in pb and 'metallicRoughnessTexture' not in pb
  assert np.allclose(pb.get('baseColorFactor',[1]*4),[1]*4)
  assert pb.get('metallicFactor',1)==0
 lo,hi=f.bounds();dims=hi-lo;assert abs(dims['xyz'.index(axis)]-size)<2e-6,(name,dims,size)
 assert lo[2]<-.02
 declared=json.loads((PREVIEW/'validation.json').read_text())[name]['joints']
 for part,(ax,motion) in joints.items():
  i=f.byname[part];node=g['nodes'][i]
  assert 'mesh' in node and f.parents[i]==root
  assert np.allclose(f.point(part),declared[part]['pivot_m'],atol=2e-6)
  assert node['extras']['motion_axis']==ax and node['extras']['motion_type']==motion
  plo,phi=f.bounds([part]);center=(plo+phi)/2;pivot=f.point(part)
  if part!='Bubbles':assert np.linalg.norm((center-pivot)[:2])<(.008 if part=='Spiral' else .002),(part,center,pivot)
  else:assert np.all(pivot>=plo) and np.all(pivot<=phi)
 if name=='dryer_twin':assert f.point('Fan_L')[0]<0<f.point('Fan_R')[0]
 if name=='foam_sponge':assert np.allclose(dims[:2],[.15,.10],atol=2e-6) and abs(dims[2]-.06)<.002,dims
 if name in ['towel','towel_thick','towel_microfiber']:
  assert abs(dims[1]-({ 'towel':.15,'towel_thick':.18,'towel_microfiber':.18}[name]))<.003
 if name in ['foam_cloud','brush_sparkle']:
  assert any(m.get('alphaMode')=='BLEND' for m in g['materials']),name
 png=PREVIEW/f'{name}.png';preview=Image.open(png);assert preview.size==(640,640)
 return {'file':str(path.relative_to(ROOT)),'result':'PASS','triangles':tris,'dimensions_m':dims.round(6).tolist(),'root_origin_m':[0,0,0],'embedded_pngs':[list(image.size)],'joints':declared,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

if __name__=='__main__':
 reports=[validate(n,s) for n,s in SPECS.items()]
 (PREVIEW/'artifact_validation.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2)+'\n')
 for r in reports:print(r['result'],Path(r['file']).stem,r['triangles'],r['dimensions_m'])
