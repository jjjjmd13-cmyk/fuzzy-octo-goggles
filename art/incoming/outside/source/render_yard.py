"""Illustrative 7m-wide x 5m-deep yard. Actual GLBs at real scale; camera eye 1.6m.
This is an art placement preview, not a gameplay build. No preview geometry enters GLBs.
"""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent));import geometry as g
OUT=g.OUT
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def place(name,p,angle=0):
 old=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')));new=[o for o in bpy.context.scene.objects if o not in old]
 root=bpy.data.objects.new('Placed_'+name,None);bpy.context.collection.objects.link(root)
 for o in new:
  if o.parent is None:o.parent=root
 root.location=g.V(p);root.rotation_euler[2]=angle;return root,new
def flatmat(col):
 m=bpy.data.materials.new('Preview surface');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
def ground(c,w,d,tex,turn=False):
 bpy.ops.mesh.primitive_plane_add(size=1,location=g.V(c));o=bpy.context.object;o.scale=(w,d,1);m=flatmat((1,1,1));im=bpy.data.images.load(str(OUT/(tex+'.png')));node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color']);o.data.materials.append(m)
 uv=o.data.uv_layers.active
 for f in o.data.polygons:
  for k in f.loop_indices:
   v=o.data.vertices[o.data.loops[k].vertex_index].co;uv.data[k].uv=(v.y*d+.5,v.x*w+.5) if turn else (v.x*w+.5,v.y*d+.5)
 return o
place('shop_front',(0,.01,0));place('sign_outside',(2.45,2.72,-.84));place('open_sign',(2.65,1.92,-.115))
ground((0,.01,-2.5),7,5,'paving');ground((0,-.06,-6.8),11,3.6,'road');ground((0,-.059,-6.8),11,1,'road_line',True)
# A neutral floor and rear panel stand in for the separately developed shop interior.
ground((0,.01,.9),7,1.8,'paving')
bpy.ops.mesh.primitive_cube_add(size=1,location=g.V((0,1.5,1.9)));o=bpy.context.object;o.dimensions=(7,.1,3);o.data.materials.append(flatmat((.98,.91,.77)))
for x in [-2.5,-.5,1.5]:place('fence',(x,.01,-4.9));place('flower_bed',(x,.01,-4.45))
place('mailbox',(3.05,.01,-3.6));place('street_lamp',(-3.05,.01,-3.05));place('cart',(-1.6,.01,-1.55),-.25)
place('delivery_mat',(1.65,.012,-1.2));place('box_medium',(1.65,.033,-1.2));place('box_small',(1.97,.033,-1.1),.2)
place('truck',(-1.65,-.06,-6.55),math.pi/2)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True;scene.render.resolution_x=1400;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.79,.88,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
for loc,power,size in [((-4,8,-4),1500,7),((5,5,-2),700,6),((0,5,4),600,5)]:
 bpy.ops.object.light_add(type='AREA',location=g.V(loc));o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(g.V((0,1,-2))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=g.V((5.6,1.6,-11.7)));cam=bpy.context.object;cam.rotation_euler=(g.V((0,1.1,-2.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=30;scene.camera=cam
scene.render.filepath=str(OUT/'yard_preview.png');scene.render.image_settings.file_format='PNG';bpy.ops.render.render(write_still=True)
print('YARD preview at 1.6m eye; yard 7 x 5m',flush=True)
