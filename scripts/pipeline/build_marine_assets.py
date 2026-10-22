"""Closed 3D fish and sea guardian meshes, with projected reference UVs.
Images supply surface detail; geometry supplies volume, fins and silhouettes.
"""
import bpy,math,pathlib,json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
reports=[]
def mat(name,color,tex=None,glow=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.use_backface_culling=False
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.28
    if tex:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/textures'/tex));m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    if glow:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=2.
    return m
atlas=mat('Generated marine reference projection',(1,1,1),'marine_reference_color.png')
dark=mat('Wet black eyes',(.006,.015,.02));silver=mat('Silver gill edging',(.3,.4,.42));fin=mat('Dark fin membrane',(.045,.07,.09));gold=mat('Tuna finlets',(.49,.37,.06));glow=mat('Cyan photophores',(.025,.65,.85),glow=True)
def mesh(name,verts,faces,material,uv_fn=None,uv_coords=None):
    me=bpy.data.meshes.new(name);me.from_pydata([(x,-z,y) for x,y,z in verts],[],faces);me.materials.append(material);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    uv=me.uv_layers.new()
    for p in me.polygons:
        p.use_smooth=True
        for li in p.loop_indices:
            vi=me.loops[li].vertex_index;v=verts[vi];uv.data[li].uv=uv_coords[vi] if uv_coords else (uv_fn(v) if uv_fn else (v[0]*.4,v[2]*.4))
    return o
def ellipsoid(name,center,size,material):
    vv=[];ff=[]
    for j in range(9):
        t=j/8*math.pi
        for k in range(16):
            a=k/16*math.tau;vv.append((center[0]+size[0]*math.cos(t),center[1]+size[1]*math.sin(t)*math.sin(a),center[2]+size[2]*math.sin(t)*math.cos(a)))
    for j in range(8):
        for k in range(16):a=j*16+k;b=j*16+(k+1)%16;ff.append((a,b,b+16,a+16))
    return mesh(name,vv,ff,material)
def export(path):
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
    dest=ROOT/path;dest.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True,export_animations=False)
    reports.append({'file':path,'triangles':tri})
    for o in objects:bpy.data.objects.remove(o,do_unlink=True)
def membrane(name,root_a,root_b,outline,material=fin):
    # A curved, slightly cambered membrane, with UVs following the fin rays.
    vv=[];ff=[];uvs=[];steps=18;radial=6
    a,b,c,d=[Vector(p) for p in outline]
    for j in range(steps+1):
        t=j/steps;edge=a*(1-t)**3+b*3*t*(1-t)**2+c*3*t*t*(1-t)+d*t**3
        root=Vector(root_a).lerp(Vector(root_b),t)
        for k in range(radial+1):
            v=k/radial;p=root.lerp(edge,v);p.z+=math.sin(v*math.pi)*math.sin(t*math.pi)*.012
            vv.append(tuple(p));uvs.append((t,v))
    for j in range(steps):
        for k in range(radial):
            i=j*(radial+1)+k;ff.append((i,i+1,i+radial+2,i+radial+1))
    return mesh(name,vv,ff,material,uv_coords=uvs)
for kind,center,sy,head,radius in [('mackerel',161,640,.146,.15),('tuna',516,690,.087,.22),('lanternfish',853,580,.137,.135)]:
    vv=[];ff=[]
    for j in range(49):
        t=j/48;x=.50-t*.99
        height=(math.sin(t*math.pi)**.75)*radius*(1.-t*.38)+.012
        width=height*.57
        for k in range(32):
            a=k/32*math.tau;vv.append((x,math.sin(a)*height,math.cos(a)*width))
    for j in range(48):
        for k in range(32):a=j*32+k;b=j*32+(k+1)%32;ff.append((a,b,b+32,a+32))
    ff.extend([tuple(range(31,-1,-1)),tuple(range(1536,1568))])
    uv=lambda p:(head+(.89-head)*(.50-p[0])/1.25,1.-(center-p[1]*sy)/1024)
    mesh(kind+' closed body',vv,ff,atlas,uv)
    membrane('Fin dorsal',(.22,radius*.76,0),(-.24,radius*.65,0),[(.22,radius*.76,0),(.13,radius+.18,0),(.12,radius+.09,0),(-.24,radius*.65,0)])
    for side in [-1,1]:
        membrane('Fin caudal',(-.47,0,0),(-.49,side*.018,0),[(-.54,0,0),(-.59,side*.05,0),(-.69,side*.24,0),(-.77,side*.25,0)])
    membrane('Fin anal',(-.18,-radius*.7,0),(-.40,-radius*.4,0),[(-.18,-radius*.7,0),(-.25,-radius-.14,0),(-.23,-radius-.05,0),(-.40,-radius*.4,0)])
    for side in [-1,1]:
        membrane('Fin pectoral',(.20,-.02,side*radius*.50),(.07,-.04,side*radius*.54),[(.20,-.02,side*radius*.5),(-.14,-.09,side*(radius+.09)),(-.24,-.11,side*(radius+.04)),(.07,-.04,side*radius*.54)])
        eye=.034 if kind=='lanternfish' else .022
        ellipsoid('Eye',(.36,.035,side*.065),(eye,eye,eye*.44),dark)
        if kind=='lanternfish':
            for j in range(11):ellipsoid('Photophore',(.28-j*.065,-.04,side*(.075-j*.004)),(.008,.008,.005),glow)
    if kind=='tuna':
        for j in range(6):
            x=-.19-j*.05;y=.13-j*.016
            mesh('Yellow finlet',[(x,y,0),(x-.028,y+.045,0),(x-.05,y-.008,0)],[(0,1,2)],gold)
    export('assets/fish/'+kind+'.glb')

# The guardian is 18 m across the wings; its side profile is a closed body.
skin=mat('Deep sea leather',(.08,.12,.16),'marine_skin_color.png')
ellipsoid('Guardian muscular body',(0,0,0),(3.2,.85,1.6),skin)
ellipsoid('Guardian tapered head',(2.9,-.05,0),(1.7,.48,.73),skin)
for side in [-1,1]:
    vv=[];ff=[]
    for j in range(25):
        t=j/24;z=side*(1.+8*t);front=1.5-3.5*t*t;back=-2.8+1.0*t
        for k in range(13):
            u=k/12;x=front*(1-u)+back*u;y=math.sin(u*math.pi)*(.45*(1-t)+.05)+.8*t*t
            vv.append((x,y,z))
    for j in range(24):
        for k in range(12):a=j*13+k;ff.append((a,a+1,a+14,a+13))
    mesh('Organic pectoral wing',vv,ff,skin)
    for j in range(20):
        t=j/20;ellipsoid('Wing photophore',(1.5-3.5*t*t,.08+.8*t*t+.05,side*(1+8*t)),(.05,.035,.035),glow)
    ellipsoid('Guardian eye',(3.8,.16,side*.55),(.18,.12,.07),dark)
vv=[];ff=[]
for j in range(41):
    t=j/40;x=-2.-9*t;r=.45*(1-t)+.025
    for k in range(16):a=k/16*math.tau;vv.append((x,math.sin(a)*r,math.cos(a)*r))
for j in range(40):
    for k in range(16):a=j*16+k;b=j*16+(k+1)%16;ff.append((a,b,b+16,a+16))
mesh('Long tapered guardian tail',vv,ff,skin)
for j in range(14):
    x=1.-j*.7;y=.78 if x>-2. else .35
    mesh('Dorsal bony ridge',[(x,y,-.16),(x+.25,y+.35,0),(x,y,.16),(x-.42,y,0)],[(0,1,2),(0,3,1),(1,3,2)],skin)
export('assets/monsters/abyssal_guardian.glb')
(ROOT/'docs/asset-audit/marine-art.json').write_text(json.dumps(reports,indent=2));print('MARINE_ART',reports,flush=True)
