"""Separate timber, plaster, roof and stone on the supplied complete harbor."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/environment/harbor.glb'))
materials=[]
for name,color in [('HarborStone',(.36,.39,.36,1)),('HarborTimber',(.27,.19,.12,1)),('HarborWall',(.70,.65,.48,1)),('HarborRoof',(.30,.12,.065,1)),('HarborMetal',(.10,.21,.24,1))]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.85;materials.append(m)
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 o.data.materials.clear()
 for m in materials:o.data.materials.append(m)
 for p in o.data.polygons:
  z=(o.matrix_world@p.center).z;n=(o.matrix_world.to_3x3()@p.normal).z
  p.material_index=0 if z<.075 or (o.name=='tripo_part_0' and z<.15) else (3 if n>.35 and z>.15 else 2)
  if o.name in ['tripo_part_3','tripo_part_5','tripo_part_6','tripo_part_9'] and n>.1:p.material_index=3
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/environment/harbor_dressed.glb'),export_format='GLB',export_yup=True,export_animations=False)
