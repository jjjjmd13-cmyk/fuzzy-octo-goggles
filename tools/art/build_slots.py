"""Blender 4.5: original Paws & Bubbles art; no downloaded meshes/materials.
Run: blender -b --factory-startup --python tools/art/build_slots.py -- dog
Coordinates in this source use the delivery convention: metres, Y-up, front -Z.
"""
import bpy, math, sys, json, os
from pathlib import Path
from mathutils import Vector
from math import sin, cos, pi
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/incoming'
PALETTE = dict(fur='#F5DEB3', cream='#FFF1D8', brown='#BD8454', dark='#30201F', eye='#20181C', iris='#89522F', white='#FFFCF5', pink='#FF8DA7', blue='#8FD3F4', red='#FF6B6B', mint='#DFF5EC', butter='#FFF1C9', wood='#E8C9A0', skin='#FFDCBD', pants='#70849E')
MATS={}
FUR=[]
PIVOTS={}

def V(p): return Vector((p[0], -p[2], p[1]))
def rgba(h):
    h=PALETTE.get(h,h).lstrip('#'); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c)+(1,)
def mat(name,color,rough=.72):
    if name in MATS:return MATS[name]
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=rgba(color);bs.inputs['Roughness'].default_value=rough
    m.diffuse_color=rgba(color);MATS[name]=m;return m

def reset():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.materials,bpy.data.images,bpy.data.meshes):
        for x in list(collection):
            if x.users==0:collection.remove(x)
    MATS.clear();FUR.clear();PIVOTS.clear()
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1

def pivot(o,p,parent=None):
    p=V(p)
    for v in o.data.vertices:v.co-=p
    o.location=p
    if parent:
        world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
        # matrix_world is evaluated lazily; explicitly retain the requested world joint.
        o.location=p-parent.matrix_world.translation
    PIVOTS[o.name]=tuple((p.x,p.z,-p.y))
    return o

def empty(name,p=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.location=V(p)
    if parent:
        o.parent=parent;o.location=V(p)-parent.matrix_world.translation
    bpy.context.view_layer.update();return o

def mesh(name,verts,faces,material,p=(0,0,0),parent=None,fur=None):
    me=bpy.data.meshes.new(name+'Mesh');me.from_pydata([V(v) for v in verts],[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    if material:o.data.materials.append(material)
    for f in me.polygons:f.use_smooth=True
    pivot(o,p,parent);bpy.context.view_layer.update()
    if fur:FUR.append((o,fur))
    return o

def uvball(name,c,s,material,p=None,parent=None,seg=24,rings=14,fur=None,shape=None):
    # Seam-free welded topology; UV generated independently of spherical poles later.
    verts=[(c[0],c[1]+s[1],c[2])]
    for j in range(1,rings):
        phi=pi*j/rings
        for i in range(seg):
            a=2*pi*i/seg; q=(sin(phi)*cos(a),cos(phi),sin(phi)*sin(a))
            if shape:q=shape(*q)
            verts.append(tuple(c[k]+s[k]*q[k] for k in range(3)))
    verts.append((c[0],c[1]-s[1],c[2]));bottom=len(verts)-1
    faces=[]
    # All faces point outwards under the right-handed coordinate conversion.
    for i in range(seg):faces.append((0,1+(i+1)%seg,1+i))
    for j in range(rings-2):
        for i in range(seg):
            a=1+j*seg+i;b=1+j*seg+(i+1)%seg;d=a+seg;cc=b+seg
            faces.append((a,b,cc,d))
    for i in range(seg):faces.append((bottom,1+(rings-2)*seg+i,1+(rings-2)*seg+(i+1)%seg))
    return mesh(name,verts,faces,material,p or c,parent,fur)

def join_into(target,parts):
    bpy.ops.object.select_all(action='DESELECT');target.select_set(True)
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=target;bpy.ops.object.join();bpy.context.view_layer.update();return target

def tube(name,points,radii,material,p=None,parent=None,n=12,fur=None):
    verts=[]
    for j,q in enumerate(points):
        tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
        tangent.normalize();axis=Vector((1,0,0))
        if abs(tangent.dot(axis))>.9:axis=Vector((0,0,1))
        u=tangent.cross(axis).normalized();v=tangent.cross(u)
        r=radii[j];r=(r,r) if isinstance(r,(float,int)) else r
        for i in range(n):
            a=2*pi*i/n;off=u*cos(a)*r[0]+v*sin(a)*r[1]
            verts.append(tuple(Vector(q)+off))
    faces=[]
    for j in range(len(points)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces+=[tuple(reversed(range(n))),tuple((len(points)-1)*n+i for i in range(n))]
    return mesh(name,verts,faces,material,p or points[0],parent,fur)

def box(name,c,size,material,bevel=.025,p=None,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=V(c));o=bpy.context.object;o.name=name
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft moulded edges','BEVEL');mod.width=bevel;mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # Bake geometry positions before assigning the articulation origin.
    loc=o.location.copy()
    for v in o.data.vertices:v.co+=loc
    o.location=(0,0,0)
    o.data.materials.append(material)
    for f in o.data.polygons:f.use_smooth=True
    pivot(o,p or (0,0,0),parent)
    mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.context.view_layer.update();return o

def disc(name,c,r,h,material,n=48,p=(0,0,0),parent=None):
    # Rounded cylinder profile, with coplanar centre caps.
    profile=[(0,-h/2),(r-.006,-h/2),(r,-h/2+.006),(r,h/2-.006),(r-.006,h/2),(0,h/2)]
    verts=[]
    for rad,y in profile:
        for i in range(n):a=2*pi*i/n;verts.append((c[0]+rad*cos(a),c[1]+y,c[2]+rad*sin(a)))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            if profile[j][0]==0:faces.append((a,a+n,b+n))
            elif profile[j+1][0]==0:faces.append((a,a+n,b))
            else:faces.append((a,a+n,b+n,b))
    return mesh(name,verts,faces,material,p,parent)

def atlas():
    # Each fur object's triangular islands have a distinct, padded atlas cell.
    # Texture colors, including the brown ear, survive the runtime fur override.
    from array import array
    side=1024; grid=math.ceil(math.sqrt(len(FUR)));px=array('f',[1,1,1,1])*(side*side)
    image=bpy.data.images.new('Dog_Clean_Albedo',width=side,height=side,alpha=True)
    image.colorspace_settings.name='sRGB'
    for idx,(o,color) in enumerate(FUR):
        col=rgba(color); # Image pixel API takes linear values, which PNG save converts to sRGB.
        x0=int((idx%grid)*side/grid);x1=int((idx%grid+1)*side/grid)
        y0=int((idx//grid)*side/grid);y1=int((idx//grid+1)*side/grid)
        # Blender generated image pixels are stored in scene-linear color space.
        row=array('f',col)*(x1-x0)
        for y in range(y0,y1):px[(y*side+x0)*4:(y*side+x1)*4]=row
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        # Constant-color fur needs no painted directional detail. Give every triangle
        # its own padded island: mathematically no overlapping UVs, including the
        # disconnected muzzle/forelock surfaces and the curved shoulder joints.
        mod=o.modifiers.new('UV triangle layout','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        if not o.data.uv_layers:o.data.uv_layers.new(name='CleanFurUV')
        count=len(o.data.polygons);cols=math.ceil(math.sqrt(count));rows=math.ceil(count/cols)
        for k,poly in enumerate(o.data.polygons):
            for loop,corner in zip(poly.loop_indices,[(.12,.12),(.88,.12),(.12,.88)]):
                u=(k%cols+corner[0])/cols;v=(k//cols+corner[1])/rows
                o.data.uv_layers.active.data[loop].uv=((idx%grid+.045+u*.91)/grid,(idx//grid+.045+v*.91)/grid)
        o.data.materials.clear();o.data.materials.append(mat('FurClean','white'))
    image.pixels.foreach_set(px);image.update()
    # save_render applies the Standard view to linear colors; no lighting is baked.
    path=OUT/'dog'/'dog_clean_albedo.png';path.parent.mkdir(parents=True,exist_ok=True)
    image.filepath_raw=str(path);image.file_format='PNG';image.save()
    # Generated image.save writes linear pixel components as raw sRGB numbers.
    # Reload a PNG written with explicit sRGB palette bytes for unambiguous clean albedo.
    # The companion PNG is temporary; only the packed texture is delivered.
    return image

def dog():
    reset();fur=mat('FurClean','white');dark=mat('MouthInterior','dark');white=mat('EyeWhite','white');iris=mat('Iris','iris',.42);black=mat('Pupil','eye',.35);nose=mat('Nose','dark',.5);pink=mat('Tongue','pink')
    body=uvball('Torso',(0,.213,.065),(.132,.19,.145),fur,p=(0,.21,.065),seg=28,rings=16,fur='fur',shape=lambda x,y,z:(x*(1-.14*y),y,z))
    chest=uvball('Chest',(0,.247,-.048),(.106,.137,.095),fur,p=(0,.247,-.048),seg=24,rings=14,fur='cream')
    head=uvball('Head',(0,.445,-.063),(.173,.145,.144),fur,p=(0,.325,-.015),seg=32,rings=20,fur='fur',shape=lambda x,y,z:(x*(1+.05*(-y)),y,z*(1+.035*(-y))))
    # Cheeks and the short twin muzzle are attached to the neck-controlled head.
    for side,tag in [(-1,'L'),(1,'R')]:
        uvball('Cheek_'+tag,(side*.11,.37,-.145),(.063,.057,.057),fur,parent=head,seg=16,rings=10,fur='fur')
    muzzle=[]
    for side in [-1,1]:muzzle.append(uvball('Muzzle',(side*.039,.385,-.205),(.057,.043,.045),fur,p=(0,.325,-.015),seg=20,rings=10))
    join_into(head,muzzle)
    # Small swept locks give the silhouette a puppy shape, without baking fluffy state.
    locks=[]
    for i,(x,z,dx) in enumerate([(-.072,-.045,-.025),(-.025,-.055,-.018),(.022,-.035,.01),(.066,-.015,.026)]):
        locks.append(tube('CrownLock',[(x,.568,z),(x+dx*.6,.585,z-.023),(x+dx*1.7,.594-i*.002,z-.062)],[.024,.017,.002],fur,p=(0,.325,-.015),n=8))
    join_into(head,locks)
    # Drooping ears are swept, flattened volumes, with pivots at the skull attachment.
    for side,tag in [(-1,'L'),(1,'R')]:
        ear=uvball('Ear_'+tag,(side*.19,.425,-.026),(.068,.112,.061),fur,p=(side*.139,.522,-.032),parent=head,seg=24,rings=16,fur='brown' if tag=='L' else 'fur',shape=lambda x,y,z:(x*(1-.22*y)+side*.24*(-y),y,z*(1-.10*y)))
        # all eye subparts follow the exact Eye_L/R pivot when blinking.
        x=side*.073
        eye=uvball('Eye_'+tag,(x,.455,-.191),(.043,.051,.022),white,parent=head,seg=24,rings=12)
        uvball('Pupil_Iris_'+tag,(x,.454,-.211),(.031,.039,.010),iris,parent=eye,seg=20,rings=12)
        uvball('Pupil_'+tag,(x-side*.003,.456,-.220),(.023,.030,.006),black,parent=eye,seg=20,rings=12)
        uvball('Glint_'+tag,(x-.010,.471,-.226),(.008,.010,.003),white,parent=eye,seg=12,rings=8)
        # Brows follow Head and are exempt from the fur material override.
        tube('NoFur_Brow_'+tag,[(x-side*.027,.518,-.17),(x,.527,-.177),(x+side*.021,.518,-.171)],[.0035,.006,.0035],mat('Brow','brown'),parent=head,n=8)
    mouth=uvball('Mouth',(0,.353,-.203),(.062,.033,.012),dark,parent=head,seg=24,rings=12)
    uvball('Tongue',(0,.335,-.219),(.024,.029,.008),pink,p=(0,.351,-.218),parent=head,seg=20,rings=12)
    uvball('Nose',(0,.405,-.251),(.035,.023,.020),nose,parent=head,seg=24,rings=12,shape=lambda x,y,z:(x*(.85+.15*y),y,z))
    for side,tag in [(-1,'L'),(1,'R')]:
        x=side*.083
        leg=tube('Leg_F'+tag,[(x,.291,-.056),(x,.225,-.082),(x,.12,-.114),(x,.058,-.129)],[(.032,.038),(.035,.04),(.035,.04),(.037,.037)],fur,p=(x,.291,-.056),n=16,fur='fur')
        # The paw remains on its leg when the shoulder is animated.
        paw=uvball('Paw_F'+tag,(x,.035,-.143),(.049,.035,.056),fur,parent=leg,seg=18,rings=10,fur='fur')
        toes=[]
        for dx in [-.026,0,.026]:toes.append(uvball('Toe',(x+dx,.029,-.179),(.019,.027,.025),fur,p=(x,.035,-.143),seg=12,rings=8))
        join_into(paw,toes)
        uvball('Haunch_'+tag,(side*.116,.108,.11),(.075,.102,.095),fur,p=(side*.11,.15,.10),seg=20,rings=12,fur='fur')
        uvball('Paw_B'+tag,(side*.132,.032,.072),(.055,.032,.069),fur,p=(side*.13,.045,.075),seg=16,rings=10,fur='fur')
    parent=None
    for i,(a,b,c,r) in enumerate([((0,.088,.169),(0,.092,.215),(0,.121,.245),.038),((0,.121,.245),(0,.161,.267),(0,.199,.27),.033),((0,.199,.27),(0,.234,.258),(0,.253,.238),.029)]):
        parent=tube('Tail_'+str(i+1),[a,b,c],[r,r*.92,.022 if i<2 else .002],fur,p=a,parent=parent,n=12,fur='fur')
    empty('FaceCenter',(0,.454,-.213),head);empty('BodyCenter',(0,.213,.065))
    reduce_budget(7600)
    img=atlas()
    # Use exact unlit palette values in an sRGB PNG (no AO, highlights or shadows).
    import struct,zlib
    grid=math.ceil(math.sqrt(len(FUR)));W=1024;raw=bytearray()
    for y in range(W):
        raw.append(0)
        for x in range(W):
            idx=min(grid-1,int((W-1-y)*grid/W))*grid+min(grid-1,int(x*grid/W))
            h=PALETTE.get(FUR[idx][1],FUR[idx][1]) if idx<len(FUR) else '#FFFFFF'
            raw.extend(bytes.fromhex(h.lstrip('#'))+b'\xff')
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    path=OUT/'dog'/'dog_clean_albedo.png';path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,W,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
    bpy.data.images.remove(img);img=bpy.data.images.load(str(path));img.name='Dog_Clean_Albedo';img.pack()
    node=fur.node_tree.nodes.new('ShaderNodeTexImage');node.image=img;fur.node_tree.links.new(node.outputs['Color'],fur.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    export('dog');path.unlink()


def owner():
    reset();skin=mat('Skin','skin');shirt=mat('Shirt','#FFFFFF');hatmat=mat('Hat','#FFFFFF');pants=mat('Trousers','pants');hair=mat('Hair','#684A3B');dark=mat('Face','dark');pink=mat('Blush','#F5ABAD');shoe=mat('Shoes','#FAEBD9')
    body=empty('Body')
    box('ShirtTorso',(0,.635,0),(.46,.40,.285),shirt,.10,parent=body)
    # 0.75m head+hat, 0.8m lower body: approximately two heads tall.
    head=uvball('Head',(0,1.136,0),(.288,.314,.247),skin,p=(0,.832,0),parent=body,seg=24,rings=16)
    for side,tag in [(-1,'L'),(1,'R')]:
        uvball('Ear_'+tag,(side*.28,1.115,0),(.042,.067,.05),skin,parent=head,seg=12,rings=8)
        uvball('Eye_'+tag,(side*.095,1.15,-.236),(.022,.033,.010),dark,parent=head,seg=12,rings=8)
        uvball('Cheek_'+tag,(side*.166,1.074,-.208),(.040,.021,.008),pink,parent=head,seg=12,rings=8)
        # Curved arms hang freely, each combined sleeve/hand mesh has its shoulder origin.
        arm=tube('Arm_'+tag,[(side*.234,.772,0),(side*.29,.702,-.003),(side*.301,.57,-.02),(side*.298,.49,-.032)],[.065,.066,.055,.05],shirt,p=(side*.234,.772,0),parent=body,n=12)
        hand=uvball('Hand',(side*.298,.462,-.033),(.058,.063,.06),skin,p=(side*.234,.772,0),seg=12,rings=8)
        join_into(arm,[hand])
        leg=box('Leg_'+tag,(side*.115,.279,0),(.17,.37,.19),pants,.055,p=(side*.115,.451,0),parent=body)
        boot=box('Shoe',(side*.115,.068,-.047),(.195,.136,.29),shoe,.055,p=(side*.115,.451,0))
        join_into(leg,[boot])
    uvball('Nose',(0,1.105,-.257),(.034,.03,.034),skin,parent=head,seg=12,rings=8)
    tube('Smile',[(-.045,1.042,-.226),(0,1.029,-.24),(.045,1.042,-.226)],[.006,.007,.006],dark,parent=head,n=8)
    # A curved bob fringe and soft cap, designed as a toy customer.
    for i,x in enumerate([-.18,-.09,0,.09,.18]):
        uvball('Fringe'+str(i),(x,1.338-abs(x)*.24,-.155),(.069,.085,.07),hair,parent=head,seg=12,rings=8)
    cap=uvball('CapCrown',(0,1.395,.025),(.292,.155,.245),hatmat,parent=head,seg=24,rings=12)
    box('CapBrim',(0,1.386,-.18),(.48,.045,.24),hatmat,.020,parent=head)
    reduce_budget(3900)
    export('owner')

def tub():
    reset();blue=mat('CeramicBlue','blue');inside=mat('TubInterior','#B8E6F7');red=mat('PlugRed','red');wood=mat('RackWood','wood');standmat=mat('StandEnamel','#EAF9FA');metal=mat('Hook','#C8E7E9')
    stand=box('Stand',(0,.848,0),(1.6,.104,1.1),standmat,.045)
    parts=[]
    for x in [-.64,.64]:
        for z in [-.39,.39]:parts.append(box('Support',(x,.405,z),(.105,.81,.105),blue,.035))
    parts.append(box('Shelf',(0,.22,0),(1.39,.07,.9),blue,.03));join_into(stand,parts)
    # Continuous, genuinely open bowl. Its front lip is lower than the back.
    n=64; profile=[(.0,.906),(.49,.906),(.535,.912),(.555,.925),(.562,.99),(.57,1.04),(.587,1.06),(.608,1.053),(.619,1.036),(.62,.933),(.603,.9),(.57,.885),(.0,.885)]
    verts=[]
    for j,(r,y) in enumerate(profile):
        for i in range(n):
            a=2*pi*i/n;front=max(0,-sin(a))
            # Rim y=1.06 at back, 0.988 at camera-facing -Z side.
            drop=.072*front**2 * max(0,min(1,(y-.905)/.115))
            verts.append((r*cos(a),y-drop,r*sin(a)))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            if profile[j][0]==0:faces.append((a,b+n,a+n))
            elif profile[j+1][0]==0:faces.append((a,b,a+n))
            else:faces.append((a,b,b+n,a+n))
    bowl=mesh('Tub',verts,faces,inside);bowl.data.materials.append(blue)
    for f in bowl.data.polygons:
        if f.index//n>=6:f.material_index=1
    disc('Plug',(.28,.918,.20),.045,.018,red,n=24,p=(.28,.918,.20))
    # Right-hand rack as viewed from in front of the delivery model.
    rack=box('ToolRack',(.72,1.077,.18),(.075,.43,.065),wood,.025)
    pieces=[box('RackPost',(.72,1.077,.48),(.075,.43,.065),wood,.025),box('RackRail',(.72,1.285,.33),(.08,.07,.43),wood,.025)]
    for z in [.19,.28,.37,.46]:
        pieces.append(tube('Hook',[(.72,1.275,z),(.67,1.23,z),(.635,1.225,z),(.63,1.25,z)],[.012]*4,metal,n=8))
    join_into(rack,pieces)
    for v in rack.data.vertices:v.co.x *= -1 # viewer's right from the -Z front
    export('tub')

def turntable():
    reset();m=mat('PlatePorcelain','#FFFFFF');plate=disc('Plate',(0,0,0),.5,.04,m,n=64)
    # Printed albedo paw medallions, with an exactly flat y=+0.02 top surface.
    # No geometry above the plate and no normals, AO or baked lighting.
    if not plate.data.uv_layers:plate.data.uv_layers.new(name='PlateUV')
    for loop in plate.data.loops:
        v=plate.data.vertices[loop.vertex_index].co
        plate.data.uv_layers.active.data[loop.index].uv=(v.x+.5,-v.y+.5)
    import struct,zlib
    W=512;raw=bytearray();paws=[(.34*cos(a),.34*sin(a)) for a in [pi/4,3*pi/4,5*pi/4,7*pi/4]]
    ellipses=[]
    for cx,cz in paws:
        ellipses.append((cx,cz,.032,.028))
        for dx,dz in [(-.032,-.027),(-.012,-.044),(.014,-.044),(.035,-.025)]:ellipses.append((cx+dx,cz+dz,.011,.014))
    for iy in range(W):
        raw.append(0);z=(W-1-iy+.5)/W-.5
        for ix in range(W):
            x=(ix+.5)/W-.5
            ink=any(((x-a)/rx)**2+((z-b)/rz)**2<1 for a,b,rx,rz in ellipses)
            raw.extend(bytes.fromhex('D2C9D9' if ink else 'EFE9F1')+b'\xff')
    def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    path=OUT/'turntable'/'plate_albedo.png';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,W,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
    image=bpy.data.images.load(str(path));image.pack();node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
    m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    export('turntable');path.unlink()


def chair():
    reset();wood=mat('ChairWood','wood');pink=mat('SeatCushion','#FFB9CD');white=mat('Feet','#FFFAED')
    seat=box('Seat',(0,.36,0),(.45,.08,.42),wood,.035)
    box('Cushion',(0,.394,-.01),(.418,.012,.38),pink,.005)
    for x in [-.165,.165]:
        for z in [-.15,.15]:
            box('Leg',(x,.16,z),(.055,.32,.055),wood,.015)
            box('Foot',(x,.018,z),(.06,.036,.06),white,.012)
    box('Back',(0,.57,.175),(.44,.23,.055),wood,.025)
    for x in [-.16,.16]:box('BackUpright',(x,.45,.175),(.045,.26,.045),wood,.014)
    # Small carved paw ornament, using a flat albedo color and real geometry.
    pad=mat('ChairPaw','#D1AB84')
    uvball('PawPad',(0,.57,.144),(.034,.025,.003),pad,seg=12,rings=6)
    for x,y in [(-.041,.602),(-.016,.619),(.016,.619),(.041,.602)]:uvball('PawToe',(x,y,.144),(.012,.016,.003),pad,seg=8,rings=4)
    reduce_budget(1450)
    export('chair')

def tiles():
    reset();mint=mat('FloorTile','mint');yellow=mat('WallTile','butter');grout=mat('Grout','#F8FFF9')
    # Two separate modules; floor top=0, wall bottom=0, room-facing side=+Z.
    for kind,color in [('floor',mint),('wall',yellow)]:
        reset();color=mat('FloorTile' if kind=='floor' else 'WallTile','mint' if kind=='floor' else 'butter');grout=mat('Grout','#F8FFF9')
        if kind=='floor':
            box('FloorBase',(0,-.035,0),(2,.05,2),grout,.0)
            for i in range(4):
                for j in range(4):box('FloorTile_%d_%d'%(i,j),(-.75+i*.5,-.018,-.75+j*.5),(.492,.036,.492),color,.008)
        else:
            box('WallBase',(0,1,-.004),(2,2,.292),grout,0)
            for i in range(4):
                for j in range(4):box('WallTile_%d_%d'%(i,j),(-.75+i*.5,.25+j*.5,.142),(.492,.492,.016),color,.006)
        export('tiles',kind)

def reduce_budget(limit):
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    total=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    if total<=limit:return
    for o in meshes:
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Delivery triangle budget','DECIMATE');mod.ratio=limit/total*.99
        bpy.ops.object.modifier_apply(modifier=mod.name)


def export(slot,filename=None):
    dest=OUT/slot;dest.mkdir(parents=True,exist_ok=True)
    # Fix normals consistently; all transforms are baked into local mesh data.
    import bmesh
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bm.to_mesh(o.data);bm.free();o.data.update();o.data.calc_loop_triangles()
            for f in o.data.polygons:f.use_smooth=True
            bpy.context.view_layer.objects.active=o;o.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    bpy.context.view_layer.update()
    path=dest/((filename or slot)+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True,export_materials='EXPORT',export_extras=True)
    print('DELIVERED',path,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['dog']
    for slot in args:globals()[slot]()
