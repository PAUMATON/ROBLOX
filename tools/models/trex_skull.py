# Genera el crani del T-Rex (estilitzat, acollidor) amb Blender (bpy).
# Ús: pip install bpy && python3 tools/models/trex_skull.py [carpeta_renders]
# Surt: assets/fossils/trex_skull.fbx i .obj (llestos per a Studio → Import 3D)
import bpy, math, os, sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "fossils")
RENDER_DIR = sys.argv[1] if len(sys.argv) > 1 else OUT
MAX_TRIS = 9000  # Roblox permet ~20k per malla; en deixem marge
BONE = (0xED/255, 0xE3/255, 0xCC/255)
SAND = (0xD9/255, 0xC7/255, 0xA0/255)
JAW_OPEN = math.radians(14)
HINGE = Vector((-1.0, 0, 0.0))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
def srgb(c): return tuple(((x+0.055)/1.055)**2.4 if x > 0.04045 else x/12.92 for x in c)

def activate(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o

def blob(loc, scale, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = scale; return o

def join(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join()
    o = objs[0]; bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); return o

def fuse(o, voxel=0.03):
    # fon totes les esferes en una sola pell i l'allisa
    activate(o)
    r = o.modifiers.new("remesh", 'REMESH'); r.mode = 'VOXEL'; r.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=r.name)
    s = o.modifiers.new("smooth", 'SMOOTH'); s.iterations = 6; s.factor = 0.8
    bpy.ops.object.modifier_apply(modifier=s.name)

def hole(target, loc, scale, rot=(math.pi/2, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1, depth=2, location=loc, rotation=rot)
    c = bpy.context.active_object; c.scale = (scale[0], scale[2], scale[1])
    activate(target)
    m = target.modifiers.new("cut", 'BOOLEAN'); m.operation = 'DIFFERENCE'; m.object = c; m.solver = 'EXACT'
    bpy.ops.object.modifier_apply(modifier=m.name); bpy.data.objects.remove(c)

# ── Crani superior (x = cap al morro, z = amunt) ──
parts = [
    blob((-0.72, 0, 0.42), (0.40, 0.44, 0.40)),      # volta del crani, ampla (T-Rex!)
    blob((-0.25, 0, 0.36), (0.48, 0.34, 0.36)),      # cos
    blob(( 0.30, 0, 0.24), (0.52, 0.25, 0.27)),      # morro
    blob(( 0.82, 0, 0.14), (0.30, 0.20, 0.20)),      # punta
    blob(( 0.40, 0, 0.02), (0.70, 0.22, 0.10)),      # maxil·lar (vora de les dents)
    blob((-0.40,  0.28, 0.70), (0.22, 0.11, 0.08)),  # celles banyudes
    blob((-0.40, -0.28, 0.70), (0.22, 0.11, 0.08)),
    blob((-0.95,  0.30, 0.05), (0.14, 0.10, 0.14)),  # articulacions de la mandíbula
    blob((-0.95, -0.30, 0.05), (0.14, 0.10, 0.14)),
]
skull = join(parts); fuse(skull)
hole(skull, (-0.45, 0, 0.47), (0.14, 0.7, 0.16))   # òrbita
hole(skull, ( 0.10, 0, 0.28), (0.24, 0.7, 0.10))   # fenestra anteorbital
hole(skull, ( 0.92, 0, 0.22), (0.07, 0.7, 0.05))   # narius
# ── Mandíbula (tancada; després l'obrim per la frontissa) ──
jaw = join([
    blob((-0.80, 0, -0.14), (0.28, 0.36, 0.16)),
    blob((-0.20, 0, -0.14), (0.55, 0.25, 0.11)),
    blob(( 0.45, 0, -0.10), (0.48, 0.18, 0.09)),
])
fuse(jaw)
hole(jaw, (-0.55, 0, -0.14), (0.18, 0.7, 0.045))  # fenestra mandibular

# ── Dents: cons que es claven on toca (raycast contra la superfície real) ──
def surface_z(obj, x, y, from_below):
    o = Vector((x, y, -5 if from_below else 5)); d = Vector((0, 0, 1 if from_below else -1))
    hit, loc, *_ = obj.ray_cast(o, d)
    return loc.z if hit else None

def teeth(obj, xs, width, down):
    out = []
    for i, x in enumerate(xs):
        f = i / (len(xs)-1)
        L = 0.19 - 0.09 * abs(f - 0.3)          # les del mig, les més grosses
        for s in (1, -1):
            y = s * width(x); z = surface_z(obj, x, y, down)
            if z is None: continue
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=L*0.3, radius2=0.006, depth=L,
                location=(x, y, z + (-L/2 + 0.04 if down else L/2 - 0.04)),
                rotation=(0, math.pi if down else 0, 0))
            t = bpy.context.active_object
            t.rotation_euler.y += math.radians(-12 if down else 12)  # corbades cap enrere
            out.append(t)
    return out

up = teeth(skull, [-0.20 + 0.14*i for i in range(9)], lambda x: 0.17 - 0.035*x, True)
lo = teeth(jaw,   [-0.05 + 0.13*i for i in range(7)], lambda x: 0.14 - 0.03*x, False)
skull = join([skull] + up); jaw = join([jaw] + lo)

# obre la boca girant la mandíbula per la frontissa
jaw.data.transform(Matrix.Translation(HINGE) @ Matrix.Rotation(JAW_OPEN, 4, 'Y') @ Matrix.Translation(-HINGE))

rex = join([skull, jaw]); rex.name = "TRexSkull"
activate(rex); bpy.ops.object.shade_smooth()
tris = sum(len(p.vertices)-2 for p in rex.data.polygons)
if tris > MAX_TRIS:
    d = rex.modifiers.new("dec", 'DECIMATE'); d.ratio = MAX_TRIS / tris
    bpy.ops.object.modifier_apply(modifier=d.name)
print("TRIANGLES:", sum(len(p.vertices)-2 for p in rex.data.polygons))

mat = bpy.data.materials.new("Bone"); mat.use_nodes = True
p = mat.node_tree.nodes["Principled BSDF"]
p.inputs["Base Color"].default_value = (*srgb(BONE), 1); p.inputs["Roughness"].default_value = 0.6
rex.data.materials.append(mat)

os.makedirs(OUT, exist_ok=True); activate(rex)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "trex_skull.fbx"), use_selection=True)
bpy.ops.wm.obj_export(filepath=os.path.join(OUT, "trex_skull.obj"), export_selected_objects=True, export_materials=False)

# ── Render de previsualització ──
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, rex.bound_box[0][2] - 0.01))
g = bpy.context.active_object; gm = bpy.data.materials.new("Sand"); gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*srgb(SAND), 1)
g.data.materials.append(gm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); scene.collection.objects.link(sun)
sun.data.energy = 3.5; sun.data.angle = math.radians(8)
sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(-40))
scene.world = bpy.data.worlds.new("W"); scene.world.use_nodes = True
bg = scene.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.55, 0.72, 0.95, 1); bg.inputs[1].default_value = 0.9
scene.render.engine = 'CYCLES'; scene.cycles.samples = 48; scene.cycles.device = 'CPU'
scene.render.resolution_x, scene.render.resolution_y = 900, 600
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam); scene.camera = cam
def shoot(name, pos, target=(-0.05, 0, 0.15)):
    cam.location = pos
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(RENDER_DIR, name); bpy.ops.render.render(write_still=True)
shoot("trex_skull_side.png", (0.0, -4.0, 0.4))
shoot("trex_skull_3q.png", (2.6, -2.6, 1.5))
