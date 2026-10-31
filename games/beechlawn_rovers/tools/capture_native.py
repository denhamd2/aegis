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


PROJECT = Path(__file__).resolve().parents[1]
IDENTITIES = {'shane':'shane_denham', 'john':'john_orourke', 'des':'bordeaux_09',
              'robbie':'robbie_roden', 'david':'david_murray',
              'referee':'des_feeney_sr', 'away_keeper':'bordeaux_01', 'paddy':'paddy_mason'}


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=3)


def peak_rss_kib(pid):
    """Linux process high-water RSS; unavailable on other platforms."""
    try:
        for line in Path(f'/proc/{pid}/status').read_text().splitlines():
            if line.startswith('VmHWM:'):
                return int(line.split()[1])
    except (FileNotFoundError, PermissionError, ValueError):
        pass
    return None


def run_bounded(command, env, deadline, log, ready_files=()):
    # Stream diagnostics immediately so a compiling/failed scene is observable
    # while the bounded render is running, rather than only after timeout.
    with log.open('wb') as stream:
        process = subprocess.Popen(command, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        started, completed = time.monotonic(), None
        cleanup = 'normal'
        run_bounded.peak_rss_kib = None
        while process.poll() is None:
            measured = peak_rss_kib(process.pid) if getattr(process,'pid',None) is not None else None
            if measured is not None:
                run_bounded.peak_rss_kib = max(run_bounded.peak_rss_kib or 0, measured)
            if completed is None and time.monotonic()-started > deadline:
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


def read_display_number(fd, timeout=8):
    # Xvfb can write digits and the newline separately. Closing the read end
    # after only digits gives its next write EPIPE and kills the ready server.
    deadline = time.monotonic()+timeout
    line = b''
    while b'\n' not in line:
        remaining = deadline-time.monotonic()
        if remaining <= 0 or not select.select([fd],[],[],remaining)[0]:
            raise RuntimeError('Xvfb did not provide a complete display line within 8s')
        chunk = os.read(fd,64)
        if not chunk:
            raise RuntimeError('Xvfb closed its display pipe before readiness; see display.log')
        line += chunk
    number = line.split(b'\n',1)[0].decode().strip()
    if not number.isdigit():
        raise RuntimeError('Xvfb provided an invalid display; see display.log')
    return ':'+number


def main():
    from PIL import Image, ImageStat
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--review-mode', choices=['receive','receive_broadcast','stride_brake','stride_review','stride_turn','keeper_full_dives','keeper_high_shots','keeper_claim_home','keeper_claim_away','keeper_distribution','p1_debug','skills','skills_moving','keeper_dive_home','keeper_dive_away','keeper_high_home','outro','audio','free_kick','presentation','movement','throw','net','montage','attack_home','attack_away','keeper_home','keeper_away','cross_home','cross_away','cross_duel_home','cross_duel_away','header_close','chest_close','volley_close','half_volley_close','cross_driven_home','cross_driven_away','cross_lofted_home','cross_early_home','shot_finesse','shot_power','shot_low','crowd'], help='Capture a native moving repair review')
    parser.add_argument('--verbose', action='store_true', help='Include engine resource diagnostics')
    parser.add_argument('--ablation', choices=['none','scattering','transmittance','near_heads','pose','morphs','normal_maps','sun_shadows','shadow_bias','close_shadows'], default='none', help='Explicit portrait-only diagnostic; recorded in evidence')
    parser.add_argument('--setup-preview', action='store_true', help='Also capture the actual venue/control options')
    parser.add_argument('--venue', choices=['kilmore_drive','rovers_arena'], default='kilmore_drive')
    parser.add_argument('--venue-view', choices=['broadcast','wide','detail','all','corners','exterior','pitch','ball','turf'], default='broadcast')
    parser.add_argument('--ball', choices=['ucl_26_27_league','worn_sunday_league'], default='ucl_26_27_league')
    parser.add_argument('--free-kick-style', choices=['standard','finesse','power','low'], default='standard')
    parser.add_argument('--free-kick-view', choices=['wide','contact','prepare'], default='wide')
    parser.add_argument('--graphics', choices=['balanced_60','custom'], default='balanced_60', help='Explicit graphics profile for repeatable native evidence')
    parser.add_argument('--weather', choices=['sunny','cloudy','rain','mist'], default='sunny')
    parser.add_argument('--project', type=Path, default=PROJECT, help='Explicit isolated football snapshot for before/after review')
    parser.add_argument('--receive-baseline', action='store_true')
    parser.add_argument('--match',action='store_true',help='Capture the actual 22-player match and broadcast camera')
    parser.add_argument('--players', nargs='+', choices=['shane','john','des','referee','robbie','david','away_keeper','paddy'],
                        default=['shane','john','des','referee'])
    parser.add_argument('--views', nargs='+', default=['portrait'], choices=[
        'portrait','head_detail','threequarter_portrait','threequarter_opposite',
        'profile_portrait','profile_opposite','rear_portrait','front','back','profile','kit'])
    parser.add_argument('--pose', choices=['idle','sprint','pass','shot','turn','slide','get_up','keeper_set','keeper_save'])
    parser.add_argument('--expression',choices=['neutral','blink','smile'],default='neutral')
    parser.add_argument('--frame', type=int, default=1)
    parser.add_argument('--resolution', default='1280x720')
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--xvfb', default=shutil.which('Xvfb'))
    parser.add_argument('--vulkan-root', type=Path, default=Path.home()/'.local/opt/vulkan')
    parser.add_argument('--deadline', type=int, default=150)
    parser.add_argument('--lighting', choices=['match','soft','sun','shade'], default='match')
    parser.add_argument('--sky', choices=['match','review'], default='match')
    args = parser.parse_args()
    project = args.project.resolve()
    if not (project/'project.godot').is_file():
        parser.error('Football project.godot is missing')
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
                env['DISPLAY'] = read_display_number(read_fd)
            finally:
                os.close(read_fd)
        captures = []
        selections = [('match','broadcast')] if args.match else [(p,v) for p in args.players for v in args.views]
        for player,view in selections:
            stem = player+'_'+view
            command = [args.godot,'--path',str(project),'--rendering-method','forward_plus',
                       '--resolution',args.resolution,'--fixed-fps','60','--disable-vsync',
                       '--audio-driver','Dummy']
            if args.verbose:
                command += ['--verbose']
            if args.review_mode == 'audio':
                command += ['--write-movie',str(args.output/'audio_review.avi')]
            if linux:
                command += ['--display-driver','x11','--rendering-driver','vulkan']
            command += (['--script',('res://scripts/review_contextual_control.gd' if args.review_mode in ['receive','receive_broadcast'] else 'res://scripts/review_match_outro.gd' if args.review_mode == 'outro' else 'res://scripts/review_audio_mix.gd' if args.review_mode == 'audio' else 'res://scripts/review_broadcast_ui.gd' if args.review_mode == 'presentation' else 'res://scripts/review_p1.gd' if args.review_mode in ['keeper_distribution','p1_debug'] else 'res://scripts/review_supporter_crowd.gd' if args.review_mode == 'crowd' else 'res://scripts/review_native_repairs.gd') if args.review_mode else 'res://scripts/review_native_match.gd'] if args.match else ['res://scenes/review/shane_asset_review.tscn'])
            command += ['--',
                '--capture-dir='+str(args.output),'--player='+player,'--view='+view,
                '--lighting='+args.lighting,'--sky='+args.sky,'--clean=1']
            command += ['--setup-preview='+('1' if args.setup_preview else '0')]
            command += ['--venue='+args.venue,'--venue-view='+args.venue_view,'--ablation='+args.ablation]
            command += ['--weather='+args.weather,'--graphics='+args.graphics]
            command += ['--ball='+args.ball]
            command += ['--free-kick-style='+args.free_kick_style,'--free-kick-view='+args.free_kick_view]
            command += ['--expression='+args.expression]
            if args.pose and not args.match:
                command += ['--pose='+args.pose,'--frame='+str(args.frame)]
            if args.review_mode:
                command += ['--review-mode='+args.review_mode,'--receive-baseline='+('1' if args.receive_baseline else '0')]
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
                'peak_rss_kib':run_bounded.peak_rss_kib,
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
