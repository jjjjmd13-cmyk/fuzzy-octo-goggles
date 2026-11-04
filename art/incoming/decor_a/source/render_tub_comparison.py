"""Same-scale GLB lineup and a .60 x .28 x .35m dog-size reference box."""
import bpy,json
from mathutils import Vector
from pathlib import Path
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.8
 return m
for name,x in [('tub_wood',2.05),('tub_claw',0),('tub_shell',-2.05)]:
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
 for o in set(bpy.data.objects)-old:
  if o.parent is None:o.location.x+=x
bpy.ops.mesh.primitive_cube_add(size=1,location=(3.34,.02,.175));box=bpy.context.object
box.name='ReferenceBox_60x28x35cm';box.dimensions=(.60,.28,.35)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
box.data.materials.append(material('Reference peach',(.9,.55,.30)))
bevel=box.modifiers.new('Soft reference corners','BEVEL');bevel.width=.008;bevel.segments=2
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.004));bpy.context.object.data.materials.append(material('Studio floor',(.76,.84,.84)))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
s.render.resolution_x=2200;s.render.resolution_y=1100;s.render.resolution_percentage=100
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.80,.88,1,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
target=Vector((.38,0,.68))
for location,power,size in [((-3,4,7),1800,6),((5,2,4),700,5),((0,-4,5),1100,5)]:
 bpy.ops.object.light_add(type='AREA',location=location);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.4,10,6.2));cam=bpy.context.object;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8.3;s.camera=cam
s.view_settings.exposure=-.25
s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'tubs_comparison.png');bpy.ops.render.render(write_still=True)
points={}
for name,p in {'wood':(2.05,.75,0),'claw':(0,.75,0),'shell':(-2.05,.75,0),'box':(3.34,0,.35)}.items():
 q=world_to_camera_view(s,cam,Vector(p));points[name]=[q.x*2200,(1-q.y)*1100]
(OUT/'source/comparison_labels.json').write_text(json.dumps(points,indent=2)+'\n')
