"""Reference-measured neutral head fit from the packed OWNED RAW mesh.

No legacy head TPS/TABLE/RELAX is applied. This bounded clay-stage draft uses
explicit front/profile measurements, one smooth global warp, protected eyes,
zero neck displacement and inverse-transpose normal transport.
"""
import hashlib,json,math,pathlib
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image,ImageDraw

def register_quarter(anchors,want,origin,distance):
    """Pose-only perspective registration; three points cannot identify a lens.

    Keep distance explicit and report its sensitivity instead of presenting a
    low anchor residual as proof of either anatomy or photographic calibration.
    Shape checks do not participate in this solve.
    """
    rel=anchors-origin;want=np.asarray(want,float);pb=want-want.mean(axis=0)
    def trial(yaw,pitch):
        a,b=np.radians([yaw,pitch]);right=np.array([np.cos(a),0,-np.sin(a)])
        outward=np.array([np.sin(a)*np.cos(b),np.sin(b),np.cos(a)*np.cos(b)])
        up=np.cross(outward,right);basis=np.stack([right,-up])
        denominator=1-rel@outward/distance;plane=(rel@basis.T)/denominator[:,None]
        pa=plane-plane.mean(axis=0);u,s,vt=np.linalg.svd(pa.T@pb);rotation=u@vt
        if np.linalg.det(rotation)<0:u[:,-1]*=-1;rotation=u@vt
        scale=np.sum((pa@rotation)*pb)/np.sum(pa*pa)
        translation=want.mean(axis=0)-plane.mean(axis=0)@rotation*scale
        projected=plane@rotation*scale+translation
        error=float(np.sqrt(np.mean(np.sum((projected-want)**2,axis=1))))
        return error,yaw,pitch,basis,outward,rotation,scale,translation,projected
    best=None
    for yaw in np.arange(25,76,2):
        for pitch in np.arange(-24,25,2):
            result=trial(yaw,pitch)
            if best is None or result[0]<best[0]:best=result
    for step in [.5,.1,.02]:
        centre=best
        for yaw in centre[1]+np.arange(-4,5)*step:
            for pitch in centre[2]+np.arange(-4,5)*step:
                result=trial(yaw,pitch)
                if result[0]<best[0]:best=result
    err,yaw,pitch,basis,outward,rotation,scale,translation,projected=best
    def project(points):
        q=np.asarray(points)-origin
        return ((q@basis.T)/(1-q@outward/distance)[...,None])@rotation*scale+translation
    return {'yaw_degrees':float(yaw),'pitch_degrees':float(pitch),'distance_m_assumed':distance,
            'roll_degrees':float(np.degrees(np.arctan2(rotation[0,1],rotation[0,0]))),
            'scale_px_per_m_at_eyes':float(scale),'anchor_rms_px':err,'anchor_projections_px':projected.tolist()},project

def fit(k,body,round_no):
    annotation_path=pathlib.Path(__file__).with_name('kenny_reference_landmarks.json')
    ann=json.loads(annotation_path.read_text());snap=k.data('KennyRawSeed');mesh=body.data;mw=np.array(body.matrix_world)
    rot=np.array([[1,0,0],[0,0,1],[0,-1,0]])
    # The owned production neck seam is protected independently from the RAW
    # facial substrate. RAW predates a sub-millimetre seam correction.
    seam_positions=(np.array([v.co[:] for v in mesh.vertices])@mw[:3,:3].T+mw[:3,3])@rot.T
    seam_normals=np.array([n.vector[:] for n in mesh.corner_normals])@np.linalg.inv(mw[:3,:3])@rot.T
    raw=k.unpack_array(snap['positions']);p=(raw@mw[:3,:3].T+mw[:3,3])@rot.T
    normals=k.unpack_array(snap['loop_normals'])@np.linalg.inv(mw[:3,:3])@rot.T
    lv=np.array([l.vertex_index for l in mesh.loops]);headmat=next(i for i,m in enumerate(mesh.materials) if m.name==k.HEAD)
    mouthmat=next(i for i,m in enumerate(mesh.materials) if m.name==k.MOUTH)
    eyemat=next(i for i,m in enumerate(mesh.materials) if m.name==k.EYE)
    head_ids=np.array(sorted({v for f in mesh.polygons if f.material_index==headmat for v in f.vertices}))
    mouth_ids=np.array(sorted({v for f in mesh.polygons if f.material_index==mouthmat for v in f.vertices}))
    eye_ids=np.array(sorted({v for f in mesh.polygons if f.material_index==eyemat for v in f.vertices}))
    mask=np.zeros(len(p),bool);mask[head_ids]=True;mask[mouth_ids]=True
    eyes=[p[[i for i in eye_ids if (p[i,0]>.004)==(side==1)]].mean(axis=0) for side in [-1,1]]
    # The visible iris/pole anchor comes from its own UV centre, rather than
    # the density-biased mean of the hemisphere's vertices.
    uvdata=mesh.uv_layers.active.data;eye_candidates={-1:[],1:[]}
    for polyeye in mesh.polygons:
        if polyeye.material_index!=eyemat:continue
        uv=np.array([uvdata[l].uv[:] for l in polyeye.loop_indices]);a,b,c=uv
        matrix=np.column_stack([b-a,c-a])
        if abs(np.linalg.det(matrix))<1e-12:continue
        vb,vc=np.linalg.solve(matrix,np.array([.5,.5])-a);va=1-vb-vc
        if min(va,vb,vc)<-1e-5:continue
        q=p[list(polyeye.vertices)];point=q[0]*va+q[1]*vb+q[2]*vc
        eye_candidates[1 if point[0]>.004 else -1].append(point)
    for i,side in enumerate([-1,1]):
        if eye_candidates[side]:eyes[i]=max(eye_candidates[side],key=lambda q:q[2])
    mid=np.mean(eyes,axis=0);eye_width=eyes[1][0]-eyes[0][0]
    feyes=np.array(ann['front_eyes'],float);fp=feyes.mean(axis=0);slope=(feyes[1,1]-feyes[0,1])/(feyes[1,0]-feyes[0,0]);sf=(feyes[1,0]-feyes[0,0])/eye_width
    def front(q):
        q=np.asarray(q,float);return np.array([mid[0]+(q[0]-fp[0])/sf,mid[1]-((q[1]-slope*(q[0]-fp[0]))-fp[1])/sf])
    # Independent profile scale from shared vertical landmarks, anchored to eye.
    num=den=0.
    for feature in ann['features']:
        if 'profile' not in feature:continue
        q=feature['front'];q=np.mean(q,axis=0) if isinstance(q[0],list) else q
        y=front(q)[1]-mid[1];dy=feature['profile'][1]-ann['profile_eye'][1]
        num+=-y*dy;den+=y*y
    sp=num/max(den,1e-12)
    faces=[list(f.vertices) for f in mesh.polygons if f.material_index==headmat]
    bvh=BVHTree.FromPolygons([Vector(v) for v in p],faces,all_triangles=True)
    front_ids=head_ids[p[head_ids,2]>-.065]
    def surface(x,y):
        hit,n,index,d=bvh.ray_cast(Vector((x,y,.28)),Vector((0,0,-1)),.5)
        if hit is not None and hit.z>-.065:return np.array(hit)
        q=p[front_ids];score=(q[:,0]-x)**2*3+(q[:,1]-y)**2*3+(q[:,2]-.01)**2*.12
        return q[int(np.argmin(score))].copy()
    sources=[];targets=[];labels=[];observations=[];measured_targets=[]
    for feature in ann['features']:
        pair=isinstance(feature['front'][0],list)
        qs=feature['front'] if pair else [feature['front']]
        for qi,q in enumerate(qs):
            side=(-1 if qi==0 else 1) if pair else 0
            source=surface(mid[0]+side*feature['source_xy'][0],feature['source_xy'][1]);target=source.copy();xy=front(q)
            target[0]=mid[0]+side*abs(xy[0]-mid[0]) if pair else mid[0];target[1]=xy[1]
            if 'profile' in feature:
                target[2]=mid[2]+(ann['profile_eye'][0]-feature['profile'][0])/sp
                if pair and feature['name'].startswith('brow'):
                    target[2]=source[2]+target[2]-surface(mid[0],feature['source_xy'][1])[2]
            measured_targets.append(target.copy())
            d=target-source;length=np.linalg.norm(d)
            if length>ann['limits']['maximum_control_displacement_m']:target=source+d*ann['limits']['maximum_control_displacement_m']/length
            sources.append(source);targets.append(target);labels.append(feature['name']+('_left' if side<0 else '_right' if side>0 else ''))
            observations.append({'front_px':q,'profile_px':feature.get('profile')})
    feature_count=len(sources)
    measured_by_name={name:q for name,q in zip(labels,measured_targets)}
    # Eye/canthus and skull/neck anchors stabilize one coherent head solve.
    for eye in eyes:
        for dx,dy in [(-.013,0),(.013,0),(0,.0105),(0,-.0105)]:
            q=surface(eye[0]+dx,eye[1]+dy);sources.append(q);targets.append(q.copy());labels.append('orbital_anchor')
    for y in [1.565,1.575,1.585]:
        for x in [-.07,-.035,0,.035,.07]:
            for z in [-.14,-.08,-.02]:
                q=np.array([mid[0]+x,y,z]);sources.append(q);targets.append(q.copy());labels.append('neck_anchor')
    for y in [1.62,1.69,1.77,1.83]:
        for x in [-.08,0,.08]:
            q=np.array([mid[0]+x,y,-.17]);sources.append(q);targets.append(q.copy());labels.append('back_anchor')
    # Measured facial controls stop at the brows. Hold the unmeasured scalp,
    # temples and ears with an actual surface cage so the affine tail cannot
    # extrapolate 5+ cm and force attenuation of every central-face target.
    for y in [1.772,1.795,1.817]:
        for x in [-.07,-.035,0,.035,.07]:
            q=surface(mid[0]+x,y);sources.append(q);targets.append(q.copy());labels.append('scalp_guard_anchor')
    for side in [-1,1]:
        for y in [1.655,1.70,1.75]:
            for z in [-.085,-.125]:
                hit,_,_,_=bvh.ray_cast(Vector((side*.30,y,z)),Vector((-side,0,0)),.5)
                if hit is not None:
                    q=np.array(hit);sources.append(q);targets.append(q.copy());labels.append('temple_ear_guard_anchor')
    c=np.array(sources);t=np.array(targets);origin=np.array([mid[0],1.70,-.055]);unit=.22;cn=(c-origin)/unit
    # Merge exact anchor duplicates before solving.
    _,keep=np.unique(np.round(cn,6),axis=0,return_index=True);keep=np.sort(keep);c=c[keep];t=t[keep];cn=cn[keep];labels=[labels[i] for i in keep]
    r=np.linalg.norm(cn[:,None,:]-cn[None,:,:],axis=2);kernel=r**3
    reg=ann['fit']['regularization'];poly=np.c_[np.ones(len(c)),cn]
    system=np.block([[kernel+np.eye(len(c))*reg,poly],[poly.T,np.zeros((4,4))]])
    rhs=np.vstack([(t-c)/unit,np.zeros((4,3))]);solution=np.linalg.solve(system,rhs);w=solution[:len(c)];aff=solution[len(c):]
    def warp(points):
        q=(points-origin)/unit;diff=q[:,None,:]-cn[None,:,:];rr=np.linalg.norm(diff,axis=2)
        d=(rr**3@w+np.c_[np.ones(len(q)),q]@aff)*unit
        jd=np.einsum('nkj,ki->nij',3*rr[:,:,None]*diff,w)+aff[1:].T[None,:,:]
        # Exactly fixed protected neck with a C1 transition into the lower head.
        y=points[:,1];fade=k.smooth((y-1.575)/.028);grad=np.zeros((len(q),3));u=np.clip((y-1.575)/.028,0,1);grad[:,1]=6*u*(1-u)/.028
        jd=jd*fade[:,None,None]+d[:,:,None]*grad[:,None,:];d*=fade[:,None]
        return d,jd
    ids=np.flatnonzero(mask);delta,jd=warp(p[ids]);identity=np.eye(3)[None,:,:]
    strength=1.
    for attempt in range(12):
        det=np.linalg.det(identity+jd*strength)
        if det.min()>=ann['limits']['minimum_jacobian_determinant'] and np.max(np.linalg.norm(delta*strength,axis=1))<.026:break
        strength*=.80
    jac=np.broadcast_to(np.eye(3),(len(p),3,3)).copy();jac[ids]+=jd*strength
    new=p.copy();new[ids]+=delta*strength
    normals=np.einsum('lji,lj->li',np.linalg.inv(jac)[lv],normals);normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    # Preserve the already-owned body/yoke baseline, independent of head fit.
    new,normals=k.field_numpy(new,normals,lv,k.data('KennyCapturedFace')['historical_yoke'],mid=0)
    seam_weight=np.zeros(len(p));seam_weight[head_ids]=1-k.smooth((seam_positions[head_ids,1]-1.575)/.025)
    before_seam=new.copy();new+=seam_weight[:,None]*(seam_positions-new)
    nw=seam_weight[lv,None];normals=normals*(1-nw)+seam_normals*nw
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    k.set_game_geometry(body,new,normals,mw,rot)
    cd,cj=warp(c);fitted=c+cd*strength;residual=np.linalg.norm(fitted-t,axis=1)
    report={'round':round_no,'reference':ann['reference'],'method':ann['annotation'],'basis':'owned RAW head; no legacy head fit/sculpt/relax',
            'front_pixels_per_m':sf,'front_roll_degrees':math.degrees(math.atan(slope)),'profile_pixels_per_m':sp,
            'eye_anchor_game_m':mid.tolist(),'eye_spacing_m':eye_width,'fit_strength':strength,
            'minimum_head_jacobian_determinant':float(np.linalg.det(jac[ids]).min()),'maximum_head_displacement_m':float(np.linalg.norm(new[head_ids]-p[head_ids],axis=1).max()),
            'mouth_vertices_following_warp':len(mouth_ids),'protected_eye_max_delta_m':float(np.linalg.norm(new[eye_ids]-p[eye_ids],axis=1).max()),
            'protected_neck_owned_seam_max_delta_m':float(np.linalg.norm((new-seam_positions)[head_ids[seam_positions[head_ids,1]<1.575]],axis=1).max()),
            'owned_neck_boundary_blend_maximum_m':float(np.linalg.norm(new-before_seam,axis=1).max()),
            'feature_residual_rms_m':float(np.sqrt(np.mean(residual[:feature_count]**2))),
            'landmarks':[{'name':name,'source_game_m':a.tolist(),'target_game_m':b.tolist(),'fitted_game_m':f.tolist(),'residual_m':float(e)} for name,a,b,f,e in zip(labels,c,t,fitted,residual)],
            'held_out_threequarter':ann['held_out_threequarter'],'limits':'Manual photo annotations and weak-perspective alignment are approximate; the clay views decide likeness. Three-quarter is a held-out visual check, not a fitted score.'}
    measured_errors=[]
    for item in report['landmarks']:
        if item['name'] in measured_by_name:
            measurement=measured_by_name[item['name']];item['measured_target_game_m']=measurement.tolist()
            item['residual_to_measured_m']=float(np.linalg.norm(np.array(item['fitted_game_m'])-measurement));measured_errors.append(item['residual_to_measured_m'])
    report['feature_measured_residual_rms_m']=float(np.sqrt(np.mean(np.square(measured_errors))))
    report['unscaled_warp_maximum_m']=float(np.linalg.norm(delta,axis=1).max())
    # Correctly homologous IRIS POLES plus the tragus register pose only.
    # Tragus is independently annotated in profile; its raw-mesh surface
    # correspondence remains approximate and is not a facial shape target.
    tragus=ann['profile_ear_tragus'];ear_y=mid[1]-(tragus[1]-ann['profile_eye'][1])/sp
    ear_z=mid[2]+(ann['profile_eye'][0]-tragus[0])/sp
    ear,n,ix,dist=bvh.ray_cast(Vector((.30,ear_y,ear_z)),Vector((-1,0,0)),.5)
    if ear is not None:
        ear=np.array(ear);ed,_=warp(ear[None,:]);ear+=ed[0]*strength
        anchors=np.vstack([eyes[0],eyes[1],ear]);want=np.array(ann['held_out_threequarter']['eyes']+[ann['held_out_threequarter']['ear_tragus']],float)
        camera,project=register_quarter(anchors,want,mid,2.0);checks={}
        for name in ['nose_tip','stomion','chin_front']:
            q=project(fitted[labels.index(name)]);target=np.array(ann['held_out_threequarter'][name])
            checks[name]={'projected_px':q.tolist(),'target_px':target.tolist(),'error_px':float(np.linalg.norm(q-target))}
        camera.update({'shape_fit_input':False,'checks':checks,'tragus_source_game_m':ear.tolist(),
                       'calibration_uncertainty':'Only three approximate homologous anchors. Lens distance is not identifiable; pose and held-out errors are diagnostic, not shape ground truth.',
                       'distance_sensitivity':[]})
        for distance in [1.2,4.0]:
            alternative,altproject=register_quarter(anchors,want,mid,distance)
            alternative['heldout_chin_projection_px']=altproject(fitted[labels.index('chin_front')]).tolist()
            camera['distance_sensitivity'].append(alternative)
        report['held_out_camera']=camera
    out=k.evidence_dir(round_no);out.mkdir(parents=True,exist_ok=True);(out/'canonical_fit_audit.json').write_text(json.dumps(report,indent=2)+'\n')
    k.text('KennyCanonicalReferenceFit',{'annotation':ann,'report':report})
    # Explicit reference overlays: green measured targets, orange fitted features.
    reference_path=k.ROOT/ann['reference']
    if not reference_path.is_file():
        print('KENNY_CANONICAL_FIT',json.dumps({key:report[key] for key in ['fit_strength','minimum_head_jacobian_determinant','maximum_head_displacement_m','feature_residual_rms_m']}))
        print('KENNY_REFERENCE_OVERLAY_SKIPPED optional analysis photo unavailable; geometry uses owned JSON/native only')
        return report
    ref=Image.open(reference_path).convert('RGB');draw=ImageDraw.Draw(ref)
    for feature in ann['features']:
        qs=feature['front'] if isinstance(feature['front'][0],list) else [feature['front']]
        for q in qs:draw.ellipse((q[0]-3,q[1]-3,q[0]+3,q[1]+3),outline=(50,255,110),width=2)
        if 'profile' in feature:
            q=feature['profile'];draw.ellipse((q[0]-3,q[1]-3,q[0]+3,q[1]+3),outline=(50,255,110),width=2)
    for name,q in zip(labels,fitted):
        if name.endswith('anchor'):continue
        x=fp[0]+(q[0]-mid[0])*sf;y=fp[1]-(q[1]-mid[1])*sf+slope*(x-fp[0]);draw.ellipse((x-2,y-2,x+2,y+2),fill=(255,160,45))
    if 'held_out_camera' in report:
        for item in report['held_out_camera']['checks'].values():
            x,y=item['projected_px'];draw.ellipse((x-3,y-3,x+3,y+3),outline=(255,160,45),width=2)
            x,y=item['target_px'];draw.ellipse((x-3,y-3,x+3,y+3),outline=(50,255,110),width=2)
    contour=['glabella','nasion','nose_bridge','nose_tip','subnasale','upper_lip','stomion','lower_lip','mentolabial','chin_front','chin_bottom']
    observed={f['name']:f for f in ann['features']}
    draw.line([tuple(observed[n]['profile']) for n in contour],fill=(50,255,110),width=2)
    draw.line([(ann['profile_eye'][0]-(fitted[labels.index(n),2]-mid[2])*sp,ann['profile_eye'][1]-(fitted[labels.index(n),1]-mid[1])*sp) for n in contour],fill=(255,160,45),width=2)
    ref.save(out/'reference_landmark_overlay.png')
    print('KENNY_CANONICAL_FIT',json.dumps({key:report[key] for key in ['front_pixels_per_m','profile_pixels_per_m','fit_strength','minimum_head_jacobian_determinant','maximum_head_displacement_m','feature_residual_rms_m']}))
    return report
