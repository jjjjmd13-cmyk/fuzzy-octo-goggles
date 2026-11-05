"""Original album props. Blender 4.2+. Metres/Y-up/front -Z; embedded clean PNG only."""
import sys,math,json,struct,zlib
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent));import build_slots as B
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/incoming/album'
COLORS={'pink':'#FF9EC4','pink_dark':'#E88CAF','blue':'#8FD3F4','mint':'#B8E3D3','cream':'#FFF1C9','wood':'#E8C9A0','cork':'#D2AC7D','gold':'#EAC66D','paper':'#FFFCF2','cherry':'#FF6B6B'}
PARTS=[]

def parent(o,p):
    bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=p;o.matrix_world=w;bpy.context.view_layer.update();return o

def box(name,c,size,color,r=.005,segments=2,p=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=B.V(c));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if r:
        mod=o.modifiers.new('Rounded toy edges','BEVEL');mod.width=r;mod.segments=segments;bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in o.data.polygons:poly.use_smooth=True
    mod=o.modifiers.new('Soft face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    if p is not None:
        old=o.matrix_world.copy();o.location=B.V(p);inv=o.matrix_world.inverted()
        for v in o.data.vertices:v.co=inv@old@v.co
    PARTS.append((o,color));return o

def ball(name,c,s,color,seg=8,rings=4):
    o=B.uvball(name,c,s,None,seg=seg,rings=rings);PARTS.append((o,color));return o

def ribbon(name,c,scale=1,plane='XZ'):
    # Joined flattened toy ribbon volumes; knot, two lobes and two notched tails.
    x,y,z=c
    def P(a,b,h=0):return (x+a*scale,y+h*scale,z+b*scale) if plane=='XZ' else (x+a*scale,y+b*scale,z-h*scale)
    def S(a,b,h):return (a*scale,h*scale,b*scale) if plane=='XZ' else (a*scale,b*scale,h*scale)
    parts=[]
    for side in [-1,1]:parts.append(ball(name+'Loop',P(side*.018,0),S(.019,.011,.0035),'blue',seg=8,rings=3))
    knot=ball(name,P(0,0,.0015),S(.008,.008,.005),'blue',seg=8,rings=3)
    for side in [-1,1]:
        vv=[P(side*.004,-.004,-.001),P(side*.012,-.005,-.001),P(side*.019,-.031,-.001),P(side*.011,-.026,-.001),P(side*.005,-.031,-.001)]
        o=B.mesh(name+'Tail',vv,[(0,1,2,3,4)],None);PARTS.append((o,'blue'));parts.append(o)
    # Keep parts separate for deterministic one-color UV assignment; parent all to Cover later.
    return [knot]+parts

def texture():
    names=list(COLORS);W=512;H=32;raw=bytearray()
    for y in range(H):
        raw.append(0)
        for key in names+['cream']*(16-len(names)):raw.extend(bytes.fromhex(COLORS[key][1:])*32)
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    temp=OUT/'_palette.png';temp.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b''))
    im=bpy.data.images.load(str(temp));im.name='Album_Clean_Palette';im.pack();im.colorspace_settings.name='sRGB'
    m=B.mat('AlbumPastelAlbedo','#FFFFFF',.80);n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    m.use_backface_culling=False
    for o,key in PARTS:
        o.data.materials.clear();o.data.materials.append(m)
        if not o.data.uv_layers:o.data.uv_layers.new(name='ColorUV')
        for uv in o.data.uv_layers.active.data:uv.uv=((names.index(key)+.5)/16,.5)
    return temp

def export(name,root):
    temp=texture()
    for o in list(bpy.context.scene.objects):
        if o!=root and o.parent is None:parent(o,root)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False,export_normals=True,export_texcoords=True)
    temp.unlink();count=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH');print('ALBUM_PROP',name,count,'triangles')

def book():
    B.reset();PARTS.clear();root=B.empty('AlbumBook')
    box('BackCover',(0,.004,0),(.35,.008,.28),'pink',.003,2)
    box('Pages',(.002,.030,0),(.326,.044,.256),'paper',.005,2)
    box('Spine',(-.169,.031,0),(.012,.052,.277),'pink_dark',.003,1)
    for y in [.020,.030,.040]:
        box('PageEdgeFront',(.002,y,-.1281),(.311,.0007,.0004),'cream',0)
        box('PageEdgeSide',(.1651,y,0),(.0004,.0007,.245),'cream',0)
    hinge=(-.175,.052,0)
    cover=box('Cover',(0,.056,0),(.35,.008,.28),'pink',.003,2,p=hinge)
    # Rest mesh stays horizontal; glTF local Y follows the long book spine.
    # Blender-local Z corresponds to glTF-local Y after Y-up export.
    old=cover.matrix_world.copy();new=Matrix.Translation(B.V(hinge))@Matrix.Rotation(math.pi/2,4,'X')
    for v in cover.data.vertices:v.co=new.inverted()@old@v.co
    cover.matrix_world=new;bpy.context.view_layer.update()
    pad=ball('GoldPawPad',(.012,.0618,-.012),(.029,.0018,.023),'gold',seg=10,rings=4);parent(pad,cover)
    for i,(x,z) in enumerate([(-.028,.019),(-.009,.032),(.014,.032),(.033,.019)]):parent(ball('GoldPawToe_'+str(i+1),(x+.012,.0616,z),(.010,.0016,.012),'gold',seg=8,rings=4),cover)
    for o in ribbon('Ribbon',(.080,.062,-.121),.8,'XZ'):parent(o,cover)
    export('album_book',root)

def board():
    B.reset();PARTS.clear();root=B.empty('PhotoBoard')
    box('BoardBack',(0,0,-.006),(.98,.68,.012),'wood',0)
    box('Cork',(0,0,-.018),(.916,.616,.018),'cork',.006,2)
    for side,tag in [(-1,'Left'),(1,'Right')]:box('Frame'+tag,(side*.475,0,-.020),(.05,.70,.04),'wood',.010,2)
    for side,tag in [(-1,'Bottom'),(1,'Top')]:box('Frame'+tag,(0,side*.325,-.020),(.90,.05,.04),'wood',.010,2)
    cx,cy,cz=-.38,.307,-.045
    for i in range(5):
        a=2*math.pi*i/5;ball('FlowerPetal_'+str(i+1),(cx+math.cos(a)*.021,cy+math.sin(a)*.021,cz),(.019,.017,.005),'pink',seg=8,rings=3)
    ball('FlowerCenter',(cx,cy,cz-.004),(.013,.013,.005),'gold',seg=8,rings=3)
    for side in [-1,1]:ball('FlowerLeaf',(cx+side*.037,cy-.015,cz+.002),(.018,.009,.0035),'mint',seg=8,rings=3)
    ribbon('BoardRibbon',(.375,.318,-.045),1,'XY')
    for i,(x,y,a) in enumerate([(-.30,.14,-4),(0,.14,3),(.30,.14,-2),(-.30,-.14,3),(0,-.14,-3),(.30,-.14,4)]):
        o=B.empty('Slot_'+str(i+1),(x,y,-.029));o.rotation_euler.y=math.radians(-a)
        # Blender Z-up: rotation about local -Y becomes glTF +Z in-plane tilt.
        o.rotation_euler=(0,math.radians(-a),0)
    export('photo_board',root)
if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);book();board()
