"""Separate the middle of the three supplied figures, then author a simple rig.
This is a new local rig/animation pass; the source upload was not animated.
"""
import bpy, bmesh, pathlib, math, json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/survivalist.glb'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# The figures are disconnected mesh components. Assign each component to its
# nearest figure centre so eyes, straps and buttons stay with their character.
mesh=obj.data
parents=list(range(len(mesh.vertices)))
def find(x):
    while parents[x]!=x:
        parents[x]=parents[parents[x]];x=parents[x]
    return x
for edge in mesh.edges:
    a,b=map(find,edge.vertices);parents[a]=b
groups={}
for v in mesh.vertices:groups.setdefault(find(v.index),[]).append(v.index)
centres={key:sum(mesh.vertices[i].co.x for i in ids)/len(ids) for key,ids in groups.items()}
keep={v.index for v in mesh.vertices if -.166<v.co.x<.166}
bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
lo=Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
hi=Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
centre=(lo+hi)*.5;factor=1.82/(hi.z-lo.z)
for v in mesh.vertices:
    p=(v.co-Vector((centre.x,centre.y,lo.z)))*factor
    v.co=Vector((-p.x,-p.y,p.z)) # Face Godot -Z after glTF +Y-up export.
obj.name='SurvivalistBody';mesh.update()
# Remove importer empty hierarchy while preserving mesh world transform.
obj.parent=None;obj.matrix_world.identity()
for other in list(bpy.context.scene.objects):
    if other!=obj:bpy.data.objects.remove(other,do_unlink=True)
arm_data=bpy.data.armatures.new('SurvivalistSkeleton')
arm=bpy.data.objects.new('SurvivalistRig',arm_data);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);obj.select_set(False)
bpy.ops.object.mode_set(mode='EDIT')
specs=[('Hips',(0,0,.82),(0,0,1.02),None),('Spine',(0,0,1.02),(0,0,1.26),'Hips'),
       ('Chest',(0,0,1.26),(0,0,1.45),'Spine'),('Neck',(0,0,1.45),(0,0,1.55),'Chest'),('Head',(0,0,1.55),(0,0,1.82),'Neck')]
for label,sign in [('Left',1),('Right',-1)]:
    specs += [(label+'UpperLeg',(sign*.105,0,.85),(sign*.105,0,.46),'Hips'),
              (label+'LowerLeg',(sign*.105,0,.46),(sign*.105,0,.13),label+'UpperLeg'),
              (label+'Foot',(sign*.105,0,.13),(sign*.105,.16,.08),label+'LowerLeg'),
              (label+'UpperArm',(sign*.23,0,1.39),(sign*.37,0,1.13),'Chest'),
              (label+'ForeArm',(sign*.37,0,1.13),(sign*.46,.01,.94),label+'UpperArm'),
              (label+'Hand',(sign*.46,.01,.94),(sign*.49,.02,.85),label+'ForeArm')]
for name,head,tail,parent in specs:
    bone=arm_data.edit_bones.new(name);bone.head=head;bone.tail=tail
    if parent:bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.ops.object.parent_set(type='ARMATURE_NAME')
# The scan is non-manifold: heat weights fail. Author regional, normalized
# two-bone envelopes instead of exporting an unweighted decorative skeleton.
unweighted=sum(1 for v in mesh.vertices if not v.groups)
def segment_distance(p,a,b):
    a,b=Vector(a),Vector(b);t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
    return (p-a-(b-a)*t).length
for v in mesh.vertices:
    p=v.co;side='Left' if p.x>0 else 'Right'
    if abs(p.x)>.235 and .65<p.z<1.47:
        candidates=[s for s in specs if s[0] in [side+'UpperArm',side+'ForeArm',side+'Hand']]
    elif p.z<.85:
        candidates=[s for s in specs if s[0] in [side+'UpperLeg',side+'LowerLeg',side+'Foot','Hips']]
    else:
        candidates=[s for s in specs if s[0] in ['Hips','Spine','Chest','Neck','Head']]
    ranked=sorted([(segment_distance(p,s[1],s[2]),s[0]) for s in candidates])[:2]
    weights=[1/max(.018,d)**4 for d,n in ranked];total=sum(weights)
    for (d,name),weight in zip(ranked,weights):obj.vertex_groups[name].add([v.index],weight/total,'REPLACE')
scene=bpy.context.scene;scene.render.fps=30
def key_pose(frame,kind,phase):
    for bone in arm.pose.bones:
        bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
    for label,sign in [('Left',1),('Right',-1)]:
        arm.pose.bones[label+'UpperArm'].rotation_euler.y=-sign*.38
        swing=math.sin(phase)*(.62 if kind=='Run' else .38)
        if kind in ('Walk','Run'):
            arm.pose.bones[label+'UpperLeg'].rotation_euler.x=sign*swing
            arm.pose.bones[label+'LowerLeg'].rotation_euler.x=max(0,-sign*math.sin(phase))*.52
            arm.pose.bones[label+'UpperArm'].rotation_euler.x=-sign*swing*.55
            arm.pose.bones['Hips'].location.y=abs(math.sin(phase))*.025
        if kind in ('Fish','Hold','Steer'):
            arm.pose.bones[label+'UpperArm'].rotation_euler.x=.68 if kind!='Hold' else (.6 if label=='Left' else 0.)
            arm.pose.bones[label+'ForeArm'].rotation_euler.x=.55
        if kind=='Swim':
            arm.pose.bones[label+'UpperArm'].rotation_euler.x=1.1+sign*math.sin(phase)*.5
            arm.pose.bones[label+'UpperLeg'].rotation_euler.x=sign*math.sin(phase)*.15
    arm.pose.bones['Chest'].rotation_euler.x=math.sin(phase)*.012
    for bone in arm.pose.bones:
        bone.keyframe_insert('rotation_euler',frame=frame,group=bone.name)
        bone.keyframe_insert('location',frame=frame,group=bone.name)
for kind in ['Idle','Walk','Run','Fish','Hold','Steer','Swim']:
    action=bpy.data.actions.new(kind);arm.animation_data_create();arm.animation_data.action=action
    for frame in [1,9,17,25,33]:key_pose(frame,kind,(frame-1)/32*math.tau)
    track=arm.animation_data.nla_tracks.new();track.name=kind;track.strips.new(kind,1,action)
arm.animation_data.action=None
for track in arm.animation_data.nla_tracks:track.mute=True
scene.frame_start=1;scene.frame_end=33
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/survivalist_rigged.glb'),export_format='GLB',export_yup=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True,export_influence_nb=4)
report={'source':'survivalist.glb','source_had_rig':False,'figures_in_source':3,'selected':'central figure cropped spatially from the merged mesh',
        'vertices':len(mesh.vertices),'triangles':len(mesh.polygons),'bones':len(arm.data.bones),'animations':[a.name for a in bpy.data.actions],'weights':'authored regional two-bone envelopes',
        'unweighted_vertices_before_accessory_assignment':unweighted,'height_m':1.82}
(ROOT/'docs/asset-audit/survivalist_rigged.json').write_text(json.dumps(report,indent=2))
print('RIG_RESULT',json.dumps(report),flush=True)
