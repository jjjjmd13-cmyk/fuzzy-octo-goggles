"""Second art direction: restrained retail simulator materials and proportions.
Uses only original procedural geometry and pigment textures, not Steam assets.
Blender 4.5.3: --python tools/art/build_retail_slots.py -- dog owner tub turntable chair tiles
"""
import sys,math,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_slots as B
import bpy,bmesh
from mathutils import Vector
from math import sin,cos,pi
ROOT=B.ROOT;OUT=B.OUT
ball=B.uvball;tube=B.tube;box=B.box;mesh=B.mesh;join=B.join_into
V=B.V;empty=B.empty
B.PALETTE.update(fur='#F5DEB3',cream='#F7E8CE',brown='#B89A73',blue='#7E9DA3',dark='#282422',pink='#BD8584',wood='#9A7E5C',skin='#E4B899',pants='#414A55')
JOINTS={}

def material(name,color,rough=.6,metal=0):
    m=B.mat(name,color,rough);m.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=metal;return m

def count(o):return sum(len(p.vertices)-2 for p in o.data.polygons)
def simplify(o,limit):
    if count(o)>limit:
        bpy.context.view_layer.objects.active=o
        d=o.modifiers.new('Triangle budget','DECIMATE');d.ratio=limit/count(o)*.995;bpy.ops.object.modifier_apply(modifier=d.name)
    for f in o.data.polygons:f.use_smooth=True

def sculpt(o,parts,size=.0045,limit=1800):
    join(o,parts);bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Continuous sculpted silhouette','REMESH');mod.mode='VOXEL';mod.voxel_size=size;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    smooth=o.modifiers.new('Sculpt relaxation','SMOOTH');smooth.factor=.65;smooth.iterations=4;bpy.ops.object.modifier_apply(modifier=smooth.name)
    simplify(o,limit);return o

def pigment(o,color,rough=.8,grain='fur'):
    # Base-color pigment variation only. This graph never feeds normals, roughness,
    # shadows, AO or lighting into the baked atlas.
    m=bpy.data.materials.new(o.name+'_PigmentSource');m.use_nodes=True
    bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Roughness'].default_value=rough
    nodes=m.node_tree.nodes;links=m.node_tree.links
    coord=nodes.new('ShaderNodeTexCoord');stretch=nodes.new('ShaderNodeVectorMath');stretch.operation='MULTIPLY'
    stretch.inputs[1].default_value=(1.8,1.8,.09) if grain=='fur' else (1,1,1)
    links.new(coord.outputs['Generated'],stretch.inputs[0])
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=120 if grain=='fur' else 75;noise.inputs['Detail'].default_value=2;noise.inputs['Roughness'].default_value=.65;links.new(stretch.outputs[0],noise.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB');base=B.rgba(color)
    ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=tuple(c*.87 for c in base[:3])+(1,)
    ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=tuple(min(1,c*1.035) for c in base[:3])+(1,)
    links.new(noise.outputs['Fac'],ramp.inputs[0]);links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
    o.data.materials.clear();o.data.materials.append(m);return m

def fur_atlas():
    W=1024;grid=math.ceil(math.sqrt(len(B.FUR)));image=bpy.data.images.new('Dog_Clean_Pigment_1024',width=W,height=W,alpha=True);image.generated_color=(1,1,1,1)
    for idx,(o,color) in enumerate(B.FUR):
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('UV triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        if not o.data.uv_layers:o.data.uv_layers.new(name='CleanPigmentUV')
        cols=math.ceil(math.sqrt(len(o.data.polygons)));rows=math.ceil(len(o.data.polygons)/cols)
        for k,f in enumerate(o.data.polygons):
            for loop,(x,y) in zip(f.loop_indices,[(.16,.16),(.84,.16),(.16,.84)]):
                u=(k%cols+x)/cols;v=(k//cols+y)/rows
                o.data.uv_layers.active.data[loop].uv=((idx%grid+.045+.91*u)/grid,(idx//grid+.045+.91*v)/grid)
        m=pigment(o,color);imnode=m.node_tree.nodes.new('ShaderNodeTexImage');imnode.image=image;m.node_tree.nodes.active=imnode
    # Fill each object's unused UV padding with its own pigment. White gutters
    # would otherwise bleed into the coat in the game's minified mip levels.
    from array import array
    pixels=array('f',[1,1,1,1])*(W*W)
    for idx,(_,color) in enumerate(B.FUR):
        x0=int((idx%grid)*W/grid);x1=int((idx%grid+1)*W/grid)
        y0=int((idx//grid)*W/grid);y1=int((idx//grid+1)*W/grid)
        row=array('f',B.rgba(color))*(x1-x0)
        for y in range(y0,y1):pixels[(y*W+x0)*4:(y*W+x1)*4]=row
    image.pixels.foreach_set(pixels);image.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o,_ in B.FUR:o.select_set(True)
    bpy.context.view_layer.objects.active=B.FUR[0][0]
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1;s.render.bake.use_clear=False;s.render.bake.margin=1
    bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'})
    p=OUT/'dog'/'clean_pigment.png';p.parent.mkdir(parents=True,exist_ok=True);image.filepath_raw=str(p);image.file_format='PNG';image.save();image.pack()
    m=material('FurCleanAlbedo','#FFFFFF',.84);n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    for o,_ in B.FUR:o.data.materials.clear();o.data.materials.append(m)
    return p

def finish(slot,file=None):
    JOINTS[slot if not file else slot+'/'+file]=dict(B.PIVOTS)
    B.export(slot,file)
    path=ROOT/'docs/art/RETAIL_JOINTS.json';prev=json.loads(path.read_text()) if path.exists() else {};prev.update(JOINTS);path.write_text(json.dumps(prev,indent=2))

def dog():
    B.reset();f=material('FurSource','fur',.85);nose=material('Nose','#282422',.38);iris=material('Iris','#5A3E2B',.32);pupil=material('Pupil','#171714',.24);white=material('EyeGlint','#DFD9C8',.15);mouth=material('Mouth','#352C29',.75);tongue=material('Tongue','pink',.72)
    torso=ball('Torso',(0,.208,.061),(.112,.185,.15),f,p=(0,.205,.06),seg=24,rings=16,fur='fur',shape=lambda x,y,z:(x*(1-.16*y),y,z))
    ball('Chest',(0,.265,-.045),(.088,.119,.080),f,p=(0,.265,-.045),seg=20,rings=12,fur='cream')
    head=ball('Head',(0,.477,-.04),(.121,.124,.125),f,p=(0,.357,-.014),seg=28,rings=18,fur='fur',shape=lambda x,y,z:(x*(1-.06*y),y,z))
    parts=[]
    for side in [-1,1]:
        parts.append(ball('MuzzleLobe',(side*.033,.431,-.174),(.060,.047,.083),f,p=(0,.357,-.014),seg=20,rings=12))
    parts.append(ball('LowerJaw',(0,.403,-.16),(.063,.030,.075),f,p=(0,.357,-.014),seg=20,rings=10))
    sculpt(head,parts,limit=2000)
    # Separate cheek joints remain embedded in the face for a continuous silhouette.
    for side,tag in [(-1,'L'),(1,'R')]:
        ball('Cheek_'+tag,(side*.069,.429,-.081),(.050,.048,.058),f,p=(side*.069,.429,-.081),parent=head,seg=16,rings=10,fur='fur')
    for side,tag in [(-1,'L'),(1,'R')]:
        ball('Ear_'+tag,(side*.129,.446,-.014),(.046,.100,.046),f,p=(side*.099,.548,-.011),parent=head,seg=20,rings=14,fur='brown' if tag=='L' else 'fur',shape=lambda x,y,z:(x*(1-.22*y)+side*.38*(-y),y,z*(1+.07*y)))
        x=side*.064
        eye=ball('Eye_'+tag,(x,.492,-.153),(.021,.024,.014),iris,parent=head,seg=20,rings=12)
        ball('Pupil_'+tag,(x,.492,-.165),(.0115,.016,.005),pupil,parent=eye,seg=16,rings=10)
        ball('Glint_'+tag,(x-.004,.499,-.169),(.003,.0036,.0016),white,parent=eye,seg=8,rings=6)
        # Slim canine forelegs, visible wrists and joined pads instead of toy tubes.
        xx=side*.071
        leg=tube('Leg_F'+tag,[(xx,.293,-.043),(xx,.233,-.065),(xx,.161,-.087),(xx,.082,-.111),(xx,.041,-.12)],[(.024,.03),(.027,.029),(.020,.023),(.017,.023),(.020,.025)],f,p=(xx,.293,-.043),n=14,fur='fur')
        paw=ball('Paw_F'+tag,(xx,.027,-.148),(.038,.027,.051),f,parent=leg,seg=16,rings=10,fur='fur')
        toes=[ball('Toe',(xx+dx,.019,-.181),(.013,.018,.017),f,p=(xx,.027,-.148),seg=10,rings=6) for dx in [-.021,0,.021]]
        sculpt(paw,toes,size=.003,limit=330)
        ball('Haunch_'+tag,(side*.105,.100,.11),(.067,.095,.093),f,p=(side*.097,.147,.1),seg=20,rings=12,fur='fur')
        ball('Paw_B'+tag,(side*.115,.024,.046),(.043,.024,.066),f,p=(side*.115,.042,.055),seg=16,rings=10,fur='fur')
    ball('Nose',(0,.451,-.25),(.025,.017,.016),nose,parent=head,seg=20,rings=12,shape=lambda x,y,z:(x*(.78+.22*y),y,z))
    mouth_obj=tube('Mouth',[(-.05,.412,-.212),(-.028,.400,-.229),(0,.397,-.236),(.028,.400,-.229),(.05,.412,-.212)],[.0024,.0031,.004,.0031,.0024],mouth,p=(0,.399,-.235),parent=head,n=8)
    ball('Tongue',(0,.391,-.242),(.013,.017,.0045),tongue,p=(0,.405,-.239),parent=head,seg=16,rings=10)
    parent=None
    for i,(a,b,c,r) in enumerate([((0,.09,.173),(0,.099,.215),(0,.128,.248),.031),((0,.128,.248),(0,.167,.27),(0,.204,.271),.026),((0,.204,.271),(0,.24,.258),(0,.258,.239),.022)]):parent=tube('Tail_'+str(i+1),[a,b,c],[r,r*.85,.018 if i<2 else .002],f,p=a,parent=parent,n=12,fur='fur')
    empty('FaceCenter',(0,.491,-.165),head);empty('BodyCenter',(0,.208,.061))
    B.reduce_budget(7800);p=fur_atlas();finish('dog');p.unlink()

def owner():
    B.reset();skin=material('Skin','skin',.78);shirt=material('Shirt','#FFFFFF',.88);hat=material('Hat','#FFFFFF',.9);pants=material('Trousers','pants',.87);hair=material('Hair','#4C3A2C',.86);dark=material('Face','#332C27',.55);shoe=material('Shoes','#313A3C',.78)
    body=empty('Body')
    torso=tube('ShirtTorso',[(0,.802,0),(0,.87,0),(0,1.05,0),(0,1.16,0),(0,1.224,0),(0,1.25,0)],[(.089,.145),(.101,.153),(.112,.175),(.105,.177),(.077,.127),(.052,.058)],shirt,p=(0,0,0),parent=body,n=24)
    head=ball('Head',(0,1.367,-.002),(.101,.128,.094),skin,p=(0,1.226,0),parent=body,seg=24,rings=16,shape=lambda x,y,z:(x*(.88+.12*y),y,z))
    # A small neck is included in Head so nodding preserves its connection.
    neck=tube('Neck',[(0,1.222,0),(0,1.27,0)],[.045,.047],skin,p=(0,1.226,0),n=12);join(head,[neck])
    for side,tag in [(-1,'L'),(1,'R')]:
        arm=tube('Arm_'+tag,[(side*.157,1.187,0),(side*.208,1.126,-.006),(side*.224,1.003,-.008),(side*.224,.966,-.012)],[.051,.053,.046,.044],shirt,p=(side*.157,1.187,0),parent=body,n=12)
        fore=tube('Forearm',[(side*.224,.984,-.012),(side*.228,.851,-.027),(side*.222,.743,-.044)],[.037,.033,.024],skin,p=(side*.157,1.187,0),n=12)
        hand=ball('Hand',(side*.219,.715,-.046),(.033,.052,.025),skin,p=(side*.157,1.187,0),seg=12,rings=8);join(arm,[fore,hand])
        hip=(side*.084,.801,0)
        knee_pos=(side*.086,.45,0)
        leg=tube('Leg_'+tag,[hip,(side*.088,.622,-.002),knee_pos],[.068,.063,.05],pants,p=hip,parent=body,n=14)
        knee=tube('Knee_'+tag,[knee_pos,(side*.084,.199,.005),(side*.084,.084,.008)],[.05,.046,.043],pants,p=knee_pos,parent=leg,n=14)
        boot=box('Shoe',(side*.084,.046,-.037),(.119,.092,.224),shoe,.025,p=knee_pos);join(knee,[boot])
        ball('Ear_'+tag,(side*.099,1.363,.002),(.017,.03,.018),skin,parent=head,seg=12,rings=8)
        ball('Eye_'+tag,(side*.039,1.389,-.087),(.009,.006,.0055),dark,parent=head,seg=12,rings=8)
        tube('Brow_'+tag,[(side*.025,1.408,-.085),(side*.039,1.414,-.086),(side*.054,1.408,-.078)],[.0024]*3,hair,parent=head,n=6)
    ball('Nose',(0,1.362,-.098),(.014,.022,.020),skin,parent=head,seg=14,rings=10)
    tube('Mouth',[(-.022,1.322,-.085),(0,1.319,-.092),(.022,1.322,-.085)],[.0018,.0022,.0018],material('Lip','#9C7262',.9),parent=head,n=6)
    # Short sculpted scalp and an ordinary cap; no bobble-head toy proportions.
    ball('Hair',(0,1.424,.014),(.104,.093,.092),hair,parent=head,seg=20,rings=12)
    ball('CapCrown',(0,1.466,.016),(.111,.084,.104),hat,parent=head,seg=24,rings=12)
    box('CapBrim',(0,1.476,-.071),(.194,.012,.13),hat,.005,parent=head)
    B.reduce_budget(3900);finish('owner')

def tub():
    B.reset();metal=material('BrushedSteel','#969D9C',.34,.82);feet=material('RubberFeet','#383F3C',.9);topmat=material('SolidSurface','#D5D0C5',.42);outer=material('EnamelBlue','blue',.28);inside=material('EnamelIvory','#E4E4D9',.25);red=material('DrainPlug','#A74D3E',.65)
    stand=box('Stand',(0,.8725,0),(1.6,.055,1.1),topmat,.008)
    parts=[]
    for x in [-.699,.699]:
        for z in [-.445,.445]:
            parts.append(box('SteelLeg',(x,.428,z),(.035,.84,.035),metal,.003))
            parts.append(box('LevelFoot',(x,.012,z),(.052,.024,.052),feet,.004))
    for z in [-.445,.445]:parts.append(box('CrossRail',(0,.231,z),(1.43,.028,.028),metal,.003))
    for x in [-.699,.699]:parts.append(box('SideRail',(x,.231,0),(.028,.028,.918),metal,.003))
    parts.append(box('LowerShelf',(0,.255,0),(1.41,.018,.90),metal,.003));join(stand,parts)
    n=64;profile=[(0,.906),(.49,.906),(.534,.912),(.554,.936),(.563,1.033),(.575,1.055),(.588,1.06),(.608,1.054),(.618,1.037),(.62,.929),(.600,.899),(.567,.885),(0,.885)]
    verts=[]
    for r,y in profile:
        for i in range(n):
            a=2*pi*i/n;drop=.075*max(0,-sin(a))**2*max(0,min(1,(y-.906)/.115));verts.append((r*cos(a),y-drop,r*sin(a)))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            faces.append((a,b+n,a+n) if profile[j][0]==0 else ((a,b,a+n) if profile[j+1][0]==0 else (a,b,b+n,a+n)))
    bowl=mesh('Tub',verts,faces,inside);bowl.data.materials.append(outer)
    for f in bowl.data.polygons:
        if f.index//n>=7:f.material_index=1
    B.disc('Plug',(.29,.916,.23),.027,.014,red,n=20,p=(.29,.916,.23))
    # Narrow stainless rack, four forward-facing hooks; all static parts are ToolRack.
    rack=box('ToolRack',(-.728,1.07,.19),(.023,.418,.023),metal,.002)
    parts=[box('RackPost',(-.728,1.07,.48),(.023,.418,.023),metal,.002),box('RackRail',(-.728,1.279,.335),(.023,.023,.313),metal,.002)]
    for z in [.20,.29,.38,.47]:parts.append(tube('Hook',[(-.728,1.276,z),(-.69,1.24,z),(-.671,1.241,z),(-.67,1.256,z)],[.004]*4,metal,n=8))
    join(rack,parts);B.reduce_budget(3950);finish('tub')

def turntable():
    B.reset();rubber=material('GripRubber','#626D69',.94);rim=material('SteelRim','#ADB4B1',.3,.75)
    n=48;profile=[(0,-.02),(.487,-.02),(.5,-.015),(.5,.014),(.493,.02),(.483,.02),(0,.02)]
    verts=[]
    for r,y in profile:
        for i in range(n):a=2*pi*i/n;verts.append((r*cos(a),y,r*sin(a)))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            faces.append((a,a+n,b+n) if profile[j][0]==0 else ((a,a+n,b) if profile[j+1][0]==0 else (a,a+n,b+n,b)))
    plate=mesh('Plate',verts,faces,rubber);plate.data.materials.append(rim)
    for f in plate.data.polygons:
        if f.index//n in [1,2,3,4]:f.material_index=1
    simplify(plate,790);finish('turntable')

def chair():
    B.reset();metal=material('ChairFrame','#777E7B',.4,.75);vinyl=material('Upholstery','#657E75',.7);feet=material('ChairFeet','#373E3B',.95)
    box('Seat',(0,.367,0),(.45,.066,.42),vinyl,.012)
    box('Back',(0,.615,.177),(.433,.267,.043),vinyl,.012)
    for x in [-.185,.185]:
        for z in [-.156,.156]:
            tube('Leg',[(x,.351,z),(x,.014,z)],[.012,.01],metal,p=(0,0,0),n=10)
            box('Foot',(x,.008,z),(.027,.016,.027),feet,.003)
        tube('BackFrame',[(x,.30,.156),(x,.58,.178),(x,.73,.178)],[.01]*3,metal,p=(0,0,0),n=10)
    B.reduce_budget(1450);finish('chair')

def tiles():
    for kind in ['floor','wall']:
        B.reset();grout=material('Grout','#B5BBB1',.95);base=material('Tile', '#BECBC1' if kind=='floor' else '#DAD5C5',.58)
        if kind=='floor':box('FloorBase',(0,-.033,0),(2,.044,2),grout,0)
        else:box('WallBase',(0,1,-.004),(2,2,.292),grout,0)
        for i in range(4):
            for j in range(4):
                factor=1+(((i*13+j*7)%9)-4)*.004
                m=material('Tile_%d_%d'%(i,j),'#BECBC1' if kind=='floor' else '#DAD5C5',.58)
                color=m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
                for k in range(3):color[k]*=factor
                if kind=='floor':box('FloorTile_%d_%d'%(i,j),(-.75+i*.5,-.011,-.75+j*.5),(.494,.022,.494),m,.003)
                else:box('WallTile_%d_%d'%(i,j),(-.75+i*.5,.25+j*.5,.142),(.494,.494,.016),m,.003)
        finish('tiles',kind)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['dog']
    for slot in args:globals()[slot]()
