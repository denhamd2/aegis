#!/usr/bin/env python3
"""Fixed-camera forehead banding check for the Des #9 portrait review.

This is a scoped visual QA measurement, not a general skin-quality metric.
It measures the unwanted repeated bands between pore and broad-form scales
in a feature-free forehead patch at the standard 1280x720 portrait camera.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('image',type=Path)
parser.add_argument('--report',type=Path)
args=parser.parse_args()
image=Image.open(args.image).convert('L')
assert image.size==(1280,720), 'Use the standard portrait capture'
patch=image.crop((615,240,665,285))
fine=np.asarray(patch.filter(ImageFilter.GaussianBlur(.8)),dtype=float)
broad=np.asarray(patch.filter(ImageFilter.GaussianBlur(3.0)),dtype=float)
residual=(fine-broad)[5:-5,5:-5]
rms=float(np.sqrt(np.mean(residual**2)))
result={'image':str(args.image),'forehead_patch':[615,240,665,285],
        'band_rms_8bit':rms,'maximum_band_rms_8bit':1.3,
        'result':'PASS' if rms<=1.3 else 'FAIL',
        'scope':'Fixed Des portrait lighting/camera; repeated forehead-band regression only'}
if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
raise SystemExit(0 if result['result']=='PASS' else 1)
