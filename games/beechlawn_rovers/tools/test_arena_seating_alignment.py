"""Regression checks against the exported seating used by Godot, not a mock grid."""
import json
import math
from pathlib import Path
import unittest

PROJECT = Path(__file__).resolve().parents[1]
SEATS = json.loads((PROJECT/'assets/environment/rovers_arena/seating.json').read_text())
SQRT_HALF = math.sqrt(.5)
OUTWARD = [(SQRT_HALF,SQRT_HALF),(1,0),(SQRT_HALF,-SQRT_HALF),(0,-1),
           (-SQRT_HALF,-SQRT_HALF),(-1,0),(-SQRT_HALF,SQRT_HALF),(0,1)]

class SeatingAlignment(unittest.TestCase):
    def test_straight_bank_columns_and_aisles_align(self):
        # Fixed lateral columns and perpendicular aisles on both long stands
        # and both goal-end stands; the normal rise between rows is preserved.
        bad_columns=[]; obstructed_aisles=[]
        for x,y,z,yaw,section in SEATS:
            side=int(section)%8
            if side not in (1,3,5,7): continue
            lateral=z if side in (1,5) else x
            drift=abs(math.remainder(lateral,.6))
            if drift>.002: bad_columns.append(drift)
            if abs(math.remainder(lateral,13.2))<1.15: obstructed_aisles.append(lateral)
        print('SEATING_ALIGNMENT columns_off_grid=',len(bad_columns),
              'max_drift_m=',round(max(bad_columns,default=0),4),
              'aisle_obstructions=',len(obstructed_aisles))
        self.assertEqual(len(bad_columns),0,'Seating columns drift sideways between rows')
        self.assertEqual(len(obstructed_aisles),0,'An aisle changes direction or is blocked in another row')

    def test_chairs_face_into_the_pitch(self):
        wrong=[]
        for x,y,z,yaw,section in SEATS:
            nx,nz=OUTWARD[int(section)%8]
            # Godot Basis(UP,yaw) transforms the chair's local -Z forward.
            fx,fz=-math.sin(yaw),-math.cos(yaw)
            alignment=fx*(-nx)+fz*(-nz)
            if alignment<.999: wrong.append((section,alignment))
        print('SEATING_ALIGNMENT wrong_facing=',len(wrong),'of',len(SEATS))
        self.assertEqual(len(wrong),0,'Some banks have chairs facing outward or diagonally across their rows')

    def test_rows_remain_level(self):
        rows={}
        for x,y,z,yaw,section in SEATS:
            rows.setdefault(int(section),set()).add(round(y,4))
        self.assertEqual(len(rows),24)
        for section,levels in rows.items():
            ordered=sorted(levels)
            self.assertEqual(len(ordered),18 if section//8==0 else 20)
            self.assertTrue(all(abs(b-a-.43)<.0002 for a,b in zip(ordered,ordered[1:])))

if __name__=='__main__': unittest.main()
