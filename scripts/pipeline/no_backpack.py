# Finds the backpack modelled into the survivalist body (raw dump of its single surface, see bake_no_backpack.gd)
# and writes assets/characters/no_backpack.json: faces to drop and back vertices pressed flat.
import numpy as np,trimesh,json
b=open('/home/claude/work/raw/char_0.bin','rb').read()
nv,ni=np.frombuffer(b[:8],np.uint32); V=np.frombuffer(b[8:8+nv*12],np.float32).reshape(-1,3).copy(); I=np.frombuffer(b[8+nv*12:8+nv*12+ni*4],np.int32).reshape(-1,3)
key=np.round(V*2000).astype(np.int64)
_,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.reshape(-1)
F=inv[I]
mm=trimesh.Trimesh(np.zeros((inv.max()+1,3)),F,process=False)
lab=trimesh.graph.connected_component_labels(mm.face_adjacency,len(F))
cent=V[I].mean(1)
remove=np.zeros(len(I),bool)
big=np.bincount(lab).argmax()
for k in range(lab.max()+1):
    f=lab==k
    if k==big or f.sum()>1500: continue
    c=cent[f].mean(0); lo=V[I[f]].reshape(-1,3).min(0); hi=V[I[f]].reshape(-1,3).max(0)
    back = c[2]>0.06 and 0.95<c[1]<1.65
    strap = 1.15<c[1]<1.6 and 0.04<abs(c[0])<0.26 and (hi[1]-lo[1])>0.15 and f.sum()<400
    buckle = 1.25<c[1]<1.5 and c[2]<-0.2 and f.sum()<200
    if back or strap or buckle: remove[f]=True; print('remove comp',k,f.sum(),c.round(2))
# flatten the bag that is fused with the jacket
newV=V.copy()
fb=lab==big
vb=np.unique(I[fb].reshape(-1))
sel=vb[(V[vb,2]>0.055)&(V[vb,1]>0.98)&(V[vb,1]<1.62)&(np.abs(V[vb,0])<0.27)]
# target back surface: gentle curve
y=V[sel,1]; x=V[sel,0]
back=0.05+0.02*np.cos((y-1.3)/0.35*np.pi/2).clip(0)-0.06*(x/0.27)**2
newV[sel,2]=np.minimum(V[sel,2],back+ (V[sel,2]-back).clip(0)*0.04)
print('flattened',len(sel),'removed faces',remove.sum())
keep=~remove
out={'remove_faces':np.where(remove)[0].tolist(),'moved':sel.tolist(),'z':newV[sel,2].round(5).tolist()}
json.dump(out,open('/home/claude/work/monster-fishing/assets/characters/no_backpack.json','w'))
m=trimesh.Trimesh(newV,I[keep][:,[0,2,1]],process=False)
