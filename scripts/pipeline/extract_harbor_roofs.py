"""Reuse real Tripo harbor architecture above accessible modular village rooms."""
import bpy,bmesh,pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/environment/harbor.glb'))
sources={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
report=[]
for variant,part in enumerate([3,5,6,9]):
    source=sources['tripo_part_'+str(part)]
    obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    mesh=obj.data
    lo=[min(v.co[i] for v in mesh.vertices) for i in range(3)]
    hi=[max(v.co[i] for v in mesh.vertices) for i in range(3)]
    cut=lo[2]+(hi[2]-lo[2])*.48
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,
                          plane_co=(0,0,cut),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
    bm.to_mesh(mesh);bm.free()
    for axis in [0,1]:
        lo[axis]=min(v.co[axis] for v in mesh.vertices);hi[axis]=max(v.co[axis] for v in mesh.vertices)
    for v in mesh.vertices:
        v.co.x=(v.co.x-(lo[0]+hi[0])*.5)/(hi[0]-lo[0])
        v.co.y=(v.co.y-(lo[1]+hi[1])*.5)/(hi[1]-lo[1])
        v.co.z=(v.co.z-cut)/(hi[2]-cut)
    obj.parent=None;obj.name='HarborRoof'+str(variant)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/environment/harbor_roof_{variant}.glb'),export_format='GLB',use_selection=True,export_yup=True)
    report.append({'source_part':source.name,'variant':variant,'triangles':len(mesh.polygons),'cut_fraction':.48})
    bpy.data.objects.remove(obj,do_unlink=True)
(ROOT/'docs/asset-audit/harbor_modules.json').write_text(json.dumps(report,indent=2))
print('HARBOR_MODULES',report,flush=True)
