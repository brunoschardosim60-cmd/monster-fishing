"""Download reproducible CC0 source files from Poly Haven's public asset API.
Only project-local, ignored source files are written; originals remain intact.
"""
from pathlib import Path
import urllib.request, json, hashlib, concurrent.futures
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'tools'/'asset-source'/'polyhaven'
IDS=['island_tree_01','island_tree_02','fern_02','coastal_cliff_02']
HEADERS={'User-Agent':'MonsterFishing-local-asset-preparation/1.0'}
def fetch(url,path,md5=None):
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists() and (not md5 or hashlib.md5(path.read_bytes()).hexdigest()==md5):return
    data=urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=180).read()
    if md5 and hashlib.md5(data).hexdigest()!=md5:raise ValueError('Checksum mismatch: '+url)
    path.write_bytes(data)
report=[]
for asset in IDS:
    meta=json.load(urllib.request.urlopen(urllib.request.Request('https://api.polyhaven.com/files/'+asset,headers=HEADERS)))
    item=meta['gltf']['1k']['gltf'];folder=BASE/asset
    tasks=[(item['url'],folder/(asset+'_1k.gltf'),item['md5'])]
    tasks += [(v['url'],folder/k,v['md5']) for k,v in item.get('include',{}).items()]
    # Preserve the original alpha channel where foliage uses cutout cards.
    for k,v in meta.get('blend',{}).get('1k',{}).get('blend',{}).get('include',{}).items():
        if '_alpha_' in k:tasks.append((v['url'],folder/k,v['md5']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda args:fetch(*args),tasks))
    report.append({'id':asset,'source':'https://polyhaven.com/a/'+asset,'license':'CC0-1.0','files':[{'url':u,'md5':m} for u,p,m in tasks]})
    print('DOWNLOADED',asset,flush=True)
(ROOT/'docs/asset-audit/polyhaven-sources.json').write_text(json.dumps(report,indent=2))
