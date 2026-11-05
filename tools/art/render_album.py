"""Actual exported GLB previews, including an open-cover proof view."""
import sys,math
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2];TMP=ROOT/'art/render_work/album';TMP.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).resolve().parent));from build_slots import V,rgba

def render(name,pose='closed'):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/incoming/album'/(name+'.glb')))
    if pose=='open':
        o=bpy.data.objects['Cover'];o.matrix_basis=o.matrix_basis@Matrix.Rotation(math.radians(105),4,'Z');bpy.context.view_layer.update()
    props=[o for o in bpy.context.scene.objects if o.type=='MESH']
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True;scene.render.resolution_x=1000;scene.render.resolution_y=820;scene.render.resolution_percentage=100
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.88,.92,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.image_settings.file_format='PNG'
    if name=='album_book':
        bounds=[o.matrix_world@Vector(c) for o in bpy.context.scene.objects if o.type=='MESH' for c in o.bound_box];lo=Vector([min(v[k] for v in bounds) for k in range(3)]);hi=Vector([max(v[k] for v in bounds) for k in range(3)]);center=(lo+hi)/2;size=max(hi-lo)*(1.43 if pose=='closed' else 1.55);camdir=Vector((1.25,2.0,1.55))
        bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));floor=bpy.context.object
        m=bpy.data.materials.new('PreviewSurface');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgba('#EDEEE5');m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;floor.data.materials.append(m)
    else:center=V((0,0,-.025));size=1.35;camdir=Vector((.35,3,.30))
    for off,power,width in [((-1.5,1.8,2.4),160,2.0),((2,1,1.5),55,2.8),((0,-2,2),85,2.0)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(off)*size);o=bpy.context.object;o.data.energy=power*size*size;o.data.shape='DISK';o.data.size=width*size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.location=center+camdir.normalized()*size*4;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size
    for attempt in range(20):
        bpy.context.view_layer.update()
        points=[world_to_camera_view(scene,cam,o.matrix_world@Vector(c)) for o in props for c in o.bound_box]
        if all(.045<pt.x<.955 and .045<pt.y<.955 for pt in points):break
        cam.data.ortho_scale*=1.1
    else:raise RuntimeError('Preview camera cannot frame prop')
    scene.render.filepath=str(TMP/(name+'_'+pose+'.png'));bpy.ops.render.render(write_still=True)
for name,pose in [('album_book','closed'),('album_book','open'),('photo_board','closed')]:render(name,pose)
