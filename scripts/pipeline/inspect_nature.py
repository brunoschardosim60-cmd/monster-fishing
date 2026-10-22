import bpy,pathlib,collections
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'tools/asset-source/polyhaven/island_tree_02/island_tree_02_1k.gltf'))
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  totals=collections.Counter()
  for p in o.data.polygons:totals[o.data.materials[p.material_index].name]+=len(p.vertices)-2
  print('MAT_COUNTS',dict(totals),flush=True)
