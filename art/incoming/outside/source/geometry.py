"""Original pastel outside assets, Blender 4.2. Metres, Y up, front -Z.
Run make_textures.py first; blender -b --factory-startup --python build_outside.py
No external assets. All meshes use an embedded colour-only PNG atlas.
"""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
from math import sin,cos,pi
OUT=Path(__file__).resolve().parents[1]
COL=['floor','butter','wood','sky','red','pink','mint','blue','white','gold','blush','grain','dark','leaf','lavender','peach','pearl','ice','glass','cardboard','asphalt','tire','cream']
PARTS={};MATS={};PIVOTS={};REPORT={}
def V(p):return Vector((p[0],-p[2],p[1]))
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 PARTS.clear();MATS.clear();PIVOTS.clear()
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
 global ATLAS
 ATLAS=bpy.data.images.load(str(OUT/'source/palette.png'),check_existing=False);ATLAS.pack();ATLAS.name='Outside_Colour_Only_128x64'
def tag(o,color,group='Body'):
 if color not in MATS:
  m=bpy.data.materials.new('Pastel_'+color);m.use_nodes=True
  bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.7;bs.inputs['Metallic'].default_value=0
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=ATLAS;tex.interpolation='Closest';m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  if color=='glass':m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=True
  MATS[color]=m
 o.data.materials.clear();o.data.materials.append(MATS[color])
 while len(o.data.uv_layers)>1:o.data.uv_layers.remove(o.data.uv_layers[-1])
 uv=o.data.uv_layers[0] if o.data.uv_layers else o.data.uv_layers.new(name='PaletteUV');uv.name='PaletteUV';i=COL.index(color);cx=(i%8+.5)/8;cy=1-(i//8+.5)/4
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

