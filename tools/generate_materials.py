"""Deterministic original seamless PBR maps; no downloaded image inputs."""
from pathlib import Path
import numpy as np
from PIL import Image
def gaussian_filter(a, sigma, mode='wrap'):
    sy,sx = (sigma,sigma) if np.isscalar(sigma) else sigma
    fy=np.fft.fftfreq(a.shape[0])[:,None]
    fx=np.fft.rfftfreq(a.shape[1])[None,:]
    return np.fft.irfft2(np.fft.rfft2(a)*np.exp(-2*np.pi**2*(sy*sy*fy*fy+sx*sx*fx*fx)),s=a.shape)

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
N = 512
rng = np.random.default_rng(4119)
y, x = np.mgrid[:N, :N].astype(float)

def noise(sigma):
    a = gaussian_filter(rng.random((N,N)), sigma, mode='wrap')
    return (a-a.min())/(a.max()-a.min())

def material(name, height, color, amount=.25, rough=.8, strength=3):
    h=(height-height.min())/(height.max()-height.min())
    rgb=np.clip(np.array(color)[None,None,:]*(1+amount*(h[:,:,None]-.5)),0,255)
    Image.fromarray(rgb.astype('uint8')).save(OUT/f'{name}_color.png')
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength
    norm=np.stack([-dx,-dy,np.ones_like(h)],-1)
    norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
    Image.fromarray(np.uint8(np.clip((norm*.5+.5)*255,0,255))).save(OUT/f'{name}_normal.png')
    Image.fromarray(np.uint8(np.clip(rough+(h-.5)*.15,0,1)*255)).save(OUT/f'{name}_rough.png')

grain = gaussian_filter(rng.random((N,N)),(32,.65),mode='wrap')*4
grain += noise(10)*.035+noise(.7)*.025
material('weathered_wood',grain,[134,123,104],.36,.9,1.2)
material('teak',grain,[151,116,76],.32,.68,.8)
stone=noise(14)*.6+noise(4)*.28+noise(.7)*.12
crack=np.power(np.clip(1-np.abs(np.sin(x*.035+noise(15)*8)),0,1),18)
material('granite',stone-crack*.12,[94,105,105],.65,.9,3.5)
sand=noise(3)*.3+noise(.4)*.3+np.sin(y*.12+noise(9)*4)*.04
material('sand',sand,[177,162,127],.16,.96,.6)
fabric=(np.sin(x*np.pi*.5)+np.sin(y*np.pi*.5))*.2+noise(2)*.2
material('fabric',fabric,[230,230,225],.13,.83,.5)
paint=noise(18)*.4+noise(1)*.1
material('paint',paint,[215,215,210],.15,.4,.6)
cloud=noise(23)*.5+noise(9)*.3+noise(3)*.2
Image.fromarray(np.uint8(cloud*255)).save(OUT/'cloud_noise.png')
water=np.sin(x*.10+noise(18)*4)*.25+np.sin(y*.16+noise(10)*3)*.25+noise(2)*.4
material('water',water,[100,128,140],.5,.25,3.5)
Image.fromarray(np.uint8(noise(5)*255)).save(OUT/'foam_noise.png')
print('Generated',len(list(OUT.glob('*.png'))),'original material maps')
