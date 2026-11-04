"""Render actual exported GLBs with neutral studio lights, never baked into assets."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]
def mat(c):
 m=bpy.data.materials.new('Preview only');m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.9;return m
def render(path):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(path));bpy.context.view_layer.update()
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
 scene.world.use_nodes=True;bg=scene.world.node_tree.nodes['Background'];bg.inputs['Color'].default_value=(.8,.88,1,1);bg.inputs['Strength'].default_value=.4
 scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.image_settings.file_format='PNG'
 points=[o.matrix_world@Vector(p) for o in scene.objects if o.type=='MESH' for p in o.bound_box];low=Vector([min(p[k] for p in points) for k in range(3)]);high=Vector([max(p[k] for p in points) for k in range(3)]);centre=(low+high)/2;size=max(high-low)
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,low.z-.003));bpy.context.object.data.materials.append(mat((.83,.88,.87)))
 def light(loc,pow,width):
  bpy.ops.object.light_add(type='AREA',location=centre+Vector(loc)*size);o=bpy.context.object;o.data.energy=pow*size*size;o.data.shape='DISK';o.data.size=width*size;o.rotation_euler=(centre-o.location).to_track_quat('-Z','Y').to_euler()
 light((-2.2,3,4),340,2.8);light((3,2,2),90,3);light((1,-3,3),150,3)
 name=path.stem
 if name.startswith(('sign_','art_')):direction=Vector((.55,4,.3));scale=1.23
 elif name.startswith('rug_'):direction=Vector((.7,1.3,3.2));scale=1.25
 elif name.startswith('tub_'):direction=Vector((1.8,3.5,2.8));scale=1.4
 elif name.startswith('lamp_'):direction=Vector((1.2,3.5,.5));scale=1.25
 else:direction=Vector((1.9,3.6,1.8));scale=1.35
 bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.location=centre+direction.normalized()*size*4;cam.rotation_euler=(centre-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*scale
 scene.render.filepath=str(OUT/(name+'_preview.png'));bpy.ops.render.render(write_still=True);print('RENDERED',name,flush=True)
if __name__=='__main__':
 names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 for p in sorted(OUT.glob('*.glb')):
  if not names or p.stem in names:render(p)
