#!/usr/bin/env python3
"""Rebuild the recorded bank from hash-verified local sources (numpy/scipy/ffmpeg).

No network access. Obtain the files listed in assets/audio/provenance.json in
SOURCE_DIR first. Freesound inputs are public HQ MP3 previews, not original WAVs.
The unchanged Cool Rock recording and original UI click are outside this tool.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
        '-ar', str(RATE), '-ac', '2', '-f', 'f32le', 'pipe:1'], timeout=30)
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_dir', type=Path)
    args = parser.parse_args()
    folder = ROOT / 'assets/audio'
    provenance_path = folder / 'provenance.json'
    provenance = json.loads(provenance_path.read_text())
    sources = {}
    for source in provenance['recorded_sources']:
        path = args.source_dir / source['local_file']
        assert sha(path) == source['source_sha256'], path
        sources[source['id']] = decode(path)
    clips = []

    def emit(name, source, start=0, end=None, *, mono=True, lowpass=11000,
             peak=.65, rms=None, loop=False, trim=False, repeat=1):
        x = sources[source][round(start*RATE):round(end*RATE) if end else None].copy()
        if mono:
            x = x.mean(axis=1, keepdims=True)
        x -= x.mean(axis=0)
        x = sosfilt(butter(2, 70, 'highpass', fs=RATE, output='sos'), x, axis=0)
        x = sosfilt(butter(2, lowpass, 'lowpass', fs=RATE, output='sos'), x, axis=0)
        if trim:
            active = np.flatnonzero(np.max(np.abs(x), axis=1) > np.max(np.abs(x))*.055)
            x = x[max(0, active[0]-240):min(len(x), active[-1]+2400)]
        if loop:
            # Bake an equal-power wrap: the final sample meets the first at
            # the same point in the original recording, without a silent gap.
            n = RATE
            theta = np.linspace(0, np.pi/2, n)[:, None]
            wrap = x[-n:]*np.cos(theta) + x[:n]*np.sin(theta)
            x = np.concatenate((x[n:-n], wrap))
        else:
            n = min(240, len(x)//4)
            x[:n] *= np.linspace(0, 1, n)[:, None]
            n = min(round(.12*RATE), len(x)//4)
            x[-n:] *= np.linspace(1, 0, n)[:, None]
        if repeat > 1:
            gap = np.zeros((round(.16*RATE), x.shape[1]))
            x = np.concatenate([v for i in range(repeat) for v in ([gap, x] if i else [x])])
        gain = peak / max(float(np.max(np.abs(x))), 1e-8)
        if rms:
            gain = min(gain, rms/max(float(np.sqrt(np.mean(x*x))), 1e-8))
        x = np.asarray(x*gain, dtype='<f4')
        path = folder / (name + ('.ogg' if loop or not mono else '.wav'))
        codec = ['-c:a', 'libvorbis', '-q:a', '4'] if path.suffix == '.ogg' else ['-c:a', 'pcm_s16le']
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE),
            '-ac', str(x.shape[1]), '-i', 'pipe:0', *codec, str(path)],
            input=x.tobytes(), check=True, timeout=30)
        shipped = decode(path)
        clips.append(dict(file=path.name, source=source, excerpt_seconds=[start,end],
            mono=mono, highpass_hz=70, lowpass_hz=lowpass, loop_wrap_seconds=1 if loop else 0,
            trim_to_contact=trim, repeat=repeat, seconds=len(shipped)/RATE,
            peak=float(np.max(np.abs(shipped))), rms=float(np.sqrt(np.mean(shipped*shipped))),
            shipped_sha256=sha(path)))

    emit('kick', 'kick', trim=True)
    emit('kick_alt', 'kick_alt', trim=True)
    emit('pass', 'kick', trim=True, lowpass=5500, peak=.48)
    emit('pass_alt', 'kick_alt', trim=True, lowpass=5500, peak=.48)
    # Edited ball-contact Foley, not claims of an actual recorded human header.
    emit('header', 'kick_alt', trim=True, lowpass=1700, peak=.42)
    emit('catch', 'kick', trim=True, lowpass=2700, peak=.45)
    emit('post', 'post', lowpass=7500, peak=.6)
    emit('net', 'net', trim=True, peak=.4, lowpass=8000)
    emit('step', 'step', trim=True, peak=.24, lowpass=6500)
    emit('step_alt', 'step_two', trim=True, peak=.24, lowpass=6500)
    emit('whistle', 'whistle', trim=True, peak=.48)
    emit('whistle_full', 'whistle', trim=True, peak=.48, repeat=3)
    emit('stadium_bed', 'crowd', 14, 36, mono=False, rms=.09, loop=True)
    emit('park_bed', 'park', 5, 51, mono=False, rms=.035, loop=True)
    emit('rain_bed', 'rain', 3, 35, mono=False, rms=.06, loop=True)
    emit('stadium_goal', 'goal', 2.2, 18, mono=False, peak=.65, rms=.14)
    emit('stadium_reaction', 'crowd', 1.2, 8.5, mono=False, peak=.55, rms=.10)
    emit('stadium_chant', 'chant', 0, 14.7, mono=False, peak=.55, rms=.10)
    emit('park_goal', 'applause', .1, 8.9, mono=False, peak=.5, rms=.08)
    emit('park_reaction', 'applause', .5, 3.5, mono=False, peak=.4, rms=.06)
    provenance['recorded_clips'] = clips
    provenance_path.write_text(json.dumps(provenance, indent=2)+'\n')
    print(f'Recorded bank: {len(clips)} clips, {sum((folder/c["file"]).stat().st_size for c in clips)} bytes')


if __name__ == '__main__':
    main()
