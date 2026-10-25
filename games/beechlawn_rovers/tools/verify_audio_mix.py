#!/usr/bin/env python3
"""Verify a native --review-mode audio Movie Maker mix and its mute interval."""
import argparse,array,json,math,subprocess
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('movie',type=Path)
parser.add_argument('--report',type=Path,required=True)
args=parser.parse_args()
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(args.movie),'-vn','-ac','1','-ar','22050','-f','f32le','pipe:1'],timeout=30)
samples=array.array('f');samples.frombytes(raw)
first=samples[int(.15*22050):int(.95*22050)]
tail=samples[int(1.45*22050):]
rms=lambda values:math.sqrt(sum(v*v for v in values)/max(1,len(values)))
report=dict(sample_rate=22050,duration=len(samples)/22050,audible_rms=rms(first),muted_tail_rms=rms(tail),peak=max(abs(v) for v in samples),source='Actual native Godot Movie Maker AudioServer mix')
assert report['duration']>=1.9,report
assert report['audible_rms']>.001,report
assert report['muted_tail_rms']<.0001,report
assert report['peak']<.99,report
report['result']='PASS'
args.report.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
