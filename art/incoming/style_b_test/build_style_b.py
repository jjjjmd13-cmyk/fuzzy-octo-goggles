"""Blender 4.5; independent builds read STYLE_B.md, never import another asset.
blender -b --factory-startup --python art/incoming/style_b_test/build_style_b.py -- shower
Also: dryer / brush / towel / dog / render. No external art or baked lighting.
"""
import bpy, math, sys, re, json, struct, zlib, hashlib, tempfile
from pathlib import Path
import numpy as np
from mathutils import Vector
from math import sin, cos, pi
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'tools/art'))
import build_slots as b
STYLE=(HERE/'STYLE_B.md').read_text(encoding='utf-8')
COLORS=dict(re.findall(r'\| (\w+) \| #(\w{6}) \|',STYLE))
RULES={m[0]:dict(rough=float(m[1]),metal=float(m[2]),size=int(m[3]),strength=float(m[4])) for m in re.findall(r'\| (\w+) \| [^|]+ \| ([\d.]+) \| ([\d.]+) \| (\d+) \| ([\d.]+) \|',STYLE)}
assert len(COLORS)==10 and len(RULES)==6
MATS={};GROUPS={};PIVOTS={}

def png(path,rgb):
    h,w,_=rgb.shape
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    raw=b''.join(b'\0'+row.tobytes() for row in rgb.astype(np.uint8))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,7))+chunk(b'IEND',b''))

def material(kind,color,eye=False):
    key=(kind,color,eye)
    if key in MATS:return MATS[key]
    r=RULES[kind];size=r['size'];y,x=np.mgrid[0:size,0:size]/size
    # All deterministic and tileable: relief/albedo only, independent of lighting.
    if kind=='wood':
        h=.40*sinarray(2*pi*(x*19+.22*sinarray(2*pi*y*2)))+.15*sinarray(2*pi*(x*47+.3*sinarray(2*pi*y)))
    elif kind=='cloth':
        h=.35*sinarray(2*pi*x*43)*sinarray(2*pi*y*43)+.18*cosarray(2*pi*y*86)
    elif kind=='fur':
        rng=np.random.default_rng(175)
        noise=rng.standard_normal((size,size));fx=np.fft.fftfreq(size)*size;fy=fx.copy()
        filt=np.exp(-.5*((fx[None,:]/65)**2+(fy[:,None]/6)**2))
        filt*=1-np.exp(-.5*(fx[None,:]/14)**2)
        field=np.fft.ifft2(np.fft.fft2(noise)*filt).real
        h=np.clip(field/(field.std()*2.7),-.6,.6)
    elif kind=='metal':h=.13*sinarray(2*pi*x*89)+.05*sinarray(2*pi*x*113)
    else:h=.12*sinarray(2*pi*x*61)*cosarray(2*pi*y*67)
    rgb=np.array(list(bytes.fromhex(COLORS[color])),dtype=float)
    albedo=np.clip(rgb[None,None,:]*(1+h[:,:,None]*.065),0,255)
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*.42;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*.42
    n=np.stack((-dx,dy,np.ones_like(h)),axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
    normal=(n*.5+.5)*255
    orm=np.ones((size,size,3));orm[:,:,1]=(.24 if eye else r['rough'])+h*.025;orm[:,:,2]=r['metal']
    m=bpy.data.materials.new('B_'+kind+'_'+color+('_eye' if eye else ''));m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.24 if eye else r['rough'];bs.inputs['Metallic'].default_value=r['metal']
    bs.inputs['Base Color'].default_value=b.rgba('#'+COLORS[color])
    bs.inputs['Specular IOR Level'].default_value=.5
    tmp=Path(tempfile.gettempdir())/'paws_style_b_textures';tmp.mkdir(exist_ok=True)
    for typ,data in [('color',albedo),('normal',normal),('orm',orm*255)]:
        p=tmp/(m.name+'_'+typ+'.png');png(p,data)
        im=bpy.data.images.load(str(p),check_existing=False);im.name=m.name+'_'+typ;im.colorspace_settings.name='sRGB' if typ=='color' else 'Non-Color';im.pack()
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.label=typ
        if typ=='color':m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
        if typ=='normal' and not eye:
            node=m.node_tree.nodes.new('ShaderNodeNormalMap');node.inputs['Strength'].default_value=r['strength'];m.node_tree.links.new(tex.outputs['Color'],node.inputs['Color']);m.node_tree.links.new(node.outputs['Normal'],bs.inputs['Normal'])
        if typ=='orm':
            sep=m.node_tree.nodes.new('ShaderNodeSeparateColor');m.node_tree.links.new(tex.outputs['Color'],sep.inputs['Color']);m.node_tree.links.new(sep.outputs['Green'],bs.inputs['Roughness']);m.node_tree.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    MATS[key]=m;return m

sinarray=np.sin;cosarray=np.cos
def tag(o,kind,color,group='Body',eye=False):
    o.data.materials.clear();o.data.materials.append(material(kind,color,eye));GROUPS.setdefault(group,[]).append(o);return o

def ball(n,c,s,kind,color,seg=16,rings=10,group='Body'):
    o=b.uvball(n,c,s,None,seg=seg,rings=rings)
    uv=o.data.uv_layers.new(name='DirectionalUV')
    for face in o.data.polygons:
        coords=[]
        for li in face.loop_indices:
            q=o.data.vertices[o.data.loops[li].vertex_index].co
            coords.append([math.atan2(-q.y/s[2],q.x/s[0])/(2*pi)+.5,math.acos(max(-1,min(1,q.z/s[1])))/pi])
        if max(p[0] for p in coords)-min(p[0] for p in coords)>.5:
            for p in coords:
                if p[0]<.5:p[0]+=1
        for li,coord in zip(face.loop_indices,coords):uv.data[li].uv=coord
    return tag(o,kind,color,group)

def box(n,c,s,kind,color,r=.002,group='Body'):
    # Limit bevel to 2 rings, ample for a 1mm production fillet.
    bpy.ops.mesh.primitive_cube_add(size=1,location=b.V(c));o=bpy.context.object;o.name=n
    o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if r:
        md=o.modifiers.new('Manufactured soft edge','BEVEL');md.width=min(r,min(s)*.42);md.segments=2;bpy.ops.object.modifier_apply(modifier=md.name)
    for f in o.data.polygons:f.use_smooth=True
    md=o.modifiers.new('Weighted normal','WEIGHTED_NORMAL');md.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=md.name)
    return tag(o,kind,color,group)

def tube(n,points,radii,kind,color,ns=10,group='Body'):
    if isinstance(radii,(int,float)):radii=[radii]*len(points)
    return tag(b.tube(n,points,radii,None,n=ns),kind,color,group)

def lathe(n,c,profile,kind,color,axis='z',ns=24,group='Body',cap_start=True,cap_end=True):
    vs=[];faces=[]
    for pos,r in profile:
        for k in range(ns):
            a=2*pi*k/ns;q=(r*cos(a),r*sin(a),pos) if axis=='z' else (r*cos(a),pos,-r*sin(a))
            vs.append(tuple(c[i]+q[i] for i in range(3)))
    for j in range(len(profile)-1):
        for k in range(ns):
            a=j*ns+k;d=j*ns+(k+1)%ns;faces.append((a,d,d+ns,a+ns))
    if cap_start:faces.append(tuple(reversed(range(ns))))
    if cap_end:faces.append(tuple((len(profile)-1)*ns+k for k in range(ns)))
    return tag(b.mesh(n,vs,faces,None),kind,color,group)

def ring(n,c,r,t,kind,color,ns=24,cross=6):
    vs=[];fs=[]
    for i in range(ns):
        a=2*pi*i/ns
        for j in range(cross):
            q=2*pi*j/cross;rad=r+t*cos(q);vs.append((c[0]+rad*cos(a),c[1]+rad*sin(a),c[2]+t*sin(q)))
    for i in range(ns):
        for j in range(cross):fs.append((i*cross+j,i*cross+(j+1)%cross,((i+1)%ns)*cross+(j+1)%cross,((i+1)%ns)*cross+j))
    return tag(b.mesh(n,vs,fs,None),kind,color)

def shower():
    ball('Ergonomic grip',(0,-.008,0),(.014,.074,.016),'plastic','sky',16,12)
    tube('Curved neck',[(0,.045,0),(0,.073,.004),(0,.098,-.005)],[.012,.012,.020],'plastic','sky',12)
    c=(0,.105,-.007)
    lathe('Head shell',c,[(-.009,.032),(-.006,.041),(.005,.044),(.014,.038),(.019,.023)],'plastic','sky',ns=32)
    lathe('Brushed steel bezel',c,[(-.013,.036),(-.012,.042),(-.008,.043),(-.006,.039)],'metal','silver',ns=32)
    lathe('Silicone face',c,[(-.015,.035),(-.012,.036)],'rubber','ivory',ns=24)
    for radius,count in [(.0,1),(.012,8),(.025,14)]:
        for i in range(count):
            a=2*pi*i/count;x=radius*cos(a);y=.105+radius*sin(a)
            lathe('Soft nozzle',(x,y,-.007),[(-.019,.0013),(-.018,.0022),(-.015,.0022)],'rubber','mint',ns=6)
    box('Thumb insert',(0,-.008,-.015),(.018,.054,.003),'rubber','ivory',.0015)
    for y in [-.024,-.012,0,.012]:box('Grip texture',(0,y,-.017),(.014,.0015,.001),'rubber','mint',.0005)
    lathe('Hose coupling',(0,-.079,0),[(-.012,.009),(-.009,.011),(.002,.011),(.004,.009)],'metal','silver',axis='y',ns=16)
    tube('Short flexible hose',[(0,-.09,0),(0,-.112,.002),(.009,-.126,.008),(.027,-.126,.015)],.005,'rubber','ivory',10)

def dryer():
    # Functional nozzle and an exposed independent rotor, not a black end cap.
    lathe('Motor housing',(0,.066,0),[(-.151,.028),(-.139,.037),(-.065,.043),(.030,.050),(.095,.042),(.119,.031),(.121,.020)],'plastic','sky',ns=24,cap_start=False)
    lathe('Nozzle lip',(0,.066,0),[(-.159,.030),(-.156,.034),(-.145,.034),(-.142,.030)],'metal','silver',ns=24,cap_start=False,cap_end=False)
    lathe('Inner air duct',(0,.066,0),[(-.159,.027),(-.149,.025),(-.136,.025)],'rubber','ink',ns=24,cap_start=False,cap_end=False)
    lathe('Rear bezel',(0,.066,0),[(.108,.030),(.119,.033),(.126,.030),(.130,.025)],'rubber','ivory',ns=24,cap_start=False,cap_end=False)
    ball('Sloping handle',(0,-.014,.010),(.022,.082,.025),'plastic','sky',12,8)
    box('Soft grip',(0,-.028,-.011),(.031,.083,.013),'rubber','ivory',.004)
    box('Warm air switch',(0,.014,-.030),(.016,.025,.006),'plastic','coral',.002)
    for y in [-.055,-.041,-.027,-.013]:box('Palm ribs',(0,y,-.019),(.027,.002,.002),'rubber','mint',.0007)
    for i in range(7):
        x=(i-3)*.007;box('Rear grille',(x,.066,.129),(.003,.044,.003),'rubber','ink',.001)
    pivot=(0,.066,-.139);PIVOTS['Fan']=pivot
    lathe('Fan hub',pivot,[(-.005,.007),(.005,.007)],'metal','silver',ns=12,group='Fan')
    for i in range(5):
        a=2*pi*i/5
        points=[(.007*cos(a),.066+.007*sin(a),-.141),(.019*cos(a+.24),.066+.019*sin(a+.24),-.141),(.024*cos(a+.56),.066+.024*sin(a+.56),-.137),(.013*cos(a+.66),.066+.013*sin(a+.66),-.136)]
        tag(b.mesh('Fan blade',points,[(0,1,2,3),(3,2,1,0)],None),'plastic','ivory','Fan')
    ring('Outlet protection',(0,.066,-.160),.026,.0015,'metal','silver',24,4)
    for x in [-.014,0,.014]:box('Safety grille',(x,.066,-.161),(.002,.045,.002),'metal','silver',.0006)

def brush():
    ball('Oak handle',(0,-.028,0),(.014,.072,.012),'wood','oak',16,10)
    ball('Solid oval back',(0,.061,-.001),(.034,.039,.014),'wood','oak',24,12)
    ball('Rubber cushion',(0,.061,-.014),(.028,.033,.006),'rubber','ivory',16,8)
    for row in range(5):
        y=.037+row*.012
        for col in range(4):
            x=(col-1.5)*.013
            if (x/.028)**2+((y-.061)/.033)**2>.85:continue
            lathe('Rounded wooden pin',(x,y,0),[(-.040,.0009),(-.039,.0022),(-.035,.0027),(-.019,.0023)],'wood','oatmeal',ns=8)
    ring('Hanging hole',(0,-.079,-.012),.004,.001,'rubber','ivory',16,4)
    box('Handle inlay',(0,-.025,-.012),(.005,.038,.001),'wood','oatmeal',.0004)

def towel():
    # Cloth is a closed, pinched volume; wiping surface faces -Z, hand origin at 0.
    nx,ny=23,15;verts=[];faces=[]
    def pos(i,j,back=False):
        u=i/(nx-1)*2-1;v=j/(ny-1)*2-1
        x=.125*u*(.70+.30*abs(v));y=.075*v-.015*(1-u*u)*(1-v*v)
        z=-.018-.045*(abs(u)**.6)+.018*sin(2*pi*u+.8*v)*(.25+.75*abs(u))+.003*cos(2*pi*v)
        return (x,y,z+(.006 if back else 0))
    for side in [False,True]:
        for j in range(ny):
            for i in range(nx):verts.append(pos(i,j,side))
    count=nx*ny
    for j in range(ny-1):
        for i in range(nx-1):
            a=j*nx+i;f=(a,a+1,a+1+nx,a+nx);faces.append(f);faces.append(tuple(k+count for k in reversed(f)))
    boundary=list(range(nx))+[j*nx+nx-1 for j in range(1,ny)]+[(ny-1)*nx+i for i in range(nx-2,-1,-1)]+[j*nx for j in range(ny-2,0,-1)]
    for a,d in zip(boundary,boundary[1:]+boundary[:1]):faces.append((d,a,a+count,d+count))
    tag(b.mesh('Pinched terry cloth',verts,faces,None),'cloth','rose')
    # Real hem and stitches, no dark painted folds.
    for j in [1,ny-2]:
        pts=[pos(i,j) for i in range(nx)];pts=[(x,y,z-.0008) for x,y,z in pts]
        tube('Woven hem',pts,.0014,'cloth','oatmeal',6)
    for side in [-1,1]:
        pts=[]
        for j in range(ny):
            p=pos(0 if side<0 else nx-1,j);pts.append((p[0],p[1],p[2]-.0008))
        tube('Rounded selvage',pts,.001,'cloth','rose',6)

def ear(side):
    # Tapered, softly rounded erect Shiba ears, never needle tips.
    c=side*.050
    points=[(c,.279,.002),(c+side*.009,.312,.007),(c+side*.015,.341,.010),(c+side*.012,.350,.009)]
    tube('Outer ear',points,[(.025,.017),(.020,.013),(.008,.006),(.0025,.0025)],'fur','honey',10)
    vs=[(c-side*.012,.297,-.014),(c+side*.020,.302,-.013),(c+side*.014,.337,.002)]
    tag(b.mesh('Inner ear',vs,[(0,1,2) if side>0 else (2,1,0)],None),'rubber','rose')

def dog():
    ball('Seated body',(0,.122,.033),(.067,.104,.065),'fur','honey',24,16)
    ball('Ivory chest',(0,.141,-.018),(.048,.078,.031),'fur','ivory',20,12)
    ball('Neck',(0,.211,-.003),(.053,.051,.048),'fur','honey',16,10)
    ball('Rounded Shiba head',(0,.258,-.017),(.078,.066,.061),'fur','honey',28,18)
    for side in [-1,1]:
        ear(side)
        ball('Haunch',(side*.060,.061,.040),(.035,.055,.048),'fur','honey',16,10)
        tube('Foreleg',[(side*.033,.153,-.030),(side*.035,.092,-.043),(side*.036,.026,-.048)],[(.018,.020),(.015,.017),(.015,.017)],'fur','ivory',12)
        ball('Front paw',(side*.036,.016,-.059),(.023,.016,.032),'fur','ivory',16,8)
        ball('Rear paw',(side*.073,.015,.029),(.024,.015,.032),'fur','ivory',12,8)
        ball('Cheek',(side*.048,.236,-.051),(.034,.028,.030),'fur','ivory',16,10)
        ball('Muzzle',(side*.021,.239,-.075),(.027,.021,.025),'fur','ivory',18,10)
        # 11% of head width; no huge white eyeballs or painted glint.
        o=ball('Warm dark eye',(side*.034,.271,-.070),(.009,.011,.006),'rubber','ink',20,12)
        o.data.materials.clear();o.data.materials.append(material('rubber','ink',True))
        ball('Brow marking',(side*.035,.289,-.063),(.012,.006,.003),'fur','oatmeal',12,6)
        for i in range(3):
            y=.231+i*.009
            tube('Cheek lock',[(side*.061,y,-.026),(side*.079,y-.008,-.038),(side*.081,y-.009,-.045)],[(.011,.007),(.007,.004),(.0018,.0018)],'fur','ivory',6)
        # The smile comes from curved mouth geometry under the muzzle.
        tube('Smile',[(side*.004,.226,-.088),(side*.021,.224,-.090),(side*.036,.232,-.082)],[.0015,.0015,.001],'rubber','ink',6)
    ball('Small nose',(0,.251,-.099),(.014,.010,.009),'rubber','ink',20,10)
    ball('Happy mouth',(0,.220,-.080),(.014,.009,.006),'rubber','ink',16,8)
    ball('Tongue',(0,.214,-.086),(.008,.009,.003),'rubber','coral',12,8)
    pts=[(.005,.097,.082),(.031,.110,.111),(.049,.148,.115),(.035,.176,.105),(.010,.176,.095),(-.002,.156,.094),(.015,.145,.100)]
    tube('Curled tail',pts,[.021,.022,.024,.023,.020,.016,.008],'fur','honey',12)
    tube('Ivory tail tip',pts[-3:],[.020,.016,.008],'fur','ivory',12)

def finish(name):
    # Each independent process rereads the style and creates only one target.
    root=b.empty('test_b_'+name)
    for group,objects in GROUPS.items():
        for o in objects:
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.mesh.normals_make_consistent(inside=False)
            if not o.data.uv_layers:bpy.ops.uv.smart_project(angle_limit=1.0,island_margin=.025,correct_aspect=True,scale_to_bounds=True)
            bpy.ops.object.mode_set(mode='OBJECT')
            o.data.uv_layers.active.name='SurfaceUV'
        target=b.join_into(objects[0],objects[1:]);target.name=group
        bpy.context.scene.cursor.location=b.V(PIVOTS.get(group,(0,0,0)));bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        world=target.matrix_world.copy();target.parent=root;target.matrix_world=world
        if group in PIVOTS:target['motion_axis']='Z';target['motion_type']='rotate'
        md=target.modifiers.new('Export triangles and tangent basis','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=md.name)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.context.view_layer.update()
    axis=1 if name in ['shower','brush','dog'] else (2 if name=='dryer' else 0)
    vals=[(o.matrix_world@v.co)[(0,2,1)[axis]] for o in meshes for v in o.data.vertices]
    scale={'shower':.25,'dryer':.30,'brush':.20,'towel':.25,'dog':.35}[name]/(max(vals)-min(vals))
    for o in meshes:
        for v in o.data.vertices:v.co*=scale
        o.location*=scale
    root['units']='metres';root['up']='+Y';root['forward']='-Z';root['style']='B v1.0';root['style_sha256']=hashlib.sha256(STYLE.encode()).hexdigest()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];tris=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes)
    assert tris<=(8000 if name=='dog' else 3000),(name,tris)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(HERE/('test_b_'+name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
    print('STYLE_B_BUILT',name,tris,root['style_sha256'],flush=True)

def render(mode):
    from bpy_extras.object_utils import world_to_camera_view
    b.reset();scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=2000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.7
    scene.world.color=(.32,.32,.32)
    ground=b.mat('Neutral studio','#E9E5DF',.85)
    b.box('Floor',(0,-.012,.2),(200,.02,200),ground,bevel=0)
    lights=[((-.7,1.8,-1.2),130,1.5),((1.3,1.0,-.2),65,1.25),((0,1.5,1),100,1.0)]
    for c,power,size in lights:
        bpy.ops.object.light_add(type='AREA',location=b.V(c));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(b.V((0,.1,0))-o.location).to_track_quat('-Z','Y').to_euler()
    if mode=='lineup':
        names=['shower','dryer','brush','towel','dog'];xs=[-.60,-.30,0,.30,.60]
        files=[HERE/('test_b_'+n+'.glb') for n in names];labels=['B / SHOWER','B / DRYER','B / OAK BRUSH','B / TOWEL','B / SHIBA'];ortho=1.68
    else:
        names=['shower','shower','brush','brush'];xs=[-.48,-.16,.16,.48]
        files=[ROOT/'assets/models/tools/shower.glb',HERE/'test_b_shower.glb',ROOT/'assets/models/tools/brush.glb',HERE/'test_b_brush.glb'];labels=['A / SHOWER','B / SHOWER','A / BRUSH','B / BRUSH'];ortho=1.38
    bpy.ops.object.camera_add(location=b.V((0,.65,-2.6)));cam=bpy.context.object
    cam.rotation_euler=(b.V((0,.155,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=ortho;scene.camera=cam
    anchors=[]
    for i,(path,x) in enumerate(zip(files,xs)):
        before=set(scene.objects);bpy.ops.import_scene.gltf(filepath=str(path));added=set(scene.objects)-before
        top=[o for o in added if o.parent not in added];pivot=b.empty('Display pivot')
        for o in top:o.parent=pivot
        pivot.rotation_euler[2]=math.radians(-22)
        bpy.context.view_layer.update()
        meshes=[o for o in added if o.type=='MESH'];lo=min((o.matrix_world@Vector(q)).z for o in meshes for q in o.bound_box)
        pivot.location=(x,0,-lo);bpy.context.view_layer.update()
        coord=world_to_camera_view(scene,cam,b.V((x,0,0)));anchors.append([labels[i],round(coord.x*2000)])
    scene.render.filepath=str(HERE/('_'+mode+'_raw.png'));bpy.ops.render.render(write_still=True)
    (HERE/('_'+mode+'_labels.json')).write_text(json.dumps(anchors))

if __name__=='__main__':
    arg=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'dog'
    if arg=='render':
        render('lineup');render('compare')
    else:
        b.reset();globals()[arg]();finish(arg)
