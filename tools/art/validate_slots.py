"""Validate delivery contracts directly on GLB bytes (Python: numpy, Pillow, shapely).
No Blender state or source assertions substitute for checking the exported artifact.
"""
from pathlib import Path
import json,struct,io,sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
PREFIXES=('Eye','Pupil','Glint','Nose','Mouth','Tongue','Collar','NoFur')
BUDGETS={'dog':8000,'owner':4000,'tub':4000,'turntable':800,'chair':1500}
class GLB:
    def __init__(self,p):
        self.path=p;b=p.read_bytes();magic,version,total=struct.unpack_from('<III',b)
        assert magic==0x46546c67 and version==2 and total==len(b)
        n,t=struct.unpack_from('<II',b,12);assert t==0x4e4f534a
        self.g=json.loads(b[20:20+n]);n2,t=struct.unpack_from('<II',b,20+n);assert t==0x004e4942
        self.bin=b[28+n:28+n+n2];self.parents={c:i for i,n in enumerate(self.g['nodes']) for c in n.get('children',[])}
        self.byname={n['name']:i for i,n in enumerate(self.g['nodes'])};assert len(self.byname)==len(self.g['nodes'])
    def acc(self,i):
        a=self.g['accessors'][i];v=self.g['bufferViews'][a['bufferView']]
        types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1',5122:'<i2',5120:'i1'};dims={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
        dt=np.dtype(types[a['componentType']]);n=dims[a['type']];stride=v.get('byteStride',dt.itemsize*n)
        result=np.ndarray((a['count'],n),dtype=dt,buffer=self.bin,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(stride,dt.itemsize)).copy()
        assert np.all(np.isfinite(result));return result
    def world(self,i):
        n=self.g['nodes'][i];m=np.eye(4);assert not n.get('matrix') and not n.get('rotation'),n
        m[:3,:3]=np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0])
        return self.world(self.parents[i])@m if i in self.parents else m
    def point(self,name):return self.world(self.byname[name])[:3,3]
    def hasparent(self,name,parent):assert self.parents[self.byname[name]]==self.byname[parent],name
    def meshes(self):
        for i,n in enumerate(self.g['nodes']):
            if 'mesh' in n:
                for p in self.g['meshes'][n['mesh']]['primitives']:yield i,n,p
    def bounds(self,names=None):
        out=[]
        for i,n,p in self.meshes():
            if names and n['name'] not in names:continue
            v=self.acc(p['attributes']['POSITION']);m=self.world(i);out.append(v@m[:3,:3].T+m[:3,3])
        v=np.concatenate(out);return v.min(0),v.max(0)

def validate(path):
    f=GLB(path);g=f.g;slot=path.parent.name
    assert not g.get('skins') and not g.get('animations') and not g.get('cameras')
    assert not g.get('extensionsRequired');assert not any('uri' in b for b in g['buffers'])
    tris=sum(len(f.acc(p['indices']))//3 for _,_,p in f.meshes());assert tris<=BUDGETS.get(slot,10000),(path,tris)
    for m in g.get('materials',[]):
        assert not m.get('normalTexture') and not m.get('occlusionTexture') and not m.get('emissiveTexture')
        assert not m.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture')
    imgs=[]
    for im in g.get('images',[]):
        assert im.get('mimeType')=='image/png' and 'bufferView' in im and 'uri' not in im
        v=g['bufferViews'][im['bufferView']];im=Image.open(io.BytesIO(f.bin[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
        assert max(im.size)<=(2048 if slot=='dog' else 1024);imgs.append(im)
    lo,hi=f.bounds();dims=hi-lo
    report={'file':str(path.relative_to(ROOT)),'triangles':tris,'mesh_nodes':sum('mesh' in n for n in g['nodes']),'bounds_m':[lo.tolist(),hi.tolist()],'dimensions_m':dims.tolist(),'embedded_pngs':[list(im.size) for im in imgs]}
    # Check nondegenerate triangles and finite, normalized normals on every primitive.
    for _,n,p in f.meshes():
        v=f.acc(p['attributes']['POSITION']);ids=f.acc(p['indices']).reshape(-1,3);t=v[ids]
        area=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)*.5
        assert np.all(area>1e-12),(n['name'],'degenerate triangles',sum(area<=1e-12))
        normal=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(normal,axis=1)-1))<.001
    if slot=='dog':
        required=['Head','Chest','Eye_L','Eye_R','Ear_L','Ear_R','Tail_1','Tail_2','Tail_3','Leg_FL','Leg_FR','Mouth','Tongue','Nose']
        assert all(x in f.byname for x in required);assert len(imgs)==1
        for x in ['Eye_L','Eye_R','Ear_L','Ear_R','Mouth','Tongue','Nose']:f.hasparent(x,'Head')
        f.hasparent('Tail_2','Tail_1');f.hasparent('Tail_3','Tail_2')
        for a,b in [('Eye_L','Eye_R'),('Ear_L','Ear_R'),('Leg_FL','Leg_FR')]:assert f.point(a)[0]<0<f.point(b)[0]
        assert f.point('Nose')[2]<f.point('Head')[2] # faces -Z
        assert .56<dims[1]<.64 and .54<dims[2]<.66 and abs(lo[1])<.002
        pivots={'Head':(0,.325,-.015),'Chest':(0,.247,-.048),'Ear_L':(-.139,.522,-.032),'Ear_R':(.139,.522,-.032),'Leg_FL':(-.083,.291,-.056),'Leg_FR':(.083,.291,-.056),'Tail_1':(0,.088,.169),'Tail_2':(0,.121,.245),'Tail_3':(0,.199,.27),'Eye_L':(-.073,.455,-.191),'Eye_R':(.073,.455,-.191),'Mouth':(0,.353,-.203),'Tongue':(0,.351,-.218),'Nose':(0,.405,-.251)}
        for name,pt in pivots.items():assert np.allclose(f.point(name),pt,atol=2e-6),(name,f.point(name),pt)
        # Geometric UV intersection, including different fur objects in the same atlas.
        from shapely.geometry import Polygon
        from shapely.strtree import STRtree
        polygons=[]
        for _,n,p in f.meshes():
            if n['name'].startswith(PREFIXES):continue
            m=g['materials'][p['material']];pbr=m['pbrMetallicRoughness'];assert 'baseColorTexture' in pbr
            uv=f.acc(p['attributes']['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1
            for ids in f.acc(p['indices']).reshape(-1,3):
                poly=Polygon(uv[ids]);assert poly.area>1e-13;polygons.append(poly)
        tree=STRtree(polygons)
        for i,p in enumerate(polygons):
            for j in tree.query(p):
                if j>i:assert p.intersection(polygons[j]).area<1e-11,('Fur UV overlap',i,int(j))
        report['fur_uv_triangles_checked']=len(polygons);report['fur_uv_positive_area_overlaps']=0
        report['joint_pivots_m']={name:f.point(name).tolist() for name in required}
        # Texture contains exclusively the intended unshaded palette, no baked light/state.
        colors=set(map(tuple,np.asarray(imgs[0].convert('RGB')).reshape(-1,3).tolist()));expected={(245,222,179),(255,241,216),(189,132,84),(255,255,255)}
        assert colors<=expected,colors;report['clean_albedo_colors']=[list(c) for c in sorted(colors)]
    elif slot=='owner':
        for name in ['Body','Head','Arm_L','Arm_R','Leg_L','Leg_R']:assert name in f.byname
        for name in ['Head','Arm_L','Arm_R','Leg_L','Leg_R']:f.hasparent(name,'Body')
        assert np.allclose(f.point('Body'),0)
        assert {'Shirt','Hat'}<={m['name'] for m in g['materials']}
        for m in g['materials']:
            if m['name'] in ['Shirt','Hat']:assert m['pbrMetallicRoughness'].get('baseColorFactor',[1]*4)==[1,1,1,1]
        assert 1.50<dims[1]<1.60 and abs(lo[1])<.002
        for a,b in [('Arm_L','Arm_R'),('Leg_L','Leg_R')]:assert f.point(a)[0]<0<f.point(b)[0]
    elif slot=='tub':
        assert {'Stand','Tub','Plug','ToolRack'}<=set(f.byname)
        # Stand consists of joined support pieces, tabletop is the highest point.
        a,b=f.bounds(['Stand']);assert np.allclose([a[0],b[0],a[2],b[2],b[1]],[-.8,.8,-.55,.55,.9],atol=.002)
        assert f.point('ToolRack')[0]==0 # static geometry stored relative to floor origin
    elif slot=='turntable':
        assert set(f.byname)=={'Plate'};assert np.allclose(f.point('Plate'),0)
        assert np.allclose([dims[0],dims[2],lo[1]], [1,1,-.02],atol=.002)
        assert abs(hi[1]-.02)<1e-6 and abs(dims[1]-.04)<1e-6
    elif slot=='chair':
        a,b=f.bounds(['Cushion']);assert abs(b[1]-.4)<.002;assert abs(dims[0]-.45)<.002;assert abs(lo[1])<.002
    elif slot=='tiles':
        assert np.allclose(dims[[0,2]] if path.stem=='floor' else dims[[0,1]],[2,2],atol=.002)
        if path.stem=='floor':assert abs(hi[1])<.001
        else:assert abs(lo[1])<.001 and abs(dims[2]-.3)<.001
    report['result']='PASS';return report
if __name__=='__main__':
    paths=[ROOT/p for p in sys.argv[1:]] if len(sys.argv)>1 else sorted((ROOT/'art/incoming').glob('*/*.glb'))
    reports=[validate(p) for p in paths];print(json.dumps(reports,indent=2,ensure_ascii=False))
