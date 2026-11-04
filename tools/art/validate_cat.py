"""Validate final GLB bytes, including exact pivots and global UV intersections.
Python dependencies: numpy, Pillow. No external geometry library required.
"""
import sys,json,io,hashlib,itertools
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parent))
from validate_slots import GLB
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'art/incoming/cat/cat.glb'

def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def area(poly):return abs(sum(cross(a,b) for a,b in zip(poly,np.roll(poly,-1,axis=0))))/2 if len(poly)>2 else 0.
def intersection(a,b):
    poly=list(a);sgn=1 if cross(b[1]-b[0],b[2]-b[0])>=0 else -1
    for u,v in zip(b,np.roll(b,-1,axis=0)):
        if not poly:return 0.
        out=[];prev=poly[-1];dp=sgn*cross(v-u,prev-u)
        for q in poly:
            dq=sgn*cross(v-u,q-u)
            if (dq>=0)!=(dp>=0):out.append(prev+(q-prev)*(dp/(dp-dq)))
            if dq>=0:out.append(q)
            prev=q;dp=dq
        poly=out
    return area(np.array(poly))

def main():
    f=GLB(P);g=f.g;assert g['asset']['version']=='2.0';assert not g.get('skins') and not g.get('animations')
    assert not any('uri' in b for b in g['buffers']);assert not g.get('extensionsRequired')
    expected=json.loads((ROOT/'docs/art/CAT_JOINTS.json').read_text())
    assert set(f.byname)==set(expected)|{'Cat'}
    assert np.allclose(f.point('Cat'),[0,0,0])
    for name,p in expected.items():assert np.allclose(f.point(name),p,atol=2e-6),(name,f.point(name),p)
    for tag in ['L','R']:
        for name in ['Ear_','Eye_','Cheek_']:f.hasparent(name+tag,'Head')
        for name in ['Pupil_','Glint_']:f.hasparent(name+tag,'Eye_'+tag)
        f.hasparent('NoFurEar_'+tag,'Ear_'+tag);f.hasparent('Paw_F'+tag,'Leg_F'+tag)
    for name in ['Mouth','Nose','Tongue','FaceCenter']:f.hasparent(name,'Head')
    f.hasparent('Tail_2','Tail_1');f.hasparent('Tail_3','Tail_2')
    for name in ['Head','Torso','Chest','Leg_FL','Leg_FR','Haunch_L','Haunch_R','Paw_BL','Paw_BR','Tail_1','BodyCenter']:f.hasparent(name,'Cat')
    for name in ['FaceCenter','BodyCenter']:assert 'mesh' not in g['nodes'][f.byname[name]]
    for name in ['Ear','Eye','Cheek','Haunch']:
        assert f.point(name+'_L')[0]<0<f.point(name+'_R')[0]
    assert f.point('Nose')[2]<f.point('Head')[2]
    lo,hi=f.bounds();dim=hi-lo;assert abs(lo[1])<1e-6 and .48<dim[1]<.52 and .45<dim[2]<.54,(lo,hi,dim)
    assert abs(lo[0]+hi[0])<.002
    images=g.get('images',[]);assert len(images)==1
    im=images[0];assert im['mimeType']=='image/png' and 'uri' not in im
    view=g['bufferViews'][im['bufferView']];png=f.bin[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']];image=Image.open(io.BytesIO(png));assert max(image.size)<=2048
    colors=image.convert('RGB').getcolors(image.width*image.height);assert set(c for _,c in colors)=={(201,205,214),(255,253,249),(173,181,195)}
    for m in g['materials']:
        assert not m.get('normalTexture') and not m.get('occlusionTexture') and not m.get('emissiveTexture')
        assert not m.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture')
    tris=0;fur_names=[];uvtri=[];by_mesh={};face_palettes={}
    nonfur=('Eye','Pupil','Glint','Nose','Mouth','Tongue','NoFur')
    for i,n,p in f.meshes():
        ids=f.acc(p['indices']).reshape(-1,3);tris+=len(ids);by_mesh[n['name']]=len(ids)
        pos=f.acc(p['attributes']['POSITION']);t=pos[ids];areas=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)/2;assert areas.min()>1e-12,n['name']
        norm=f.acc(p['attributes']['NORMAL']);assert np.max(abs(np.linalg.norm(norm,axis=1)-1))<.001
        m=g['materials'][p['material']]
        if n['name'].startswith(nonfur):assert m['name']!='FurCleanAlbedo';continue
        assert m['name']=='FurCleanAlbedo';assert 'baseColorTexture' in m['pbrMetallicRoughness'];fur_names.append(n['name'])
        uv=f.acc(p['attributes']['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1
        for ids3 in ids:
            tri=uv[ids3];assert area(tri)>1e-13;uvtri.append(tri)
    assert tris<=8000,tris
    # Spatial bins and exact polygon clipping detect both self and cross-mesh UV overlap.
    bins={};triangles=[];overlap=0.;pairs=0
    for tri in uvtri:
        tlo=tri.min(0);thi=tri.max(0);keys=list(itertools.product(range(int(tlo[0]*64),int(thi[0]*64)+1),range(int(tlo[1]*64),int(thi[1]*64)+1)))
        candidates=set(j for key in keys for j in bins.get(key,[]))
        for j in candidates:
            other=triangles[j]
            if np.any(thi<=other.min(0)+1e-10) or np.any(other.max(0)<=tlo+1e-10):continue
            a=intersection(tri,other);pairs+=1;overlap=max(overlap,a);assert a<1e-10,('UV overlap',len(triangles),j,a)
        for key in keys:bins.setdefault(key,[]).append(len(triangles))
        triangles.append(tri)
    # The forehead contains exactly three separated pigment bands at mid-height.
    samples=[]
    i=f.byname['Head'];node=g['nodes'][i];p=g['meshes'][node['mesh']]['primitives'][0];verts=f.acc(p['attributes']['POSITION']);world=f.world(i);verts=verts@world[:3,:3].T+world[:3,3];uv=f.acc(p['attributes']['TEXCOORD_0']);arr=np.array(image.convert('RGB'))
    for ids in f.acc(p['indices']).reshape(-1,3):
        xyz=verts[ids].mean(0);tuv=uv[ids].mean(0);pix=arr[min(image.height-1,int(tuv[1]*image.height)),min(image.width-1,int(tuv[0]*image.width))]
        if tuple(pix)==(173,181,195):samples.append(xyz.tolist())
    assert len(samples)>3
    result={'file':'art/incoming/cat/cat.glb','sha256':hashlib.sha256(P.read_bytes()).hexdigest(),'triangles':tris,'mesh_nodes':len(by_mesh),'fur_meshes':len(fur_names),'dimensions_m':dim.tolist(),'bounds_m':[lo.tolist(),hi.tolist()],'embedded_png_size':list(image.size),'clean_palette_rgb':[c for _,c in colors],'joint_pivots_m':expected,'triangles_by_mesh':by_mesh,'fur_uv_triangles_checked':len(uvtri),'uv_intersection_pairs_checked':pairs,'max_uv_overlap_area':overlap,'global_fur_uv_overlap':False,'rig':False,'animations':False,'clean_palette_only':True}
    (ROOT/'docs/art/CAT_VALIDATION.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['joint_pivots_m','triangles_by_mesh']},indent=2))
if __name__=='__main__':main()
