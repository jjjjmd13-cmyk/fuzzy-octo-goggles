"""Render the exported GLBs, not a second approximation. Blender 4.5 CPU Cycles."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
TMP=ROOT/'art/render_work';TMP.mkdir(parents=True,exist_ok=True)
def V(p):return Vector((p[0],-p[2],p[1]))
def material(name,col):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m

def render(slot,filename=None,view='hero'):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    p=ROOT/'art/incoming'/slot/((filename or slot)+'.glb')
    bpy.ops.import_scene.gltf(filepath=str(p))
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
    scene.cycles.use_denoising=True;scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.83,.9,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=.45;scene.render.image_settings.file_format='PNG'
    bounds=[]
    for o in scene.objects:
        if o.type=='MESH':bounds.extend(o.matrix_world@Vector(c) for c in o.bound_box)
    low=Vector([min(v[k] for v in bounds) for k in range(3)]);high=Vector([max(v[k] for v in bounds) for k in range(3)])
    center=(low+high)/2;size=max(high-low)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,low.z-.002));plane=bpy.context.object;plane.name='PreviewGround';plane.data.materials.append(material('PreviewGround',(.88,.91,.89)))
    if slot=='turntable':center.z=0
    if slot=='tiles' and filename=='wall':center.z=1
    def area(name,loc,power,width):
        bpy.ops.object.light_add(type='AREA',location=center+Vector(loc)*size);l=bpy.context.object;l.name=name;l.data.energy=power*size*size;l.data.shape='DISK';l.data.size=width*size;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
    area('Key',(-2.2, 3,4),500,3);area('Fill',(3,1,2),120,3);area('Rim',(1,-3,3),200,3)
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam
    if view=='front':direction=Vector((0,3,.4))
    elif view=='back':direction=Vector((-2,-3,1.3))
    else:direction=Vector((1.9,3.6,1.8))
    if slot in ['turntable','tiles'] and filename!='wall':direction=Vector((1.5,-2.5,3.5))
    if slot=='tiles' and filename=='wall':direction=Vector((1.5,-3.6,1.8))
    cam.location=center+direction.normalized()*size*4;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.3;cam.data.lens=50
    if slot=='owner':cam.data.ortho_scale=size*1.18
    if slot=='tiles' and filename=='floor':cam.data.ortho_scale=size*1.65
    scene.render.filepath=str(TMP/(slot+'_'+(filename or slot)+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
if __name__=='__main__':
    a=sys.argv[sys.argv.index('--')+1:]
    if a[0]=='all':
        for view in ['hero','front','back']:render('dog',view=view)
        for slot in ['owner','tub','turntable','chair']:render(slot)
        render('tiles','floor');render('tiles','wall')
    elif a[0]=='dog':
        for view in ['hero','front','back']:render('dog',view=view)
    elif a[0]=='tiles':
        render('tiles','floor');render('tiles','wall')
    else:render(a[0])
