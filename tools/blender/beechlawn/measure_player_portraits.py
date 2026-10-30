"""Offline portrait measurements; requires MediaPipe and the official task model.

Run from repository root after baseline Blender front renders. Tool/model stay
outside the game; only original measurements and editable fit ratios are used.
Inspect current crop bounds and input versions before measuring another batch.
"""
from pathlib import Path
import argparse,json,hashlib,math
import numpy as np
from PIL import Image
import mediapipe as mp
from portrait_coordinates import eye_coordinates
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--model-root',type=Path,required=True,help='Archived front.png directory per identity')
parser.add_argument('--output',type=Path,required=True,help='New measurement JSON; refuses to overwrite evidence')
parser.add_argument('--players',nargs='+',choices=('shane_denham','john_orourke','bordeaux_09','des_feeney_sr','robbie_roden','david_murray'))
args=parser.parse_args()
if args.output.exists():raise FileExistsError(args.output)
args.output.parent.mkdir(parents=True,exist_ok=True)
root=Path.cwd();p=root/'games/beechlawn_rovers';folder=p/'references/source_uploads/chat_attachments'
model=p/'build/head-fit-model/face_landmarker.task'
options=mp.tasks.vision.FaceLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),num_faces=1,min_face_detection_confidence=.2,min_face_presence_confidence=.2,output_facial_transformation_matrixes=True)
inputs={'shane_denham':('shane_face_photo/69012.jpg',(0,130,576,1080)),
        'john_orourke':('john_orourke_photo/69010.jpg',(0,230,576,1080)),
        'bordeaux_09':('boardeaux_des_photo/69016.jpg',(0,140,576,1120)),
        'des_feeney_sr':('des_feeney_referee_likeness/69015.jpg',(0,70,576,1060)),
        'robbie_roden':('br022_realism_followup/70467.jpg',(0,100,576,1120)),
        'david_murray':('br022_realism_followup/70466.jpg',(0,150,576,1150))}
out={}
with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
 for identity,(file,crop) in inputs.items():
  if args.players and identity not in args.players:continue
  out[identity]={}
  for kind,path in [('reference',folder/file),('model',args.model_root.resolve()/identity/'front.png')]:
   im=Image.open(path).convert('RGB')
   if kind=='reference':im=im.crop(crop)
   data=np.asarray(im);result=detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=data))
   if not result.face_landmarks:raise RuntimeError((identity,kind,'No face'))
   points=np.asarray([[l.x*im.width,l.y*im.height,l.z*im.width] for l in result.face_landmarks[0]])
   left=points[468,:2];right=points[473,:2]
   if left[0]>right[0]:left,right=right,left
   centre=(left+right)*.5;axis=right-left;distance=np.linalg.norm(axis);c,s=axis/distance
   norm=eye_coordinates(points)
   metrics={'face_width':abs(norm[234,0]-norm[454,0]),'jaw_width':abs(norm[172,0]-norm[397,0]),'mouth_width':abs(norm[61,0]-norm[291,0]),'nose_width':abs(norm[98,0]-norm[327,0]),'mouth_y':float((norm[13,1]+norm[14,1])*.5),'chin_y':float(norm[152,1]),'nose_y':float(norm[1,1])}
   out[identity][kind]={'source':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'crop':crop if kind=='reference' else None,'normalized_points':norm.tolist(),'image_points':points.tolist(),'image_size':list(im.size),'metrics':metrics,'pose_matrix':result.facial_transformation_matrixes[0].tolist()}
  print(identity,{k:round(out[identity]['reference']['metrics'][k]/out[identity]['model']['metrics'][k],3) for k in ('face_width','jaw_width','mouth_width','nose_width','mouth_y','chin_y')},flush=True)
args.output.write_text(json.dumps({'method':'MediaPipe Face Landmarker, eye-line normalized portrait measurements; ratios guide sculpt, not an exact 3D scan','tool':'mediapipe '+mp.__version__+' / Apache-2.0','model_url':'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task','model_sha256':hashlib.sha256(model.read_bytes()).hexdigest(),'players':out},indent=2)+'\n')
