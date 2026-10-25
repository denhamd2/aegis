"""Check the actual exported layout independently of Blender's generator."""
import json,math,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets/environment/rovers_arena'
SEATS=json.loads((ROOT/'seating.json').read_text());LAYOUT=json.loads((ROOT/'seating_layout.json').read_text())
BANKS={b['name']:b for b in LAYOUT['banks']}
class SeatingAlignment(unittest.TestCase):
 def test_supported_level_rows_and_clear_aisles(self):
  rows={};bad=0
  for x,h,z,yaw,section in SEATS:
   b=BANKS[LAYOUT['sections'][int(section)]['bank']];dx=x-b['origin'][0];dy=-z-b['origin'][1]
   if b['kind']=='line':
    depth=dx*b['normal'][0]+dy*b['normal'][1];along=dx*b['tangent'][0]+dy*b['tangent'][1]
    bad+=abs(math.remainder(along,LAYOUT['seat_pitch']))>.002
    bad+=abs(math.remainder(along,LAYOUT['aisle_pitch']))<LAYOUT['aisle_half']+.21
    self.assertLess(abs(along),b['half']-.20)
   else:
    radius=math.hypot(dx,dy);depth=radius-LAYOUT['radius'];along=math.atan2(dy,dx)
    if along<b['angles'][0]-.001:along+=math.tau
    self.assertGreaterEqual(along,b['angles'][0]-.001);self.assertLessEqual(along,b['angles'][1]+.001)
    bad+=abs(along-sum(b['angles'])/2)*radius<LAYOUT['aisle_half']+.21
   row=round(depth/LAYOUT['tread']-.5)
   self.assertAlmostEqual(depth,(row+.5)*LAYOUT['tread'],delta=.002)
   self.assertGreaterEqual(row,0);self.assertLess(row,b['rows'])
   self.assertAlmostEqual(h,1.07+min(row,32)*.42+max(0,row-32)*.49,delta=.002)
   self.assertFalse(b['role']!='home' and 32<=row<=35)
   rows.setdefault((b['name'],row),[]).append((along,depth))
  self.assertEqual(bad,0,'A seating column drifts or a chair obstructs a gangway')
  for (name,row),values in rows.items():
   values.sort();b=BANKS[name]
   for (a,depth),(c,_) in zip(values,values[1:]):
    separation=(c-a)*(LAYOUT['radius']+depth) if b['kind']=='arc' else c-a
    self.assertGreater(separation,.53,'Overlapping adjacent chairs')
  self.assertEqual(LAYOUT['support_audit']['errors'],0)
  self.assertGreater(LAYOUT['support_audit']['sampled'],2000)
 def test_inward_yaw_and_corner_fan(self):
  angles={}
  for x,h,z,yaw,section in SEATS:
   b=BANKS[LAYOUT['sections'][int(section)]['bank']]
   nx,ny=b['normal'] if b['kind']=='line' else (x-b['origin'][0],-z-b['origin'][1]);length=math.hypot(nx,ny);nx/=length;ny/=length
   self.assertGreater((-math.sin(yaw))*(-nx)+(-math.cos(yaw))*ny,.99999)
   angles.setdefault(b['name'],set()).add(round(yaw,3))
  for b in LAYOUT['banks']:
   self.assertGreater(len(angles[b['name']]),200) if b['kind']=='arc' else self.assertEqual(len(angles[b['name']]),1)
 def test_distinct_profiles_and_spatial_blocks(self):
  self.assertEqual(BANKS['South']['rows'],63);self.assertEqual(BANKS['North']['rows'],50)
  self.assertTrue(all(not r['walkway'] for r in LAYOUT['rows'] if r['bank']=='South'))
  self.assertTrue(all(LAYOUT['tread']==.78 for b in LAYOUT['banks']))
  self.assertGreater(len(SEATS),45000);self.assertLess(len(SEATS),56000)
  counts={}
  for e in SEATS:counts[int(e[4])]=counts.get(int(e[4]),0)+1
  self.assertGreater(len(counts),24)
  for s in LAYOUT['sections']:
   self.assertEqual(counts[s['id']],s['count']);self.assertGreater(math.hypot(s['centre'][0],s['centre'][2]),35)
if __name__=='__main__':unittest.main()
