"""Optimize CC0 nature meshes and author curved palm geometry for Godot."""
import bpy, bmesh, pathlib, json, math, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/environment/nature';OUT.mkdir(parents=True,exist_ok=True)
reports=[]
for asset,budget in [('island_tree_01',26000),('island_tree_02',24000),('fern_02',4000),('coastal_cliff_02',9000)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source=ROOT/'tools/asset-source/polyhaven'/asset
    bpy.ops.import_scene.gltf(filepath=str(source/(asset+'_1k.gltf')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if asset.startswith('island_tree'):
        # Retain the real branching skeleton. Rebuild leaf sprays at the source
        # canopy's locations instead of decimating alpha cards into torn slivers.
        grid={};random.seed(300+len(asset))
        for obj in meshes:
            ids=[i for i,m in enumerate(obj.data.materials) if 'leav' in m.name.lower()]
            for p in obj.data.polygons:
                if p.material_index in ids:
                    c=obj.matrix_world@p.center
                    key=tuple(round(v/.22) for v in c)
                    grid[key]=c.copy()
            bm=bmesh.new();bm.from_mesh(obj.data)
            bmesh.ops.delete(bm,geom=[p for p in bm.faces if p.material_index in ids],context='FACES')
            bm.to_mesh(obj.data);bm.free()
        material=bpy.data.materials.new('Generated coastal leaves');material.use_nodes=True;material.use_backface_culling=False;material.surface_render_method='DITHERED'
        bs=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.9
        tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/textures/coastal_leaves.png'))
        material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);material.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
        points=list(grid.values());random.shuffle(points);points=points[:1100]
        verts=[];faces=[];uvs=[]
        for center in points:
            for k in range(2):
                a=random.random()*math.tau;size=random.uniform(.32,.50)
                side=Vector((math.cos(a),math.sin(a),0))*size
                forward=Vector((-math.sin(a)*.55,math.cos(a)*.55,random.uniform(.25,.8))).normalized()*size
                start=len(verts)
                for v,uv in [(-side-forward,(0,0)),(side-forward,(1,0)),(side+forward,(1,1)),(-side+forward,(0,1))]:verts.append(center+v);uvs.append(uv)
                faces.append((start,start+1,start+2,start+3))
        mesh=bpy.data.meshes.new('LeafSprays');mesh.from_pydata(verts,[],faces);mesh.materials.append(material);uv=mesh.uv_layers.new()
        for p in mesh.polygons:
            p.use_smooth=True
            for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
        obj=bpy.data.objects.new('LeafCards',mesh);bpy.context.collection.objects.link(obj);meshes.append(obj)
    total=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    for o in meshes:
        bpy.context.view_layer.objects.active=o
        tris=sum(len(p.vertices)-2 for p in o.data.polygons)
        if tris>300 and total>budget and o.name!='LeafCards':
            mod=o.modifiers.new('Runtime budget','DECIMATE');mod.ratio=max(.015,min(1,budget/total));mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        for p in o.data.polygons:p.use_smooth=True
    for mat in bpy.data.materials:
        mat.use_backface_culling=False
        if not mat.use_nodes:continue
        bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bsdf:bsdf.inputs['Roughness'].default_value=.86
        alpha=next(source.glob('textures/*alpha*'),None)
        if alpha and not mat.name.startswith('Generated') and ('leav' in mat.name.lower() or asset=='fern_02') and bsdf:
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(alpha));tex.image.colorspace_settings.name='Non-Color'
            mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Alpha']);mat.surface_render_method='DITHERED'
    corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector([min(c[i] for c in corners) for i in range(3)]);hi=Vector([max(c[i] for c in corners) for i in range(3)])
    shift=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    for o in meshes:o.location-=shift
    bpy.ops.export_scene.gltf(filepath=str(OUT/(asset+'.glb')),export_format='GLB',export_apply=True,export_yup=True,export_animations=False)
    reports.append({'id':asset,'before':total,'after':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'size_m':list(hi-lo)})
    print('NATURE',reports[-1],flush=True)

# Palm fronds use the generated alpha texture on a curved, subdivided surface.
for variant in range(2):
    bpy.ops.wm.read_factory_settings(use_empty=True);random.seed(81+variant)
    bark=bpy.data.materials.new('Palm bark');bark.diffuse_color=(.32,.23,.13,1);bark.use_nodes=True
    bn=bark.node_tree.nodes;bs=next(n for n in bn if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.32,.23,.13,1);bs.inputs['Roughness'].default_value=.93
    tex=bn.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/textures/weathered_wood_color.png'))
    bark.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    leaf=bpy.data.materials.new('Palm frond');leaf.use_nodes=True;leaf.use_backface_culling=False
    bs=next(n for n in leaf.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.88
    tex=leaf.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/textures/palm_frond.png'))
    leaf.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);leaf.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);leaf.surface_render_method='DITHERED'
    verts=[];faces=[];uvs=[];height=8.+variant*1.7
    for j in range(25):
        t=j/24;r=(.22*(1-t)+.10*t)*(1+.05*math.sin(j*math.pi));bend=1.6*t*t
        for k in range(12):
            a=k/12*math.tau;verts.append((bend+math.cos(a)*r,math.sin(a)*r,height*t));uvs.append((k/12,t*4))
    for j in range(24):
        for k in range(12):a=j*12+k;b=j*12+(k+1)%12;faces.append((a,b,b+12,a+12))
    mesh=bpy.data.meshes.new('Curved palm trunk');mesh.from_pydata(verts,[],faces);mesh.materials.append(bark);obj=bpy.data.objects.new('PalmTrunk',mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    verts=[];faces=[];uvs=[]
    for f in range(19):
        angle=f*2.39996;length=random.uniform(3.6,5.2);sag=random.uniform(1.1,3.5);up=random.uniform(.4,1.9)
        base=len(verts);direction=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-math.sin(angle),math.cos(angle),0))
        for j in range(13):
            t=j/12;center=Vector((1.6,0,height))+direction*(length*t)+Vector((0,0,math.sin(t*math.pi)*up-sag*t*t))
            for k in range(3):
                u=k/2;p=center+side*((u-.5)*length*.48);p.z-=abs(u-.5)*.2
                verts.append(p);uvs.append((u,1-t))
        for j in range(12):
            for k in range(2):a=base+j*3+k;faces.append((a,a+1,a+4,a+3))
    mesh=bpy.data.meshes.new('Palm crown');mesh.from_pydata(verts,[],faces);mesh.materials.append(leaf);obj=bpy.data.objects.new('PalmLeaves',mesh);bpy.context.collection.objects.link(obj);uv=mesh.uv_layers.new()
    for p in mesh.polygons:
        p.use_smooth=True
        for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    bpy.ops.export_scene.gltf(filepath=str(OUT/('coconut_palm_%d.glb'%variant)),export_format='GLB',export_yup=True,export_animations=False)
(ROOT/'docs/asset-audit/nature-runtime.json').write_text(json.dumps(reports,indent=2))
