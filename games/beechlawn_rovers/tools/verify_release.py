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
import re

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
        for venue in ['kilmore_drive', 'rovers_arena']:
            for ball in ['ucl_26_27_league', 'worn_sunday_league']:
                # Use the application's window-close path so the AudioServer
                # gets main-thread updates to drain Ogg playback (Godot #76745).
                # Abrupt --quit-after tears down after the final server update.
                startup_probe = Path(__file__).resolve().parents[1]/'tests/package_startup_probe.gd'
                startup = subprocess.run(['godot','--headless','--main-pack',str(path),
                    '--script',str(startup_probe),'--','--venue='+venue,'--ball='+ball],
                    capture_output=True,text=True,timeout=45)
                output = startup.stdout+startup.stderr
                assert startup.returncode == 0 and 'ERROR:' not in output, output
                assert 'BEECHLAWN_MATCH_READY actors=22 officials=1 venue='+venue+' ball='+ball in output, output
                assert 'BEECHLAWN_PACKAGE_STARTUP_CLOSE venue='+venue in output, output
                print('Packaged match startup PASS:', venue, ball, '(22 players + referee)')
        # Validate the new resources through the actual pack, including JSON,
        # signed EXRs, the supporter MIT license and transparent tifo texture.
        for name in ['graphics_budget_smoke.gd','frame_profiler_smoke.gd',
                     'supporter_crowd_smoke.gd','stadium_presentation_smoke.gd','pitch_audio_smoke.gd','recorded_audio_smoke.gd','free_kick_planner_smoke.gd','free_kick_contact_smoke.gd','left_strike_smoke.gd','ai_attack_choice_smoke.gd']:
            source_probe=Path(__file__).resolve().parents[1]/'tests'/name
            result=subprocess.run(['godot','--headless','--main-pack',str(path),
                '--script',str(source_probe)],capture_output=True,text=True,timeout=60)
            text=result.stdout+result.stderr
            clean='\n'.join(line for line in text.splitlines() if not re.match(r'^ERROR: \d+ resources? still in use at exit',line))
            assert result.returncode==0 and 'ERROR:' not in clean,text
            print('Packaged feature probe PASS:',name)
        # The probe stays outside the shipped game. Its res:// scene/classes
        # resolve through the actual exported PCK, including receive JSON/GLB.
        probe = Path(__file__).resolve().parents[1]/'tests/moving_receive_smoke.gd'
        for venue in ['kilmore_drive', 'rovers_arena']:
            contact = subprocess.run(['godot','--headless','--main-pack',str(path),
                '--script',str(probe),'--','--venue='+venue],
                capture_output=True,text=True,timeout=45)
            output = contact.stdout+contact.stderr
            clean = '\n'.join(line for line in output.splitlines() if not re.match(r'^ERROR: \d+ resources? still in use at exit',line))
            assert contact.returncode == 0 and 'ERROR:' not in clean, output
            assert 'MOVING_RECEIVE_FIRST_EVENT [&"first_touch"]' in output, output
            print('Packaged live receive PASS:',venue,'(selected boot and physical first touch)')
    print('Mac bundle PASS: universal arm64/x86_64, football identifier, resources, ZIP CRC')
print('Scope: package checks only; no native Mac execution or performance acceptance.')
