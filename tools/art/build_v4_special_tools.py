"""14 original matching pastel assets. Blender 4.2+, reuse previous delivery geometry helpers.
Run: blender -b --factory-startup --python tools/art/build_v4_special_tools.py
All design coordinates: metres, Y-up, working face -Z. No external assets.
"""
import sys, math, json, struct, tempfile
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_v4_tool_upgrades as a
b=a.b
ROOT=a.ROOT
PREVIEW=ROOT/'art/incoming/special_tools'
# Colour only, including opacity for two toy-clear shells. No normal/AO/emission maps.
COLORS=['8FD3F4','FF6B6B','FF9EC4','B8E3D3','E8C9A0','DDE5EA','FFF1D8','42576A','FFFFFF','759AB0','D4AF85','F9C3D8','F2EEE9','E9BE61','FFAB8A','FFE58C','B9E7A2','A2DCEB','A8BAF0','CAA6EB','F2B5DB','D6ECFA','D4F2E9','8FD3F4']
NAMES=a.NAMES+['pearl','gold','peach','lemon','lime','aqua','periwinkle','lavender','rose','ice','seam','glass']
RAIN=['red','peach','lemon','lime','aqua','periwinkle','lavender']
a.NAMES=NAMES

def reset():
    b.reset();a.PARTS.clear();a.PIVOTS.clear();a.PALETTE_MATS.clear()
    # Exact sRGB PNG bytes; no colour-management transform or baked lighting.
    import zlib
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    rows=[]
    for y in range(128):
        row=bytearray([0])
        for x in range(128):
            i=(y//16)*8+x//16
            row.extend(bytes.fromhex(COLORS[i] if i<len(COLORS) else 'FFFFFF'))
            row.append(51 if i==23 else 255)
        rows.append(bytes(row))
    path=Path(tempfile.gettempdir())/'special_tool_palette.png'
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b''))
    im=bpy.data.images.load(str(path),check_existing=False);im.name='Special_Set_Albedo';im.pack();a.ATLAS=im
    a.MAT=bpy.data.materials.new('Pastel_Colour_Only');a.MAT.use_nodes=True
    bs=a.MAT.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.8;bs.inputs['Metallic'].default_value=0;bs.inputs['Specular IOR Level'].default_value=0
    tex=a.MAT.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest'
    a.MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])

def tag(o,color,group='Body'):
    if color not in a.PALETTE_MATS:
        m=a.MAT.copy();m.name='Pastel_'+color
        if color=='glass':
            bs=m.node_tree.nodes.get('Principled BSDF');tex=next(n for n in m.node_tree.nodes if n.type=='TEX_IMAGE');m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=True
        a.PALETTE_MATS[color]=m
    o.data.materials.clear();o.data.materials.append(a.PALETTE_MATS[color]);uv=o.data.uv_layers.active or o.data.uv_layers.new(name='PaletteUV')
    uv.name='PaletteUV'
    i=NAMES.index(color);center=((i%8+.5)/8,1-(i//8+.5)/8)
    for p in o.data.polygons:
        for j,loop in enumerate(p.loop_indices):
            th=2*math.pi*j/len(p.loop_indices);uv.data[loop].uv=(center[0]+.003*math.cos(th),center[1]+.003*math.sin(th))
    a.PARTS.setdefault(group,[]).append(o);return o

a.tag=tag
ball,box,tube,lathe,ring,port,paw,grip=a.ball,a.box,a.tube,a.lathe,a.ring,a.port,a.paw,a.grip

def orb(c,s,color='white',group='Body',seg=10,rings=5):return ball(c,s,color,group,seg,rings)

def star(c,r,color='gold',group='Body',depth=.002):
    # Small blunt embossed five-point star, front faces -Z.
    x,y,z=c;vs=[]
    for dz in [-depth/2,depth/2]:
        for k in range(10):
            th=math.pi/2+k*math.pi/5;rr=r if k%2==0 else r*.55
            vs.append((x+rr*math.cos(th),y+rr*math.sin(th),z+dz))
    fs=[tuple(reversed(range(10))),tuple(range(10,20))]+[(k,(k+1)%10,(k+1)%10+10,k+10) for k in range(10)]
    return tag(b.mesh('Blunt star',vs,fs,a.MAT),color,group)

def cloud(c,s,color='pearl',group='Body'):
    x,y,z=c;sx,sy,sz=s
    for dx,dy,rr in [(-.60,-.10,.61),(0,.22,.80),(.60,-.08,.59)]:orb((x+dx*sx,y+dy*sy,z),(sx*rr,sy*rr,sz),color,group,10,5)

def arc(c,r,t,color,start,end,group='Body',steps=6):
    pts=[(c[0]+r*math.cos(start+(end-start)*i/steps),c[1]+r*math.sin(start+(end-start)*i/steps),c[2]) for i in range(steps+1)]
    tube(pts,t,color,group,n=5)

def rainbow(c,r,t,group='Body'):
    for k,col in enumerate(RAIN):arc(c,r,t,col,k*2*math.pi/7,(k+1)*2*math.pi/7,group,5)

def special_grip(color='pearl',length=.16,width=.036):
    grip(color,length,width)
    for y in [-.050,-.025,0,.025]:box((0,y,-.0205),(width*.62,.004,.004),'gold',r=.001)

def shower_massage():
    reset();grip('sky',.175,.033)
    tube([(0,.05,0),(0,.10,0)],[.016,.026],'silver',n=10)
    c=(0,.095,-.008)
    lathe(c,[(-.018,.061),(-.012,.072),(.010,.072),(.017,.059)],'sky',n=28)
    lathe(c,[(-.023,.058),(-.019,.063)],'silver',n=28)
    for r,count in [(.018,8),(.035,14),(.052,20)]:
        ring((0,.095,-.033),r,.0013,'sky',n=count,cross=4)
        for k in range(count):th=k*2*math.pi/count;port(r*math.cos(th),.095+r*math.sin(th),-.035,.0025)
    p=(0,-.005,-.024);a.PIVOTS['Dial']=(p,'z','rotate')
    lathe(p,[(-.006,.013),(.004,.013)],'silver',group='Dial',n=16)
    box((0,-.001,-.032),(.004,.016,.004),'red','Dial',r=.0015)
    tube([(0,-.09,0),(0,-.127,0)],[.008,.007],'silver',n=10)
    finish('shower_massage',.30,'y')

def shower_rainbow():
    reset();special_grip(length=.19,width=.039)
    tube([(0,.045,0),(0,.097,0)],[.020,.026],'gold',n=10)
    c=(0,.102,-.010)
    lathe(c,[(-.014,.077),(-.007,.087),(.011,.087),(.018,.074)],'pearl',n=28)
    lathe(c,[(-.020,.071),(-.015,.076)],'ice',n=28)
    a.PIVOTS['Ring']=(c,'z','rotate');rainbow((0,.102,-.020),.084,.005,'Ring')
    for rr,n in [(.022,6),(.048,12),(.064,16)]:
        for k in range(n):th=k*2*math.pi/n;star((rr*math.cos(th),.102+rr*math.sin(th),-.032),.0044,'slate',depth=.0015)
    cloud((0,.202,-.006),(.025,.018,.010))
    tube([(0,-.098,0),(0,-.126,0)],[.009,.008],'gold',n=10)
    finish('shower_rainbow',.35,'y')

def foam_sponge():
    reset();box((0,0,0),(.15,.1,.05),'pink',r=.022)
    for x,y,s in [(-.043,.02,.012),(-.020,.027,.018),(.010,.031,.011),(.034,.028,.016)]:orb((x,y,-.0233),(s,s,s*.65),'white',seg=10,rings=5)
    for k in range(9):
        x=(k%3-1)*.034;y=(k//3-1)*.024
        orb((x,y,-.029),(.003,.002,.0015),'blush',seg=6,rings=3)
    finish('foam_sponge',.15,'x')

def foam_cloud():
    reset();special_grip(length=.14,width=.052)
    lathe((0,.075,0),[(-.18,.049),(-.15,.063),(.10,.063),(.12,.045)],'sky',n=20)
    c=(0,.075,-.205)
    lathe(c,[(-.015,.061),(.02,.061)],'gold',n=20)
    # Moulded cloud nozzle, open central bore.
    for k in range(7):th=k*2*math.pi/7;orb((.053*math.cos(th),.075+.053*math.sin(th),-.225),(.025,.025,.024),'pearl',seg=10,rings=5)
    lathe((0,.075,-.226),[(-.005,.033),(.001,.033)],'ice',n=20)
    port(0,.075,-.233,.020)
    tube([(0,.13,-.025),(0,.158,-.025)],[.026,.026],'gold',n=10)
    # Clear low-poly jar. Bubbles are separate from shell and body.
    lathe((0,0,-.025),[(.155,.046),(.167,.057),(.275,.057),(.288,.045)],'glass',axis='y',n=20)
    for y in [.16,.285]:ring((0,y,-.025),.046,.005,'gold',axis='y',n=20,cross=4)
    a.PIVOTS['Bubbles']=((0,.222,-.025),'xyz','float')
    for i,(x,y,z,r) in enumerate([(-.024,.19,-.04,.017),(.020,.20,-.04,.021),(0,.232,-.03,.022),(-.023,.255,-.023,.018),(.022,.261,-.02,.015)]):
        orb((x,y,z),(r,r,r),RAIN[i+1],'Bubbles',10,5)
        orb((x-r*.25,y+r*.35,z-r*.88),(r*.15,r*.15,r*.04),'white','Bubbles',6,3)
    for side in [-1,1]:
        for i in range(3):orb((side*(.068+i*.012),.08+i*.009,-.015+i*.014),(.031-i*.005,.012,.016),'pearl',seg=8,rings=4)
    star((0,.07,-.066),.018,'gold');box((0,.012,-.035),(.021,.026,.014),'gold',r=.005)
    finish('foam_cloud',.40,'z')

def cloth(color,w,h,thick,folds=3):
    # Closed cloth with a real, softly pleated surface and rolled edge profile.
    nx,ny=18,12;verts=[]
    for side in [-1,1]:
        for iy in range(ny+1):
            yy=iy/ny*2-1
            for ix in range(nx+1):
                xx=ix/nx*2-1
                x=xx*w*.5*(1-.045*abs(yy)**10)
                y=yy*h*.5*(1-.045*abs(xx)**10)
                wave=.0055*math.sin(xx*math.pi*folds+.5)*math.cos(yy*1.2)+.0018*math.sin(yy*5+xx*2)
                edge=1-.38*max(abs(xx),abs(yy))**10
                z=-.008+wave+side*thick*.5*edge
                verts.append((x,y,z))
    layer=(nx+1)*(ny+1);faces=[]
    for iy in range(ny):
        for ix in range(nx):
            k=iy*(nx+1)+ix
            faces.append((k,k+nx+1,k+nx+2,k+1))
            faces.append((k+layer,k+1+layer,k+nx+2+layer,k+nx+1+layer))
    perimeter=list(range(nx+1))+[iy*(nx+1)+nx for iy in range(1,ny+1)]+[ny*(nx+1)+ix for ix in range(nx-1,-1,-1)]+[iy*(nx+1) for iy in range(ny-1,0,-1)]
    for i,k in enumerate(perimeter):j=perimeter[(i+1)%len(perimeter)];faces.append((k,j,j+layer,k+layer))
    return tag(b.mesh('Soft pleated cloth',verts,faces,a.MAT),color)


def towel():
    reset();cloth('blush',.25,.15,.024,3)
    # One white woven border line follows the cloth, on wiping side.
    pts=[(-.11+i*.022,-.052,-.024-.0045*math.sin((-.11+i*.022)/.25*math.pi*3+.5)) for i in range(11)]
    tube(pts,.0023,'white',n=6)
    finish('towel',.25,'x')

def towel_thick():
    reset();cloth('mint',.28,.18,.047,2)
    for y in [-.066,.066]:
        for i in range(12):x=-.117+i*.021;tube([(x,y,-.034),(x+.009,y,-.034)],.0011,'seam',n=5)
    tube([(-.125,-.075,.012),(-.125,0,.014),(-.125,.075,.012)],.002,'seam',n=6)
    finish('towel_thick',.28,'x')

def towel_microfiber():
    reset();cloth('sky',.28,.18,.043,2)
    for iy in range(7):
        yy=-.063+iy*.021
        pts=[(-.115+ix*.023,yy+.001*math.sin(ix),-.031-.0055*math.sin(((-.115+ix*.023)/.28*2)*math.pi*2+.5)*math.cos(yy/.18*2*1.2)) for ix in range(11)]
        tube(pts,.00065,'sky',n=5)
    for y in [-.078,.078]:tube([(-.12,y,-.025),(0,y,-.028),(.12,y,-.025)],.0023,'aqua',n=6)
    finish('towel_microfiber',.28,'x')

def towel_mitt():
    reset();orb((0,.008,0),(.057,.080,.026),'pink',seg=16,rings=8)
    orb((.051,-.005,0),(.025,.036,.023),'pink',seg=10,rings=5)
    box((0,-.067,.002),(.090,.036,.038),'white',r=.010)
    # Entire palm is -Z; white paw and raised chenille tufts.
    orb((0,.017,-.024),(.047,.057,.008),'blush',seg=12,rings=6)
    paw((0,.017,-.034),.067,'white')
    for side in [-1,1]:
        for k in range(6):orb((side*.040,-.026+k*.014,-.028),(.006,.007,.004),'blush',seg=6,rings=3)
    finish('towel_mitt',.20,'y')

def towel_cloud():
    reset()
    for x,y,sx,sy in [(-.085,-.012,.065,.058),(-.045,.027,.067,.066),(.022,.030,.073,.071),(.087,-.008,.063,.052),(0,-.039,.089,.049)]:
        orb((x,y,-.012),(sx,sy,.030),'pearl',seg=12,rings=6)
    # Small rolled rainbow piping along the lower edge, not baked lighting.
    for i,col in enumerate(RAIN):
        x=-.105+i*.035;tube([(x-.017,-.061,-.020),(x,-.066,-.029),(x+.017,-.061,-.020)],.0035,col,n=6)
    for x,y,r in [(-.056,.026,.015),(.021,.043,.019),(.081,.001,.012)]:star((x,y,-.045),r,'gold',depth=.003)
    finish('towel_cloud',.30,'x')

def open_barrel(c,profile,color,n=20):
    o=lathe(c,profile,color,n=n);me=o.data
    verts=[tuple(v.co) for v in me.vertices];fs=[tuple(p.vertices) for i,p in enumerate(me.polygons) if i!=len(me.polygons)-2]
    o.data=bpy.data.meshes.new('Open moulded barrel');o.data.from_pydata(verts,[],fs);o.data.update();bpy.data.meshes.remove(me);a.PARTS['Body'].remove(o);tag(o,color)

def fan(c,r,name='Fan',color='silver',spiral=False):
    a.PIVOTS[name]=(c,'z','rotate');orb(c,(r*.16,r*.16,.007),'gold' if spiral else 'sky',name,10,5)
    if spiral:
        for k in range(5):
            pts=[]
            for j in range(9):
                th=k*2*math.pi/5+j*.16;rr=r*(.17+.095*j);pts.append((c[0]+rr*math.cos(th),c[1]+rr*math.sin(th),c[2]))
            tube(pts,[r*.12]*len(pts),RAIN[k+2],name,n=5)
    else:
        for k in range(4):
            th=k*math.pi/2+.3;o=orb((c[0]+r*.49*math.cos(th),c[1]+r*.49*math.sin(th),c[2]),(r*.39,r*.17,.004),color,name,10,4)
            o.rotation_mode='QUATERNION';o.rotation_quaternion=Quaternion(b.V((0,0,1)),th)

def dryer_twin():
    reset();grip('mint',.15,.048);box((0,.018,-.026),(.025,.035,.008),'silver',r=.006)
    box((0,.095,-.02),(.148,.072,.17),'mint',r=.024)
    for side,name in [(-1,'Fan_L'),(1,'Fan_R')]:
        x=side*.052;c=(x,.115,0)
        open_barrel(c,[(-.265,.047),(-.245,.052),(.092,.044),(.13,.033)],'mint',20)
        ring((x,.115,-.263),.043,.005,'silver',n=20,cross=5)
        lathe((x,.115,-.231),[(-.002,.038),(.002,.038)],'dark',n=16)
        fan((x,.115,-.246),.036,name)
    finish('dryer_twin',.40,'z')

def dryer_turbo():
    reset();grip('sky',.16,.05);box((0,.025,-.026),(.025,.035,.012),'red',r=.007)
    c=(0,.123,0);open_barrel(c,[(-.288,.084),(-.267,.091),(-.07,.080),(.114,.070),(.13,.052)],'sky',24)
    ring((0,.123,-.285),.081,.006,'red',n=24,cross=5)
    lathe((0,.123,-.244),[(-.002,.073),(.002,.073)],'dark',n=20)
    fan((0,.123,-.263),.068,color='silver')
    for side in [-1,1]:
        for k in range(4):box((side*.073,.108+(k-1.5)*.018,.025),(.008,.008,.060),'slate',r=.003)
        tube([(side*.08,.138,-.07),(side*.078,.14,-.14),(side*.085,.14,-.21)],.0045,'red',n=6)
    finish('dryer_turbo',.42,'z')

def dryer_tornado():
    reset();special_grip(length=.16,width=.055)
    c=(0,.132,0);open_barrel(c,[(-.313,.092),(-.292,.099),(-.08,.080),(.11,.073),(.135,.05)],'pearl',24)
    ring((0,.132,-.308),.089,.005,'gold',n=28,cross=5)
    lathe((0,.132,-.258),[(-.002,.080),(.002,.080)],'dark',n=24)
    fan((0,.132,-.281),.078,'Spiral',spiral=True)
    # Painted-looking relief ribbons turn round the rim: blue -> purple.
    for k in range(12):
        th=k*2*math.pi/12;arc((0,.132,-.312),.096,.004,['sky','aqua','periwinkle','lavender'][k//3],th,th+.37,steps=3)
    ring((0,.132,.06),.073,.004,'gold',n=24,cross=4)
    cloud((0,-.087,0),(.024,.018,.018))
    star((0,.13,-.32),.012,'gold')
    finish('dryer_tornado',.45,'z')

def brush_twin():
    reset();grip('wood',.13,.030)
    box((0,.064,0),(.074,.078,.024),'wood',r=.012)
    for side,col,rows,rad in [(-1,'mint',4,.0032),(1,'silver',7,.0015)]:
        # Front coarse tines -Z, reverse fine tines +Z, both explicitly modelled.
        box((0,.064,side*.015),(.062,.066,.006),'mint',r=.007)
        for ix in range(rows):
            for iy in range(5):
                x=(ix-(rows-1)/2)*(.045/(rows-1));y=.064+(iy-2)*.012
                tube([(x,y,side*.017),(x,y,side*.033),(x,y,side*.037)],[rad,rad,rad*.4],col,n=6)
    finish('brush_twin',.22,'y')

def brush_sparkle():
    reset();special_grip('blush',.155,.043)
    orb((0,.004,-.025),(.010,.013,.004),'gold',seg=10,rings=5)
    tube([(0,.04,0),(0,.083,0)],[.018,.024],'gold',n=10)
    c=(0,.090,-.008);a.PIVOTS['Head']=(c,'z','rotate')
    lathe(c,[(-.020,.044),(-.014,.052),(.013,.052),(.018,.044)],'glass',group='Head',n=24)
    ring((0,.090,.009),.045,.004,'gold',group='Head',n=24,cross=5)
    ring((0,.090,-.028),.046,.003,'aqua',group='Head',n=24,cross=4)
    for x,y,r,col in [(-.017,.104,.012,'gold'),(.020,.095,.009,'lemon'),(-.005,.069,.010,'rose')]:star((x,y,-.013),r,col,'Head',depth=.003)
    for k in range(12):
        th=k*2*math.pi/12;orb((.033*math.cos(th),.090+.033*math.sin(th),-.034),(.004,.004,.008),'ice','Head',8,4)
    # Recognisable rounded heart charm, a single closed moulding.
    pts=[]
    for k in range(24):
        th=k*2*math.pi/24
        xx=.0012*16*math.sin(th)**3
        yy=-.087+.0012*(13*math.cos(th)-5*math.cos(2*th)-2*math.cos(3*th)-math.cos(4*th))
        pts.append((xx,yy))
    vs=[(x,y,z) for z in [-.007,.007] for x,y in pts]
    fs=[tuple(reversed(range(24))),tuple(range(24,48))]+[(k,(k+1)%24,(k+1)%24+24,k+24) for k in range(24)]
    heart=b.mesh('Heart charm',vs,fs,a.MAT)
    bevel=heart.modifiers.new('Soft heart edge','BEVEL');bevel.width=.0015;bevel.segments=2
    bpy.context.view_layer.objects.active=heart;bpy.ops.object.modifier_apply(modifier=bevel.name)
    tag(heart,'gold')
    finish('brush_sparkle',.25,'y')


REPORT={}
OUT=ROOT/'assets/models/tools'
def finish(name,target,axis):
    global REPORT
    # Join the actual moving geometry to the named mesh; no armatures or dummy pivots.
    objects=[]
    for group,parts in a.PARTS.items():
        bpy.context.view_layer.update()
        o=b.join_into(parts[0],parts[1:]);o.name=group
        pivot=a.PIVOTS[group][0] if group in a.PIVOTS else (0,0,0)
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
        if o.name in a.PIVOTS:
            _,ax,mode=a.PIVOTS[o.name];o['motion_axis']=ax.upper();o['motion_type']=mode
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
    REPORT[name]={'triangles':count,'texture':{'embedded':True,'mimeType':'image/png','size':[128,128]},'dimensions_m':[round(hi.x-lo.x,6),round(hi.z-lo.z,6),round(hi.y-lo.y,6)],'root_origin_m':[0,0,0],'size_axis':axis,'target_size_m':target,'joints':{o.name:{'pivot_m':gltf_xyz(o.location),'axis':a.PIVOTS[o.name][1].upper(),'motion':a.PIVOTS[o.name][2]} for o in objects if o.name in a.PIVOTS}}
    PREVIEW.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.camera_add(location=center+b.V((.38,.28,-.58)))
    cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO'
    cam.data.ortho_scale=max(hi-lo)*1.40
    scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.74,.79,.82,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
    for loc,power,size in [((-.32,.55,-.4),12,.5),((.4,.25,-.1),6,.4),((0,.3,.4),8,.4)]:
        bpy.ops.object.light_add(type='AREA',location=center+b.V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
    # Matte backdrop exists only in the preview, created after GLB export.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,lo.z-.012))
    floor=bpy.context.object;floor.data.materials.append(b.mat('Preview_Backdrop','#EDF2F3'))
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.9
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('TOOL_COMPLETE',name,count,flush=True)


IDS=['shower_massage','shower_rainbow','foam_sponge','foam_cloud','towel','towel_thick','towel_microfiber','towel_mitt','towel_cloud','dryer_twin','dryer_turbo','dryer_tornado','brush_twin','brush_sparkle']
if __name__=='__main__':
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    for name in requested:globals()[name]()
    report_path=PREVIEW/'validation.json'
    previous=json.loads(report_path.read_text()) if report_path.exists() else {}
    previous.update(REPORT);report_path.write_text(json.dumps(previous,ensure_ascii=False,indent=2)+'\n')
