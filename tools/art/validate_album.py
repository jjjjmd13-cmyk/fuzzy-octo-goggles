"""Validate actual delivered GLB bytes and RGBA PNG pixel contracts."""
from pathlib import Path
import sys,json,io,hashlib,itertools,math
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0,str(Path(__file__).resolve().parent));from validate_slots import GLB
ROOT=Path(__file__).resolve().parents[2]

def rot(q):
    x,y,z,w=q;n=math.sqrt(x*x+y*y+z*z+w*w);x,y,z,w=[v/n for v in q]
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
class Asset(GLB):
    def local(self,i):
        n=self.g['nodes'][i];m=np.eye(4)
        if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
        m[:3,:3]=rot(n.get('rotation',[0,0,0,1]))@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
    def world(self,i):
        m=self.local(i);return self.world(self.parents[i])@m if i in self.parents else m

def validate3d(name,budget):
    path=ROOT/'art/incoming/album'/(name+'.glb');f=Asset(path);g=f.g
    assert g['asset']['version']=='2.0' and not g.get('animations') and not g.get('skins') and not g.get('cameras')
    assert not any('uri' in b for b in g['buffers']);assert not g.get('extensionsRequired')
    count=0
    for i,node,p in f.meshes():
        ids=f.acc(p['indices']).reshape(-1,3);count+=len(ids);v=f.acc(p['attributes']['POSITION']);tri=v[ids]
        assert np.min(np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1))>1e-12,node['name']
        norm=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(norm,axis=1)-1))<.001
        uv=f.acc(p['attributes']['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1
    assert count<=budget,(name,count,budget)
    assert len(g['images'])==1
    im=g['images'][0];assert im['mimeType']=='image/png' and 'bufferView' in im and 'uri' not in im
    bv=g['bufferViews'][im['bufferView']];png=f.bin[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']];image=Image.open(io.BytesIO(png));assert max(image.size)<=1024
    for mat in g['materials']:
        assert not mat.get('normalTexture') and not mat.get('occlusionTexture') and not mat.get('emissiveTexture')
        assert not mat['pbrMetallicRoughness'].get('metallicRoughnessTexture');assert 'baseColorTexture' in mat['pbrMetallicRoughness']
    lo,hi=f.bounds();dims=hi-lo;result={'file':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':count,'budget':budget,'bounds_m':[lo.tolist(),hi.tolist()],'dimensions_m':dims.tolist(),'embedded_png':list(image.size),'rig':False,'animations':False,'normal_map_or_lighting_bake':False}
    if name=='album_book':
        assert np.allclose(f.point('AlbumBook'),[0,0,0],atol=1e-7);assert abs(lo[1])<1e-6
        assert abs(dims[0]-.35)<.001 and .27<dims[2]<.30 and .058<dims[1]<.072
        assert np.allclose(f.point('Cover'),[-.175,.052,0],atol=1e-6)
        i=f.byname['Cover'];m=f.world(i);assert np.allclose(m[:3,1],[0,0,1],atol=1e-6)
        # A right-handed local-Y rotation opens the cover upwards around its spine.
        a=math.radians(75);r=np.eye(4);r[:3,:3]=[[math.cos(a),0,math.sin(a)],[0,1,0],[-math.sin(a),0,math.cos(a)]]
        point=np.linalg.inv(m)@np.array([.16,.056,0,1]);opened=m@r@point;assert opened[1]>.36
        p=f.point('Cover');assert np.allclose((m@r)[:3,3],p)
        for n in g['nodes']:
            if n['name'].startswith(('GoldPaw','Ribbon')):assert f.parents[f.byname[n['name']]]==i
        result['cover_hinge_m']=p.tolist();result['cover_local_Y_world_axis']=m[:3,1].tolist();result['cover_open_75deg_free_edge_m']=opened[:3].tolist()
    else:
        assert np.allclose(f.point('PhotoBoard'),[0,0,0]);assert abs(hi[2])<1e-6
        assert np.allclose(dims[:2],[1,.7],atol=.001)
        slots=[];rects=[]
        for k in range(1,7):
            name='Slot_'+str(k);i=f.byname[name];n=g['nodes'][i];assert 'mesh' not in n
            w=f.world(i);assert abs(w[2,3]+.029)<1e-6;assert np.allclose(w[:3,2],[0,0,1],atol=1e-6)
            rect=np.array([w@np.array([x,y,0,1]) for x,y in itertools.product([-.1,.1],repeat=2)])
            assert abs(rect[:,0]).max()<.455 and abs(rect[:,1]).max()<.305
            rects.append(rect[:,:2]);slots.append({'name':name,'position_m':w[:3,3].tolist(),'angle_deg':math.degrees(math.atan2(w[1,0],w[0,0])),'photo_size_m':[.2,.2]})
        for a,b in itertools.combinations(rects,2):
            assert np.any(a.max(0)<b.min(0)) or np.any(b.max(0)<a.min(0))
        assert sorted(round(s['position_m'][0],2) for s in slots)==[-.3,-.3,0,0,.3,.3]
        assert sorted(round(s['position_m'][1],2) for s in slots)==[-.14,-.14,-.14,.14,.14,.14]
        result['slots']=slots
    return result

ui={};folder=ROOT/'art/incoming/album_ui'
for p in sorted(folder.glob('*.png')):
    im=Image.open(p);assert im.format=='PNG' and im.mode=='RGBA';a=np.array(im);alpha=a[:,:,3]
    size=(1024,1280) if p.stem=='album_page' else ((512,600) if p.stem.startswith('photo_frame_') else ((512,512) if p.stem=='photo_unknown' else (128,128)))
    assert im.size==size,(p.name,im.size);assert (alpha==0).any() and (alpha==255).any()
    assert np.all(alpha[:2,:]==0) and np.all(alpha[-2:,:]==0) and np.all(alpha[:,:2]==0) and np.all(alpha[:,-2:]==0)
    d={'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'alpha':True}
    if p.stem.startswith('photo_frame_'):
        assert not alpha[64:448,64:448].any();assert alpha[500,256]>240;assert alpha[44,256]>240
        d['transparent_photo_rect_px']=[64,64,384,384];d['outer_rect_px']=[24,24,464,552]
    if p.stem.startswith('fav_spot_'):
        rgb=a[:,:,:3].astype(float);pink=(rgb[:,:,0]>rgb[:,:,2]*.95)&(rgb[:,:,0]>rgb[:,:,1]*1.2)&(alpha>200)
        lab,n=ndimage.label(pink);counts=np.bincount(lab.ravel());large=[i for i in range(1,len(counts)) if counts[i]>8];assert len(large)==1,(p.name,counts)
        y,x=np.nonzero(lab==large[0]);d['pink_heart_center_px']=[float(x.mean()),float(y.mean())]
    ui[p.name]=d
assert len(ui)==11,len(ui)
heart={k:v['pink_heart_center_px'] for k,v in ui.items() if 'pink_heart_center_px' in v}
assert heart['fav_spot_chin.png'][0]>heart['fav_spot_ear_back.png'][0]+25
assert heart['fav_spot_back.png'][1]>heart['fav_spot_ear_back.png'][1]+10
assert heart['fav_spot_rump.png'][1]>heart['fav_spot_back.png'][1]+10
result={'models':[validate3d('album_book',800),validate3d('photo_board',1000)],'ui':ui,'ui_art_source':'Built-in image_gen, size/alpha/9-slice asset packaging','text_numbers_logos':'None in delivered art; visual inspection','gltf':'2.0 binary, metres, Y-up, front -Z'}
(ROOT/'docs/art/ALBUM_VALIDATION.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
