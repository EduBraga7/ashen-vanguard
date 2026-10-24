"""
Ashen Vanguard - gerador procedural de modelos Low-Poly (Blender 5.2 -> Godot 4.7).

Gera e exporta .glb para res://assets/models/ :
    knight_player, enemy_skeleton, enemy_bat, boss_renegade_knight,
    gem_blue, gem_green, gem_red, battle_axe, fire_flask, roast_meat, treasure_chest,
    ruin_pillar, rubble_pile

Uso (linha de comando, headless):
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup ^
        --python tools/blender/generate_models.py -- "C:\\caminho\\ashen-vanguard\\assets\\models"

Uso (Blender MCP): cole este arquivo inteiro em `execute_blender_code`. Sem argumentos,
os arquivos vao para OUT_DIR_DEFAULT.

Convencoes:
  * Escala em metros. Humanos: 1.80 m = 7.5 cabecas (cabeca = 0.24 m).
  * A FRENTE do modelo aponta para -Y no Blender, o que vira +Z no Godot
    (o projeto rotaciona o visual com atan2(dir.x, dir.z)).
  * Pivos de animacao procedural (LegL, LegR, ArmL, ArmR, WingL, WingR) sao Empties
    posicionados na articulacao; o Godot os rotaciona em tempo de execucao.
  * Sombreamento flat (facetado), poucas cores sobrias, emissao so em detalhes (visor, olhos, gemas).
"""
import math
import os
import random
import sys

import bmesh
import bpy

OUT_DIR_DEFAULT = r"C:\Users\du-xb\Documents\games\ashen-vanguard\assets\models"


def _out_dir() -> str:
    if "--" in sys.argv:
        extra = sys.argv[sys.argv.index("--") + 1:]
        if extra:
            return extra[0]
    return OUT_DIR_DEFAULT


# --------------------------------------------------------------------------- materiais
def srgb(r, g, b, a=1.0):
    """Converte cor sRGB (como na paleta do GDD) para linear, que e o que o Blender/glTF esperam."""
    def f(c):
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    return (f(r), f(g), f(b), a)


# nome: (rgb sRGB, metallic, roughness, emissao rgb | None, forca da emissao)
PALETTE = {
    "plate":      ((0.46, 0.49, 0.55), 0.65, 0.42, None, 0.0),
    "dark_iron":  ((0.15, 0.16, 0.19), 0.70, 0.50, None, 0.0),
    "chain":      ((0.27, 0.29, 0.33), 0.55, 0.65, None, 0.0),
    "leather":    ((0.26, 0.16, 0.10), 0.00, 0.85, None, 0.0),
    "cape_red":   ((0.50, 0.09, 0.10), 0.00, 0.90, None, 0.0),
    "gold":       ((0.80, 0.62, 0.22), 0.80, 0.40, None, 0.0),
    "visor_glow": ((1.00, 0.80, 0.20), 0.00, 0.50, (1.0, 0.75, 0.15), 6.0),
    # Cavaleiro Renegado
    "boss_plate": ((0.27, 0.27, 0.33), 0.55, 0.55, None, 0.0),
    "boss_rust":  ((0.38, 0.19, 0.10), 0.40, 0.70, None, 0.0),
    "boss_cape":  ((0.14, 0.04, 0.05), 0.00, 0.95, None, 0.0),
    "boss_glow":  ((1.00, 0.15, 0.08), 0.00, 0.50, (1.0, 0.10, 0.05), 7.0),
    # Esqueleto
    "bone":       ((0.66, 0.62, 0.52), 0.00, 0.75, None, 0.0),
    "bone_dark":  ((0.30, 0.27, 0.22), 0.00, 0.85, None, 0.0),
    "rust":       ((0.40, 0.24, 0.14), 0.45, 0.65, None, 0.0),
    "cloth":      ((0.22, 0.17, 0.12), 0.00, 0.95, None, 0.0),
    "eye_red":    ((1.00, 0.15, 0.10), 0.00, 0.50, (1.0, 0.12, 0.06), 3.5),
    # Morcego
    "bat_fur":    ((0.17, 0.13, 0.20), 0.00, 0.90, None, 0.0),
    "bat_wing":   ((0.30, 0.13, 0.20), 0.00, 0.85, None, 0.0),
    "fang":       ((0.90, 0.88, 0.80), 0.00, 0.60, None, 0.0),
    # Drops
    "gem_blue":   ((0.25, 0.80, 1.00), 0.00, 0.25, (0.15, 0.75, 1.0), 3.5),
    "gem_green":  ((0.10, 0.90, 0.45), 0.00, 0.25, (0.05, 0.90, 0.35), 3.5),
    "gem_red":    ((0.95, 0.10, 0.20), 0.00, 0.25, (1.00, 0.05, 0.12), 3.5),
    "wood":       ((0.30, 0.18, 0.10), 0.00, 0.85, None, 0.0),
    "steel":      ((0.62, 0.65, 0.70), 0.75, 0.35, None, 0.0),
    "glass_dark": ((0.12, 0.14, 0.14), 0.30, 0.30, None, 0.0),
    "fire_liquid": ((1.00, 0.45, 0.08), 0.00, 0.30, (1.0, 0.40, 0.05), 4.0),
    "cork":       ((0.45, 0.30, 0.16), 0.00, 0.90, None, 0.0),
    "ember":      ((1.00, 0.55, 0.10), 0.00, 0.50, (1.0, 0.45, 0.05), 6.0),
    "meat":       ((0.55, 0.24, 0.10), 0.00, 0.60, None, 0.0),
    "meat_char":  ((0.22, 0.09, 0.04), 0.00, 0.80, None, 0.0),
    "chest_gold": ((0.95, 0.72, 0.20), 0.85, 0.35, (0.9, 0.55, 0.1), 0.8),
    # Cenario
    "masonry":    ((0.30, 0.32, 0.37), 0.00, 0.90, None, 0.0),
    "masonry_dk": ((0.20, 0.22, 0.26), 0.00, 0.92, None, 0.0),
}


def M(key: str):
    """Material lazy-criado a partir da PALETTE."""
    existing = bpy.data.materials.get(key)
    if existing:
        return existing
    rgb, metallic, roughness, emit, strength = PALETTE[key]
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True  # deprecado no 5.x (sempre True), inofensivo
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = srgb(*rgb)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit:
        bsdf.inputs["Emission Color"].default_value = srgb(*emit)
        bsdf.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = srgb(*rgb)
    return m


# --------------------------------------------------------------------------- primitivas
def _finish(name, verts, faces, mat, parent, loc, rot):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if hasattr(me, "shade_flat"):
        me.shade_flat()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(M(mat))
    ob.location = loc
    ob.rotation_euler = rot
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    if parent is not None:
        ob.parent = parent
    return ob


def frustum(name, bottom, top, h, loc, mat, parent=None, rot=(0, 0, 0), top_shift=(0, 0)):
    """Tronco de piramide de base retangular: bottom=(w,d), top=(w,d), centrado no pivo."""
    bw, bd = bottom[0] / 2, bottom[1] / 2
    tw, td = top[0] / 2, top[1] / 2
    sx, sy = top_shift
    z0, z1 = -h / 2, h / 2
    v = [(-bw, -bd, z0), (bw, -bd, z0), (bw, bd, z0), (-bw, bd, z0),
         (-tw + sx, -td + sy, z1), (tw + sx, -td + sy, z1), (tw + sx, td + sy, z1), (-tw + sx, td + sy, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return _finish(name, v, f, mat, parent, loc, rot)


def box(name, size, loc, mat, parent=None, rot=(0, 0, 0)):
    return frustum(name, (size[0], size[1]), (size[0], size[1]), size[2], loc, mat, parent, rot)


def cyl(name, rb, rt, h, sides, loc, mat, parent=None, rot=(0, 0, 0), sxy=(1.0, 1.0), spin=0.0):
    """Cilindro/cone facetado (rt pequeno = cone). Eixo = Z local, centrado no pivo."""
    v = []
    for z, r in ((-h / 2, rb), (h / 2, rt)):
        for i in range(sides):
            a = spin + 2 * math.pi * i / sides
            v.append((math.cos(a) * r * sxy[0], math.sin(a) * r * sxy[1], z))
    f = []
    for i in range(sides):
        j = (i + 1) % sides
        f.append((i, j, sides + j, sides + i))
    f.append(tuple(reversed(range(sides))))
    f.append(tuple(range(sides, 2 * sides)))
    return _finish(name, v, f, mat, parent, loc, rot)


def ico(name, r, loc, mat, parent=None, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=2):
    bm = bmesh.new()
    try:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    except TypeError:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, diameter=r)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    v = [(p.co.x * scale[0], p.co.y * scale[1], p.co.z * scale[2]) for p in bm.verts]
    f = [tuple(p.index for p in face.verts) for face in bm.faces]
    bm.free()
    return _finish(name, v, f, mat, parent, loc, rot)


def slab(name, points, thickness, axes, loc, mat, parent=None, rot=(0, 0, 0), mirror=False):
    """
    Poligono 2D (estrelado em relacao ao centroide) extrudado com espessura.
    axes: 'XY' (espessura em Z), 'YZ' (espessura em X) ou 'XZ' (espessura em -Y).
    """
    basis = {
        "XY": ((1, 0, 0), (0, 1, 0)),
        "YZ": ((0, 1, 0), (0, 0, 1)),
        "XZ": ((1, 0, 0), (0, 0, 1)),
    }[axes]
    eu, ev = basis
    en = (eu[1] * ev[2] - eu[2] * ev[1], eu[2] * ev[0] - eu[0] * ev[2], eu[0] * ev[1] - eu[1] * ev[0])
    pts = [(-u if mirror else u, w) for u, w in points]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:
        pts.reverse()
    n = len(pts)
    cu = sum(p[0] for p in pts) / n
    cv = sum(p[1] for p in pts) / n
    t = thickness / 2

    def vert(u, w, s):
        return tuple(u * eu[k] + w * ev[k] + s * t * en[k] for k in range(3))

    v = [vert(u, w, +1) for u, w in pts] + [vert(u, w, -1) for u, w in pts]
    v.append(vert(cu, cv, +1))  # centro topo
    v.append(vert(cu, cv, -1))  # centro base
    ct, cb = 2 * n, 2 * n + 1
    f = []
    for i in range(n):
        j = (i + 1) % n
        f.append((ct, i, j))             # topo (normal +en)
        f.append((cb, n + j, n + i))     # base (normal -en)
        f.append((i, n + i, n + j, j))   # lateral
    return _finish(name, v, f, mat, parent, loc, rot)


def octahedron(name, half_w, half_h, loc, mat, parent=None):
    v = [(0, 0, half_h), (0, 0, -half_h),
         (half_w, 0, 0), (0, half_w, 0), (-half_w, 0, 0), (0, -half_w, 0)]
    f = [(0, 2, 3), (0, 3, 4), (0, 4, 5), (0, 5, 2), (1, 3, 2), (1, 4, 3), (1, 5, 4), (1, 2, 5)]
    return _finish(name, v, f, mat, parent, loc, (0, 0, 0))


# --------------------------------------------------------------------------- export
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def export(filename):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.join(_out_dir(), filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("[ashen] exportado %s (%d poligonos)" % (path, tris))


# --------------------------------------------------------------------------- humanoides
def build_knight(boss=False):
    """Cavaleiro de placas sobre cota de malha. boss=True gera o Cavaleiro Renegado."""
    plate = "boss_plate" if boss else "plate"
    trim = "boss_rust" if boss else "gold"
    cape = "boss_cape" if boss else "cape_red"
    glow = "boss_glow" if boss else "visor_glow"
    iron = "dark_iron"
    chain = "chain"

    root = empty("Root")

    # --- Pernas (pivo no quadril, z = 0.93)
    for side, sx in (("L", 1), ("R", -1)):
        leg = empty("Leg" + side, (0.095 * sx, 0, 0.93), root)
        frustum("Thigh" + side, (0.13, 0.14), (0.17, 0.18), 0.42, (0, 0, -0.21), chain, leg)
        frustum("Knee" + side, (0.10, 0.07), (0.13, 0.05), 0.10, (0, -0.07, -0.45), plate, leg)
        frustum("Greave" + side, (0.10, 0.11), (0.14, 0.15), 0.36, (0, 0, -0.63), plate, leg)
        frustum("Boot" + side, (0.12, 0.28), (0.13, 0.22), 0.12, (0, -0.05, -0.87), iron, leg)

    # --- Quadril, cinto e torso
    frustum("Tasset", (0.44, 0.27), (0.36, 0.22), 0.24, (0, 0, 0.90), chain, root)
    box("Belt", (0.38, 0.24, 0.06), (0, 0, 1.02), "leather", root)
    box("Buckle", (0.07, 0.02, 0.06), (0, -0.125, 1.02), trim, root)
    frustum("TorsoMail", (0.35, 0.21), (0.41, 0.23), 0.46, (0, 0, 1.25), chain, root)
    frustum("Breastplate", (0.31, 0.10), (0.39, 0.12), 0.38, (0, -0.10, 1.29), plate, root)
    box("BreastRidge", (0.035, 0.035, 0.34), (0, -0.165, 1.29), iron, root)
    frustum("Backplate", (0.33, 0.06), (0.37, 0.06), 0.36, (0, 0.12, 1.29), plate, root)
    cyl("Gorget", 0.075, 0.07, 0.09, 8, (0, 0, 1.53), iron, root)

    # --- Ombreiras angulares (escalonadas, com espinho)
    for side, sx in (("L", 1), ("R", -1)):
        roll = 0.38 * sx
        frustum("PauldronTop" + side, (0.20, 0.19), (0.24, 0.22), 0.07, (0.275 * sx, 0, 1.49), plate, root, (0, roll, 0))
        frustum("PauldronLow" + side, (0.16, 0.15), (0.20, 0.18), 0.05, (0.30 * sx, 0, 1.43), plate, root, (0, roll, 0))
        spike_h = 0.16 if boss else 0.08
        cyl("PauldronSpike" + side, 0.04 if boss else 0.03, 0.008, spike_h, 4, (0.30 * sx, 0, 1.53 + spike_h / 2), trim, root,
            (0, roll, 0))

    # --- Bracos (pivo no ombro)
    for side, sx in (("L", 1), ("R", -1)):
        arm = empty("Arm" + side, (0.265 * sx, 0, 1.45), root, (0, -0.10 * sx, 0))
        box("UpperArm" + side, (0.09, 0.09, 0.28), (0, 0, -0.15), chain, arm)
        frustum("Elbow" + side, (0.10, 0.10), (0.12, 0.12), 0.08, (0, 0.01, -0.31), plate, arm)
        frustum("Vambrace" + side, (0.08, 0.08), (0.10, 0.10), 0.26, (0, 0, -0.46), plate, arm)
        box("Gauntlet" + side, (0.09, 0.10, 0.10), (0, 0, -0.63), iron, arm)
        if boss and side == "R":
            # Montante gigante: lamina apontada para a frente (-Y), empunhada na mao direita
            box("SwordGrip", (0.04, 0.04, 0.16), (0, 0, -0.63), "leather", arm, (0, 0, 0))
            box("SwordGuard", (0.30, 0.05, 0.05), (0, -0.04, -0.70), iron, arm)
            slab("SwordBlade", [(0.0, -0.07), (0.0, 0.07), (-1.05, 0.05), (-1.20, 0.0), (-1.05, -0.05)], 0.03, "YZ",
                 (0, 0, -0.70), "steel", arm)
        if boss and side == "L":
            frustum("Buckler", (0.34, 0.06), (0.40, 0.06), 0.40, (0, -0.10, -0.52), iron, arm)
            cyl("BucklerBoss", 0.07, 0.02, 0.06, 6, (0, -0.15, -0.52), trim, arm, (math.radians(90), 0, 0))

    # --- Elmo (grande elmo com fenda de visao luminosa)
    cyl("Helm", 0.115, 0.105, 0.24, 8, (0, 0, 1.66), plate, root, spin=math.radians(22.5))
    cyl("HelmDome", 0.105, 0.03, 0.07, 8, (0, 0, 1.815), plate, root, spin=math.radians(22.5))
    box("VisorSlit", (0.17, 0.02, 0.028), (0, -0.114, 1.69), glow, root)
    box("VisorCross", (0.028, 0.02, 0.20), (0, -0.117, 1.66), iron, root)
    box("HelmCrest", (0.025, 0.22, 0.05), (0, 0, 1.845), iron, root)
    if boss:
        for side, sx in (("L", 1), ("R", -1)):
            cyl("Horn" + side, 0.04, 0.008, 0.30, 5, (0.17 * sx, 0, 1.78), iron, root, (0, 0.8 * sx, 0))
        box("HelmPlume", (0.05, 0.30, 0.10), (0, 0.16, 1.86), cape, root)
    else:
        box("HelmPlume", (0.04, 0.20, 0.07), (0, 0.10, 1.87), cape, root, (0.35, 0, 0))

    # --- Capa curta (boss: capa longa e rasgada)
    if boss:
        frustum("Cape", (0.60, 0.04), (0.38, 0.04), 1.05, (0, 0.17, 1.00), cape, root, (-0.06, 0, 0))
        frustum("CapeRag1", (0.18, 0.03), (0.16, 0.03), 0.30, (-0.14, 0.18, 0.34), cape, root, (-0.06, 0, 0.1))
        frustum("CapeRag2", (0.16, 0.03), (0.14, 0.03), 0.22, (0.15, 0.18, 0.38), cape, root, (-0.06, 0, -0.1))
    else:
        frustum("Cape", (0.46, 0.03), (0.36, 0.03), 0.60, (0, 0.145, 1.17), cape, root, (-0.10, 0, 0))
    box("CapeClasp", (0.10, 0.03, 0.04), (0, -0.01, 1.51), trim, root)
    return root


def build_skeleton():
    """Esqueleto andarilho com espada enferrujada (1.70 m, ligeiramente curvado)."""
    root = empty("Root")
    for side, sx in (("L", 1), ("R", -1)):
        leg = empty("Leg" + side, (0.08 * sx, 0, 0.88), root)
        box("Femur" + side, (0.05, 0.05, 0.40), (0, 0, -0.20), "bone", leg)
        box("Patella" + side, (0.075, 0.075, 0.075), (0, -0.015, -0.42), "bone_dark", leg)
        box("Tibia" + side, (0.042, 0.042, 0.38), (0, 0, -0.64), "bone", leg)
        box("Foot" + side, (0.08, 0.20, 0.05), (0, -0.05, -0.855), "bone", leg)

    frustum("Pelvis", (0.26, 0.13), (0.30, 0.15), 0.13, (0, 0, 0.93), "bone", root)
    box("Spine", (0.05, 0.05, 0.50), (0, 0.04, 1.18), "bone_dark", root, (-0.08, 0, 0))
    for i, z in enumerate((1.20, 1.28, 1.36, 1.44)):
        w = 0.07 + 0.012 * i
        for side, sx in (("L", 1), ("R", -1)):
            box("Rib%d%s" % (i, side), (w, 0.20, 0.028), (0.115 * sx, -0.03, z), "bone", root, (0, 0, 0.35 * sx))
    box("Sternum", (0.045, 0.03, 0.26), (0, -0.14, 1.32), "bone", root)
    box("Clavicle", (0.38, 0.05, 0.04), (0, 0, 1.50), "bone", root)
    box("Cloth", (0.22, 0.02, 0.24), (0, -0.09, 0.80), "cloth", root, (0.06, 0, 0))
    box("ClothBack", (0.22, 0.02, 0.20), (0, 0.09, 0.82), "cloth", root)

    # Cranio
    ico("Skull", 0.115, (0, -0.01, 1.66), "bone", root, scale=(0.95, 1.05, 1.0), subdiv=2)
    box("Jaw", (0.10, 0.12, 0.045), (0, -0.045, 1.56), "bone", root)
    box("Cheek", (0.14, 0.06, 0.03), (0, -0.07, 1.60), "bone", root)
    box("Nose", (0.025, 0.02, 0.03), (0, -0.115, 1.62), "bone_dark", root)
    for side, sx in (("L", 1), ("R", -1)):
        box("EyeSocket" + side, (0.045, 0.035, 0.045), (0.042 * sx, -0.105, 1.675), "eye_red", root)

    # Bracos
    for side, sx in (("L", 1), ("R", -1)):
        arm = empty("Arm" + side, (0.20 * sx, 0, 1.48), root, (0, -0.06 * sx, 0))
        box("Humerus" + side, (0.04, 0.04, 0.28), (0, 0, -0.14), "bone", arm)
        box("Radius" + side, (0.035, 0.035, 0.26), (0, -0.02, -0.40), "bone", arm, (0.12, 0, 0))
        box("Hand" + side, (0.05, 0.05, 0.07), (0, -0.04, -0.56), "bone_dark", arm)
        if side == "R":
            box("SwordGuard", (0.14, 0.03, 0.03), (0, -0.07, -0.60), "rust", arm)
            slab("SwordBlade", [(0.0, -0.04), (0.0, 0.04), (-0.62, 0.035), (-0.72, 0.0), (-0.62, -0.035)], 0.014, "YZ",
                 (0, -0.07, -0.60), "rust", arm)
    return root


def build_bat():
    """Morcego voraz. Origem no centro do corpo; o Godot o eleva (voa baixo)."""
    root = empty("Root")
    ico("Body", 0.13, (0, 0, 0), "bat_fur", root, scale=(0.85, 1.1, 0.85), subdiv=2)
    ico("Head", 0.085, (0, -0.15, 0.05), "bat_fur", root, subdiv=1)
    box("Snout", (0.05, 0.05, 0.04), (0, -0.215, 0.03), "bat_fur", root)
    for side, sx in (("L", 1), ("R", -1)):
        cyl("Ear" + side, 0.035, 0.008, 0.11, 3, (0.05 * sx, -0.14, 0.14), "bat_fur", root, (0, 0.18 * sx, 0))
        box("Eye" + side, (0.028, 0.02, 0.028), (0.04 * sx, -0.225, 0.07), "eye_red", root)
        cyl("Fang" + side, 0.012, 0.003, 0.05, 3, (0.02 * sx, -0.235, -0.01), "fang", root, (math.pi, 0, 0))
        box("Foot" + side, (0.03, 0.05, 0.03), (0.05 * sx, 0.12, -0.12), "bat_fur", root)
    # Asas: fan de triangulos a partir do centroide, pivo no ombro
    wing = [(0.0, -0.08), (0.30, -0.14), (0.72, -0.22), (0.60, 0.02), (0.44, 0.07), (0.38, 0.22),
            (0.20, 0.11), (0.0, 0.14)]
    for side, sx in (("L", 1), ("R", -1)):
        j = empty("Wing" + side, (0.09 * sx, 0, 0.05), root)
        slab("Membrane" + side, wing, 0.012, "XY", (0, 0, 0), "bat_wing", j, mirror=(sx < 0))
        # osso do bordo de ataque
        box("WingBone" + side, (0.73, 0.025, 0.02), (0.36 * sx, -0.15, 0.012), "bat_fur", j, (0, 0, -0.19 * sx))
    return root


# --------------------------------------------------------------------------- drops
def build_gem(key):
    root = empty("Root")
    octahedron("Crystal", 0.11, 0.20, (0, 0, 0), key, root)
    # facetas internas para dar volume
    octahedron("Core", 0.05, 0.10, (0, 0, 0), key, root)
    return root


def build_battle_axe():
    root = empty("Root")
    cyl("Handle", 0.028, 0.026, 0.95, 6, (0, 0, 0), "wood", root)
    cyl("Grip", 0.034, 0.034, 0.22, 6, (0, 0, -0.26), "leather", root)
    cyl("Pommel", 0.04, 0.02, 0.06, 6, (0, 0, -0.50), "dark_iron", root)
    box("Collar", (0.075, 0.075, 0.12), (0, 0, 0.33), "dark_iron", root)
    # lamina: em Y (frente = -Y) e Z (altura), espessura em X
    head = [(0.05, 0.22), (0.05, 0.46), (-0.04, 0.48), (-0.24, 0.55), (-0.32, 0.34), (-0.24, 0.13), (-0.04, 0.20)]
    slab("AxeHead", head, 0.035, "YZ", (0, 0, 0), "steel", root)
    slab("AxeEdge", [(-0.24, 0.55), (-0.32, 0.34), (-0.24, 0.13), (-0.27, 0.34)], 0.045, "YZ", (0, 0, 0), "plate", root)
    cyl("Spike", 0.035, 0.006, 0.14, 4, (0, 0.13, 0.34), "dark_iron", root, (math.radians(-90), 0, 0))
    cyl("Tip", 0.03, 0.006, 0.10, 4, (0, 0, 0.53), "dark_iron", root)
    return root


def build_fire_flask():
    root = empty("Root")
    ico("Liquid", 0.13, (0, 0, 0), "fire_liquid", root, scale=(1, 1, 0.95), subdiv=2)
    cyl("Band", 0.136, 0.136, 0.035, 8, (0, 0, 0.0), "dark_iron", root, spin=math.radians(22.5))
    cyl("Neck", 0.05, 0.042, 0.11, 6, (0, 0, 0.17), "glass_dark", root)
    cyl("Rim", 0.058, 0.058, 0.025, 6, (0, 0, 0.23), "dark_iron", root)
    cyl("Cork", 0.04, 0.035, 0.05, 6, (0, 0, 0.265), "cork", root)
    box("Wick", (0.02, 0.02, 0.09), (0.005, 0, 0.33), "cloth", root, (0, 0.2, 0))
    box("Ember", (0.03, 0.03, 0.03), (0.02, 0, 0.375), "ember", root, (0.4, 0.4, 0))
    return root


def build_roast_meat():
    root = empty("Root")
    tilt = (0, math.radians(-25), 0)
    ico("Meat", 0.17, (0, 0, 0.02), "meat", root, scale=(1.15, 0.95, 0.9), rot=tilt, subdiv=2)
    for i, x in enumerate((-0.06, 0.0, 0.06)):
        box("Char%d" % i, (0.025, 0.2, 0.02), (x, 0, 0.165), "meat_char", root, (0, 0, 0.35))
    cyl("Bone", 0.03, 0.026, 0.24, 6, (0.25, 0, 0.08), "bone", root, (0, math.radians(65), 0))
    ico("KnobA", 0.045, (0.36, 0.035, 0.115), "bone", root, subdiv=1)
    ico("KnobB", 0.045, (0.36, -0.035, 0.115), "bone", root, subdiv=1)
    return root


def build_treasure_chest():
    root = empty("Root")
    box("Body", (0.72, 0.46, 0.34), (0, 0, 0.17), "wood", root)
    # tampa: prisma hexagonal deitado (eixo X), metade fica dentro do corpo
    lid_rot = (0, math.radians(90), 0)
    cyl("Lid", 0.25, 0.25, 0.72, 6, (0, 0, 0.34), "wood", root, lid_rot, sxy=(1.0, 1.0), spin=math.radians(30))
    for side, sx in (("L", 1), ("R", -1)):
        box("Strap" + side, (0.07, 0.48, 0.36), (0.22 * sx, 0, 0.17), "dark_iron", root)
        cyl("LidStrap" + side, 0.27, 0.27, 0.07, 6, (0.22 * sx, 0, 0.34), "dark_iron", root, lid_rot, spin=math.radians(30))
    box("LockPlate", (0.13, 0.03, 0.15), (0, -0.245, 0.33), "chest_gold", root)
    box("Keyhole", (0.03, 0.035, 0.05), (0, -0.26, 0.33), "dark_iron", root)
    for sx in (1, -1):
        for sy in (1, -1):
            box("Stud", (0.05, 0.05, 0.05), (0.35 * sx, 0.22 * sy, 0.03), "chest_gold", root)
    return root


# --------------------------------------------------------------------------- cenario
def build_ruin_pillar():
    root = empty("Root")
    box("Plinth", (1.30, 1.30, 0.30), (0, 0, 0.15), "masonry_dk", root)
    cyl("Base", 0.62, 0.52, 0.22, 8, (0, 0, 0.41), "masonry", root, spin=math.radians(22.5))
    cyl("Shaft", 0.50, 0.44, 1.60, 8, (0, 0, 1.32), "masonry", root, spin=math.radians(22.5))
    # topo quebrado
    cyl("Broken", 0.44, 0.20, 0.40, 5, (0.04, 0, 2.32), "masonry_dk", root, (0.10, -0.12, 0), spin=math.radians(10))
    rng = random.Random(11)
    for i in range(5):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.85, 1.25)
        s = rng.uniform(0.18, 0.34)
        box("Chunk%d" % i, (s, s * rng.uniform(0.8, 1.3), s * 0.7), (math.cos(a) * d, math.sin(a) * d, s * 0.35), "masonry_dk",
            root, (0, 0, rng.uniform(0, 3)))
    return root


def build_rubble_pile():
    root = empty("Root")
    rng = random.Random(23)
    for i in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.7)
        s = rng.uniform(0.28, 0.62)
        z = s * 0.3 + (0.2 if d < 0.3 else 0.0)
        box("Stone%d" % i, (s, s * rng.uniform(0.7, 1.2), s * 0.65), (math.cos(a) * d, math.sin(a) * d, z),
            "masonry" if i % 2 else "masonry_dk", root, (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, 3)))
    return root


# --------------------------------------------------------------------------- main
MODELS = [
    ("knight_player.glb", lambda: build_knight(False)),
    ("boss_renegade_knight.glb", lambda: build_knight(True)),
    ("enemy_skeleton.glb", build_skeleton),
    ("enemy_bat.glb", build_bat),
    ("gem_blue.glb", lambda: build_gem("gem_blue")),
    ("gem_green.glb", lambda: build_gem("gem_green")),
    ("gem_red.glb", lambda: build_gem("gem_red")),
    ("battle_axe.glb", build_battle_axe),
    ("fire_flask.glb", build_fire_flask),
    ("roast_meat.glb", build_roast_meat),
    ("treasure_chest.glb", build_treasure_chest),
    ("ruin_pillar.glb", build_ruin_pillar),
    ("rubble_pile.glb", build_rubble_pile),
]


def main():
    for filename, builder in MODELS:
        reset_scene()
        builder()
        export(filename)
    print("[ashen] concluido: %d modelos em %s" % (len(MODELS), _out_dir()))


main()
