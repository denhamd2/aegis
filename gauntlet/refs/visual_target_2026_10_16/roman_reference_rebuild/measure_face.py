#!/usr/bin/env python3
"""Optional build-time likeness diagnostics, never a game/runtime dependency.

Install mediapipe, numpy, pillow and matplotlib in a separate environment.
Download the model URL recorded in the generated-source provenance, then run:
  python measure_face.py --model /path/to/face_landmarker.task
Measurements guide sculpting; camera/lighting/expression bias the estimates.
They are not an identity similarity score or a visual acceptance gate.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

HERE = Path(__file__).resolve().parent
PAIRS = [('nose_width',98,327),('mouth_width',61,291),('jaw_width',172,397),
         ('cheek_width',234,454),('forehead_to_eyes',10,168),
         ('brow_to_nose',168,2),('nose_to_mouth',2,13),
         ('mouth_to_chin',13,152),('eye_width',33,133),('eye_opening',159,145)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model',type=Path,required=True)
    parser.add_argument('--reference',type=Path,default=HERE.parent/'roman_face_review/reference.png')
    parser.add_argument('--before',type=Path,default=HERE/'before_front.png')
    parser.add_argument('--after',type=Path,default=HERE/'after_front.png')
    parser.add_argument('--out',type=Path,default=HERE)
    args = parser.parse_args()
    args.out.mkdir(exist_ok=True,parents=True)
    options = vision.FaceLandmarkerOptions(base_options=python.BaseOptions(
        model_asset_path=str(args.model),delegate=python.BaseOptions.Delegate.CPU),
        num_faces=1,min_face_detection_confidence=.2,min_face_presence_confidence=.2)
    record = {'scope':'diagnostic 2D landmarks; camera/lighting/expression can bias estimates; not an AAA/identity score',
              'model_sha256':hashlib.sha256(args.model.read_bytes()).hexdigest(),'captures':{}}
    images = {}
    with vision.FaceLandmarker.create_from_options(options) as detector:
        for name,path in [('reference',args.reference),('before',args.before),('after',args.after)]:
            image = Image.open(path).convert('RGB'); images[name] = image
            # Face detection fails in the wide, highly saturated supplied
            # stage image. Restrict inference to its known head region.
            crop = [680,210,1010,560] if name=='reference' else None
            feed = image.crop(crop).resize((660,700)) if crop else image
            result = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=np.array(feed)))
            if not result.face_landmarks:raise RuntimeError('No landmarks: '+name)
            points = np.array([[p.x*feed.width,p.y*feed.height,p.z*feed.width] for p in result.face_landmarks[0]])
            if crop:
                points *= .5; points[:,0] += crop[0]; points[:,1] += crop[1]
            ipd = float(np.linalg.norm(points[468,:2]-points[473,:2]))
            ratios = {label:round(float(np.linalg.norm(points[a,:2]-points[b,:2])/ipd),4)
                      for label,a,b in PAIRS}
            record['captures'][name] = {'image':path.name,'image_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'pixels':list(image.size),'detector_crop':crop,'inter_pupil_px':ipd,
                'ratios_to_ipd':ratios,'landmarks':points.tolist()}
            print(name,json.dumps(ratios))
    (args.out/'landmarks.json').write_text(json.dumps(record,indent=2)+'\n')
    # A scientific comparison figure: crop/scale by eye centres, no retouch,
    # colour grade, generated content or replacement of any rendered pixels.
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig,axes = plt.subplots(1,3,figsize=(12,4.7),facecolor='#101216')
    for ax,name,title in zip(axes,['reference','before','after'],['Supplied target','Previous engine frame · 140d930','Rebuilt engine frame']):
        item = record['captures'][name]; points = np.array(item['landmarks'])
        centre = (points[468,:2]+points[473,:2])*.5; ipd = item['inter_pupil_px']
        image = images[name]; w,h = image.size
        ax.imshow(image,extent=[-centre[0]/ipd,(w-centre[0])/ipd,(h-centre[1])/ipd,-centre[1]/ipd],interpolation='nearest')
        ax.set_xlim(-1.60,1.60); ax.set_ylim(2.10,-1.60); ax.set_aspect('equal')
        ax.set_title(title,color='white',fontsize=11);ax.axis('off')
    fig.text(.5,.02,'Diagnostic crops scaled by pupil distance. Source pixels unchanged; lighting and pose differ.',ha='center',color='#bdc6d6',fontsize=10)
    fig.tight_layout(rect=[0,.05,1,1]);fig.savefig(args.out/'face_comparison.png',dpi=140,facecolor=fig.get_facecolor())


if __name__=='__main__':main()
