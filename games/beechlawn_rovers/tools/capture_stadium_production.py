#!/usr/bin/env python3
"""Bounded Forward+ stadium evidence; no browser or replacement images."""
import os,argparse,subprocess,shutil
from pathlib import Path
from capture_native import PROJECT,stop,read_display_number,run_bounded
p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--group',choices=['architecture','crowd','tifo','single'],default='architecture');p.add_argument('--isolate-no-crowd',action='store_true');a=p.parse_args()
folder=a.output.resolve();folder.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,LP_NUM_THREADS='4');vulkan=Path.home()/'.local/opt/vulkan'
if (vulkan/'usr/share/vulkan/icd.d/lvp_icd.json').exists():
 env['VK_ICD_FILENAMES']=str(vulkan/'usr/share/vulkan/icd.d/lvp_icd.json');env['LD_LIBRARY_PATH']=str(vulkan/'usr/lib/x86_64-linux-gnu')
read,write=os.pipe()
with (folder/'display.log').open('wb') as log:
 display=subprocess.Popen([shutil.which('Xvfb') or '/workspace/aegis-render-tools/root/usr/bin/Xvfb','-displayfd',str(write),'-screen','0','960x540x24','-nolisten','tcp','-ac'],env=env,pass_fds=(write,),stdout=log,stderr=subprocess.STDOUT,start_new_session=True);os.close(write)
 try:
  env['DISPLAY']=read_display_number(read);os.close(read)
  command=['godot','--path',str(PROJECT),'--rendering-method','forward_plus','--rendering-driver','vulkan','--display-driver','x11','--audio-driver','Dummy','--resolution','960x540','--script','res://scripts/review_stadium_production.gd','--','--graphics=balanced_60','--capture-dir='+str(folder),'--group='+a.group]
  if a.isolate_no_crowd:command.append('--isolate-no-crowd')
  run_bounded(command,env,90 if a.isolate_no_crowd else 240,folder/'native.log')
 finally:stop(display)
