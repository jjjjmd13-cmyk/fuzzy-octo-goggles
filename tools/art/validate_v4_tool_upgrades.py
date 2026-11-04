"""Inspect the exported GLB bytes; numpy/Pillow, no Blender required."""
import io,json,sys
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parent))
from validate_slots import GLB
ROOT=Path(__file__).resolve().parents[2]
SPECS={
 'brush':('y',.20,{}), 'brush_slicker':('y',.20,{}),
 'brush_electric':('y',.22,{'Head':('Z','rotate')}),
 'shower_wide':('y',.28,{}), 'shower_rain':('y',.32,{}),
 'foam_pump':('y',.22,{'Pump':('Y','translate')}),
 'foam_cannon':('z',.35,{}), 'dryer_big':('z',.40,{'Fan':('Z','rotate')}),
 'scissors':('z',.18,{'Blade_L':('Y','rotate'),'Blade_R':('Y','rotate')})}

def validate(name,spec):
 axis,size,joints=spec;path=ROOT/'assets/models/tools'/f'{name}.glb';f=GLB(path);g=f.g
 assert g['asset']['version']=='2.0'
 assert not any(g.get(k) for k in ['skins','animations','cameras','extensionsRequired'])
 assert len(g['scenes'][g.get('scene',0)]['nodes'])==1
 root_idx=g['scenes'][g.get('scene',0)]['nodes'][0];node=g['nodes'][root_idx]
 assert node['name']==name and np.allclose(f.world(root_idx),np.eye(4))
 assert node['extras']['units']=='metres' and node['extras']['forward']=='-Z'
 assert all('uri' not in buf for buf in g['buffers'])
 tris=0
 for _,n,p in f.meshes():
  assert p.get('mode',4)==4 and 'TEXCOORD_0' in p['attributes']
  ids=f.acc(p['indices']).reshape(-1,3);v=f.acc(p['attributes']['POSITION']);tris+=len(ids)
  assert ids.min()>=0 and ids.max()<len(v)
  t=v[ids];area=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)/2
  assert np.all(area>1e-12),(name,n['name'],'degenerate triangles')
  normals=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(normals,axis=1)-1))<.001
 assert tris<=3000
 assert len(g['images'])==1
 im=g['images'][0];assert im.get('mimeType')=='image/png' and 'bufferView' in im and 'uri' not in im
 view=g['bufferViews'][im['bufferView']];off=view.get('byteOffset',0)
 image=Image.open(io.BytesIO(f.bin[off:off+view['byteLength']]))
 assert image.format=='PNG' and max(image.size)<=1024
 assert len(g['materials'])>=2 # Preserve the existing multi-surface highlight contract.
 for m in g['materials']:
  assert not any(k in m for k in ['normalTexture','occlusionTexture','emissiveTexture'])
  pbr=m['pbrMetallicRoughness'];assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' not in pbr
  assert np.allclose(pbr.get('baseColorFactor',[1]*4),[1]*4)
 lo,hi=f.bounds();dims=hi-lo;ai='xyz'.index(axis)
 assert abs(dims[ai]-size)<2e-6,(name,dims,size)
 assert lo[2]<-.02 # Working face/nozzle extends in front of the grip (-Z).
 declared=json.loads((ROOT/'art/incoming/tool_upgrades/validation.json').read_text())[name]['joints']
 for part,(ax,motion) in joints.items():
  assert part in f.byname and 'mesh' in g['nodes'][f.byname[part]]
  assert f.parents[f.byname[part]]==root_idx
  assert np.allclose(f.point(part),declared[part]['pivot_m'],atol=2e-6)
  extras=g['nodes'][f.byname[part]]['extras'];assert extras['motion_axis']==ax and extras['motion_type']==motion
 if name=='scissors':assert np.allclose(f.point('Blade_L'),f.point('Blade_R'))
 return {'file':str(path.relative_to(ROOT)),'result':'PASS','triangles':tris,'materials':len(g['materials']),'dimensions_m':dims.round(6).tolist(),'bounds_m':[lo.round(6).tolist(),hi.round(6).tolist()],'embedded_pngs':[list(image.size)],'joints':declared}

if __name__=='__main__':
 reports=[validate(n,s) for n,s in SPECS.items()]
 dest=ROOT/'art/incoming/tool_upgrades/artifact_validation.json'
 dest.write_text(json.dumps(reports,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(reports,ensure_ascii=False,indent=2))
