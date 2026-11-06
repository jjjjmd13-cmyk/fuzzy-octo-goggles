"""Original toy accessories. Run with Blender 4.2+ from the repository."""

import math
import struct
import sys
import zlib
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_slots as B

OUT = B.ROOT / "art/incoming/accessory"
COLORS = {
    "pink": "FF9EC4",
    "rose": "E784AD",
    "blue": "8FD3F4",
    "sky": "6CBBDD",
    "mint": "B8E3D3",
    "mint_dark": "82C4AF",
    "butter": "FFF1C9",
    "yellow": "FFD97A",
    "red": "FF6B6B",
    "wood": "E8C9A0",
    "white": "FFFFFF",
    "pearl": "FFF9ED",
    "gold": "EABC58",
    "gold_light": "FFE18D",
    "gold_dark": "C58A35",
    "lilac": "BCAAF0",
    "blush": "F5A0A6",
    "wicker": "CEA574",
}
PARTS = []


def add(name, vertices, faces, color, uv=None):
    obj = B.mesh(name, vertices, faces, None)
    # All closed shells use outward normals. Cloth sheets are double sided.
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    PARTS.append((obj, color, uv))
    return obj


def ball(name, center, scale, color, segments=12, rings=6):
    obj = B.uvball(name, center, scale, None, seg=segments, rings=rings)
    PARTS.append((obj, color, None))
    return obj


def rounded(points, fraction=0.20, steps=3):
    if steps == 1:
        return points
    result = []
    for i, b in enumerate(points):
        a = b + (points[i - 1] - b) * fraction
        c = b + (points[(i + 1) % len(points)] - b) * fraction
        for t in np.linspace(0, 1, steps):
            result.append((1 - t) ** 2 * a + 2 * t * (1 - t) * b + t * t * c)
    return np.array(result)


def pillow(name, points, depth, color, mapping=None, steps=3):
    """Domed shape from a planar outline. Depth is along model Z."""
    outline = rounded(np.asarray(points, dtype=float), steps=steps)
    center = outline.mean(0)
    n = len(outline)
    vertices = []
    faces = []
    for scale, z in [(0.83, -0.50), (1, 0), (0.83, 0.50)]:
        ring = center + (outline - center) * scale
        ring[:, 2] += depth * z
        vertices.extend(ring)
    for i in range(2):
        for j in range(n):
            a, b = i * n + j, i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    faces += [tuple(reversed(range(n))), tuple(2 * n + j for j in range(n))]
    uv = [mapping(v) for v in vertices] if mapping else None
    return add(name, vertices, faces, color, uv)


def lathe(name, profile, color, n=24, close=False, transform=None):
    verts = []
    for radius, y in profile:
        for j in range(n):
            a = math.tau * j / n
            point = (radius * math.cos(a), y, radius * math.sin(a))
            verts.append(transform(point) if transform else point)
    faces = []
    for i in range(len(profile) if close else len(profile) - 1):
        k = (i + 1) % len(profile)
        for j in range(n):
            q = (j + 1) % n
            faces.append((i * n + j, i * n + q, k * n + q, k * n + j))
    if not close:
        faces.extend(
            [
                tuple(reversed(range(n))),
                tuple((len(profile) - 1) * n + j for j in range(n)),
            ]
        )
    return add(name, verts, faces, color)


def star(name, x, y, z, radius, depth, color="gold_light", steps=2, turn=0):
    points = []
    for i in range(10):
        a = math.pi / 2 + turn + i * math.pi / 5
        r = radius * (1 if i % 2 == 0 else 0.49)
        points.append((x + r * math.cos(a), y + r * math.sin(a), z))
    return pillow(name, points, depth, color, steps=steps)


def ribbon(tier):
    color = ["pink", "polka", "gold"][tier - 1]
    reach = [0.052, 0.054, 0.061][tier - 1]
    rise = [0.039, 0.042, 0.049][tier - 1]
    tail = [0.014, 0.027, 0.025][tier - 1]

    def map_dot(v):
        return (v[0] / 0.126 + 0.5, (v[1] + 0.034) / 0.09)

    mapping = map_dot if tier == 2 else None
    for s in [-1, 1]:
        pillow(
            "Tail",
            [
                (s * 0.005, 0.012, -0.002),
                (s * 0.018, 0.011, -0.003),
                (s * 0.033, -tail, -0.023),
                (s * 0.022, -tail + 0.004, -0.022),
                (s * 0.017, -tail - 0.002, -0.023),
                (s * 0.009, -0.006, -0.010),
            ],
            0.004,
            color,
            mapping,
        )
        pillow(
            "Loop",
            [
                (s * 0.005, 0.013, -0.003),
                (s * 0.020, 0.031, -0.001),
                (s * (reach - 0.006), rise, 0),
                (s * reach, 0.026, 0.003),
                (s * (reach - 0.003), 0.007, 0.001),
                (s * 0.023, 0.004, -0.001),
            ],
            0.013 if tier < 3 else 0.020,
            color,
            mapping,
        )
        if tier == 3:
            pillow(
                "Fold",
                [
                    (s * 0.008, 0.014, -0.011),
                    (s * 0.027, 0.026, -0.014),
                    (s * 0.045, 0.028, -0.013),
                    (s * 0.030, 0.017, -0.015),
                ],
                0.0035,
                "gold_light",
                steps=1,
            )
    knot_color = ["rose", "sky", "gold_dark"][tier - 1]
    ball("Knot", (0, 0.012, -0.006), (0.010, 0.012, 0.009), knot_color, 12, 5)
    if tier == 3:
        ball("Pearl", (0, 0.015, -0.017), (0.007, 0.007, 0.006), "pearl", 12, 5)


def party():
    bands = [
        (0, 0.047),
        (0.006, 0.050),
        (0.019, 0.044),
        (0.036, 0.036),
        (0.054, 0.028),
        (0.072, 0.021),
        (0.089, 0.013),
        (0.105, 0.005),
    ]
    obj = lathe("PartyCone", [(r, y) for y, r in bands], "pink", n=24)
    obj["stripe_profile"] = True
    ball("PomPom", (0, 0.110, 0), (0.012, 0.012, 0.012), "butter", 12, 6)


def beret():
    lathe(
        "HeadBand",
        [(0.045, 0), (0.049, 0.003), (0.049, 0.014), (0.046, 0.017)],
        "mint_dark",
        n=24,
    )

    def tilt(p):
        x, y, z = p
        return (x + 0.011 * (y / 0.055), y + 0.14 * x + 0.04 * z, z)

    lathe(
        "SoftCap",
        [
            (0.038, 0.012),
            (0.058, 0.017),
            (0.068, 0.025),
            (0.070, 0.034),
            (0.063, 0.043),
            (0.044, 0.050),
            (0.014, 0.051),
        ],
        "mint",
        n=24,
        transform=tilt,
    )
    ball("Stem", (0.016, 0.054, -0.002), (0.006, 0.010, 0.006), "mint", 10, 5)


def crown():
    n = 42
    vertices = []
    for layer in range(6):
        for j in range(n):
            a = math.tau * j / n - math.pi / 2
            peak = [1, 0.76, 0.37, 0.12, 0.12, 0.37, 0.76][j % 7]
            top = 0.030 + 0.033 * peak
            r, y = [
                (0.043, 0),
                (0.050, 0.007),
                (0.048, 0.020),
                (0.049, top),
                (0.043, top - 0.003),
                (0.039, 0.005),
            ][layer]
            vertices.append((r * math.cos(a), y, r * math.sin(a)))
    faces = []
    for i in range(6):
        k = (i + 1) % 6
        for j in range(n):
            q = (j + 1) % n
            faces.append((i * n + j, i * n + q, k * n + q, k * n + j))
    obj = add("Crown", vertices, faces, "gold")
    obj["crown_bands"] = True
    for i in range(6):
        a = math.tau * i / 6 - math.pi / 2
        center = np.array((0.050 * math.cos(a), 0.057, 0.050 * math.sin(a)))
        tangent = np.array((-math.sin(a), 0, math.cos(a)))
        radial = np.array((math.cos(a), 0, math.sin(a)))
        up = np.array((0, 1, 0))
        v = [
            center + axis * size
            for axis, size in [
                (up, 0.008),
                (-up, 0.008),
                (tangent, 0.006),
                (-tangent, 0.006),
                (radial, 0.005),
                (-radial, 0.004),
            ]
        ]
        gem = add(
            "Gem",
            v,
            [
                (0, 2, 4),
                (0, 4, 3),
                (0, 3, 5),
                (0, 5, 2),
                (1, 4, 2),
                (1, 3, 4),
                (1, 5, 3),
                (1, 2, 5),
            ],
            "pink" if i % 2 == 0 else "blue",
        )
        for face in gem.data.polygons:
            face.use_smooth = False


def collar(color, segments=32):
    lathe(
        "NeckRing",
        [
            (0.080, -0.013),
            (0.086, -0.018),
            (0.094, -0.010),
            (0.094, 0.010),
            (0.087, 0.017),
            (0.080, 0.012),
        ],
        color,
        n=segments,
        close=True,
    )


def mint_scarf():
    collar("mint")
    ball("Knot", (0, -0.002, -0.094), (0.019, 0.014, 0.014), "mint_dark", 12, 5)
    for s in [-1, 1]:
        pillow(
            "ShortTie",
            [
                (s * 0.005, -0.005, -0.100),
                (s * 0.016, -0.003, -0.101),
                (s * 0.032, -0.030, -0.103),
                (s * 0.022, -0.027, -0.104),
                (s * 0.014, -0.034, -0.105),
            ],
            0.006,
            "mint",
            steps=2,
        )


def bandana():
    collar("red")
    outline = [
        (-0.072, 0.005, -0.065),
        (-0.037, 0.009, -0.092),
        (0, 0.005, -0.100),
        (0.037, 0.009, -0.092),
        (0.072, 0.005, -0.065),
        (0.048, -0.043, -0.089),
        (0, -0.106, -0.116),
        (-0.048, -0.043, -0.089),
    ]
    pillow(
        "CheckedCloth",
        outline,
        0.006,
        "check",
        lambda v: (v[0] / 0.160 + 0.5, (v[1] + 0.112) / 0.13),
    )
    ball("FoldButton", (0, 0.003, -0.101), (0.012, 0.008, 0.006), "red", 10, 4)


def cape():
    collar("blue", segments=20)
    # A curved double-sided drape. The hem wraps the rear flank and drops below the neck.
    verts = []
    n = 13
    for i in range(5):
        t = i / 4
        for j in range(n):
            s = j / (n - 1) * 2 - 1
            x = s * (0.064 + 0.060 * t)
            z = 0.064 + 0.100 * t - 0.030 * s * s * (1 - t)
            y = -0.007 - 0.119 * t + 0.028 * s * s * t
            verts.append((x, y, z))
    faces = []
    for i in range(4):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + 1, a + n + 1, a + n))
    add("CapeCloth", verts, faces, "blue")
    edge = verts[-n:]
    trim = B.tube("GoldHem", edge, [0.0035] * len(edge), None, n=5)
    PARTS.append((trim, "gold", None))
    for x in [-0.078, 0, 0.078]:
        t = 0.84
        s = x / (0.064 + 0.060 * t)
        y = -0.007 - 0.119 * t + 0.028 * s * s * t + 0.0015
        z = 0.064 + 0.100 * t - 0.030 * s * s * (1 - t) + 0.0015
        # Decor lies flat on the sloping exterior (+Y,+Z) face.
        obj = star("HemStar", x, y, z, 0.0125, 0.0035, "gold_light", steps=1)
        center = B.V((x, y, z))
        for v in obj.data.vertices:
            d = v.co - center
            d.y += d.z * 0.78
            v.co = center + d
    ball("FrontKnot", (0, -0.004, -0.094), (0.014, 0.011, 0.012), "gold", 10, 4)
    for s in [-1, 1]:
        pillow(
            "FrontTie",
            [
                (s * 0.003, -0.005, -0.101),
                (s * 0.011, -0.004, -0.102),
                (s * 0.023, -0.026, -0.108),
                (s * 0.011, -0.024, -0.105),
            ],
            0.004,
            "blue",
            steps=2,
        )


def clip():
    ball("Clip", (0, 0, 0.002), (0.015, 0.0035, 0.004), "gold_dark", 8, 3)


def daisy():
    clip()
    for i in range(7):
        a = math.tau * i / 7
        x, y = 0.0155 * math.cos(a), 0.0155 * math.sin(a)
        obj = ball("Petal", (x, y, -0.004), (0.010, 0.007, 0.004), "white", 10, 5)
        obj.rotation_euler.y = -a
    ball("FlowerCenter", (0, 0, -0.008), (0.010, 0.010, 0.005), "yellow", 12, 6)


def star_pin():
    clip()
    star("PuffyStar", 0, 0, -0.005, 0.028, 0.010, "yellow", steps=3, turn=0.08)
    ball("SoftGlint", (-0.007, 0.010, -0.010), (0.005, 0.0027, 0.0015), "butter", 8, 3)


def rainbow_pin():
    clip()
    for k, color in enumerate(["pink", "yellow", "mint", "blue", "lilac"]):
        outer = 0.0245 - k * 0.0034
        inner = outer - 0.0035
        verts = []
        for j in range(12):
            a = math.pi * j / 11
            for r, z in [
                (outer, -0.008),
                (inner, -0.008),
                (inner, -0.003),
                (outer, -0.003),
            ]:
                verts.append((r * math.cos(a), -0.006 + r * math.sin(a), z))
        faces = []
        for j in range(11):
            for k2 in range(4):
                a = j * 4 + k2
                b = j * 4 + (k2 + 1) % 4
                faces.append((a, b, b + 4, a + 4))
        faces += [(3, 2, 1, 0), (44, 45, 46, 47)]
        add("RainbowArc", verts, faces, color)
    for s in [-1, 1]:
        for x, y, r in [
            (s * 0.019, -0.007, 0.008),
            (s * 0.025, -0.010, 0.0055),
            (s * 0.013, -0.010, 0.0055),
        ]:
            ball("CloudPuff", (x, y, -0.008), (r, r * 0.74, 0.0045), "white", 8, 4)
    # Keep the wide cloud silhouette close to the other 5 cm pins.
    for obj, _, _ in PARTS:
        obj.location *= 0.89
        for vertex in obj.data.vertices:
            vertex.co *= 0.89


def basket():
    # One continuous open shell with a pink liner. No face spans the mouth.
    n = 24
    verts = []
    profile = [
        (0.144, 0.097, 0, 0.028),
        (0.153, 0.105, 0.010, 0.030),
        (0.170, 0.121, 0.112, 0.033),
        (0.175, 0.125, 0.138, 0.034),
        (0.172, 0.122, 0.150, 0.034),
        (0.159, 0.110, 0.149, 0.033),
        (0.153, 0.103, 0.137, 0.032),
        (0.141, 0.091, 0.027, 0.029),
        (0.133, 0.083, 0.022, 0.027),
    ]
    for hx, hz, y, r in profile:
        for k in range(4):
            a0 = k * math.pi / 2
            cx = math.copysign(hx - r, math.cos(a0 + math.pi / 4))
            cz = math.copysign(hz - r, math.sin(a0 + math.pi / 4))
            for a in np.linspace(a0, a0 + math.pi / 2, 6):
                verts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    faces = []
    for i in range(len(profile) - 1):
        for j in range(n):
            q = (j + 1) % n
            faces.append((i * n + j, i * n + q, (i + 1) * n + q, (i + 1) * n + j))
    faces += [
        tuple(reversed(range(n))),
        tuple((len(profile) - 1) * n + j for j in range(n)),
    ]
    obj = add("OpenLinedBasket", verts, faces, "wood")
    obj["basket"] = True
    ring = np.asarray(verts[2 * n : 3 * n])
    lengths = np.linalg.norm(np.roll(ring, -1, axis=0) - ring, axis=1)
    obj["basket_u"] = (np.r_[0, np.cumsum(lengths)] / sum(lengths)).tolist()


def write_png(path, pixels):
    height, width, _ = pixels.shape

    def chunk(kind, data):
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    scan = b"".join(b"\0" + row.tobytes() for row in pixels)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(scan, 9))
        + chunk(b"IEND", b"")
    )


def palette(name):
    pixels = np.zeros((512, 512, 3), dtype=np.uint8)
    names = list(COLORS)
    rgb = lambda key: tuple(bytes.fromhex(COLORS[key]))
    for i, key in enumerate(names):
        pixels[:32, i * 24 : (i + 1) * 24] = rgb(key)
    y, x = np.mgrid[:448, :480]
    if name == "ribbon_polka":
        dx = (x + (y // 56 % 2) * 28) % 56 - 28
        dy = y % 56 - 28
        pattern = np.where(
            (dx * dx + dy * dy < 11 * 11)[:, :, None], rgb("white"), rgb("blue")
        )
    elif name == "scarf_bandana":
        k = (x // 58 % 2) + (y // 58 % 2)
        pattern = np.asarray([rgb("white"), rgb("blush"), rgb("red")])[k]
    elif name == "acc_basket":
        row = y // 40
        block = (x + (row % 2) * 15) % 30
        seam = (y % 40 < 3) | (block < 3)
        pattern = np.where(
            seam[:, :, None],
            rgb("wicker"),
            np.where((row % 2 == 0)[:, :, None], rgb("wood"), (231, 195, 151)),
        )
    else:
        pattern = np.zeros((448, 480, 3), dtype=np.uint8)
    pixels[64:512, 16:496] = pattern
    path = OUT / "_palette.png"
    write_png(path, pixels)
    im = bpy.data.images.load(str(path))
    im.name = name + "_CleanColor"
    im.pack()
    material = B.mat("AccessoryCleanColor", "#FFFFFF", 0.75)
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = im
    material.node_tree.links.new(
        node.outputs["Color"],
        material.node_tree.nodes["Principled BSDF"].inputs["Base Color"],
    )

    def flat(key):
        return ((names.index(key) * 24 + 12) / 512, 1 - 16 / 512)

    def pattern_uv(x, y):
        return (
            (17 + 478 * min(1, max(0, x))) / 512,
            1 - (65 + 446 * min(1, max(0, y))) / 512,
        )

    for obj, key, uv in PARTS:
        obj.data.materials.append(material)
        layer = obj.data.uv_layers.new(name="ColorUV")
        for p in obj.data.polygons:
            color = key
            if obj.get("stripe_profile"):
                color = "pink" if (p.index // 24) % 2 == 0 else "butter"
            if obj.get("crown_bands"):
                color = {
                    0: "gold_dark",
                    1: "gold_light",
                    2: "gold",
                    3: "gold_light",
                    4: "gold",
                    5: "gold_dark",
                }[p.index // 42]
            for li in p.loop_indices:
                vi = obj.data.loops[li].vertex_index
                if uv is not None:
                    coord = pattern_uv(*uv[vi])
                elif obj.get("basket") and p.index < 24 * 3:
                    j = vi % 24
                    if p.index % 24 == 23 and j == 0:
                        j = 24
                    coord = pattern_uv(obj["basket_u"][j], (vi // 24) / 3)
                elif obj.get("basket"):
                    coord = flat(
                        "pink"
                        if 24 * 4 <= p.index < 24 * 8 or p.index == 193
                        else "wood"
                    )
                else:
                    coord = flat(color)
                layer.data[li].uv = coord
    return path


def export(name, build):
    B.reset()
    PARTS.clear()
    build()
    tmp = palette(name)
    root = B.empty("AccessoryRoot")
    for obj, _, _ in PARTS:
        matrix = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = matrix
    bpy.context.view_layer.update()
    total = sum(
        sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj, _, _ in PARTS
    )
    if total > 800:
        raise RuntimeError(f"{name}: {total} triangles")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / (name + ".glb")),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=False,
        export_lights=False,
        export_cameras=False,
        export_normals=True,
        export_texcoords=True,
    )
    tmp.unlink()
    print("ACCESSORY", name, total, flush=True)


BUILDS = {
    "ribbon_pink": lambda: ribbon(1),
    "ribbon_polka": lambda: ribbon(2),
    "ribbon_gold": lambda: ribbon(3),
    "hat_party": party,
    "hat_beret": beret,
    "hat_crown": crown,
    "scarf_mint": mint_scarf,
    "scarf_bandana": bandana,
    "scarf_cape": cape,
    "pin_daisy": daisy,
    "pin_star": star_pin,
    "pin_rainbow": rainbow_pin,
    "acc_basket": basket,
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else BUILDS
    for name in names:
        export(name, BUILDS[name])
