#!/usr/bin/env python3
"""Reject Ogg playback/resource leaks on normal SceneTree shutdown."""
import os
from pathlib import Path
import subprocess
import sys

project = Path(__file__).resolve().parents[1]
for mode in sys.argv[1:] or ['park', 'stadium', 'rain', 'music']:
    result = subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless',
        '--verbose', '--path', str(project), '--script',
        'res://tests/audio_shutdown_probe.gd', '--', '--audio-probe='+mode],
        capture_output=True, text=True, timeout=45)
    output = result.stdout+result.stderr
    assert result.returncode == 0 and 'AUDIO_SHUTDOWN probe='+mode in output, output[-4000:]
    assert not any(s in output for s in ['ERROR:', 'leaked at exit', 'Leaked instance:']), output[-4000:]
    print('AUDIO_SHUTDOWN PASS:', mode, flush=True)
if not sys.argv[1:]:
    for venue in ['kilmore_drive', 'rovers_arena']:
        result = subprocess.run([os.environ.get('GODOT_BIN', 'godot'), '--headless',
            '--path', str(project), '--script', 'res://tests/package_startup_probe.gd',
            '--', '--venue='+venue], capture_output=True, text=True, timeout=45)
        output = result.stdout+result.stderr
        assert result.returncode == 0 and 'BEECHLAWN_PACKAGE_STARTUP_CLOSE venue='+venue in output, output[-4000:]
        assert 'ERROR:' not in output and 'leaked at exit' not in output, output[-4000:]
        print('AUDIO_SHUTDOWN actual 11v11 PASS:', venue, flush=True)
