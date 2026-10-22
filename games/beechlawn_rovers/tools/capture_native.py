#!/usr/bin/env python3
"""Capture playable football assets through native Godot Forward+.

Linux uses Xvfb and Vulkan (a software Vulkan adapter is sufficient for stills).
macOS uses its actual display and Godot's default native graphics driver.
Never falls back to Compatibility. These stills do not establish frame rate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import select
import shutil
import signal
import subprocess
import time

from PIL import Image, ImageStat

PROJECT = Path(__file__).resolve().parents[1]
IDENTITIES = {'shane':'shane_denham', 'john':'john_orourke', 'des':'bordeaux_09',
              'referee':'des_feeney_sr', 'away_keeper':'bordeaux_01', 'paddy':'paddy_mason'}


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=3)


def run_bounded(command, env, deadline, log, ready_files=()):
    # Stream diagnostics immediately so a compiling/failed scene is observable
    # while the bounded render is running, rather than only after timeout.
    with log.open('wb') as stream:
        process = subprocess.Popen(command, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        started, completed = time.monotonic(), None
        cleanup = 'normal'
        while process.poll() is None:
            if time.monotonic()-started > deadline:
                stop(process)
                raise RuntimeError(f'Native render exceeded {deadline}s; see {log}')
            # llvmpipe can hang during teardown after a successful synchronous
            # readback. Bound cleanup separately, requiring freshly saved
            # evidence and the scene's completion marker first.
            if ready_files and all(p.is_file() for p in ready_files) and b'BEECHLAWN_NATIVE_CAPTURE ' in log.read_bytes():
                completed = completed or time.monotonic()
                if time.monotonic()-completed > 10:
                    stop(process)
                    cleanup = 'terminated_after_saved_capture'
                    break
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass
    output = log.read_bytes()
    if (process.returncode and cleanup == 'normal') or any(marker in output for marker in
            (b'ERROR:', b'Parse Error:', b'Shader compilation failed')):
        raise RuntimeError(f'Native render failed; see {log}\n'+output[-4000:].decode(errors='replace'))
    return cleanup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--review-mode', choices=['movement','throw','net','montage','attack_home','attack_away','keeper_home','keeper_away'], help='Capture a native moving repair review')
    parser.add_argument('--match',action='store_true',help='Capture the actual 22-player match and broadcast camera')
    parser.add_argument('--players', nargs='+', choices=['shane','john','des','referee','away_keeper','paddy'],
                        default=['shane','john','des','referee'])
    parser.add_argument('--views', nargs='+', default=['portrait'], choices=[
        'portrait','threequarter_portrait','profile_portrait','front','back','profile','kit'])
    parser.add_argument('--pose', choices=['idle','sprint','pass','shot','turn','slide','get_up','keeper_set','keeper_save'])
    parser.add_argument('--frame', type=int, default=1)
    parser.add_argument('--resolution', default='1280x720')
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--xvfb', default=shutil.which('Xvfb'))
    parser.add_argument('--vulkan-root', type=Path, default=Path.home()/'.local/opt/vulkan')
    parser.add_argument('--deadline', type=int, default=150)
    parser.add_argument('--lighting', choices=['match','soft','sun','shade'], default='match')
    parser.add_argument('--sky', choices=['match','review'], default='match')
    args = parser.parse_args()
    if args.review_mode:
        args.match = True
    if not args.godot:
        parser.error('Godot executable is required')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    # A failed rerun must never leave an earlier PASS manifest looking current.
    (args.output/'manifest.json').unlink(missing_ok=True)
    env = os.environ.copy()
    display_process = None
    display_log = None
    linux = platform.system() == 'Linux'
    try:
        if linux:
            # This is a machine-installed tool, separate from both game projects.
            fallback = Path('/workspace/aegis-render-tools/root/usr/bin/Xvfb')
            executable = args.xvfb or (str(fallback) if fallback.is_file() else None)
            if not executable:
                parser.error('Xvfb is required on Linux; set --xvfb to its executable')
            library = args.vulkan_root/'usr/lib/x86_64-linux-gnu'
            icd = args.vulkan_root/'usr/share/vulkan/icd.d/lvp_icd.json'
            if icd.is_file():
                env['VK_ICD_FILENAMES'] = str(icd)
                env['LD_LIBRARY_PATH'] = str(library)+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
            env.setdefault('LP_NUM_THREADS','4')
            read_fd, write_fd = os.pipe()
            display_log = (args.output/'display.log').open('wb')
            try:
                display_process = subprocess.Popen([executable,'-displayfd',str(write_fd),'-screen','0',
                    args.resolution+'x24','-nolisten','tcp','-ac'],env=env,pass_fds=(write_fd,),
                    stdout=display_log,stderr=subprocess.STDOUT,start_new_session=True)
            finally:
                os.close(write_fd)
            try:
                if not select.select([read_fd],[],[],8)[0]:
                    raise RuntimeError('Xvfb did not provide a display within 8s')
                number = os.read(read_fd,64).decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Xvfb failed; see display.log')
                env['DISPLAY'] = ':'+number
            finally:
                os.close(read_fd)
        captures = []
        selections = [('match','broadcast')] if args.match else [(p,v) for p in args.players for v in args.views]
        for player,view in selections:
            stem = player+'_'+view
            command = [args.godot,'--path',str(PROJECT),'--rendering-method','forward_plus',
                       '--resolution',args.resolution,'--fixed-fps','60','--disable-vsync',
                       '--audio-driver','Dummy']
            if linux:
                command += ['--display-driver','x11','--rendering-driver','vulkan']
            command += (['--script','res://scripts/review_native_repairs.gd' if args.review_mode else 'res://scripts/review_native_match.gd'] if args.match else ['res://scenes/review/shane_asset_review.tscn'])
            command += ['--',
                '--capture-dir='+str(args.output),'--player='+player,'--view='+view,
                '--lighting='+args.lighting,'--sky='+args.sky,'--clean=1']
            if args.pose and not args.match:
                command += ['--pose='+args.pose,'--frame='+str(args.frame)]
            if args.review_mode:
                command += ['--review-mode='+args.review_mode]
            started = time.monotonic()
            image_path = args.output/(stem+'.png')
            report_path = args.output/(stem+'.json')
            image_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)
            cleanup = run_bounded(command,env,args.deadline,args.output/(stem+'.log'),
                                  (image_path,report_path))
            report = json.loads(report_path.read_text())
            if report['rendering_method'] != 'forward_plus' or report['display_server'].lower() == 'headless':
                raise RuntimeError('Capture used the wrong rendering pipeline')
            if not args.match and report.get('player_id') != IDENTITIES[player]:
                raise RuntimeError('Capture selected the wrong player identity')
            if args.match and [report.get(k) for k in ('home_players','away_players','officials')] != [11,11,1]:
                raise RuntimeError('Match capture has an incomplete roster')
            with Image.open(image_path) as image:
                stats = ImageStat.Stat(image.convert('L'))
                if stats.stddev[0] < 2:
                    raise RuntimeError('Blank/flat native capture: '+str(image_path))
            captures.append({'image':image_path.name,'report':report_path.name,
                'sha256':hashlib.sha256(image_path.read_bytes()).hexdigest(),
                'process_cleanup':cleanup,
                'capture_seconds':round(time.monotonic()-started,2),
                'command':command})
            print('NATIVE_CAPTURE PASS',stem,report['adapter'],flush=True)
        manifest = {'result':'PASS','captures':captures,'platform':platform.platform(),
                    'scope':'Forward+ appearance stills; software Vulkan does not measure Mac performance.'}
        (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    finally:
        if display_process is not None:
            stop(display_process)
        if display_log is not None:
            display_log.close()


if __name__ == '__main__':
    main()
