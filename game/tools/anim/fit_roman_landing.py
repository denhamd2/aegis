"""Offline constrained Roman landing envelope; requires NumPy/SciPy.
Usage: python fit_roman_landing.py baseline.json > coefficients.json
No build/runtime dependency. Input must be a pre-fit real-controller trace.
"""
import json, sys, hashlib
import numpy as np
from scipy.optimize import minimize, LinearConstraint, Bounds
from scipy.special import comb
rows=json.load(open(sys.argv[1]))['samples']
frames=[]; floors=[]
for r in rows:
 if not r['active']: continue
 values=[]
 for s in r['surfaces']:
  if s['cosmetic'] or s['path'].endswith(('lambert1_skinned','Ringlets','body_skinned','mouthbag_skinned')):continue
  values += [v['y'] for v in s['regions'].values()]
 # Actual 60Hz playback evaluates the body pose one tick behind the
 # reported player clock; this lag was measured from applied displacement.
 frames.append(r['source_frame']-.5);floors.append(min(values))
start,end=55.,63.
x=np.linspace(start,end,193);t=(x-start)/(end-start)
def mat(t,n=12):return np.array([comb(n,k)*t**k*(1-t)**(n-k) for k in range(n+1)]).T
B=mat(t)[:,3:10]
lower=np.maximum(-.24,.008-np.interp(x,frames,floors))
impact=mat(np.array([(58.5-start)/(end-start)]))[:,3:10]
# Match actual impact at root59; smooth derivative cost in normalized phase.
D=np.diff(B,n=3,axis=0)/(t[1]-t[0])**3
sel=(x>=58.5)&(x<=61.)
target=np.minimum(0,.025-np.interp(x[sel],frames,floors))
M=B[sel]
def fun(c):return np.mean((M@c-target)**2)+1e-8*np.mean((D@c)**2)
def jac(c):return 2*M.T@(M@c-target)/len(M)+2e-8*D.T@(D@c)/len(D)
r=minimize(fun,np.full(7,-.4),jac=jac,bounds=Bounds(-3,0),constraints=[LinearConstraint(B,lower,np.zeros(len(x))),LinearConstraint(impact,[-.225],[-.225])],method='SLSQP',options={'maxiter':1000,'ftol':1e-13})
assert r.success, r.message
assert min(B@r.x-lower) >= -1e-8
coeff=np.r_[np.zeros(3),r.x,np.zeros(3)]
json.dump({
    "baseline_sha256": hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest(),
    "start_source_frame": start, "end_source_frame": end,
    "pose_evaluation_lag_source_frames": 0.5,
    "coefficients_world": coeff.tolist(),
    "coefficients_before_stature": (coeff * 1.866 / 1.905).tolist(),
    "minimum_predicted_floor_margin_m": float(min(B @ r.x - lower)),
}, sys.stdout, indent=2)
print()
