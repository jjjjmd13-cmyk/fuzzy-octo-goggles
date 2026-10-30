"""Original first-person props. Run with Blender --background --python this_file."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_slots as b
import bpy
from mathutils import Vector
ROOT=b.ROOT
report={}
def ball(n,c,s,m):return b.uvball(n,c,s,m,seg=12,rings=8)
def box(n,c,s,m,r=.008):return b.box(n,c,s,m,bevel=r)
def tube(n,pts,r,m):return b.tube(n,pts,[r]*len(pts),m,n=12)
def finish(name,group='tools'):
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if name!='hands':
        for o in meshes:
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        root=b.join_into(meshes[0],meshes[1:]);root.name=name.title()
        bpy.context.scene.cursor.location=(0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    count=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert count<=3000,(name,count)
    b.OUT=ROOT/'assets/models';b.export(group,name)
    import struct
    raw=(ROOT/'assets/models'/group/(name+'.glb')).read_bytes()
    gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
    count=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    assert count<=3000 and not gltf.get('images')
    report[name]={'triangles':count,'textures':0,'units':'metres','up':'+Y','forward':'-Z'}
    # A single consistent studio preview, viewing the front (-Z).
    bpy.ops.object.camera_add(location=b.V((.42,.30,-.62)))
    cam=bpy.context.object;cam.rotation_euler=(b.V((0,.025,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.48
    scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.world.color=(.6,.6,.6)
    for loc,power,size in [((-.3,.5,-.4),35,.5),((.4,.3,.2),25,.4)]:
        bpy.ops.object.light_add(type='AREA',location=b.V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
    dest=ROOT/'art/incoming/first_person';dest.mkdir(parents=True,exist_ok=True);scene.render.filepath=str(dest/(name+'.png'));bpy.ops.render.render(write_still=True)
def mats():
    b.reset();return [b.mat(c,c) for c in ['cream','mint','blue','pink','red','dark']]
c,m,blue,pink,red,dark=mats()
ball('Grip',(0,0,0),(.014,.075,.014),c)
ball('Head',(0,.093,-.012),(.04,.04,.012),blue)
ball('Face',(0,.093,-.023),(.035,.035,.004),c)
for x,y in [(-.014,-.014),(0,-.018),(.014,-.014),(-.019,0),(0,0),(.019,0),(-.014,.014),(0,.019),(.014,.014)]:ball('Jet',(x,.093+y,-.027),(.0025,.0025,.001),dark)
tube('Short hose',[(0,-.071,0),(0,-.10,0),(.025,-.123,.005),(.05,-.12,.012)],.006,blue)
finish('shower')
c,m,blue,pink,red,dark=mats()
box('Squeezable bottle',(0,0,0),(.065,.145,.043),m,.018)
box('Flip cap',(0,.083,0),(.035,.021,.03),c,.006)
box('Label',(0,.006,-.022),(.045,.067,.002),c,.001)
ball('Paw pad',(0,-.003,-.025),(.01,.009,.002),pink)
for x,y in [(-.012,.013),(0,.019),(.012,.013)]:ball('Paw toe',(x,y,-.025),(.004,.005,.002),pink)
# Total height .18 m, grip at bottle centre.
box('Cap lip',(0,.101,0),(.032,.013,.028),c,.004)
finish('shampoo')
c,m,blue,pink,red,dark=mats()
for i in range(3):box('Fold '+str(i),(0,.009+i*.016,-.07),(.30,.018,.20),pink,.008)
for x in [-.135,.135]:box('Woven border',(x,.051,-.07),(.009,.002,.18),c,.001)
finish('towel')
c,m,blue,pink,red,dark=mats()
box('Grip',(0,0,0),(.037,.11,.04),blue,.014)
ball('Motor',(0,.078,0),(.052,.049,.085),blue)
tube('Nozzle',[(0,.078,-.052),(0,.078,-.116)],.03,blue)
ball('Air outlet',(0,.078,-.118),(.025,.025,.002),dark)
for x in [-.012,0,.012]:box('Grille',(x,.078,-.121),(.003,.043,.002),c,.001)
box('Red button',(0,.022,-.023),(.018,.026,.009),red,.004)
finish('dryer')
c,m,blue,pink,red,dark=mats();yellow=b.mat('Rubber yellow','#FFE58A',.55)
for side,sgn in [('L',-1),('R',1)]:
    x=sgn*.105;parts=[]
    parts.append(box('Cuff',(x,0,.012),(.074,.047,.043),yellow,.008))
    parts.append(ball('Palm',(x,0,-.047),(.039,.023,.054),yellow))
    for dx,length in [(-.026,.048),(-.009,.063),(.009,.058),(.026,.045)]:
        parts.append(ball('Finger',(x+sgn*dx,-.003,-.092-length/2),(.009,.011,length/2+.008),yellow))
    parts.append(ball('Thumb',(x-sgn*.043,-.005,-.052),(.022,.013,.027),yellow))
    for o in parts:
        bpy.context.view_layer.objects.active=o
        for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    root=b.join_into(parts[0],parts[1:]);root.name='Hand_'+side
    bpy.context.scene.cursor.location=b.V((x,0,0));bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
finish('hands','hands')
(ROOT/'art/incoming/first_person/validation.json').write_text(json.dumps(report,indent=2))

