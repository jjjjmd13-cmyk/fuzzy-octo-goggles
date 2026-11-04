"""Original pastel shop decorations, Blender 4.2. Metres, Y up, front -Z.
Run make_textures.py first; blender -b --factory-startup --python build_decor.py
No external assets. All meshes use an embedded colour-only PNG atlas.
"""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
from math import sin,cos,pi
OUT=Path(__file__).resolve().parents[1]
COL=['floor','butter','wood','sky','red','pink','mint','blue','white','gold','blush','grain','dark','leaf','lavender','peach','pearl','ice','glass']
PARTS={};MATS={};PIVOTS={};REPORT={}
def V(p):return Vector((p[0],-p[2],p[1]))
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 PARTS.clear();MATS.clear();PIVOTS.clear()
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
 global ATLAS
 ATLAS=bpy.data.images.load(str(OUT/'source/palette.png'),check_existing=False);ATLAS.pack();ATLAS.name='Decor_Colour_Only_128x64'
def tag(o,color,group='Body'):
 if color not in MATS:
  m=bpy.data.materials.new('Pastel_'+color);m.use_nodes=True
  bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.7;bs.inputs['Metallic'].default_value=0
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=ATLAS;tex.interpolation='Closest';m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  if color=='glass':m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=True
  MATS[color]=m
 o.data.materials.clear();o.data.materials.append(MATS[color])
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='PaletteUV');uv.name='PaletteUV';i=COL.index(color);cx=(i%8+.5)/8;cy=1-(i//8+.5)/4
 for f in o.data.polygons:
  for j,k in enumerate(f.loop_indices):
   a=j*2*pi/len(f.loop_indices);uv.data[k].uv=(cx+.003*cos(a),cy+.003*sin(a))
 PARTS.setdefault(group,[]).append(o);return o
def mesh(vs,fs,col,group='Body',smooth=True):
 me=bpy.data.meshes.new('SoftMesh');me.from_pydata([V(v) for v in vs],[],fs);me.update()
 o=bpy.data.objects.new('SoftPart',me);bpy.context.collection.objects.link(o)
 for f in me.polygons:f.use_smooth=smooth
 return tag(o,col,group)
def ball(c,s,col,group='Body',n=12,r=6):
 vs=[(c[0],c[1]+s[1],c[2])]
 for j in range(1,r):
  for i in range(n):
   a=2*pi*i/n;th=pi*j/r;vs.append((c[0]+s[0]*sin(th)*cos(a),c[1]+s[1]*cos(th),c[2]+s[2]*sin(th)*sin(a)))
 vs.append((c[0],c[1]-s[1],c[2]));bot=len(vs)-1
 fs=[(0,1+(i+1)%n,1+i) for i in range(n)]
 for j in range(r-2):
  for i in range(n):a=1+j*n+i;b=1+j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend((bot,1+(r-2)*n+i,1+(r-2)*n+(i+1)%n) for i in range(n))
 return mesh(vs,fs,col,group)
def box(c,s,col,group='Body',bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=V(c));o=bpy.context.object;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  m=o.modifiers.new('Rounded corners','BEVEL');m.width=min(bevel,min(s)*.45);m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
 for f in o.data.polygons:f.use_smooth=True
 m=o.modifiers.new('Soft normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
 return tag(o,col,group)
def tube(points,r,col,group='Body',n=8):
 radii=[r]*len(points) if isinstance(r,(float,int)) else r;vs=[]
 for j,p in enumerate(points):
  t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized();a=Vector((1,0,0))
  if abs(t.dot(a))>.9:a=Vector((0,0,1))
  u=t.cross(a).normalized();v=t.cross(u)
  for k in range(n):
   off=radii[j]*(u*cos(2*pi*k/n)+v*sin(2*pi*k/n));vs.append(tuple(Vector(p)+off))
 fs=[tuple(reversed(range(n))),tuple((len(points)-1)*n+i for i in range(n))]
 for j in range(len(points)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 return mesh(vs,fs,col,group)
def lathe(c,prof,col,group='Body',n=24,oval=1,axis='y'):
 vs=[]
 for h,r in prof:
  for k in range(n):
   a=2*pi*k/n;u=r*cos(a);v=r*sin(a)*oval;q=(u,h,-v) if axis=='y' else (u,v,h)
   vs.append(tuple(c[i]+q[i] for i in range(3)))
 fs=[]
 for j in range(len(prof)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend([tuple(reversed(range(n))),tuple((len(prof)-1)*n+k for k in range(n))])
 return mesh(vs,fs,col,group)
def ring(c,r,t,col,group='Body',n=24,m=6,oval=1,axis='y',height=None):
 vs=[]
 for k in range(n):
  a=2*pi*k/n;h=c[1] if height is None else height(a)
  for j in range(m):
   q=2*pi*j/m;rr=r+t*cos(q);u=rr*cos(a);v=rr*sin(a)*oval;w=t*sin(q)
   vs.append((c[0]+u,h+w,c[2]-v) if axis=='y' else (c[0]+u,c[1]+v,c[2]+w))
 fs=[]
 for k in range(n):
  for j in range(m):a=k*m+j;b=k*m+(j+1)%m;fs.append((a,b,((k+1)%n)*m+(j+1)%m,((k+1)%n)*m+j))
 return mesh(vs,fs,col,group)
def extrude(points,lo,hi,col,group='Body',plane='xy'):
 vs=[]
 for dep in [lo,hi]:
  for x,y in points:vs.append((x,y,dep) if plane=='xy' else (x,dep,-y))
 n=len(points);fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
 return mesh(vs,fs,col,group,smooth=False)
def oval(c,rx,ry,depth,col,group='Body',plane='xy',n=24):
 pts=[(c[0]+rx*cos(2*pi*k/n),(c[1] if plane=='xy' else -c[2])+ry*sin(2*pi*k/n)) for k in range(n)]
 mid=c[2] if plane=='xy' else c[1];return extrude(pts,mid-depth/2,mid+depth/2,col,group,plane)
def star(c,r,col='gold',group='Body',dep=.009,plane='xy'):
 pts=[(c[0]+(r if k%2==0 else r*.52)*cos(pi/2+k*pi/5),(c[1] if plane=='xy' else -c[2])+(r if k%2==0 else r*.52)*sin(pi/2+k*pi/5)) for k in range(10)]
 mid=c[2] if plane=='xy' else c[1];return extrude(pts,mid-dep/2,mid+dep/2,col,group,plane)
def cloud(c,s,col='white',group='Body',n=10,r=5):
 for dx,dy,rr in [(-.58,-.08,.62),(0,.20,.80),(.58,-.08,.62)]:ball((c[0]+dx*s[0],c[1]+dy*s[1],c[2]),(s[0]*rr,s[1]*rr,s[2]),col,group,n,r)
def arc(c,r,t,col,group='Body',steps=14,plane='xy'):
 if plane=='xy':p=[(c[0]+r*cos(pi*k/steps),c[1]+r*sin(pi*k/steps),c[2]) for k in range(steps+1)]
 else:p=[(c[0]+r*cos(pi*k/steps),c[1],c[2]-r*sin(pi*k/steps)) for k in range(steps+1)]
 return tube(p,t,col,group,n=5)
def bone2(w,h):
 # Smooth concave bone silhouette, sampled analytically as rounded lobes.
 pts=[]
 for cx,cy,a0,a1 in [(w*.31,h*.20,0,140),(-w*.31,h*.20,40,180),(-w*.31,-h*.20,180,320),(w*.31,-h*.20,220,360)]:
  for k in range(9):
   a=math.radians(a0+(a1-a0)*k/8);pts.append((cx+w*.19*cos(a),cy+h*.30*sin(a)))
 return pts
def normalize_xz(width,depth):
 bpy.context.view_layer.update();obs=[o for ps in PARTS.values() for o in ps];pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices];mn=[min(p[k] for p in pts) for k in range(3)];mx=[max(p[k] for p in pts) for k in range(3)]
 for o in obs:
  for v in o.data.vertices:
   p=o.matrix_world@v.co;p.x=(p.x-(mn[0]+mx[0])/2)*width/(mx[0]-mn[0]);p.y=(p.y-(mn[1]+mx[1])/2)*depth/(mx[1]-mn[1]);v.co=o.matrix_world.inverted()@p

def finish(name,limit,origin='floor',notes=None):
 bpy.context.view_layer.update()
 if origin=='back centre':
  obs=[o for ps in PARTS.values() for o in ps];pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
  mn=[min(p[k] for p in pts) for k in range(3)];mx=[max(p[k] for p in pts) for k in range(3)]
  width,height,depth=(1.6,.5,.08) if name.startswith('sign_') else (.6,.5,.05)
  def convert(p):return Vector(((p.x-(mn[0]+mx[0])/2)*width/(mx[0]-mn[0]),(p.y-mn[1])*depth/(mx[1]-mn[1]),(p.z-(mn[2]+mx[2])/2)*height/(mx[2]-mn[2])))
  for o in obs:
   inv=o.matrix_world.inverted()
   for v in o.data.vertices:v.co=inv@convert(o.matrix_world@v.co)
  for g,p in list(PIVOTS.items()):
   q=convert(V(p));PIVOTS[g]=(q.x,q.z,-q.y)
  # Front is -Z in delivery coordinates, i.e. +Y in Blender.
 if name=='counter_cake':
  obs=[o for ps in PARTS.values() for o in ps];top=max((o.matrix_world@v.co).z for o in obs for v in o.data.vertices)
  for o in obs:
   inv=o.matrix_world.inverted()
   for v in o.data.vertices:
    p=o.matrix_world@v.co;p.z*=.95/top;v.co=inv@p
 bpy.context.view_layer.update();root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for group,obs in list(PARTS.items()):
  bpy.ops.object.select_all(action='DESELECT')
  for o in obs:o.select_set(True)
  bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  # Weld profile poles before triangulating and rebuild outward normals.
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
  m=o.modifiers.new('Delivery triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
  p=V(PIVOTS.get(group,(0,0,0)))
  for v in o.data.vertices:v.co-=p
  o.location=p;o.parent=root
 bpy.context.view_layer.update()
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];tris=sum(len(o.data.polygons) for o in obs)
 assert tris<=limit,(name,tris,limit)
 pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
 mn=[min(p[k] for p in pts) for k in range(3)];mx=[max(p[k] for p in pts) for k in range(3)]
 REPORT[name]={'triangles':tris,'budget':limit,'dimensions_m':[round(mx[0]-mn[0],5),round(mx[2]-mn[2],5),round(mx[1]-mn[1],5)],'bounds_min_y_up':[mn[0],mn[2],-mx[1]],'bounds_max_y_up':[mx[0],mx[2],-mn[1]],'origin':origin,'parts':{o.name:[round(o.location.x,5),round(o.location.z,5),round(-o.location.y,5)] for o in obs},'notes':notes or ''}
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
 print('DECOR',name,tris,REPORT[name]['dimensions_m'],flush=True)

def stand(col='wood',wave=False):
 box((0,.43,0),(1.48,.86,.98),col,'Stand',.09)
 box((0,.875,0),(1.6,.05,1.1),'sky' if wave else col,'Stand',.022)
 if wave:
  for x in [-.56,-.28,0,.28,.56]:ball((x,.37,-.493),(.20,.12,.018),'ice','Stand',10,4)
 else:
  for x in [-.48,-.16,.16,.48]:box((x,.43,-.494),(.012,.68,.012),'grain','Stand',.003)
def bowl(col='wood',rim='sky',claw=False,shell=False):
 n=40;vs=[];radii=[.42,.52,.59,.60,.54,.48,.38];ys=[.905,.92,.99,1.044,1.04,.955,.93]
 for j in range(len(radii)):
  for k in range(n):
   a=2*pi*k/n;front=max(0,sin(a));h=ys[j]-(.042*front**4 if j in [2,3,4] else 0)
   rr=radii[j]*(1+.025*cos(10*a) if shell else 1);vs.append((rr*cos(a),h,-rr*sin(a)))
 fs=[]
 for j in range(len(radii)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend([tuple(reversed(range(n))),tuple((len(radii)-1)*n+k for k in range(n))])
 mesh(vs,fs,col,'Tub');ring((0,1.044,0),.60,.016,rim,'Tub',n=40,m=8,height=lambda a:1.044-.042*max(0,sin(a))**4)
 if col=='wood':
  for h,r in [(.94,.545),(1.005,.591)]:ring((0,h,0),r,.012,'sky','Tub',n=40,m=4)
  for k in range(24):
   a=k*2*pi/24;tube([(.526*cos(a),.93,-.526*sin(a)),(.591*cos(a),.995-.027*max(0,sin(a))**4,-.591*sin(a))],.004,'grain','Tub',n=4)
 if claw:
  for x in [-.40,.40]:
   for z in [-.34,.34]:
    ball((x,.92,z),(.085,.05,.085),'pink','Tub',10,5)
    for dx in [-.035,0,.035]:ball((x+dx,.908,z-.060),(.022,.025,.024),'blush','Tub',8,4)
 if shell:
  # Shallow scallop flutes on the back, leaving the player's front edge lowered.
  for k in range(11):
   a=pi+k*pi/10;r=.57
   tube([(r*.73*cos(a),.935,-r*.73*sin(a)),(r*cos(a),1.035,-r*sin(a))],[.018,.024],'blush' if k%2 else 'ice','Tub',n=6)
 PIVOTS['Plug']=(0,.935,-.23);lathe((0,.935,-.23),[(0,.035),(.008,.035)],'gold' if shell else 'sky','Plug',n=16)
 ring((0,.947,-.23),.012,.003,'white','Plug',n=12,m=4)
def tubs():
 for name,col,rim in [('tub_wood','wood','sky'),('tub_claw','white','pink'),('tub_shell','pearl','gold')]:
  reset();stand('sky' if name=='tub_shell' else 'wood',name=='tub_shell');bowl(col,rim,name=='tub_claw',name=='tub_shell');finish(name,4000,notes='Stand 1.6 x 1.1 m, top Y=.9; round Tub radius .6; rear rim Y=1.06, front rim Y=1.018. Plug separate.')
def shelves():
 for name in ['shelf_wood','shelf_basket','shelf_cloud']:
  reset();fancy=name=='shelf_cloud';col='white' if fancy else 'wood'
  box((0,.85,0),(1.8,.10,.6),col,bevel=.035)
  for x in [-.78,.78]:
   for z in [-.22,.22]:box((x,.4,z),(.12,.8,.12),'sky' if fancy else 'wood',bevel=.035)
  box((0,.15,0),(1.66,.10,.52),col,bevel=.03);box((0,.49,.25),(1.6,.60,.04),col,bevel=.015)
  if name=='shelf_wood':box((0,.49,0),(.07,.58,.5),'wood',bevel=.015)
  if name=='shelf_basket':
   for i,x in enumerate([-.53,0,.53]):
    c='pink' if i==1 else 'mint';box((x,.35,-.005),(.45,.32,.43),c,bevel=.055)
    box((x,.47,-.01),(.46,.055,.44),'blush' if i==1 else 'floor',bevel=.023)
    oval((x,.38,-.226),.075,.025,.009,'butter',n=16)
    for dx in [-.14,.14]:tube([(x+dx,.22,-.225),(x+dx,.43,-.225)],.005,'blush' if i==1 else 'floor',n=4)
  if fancy:
   for x,y,r in [(-.70,.76,.16),(-.37,.78,.20),(0,.78,.22),(.37,.78,.20),(.70,.76,.16)]:
    ball((x,y,-.22),(r,.115,.075),'white',n=10,r=5)
   star((0,.44,-.28),.12);star((-.51,.66,-.292),.055);star((.51,.66,-.292),.055)
  finish(name,3000,notes='Flat horizontal working surface Y=.9, 1.8 x .6 m; ornaments remain below top.')
def counters():
 reset();box((0,.455,0),(1.12,.91,.44),'wood',bevel=.045);box((0,.92,0),(1.2,.06,.5),'wood',bevel=.025)
 box((0,.70,-.224),(1.08,.12,.016),'sky',bevel=.007);box((0,.08,-.225),(.98,.045,.014),'grain',bevel=.006);finish('counter_wood',3000)
 reset();pts=bone2(1.2,.5);extrude(pts,.86,.95,'pink',plane='xz');box((0,.43,0),(.83,.86,.32),'blush',bevel=.08)
 for x in [-.38,.38]:ball((x,.45,0),(.13,.45,.16),'pink',n=14,r=8)
 finish('counter_bone',3000)
 reset();lathe((0,0,0),[(0,.5),(.05,.55),(.48,.55),(.52,.51)],'pink',n=36,oval=.43)
 lathe((0,0,0),[(.48,.4),(.54,.44),(.86,.44),(.88,.41)],'butter',n=36,oval=.49)
 for h,rr in [(.07,.55),(.5,.535),(.88,.435)]:ring((0,h,0),rr,.014,'gold',n=36,m=4,oval=.44)
 # Cream crown, with rounded drips along the front rather than a dark decal.
 for i in range(12):
  a=2*pi*i/12;x=.44*cos(a);z=-.215*sin(a);ball((x,.81,z),(.045,.075 if i%2 else .10,.026),'white',n=8,r=4)
 lathe((0,0,0),[(.87,.40),(.90,.43)],'white',n=36,oval=.49)
 ball((0,.915,0),(.045,.035,.045),'red',n=12,r=6);tube([(0,.94,0),(.015,.95,.005)],.005,'mint',n=6)
 normalize_xz(1.2,.5);finish('counter_cake',3000,notes='Overall height .95 m including cherry stem; two oval cake tiers.')
def signs():
 reset();box((0,-.035,-.04),(1.6,.36,.08),'wood',bevel=.07)
 for x in [-.52,.52]:tube([(x,.14,-.025),(x*.7,.25,-.025)],.012,'grain',n=8)
 # A clean inset blank label on the face, no lettering.
 box((0,-.035,-.083),(1.32,.23,.006),'butter',bevel=.055)
 finish('sign_board',1500,'back centre',notes='Blank label 1.32 x .23 m. Back Z=0.')
 reset();ball((0,-.065,-.04),(.8,.17,.04),'pink',n=24,r=8)
 for x,y,s in [(-.59,.11,.11),(-.22,.15,.1),(.22,.15,.1),(.59,.11,.11)]:ball((x,y,-.04),(s,.10,.04),'pink',n=10,r=5)
 box((0,-.065,-.079),(1.08,.20,.004),'blush',bevel=.07);finish('sign_paw',1500,'back centre',notes='Wide paw silhouette, blank central label 1.08 x .2 m; back Z=0.')
 reset();box((0,-.025,-.04),(1.50,.40,.08),'butter',bevel=.08)
 # Five rounded stripes follow the plate perimeter and leave the whole centre blank.
 for i,col in enumerate(['pink','butter','mint','sky','lavender']):
  x=.67+i*.018;y=.155+i*.014
  pts=[(-x,-y-.025,-.085),(-x-.015,y-.025,-.085),(-x+.07,y+.015,-.085),(x-.07,y+.015,-.085),(x+.015,y-.025,-.085),(x,-y-.025,-.085)]
  tube(pts,.011,col,n=5)
 for x in [-.67,.67]:cloud((x,-.13,-.104),(.105,.07,.025),n=8,r=4)
 for x in [-.55,.55]:star((x,.18,-.114),.045,dep=.008)
 finish('sign_rainbow',1500,'back centre',notes='Cream blank label 1.05 x .25 m; rainbow trim, cloud ends, gold stars.')
def lamps():
 reset();lathe((0,0,0),[(-.04,.06),(0,.06)],'white',n=16);tube([(0,-.04,0),(0,-.43,0)],.012,'wood',n=8)
 lathe((0,0,0),[(-.43,.04),(-.45,.09),(-.49,.15),(-.58,.20),(-.60,.20),(-.59,.17),(-.49,.07)],'sky',n=24)
 ball((0,-.64,0),(.055,.06,.055),'butter','Bulb',n=12,r=6);PIVOTS['Bulb']=(0,-.64,0);finish('lamp_bulb',1500,'top hook')
 reset();lathe((0,0,0),[(-.04,.07),(0,.07)],'butter',n=16)
 for x,y,z,rr in [(-.12,-.47,.025,.115),(.12,-.52,.025,.105),(0,-.60,-.10,.10)]:
  tube([(x*.45,-.035,z*.45),(x,y+rr,z)],.006,'grain',n=6);ball((x,y,z),(rr,rr,rr),'glass',n=16,r=8)
  ring((x,y,z),rr,.003,'ice',n=16,m=4,axis='z');ball((x,y,z),(.026,.032,.026),'butter','Bulb',n=8,r=4)
 PIVOTS['Bulb']=(0,-.53,0);finish('lamp_bubble',1500,'top hook',notes='Three alpha-blended bubble shades; Bulb groups all three bulb cores, no baked light.')
 reset();lathe((0,0,0),[(-.04,.065),(0,.065)],'gold',n=16);tube([(0,-.04,0),(0,-.35,0)],.009,'sky',n=6)
 cloud((0,-.41,0),(.17,.09,.15),n=12,r=6);ball((0,-.445,0),(.09,.018,.07),'butter','Bulb',n=12,r=5);PIVOTS['Bulb']=(0,-.445,0)
 for x,y in [(-.14,-.62),(0,-.67),(.14,-.61)]:tube([(x,-.46,0),(x,y+.035,0)],.004,'gold',n=5);star((x,y,0),.034,dep=.012)
 finish('lamp_cloud',1500,'top hook')
def pot(h,r,col):
 lathe((0,0,0),[(0,r*.78),(.025,r*.85),(h*.84,r),(h,r*.98),(h,r*.84),(h-.035,r*.83)],col,n=20)
 lathe((0,h-.03,0),[(0,r*.80),(.006,r*.80)],'grain',n=20)
 ring((0,h*.91,0),r,.012,'butter' if col=='wood' else col,n=20,m=5)
def leaf(c,w,h,col,angle=0,tilt=.04):
 # Monstera-like open edge fenestrations, a heart-shaped base and soft lobes.
 pts=[(0,0),(-.32,.13),(-.47,.30),(-.49,.47),(-.27,.43),(-.50,.64),(-.43,.78),(-.20,.66),(-.28,.90),(0,1),(.28,.90),(.20,.66),(.43,.78),(.50,.64),(.27,.43),(.49,.47),(.47,.30),(.32,.13)]
 # One corner-cut pass rounds the leaf lobes and open notches.
 pts=[(a[0]*q+b[0]*(1-q),a[1]*q+b[1]*(1-q)) for a,b in zip(pts,pts[1:]+pts[:1]) for q in [.75,.25]]
 vs=[]
 for x,y in pts:
  xx=x*w;yy=y*h;vs.append((c[0]+xx*cos(angle)+yy*sin(angle),c[1]-xx*sin(angle)+yy*cos(angle),c[2]+tilt*sin(y*pi)))
 centre=(sum(v[0] for v in vs)/len(vs),sum(v[1] for v in vs)/len(vs),c[2]-.015);vs.append(centre);n=len(pts)
 fs=[(n,k,(k+1)%n) for k in range(n)];o=mesh(vs,fs,col)
 # Two-sided leaf surface, baked into geometry without a normal texture.
 m=o.modifiers.new('Leaf thickness','SOLIDIFY');m.thickness=.008;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
 tube([c,(c[0]+h*.85*sin(angle),c[1]+h*.85*cos(angle),c[2]-.018)],.004,'floor',n=5)
def plants():
 reset();pot(.25,.16,'pink');tube([(0,.22,0),(0,.42,0)],.025,'mint',n=8)
 for x,y,z,r in [(-.12,.43,0,.13),(.11,.44,.02,.135),(0,.48,0,.12),(0,.41,-.10,.13)]:ball((x,y,z),(r,r,r),'mint' if x<0 else 'leaf',n=12,r=6)
 finish('plant_round',2000)
 reset();pot(.30,.18,'sky')
 for x,y,z,ang,w,h in [(-.16,.5,.04,-.85,.27,.33),(.16,.57,.07,.7,.28,.35),(0,.61,.08,0,.30,.29),(-.05,.43,-.12,-1.1,.25,.28),(.09,.40,-.11,1.05,.26,.29)]:
  tube([(0,.27,0),(x,y,z)],.010,'mint',n=7);leaf((x,y,z),w,h,'mint' if x<0 else 'leaf',ang)
 # Normalize vertical extent to the requested .9 m while preserving base pivot.
 for ps in PARTS.values():
  for o in ps:
   for v in o.data.vertices:v.co.z*=.9/.98
 # Exact final height adjustment after updating transforms.
 bpy.context.view_layer.update();top=max((o.matrix_world@v.co).z for ps in PARTS.values() for o in ps for v in o.data.vertices)
 for ps in PARTS.values():
  for o in ps:
   for v in o.data.vertices:v.co.z*=.9/top
 finish('plant_monstera',2000)
 reset();pot(.34,.23,'wood');tube([(0,.30,0),(-.025,.68,0),(0,1.07,0)],[.045,.033,.018],'grain',n=10)
 for side in [-1,1]:tube([(0,.68,0),(side*.20,.92,.01),(side*.24,1.08,0)],[.022,.018,.008],'grain',n=7)
 for x,y,z,rr in [(-.22,1.04,0,.19),(0,1.10,0,.20),(.22,1.04,0,.19),(0,.91,-.08,.20)]:ball((x,y,z),(rr,rr,rr*.85),'mint' if x<0 else 'leaf',n=12,r=6)
 for x,y,z in [(-.24,1.01,-.16),(0,1.14,-.17),(.24,.98,-.15),(.08,.87,-.23),(-.11,.91,-.22)]:
  ball((x,y,z),(.045,.060,.045),'butter',n=10,r=5);tube([(x,y+.05,z),(x,y+.075,z)],.005,'mint',n=5)
 finish('plant_lemon',2000)
def rugs():
 reset();oval((0,.009,0),.8,.5,.018,'white',plane='xz',n=40);oval((0,.018,0),.75,.45,.004,'sky',plane='xz',n=40);finish('rug_circle',500,notes='1.6 x 1 m, total thickness .02 m.')
 reset();oval((0,.009,.18),.56,.32,.018,'pink',plane='xz',n=24)
 for x,z,rx,rz in [(-.60,-.19,.20,.19),(-.22,-.32,.18,.18),(.22,-.32,.18,.18),(.60,-.19,.20,.19)]:oval((x,.009,z),rx,rz,.018,'pink',plane='xz',n=16)
 normalize_xz(1.6,1);finish('rug_paw',500)
 reset()
 # Continuous 16-segment arch: coloured top bands, one shared closed underside.
 cols=['pink','peach','butter','mint','sky','lavender'];steps=16
 for i,col in enumerate(cols):
  ro=.80-i*.10;ri=ro-.10
  vs=[(rr*cos(pi*k/steps),.018,-rr*sin(pi*k/steps)+.24) for rr in [ro,ri] for k in range(steps+1)]
  mesh(vs,[(k,k+1,k+1+steps+1,k+steps+1) for k in range(steps)],col,smooth=False)
 vs=[(rr*cos(pi*k/steps),h,-rr*sin(pi*k/steps)+.24) for h,rr in [(.018,.8),(.018,.2),(0,.8),(0,.2)] for k in range(steps+1)]
 n=steps+1;fs=[]
 for k in range(steps):
  fs.extend([(2*n+k,3*n+k,3*n+k+1,2*n+k+1),(k,2*n+k,2*n+k+1,k+1),(n+k,n+k+1,3*n+k+1,3*n+k)])
 for k in [0,steps]:
  ids=[k]
  for rr in [.7,.6,.5,.4,.3]:ids.append(len(vs));vs.append((rr*cos(pi*k/steps),.018,-rr*sin(pi*k/steps)+.24))
  ids.extend([n+k,3*n+k,2*n+k]);fs.append(tuple(ids))
 mesh(vs,fs,'pink',smooth=False)
 for x in [-.64,.64]:
  oval((x,.01,.25),.16,.13,.020,'white',plane='xz',n=12)
  for dx in [-.08,0,.08]:box((x+dx,.009,.38),(.035,.018,.10),'white',bevel=0)
 normalize_xz(1.6,1);finish('rug_rainbow',500)
def arts():
 reset();box((0,0,-.025),(.60,.50,.05),'wood',bevel=.035);box((0,0,-.051),(.52,.42,.003),'butter',bevel=.014)
 # Relief-style flat graphic, no text. Smiling puppy with drooping ears.
 oval((0,-.005,-.054),.145,.14,.002,'wood',n=24)
 for x in [-.143,.143]:oval((x,-.025,-.055),.05,.095,.003,'grain',n=16)
 for x in [-.055,.055]:oval((x,.021,-.057),.011,.017,.003,'dark',n=12)
 for x in [-.034,.034]:oval((x,-.062,-.058),.048,.033,.003,'white',n=16)
 oval((0,-.045,-.061),.018,.012,.002,'dark',n=12)
 tube([(-.032,-.087,-.061),(0,-.102,-.061),(.032,-.087,-.061)],.004,'dark',n=5)
 for x in [-.10,.10]:oval((x,-.049,-.060),.026,.012,.002,'pink',n=12)
 finish('art_dog',1500,'back centre',notes='Original smiling dog flat-colour relief picture. Back Z=0.')
 reset();pts=bone2(.60,.50);extrude(pts,-.045,0,'pink')
 oval((0,0,-.047),.17,.17,.004,'butter',n=40)
 for k in range(12):
  a=k*2*pi/12;oval((.14*sin(a),.14*cos(a),-.050),.009,.009,.003,'wood',n=8)
 for group,p,sz,col in [('Hand_H',(0,.040,-.055),(.018,.09,.005),'sky'),('Hand_M',(.045,.067,-.061),(.014,.16,.005),'red')]:
  o=box(p,sz,col,group,bevel=.005)
  if group=='Hand_M':
   # Tilt around joint, with hand centre offset from clock centre.
   for v in o.data.vertices:
    pass
   o.rotation_euler[1]=-.55
  PIVOTS[group]=(0,0,-.055 if group=='Hand_H' else -.061)
 ball((0,0,-.067),(.018,.018,.008),'gold',n=10,r=4)
 finish('art_clock',1500,'back centre',notes='Hand_H and Hand_M are separate mesh nodes, pivot at clock centre; rotate local Z. 12 face dots.')
 reset();cloud((-.04,-.11,-.024),(.20,.10,.024),n=10,r=5)
 for i,(x,y,r,col) in enumerate([(-.18,.055,.066,'pink'),(-.045,.12,.075,'mint'),(.105,.10,.067,'sky'),(.20,.02,.05,'lavender')]):
  ball((x,y,-.021),(r,r,.021),col,n=10,r=5);ring((x,y,-.044),r*.88,.004,'white',n=12,m=4,axis='z')
  oval((x-r*.3,y+r*.3,-.047),r*.12,r*.19,.002,'white',n=8)
 # Tiny rubber duck in the lower-right cloud.
 ball((.18,-.12,-.033),(.065,.04,.016),'butter',n=12,r=5);ball((.205,-.073,-.032),(.031,.031,.018),'butter',n=10,r=5)
 ball((.239,-.078,-.036),(.023,.009,.012),'peach',n=8,r=4);oval((.215,-.068,-.051),.004,.005,.002,'dark',n=8)
 for x,y,r in [(-.26,.18,.028),(.25,.18,.024),(.02,-.215,.026)]:star((x,y,-.025),r,dep=.009)
 finish('art_bubble',1500,'back centre',notes='Rainbow bubble cloud, original small rubber duck, gold sparkles; back Z=0.')
if __name__=='__main__':
 names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 if names and (OUT/'validation_geometry.json').exists():REPORT.update(json.loads((OUT/'validation_geometry.json').read_text()))
 for f in [tubs,shelves,counters,signs,lamps,plants,rugs,arts]:
  if not names or f.__name__ in names:f()
 (OUT/'validation_geometry.json').write_text(json.dumps(REPORT,indent=2)+'\n')
 print('DONE',len(REPORT),flush=True)
