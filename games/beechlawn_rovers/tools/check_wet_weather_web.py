from pathlib import Path
import subprocess,json,time
import argparse
root=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description='Serial actual WebGL weather/shadow review; debug export required.')
parser.add_argument('web_root',type=Path)
parser.add_argument('--evidence',type=Path,default=root/'games/beechlawn_rovers/docs/art_briefs/wet_weather_evidence')
parser.add_argument('--shots',nargs='+',help='Optional subset of named review shots')
args=parser.parse_args()
out=args.evidence.resolve();out.mkdir(parents=True,exist_ok=True)
records=json.loads((out/'captures.json').read_text()) if (out/'captures.json').is_file() else []
shots=[('sunny_goalmouth','sunny','goalmouth',True),('sunny_shadows_off','sunny','goalmouth',False),('ball_shadow_on','sunny','ball_shadow',True),('ball_shadow_off','sunny','ball_shadow',False),('sunny_broadcast','sunny','broadcast',True),('cloudy_broadcast','cloudy','broadcast',False),('rain_goalmouth','rain','goalmouth',False),('mist_broadcast','mist','broadcast',False)]
if args.shots:
 unknown=set(args.shots)-{shot[0] for shot in shots}
 if unknown:parser.error('Unknown shots: '+str(sorted(unknown)))
 shots=[next(shot for shot in shots if shot[0]==name) for name in args.shots]
for name,weather,view,shadows in shots:
 q=f'software=1&weather={weather}&view={view}&surface_review=1'+('&shadows=1' if shadows else '')
 cmd=['python3',str(root/'tools/capture/capture_beechlawn_web.py'),str(out/(name+'.png')),'--web-root',str(args.web_root.resolve()),'--query',q,'--ready-expression',f"window.BEECHLAWN_MATCH_READY === true && window.BEECHLAWN_WEATHER === '{weather}'",'--width','960','--height','540','--wait','3']
 started=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=100,cwd=root)
 print(name,r.returncode,round(time.monotonic()-started,1),'seconds',flush=True)
 if r.returncode:print(r.stdout,r.stderr,flush=True);raise SystemExit(r.returncode)
 records=[entry for entry in records if entry['file']!=name+'.png']
 records.append({'file':name+'.png','weather':weather,'sun_shadows':shadows,'query':q,'width':960,'height':540,'browser_errors':False,'staged_ball':True})
 (out/'captures.json').write_text(json.dumps(records,indent=2)+'\n')
