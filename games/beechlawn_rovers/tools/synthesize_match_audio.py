#!/usr/bin/env python3
"""Historical original synthesized audio source, retained for reproducibility.

Writes to a scratch output directory; never replaces the shipped licensed music
or provenance. See assets/audio/README.md for the current asset catalogue.
"""
from pathlib import Path
import math,random,struct,wave,json,argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('output',type=Path)
OUT=parser.parse_args().output;OUT.mkdir(parents=True,exist_ok=True)
RATE=22050;rng=random.Random(2704)
def save(name,samples):
 peak=max(abs(v) for v in samples) or 1
 gain=min(.85/peak,1)
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
  f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,x*gain))*32767)) for x in samples))
 return {'file':name+'.wav','seconds':len(samples)/RATE,'peak':peak*gain,'rms':math.sqrt(sum((v*gain)**2 for v in samples)/len(samples))}
def effect(name,duration,fn):return save(name,[fn(i/RATE,rng.uniform(-1,1)) for i in range(int(RATE*duration))])
report=[]
report.append(effect('pass',.24,lambda t,n:(.7*math.sin(math.tau*(110-90*t)*t)+.25*n)*math.exp(-26*t)))
report.append(effect('kick',.40,lambda t,n:(.8*math.sin(math.tau*(85-35*t)*t)+.36*n)*math.exp(-18*t)))
report.append(effect('header',.20,lambda t,n:(.6*math.sin(math.tau*155*t)+.16*n)*math.exp(-30*t)))
report.append(effect('post',.85,lambda t,n:sum(.17*math.sin(math.tau*f*t)*math.exp(-d*t) for f,d in [(460,6),(940,9),(1520,13),(2470,18)])+.08*n*math.exp(-60*t)))
report.append(effect('net',.55,lambda t,n:n*.33*math.exp(-8*t)*( .6+.4*math.sin(45*t)**2)))
report.append(effect('step',.13,lambda t,n:(.2*n+.12*math.sin(math.tau*150*t))*math.exp(-35*t)))
report.append(effect('whistle',.8,lambda t,n:(.5*math.sin(math.tau*2900*t+2*math.sin(50*t))+.11*n)*min(t*60,1)*min((.8-t)*20,1)))
report.append(effect('ui',.1,lambda t,n:.18*math.sin(math.tau*(700+1200*t)*t)*math.exp(-30*t)))
# Soft multi-voice procedural sideline murmur. Filtered noise avoids a harsh hiss.
noise=0.;samples=[]
for i in range(RATE*8):
 t=i/RATE;noise=.94*noise+.06*rng.uniform(-1,1)
 samples.append(.20*noise+sum(.007*math.sin(math.tau*f*t+math.sin((j+1)*t)) for j,f in enumerate([117,143,179,224,267])))
report.append(save('crowd',samples))
report.append(effect('cheer',2.6,lambda t,n:(n*.23+sum(.035*math.sin(math.tau*f*t+math.sin(6*t)) for f in [176,223,271,359]))*min(1,t*5)*min(1,(2.6-t)*1.2)))
report.append(effect('rain',4,lambda t,n:.04*n))
# Original 16-second, eight-bar instrumental loop, 120 BPM. No PES melody.
notes=[(48,55,60),(45,52,57),(41,48,53),(43,50,55)]
samples=[]
for i in range(RATE*16):
 t=i/RATE;chord=notes[int(t//4)%4];v=0.
 for note in chord:
  freq=440*2**((note-69)/12);v+=.035*(math.sin(math.tau*freq*t)+.3*math.sin(math.tau*2*freq*t))
 beat=t%.5;v+=.20*math.sin(math.tau*(52*beat+45*(1-math.exp(-30*beat))/30))*math.exp(-24*beat)
 eighth=t%.25;v+=.022*rng.uniform(-1,1)*math.exp(-80*eighth)
 bass=440*2**((chord[0]-12-69)/12);v+=.07*math.sin(math.tau*bass*t)*(.6+.4*math.exp(-8*beat))
 v*=min(1,t/.02,(16-t)/.02);samples.append(v)
report.append(save('menu_music',samples))
(OUT/'provenance.json').write_text(json.dumps({'author':'Beechlawn Rovers project','license':'CC0-1.0','source':'tools/synthesize_match_audio.py','description':'Original procedurally synthesized audio; no sampled commercial recordings or melodies.','clips':report},indent=2)+'\n')
assert all(r['rms']>.001 and r['peak']<.99 for r in report)
print('Original audio generated:',len(report),'clips; peaks/RMS verified')
