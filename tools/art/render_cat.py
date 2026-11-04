"""Render final delivered GLB after reimport: neutral front / side / rear."""
import sys,math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];TMP=ROOT/'art/render_work/cat';TMP.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).resolve().parent));from build_slots import V,rgba
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/incoming/cat/cat.glb'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.render.resolution_x=700;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.80,.86,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.image_settings.file_format='PNG'
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));floor=bpy.context.object
m=bpy.data.materials.new('PreviewFloor');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgba('#E7ECEB');m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;floor.data.materials.append(m)
center=V((0,.25,.025))
for loc,power,size in [((-.7,1.0,-1.0),40,1.1),((.7,.6,-.3),12,1.2),((0,.9,.8),25,1.0)]:
    bpy.ops.object.light_add(type='AREA',location=V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=.66
for name,pos in [('front',(0,.33,-1.6)),('side',(1.6,.33,.025)),('back',(0,.33,1.6)),('hero',(.85,.61,-1.5))]:
    cam.location=V(pos);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(TMP/(name+'.png'));bpy.ops.render.render(write_still=True)
