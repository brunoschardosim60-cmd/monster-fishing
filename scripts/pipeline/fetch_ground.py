from pathlib import Path
import urllib.request,json,hashlib,concurrent.futures
ROOT=Path(__file__).resolve().parents[2]
HEADERS={'User-Agent':'MonsterFishing-local-asset-preparation/1.0'}
reports=[];jobs=[]
for asset,target in [('forest_ground_04','forest_floor'),('aerial_grass_rock','meadow'),('cobblestone_floor_01','cobblestone')]:
    meta=json.load(urllib.request.urlopen(urllib.request.Request('https://api.polyhaven.com/files/'+asset,headers=HEADERS)))
    for channel,suffix in [('Diffuse','color'),('nor_gl','normal'),('Rough','rough')]:
        item=meta[channel]['1k']['jpg'];path=ROOT/'assets/textures'/(target+'_'+suffix+'.jpg')
        jobs.append((item['url'],path,item['md5']))
        reports.append({'source':item['url'],'asset':asset,'license':'CC0-1.0','file':str(path.relative_to(ROOT)),'md5':item['md5']})
def download(job):
    url,path,digest=job
    data=urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=90).read()
    assert hashlib.md5(data).hexdigest()==digest
    path.write_bytes(data)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(download,jobs))
(ROOT/'docs/asset-audit/ground-sources.json').write_text(json.dumps(reports,indent=2))
print('GROUND_TEXTURES',len(jobs))
