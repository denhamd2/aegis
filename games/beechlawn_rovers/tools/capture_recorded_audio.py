#!/usr/bin/env python3
"""Capture both venue mixes through native Forward+ and the real AudioServer.

Uses a minimal 3D listening fixture; recorded_audio_smoke covers actual 11v11
event wiring. This measures signal output, not subjective listening quality.
"""
import argparse
import array
import json
import math
import os
import platform
import shutil
import subprocess
from pathlib import Path

from capture_native import PROJECT, read_display_number, run_bounded, stop


def verify(movie):
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(movie),'-vn',
        '-ac','1','-ar','22050','-f','f32le','pipe:1'], timeout=30)
    samples = array.array('f'); samples.frombytes(raw)
    def window(start, end):
        values = samples[round(start*22050):round(end*22050)]
        return dict(rms=math.sqrt(sum(v*v for v in values)/max(1,len(values))),
                    peak=max(abs(v) for v in values))
    report = dict(duration=len(samples)/22050,
        bed=window(.25,.65), kick=window(1.5,1.9), whistle=window(4,4.55),
        goal=window(7.5,9), chant_window=window(19,21), muted=window(24.55,24.95),
        peak=max(abs(v) for v in samples))
    assert report['duration'] >= 24.95, report
    assert report['bed']['rms'] > .0005, report
    assert report['kick']['peak'] > report['bed']['peak']*1.2, report
    assert report['whistle']['rms'] > report['bed']['rms']*1.1, report
    assert report['goal']['rms'] > report['bed']['rms']*1.25, report
    assert report['muted']['rms'] < .0001 and report['peak'] < .95, report
    report['result'] = 'PASS'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    display = None; display_log = None
    linux = platform.system() == 'Linux'
    try:
        if linux:
            executable = shutil.which('Xvfb') or '/workspace/aegis-render-tools/root/usr/bin/Xvfb'
            vulkan = Path.home()/'.local/opt/vulkan'
            icd = vulkan/'usr/share/vulkan/icd.d/lvp_icd.json'
            if icd.is_file():
                env['VK_ICD_FILENAMES'] = str(icd)
                env['LD_LIBRARY_PATH'] = str(vulkan/'usr/lib/x86_64-linux-gnu') + (':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
            env.setdefault('LP_NUM_THREADS', '4')
            read_fd, write_fd = os.pipe()
            display_log = (output/'display.log').open('wb')
            try:
                display = subprocess.Popen([executable,'-displayfd',str(write_fd),
                    '-screen','0','320x180x24','-nolisten','tcp','-ac'],env=env,
                    pass_fds=(write_fd,),stdout=display_log,stderr=subprocess.STDOUT,start_new_session=True)
            finally:
                os.close(write_fd)
            try:
                env['DISPLAY'] = read_display_number(read_fd)
            finally:
                os.close(read_fd)
        summaries = []
        for venue in ['kilmore_drive','rovers_arena']:
            folder = output/venue; folder.mkdir(exist_ok=True)
            movie = folder/'recorded_audio.avi'; movie.unlink(missing_ok=True)
            report_file = folder/'audio_fixture.json'; report_file.unlink(missing_ok=True)
            command = [shutil.which('godot'),'--path',str(PROJECT),'--rendering-method','forward_plus',
                '--resolution','320x180','--fixed-fps','60','--disable-vsync',
                '--audio-driver','Dummy','--write-movie',str(movie)]
            if linux:
                command += ['--display-driver','x11','--rendering-driver','vulkan']
            command += ['--script','res://scripts/review_recorded_audio.gd','--',
                '--capture-dir='+str(folder),'--venue='+venue]
            run_bounded(command, env, 60, folder/'capture.log')
            report = json.loads(report_file.read_text())
            assert report['rendering_method'] == 'forward_plus' and report['display_server'] != 'headless', report
            assert report['chants'] == (1 if venue == 'rovers_arena' else 0), report
            report['mix'] = verify(movie)
            (folder/'mix_report.json').write_text(json.dumps(report,indent=2)+'\n')
            summaries.append(report)
            print('RECORDED_MIX PASS:', venue, 'peak=',round(report['mix']['peak'],4),flush=True)
        (output/'manifest.json').write_text(json.dumps(dict(result='PASS',captures=summaries),indent=2)+'\n')
    finally:
        if display is not None: stop(display)
        if display_log is not None: display_log.close()


if __name__ == '__main__':
    main()
