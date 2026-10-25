"""Native Forward+ source-asset review through the project's bounded capture helpers."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
from capture_native import read_display_number,run_bounded,stop,PROJECT

folder=Path(sys.argv[1]).resolve();folder.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,LP_NUM_THREADS='4')
vulkan=Path.home()/'.local/opt/vulkan'
if (vulkan/'usr/share/vulkan/icd.d/lvp_icd.json').exists():
 env['VK_ICD_FILENAMES']=str(vulkan/'usr/share/vulkan/icd.d/lvp_icd.json')
 env['LD_LIBRARY_PATH']=str(vulkan/'usr/lib/x86_64-linux-gnu')+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
read,write=os.pipe()
with (folder/'display.log').open('wb') as log:
 display=subprocess.Popen([shutil.which('Xvfb') or '/workspace/aegis-render-tools/root/usr/bin/Xvfb','-displayfd',str(write),'-screen','0','800x600x24','-nolisten','tcp','-ac'],env=env,pass_fds=(write,),stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 os.close(write)
 try:
  env['DISPLAY']=read_display_number(read)
  os.close(read)
  command=['godot','--path',str(PROJECT),'--rendering-method','forward_plus','--rendering-driver','vulkan','--display-driver','x11','--audio-driver','Dummy','--resolution','800x600','--script','res://scripts/review_supporter_asset.gd','--','--graphics=custom','--capture-dir='+str(folder)]
  run_bounded(command,env,180,folder/'review.log')
 finally:stop(display)
