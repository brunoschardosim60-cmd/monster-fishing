"""Run with Blender --background --python this_file -- fishing_boat.
Original uploads are read only. Decimation is applied to a separate game export.
"""
import bpy, json, pathlib, sys, hashlib, zipfile
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOWNLOADS = pathlib.Path.home() / 'Downloads'
ASSETS = {
    'fishing_boat': ('fishing boat 3d model.glb', 'boats', 0.045),
    'tugboat': ('tugboat 3d model.glb', 'boats', 0.035),
    'harbor': ('coastal village harbor 3d model.glb', 'environment', 0.07),
    'dragon': ('dragon creature 3d model.glb', 'monsters', 0.025),
    'goat': ('goat 3d model (1).glb', 'props', 0.018),
    'survivalist': ('survivalist character 3d model.zip', 'characters', 1.0),
}

def run(key):
    source, folder, ratio = ASSETS[key]
    src = DOWNLOADS / source
    output = ROOT / 'assets' / folder / (key + '.glb')
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if src.suffix == '.zip':
        extraction = ROOT / 'tools' / 'asset-source' / key
        extraction.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(src) as archive:
            for member in archive.infolist():
                target = (extraction / member.filename).resolve()
                if not target.is_relative_to(extraction.resolve()):
                    raise ValueError('Unsafe archive member')
                if target.suffix.lower() in ('.fbx', '.jpg', '.png'):
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(member))
        bpy.ops.import_scene.fbx(filepath=str(next(extraction.glob('*.fbx'))))
    else:
        bpy.ops.import_scene.gltf(filepath=str(src))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    report = {'source': source, 'sha256': hashlib.sha256(src.read_bytes()).hexdigest(),
              'parts': len(objects), 'triangles_before': sum(len(o.data.polygons) for o in objects),
              'armatures': [{'name':o.name,'bones':len(o.data.bones)} for o in bpy.context.scene.objects if o.type=='ARMATURE'],
              'actions': [a.name for a in bpy.data.actions], 'ratio':ratio,
              'textured': any(n.type=='TEX_IMAGE' for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes)}
    part_info=[]
    for obj in objects:
        if ratio < 1. and len(obj.data.polygons) > 200:
            bpy.context.view_layer.objects.active = obj
            modifier = obj.modifiers.new('Game budget', 'DECIMATE')
            modifier.ratio = max(ratio, min(1., 90. / len(obj.data.polygons)))
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        for poly in obj.data.polygons: poly.use_smooth = True
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        part_info.append({'name':obj.name,'triangles':len(obj.data.polygons),
                          'min':[min(v[i] for v in corners) for i in range(3)],
                          'max':[max(v[i] for v in corners) for i in range(3)]})
    # Keep packed textures within a 2K budget. Geometry-only uploads remain honest
    # geometry-only sources; runtime materials are applied in the reusable wrapper.
    for im in bpy.data.images:
        if im.size[0] > 2048 or im.size[1] > 2048:
            factor=2048 / max(im.size)
            im.scale(int(im.size[0]*factor), int(im.size[1]*factor))
    report['triangles_after']=sum(len(o.data.polygons) for o in objects)
    report['parts_detail_blender_z_up']=part_info
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_yup=True,
                             export_apply=True, export_animations=True, export_materials='EXPORT')
    report['export_bytes']=output.stat().st_size
    reports=ROOT/'docs'/'asset-audit';reports.mkdir(parents=True,exist_ok=True)
    (reports/(key+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ASSET_RESULT',key,report['triangles_before'],report['triangles_after'],report['armatures'],report['actions'],flush=True)

keys=sys.argv[sys.argv.index('--')+1:]
for key in keys: run(key)
