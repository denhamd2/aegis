"""Remove only the retired football subsite from a saved shared Pages artifact.

Refuses a missing/invalid wrestling export; verifies every retained file hash
before the caller publishes the cleaned artifact. Never rebuilds wrestling.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def inventory(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()
            and p.relative_to(root).parts[0] != 'beechlawn-rovers'}


def retire(root, report_path):
    root = root.resolve()
    if report_path.resolve().is_relative_to(root):
        raise ValueError('Write the retirement proof outside the preserved site')
    for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
        path = root/name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError('Refusing to replace the site: missing wrestling file '+name)
    if (root/'index.wasm').read_bytes()[:4] != b'\0asm':
        raise RuntimeError('Refusing an invalid wrestling WASM export')
    before = inventory(root)
    football = root/'beechlawn-rovers'
    existed = football.exists() or football.is_symlink()
    if football.is_symlink():
        football.unlink()
    elif football.is_dir():
        shutil.rmtree(football)
    elif existed:
        football.unlink()
    after = inventory(root)
    if before != after or football.exists():
        raise RuntimeError('Retained Pages files changed during football removal')
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = {'result':'PASS', 'removed':'beechlawn-rovers/',
              'football_folder_was_present':existed,
              'retained_files':len(after), 'retained_sha256':after}
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print('Web retirement PASS:',len(after),'wrestling files unchanged')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('site',type=Path)
    parser.add_argument('report',type=Path)
    args = parser.parse_args()
    retire(args.site,args.report)
