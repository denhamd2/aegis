"""Check the universal Mac bundle without claiming a Mac playtest."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import plistlib
import struct
import sys
import zipfile

root = Path(sys.argv[1])
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
    # Run the actual exported resource pack with the matching Linux engine.
    # This verifies packaged GDScript/resources/metadata, not the Mac executable.
    expected = json.loads((Path(__file__).resolve().parents[1]/'data/build_info.json').read_text())
    assert info['CFBundleShortVersionString'] == expected['version']
    pack = next(n for n in archive.namelist() if n.endswith('.pck'))
    with tempfile.TemporaryDirectory(prefix='beechlawn-package-') as temporary:
        path = Path(temporary)/'match.pck'
        with archive.open(pack) as source, path.open('wb') as target:
            shutil.copyfileobj(source,target)
        result = subprocess.run(['godot','--headless','--main-pack',str(path),'--','--print-build-info'],capture_output=True,text=True,timeout=30)
        assert result.returncode == 0, result.stdout+result.stderr
        line = next((line for line in result.stdout.splitlines() if line.startswith('BEECHLAWN_BUILD_INFO ')),None)
        assert line, result.stdout+result.stderr
        actual = json.loads(line.removeprefix('BEECHLAWN_BUILD_INFO '))
        assert actual == expected, (actual,expected)
        assert len(actual['source_sha']) == 40 and actual['packaged_utc'].endswith(' UTC')
        (root/'mac/build-info.json').write_text(json.dumps(actual,indent=2)+'\n')
        print('Exported pack identity PASS:',json.dumps(actual))
    print('Mac bundle PASS: universal arm64/x86_64, football identifier, resources, ZIP CRC')
print('Scope: package checks only; no native Mac execution or performance acceptance.')
