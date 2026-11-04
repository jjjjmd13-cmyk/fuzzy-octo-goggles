"""Validate actual shipped bytes; Python + numpy + Pillow, no Blender needed."""
from pathlib import Path
import sys,re,hashlib,json,io
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parents[2]/'tools/art'))
from validate_slots import GLB
style=(HERE/'STYLE_B.md').read_text(encoding='utf-8')
colors=dict(re.findall(r'\| (\w+) \| #(\w{6}) \|',style))
rules={m[0]:(float(m[1]),float(m[2]),int(m[3]),float(m[4])) for m in re.findall(r'\| (\w+) \| [^|]+ \| ([\d.]+) \| ([\d.]+) \| (\d+) \| ([\d.]+) \|',style)}
report=[]
for name,axis,target in [('shower',1,.25),('dryer',2,.30),('brush',1,.20),('towel',0,.25),('dog',1,.35)]:
    f=GLB(HERE/('test_b_'+name+'.glb'));g=f.g
    assert g['asset']['version']=='2.0' and not any(g.get(k) for k in ['skins','animations','cameras','extensionsRequired'])
    roots=g['scenes'][g.get('scene',0)]['nodes'];assert len(roots)==1
    root=g['nodes'][roots[0]];assert np.allclose(f.world(roots[0]),np.eye(4))
    assert root['extras']['style_sha256']==hashlib.sha256(style.encode()).hexdigest()
    assert root['extras']['units']=='metres' and root['extras']['up']=='+Y' and root['extras']['forward']=='-Z'
    assert all('uri' not in b for b in g['buffers'])
    images=[]
    for im in g['images']:
        assert im['mimeType']=='image/png' and 'bufferView' in im and 'uri' not in im
        view=g['bufferViews'][im['bufferView']];off=view.get('byteOffset',0)
        image=Image.open(io.BytesIO(f.bin[off:off+view['byteLength']])).convert('RGB')
        assert max(image.size)<=1024;images.append(np.asarray(image))
    def texture(t):return images[g['textures'][t['index']]['source']]
    for mat in g['materials']:
        _,kind,color,*extra=mat['name'].split('_');rough,metal,size,strength=rules[kind]
        assert not any(mat.get(k) for k in ['emissiveTexture','occlusionTexture'])
        assert np.allclose(mat.get('emissiveFactor',[0,0,0]),0)
        assert not mat.get('extensions') and mat.get('alphaMode','OPAQUE')=='OPAQUE'
        pbr=mat['pbrMetallicRoughness'];albedo=texture(pbr['baseColorTexture']);orm=texture(pbr['metallicRoughnessTexture'])/255
        assert albedo.shape[:2]==(size,size)
        expected=np.array(list(bytes.fromhex(colors[color])));assert np.max(abs(albedo-expected))<=expected.max()*.041+1
        assert np.allclose(pbr.get('baseColorFactor',[1]*4),1)
        assert np.max(abs(orm[:,:,2]*pbr.get('metallicFactor',1)-metal))<=1/255+.0001
        if extra:rough=.24
        assert np.max(abs(orm[:,:,1]*pbr.get('roughnessFactor',1)-rough))<.026
        if not extra:
            assert abs(mat['normalTexture'].get('scale',1)-strength)<1e-6
            normals=texture(mat['normalTexture'])/255*2-1
            assert np.max(abs(np.linalg.norm(normals,axis=2)-1))<.015
    tris=0
    for _,node,p in f.meshes():
        assert p.get('mode',4)==4
        ids=f.acc(p['indices']).reshape(-1,3);v=f.acc(p['attributes']['POSITION']);tris+=len(ids)
        assert ids.min()>=0 and ids.max()<len(v)
        t=v[ids];area=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)/2
        assert np.all(area>1e-12),(name,'degenerate faces')
        normal=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(normal,axis=1)-1))<.001
        uv=f.acc(p['attributes']['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1.5 # repeat seam on directional spheres
        tan=f.acc(p['attributes']['TANGENT']);assert np.max(abs(np.linalg.norm(tan[:,:3],axis=1)-1))<.001
    assert 0<tris<=(8000 if name=='dog' else 3000)
    lo,hi=f.bounds();dims=hi-lo;assert abs(dims[axis]-target)<2e-6
    if name=='towel':assert abs(dims[1]-.15)<.003 and hi[2]<0
    if name=='dog':assert abs(lo[1])<.001
    fan=None
    if name=='dryer':
        fan=f.point('Fan');a,c=f.bounds(['Fan']);assert np.linalg.norm(((a+c)/2-fan)[:2])<.003 # odd blade count has asymmetric AABB
        assert np.allclose(fan,np.array([0,.066,-.139])*(.30/.2925),atol=.004)
        node=g['nodes'][f.byname['Fan']];assert node['extras']['motion_axis']=='Z' and 'mesh' in node
        assert f.parents[f.byname['Fan']]==roots[0]
    row={'name':name,'result':'PASS','triangles':tris,'dimensions_m':dims.round(6).tolist(),'root_identity':True,'png_count':len(images),'max_png':max(max(im.shape[:2]) for im in images),'fan_pivot_m':fan.tolist() if fan is not None else None,'style_sha256':root['extras']['style_sha256'],'sha256':hashlib.sha256(f.path.read_bytes()).hexdigest()}
    print(name,tris,dims.round(6),len(images),'PNGs',flush=True);report.append(row)
(HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
