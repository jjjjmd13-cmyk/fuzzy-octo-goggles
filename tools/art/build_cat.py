"""Original cat customer; Blender 4.2+, metres / Y-up / front -Z.
Run: blender -b --factory-startup --python tools/art/build_cat.py
No rig, external assets, paid services, lighting bakes or normal maps.
"""
import sys,math,json,struct,zlib
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_slots as B
import build_retail_slots as R
ROOT=B.ROOT; OUT=ROOT/'art/incoming/cat'; OUT.mkdir(parents=True,exist_ok=True)
PIVOTS={};FUR=[]
BASE='#C9CDD6';WHITE='#FFFDF9';STRIPE='#ADB5C3'

def register(o,p,fur=False):
    PIVOTS[o.name]=list(p)
    if fur:FUR.append(o)
    return o

def ball(name,c,s,m,p=None,parent=None,seg=20,rings=12,fur=False,shape=None):
    return register(B.uvball(name,c,s,m,p=p or c,parent=parent,seg=seg,rings=rings,shape=shape),p or c,fur)

def tube(name,pts,rs,m,p=None,parent=None,n=12,fur=False):
    return register(B.tube(name,pts,rs,m,p=p or pts[0],parent=parent,n=n),p or pts[0],fur)

def pillow(name,outline,depth,m,p,parent=None,fur=False):
    # A rounded triangular pillow. Rounded quadratic corners, softly domed faces.
    outline=[Vector(x) for x in outline];curve=[]
    for i,c in enumerate(outline):
        a=c+(outline[i-1]-c)*.20;b=c+(outline[(i+1)%3]-c)*.20
        for j in range(5):
            t=j/4;curve.append((1-t)**2*a+2*t*(1-t)*c+t*t*b)
    center=sum(outline,Vector())/3;verts=[];faces=[];n=len(curve)
    for scale,dz in [(.20,-depth*.50),(.90,-depth*.50),(1,0),(.90,depth*.50),(.20,depth*.50)]:
        for q in curve:
            v=center+(q-center)*scale;v.z+=dz;verts.append(tuple(v))
    for j in range(4):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
    faces += [tuple(reversed(range(n))),tuple(4*n+i for i in range(n))]
    o=B.mesh(name,verts,faces,m,p=p,parent=parent)
    # Recalculate outward normals for the rounded closed volume.
    bpy.context.view_layer.objects.active=o;B.bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    return register(o,p,fur)

def clean_color(name,xyz):
    result=np.empty((len(xyz),3),dtype=np.uint8);result[:]=tuple(bytes.fromhex(BASE[1:]))
    if name=='Chest' or name.startswith('Paw_'):result[:]=tuple(bytes.fromhex(WHITE[1:]))
    if name=='Head':
        x,y,z=xyz.T
        # Three tapered, gently swept forehead stripes, painted pigment only.
        t=np.clip((y-.395)/.052,0,1)
        for side in [-1,0,1]:
            cx=side*(.033+.012*t)
            width=.0065*(1-.55*t)
            stripe=(abs(x-cx)<width)&(y>.395+abs(side)*.004)&(y<.447-abs(side)*.007)&(z<-.102)
            result[stripe]=tuple(bytes.fromhex(STRIPE[1:]))
    return result

def atlas():
    W=2048;grid=5;cell=W/grid;pixels=np.empty((W,W,3),dtype=np.uint8);pixels[:]=tuple(bytes.fromhex(BASE[1:]));occupied=np.zeros((W,W),dtype=bool)
    for idx,o in enumerate(FUR):
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.025,scale_to_bounds=True);bpy.ops.object.mode_set(mode='OBJECT')
        uv=o.data.uv_layers.active;uv.name='CleanFurUV'
        for loop in uv.data:loop.uv=((idx%grid+.04+loop.uv.x*.92)/grid,(idx//grid+.04+loop.uv.y*.92)/grid)
        mod=o.modifiers.new('Delivery triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        uv=o.data.uv_layers.active
        for face in o.data.polygons:
            coords=np.array([uv.data[k].uv[:] for k in face.loop_indices])*W-.5
            lo=np.maximum(0,np.floor(coords.min(axis=0)).astype(int));hi=np.minimum(W-1,np.ceil(coords.max(axis=0)).astype(int))
            xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));q=np.stack((xx.ravel(),yy.ravel()),axis=1)
            a,b,c=coords;den=np.cross(b-a,c-a)
            if abs(den)<1e-9:raise RuntimeError('Degenerate UV '+o.name)
            w1=np.cross(q-a,c-a)/den;w2=np.cross(b-a,q-a)/den;w0=1-w1-w2
            valid=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)
            if not np.any(valid):continue
            v=np.array([o.matrix_world@o.data.vertices[o.data.loops[k].vertex_index].co for k in face.loop_indices])
            bl=w0[valid,None]*v[0]+w1[valid,None]*v[1]+w2[valid,None]*v[2]
            xyz=np.stack((bl[:,0],bl[:,2],-bl[:,1]),axis=1)
            dest=q[valid];pixels[dest[:,1],dest[:,0]]=clean_color(o.name,xyz);occupied[dest[:,1],dest[:,0]]=True
        # Nearest colour dilation within this object's isolated atlas cell.
        # A small CPU flood fill provides 12px gutters without external dependencies.
    for iteration in range(12):
        old=occupied.copy()
        for axis,delta in [(0,1),(0,-1),(1,1),(1,-1)]:
            avail=np.roll(old,delta,axis)&~occupied
            if delta==1:
                if axis==0:avail[0,:]=False
                else:avail[:,0]=False
            else:
                if axis==0:avail[-1,:]=False
                else:avail[:,-1]=False
            pixels[avail]=np.roll(pixels,delta,axis)[avail];occupied[avail]=True
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    # Explicit sRGB PNG bytes; only the three clean coat palette colours exist.
    raw=b''.join(b'\0'+row.tobytes() for row in pixels[::-1]);path=OUT/'_clean_albedo.png'
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,W,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
    image=bpy.data.images.load(str(path));image.name='Cat_Clean_Albedo';image.pack();image.colorspace_settings.name='sRGB'
    fur=B.mat('FurCleanAlbedo','#FFFFFF',.78);bs=fur.node_tree.nodes.get('Principled BSDF');node=fur.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;fur.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    for o in FUR:o.data.materials.clear();o.data.materials.append(fur)
    return path

def build():
    B.reset();PIVOTS.clear();FUR.clear();bpy.context.scene.unit_settings.scale_length=1
    f=B.mat('FurCleanAlbedo','#FFFFFF',.78);eye=B.mat('Eye','#7B9693',.35);pupil=B.mat('Pupil','#27313E',.32);glint=B.mat('Glint','#FFFEFA',.25);pink=B.mat('Nose','#FF9EC4',.64);tongue=B.mat('Tongue','#F38EB6',.75);mouth=B.mat('Mouth','#705F73',.8);inner=B.mat('NoFurEar','#FF9EC4',.85)
    ball('Torso',(0,.157,.050),(.101,.148,.120),f,p=(0,.157,.050),seg=22,rings=12,fur=True,shape=lambda x,y,z:(x*(1-.18*y),y,z))
    ball('Chest',(0,.210,-.042),(.078,.108,.070),f,seg=20,rings=12,fur=True)
    head=ball('Head',(0,.350,-.054),(.137,.112,.112),f,p=(0,.267,-.025),seg=28,rings=16,fur=True,shape=lambda x,y,z:(x*(1-.075*y),y,z))
    parts=[]
    for side in [-1,1]:parts.append(B.uvball('Muzzle',(side*.028,.307,-.147),(.045,.028,.043),f,seg=16,rings=10))
    R.sculpt(head,parts,size=.0035,limit=1200)
    for side,tag in [(-1,'L'),(1,'R')]:
        ball('Cheek_'+tag,(side*.083,.309,-.107),(.046,.036,.040),f,parent=head,seg=14,rings=8,fur=True)
        # Local left is -X when the animal faces -Z, matching the delivered dog.
        outline=[(side*.060,.408,-.047),(side*.148,.411,-.024),(side*.126,.510,-.035)]
        ear=pillow('Ear_'+tag,outline,.047,f,(side*.102,.416,-.038),head,True)
        center=sum((Vector(q) for q in outline),Vector())/3
        innerline=[]
        for q in outline:
            v=center+(Vector(q)-center)*.62;v.z-=.0240;innerline.append(tuple(v))
        pillow('NoFurEar_'+tag,innerline,.0015,inner,(side*.108,.443,-.060),ear)
        x=side*.059
        e=ball('Eye_'+tag,(x,.356,-.154),(.037,.043,.018),eye,parent=head,seg=16,rings=10)
        ball('Pupil_'+tag,(x,.357,-.170),(.026,.032,.008),pupil,parent=e,seg=14,rings=8)
        g=ball('Glint_'+tag,(x-.008,.369,-.177),(.007,.0085,.003),glint,parent=e,seg=10,rings=6)
        dot=B.uvball('GlintSmall',(x+.009,.347,-.177),(.003,.0035,.002),glint,seg=8,rings=4)
        B.join_into(g,[dot])
    # Mouth is a small, rounded W smile with a central philtrum, all one object.
    pts=[(-.021,.299,-.180),(-.015,.294,-.184),(-.008,.293,-.186),(0,.299,-.187),(.008,.293,-.186),(.015,.294,-.184),(.021,.299,-.180)]
    m=tube('Mouth',pts,[.0022]*7,mouth,p=(0,.298,-.184),parent=head,n=8)
    stem=B.tube('MouthStem',[(0,.313,-.187),(0,.299,-.187)],[.0022,.0022],mouth,n=8)
    B.join_into(m,[stem])
    nose_outline=[(-.013,.320,-.187),(.013,.320,-.187),(0,.306,-.192)]
    pillow('Nose',nose_outline,.014,pink,(0,.316,-.190),head)
    # Full-size tongue geometry stays inside the muzzle in the neutral asset.
    ball('Tongue',(0,.312,-.140),(.011,.016,.005),tongue,p=(0,.322,-.140),parent=head,seg=12,rings=8)
    for side,tag in [(-1,'L'),(1,'R')]:
        x=side*.060
        leg=ball('Leg_F'+tag,(x,.125,-.088),(.031,.110,.035),f,p=(x,.228,-.059),seg=16,rings=12,fur=True)
        ball('Paw_F'+tag,(x,.028,-.123),(.040,.028,.049),f,parent=leg,seg=16,rings=8,fur=True)
        ball('Haunch_'+tag,(side*.091,.086,.070),(.066,.080,.077),f,p=(side*.084,.115,.063),seg=18,rings=12,fur=True)
        ball('Paw_B'+tag,(side*.101,.026,.028),(.043,.026,.057),f,p=(side*.101,.035,.047),seg=16,rings=8,fur=True)
    # A long slender tail curls up and forward, with three independent joints.
    # One smooth centreline, split at three joints. Shared ring positions and
    # radial normals keep the neutral silhouette continuous across separate meshes.
    controls=np.array([(0,.074,.145),(.005,.077,.183),(.017,.090,.221),(.025,.116,.248),(.030,.151,.258),(.032,.192,.254),(.029,.232,.242),(.022,.267,.221),(.013,.283,.198),(.007,.279,.180)])
    radii=np.array([.018,.018,.0175,.017,.016,.015,.014,.013,.011,.0015])
    curve=[];rr=[]
    for j in range(9):
        a=controls[max(0,j-1)];b=controls[j];c=controls[j+1];d=controls[min(9,j+2)]
        for k in range(3):
            t=k/3;curve.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t));rr.append(radii[j]*(1-t)+radii[j+1]*t)
    curve.append(controls[-1]);rr.append(radii[-1]);parent=None
    for part in range(3):
        verts=[];normals=[];faces=[];n=10;start=part*9;end=start+9
        for j in range(start,end+1):
            q=Vector(curve[j]);tangent=Vector(curve[min(j+1,27)]-curve[max(j-1,0)]).normalized();u=tangent.cross(Vector((1,0,0))).normalized();v=tangent.cross(u)
            for k in range(n):
                a=2*math.pi*k/n;radial=u*math.cos(a)+v*math.sin(a);verts.append(tuple(q+radial*rr[j]));normals.append(B.V(radial))
        for j in range(9):
            for k in range(n):
                a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
        faces += [tuple(reversed(range(n))),tuple(9*n+i for i in range(n))]
        parent=B.mesh('Tail_'+str(part+1),verts,faces,f,p=curve[start],parent=parent)
        parent.data.normals_split_custom_set([normals[loop.vertex_index] for loop in parent.data.loops])
        register(parent,curve[start].tolist(),True)
    for name,pos,par in [('FaceCenter',(0,.357,-.174),head),('BodyCenter',(0,.157,.050),None)]:B.empty(name,pos,par);PIVOTS[name]=list(pos)
    path=atlas();bpy.ops.object.select_all(action='SELECT')
    # A neutral identity root preserves the floor origin across importers.
    root=B.empty('Cat',(0,0,0))
    for o in list(bpy.context.scene.objects):
        if o!=root and o.parent is None:
            world=o.matrix_world.copy();o.parent=root;o.matrix_world=world
    bpy.context.view_layer.update();bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'cat.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_extras=False)
    path.unlink()
    (ROOT/'docs/art/CAT_JOINTS.json').write_text(json.dumps(PIVOTS,indent=2)+'\n')
    print('CAT_BUILT',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'),'triangles')
if __name__=='__main__':build()
