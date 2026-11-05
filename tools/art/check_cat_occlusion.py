import bpy,sys,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=Path(__file__).resolve().parents[2]/'art/incoming/cat/cat.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p))
deps=bpy.context.evaluated_depsgraph_get();tongue=bpy.data.objects['Tongue'];world=tongue.matrix_world;targets=[world@v.co for v in tongue.data.vertices];hidden_by=[]
geo=[]
for o in bpy.context.scene.objects:
    if o.type=='MESH' and o!=tongue:geo.append((o,BVHTree.FromObject(o,deps)))
for target in targets:
    for angle in [-.65,0,.65]:
        # Front direction and its +/-37 degree sides, including a slight elevated camera.
        eye=target+Vector((math.sin(angle),math.cos(angle),.15))*1.0
        direction=(target-eye).normalized();best=(999,None)
        for o,bvh in geo:
            inv=o.matrix_world.inverted();a=inv@eye;d=(inv.to_3x3()@direction).normalized();hit,normal,index,dist=bvh.ray_cast(a,d,2)
            if hit is not None:
                world_hit=o.matrix_world@hit;distance=(world_hit-eye).length
                if distance<best[0]:best=(distance,o.name)
        assert best[0]<(target-eye).length-.0001,('Visible tongue point',tuple(target),angle,best)
        hidden_by.append(best[1])
print('CAT_TONGUE_OCCLUSION_PASS',len(targets)*3,'rays; neutral tongue fully behind muzzle from front cameras')
