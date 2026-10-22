"""Separate the middle of the three supplied figures, then author a simple rig.
This is a new local rig/animation pass; the source upload was not animated.
"""
import bpy, bmesh, pathlib, math, json
from mathutils import Vector, Quaternion
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
    # The jacket's side pockets protrude at the waist. A vertical x threshold
    # incorrectly binds those pockets to the hands and stretches the trousers.
    boundary=min(.39,.19+max(0.,1.24-p.z)*.8)
    a=max(0.,min(1.,(abs(p.x)-boundary+.025)/.065)) if .65<p.z<1.49 else 0.
    a=a*a*(3-2*a)
    arm_candidates=[s for s in specs if s[0] in [side+'UpperArm',side+'ForeArm',side+'Hand']]
    body_candidates=[s for s in specs if s[0] in (['Hips','Spine','Chest','Neck','Head'] if p.z>.88 else [side+'UpperLeg',side+'LowerLeg',side+'Foot','Hips'])]
    for candidates,mix in [(arm_candidates,a),(body_candidates,1-a)]:
        if mix<.0001:continue
        ranked=sorted([(segment_distance(p,s[1],s[2]),s[0]) for s in candidates])[:2]
        weights=[1/max(.018,d)**4 for d,n in ranked];total=sum(weights)
        for (d,name),weight in zip(ranked,weights):obj.vertex_groups[name].add([v.index],mix*weight/total,'REPLACE')
scene=bpy.context.scene;scene.render.fps=30
def rotate_world(name,x=0.,y=0.,z=0.):
    # Bone-local Y follows the bone; it is NOT the character's vertical axis.
    # Convert character-space rotations so arms bend instead of just twisting.
    bone=arm.pose.bones[name];rest=arm.data.bones[name].matrix_local.to_quaternion()
    world=Quaternion((0,0,1),z) @ Quaternion((0,1,0),y) @ Quaternion((1,0,0),x)
    bone.rotation_mode='QUATERNION';bone.rotation_quaternion=rest.inverted() @ world @ rest
def key_pose(frame,kind,phase):
    for bone in arm.pose.bones:
        bone.rotation_mode='QUATERNION';bone.rotation_quaternion=(1,0,0,0);bone.location=(0,0,0)
    running=kind=='Run';moving=kind in ('Walk','Run')
    swing=math.sin(phase);stride=.88 if running else .58
    rotate_world('Hips',x=.10 if running else .015,y=math.sin(phase)*(.05 if moving else .008),z=swing*.07 if moving else .012*math.sin(phase))
    rotate_world('Spine',x=-.04 if running else .015,z=-swing*.10 if moving else .012*math.sin(phase))
    rotate_world('Chest',x=.018*math.sin(phase*2),z=-swing*.08 if moving else .02*math.sin(phase))
    rotate_world('Head',z=.02*math.sin(phase),x=.025*math.sin(phase))
    arm.pose.bones['Hips'].location.y=((1-math.cos(phase*2))*(.023 if running else .009)) if moving else math.sin(phase)*.004
    for label,sign in [('Left',1),('Right',-1)]:
        rotate_world(label+'UpperArm',x=.02*math.sin(phase+sign),y=sign*.36)
        rotate_world(label+'ForeArm',x=.10)
        if moving:
            rotate_world(label+'UpperLeg',x=sign*swing*stride)
            leg_phase=phase if sign==1 else phase+math.pi
            lift=max(0,math.sin(leg_phase-.18))**2
            rotate_world(label+'LowerLeg',x=-(.08+lift*(1.15 if running else .85)))
            rotate_world(label+'Foot',x=-sign*swing*.18+lift*.3)
            rotate_world(label+'UpperArm',x=-sign*swing*(.65 if running else .48),y=sign*.40)
            rotate_world(label+'ForeArm',x=(.85 if running else .18)+(.12+.10*math.sin(phase*sign-.4)))
            rotate_world(label+'Hand',x=-.1,z=sign*.06)
        if kind in ('Fish','Hold','Steer'):
            rotate_world(label+'UpperArm',x=.50 if kind!='Hold' else (.64 if label=='Left' else .05),y=sign*(.32 if kind=='Hold' else .55))
            rotate_world(label+'ForeArm',x=.65 if kind!='Hold' else (.7 if label=='Left' else .12),y=sign*.8 if kind!='Hold' else -sign*.12)
            rotate_world('Chest',x=.035+math.sin(phase)*.025,z=math.sin(phase)*.03)
        if kind=='Reel':
            rotate_world(label+'UpperArm',x=.72+math.sin(phase)*.04,y=sign*.58)
            rotate_world(label+'ForeArm',x=.6+(math.sin(phase)*.12 if label=='Left' else .06),y=sign*.85)
            rotate_world(label+'Hand',z=math.sin(phase)*.35 if label=='Left' else 0.)
            rotate_world('Spine',x=-.11+math.sin(phase)*.04)
        if kind=='Cast':
            t=(frame-1)/32
            windup=math.sin(min(1,t/.45)*math.pi*.5) if t<.45 else max(0,1-(t-.45)/.3)
            rotate_world(label+'UpperArm',x=.4+windup*1.8,y=sign*.25)
            rotate_world(label+'ForeArm',x=.45+windup*.6)
            rotate_world('Chest',x=-windup*.15,z=windup*.25)
        if kind in ('Jump','Fall'):
            rotate_world(label+'UpperArm',x=.5 if kind=='Jump' else -.18,y=-sign*.18)
            rotate_world(label+'ForeArm',x=.65 if kind=='Jump' else .28)
            rotate_world(label+'UpperLeg',x=.35 if kind=='Jump' else .08)
            rotate_world(label+'LowerLeg',x=-.6 if kind=='Jump' else -.22)
            rotate_world('Chest',x=.1)
        if kind=='Swim':
            rotate_world(label+'UpperArm',x=1.45+sign*swing*.85,y=sign*.2)
            rotate_world(label+'ForeArm',x=.4+sign*swing*.3)
            rotate_world(label+'UpperLeg',x=sign*swing*.24)
    for bone in arm.pose.bones:
        bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
        bone.keyframe_insert('location',frame=frame,group=bone.name)
for kind in ['Idle','Walk','Run','Fish','Hold','Steer','Swim','Cast','Reel','Jump','Fall']:
    action=bpy.data.actions.new(kind);arm.animation_data_create();arm.animation_data.action=action
    for frame in range(1,34):key_pose(frame,kind,(frame-1)/32*math.tau)
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
