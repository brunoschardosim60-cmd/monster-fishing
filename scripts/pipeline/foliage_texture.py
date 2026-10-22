"""Deterministic original pine frond alpha texture; no external image inputs."""
from PIL import Image, ImageDraw
from pathlib import Path
import random, math
random.seed(731)
im=Image.new('RGBA',(512,512),(0,0,0,0)); d=ImageDraw.Draw(im)
for branch in range(13):
    y=462-branch*30
    span=145*(1-branch/16)
    for side in [-1,1]:
        tip=(256+side*span,y-80)
        d.line([(256,y),tip],fill=(108,117,58,255),width=3)
        for k in range(14):
            t=k/14; x=256+(tip[0]-256)*t; yy=y+(tip[1]-y)*t
            for sign in [-1,1]:
                green=random.randint(145,215)
                end=(x+side*random.uniform(7,23), yy-random.uniform(15,31)+sign*15)
                d.line([(x,yy),end],fill=(green-25,green,green-55,255),width=3)
d.line([(256,475),(256,30)],fill=(130,133,75,255),width=4)
out=Path(__file__).resolve().parents[2]/'assets/textures/pine_frond.png'
im.save(out)
print(out)
