"""Original pastel yard and delivery assets. Blender 4.2+, metres/Y-up/front -Z.
Run make_textures.py, then blender -b --factory-startup --python build_outside.py.
"""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from math import sin,cos,pi
sys.path.insert(0,str(Path(__file__).resolve().parent));import geometry as g
OUT=g.OUT
box,ball,tube,lathe,ring,oval,cloud,mesh,extrude=g.box,g.ball,g.tube,g.lathe,g.ring,g.oval,g.cloud,g.mesh,g.extrude
PARTS,PIVOTS=g.PARTS,g.PIVOTS
REPORT={};EMPTY={};JOINTS={};IMATS={}
def reset():g.reset();EMPTY.clear();JOINTS.clear();IMATS.clear()
def joint(name,p,axis,angle):PIVOTS[name]=p;JOINTS[name]={'pivot':list(p),'axis':axis,'test_angle_radians':angle}
def picture(points,file,group='Body',reverse=False,uvs=None):
 # Flat original colour art. Explicit UV set avoids palette/decal layer mismatch.
 name=Path(file).stem
 if name not in IMATS:
  m=bpy.data.materials.new('Art_'+name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.8;bs.inputs['Metallic'].default_value=0
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');im=bpy.data.images.load(str(OUT/'source'/file),check_existing=False);im.pack();tex.image=im;m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  if name=='paw_stamp':m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=True
  IMATS[name]=m
 o=mesh(points,[tuple(reversed(range(len(points)))) if reverse else tuple(range(len(points)))],'white',group,smooth=False);o.data.materials.clear();o.data.materials.append(IMATS[name])
 uv=o.data.uv_layers.active
 for f in o.data.polygons:
  for k in f.loop_indices:
   vi=o.data.loops[k].vertex_index;uv.data[k].uv=uvs[vi] if uvs else [(0,0),(1,0),(1,1),(0,1)][vi]
 return o
def frontpic(x,y,z,w,h,file,group='Body',back=False):
 pts=[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)]
 if not back:pts=list(reversed(pts))
 return picture(pts,file,group)
def sidepic(x,y,z,w,h,file,group='Body',left=False):
 pts=[(x,y-h/2,z+w/2),(x,y-h/2,z-w/2),(x,y+h/2,z-w/2),(x,y+h/2,z+w/2)]
 if left:pts=list(reversed(pts))
 return picture(pts,file,group)
def cut_round(o,c,r,depth=.5):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=g.V(c),rotation=(pi/2,0,0));cutter=bpy.context.object
 bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Real window opening','BOOLEAN');m.operation='DIFFERENCE';m.object=cutter;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cutter,do_unlink=True)
 # Boolean faces also sample the body's constant palette colour.
 color=o.data.materials[0].name.split('Pastel_')[1].split('.')[0];group=next(k for k,v in PARTS.items() if o in v);PARTS[group].remove(o);g.tag(o,color,group)
 return o
def boolean_cut(o,c,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=g.V(c));q=bpy.context.object;q.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Passable door opening','BOOLEAN');m.operation='DIFFERENCE';m.object=q;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(q,do_unlink=True)
 return o
def retag(o,col,group):
 for k in list(PARTS):
  if o in PARTS[k]:PARTS[k].remove(o)
 return g.tag(o,col,group)
def lathex(c,prof,col,group,n=20):
 vs=[]
 for x,r in prof:
  for k in range(n):a=k*2*pi/n;vs.append((c[0]+x,c[1]+r*cos(a),c[2]+r*sin(a)))
 fs=[tuple(reversed(range(n))),tuple((len(prof)-1)*n+k for k in range(n))]
 for j in range(len(prof)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 return mesh(vs,fs,col,group)
def rounded_rect(w,d,r,n=3):
 p=[]
 for x,z,start in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,90),(-w/2+r,-d/2+r,180),(w/2-r,-d/2+r,270)]:
  for k in range(n):a=math.radians(start+k*90/(n-1));p.append((x+r*cos(a),z+r*sin(a)))
 return p
def scale_world(sx=1,sy=1,sz=1):
 bpy.context.view_layer.update()
 for obs in PARTS.values():
  for o in obs:
   inv=o.matrix_world.inverted()
   for v in o.data.vertices:
    p=o.matrix_world@v.co;p.x*=sx;p.y*=sz;p.z*=sy;v.co=inv@p
 for k,p in list(PIVOTS.items()):PIVOTS[k]=(p[0]*sx,p[1]*sy,p[2]*sz)
 for k,p in list(EMPTY.items()):EMPTY[k]=(p[0]*sx,p[1]*sy,p[2]*sz)
 for k,j in JOINTS.items():j['pivot']=list(PIVOTS[k])
def fit_back(width,height,depth):
 bpy.context.view_layer.update();obs=[o for v in PARTS.values() for o in v];ps=[o.matrix_world@v.co for o in obs for v in o.data.vertices];lo=[min(p[k] for p in ps) for k in range(3)];hi=[max(p[k] for p in ps) for k in range(3)]
 for o in obs:
  inv=o.matrix_world.inverted()
  for v in o.data.vertices:
   p=o.matrix_world@v.co;p.x=(p.x-(lo[0]+hi[0])/2)*width/(hi[0]-lo[0]);p.z=(p.z-(lo[2]+hi[2])/2)*height/(hi[2]-lo[2]);p.y=(p.y-lo[1])*depth/(hi[1]-lo[1]);v.co=inv@p

def finish(name,limit,origin='floor',notes=''):
 bpy.context.view_layer.update();root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for group,obs in list(PARTS.items()):
  if not obs:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in obs:o.select_set(True)
  bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
  m=o.modifiers.new('Delivery triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
  p=g.V(PIVOTS.get(group,(0,0,0)))
  for v in o.data.vertices:v.co-=p
  o.location=p;o.parent=root
  if group in JOINTS:o['rotation_axis']=JOINTS[group]['axis'];o['test_angle_radians']=JOINTS[group]['test_angle_radians']
 for n,p in EMPTY.items():
  o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.location=g.V(p);o.parent=root
 bpy.context.view_layer.update();obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=sum(len(o.data.polygons) for o in obs);assert tri<=limit,(name,tri,limit)
 ps=[o.matrix_world@v.co for o in obs for v in o.data.vertices];lo=[min(p[k] for p in ps) for k in range(3)];hi=[max(p[k] for p in ps) for k in range(3)]
 REPORT[name]={'triangles':tri,'budget':limit,'dimensions_m':[round(hi[0]-lo[0],5),round(hi[2]-lo[2],5),round(hi[1]-lo[1],5)],'bounds_min':[lo[0],lo[2],-hi[1]],'bounds_max':[hi[0],hi[2],-lo[1]],'origin':origin,'joints':dict(JOINTS),'empty_nodes':dict(EMPTY),'notes':notes}
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
 print('OUTSIDE',name,tri,REPORT[name]['dimensions_m'],flush=True)

def facade():
 reset();wall=box((0,1.5,0),(7,3,.2),'butter',bevel=.025)
 boolean_cut(wall,(2.6,1.04,0),(1.2,2.12,.5))
 for x in [-2.0,.25]:cut_round(wall,(x,1.5,0),.58)
 retag(wall,'butter','Body')
 for x in [-2.0,.25]:
  ring((x,1.5,-.108),.60,.055,'white',n=32,m=6,axis='z');ring((x,1.5,-.129),.557,.015,'sky',n=32,m=4,axis='z');oval((x,1.5,-.07),.555,.555,.012,'glass',n=32)
  box((x,1.5,-.15),(.035,1.1,.035),'white',bevel=.012);box((x,1.5,-.15),(1.10,.035,.035),'white',bevel=.012)
 # Striped arched awning, including scalloped fabric valance.
 for i in range(12):
  x=-3.30+i*.55;col='sky' if i%2==0 else 'white'
  prof=[(2.58,-.10),(2.55,-.34),(2.46,-.60),(2.32,-.81),(2.30,-.80),(2.44,-.58),(2.53,-.33),(2.56,-.10)]
  vs=[(xx,y,z) for xx in [x,x+.55] for y,z in prof];n=len(prof);fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)];mesh(vs,fs,col,smooth=False)
  ball((x+.275,2.30,-.80),(.274,.11,.025),col,n=12,r=5)
 door=box((2.6,1.05,-.035),(1.16,2.06,.065),'pink','Door',bevel=.045)
 cut_round(door,(2.6,1.58,-.035),.22,.3);retag(door,'pink','Door')
 ring((2.6,1.58,-.083),.238,.025,'white','Door',n=24,m=6,axis='z');oval((2.6,1.58,-.035),.217,.217,.009,'glass','Door',n=24)
 ball((3.02,.99,-.095),(.045,.045,.045),'gold','Door',n=12,r=6);joint('Door',(2.02,.02,-.035),'Y',-1.5)
 # Bell is stationary over the door; only its own pendulum pivot moves.
 tube([(2.6,2.37,-.24),(2.6,2.37,-.36)],.013,'gold',n=8)
 lathe((2.6,2.36,-.36),[(-.16,.065),(-.145,.07),(-.13,.048),(-.04,.025),(0,.015)],'gold','Bell',n=20)
 ball((2.6,2.185,-.36),(.018,.024,.018),'gold','Bell',n=10,r=5);joint('Bell',(2.6,2.36,-.36),'Z',.4)
 finish('shop_front',7000,'wall bottom centre','Wall itself 7 x 3 x .2 m. True opening X=2.0..3.2, Y=0..2.1; door centre +2.6m. Overall depth includes the awning. Two actual circular wall openings with alpha glass.')
def outside_sign():
 reset();box((0,0,-.045),(2,.6,.09),'sky',bevel=.085);box((0,0,-.097),(1.86,.46,.014),'cream',bevel=.07)
 for side in [-1,1]:
  for x,y,r in [(side*.80,.12,.072),(side*.88,-.11,.048)]:ball((x,y,-.104),(r,r,.027),'glass',n=12,r=6);ring((x,y,-.126),r,.008,'white',n=16,m=4,axis='z')
  frontpic(side*.72,-.105,-.134,.17,.17,'paw_stamp.png')
 fit_back(2,.6,.1);finish('sign_outside',2000,'back centre','Blank centre approx 1.25 x .36 m; no lettering.')
def open_sign():
 reset();ring((0,-.016,0),.012,.004,'gold',n=12,m=4,axis='z');tube([(0,-.024,0),(0,-.070,0)],.004,'grain',n=6)
 box((0,-.165,0),(.35,.17,.023),'wood','Plate',bevel=.04)
 for x in [-.105,.105]:tube([(0,-.070,0),(x,-.09,0)],.003,'grain','Plate',n=5)
 frontpic(0,-.165,-.0124,.29,.145,'plate_sun.png','Plate');frontpic(0,-.165,.0124,.29,.145,'plate_moon.png','Plate',back=True)
 joint('Plate',(0,-.070,0),'Y',pi);finish('open_sign',1500,'top hanger','Sun front -Z, sleeping moon back +Z. Plate includes lower strings and flips around its upper central Y pivot.')

def cartons():
 for name,w,h,d in [('box_small',.3,.25,.25),('box_medium',.5,.4,.4),('box_large',.9,.6,.6)]:
  reset();r=min(w,d)*.025;t=.006
  profiles=[(0,w-.008,d-.008),(.006,w,d),(h-.011,w,d),(h-.011,w-2*t,d-2*t),(.009,w-2*t,d-2*t)]
  vs=[]
  for y,ww,dd in profiles:
   for x,z in rounded_rect(ww,dd,r,3):vs.append((x,y,z))
  n=12;fs=[]
  for j in range(len(profiles)-1):
   for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
  fs.extend([tuple(reversed(range(n))),tuple((len(profiles)-1)*n+k for k in range(n))]);mesh(vs,fs,'cardboard')
  for side,group in [(-1,'Lid_L'),(1,'Lid_R')]:
   box((side*w/4,h-.0055,0),(w/2-.001,.011,d),'cardboard',group,bevel=.004)
   # Split one continuous seam tape between the two independently opening flaps.
   tw=min(.05,w*.15);cx=side*(tw/4+.0005)
   mesh([(cx-tw/4,h+.00001,-d*.49),(cx+tw/4,h+.00001,-d*.49),(cx+tw/4,h+.00001,d*.49),(cx-tw/4,h+.00001,d*.49)],[(0,3,2,1)],'sky',group,smooth=False)
   joint(group,(side*(w/2-.001),h-.0055,0),'Z',side*-1.9)
  sidepic(w/2+.0003,h*.52,0,min(d,h)*.63,min(d,h)*.63,'paw_stamp.png')
  finish(name,500,notes='Hollow carton, two independent flaps. Lid_L local Z +1.9, Lid_R local Z -1.9 opens outward. Tape is part of each lid.')
def wheel(c,r,width,name):
 x,y,z=c;lathex(c,[(-width/2,r*.86),(-width*.35,r),(width*.35,r),(width/2,r*.86)],'tire',name,n=20)
 sign=1 if x>0 else -1;lathex((x+sign*(width/2+.002),y,z),[(-.006,r*.59),(.006,r*.59)],'butter',name,n=16)
 for k in range(3):
  a=k*2*pi/3;ball((x+sign*(width/2+.010),y+r*.3*cos(a),z+r*.3*sin(a)),(.009,r*.105,r*.105),'pink',name,n=8,r=4)
 joint(name,c,'X',1.2)
def truck():
 reset();box((0,.48,.0),(1.52,.18,3.15),'sky',bevel=.07)
 box((0,1.10,-1.055),(1.62,1.32,1.32),'sky',bevel=.14);box((0,1.80,-1.055),(1.62,.10,1.22),'sky',bevel=.045)
 for x in [-.37,.37]:box((x,1.43,-1.725),(.63,.48,.025),'ice',bevel=.06)
 for x in [-.825,.825]:box((x,1.43,-1.02),(.025,.46,.86),'ice',bevel=.06)
 box((0,.60,-1.735),(1.44,.12,.10),'white',bevel=.04)
 for x in [-.57,.57]:ball((x,.84,-1.725),(.115,.115,.052),'butter',n=16,r=8)
 box((0,.98,-1.725),(.40,.10,.025),'white',bevel=.035)
 # Open cargo body; the rear door really uncovers the interior.
 box((0,.64,.69),(1.64,.10,2.12),'cream',bevel=.035);box((0,1.95,.69),(1.64,.10,2.12),'cream',bevel=.035)
 for x in [-.79,.79]:box((x,1.3,.69),(.06,1.30,2.12),'cream',bevel=.025)
 box((0,1.30,-.34),(1.60,1.30,.06),'cream',bevel=.025)
 box((0,1.30,1.738),(1.51,1.24,.045),'cream','Door_Back',bevel=.035)
 for x in [-.35,.35]:box((x,.86,1.769),(.20,.035,.035),'sky','Door_Back',bevel=.012)
 joint('Door_Back',(0,1.92,1.738),'X',-1.8)
 for x,side in [(-.78,'L'),(.78,'R')]:
  for z,end in [(-1.05,'F'),(1.12,'B')]:wheel((x,.30,z),.30,.22,'Wheel_'+end+side)
 for side in [-1,1]:sidepic(side*.824,1.31,.64,1.35,.85,'truck_side.png',left=side<0)
 # Fit overall width and length including lights, caps and bumpers; retain actual joints.
 bpy.context.view_layer.update();ps=[o.matrix_world@v.co for a in PARTS.values() for o in a for v in o.data.vertices];wx=max(v.x for v in ps)-min(v.x for v in ps);dz=max(v.y for v in ps)-min(v.y for v in ps);scale_world(sx=1.8/wx,sz=3.5/dz)
 # Recenter depth on floor origin after fitting asymmetric cab and rear.
 bpy.context.view_layer.update();ps=[o.matrix_world@v.co for a in PARTS.values() for o in a for v in o.data.vertices];mid=(max(v.y for v in ps)+min(v.y for v in ps))/2
 for a in PARTS.values():
  for o in a:
   inv=o.matrix_world.inverted()
   for v in o.data.vertices:p=o.matrix_world@v.co;p.y-=mid;v.co=inv@p
 for n,p in list(PIVOTS.items()):PIVOTS[n]=(p[0],p[1],p[2]+mid);JOINTS[n]['pivot']=list(PIVOTS[n])
 finish('truck',6000,notes='1.8m overall width, 3.5m overall length, 2m high. Left=-X. Four X-axis wheels, upper X-hinged rear cargo door. Frosted opaque cab windows; no people.')
def cart():
 reset();box((0,.22,0),(.90,.04,.60),'mint',bevel=.04)
 for x in [-.43,.43]:box((x,.27,0),(.04,.06,.56),'mint',bevel=.018)
 for z in [-.28,.28]:box((0,.27,z),(.86,.06,.04),'mint',bevel=.018)
 for x in [-.32,.32]:tube([(x,.25,.23),(x,.40,.33),(x,.94,.45),(x,.975,.45)],.025,'pink',n=10)
 tube([(-.32,.975,.45),(.32,.975,.45)],.025,'pink',n=10)
 for x,n in [(-.46,'Wheel_L'),(.46,'Wheel_R')]:wheel((x,.16,.16),.16,.10,n)
 tube([(0,.23,-.22),(0,.028,-.22)],.025,'wood',n=8);box((0,.015,-.22),(.18,.03,.12),'wood',bevel=.014)
 finish('cart',2000,notes='Tray footprint .9 x .6m, tray rim top .3m, inner deck .24m; handle +Z, overall handle height 1m. Wheels rotate local X.')
def mailbox():
 reset();box((0,.04,0),(.30,.08,.30),'wood',bevel=.025);box((0,.47,0),(.10,.86,.10),'wood',bevel=.025)
 pts=[(-.18,.85),(.18,.85),(.18,1.02)]+[(.18*cos(pi*k/12),1.02+.18*sin(pi*k/12)) for k in range(1,13)]
 extrude(pts,-.24,.24,'red');box((0,.90,-.244),(.30,.025,.008),'blush',bevel=.008);ball((0,.995,-.258),(.018,.018,.014),'butter',n=10,r=4)
 box((.214,.99,.11),(.015,.022,.18),'butter','Flag',bevel=.006);box((.214,1.032,.18),(.015,.10,.10),'butter','Flag',bevel=.012)
 lathex((.215,.99,.02),[(-.008,.022),(.008,.022)],'gold','Flag',n=12);joint('Flag',(.215,.99,.02),'X',-pi/2)
 finish('mailbox',1000,notes='1.2m high arched red mailbox. Flag raises with negative local X rotation.')
def street_lamp():
 reset();lathe((0,0,0),[(0,.18),(.04,.20),(.11,.15),(.15,.06)],'sky',n=20)
 lathe((0,0,0),[(.11,.04),(2.50,.04),(2.55,.07)],'sky',n=16)
 ball((0,2.68,0),(.18,.18,.18),'butter',n=16,r=8);ring((0,2.68,0),.183,.013,'sky',n=20,m=5)
 lathe((0,0,0),[(2.81,.13),(2.86,.10),(2.88,.055)],'sky',n=20);cloud((0,2.925,0),(.10,.07,.065),n=10,r=5)
 EMPTY['Bulb']=(0,2.68,0)
 bpy.context.view_layer.update();top=max((o.matrix_world@v.co).z for a in PARTS.values() for o in a for v in o.data.vertices);scale_world(sy=3/top)
 finish('street_lamp',1500,notes='Exactly 3m high. Bulb is an EMPTY node at the round lamp centre, ready for a game light.')
def fence():
 reset()
 for k in range(10):
  x=-.9+k*.2;w=.12;r=w/2;pts=[(x-r,0),(x+r,0),(x+r,.74)]+[(x+r*cos(pi*j/8),.74+r*sin(pi*j/8)) for j in range(1,9)]
  extrude(pts,-.035,.035,'white')
 # Rails have identical full cross-sections at x=-1 and +1 for 2m repeat placement.
 for y in [.23,.53]:
  cross=rounded_rect(.08,.06,.014,3);vs=[(x,y+a,b) for x in [-1,1] for a,b in cross];n=len(cross);fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)];mesh(vs,fs,'white')
 finish('fence',800,notes='Repeat pitch X=2m. Rail endpoint cross-sections match at X=-1,+1; picket pitch .2m. Height .8m.')
def flower_bed():
 reset()
 for z in [-.27,.27]:box((0,.10,z),(2,.20,.06),'wood',bevel=.025)
 for x in [-.97,.97]:box((x,.10,0),(.06,.20,.48),'wood',bevel=.025)
 box((0,.12,0),(1.88,.08,.47),'grain',bevel=0)
 for i in range(7):
  x=-.75+i*.25;z=.11 if i%2 else -.11;col=['pink','butter','sky'][i%3]
  tube([(x,.16,z),(x,.335,z)],.009,'mint',n=6)
  for k in range(5):
   a=2*pi*k/5;ball((x+.038*cos(a),.335+.038*sin(a),z),(.029,.027,.018),col,n=6,r=3)
  ball((x,.335,z-.019),(.022,.022,.010),'butter',n=6,r=3)
  for side in [-1,1]:ball((x+side*.026,.23,z),(.029,.012,.015),'mint',n=6,r=3)
 bpy.context.view_layer.update();top=max((o.matrix_world@v.co).z for a in PARTS.values() for o in a for v in o.data.vertices);scale_world(sy=.4/top)
 finish('flower_bed',2000,notes='2 x .6m repeat footprint; wood border .2m high, flowers reach about .4m; repeat along X every 2m.')
def delivery_mat():
 reset();box((0,.0095,0),(1.6,.019,1),'cream',bevel=.009)
 pts=rounded_rect(1.58,.98,.035,4);verts=[(x,.020,z) for x,z in pts];uv=[((x+.8)/1.6,(-z+.5)) for x,z in pts]
 picture(list(reversed(verts)),'mat_albedo.png',uvs=list(reversed(uv)))
 finish('delivery_mat',300,notes='1.6 x 1m, .02m thick, original box picture and paw border in colour-only PNG; no text.')
if __name__=='__main__':
 names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 if names and (OUT/'validation_geometry.json').exists():REPORT.update(json.loads((OUT/'validation_geometry.json').read_text()))
 for f in [facade,outside_sign,open_sign,cartons,truck,cart,mailbox,street_lamp,fence,flower_bed,delivery_mat]:
  if not names or f.__name__ in names:f()
 (OUT/'validation_geometry.json').write_text(json.dumps(REPORT,indent=2)+'\n');print('DONE',len(REPORT),flush=True)
