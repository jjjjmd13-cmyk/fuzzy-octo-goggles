"""Original pastel tool assets, Blender 4.0+; no downloaded geometry/textures.
blender -b --factory-startup --python tools/art/build_v4_tool_upgrades.py
Coordinates use the existing build_slots.V convention (metres, Y-up, -Z front).
"""
import sys, math, json, struct, zlib, tempfile
from pathlib import Path
from mathutils import Vector
import bpy
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_slots as b
ROOT=b.ROOT
OUT=ROOT/'assets/models/tools'
PREVIEW=ROOT/'art/incoming/tool_upgrades'
COLORS=['8FD3F4','FF6B6B','FF9EC4','B8E3D3','E8C9A0','DDE5EA','FFF1D8','42576A','FFFFFF','759AB0','D4AF85','F9C3D8']
NAMES=['sky','red','pink','mint','wood','silver','cream','dark','white','slate','wood_edge','blush']
PARTS={}
PIVOTS={}
REPORT={}
MAT=None
ATLAS=None
PALETTE_MATS={}


def png_palette(path):
    # Exact sRGB bytes, flat colour only: no illumination/normal/AO baking.
    rows=[]
    for y in range(64):
        row=bytearray([0])
        for x in range(64):
            i=(y//16)*4+x//16
            row.extend(bytes.fromhex(COLORS[i] if i<len(COLORS) else 'FFFFFF'))
        rows.append(bytes(row))
    def chunk(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',64,64,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b''))


def reset():
    global MAT,ATLAS
    b.reset();PARTS.clear();PIVOTS.clear();PALETTE_MATS.clear()
    p=Path(tempfile.gettempdir())/'paws_v4_tool_albedo.png';png_palette(p)
    ATLAS=bpy.data.images.load(str(p),check_existing=False);ATLAS.name='PastelTools_Albedo64';ATLAS.pack()
    MAT=bpy.data.materials.new('Pastel_Albedo_Only');MAT.use_nodes=True
    bs=MAT.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.68;bs.inputs['Metallic'].default_value=0
    tex=MAT.node_tree.nodes.new('ShaderNodeTexImage');tex.image=ATLAS;tex.interpolation='Closest'
    MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])


def tag(o,color,group='Body'):
    if color not in PALETTE_MATS:
        m=MAT.copy();m.name='Pastel_'+color;PALETTE_MATS[color]=m
    o.data.materials.clear();o.data.materials.append(PALETTE_MATS[color])
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='PaletteUV')
    i=NAMES.index(color);center=((i%4+.5)/4,1-(i//4+.5)/4)
    # A nondegenerate tiny triangle in the centre of a padded constant-colour cell.
    for p in o.data.polygons:
        for j,loop in enumerate(p.loop_indices):
            a=2*math.pi*j/len(p.loop_indices)
            uv.data[loop].uv=(center[0]+.008*math.cos(a),center[1]+.008*math.sin(a))
    PARTS.setdefault(group,[]).append(o)
    return o


def ball(c,s,color,group='Body',seg=12,rings=6):
    return tag(b.uvball('Soft',c,s,MAT,seg=seg,rings=rings),color,group)


def box(c,size,color,group='Body',r=.008):
    # Two bevel segments keep the small hand-held assets below 3,000 triangles.
    bpy.ops.mesh.primitive_cube_add(size=1,location=b.V(c));o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if r:
        m=o.modifiers.new('Rounded moulding','BEVEL');m.width=min(r,min(size)*.45);m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons:p.use_smooth=True
    m=o.modifiers.new('Soft corner normals','WEIGHTED_NORMAL');m.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=m.name)
    return tag(o,color,group)


def tube(points,radii,color,group='Body',n=10):
    if isinstance(radii,(int,float)):radii=[radii]*len(points)
    return tag(b.tube('Rounded tube',points,radii,MAT,n=n),color,group)


def lathe(c,profile,color,axis='z',group='Body',n=24):
    # profile=(axis offset, radius). Positive axis x/y/z in glTF convention.
    verts=[]
    for pos,r in profile:
        for k in range(n):
            a=2*math.pi*k/n;u=r*math.cos(a);v=r*math.sin(a)
            q=(u,v,pos) if axis=='z' else (u,pos,-v)
            verts.append(tuple(c[i]+q[i] for i in range(3)))
    faces=[]
    for j in range(len(profile)-1):
        for k in range(n):
            a=j*n+k;d=j*n+(k+1)%n
            faces.append((a,d,d+n,a+n))
    # Explicit end caps; zero radius rings are welded by b.export.
    faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
    return tag(b.mesh('Moulded profile',verts,faces,MAT),color,group)


def ring(c,r,t,color,axis='z',group='Body',n=24,cross=6,oval=1):
    verts=[];faces=[]
    for k in range(n):
        a=2*math.pi*k/n
        for j in range(cross):
            q=2*math.pi*j/cross;rad=r+t*math.cos(q);u=rad*math.cos(a);v=rad*math.sin(a)*oval;h=t*math.sin(q)
            p=(u,v,h) if axis=='z' else (u,h,-v)
            verts.append(tuple(c[i]+p[i] for i in range(3)))
    for k in range(n):
        for j in range(cross):
            a=k*cross+j;d=k*cross+(j+1)%cross
            faces.append((a,d,((k+1)%n)*cross+(j+1)%cross,((k+1)%n)*cross+j))
    return tag(b.mesh('Soft rim',verts,faces,MAT),color,group)


def port(x,y,z,r=.003,group='Body'):
    # Recessed dark port, not a baked shadow. Six-sided coloured inner face.
    vs=[(x+r*math.cos(2*math.pi*k/6),y+r*math.sin(2*math.pi*k/6),z) for k in range(6)]
    return tag(b.mesh('Outlet',vs,[tuple(range(6))],MAT),'dark',group)


def paw(c,size=.015,color='pink',group='Body'):
    x,y,z=c
    ball((x,y-size*.22,z),(size*.38,size*.31,.0015),color,group,8,4)
    for dx,dy in [(-.47,.26),(0,.49),(.47,.26)]:
        ball((x+size*dx,y+size*dy,z),(size*.16,size*.19,.0015),color,group,6,3)


def grip(color='sky',length=.125,width=.032):
    ball((0,-.01,0),(width/2,length/2,.018),color,seg=12,rings=8)


def brush():
    reset();grip('wood',.128,.026)
    ball((0,.062,-.004),(.037,.046,.014),'wood',seg=16,rings=8)
    ball((0,.062,-.016),(.030,.039,.006),'wood_edge',seg=12,rings=6)
    for x in [-.020,-.01,0,.01,.020]:
        for y in [.040,.062,.084]:
            tube([(x,y,-.019),(x,y,-.034),(x,y,-.038)],[.0034,.0034,.0015],'cream',n=6)
    box((0,-.053,-.017),(.012,.006,.002),'wood_edge',r=.002)
    finish('brush',.20,'y')


def brush_slicker():
    reset();grip('pink',.123,.032)
    box((0,.067,0),(.103,.078,.026),'pink',r=.012)
    box((0,.067,-.015),(.091,.064,.008),'blush',r=.007)
    for ix in range(7):
        for iy in range(6):
            x=(ix-3)*.012;y=.067+(iy-2.5)*.010
            lathe((x,y,0),[(-.018,.0012),(-.033,.0012),(-.035,.0004)],'silver',n=6)
    ring((0,-.058,-.016),.006,.0016,'cream',n=12,cross=4)
    finish('brush_slicker',.20,'y')


def brush_electric():
    reset();grip('sky',.14,.038)
    box((0,-.015,-.019),(.023,.065,.006),'cream',r=.007)
    ball((0,.005,-.025),(.009,.012,.004),'red',seg=10,rings=6)
    for x in [-.007,0,.007]:ball((x,-.044,-.024),(.0018,.0018,.001),'mint',seg=6,rings=3)
    tube([(0,.033,0),(0,.066,-.005)],[.018,.022],'silver',n=12)
    p=(0,.072,-.010);PIVOTS['Head']=(p,'z','rotate')
    lathe(p,[(-.015,.041),(-.012,.047),(.008,.047),(.013,.040)],'sky',group='Head',n=24)
    lathe(p,[(-.019,.037),(-.016,.041)],'cream',group='Head',n=24)
    for k in range(12):
        a=2*math.pi*k/12;x=.028*math.cos(a);y=.072+.028*math.sin(a)
        ball((x,y,-.037),(.0037,.0037,.008),'pink','Head',8,4)
    for k in range(6):
        a=2*math.pi*k/6;ball((.013*math.cos(a),.072+.013*math.sin(a),-.038),(.0037,.0037,.008),'pink','Head',8,4)
    ball((0,.072,-.040),(.006,.006,.007),'mint','Head',8,4)
    finish('brush_electric',.22,'y')


def shower_wide():
    reset();grip('sky',.17,.029)
    tube([(0,-.089,0),(0,-.123,0),(.028,-.132,.012)],[.008,.007,.007],'cream',n=10)
    tube([(0,.047,0),(0,.091,-.004)],[.015,.024],'sky',n=12)
    c=(0,.090,-.006)
    lathe(c,[(-.018,.053),(-.012,.062),(.009,.062),(.016,.050)],'sky',n=28)
    lathe(c,[(-.022,.049),(-.019,.053)],'cream',n=28)
    for row in range(-3,4):
        for col in range(-3,4):
            x=col*.013;y=row*.013
            if x*x+y*y<.044**2:port(x,.090+y,-.029,.0028)
    finish('shower_wide',.28,'y')


def shower_rain():
    reset();grip('sky',.18,.035)
    box((0,-.005,-.019),(.019,.080,.005),'cream',r=.006)
    tube([(0,-.095,0),(0,-.151,.005),(.035,-.159,.013)],[.009,.008,.008],'silver',n=10)
    tube([(0,.05,0),(0,.077,-.006)],[.017,.025],'silver',n=12)
    c=(0,.073,-.010)
    lathe(c,[(-.010,.080),(-.006,.090),(.006,.090),(.012,.080)],'silver',n=32)
    lathe(c,[(-.014,.077),(-.011,.082)],'sky',n=32)
    for row in range(-5,6):
        for col in range(-5,6):
            x=col*.0136+(row%2)*.0068;y=row*.0120
            if x*x+y*y<.073**2:port(x,.073+y,-.025,.0024)
    finish('shower_rain',.32,'y')


def foam_pump():
    reset()
    lathe((0,0,0),[(-.095,.030),(-.090,.042),(.046,.042),(.061,.034),(.065,.020)],'mint',axis='y',n=24)
    box((0,-.012,-.042),(.047,.068,.004),'cream',r=.007)
    paw((0,-.011,-.045),.027)
    lathe((0,.070,0),[(-.007,.022),(.007,.022)],'silver',axis='y',n=18)
    p=(0,.080,0);PIVOTS['Pump']=(p,'y','translate')
    tube([(0,.073,0),(0,.101,0)],[.010,.010],'cream','Pump',n=12)
    box((0,.112,-.015),(.047,.022,.070),'mint','Pump',r=.008)
    box((0,.104,-.055),(.024,.014,.030),'cream','Pump',r=.006)
    lathe((0,.104,-.071),[(-.001,.006),(.001,.007)],'dark',group='Pump',n=10)
    finish('foam_pump',.22,'y')


def foam_cannon():
    reset();grip('pink',.12,.044)
    box((0,.025,-.012),(.041,.066,.073),'sky',r=.015)
    lathe((0,.075,0),[(-.186,.035),(-.163,.049),(.055,.049),(.088,.035)],'sky',n=20)
    lathe((0,.075,-.193),[(-.036,.044),(-.030,.052),(.012,.052),(.022,.043)],'pink',n=20)
    lathe((0,.075,-.231),[(-.005,.027),(.002,.027)],'cream',n=18)
    lathe((0,.075,-.237),[(-.002,.016),(.001,.016)],'dark',n=16)
    box((.035,.068,-.036),(.014,.046,.100),'pink',r=.006)
    box((-.035,.068,-.036),(.014,.046,.100),'pink',r=.006)
    tube([(0,.107,-.040),(0,.139,-.040)],[.025,.025],'cream',n=12)
    lathe((0,0,-.040),[(.135,.034),(.145,.047),(.231,.047),(.247,.034)],'mint',axis='y',n=20)
    lathe((0,.249,-.040),[(-.006,.034),(.006,.034)],'pink',axis='y',n=18)
    box((0,.187,-.086),(.052,.062,.004),'cream',r=.008)
    paw((0,.187,-.089),.026)
    box((0,.001,-.050),(.020,.030,.015),'red',r=.006)
    finish('foam_cannon',.35,'z')


def dryer_big():
    reset();grip('sky',.15,.045)
    box((0,-.010,-.025),(.027,.068,.007),'cream',r=.008)
    box((0,.030,-.029),(.023,.030,.010),'red',r=.007)
    # Hollow barrel profile: front aperture stays open so the separate Fan is visible.
    c=(0,.112,0)
    lathe(c,[(-.277,.077),(-.261,.085),(-.080,.070),(.096,.068),(.114,.055)],'sky',n=28)
    # Remove the front end cap only; retain the closed motor back cap.
    o=PARTS['Body'][-1];me=o.data
    # Rebuild without front n-gon (second-last polygon).
    verts=[tuple(v.co) for v in me.vertices];faces=[tuple(p.vertices) for i,p in enumerate(me.polygons) if i!=len(me.polygons)-2]
    old=me;o.data=bpy.data.meshes.new('Open dryer barrel');o.data.from_pydata(verts,[],faces);o.data.update();bpy.data.meshes.remove(old)
    # Reassign atlas UVs after replacing mesh data, without retagging the part list.
    PARTS['Body'].remove(o);tag(o,'sky')
    ring((0,.112,-.275),.074,.006,'silver',n=28,cross=6)
    lathe((0,.112,-.235),[(-.003,.065),(.002,.065)],'dark',n=24)
    p=(0,.112,-.248);PIVOTS['Fan']=(p,'z','rotate')
    ball(p,(.012,.012,.008),'pink','Fan',12,6)
    for k in range(4):
        a=k*math.pi/2+.3;x=.031*math.cos(a);y=.112+.031*math.sin(a)
        o=ball((x,y,-.249),(.023,.012,.003),'cream','Fan',12,5)
        # Rotate the flattened petal radially about its own centre.
        from mathutils import Quaternion
        o.rotation_mode='QUATERNION';o.rotation_quaternion=Quaternion(b.V((0,0,1)),a)
    for x in [-.036,.036]:
        box((x,.112,-.284),(.004,.114,.006),'sky',r=.002)
    for side in [-1,1]:
        for k in range(4):
            box((side*.064,.112+(k-1.5)*.014,.044),(.006,.006,.029),'slate',r=.002)
    finish('dryer_big',.40,'z')


def scissors():
    reset();p=(0,0,-.027)
    for side,name in [(-1,'Blade_L'),(1,'Blade_R')]:
        PIVOTS[name]=(p,'y','rotate')
        ring((side*.025,side*.003,.026),.017,.0047,'pink',axis='y',group=name,n=20,cross=6,oval=1.25)
        tube([(side*.019,side*.003,.008),(side*.009,side*.003,-.025),(-side*.005,side*.003,-.063)],[.007,.008,.006],'silver',name,n=8)
        # Broad, rounded closed tip; neither a point nor a bevelled sharp cutting edge.
        ball((-side*.010,side*.003,-.086),(.0075,.0038,.036),'silver',name,12,7)
        ball((-side*.011,side*.003-.0008,-.114),(.0062,.0040,.009),'cream',name,10,5)
    lathe(p,[(-.006,.009),(.006,.009)],'silver',axis='y',n=16)
    lathe((0,.007,-.027),[(-.001,.005),(.001,.005)],'pink',axis='y',n=12)
    # Put the root at the midpoint between the two finger-ring grip centres.
    for parts in PARTS.values():
        for o in parts:o.location += b.V((0,0,-.026))
    for name in ['Blade_L','Blade_R']:PIVOTS[name]=((0,0,-.053),'y','rotate')
    finish('scissors',.18,'z')


def finish(name,target,axis):
    global REPORT
    # Join the actual moving geometry to the named mesh; no armatures or dummy pivots.
    objects=[]
    for group,parts in PARTS.items():
        bpy.context.view_layer.update()
        o=b.join_into(parts[0],parts[1:]);o.name=group
        pivot=PIVOTS[group][0] if group in PIVOTS else (0,0,0)
        bpy.context.scene.cursor.location=b.V(pivot)
        bpy.context.view_layer.objects.active=o;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        objects.append(o)
    world=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    ai={'x':0,'y':2,'z':1}[axis]
    factor=target/(max(p[ai] for p in world)-min(p[ai] for p in world))
    for o in objects:
        o.location*=factor
        for v in o.data.vertices:v.co*=factor
    root=b.empty(name)
    root['units']='metres';root['forward']='-Z';root['palette']='original embedded albedo only'
    for o in objects:
        o.parent=root
        if o.name in PIVOTS:
            _,ax,mode=PIVOTS[o.name];o['motion_axis']=ax.upper();o['motion_type']=mode
    OUT.mkdir(parents=True,exist_ok=True)
    b.OUT=ROOT/'assets/models';b.export('tools',name)
    raw=(OUT/(name+'.glb')).read_bytes();j=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
    count=sum(j['accessors'][pr['indices']]['count']//3 for m in j['meshes'] for pr in m['primitives'])
    if count>3000:raise RuntimeError(f'{name}: {count} triangles exceeds 3000')
    assert len(j.get('images',[]))==1 and j['images'][0].get('mimeType')=='image/png'
    assert 'bufferView' in j['images'][0] and not j.get('skins') and not j.get('animations')
    assert not any('uri' in x for x in j.get('buffers',[])+j.get('images',[]))
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(lo+hi)/2
    gltf_xyz=lambda p:[round(p.x,6),round(p.z,6),round(-p.y,6)]
    REPORT[name]={'triangles':count,'texture':{'embedded':True,'mimeType':'image/png','size':[64,64]},'dimensions_m':[round(hi.x-lo.x,6),round(hi.z-lo.z,6),round(hi.y-lo.y,6)],'root_origin_m':[0,0,0],'size_axis':axis,'target_size_m':target,'joints':{o.name:{'pivot_m':gltf_xyz(o.location),'axis':PIVOTS[o.name][1].upper(),'motion':PIVOTS[o.name][2]} for o in objects if o.name in PIVOTS}}
    PREVIEW.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.camera_add(location=center+b.V((.38,.28,-.58)))
    cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO'
    cam.data.ortho_scale=max(hi-lo)*1.50
    scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=False
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.74,.79,.82,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
    for loc,power,size in [((-.32,.55,-.4),12,.5),((.4,.25,-.1),6,.4),((0,.3,.4),8,.4)]:
        bpy.ops.object.light_add(type='AREA',location=center+b.V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
    # Matte backdrop exists only in the preview, created after GLB export.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,lo.z-.012))
    floor=bpy.context.object;floor.data.materials.append(b.mat('Preview_Backdrop','#EDF2F3'))
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.5
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('TOOL_COMPLETE',name,count,flush=True)


if __name__=='__main__':
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(('brush','brush_slicker','brush_electric','shower_wide','shower_rain','foam_pump','foam_cannon','dryer_big','scissors'))
    for name in requested:globals()[name]()
    report_path=PREVIEW/'validation.json'
    previous=json.loads(report_path.read_text()) if report_path.exists() else {}
    previous.update(REPORT)
    report_path.write_text(json.dumps(previous,ensure_ascii=False,indent=2)+'\n')
