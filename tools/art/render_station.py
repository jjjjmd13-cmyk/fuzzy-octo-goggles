"""Assembly preview only; imports the delivered meshes without modifying game scenes."""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
def V(p):return Vector((p[0],-p[2],p[1]))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def put(slot,position=(0,0,0),rotate=False,file=None):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/incoming'/slot/((file or slot)+'.glb')))
    objects=set(bpy.context.scene.objects)-before
    root=bpy.data.objects.new(slot+'_assembly',None);bpy.context.collection.objects.link(root)
    for o in objects:
        if o.parent is None:o.parent=root
    root.location=V(position)
    if rotate:root.rotation_euler.z=math.pi
    return root
put('tub');put('turntable',(0,.926,0));put('dog',(0,.946,0))
put('owner',(-1.25,0,-.47));put('chair',(-1.26,0,.57))
for x in [-1,1]:
    for z in [-1,1]:put('tiles',(x,0,z),file='floor')
    put('tiles',(x,0,1.85),True,file='wall')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.83,.9,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-1.3
center=V((-.15,.85,0))
for loc,power,size in [((-2,4,-3),1600,5),((3,2,-1),500,4),((0,3,1.4),600,3)]:
    bpy.ops.object.light_add(type='AREA',location=V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=V((3,3.1,-5.8)));cam=bpy.context.object;scene.camera=cam;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.45
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'docs/art/slots_scene_preview.png');bpy.ops.render.render(write_still=True)
