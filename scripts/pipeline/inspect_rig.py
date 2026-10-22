import bpy,json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/survivalist_rigged.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for z in [.75,.85,.95,1.05,1.15,1.25,1.35,1.45]:
    p=[v.co for v in o.data.vertices if abs(v.co.z-z)<.025 and v.co.x>0]
    xs=sorted(v.x for v in p)
    print('RIG_SLICE',z,'xquantiles',[round(xs[int((len(xs)-1)*q)],3) for q in [.5,.8,.9,.97,1]],flush=True)
