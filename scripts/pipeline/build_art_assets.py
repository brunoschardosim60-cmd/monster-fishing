"""Author real mesh assets from the generated design references, using Blender.
No image-to-mesh service is assumed. Source images remain unmodified.
"""
import bpy, math, random, pathlib, json
from mathutils import Vector, noise
ROOT=pathlib.Path(__file__).resolve().parents[2]
random.seed(812)
bpy.ops.wm.read_factory_settings(use_empty=True)
reports=[]
def material(name,color,texture=None,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.86;bs.inputs['Metallic'].default_value=metal
    if texture:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/textures'/texture));m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    return m
wood=material('Weathered timber',(.35,.27,.18),'weathered_wood_color.png')
clay=material('Warm terracotta',(.32,.12,.065),'lime_plaster_color.png')
clay_bs=clay.node_tree.nodes.get('Principled BSDF')
clay_tex=next(n for n in clay.node_tree.nodes if n.type=='TEX_IMAGE')
clay_tint=clay.node_tree.nodes.new('ShaderNodeMixRGB');clay_tint.blend_type='MULTIPLY';clay_tint.inputs[0].default_value=1.;clay_tint.inputs[2].default_value=(.40,.16,.075,1.)
clay.node_tree.links.new(clay_tex.outputs['Color'],clay_tint.inputs[1]);clay.node_tree.links.new(clay_tint.outputs[0],clay_bs.inputs['Base Color'])
stone=material('Coastal granite',(.55,.53,.48),'cliff_granite_color.png')
canvas=material('Fisher navy canvas',(.08,.12,.16),'fisher_canvas_color.png')
leather=material('Weathered brown leather',(.16,.09,.045),'weathered_wood_color.png')
bronze=material('Aged brass',(.30,.20,.08),metal=.7)
shutter=material('Salt worn teal shutters',(.10,.25,.25))
def coord(p):return (p[0],-p[2],p[1])
class Batch:
    def __init__(self,name,mat):self.name=name;self.mat=mat;self.v=[];self.f=[]
    def mesh(self,vertices,faces):
        off=len(self.v);self.v.extend(coord(p) for p in vertices);self.f.extend(tuple(i+off for i in face) for face in faces)
    def box(self,c,s,bevel=0):
        # Chamfered corners add a readable edge at human scale.
        x,y,z=c;w,h,d=[a*.5 for a in s]
        if bevel:
            r=min(bevel,w*.4,d*.4)
            outline=[(-w+r,-d),(w-r,-d),(w,-d+r),(w,d-r),(w-r,d),(-w+r,d),(-w,d-r),(-w,-d+r)]
            vv=[(x+a,y+b,z+c) for b in [-h,h] for a,c in outline]
            ff=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
        else:
            vv=[(x+a*w,y+b*h,z+c*d) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
            ff=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        self.mesh(vv,ff)
    def ellipsoid(self,c,s,rings=10,sides=24):
        vv=[];ff=[]
        for j in range(rings+1):
            t=j/rings*math.pi
            for k in range(sides):
                a=k/sides*math.tau
                vv.append((c[0]+s[0]*math.sin(t)*math.cos(a),c[1]+s[1]*math.cos(t),c[2]+s[2]*math.sin(t)*math.sin(a)))
        for j in range(rings):
            for k in range(sides):a=j*sides+k;b=j*sides+(k+1)%sides;ff.append((a,b,b+sides,a+sides))
        self.mesh(vv,ff)
    def object(self):
        mesh=bpy.data.meshes.new(self.name);mesh.from_pydata(self.v,[],self.f);mesh.materials.append(self.mat);mesh.update()
        uv=mesh.uv_layers.new()
        for p in mesh.polygons:
            p.use_smooth=('cap' in self.name.lower() or 'canvas backpack' in self.name.lower() or self.name=='Granite sea arch')
            axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
            for li in p.loop_indices:
                v=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]],v[axes[1]])
        obj=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(obj);return obj
def export(name,batches):
    objects=[b.object() for b in batches if b.v]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    dest=ROOT/name;dest.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    reports.append({'file':name,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)})
    for o in objects:bpy.data.objects.remove(o,do_unlink=True)

# A fitted 8 x 7 m shell enhancement: open door stays 1.8 m, no fake interior.
roof=Batch('Individual curved terracotta tiles',clay);trim=Batch('Roof rafters and porch joinery',wood);masonry=Batch('Irregular masonry footings',stone);blinds=Batch('Open timber shutters',shutter)
for side in [-1,1]:
    for row in range(14):
        t=row/14.;x=side*(.02+4.48*t);y=5.16-1.7*t
        for col in range(29):
            z=-4.+col*.28;vv=[];ff=[]
            for along in [0.,.38]:
                for k in range(7):
                    a=k/6*math.pi
                    vv.append((x+side*along,y-along*1.7/4.5+math.sin(a)*.075+random.uniform(-.007,.007),z+(k/6)*.29))
            for k in range(6):ff.append((k,k+1,k+8,k+7) if side>0 else (k+7,k+8,k+1,k))
            roof.mesh(vv,ff)
    for z in [-3.92,3.92]:
        for j in range(12):
            t=(j+.5)/12;trim.box((side*4.5*t,5.03-1.7*t,z),(.39,.13,.17),.035)
    for x in [-3.9,3.9]:
        for y in [.22,.52,.82]:
            for j in range(11):masonry.box((x,y,-3.35+j*.67),(.37,.28,.62),.05)
for side in [-1,1]:
    for j in range(5):
        x=side*(1.23+j*.56)
        for y in [.22,.53,.82]:masonry.box((x,y,-3.56),(.53,.28,.28),.04)
    for window_x in [-2.48,2.48]:
        x=window_x+side*.82
        for j in range(5):blinds.box((x+side*j*.085,1.75,-3.61-j*.04),(.075,1.46,.07),.01)
        for y in [1.25,2.25]:trim.box((x+side*.17,y,-3.67),(.47,.06,.065),.01)
for side in [-1,1]:
    for y in [.55,1.2,1.85,2.5]:trim.box((side*.96,y,-3.62),(.16,.06,.13),.01)
# Dormer front centered above the entry, details rise above the actual ridge slope.
for x in [-.66,.66]:trim.box((x,4.47,-3.8),(.12,1.15,.12),.02)
trim.box((0,4.0,-3.8),(1.45,.14,.16),.02);trim.box((0,4.94,-3.8),(1.45,.14,.16),.02)
for x in [-.36,0,.36]:blinds.box((x,4.46,-3.77),(.25,.84,.08),.025)
export('assets/environment/architecture/coastal_house_details.glb',[roof,trim,masonry,blinds])

# A fractured stone arch, 104 m wide, 71 m high, with an actual open passage.
arch=Batch('Granite sea arch',stone);vv=[];ff=[]
for j in range(101):
    theta=j/100*math.pi;arch_curve=max(0.,math.sin(theta));cx=40*math.cos(theta)+7*arch_curve;cy=-7+59*arch_curve**.78+5*arch_curve*math.sin(theta*3.)
    outward=Vector((math.cos(theta),math.sin(theta),0))
    for k in range(24):
        a=k/24*math.tau;r=10.+3.*abs(math.cos(theta))+2.5*math.sin(theta*3.)
        p=Vector((cx,cy,0))+outward*(math.cos(a)*r)+Vector((0,0,math.sin(a)*14))
        n=noise.noise_vector(Vector((p.x*.15,p.y*.15,p.z*.15)))
        p+=n*2.5;p.x+=math.sin(p.y*.43)*.55
        vv.append(tuple(p))
for j in range(100):
    for k in range(24):a=j*24+k;b=j*24+(k+1)%24;ff.append((a,b,b+24,a+24))
ff.append(tuple(range(23,-1,-1)));ff.append(tuple(range(2400,2424)))
arch.mesh(vv,ff);export('assets/environment/geology/aurora_sea_arch.glb',[arch])

# Accessories are actual geometry, attached to head/chest bones in Godot.
cap=Batch('Navy fisher cap crown',canvas);cap.ellipsoid((0,1.806,-.012),(.137,.069,.134),10,32)
cap.ellipsoid((0,1.765,-.14),(.143,.014,.107),5,32)
band=Batch('Leather cap band',leather);band.ellipsoid((0,1.764,-.005),(.139,.018,.137),4,32)
badge=Batch('Brass cap badge',bronze);badge.ellipsoid((0,1.789,-.139),(.018,.012,.004),5,16)
for batch in [cap,band,badge]:batch.v=[(x,y,z-.035) for x,y,z in batch.v]
export('assets/characters/accessories/fisher_cap.glb',[cap,band,badge])
bag=Batch('Waxed canvas backpack',canvas);bag.ellipsoid((0,1.29,.255),(.245,.28,.12),12,24)
bag.ellipsoid((0,1.5,.28),(.25,.10,.12),8,24)
for side in [-1,1]:bag.ellipsoid((side*.23,1.21,.25),(.07,.12,.10),8,16)
straps=Batch('Leather backpack straps',leather);buckles=Batch('Brass backpack hardware',bronze)
for side in [-1,1]:
    straps.box((side*.14,1.29,.371),(.035,.47,.018),.006)
    for y in [1.19,1.4]:
        buckles.box((side*.14,y,.387),(.057,.013,.015),.004)
        for x in [-.025,.025]:buckles.box((side*.14+x,y+.021,.387),(.008,.05,.015),.002)
export('assets/characters/accessories/fisher_backpack.glb',[bag,straps,buckles])
(ROOT/'docs/asset-audit/authored-world-art.json').write_text(json.dumps(reports,indent=2))
print('AUTHORED_ART',json.dumps(reports),flush=True)
