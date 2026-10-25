#!/usr/bin/env python3
"""Bounded native Mac benchmark, including actual resident process memory.

python3 tools/benchmark_mac.py '/Applications/Beechlawn Rovers.app' results/
Runs 15 minutes plus a bounded startup/cleanup allowance. The executable must
be the v0.5.0 build containing benchmark_match.gd. No browser or Blender.
"""
import argparse,csv,json,os,platform,signal,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('app',type=Path);p.add_argument('output',type=Path)
p.add_argument('--seconds',type=int,default=900)
a=p.parse_args()
if platform.system()!='Darwin':p.error('This acceptance runner requires the target Mac display and Metal GPU.')
a.output.mkdir(parents=True,exist_ok=True);out=a.output.resolve()
executable=next((a.app/'Contents/MacOS').glob('*')) if a.app.suffix=='.app' else a.app
command=[str(executable),'--script','res://scripts/benchmark_match.gd','--','--graphics=balanced_60','--benchmark='+str(out/'frames.csv'),'--benchmark-seconds='+str(a.seconds)]
peak=0;started=time.monotonic()
with (out/'native.log').open('wb') as log,(out/'resident_memory.csv').open('w') as memory:
 writer=csv.writer(memory);writer.writerow(['wall_seconds','resident_bytes'])
 process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 try:
  while process.poll() is None:
   try:rss=int(subprocess.check_output(['ps','-o','rss=','-p',str(process.pid)],timeout=3).strip())*1024
   except (ValueError,subprocess.SubprocessError):rss=0
   peak=max(peak,rss);writer.writerow([time.monotonic()-started,rss]);memory.flush()
   if time.monotonic()-started>a.seconds+120:raise TimeoutError('Benchmark exceeded its deadline')
   time.sleep(1)
 finally:
  if process.poll() is None:
   os.killpg(process.pid,signal.SIGTERM)
   try:process.wait(timeout=3)
   except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=3)
summary_path=out/'frames.csv.summary.json'
summary=json.loads(summary_path.read_text()) if summary_path.exists() else {'meets_frame_target':False,'error':'No completed frame report'}
summary.update(peak_resident_bytes=peak,resident_memory_budget_bytes=6*1024**3,exit_code=process.returncode)
summary['accepted']=bool(summary.get('meets_frame_target')) and peak>0 and peak<6*1024**3 and process.returncode==0
(out/'acceptance.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
raise SystemExit(0 if summary['accepted'] else 1)
