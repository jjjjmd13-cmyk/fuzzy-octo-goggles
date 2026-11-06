"""Render front, right, and a detail view from the exported GLBs."""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/incoming/accessory"
TMP = ROOT / "art/render_work/accessory"
TMP.mkdir(parents=True, exist_ok=True)


def vec(point):
    x, y, z = point
    return Vector((x, -z, y))


def render(asset):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(asset))
    bpy.context.view_layer.update()
    vertices = [
        obj.matrix_world @ v.co
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        for v in obj.data.vertices
    ]
    minimum = Vector([min(v[i] for v in vertices) for i in range(3)])
    maximum = Vector([max(v[i] for v in vertices) for i in range(3)])
    center = (minimum + maximum) / 2
    size = max(maximum - minimum)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 448
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.89, 0.94, 1, 1)
    background.inputs["Strength"].default_value = 0.43
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    for offset, power, width in [
        ((-2, 3, 4), 230, 2.6),
        ((2, -2, 2), 130, 2.8),
        ((3, 2, 1), 95, 2.4),
    ]:
        bpy.ops.object.light_add(type="AREA", location=center + Vector(offset) * size)
        light = bpy.context.object
        light.data.energy = power * size**2
        light.data.shape = "DISK"
        light.data.size = width * size
        light.rotation_euler = (
            (center - light.location).to_track_quat("-Z", "Y").to_euler()
        )
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.clip_start = 0.0001
    scene.camera = camera
    detail = (0.7, 0.55, -1.4)
    if asset.stem == "scarf_cape":
        detail = (0.6, 0.75, 1.5)
    elif asset.stem == "acc_basket":
        detail = (0.65, 1.7, -1.4)
    for name, direction in [
        ("front", (0, 0, -1)),
        ("side", (1, 0, 0)),
        ("detail", detail),
    ]:
        direction = vec(direction).normalized()
        orientation = (-direction).to_track_quat("-Z", "Y")
        projected = [orientation.inverted() @ v for v in vertices]
        lo = Vector([min(v[i] for v in projected) for i in range(3)])
        hi = Vector([max(v[i] for v in projected) for i in range(3)])
        camera.location = orientation @ ((lo + hi) / 2) + direction * (size * 5 + 0.01)
        camera.rotation_euler = orientation.to_euler()
        camera.data.ortho_scale = (
            max(hi.x - lo.x, hi.y - lo.y) if name == "detail" else size
        ) * 1.22
        scene.render.filepath = str(TMP / (asset.stem + "_" + name + ".png"))
        bpy.ops.render.render(write_still=True)


selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
for asset in sorted(OUT.glob("*.glb")):
    if not selected or asset.stem in selected:
        render(asset)
