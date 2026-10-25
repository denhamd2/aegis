"""Fetch a pinned, licensed Rocketbox subset with bounded individual requests.

Raw FBX/TGA stay in a scratch cache; only authored football exports enter git.
Run with Python, not Blender. Downloads are atomic and checked against Git blobs.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.request

COMMIT = '0943055db6ec570bcef9f2c8b41c9e5467c808f9'
AVATARS = ('Male_Adult_01','Male_Adult_04','Male_Adult_06','Male_Adult_07',
           'Male_Adult_09','Male_Adult_10','Male_Adult_11','Female_Adult_03',
           'Female_Adult_07','Female_Adult_08','Female_Adult_12','Female_Adult_13')
CLIPS = ('sit_chair_idle_neutral_01','sit_chair_idle_relaxed_01',
         'sit_chair_breathe_01','claphands_01','cheer_01','idle_neutral_01')

def main():
    root = Path(os.environ.get('ROCKETBOX_DIR','/tmp/beechlawn-rocketbox'))
    root.mkdir(parents=True, exist_ok=True)
    tree = json.loads(subprocess.check_output(['gh','api',
        f'repos/microsoft/Microsoft-Rocketbox/git/trees/{COMMIT}?recursive=1'], timeout=45))
    prefix = 'Assets/Animations/all_animations_max_motextr_static/'
    required = {'LICENSE.md'} | {prefix+g+'_'+c+'.max.fbx' for c in CLIPS for g in ('m','f')}
    selected = []
    for entry in tree['tree']:
        name = entry['path']
        avatar = next((a for a in AVATARS if name.startswith('Assets/Avatars/Adults/'+a+'/')),None)
        if name in required or (avatar and (name.endswith('/Export/'+avatar+'.fbx') or name.endswith('_color.tga'))):
            selected.append(entry)
    assert required.issubset({e['path'] for e in selected})
    assert all(any(e['path'].endswith('/Export/'+a+'.fbx') for e in selected) for a in AVATARS)
    def fetch(entry):
        target = root/entry['path']
        def valid(data):
            return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==entry['sha']
        if target.exists() and valid(target.read_bytes()): return entry['path'],'cached'
        target.parent.mkdir(parents=True, exist_ok=True)
        url = 'https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/'+COMMIT+'/'+entry['path']
        data = urllib.request.urlopen(url,timeout=45).read()
        assert valid(data), 'Source blob mismatch: '+entry['path']
        temporary = target.with_suffix(target.suffix+'.part')
        temporary.write_bytes(data);temporary.replace(target)
        return entry['path'],len(data)
    with ThreadPoolExecutor(max_workers=4) as pool:
        for future in as_completed([pool.submit(fetch,e) for e in selected]):
            name,size = future.result();print('SUPPORTER_SOURCE',name,size,flush=True)
    (root/'source_manifest.json').write_text(json.dumps({'commit':COMMIT,'files':selected},indent=2)+'\n')
    print('SUPPORTER_SOURCES_READY',len(selected),str(root),flush=True)

if __name__=='__main__': main()
