"""Check exported files and the Mac bundle without claiming a Mac playtest."""
from pathlib import Path
import plistlib
import struct
import sys
import zipfile

root = Path(sys.argv[1])
for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
    path = root / 'web' / name
    assert path.is_file() and path.stat().st_size > 0, path
assert (root / 'web/index.wasm').read_bytes()[:4] == b'\0asm'
with zipfile.ZipFile(root / 'mac/Beechlawn-Rovers-Mac.zip') as archive:
    assert archive.testzip() is None, 'Corrupt Mac archive'
    plist_path = next(n for n in archive.namelist() if n.endswith('.app/Contents/Info.plist'))
    info = plistlib.loads(archive.read(plist_path))
    assert info['CFBundleIdentifier'] == 'com.denhamd2.beechlawnrovers'
    executable = plist_path.removesuffix('Info.plist') + 'MacOS/' + info['CFBundleExecutable']
    raw = archive.read(executable)
    assert raw[:4] == b'\xca\xfe\xba\xbe', 'Expected universal Mach-O'
    arch_count = struct.unpack_from('>I', raw, 4)[0]
    cpus = [struct.unpack_from('>I', raw, 8 + 20*i)[0] for i in range(arch_count)]
    assert 0x0100000C in cpus, 'Missing Apple Silicon executable'
    assert 0x01000007 in cpus, 'Missing Intel executable'
    assert any(n.endswith('.pck') for n in archive.namelist()), 'Missing game resources'
    assert not any('/references/' in n or '/tests/' in n for n in archive.namelist())
    print('Mac bundle PASS: universal arm64/x86_64, football identifier, resources, ZIP CRC')
print('Web export PASS: HTML, JS, WASM magic and nonempty PCK')
print('Scope: package checks only; no native Mac execution or performance acceptance.')
