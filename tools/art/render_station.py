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
    for z in [-3,-1,1]:put('tiles',(x,0,z),file='floor')
    for y in [0,2]:put('tiles',(x,y,1.85),True,file='wall')
for z in [-3,-1,1]:
    for y in [0,2]:
        wall=put('tiles',(-2,y,z),file='wall');wall.rotation_euler.z=math.pi/2
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.83,.9,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.9
center=V((-.10,1.00,0))
for loc,power,size in [((-2.5,2.8,-2),1100,3.5),((2,2.7,-1),220,3),((0,3.3,1.2),450,3)]:
    bpy.ops.object.light_add(type='AREA',location=V(loc));o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=V((1.25,1.70,-2.7)));cam=bpy.context.object;scene.camera=cam;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.lens=38
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'docs/art/slots_scene_preview.png');bpy.ops.render.render(write_still=True)
