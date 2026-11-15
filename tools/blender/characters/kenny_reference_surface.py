"""Optional photo-to-owned-UV authoring pass for the accepted R7 clay mesh.

Normal regeneration consumes the resulting packed map, not the photograph.
Projection is evaluated on the final mesh rather than guessed atlas bands.
"""
import io,json,pathlib
import bpy
import numpy as np
from PIL import Image,ImageDraw,ImageFilter

W=np.array([.2126,.7152,.0722])

def linear(a):return np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
def srgb(a):return np.where(a<=.0031308,a*12.92,1.055*np.maximum(a,0)**(1/2.4)-.055)

def sample(image,xy):
    x=np.clip(xy[:,0],0,image.shape[1]-1.001);y=np.clip(xy[:,1],0,image.shape[0]-1.001)
    ix=x.astype(int);iy=y.astype(int);fx=(x-ix)[:,None];fy=(y-iy)[:,None]
    return (image[iy,ix]*(1-fx)+image[iy,ix+1]*fx)*(1-fy)+(image[iy+1,ix]*(1-fx)+image[iy+1,ix+1]*fx)*fy

def skin_confidence(size,polygon,k):
    """C1 feather INSIDE an annotated skin contour, excluding photo hair."""
    mask=Image.new('L',size,0);ImageDraw.Draw(mask).polygon(polygon,fill=255)
    edge=np.asarray(mask.filter(ImageFilter.GaussianBlur(5)),dtype=float)/255
    return k.smooth((edge-.52)/.43)

def boundaries(k):
    """V3: local continuation from a frozen owned V2 map; no photo re-bake."""
    out=k.evidence_dir(7);out.mkdir(parents=True,exist_ok=True)
    body=bpy.data.objects['Body'];mesh=body.data;outputs=k.data('KennyOutputMaps')
    frozen=bpy.data.images.get('BoundarySeed::kenny_head_v2.png')
    if frozen is not None and not k.data('KennySurfaceSource').get('boundary_version'):
        # A deliberate later surface-author resets its source manifest. Start
        # the new boundary pass from that new owned preview, not a stale seed.
        bpy.data.images.remove(frozen);frozen=None
    if frozen is None:
        scratch=pathlib.Path('/tmp/aegis-kenny-author/kenny_head_v2_boundary_seed.png');scratch.parent.mkdir(exist_ok=True)
        scratch.write_bytes(bytes(bpy.data.images[outputs['kenny_head.png']].packed_file.data))
        frozen=k.packed_map(scratch,'kenny_head_v2_boundary_seed.png',True);frozen.name='BoundarySeed::kenny_head_v2.png'
    raw_bytes=bytes(frozen.packed_file.data);base=Image.open(io.BytesIO(raw_bytes)).convert('RGBA')
    rgba=np.array(base);h,w=rgba.shape[:2];source=linear(rgba[:,:,:3]/255.);result=source.copy()
    # Use only the owned V2 forehead's observed skin frequency / colour. This
    # continues existing data into the flat fallback, rather than stamping more
    # source portrait pixels or changing the accepted central face.
    box=(int(.42*w),int(.230*h),int(.58*w),int(.278*h));patch=base.crop(box).convert('RGB')
    patch_c=linear(np.asarray(patch,float)/255.);blur_c=linear(np.asarray(patch.filter(ImageFilter.GaussianBlur(6)),float)/255.)
    detail=np.clip(patch_c/np.maximum(blur_c,.025),.86,1.14)
    forehead_mean=np.median(patch_c.reshape(-1,3),axis=0)
    uv=mesh.uv_layers.active.data;P=np.array([k.game(body.matrix_world@v.co)[:] for v in mesh.vertices]);mid=k.data('KennyCanonicalReferenceFit')['report']['eye_anchor_game_m'][0]
    # Exact coincident material-border pairs identify the owned adjacent body
    # colour; the fix is local to the head side of the seam, not a body repaint.
    head_border={};body_border={};skin_images={}
    for poly in mesh.polygons:
        name=mesh.materials[poly.material_index].name
        if name not in k.SKIN:continue
        if name!=k.HEAD and name not in skin_images:
            img=bpy.data.images[outputs[k.SKIN[name]]];skin_images[name]=linear(np.array(Image.open(io.BytesIO(bytes(img.packed_file.data))).convert('RGB'))/255.)
        for li in poly.loop_indices:
            v=mesh.loops[li].vertex_index
            if P[v,1]>1.70:continue
            key=tuple(np.round(P[v],5));(head_border if name==k.HEAD else body_border).setdefault(key,(li,name))
    seam_points=[];seam_ratios=[];body_colours=[]
    for key in head_border.keys()&body_border.keys():
        hl,_=head_border[key];bl,name=body_border[key];hu=uv[hl].uv;bu=uv[bl].uv;image=skin_images[name]
        hc=sample(source,np.array([[hu.x*w,(1-hu.y)*h]]))[0]
        bc=sample(image,np.array([[bu.x*image.shape[1],(1-bu.y)*image.shape[0]]]))[0]
        seam_points.append(key);seam_ratios.append(np.clip(bc/np.maximum(hc,.025),.65,1.55));body_colours.append(bc)
    seam_points=np.array(seam_points);seam_ratios=np.array(seam_ratios);body_colours=np.array(body_colours)
    neck_mean=np.median(body_colours,axis=0) if len(body_colours) else forehead_mean
    mask_atlas=np.zeros((h,w),np.float32);valid=np.zeros((h,w),bool);core_error=0.;temple_conf=[]
    # Provenance is diagnostic only: V2 recorded the observed-source confidence
    # atlas. It is not required for this owned-map boundary postprocess.
    confidence_path=k.ROOT/'gauntlet/refs/kenny_judge_continued_2026_11_14/round7/surface_preview2/head_projection_coverage.png'
    provenance=np.array(Image.open(confidence_path),float)/255 if confidence_path.exists() else None
    for poly in mesh.polygons:
        if mesh.materials[poly.material_index].name!=k.HEAD:continue
        vertices=list(poly.vertices);pverts=P[vertices];U=np.array([uv[i].uv[:] for i in poly.loop_indices]);U=np.c_[U[:,0]*w,(1-U[:,1])*h]
        lo=np.maximum(np.floor(U.min(axis=0)-1).astype(int),[0,0]);hi=np.minimum(np.ceil(U.max(axis=0)+1).astype(int),[w-1,h-1])
        if np.any(hi<lo):continue
        matrix=np.column_stack([U[1]-U[0],U[2]-U[0]])
        if abs(np.linalg.det(matrix))<1e-7:continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];Q=np.c_[xx.ravel()+.5,yy.ravel()+.5];bc=(Q-U[0])@np.linalg.inv(matrix).T;B=np.c_[1-bc.sum(axis=1),bc]
        inside=np.all(B>=-.002,axis=1)
        if not inside.any():continue
        rows=yy.ravel()[inside];cols=xx.ravel()[inside];p=B[inside]@pverts;valid[rows,cols]=True
        scalp=k.smooth((p[:,1]-1.740)/.035)
        temple=k.smooth((np.abs(p[:,0]-mid)-.042)/.020)*k.smooth((p[:,1]-1.705)/.020)*(1-k.smooth((p[:,1]-1.775)/.025))
        temple*=k.smooth((p[:,2]+.108)/.030)*(1-k.smooth((p[:,2]+.025)/.025))
        nape=k.smooth((-p[:,2]-.065)/.040)*k.smooth((p[:,1]-1.540)/.045)
        mask=np.maximum.reduce([scalp,temple,nape])
        # Hard hold on central brow, nose, lips, stubble: this is a boundary pass.
        core=(np.abs(p[:,0]-mid)<.045)&(p[:,1]<1.738)&(p[:,2]>-.030)
        mask[core]=0
        a=np.abs((((p[:,0]*12.3+p[:,2]*8.7+.17)%1)*2)-1)*(detail.shape[1]-1)
        b=np.abs((((p[:,1]*15.7+p[:,2]*6.1+.39)%1)*2)-1)*(detail.shape[0]-1)
        noise=sample(detail,np.c_[a,b]);neck=1-k.smooth((p[:,1]-1.550)/.140)
        colour=(forehead_mean[None,:]*(1-neck[:,None])+neck_mean[None,:]*neck[:,None])*noise
        old=source[rows,cols];new=old*(1-mask[:,None])+colour*mask[:,None]
        if len(seam_points):
            ds=np.sum((p[:,None,:]-seam_points[None,:,:])**2,axis=2);nearest=np.argmin(ds,axis=1);distance=np.sqrt(ds[np.arange(len(p)),nearest])
            seam=1-k.smooth(distance/.035);seam[core]=0
            # Anchors sample the same frozen V2 input as the current pixels.
            corrected=old*seam_ratios[nearest]
            new=new*(1-seam[:,None])+corrected*seam[:,None]
            mask=np.maximum(mask,seam)
        result[rows,cols]=new;mask_atlas[rows,cols]=np.maximum(mask_atlas[rows,cols],mask)
        if core.any():core_error=max(core_error,float(np.max(abs(new[core]-old[core]))))
        if provenance is not None and (temple>.7).any():temple_conf.extend(provenance[rows[temple>.7],cols[temple>.7]].tolist())
    # Refresh only padding neighbouring edited boundary texels; central face
    # colours remain byte-identical after sRGB round-trip quantisation.
    for _ in range(3):
        count=np.zeros((h,w),np.float32);acc=np.zeros_like(result);edit=np.zeros((h,w),np.float32)
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            vv=np.roll(valid,(dy,dx),(0,1));count+=vv;acc+=np.roll(result,(dy,dx),(0,1))*vv[...,None];edit=np.maximum(edit,np.roll(mask_atlas,(dy,dx),(0,1)))
        fill=(~valid)&(count>0)&(edit>.01);result[fill]=acc[fill]/count[fill,None];valid[fill]=True
    rgba[:,:,:3]=np.uint8(np.clip(np.rint(srgb(result)*255),0,255));paint=Image.fromarray(rgba,'RGBA')
    old=bpy.data.images.get('SurfaceMap::kenny_head.png')
    if old:bpy.data.images.remove(old)
    image=k.store_map('kenny_head_reference_surface.png',paint);image.name='SurfaceMap::kenny_head.png';image['output_name']='kenny_head.png'
    outputs['kenny_head.png']=image.name;k.text('KennyOutputMaps',outputs)
    source_info=k.data('KennySurfaceSource');source_info.update({'boundary_version':3,'owned_boundary_input':frozen.name,'boundary_input_sha256':__import__('hashlib').sha256(raw_bytes).hexdigest()});k.text('KennySurfaceSource',source_info)
    paint.resize((1024,1024)).save(out/'head_surface_atlas_preview.png');Image.fromarray(np.uint8(mask_atlas*255)).save(out/'boundary_edit_mask.png')
    audit={'recipe_version':3,'method':'Masked postprocess of frozen packed V2 albedo, not a global photo re-bake','input':frozen.name,'input_sha256':source_info['boundary_input_sha256'],
           'core_face_max_linear_colour_delta':core_error,'geometry_changes':False,'groom_changes':False,'global_colour_or_exposure_changes':False,
           'forehead_frequency_source':{'owned_v2_patch_atlas_px':box,'highpass_blur_px':6,'ratio_limits':[.86,1.14],'mean_linear_rgb':forehead_mean.tolist()},
           'body_border_pairs':len(seam_points),'neck_mean_linear_rgb':neck_mean.tolist(),'body_border_match_radius_m':.035,
           'temple_tuft_provenance':{'v2_source_confidence_median':float(np.median(temple_conf)) if temple_conf else None,'pixels_over_half_source':float(np.mean(np.array(temple_conf)>.5)) if temple_conf else None,'interpretation':'Confidence is the V2 projected-photo contribution; remaining contribution is the older owned fallback.'},
           'limitations':'Local texture continuation uses observed owned forehead frequency, not a new measured scalp scan; border colours use existing owned body maps.'}
    k.text('KennySurfaceBoundaryAudit',audit);(out/'boundary_authoring_audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('KENNY_SURFACE_BOUNDARY',json.dumps(audit))

def author(k):
    body=bpy.data.objects['Body'];mesh=body.data;ann=json.loads(pathlib.Path(__file__).with_name('kenny_reference_landmarks.json').read_text())
    report=k.data('KennyCanonicalReferenceFit')['report'];photo_path=k.ROOT/ann['reference']
    if not photo_path.is_file():raise FileNotFoundError('The optional surface-author action needs its confirmed source photo: '+str(photo_path))
    photo=Image.open(photo_path).convert('RGB');a=np.array(photo,dtype=float)/255
    # Do not stamp sclera/pupils onto surrounding eyelid skin. Interpolate only
    # inside the visible eyeball ellipses; the separate owned brown eye remains.
    yy,xx=np.mgrid[:a.shape[0],:a.shape[1]]
    for cx,cy in ann['front_eyes']+ann['held_out_threequarter']['eyes']+[ann['profile_eye']]:
        rx,ry=(14,6.2) if cx>1100 else ((10,6) if cx>500 else (7,6))
        r=((xx-cx)/rx)**2+((yy-cy)/ry)**2;mask=np.clip((1-r)*3,0,1)
        xa=np.clip(np.arange(a.shape[1]),0,a.shape[1]-1)
        top=a[max(0,int(cy-ry-2)),xa];bottom=a[min(a.shape[0]-1,int(cy+ry+2)),xa]
        t=np.clip((yy-cy+ry)/(2*ry),0,1)[...,None];fill=top[None,:,:]*(1-t)+bottom[None,:,:]*t
        a=a*(1-mask[...,None])+fill*mask[...,None]
    clean=Image.fromarray(np.uint8(np.clip(a*255,0,255)))
    blur=np.asarray(clean.filter(ImageFilter.GaussianBlur(15)),float)/255
    c=linear(a);illum=linear(blur)@W
    # Partial broad-scale de-lighting: flatten large photographic highlights /
    # shadow gradients, while preserving the small actual hairs and freckles.
    # The exposed forehead provides the illumination reference, rather than
    # the shaded lateral cheek used by preview1. This matches source exposure
    # and removes the broad dark lower-face cast instead of baking it in.
    skin=c[285:322,1220:1350];median=float(np.median(skin@W))
    gain=np.clip((median/np.maximum(illum,.025))**.80,.72,2.25)
    c*=gain[...,None]
    # Chroma-only compensation for the known LIVE Kenny tint, in linear light.
    # Match each pixel's luminance; this is not a brightness/light change.
    tint=linear(np.array([.73,.65,.59]))
    lum=c@W;c/=tint;c*=lum[...,None]/np.maximum((c@W)[...,None],1e-8)
    c=np.clip(c,0,1)
    # Retain the reference's short hairs while softening broad beard paint.
    # The lip ellipse is excluded so its natural colour/detail is not washed.
    clean_skin=np.median(c[285:322,1220:1350].reshape(-1,3),axis=0)
    beard_front=k.smooth((yy-458)/28)*(1-k.smooth((yy-565)/20))*k.smooth((xx-1155)/35)*(1-k.smooth((xx-1390)/35))
    lip=1-k.smooth((((xx-1283)/49)**2+((yy-494)/20)**2-.75)/.6)
    beard_profile=k.smooth((yy-435)/35)*(1-k.smooth((yy-558)/25))*k.smooth((xx-150)/35)*(1-k.smooth((xx-320)/30))
    soften=np.clip(beard_front*(1-lip)+beard_profile,0,1)*.12
    c=c*(1-soften[...,None])+clean_skin*soften[...,None]
    photo_processed=Image.fromarray(np.uint8(np.clip(srgb(c)*255,0,255)))
    out=k.evidence_dir(7);out.mkdir(parents=True,exist_ok=True)
    photo_processed.save(out/'source_delighted_preview.jpg',quality=92)
    front_polygon=[(1215,265),(1255,253),(1332,253),(1370,267),(1395,315),(1410,400),(1405,457),(1374,514),(1335,557),(1284,580),(1235,562),(1190,528),(1162,476),(1149,424),(1161,354),(1184,310)]
    profile_polygon=[(158,310),(211,294),(250,306),(272,334),(287,361),(295,397),(297,446),(277,495),(231,542),(187,566),(172,549),(166,519),(153,486),(152,459),(125,442),(117,430),(137,390),(154,369),(144,345)]
    front_skin=skin_confidence(photo.size,front_polygon,k);profile_skin=skin_confidence(photo.size,profile_polygon,k)
    Image.fromarray(np.uint8(np.maximum(front_skin,profile_skin)*255)).save(out/'source_valid_skin_confidence.png')

    outputs=k.data('KennyOutputMaps')
    # Start each authoring attempt from the owned pre-projection R3/R6 map,
    # never feed the last projected/generated result back into itself.
    fallback_map=bpy.data.images.get('Map::kenny_head.png') or k.seed_image('kenny_head.png')
    fallback=Image.open(io.BytesIO(bytes(fallback_map.packed_file.data))).convert('RGBA')
    rgba=np.array(fallback);height,width=rgba.shape[:2];result=linear(rgba[:,:,:3]/255.)
    confidence=np.zeros((height,width),np.float32);front_conf=np.zeros_like(confidence);uv_valid=np.zeros((height,width),bool)
    mw=np.array(body.matrix_world);rot=np.array([[1,0,0],[0,0,1],[0,-1,0]])
    positions=(np.array([v.co[:] for v in mesh.vertices])@mw[:3,:3].T+mw[:3,3])@rot.T
    normals=np.array([n.vector[:] for n in mesh.corner_normals])@np.linalg.inv(mw[:3,:3])@rot.T
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-9)
    uv=mesh.uv_layers.active.data;mid=np.array(report['eye_anchor_game_m']);fp=np.mean(ann['front_eyes'],axis=0)
    slope=np.tan(np.radians(report['front_roll_degrees']));sf=report['front_pixels_per_m'];sp=report['profile_pixels_per_m']
    photo_facing=[];raster_triangles=0
    for poly in mesh.polygons:
        if mesh.materials[poly.material_index].name!=k.HEAD:continue
        vertices=np.array(list(poly.vertices));P=positions[vertices]
        if np.max(P[:,1])<1.555:continue
        U=np.array([uv[i].uv[:] for i in poly.loop_indices]);U=np.c_[U[:,0]*width,(1-U[:,1])*height]
        lo=np.maximum(np.floor(U.min(axis=0)-1).astype(int),[0,0]);hi=np.minimum(np.ceil(U.max(axis=0)+1).astype(int),[width-1,height-1])
        if np.any(hi<lo):continue
        u,v,w=U;matrix=np.column_stack([v-u,w-u]);det=np.linalg.det(matrix)
        if abs(det)<1e-7:continue
        yy0,xx0=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];Q=np.c_[xx0.ravel()+.5,yy0.ravel()+.5]
        bc=(Q-u)@np.linalg.inv(matrix).T;weights=np.c_[1-bc.sum(axis=1),bc]
        inside=np.all(weights>=-.002,axis=1)
        if not inside.any():continue
        weights=weights[inside];rows=yy0.ravel()[inside];cols=xx0.ravel()[inside];p=weights@P;uv_valid[rows,cols]=True
        N=weights@normals[list(poly.loop_indices)];N/=np.maximum(np.linalg.norm(N,axis=1)[:,None],1e-9)
        x=fp[0]+(p[:,0]-mid[0])*sf;y=fp[1]-(p[:,1]-mid[1])*sf+slope*(x-fp[0]);fxy=np.c_[x,y]
        sxy=np.c_[ann['profile_eye'][0]-(p[:,2]-mid[2])*sp,ann['profile_eye'][1]-(p[:,1]-mid[1])*sp]
        fvalid=sample(front_skin[...,None],fxy)[:,0];svalid=sample(profile_skin[...,None],sxy)[:,0]
        fweight=np.maximum(N[:,2],0)**2*fvalid
        # Profile supplies lateral cheek/temple colour; frontal tissue receives
        # frontal pigment, avoiding a side-photo silhouette painted on the nose.
        side=np.clip((np.abs(p[:,0]-mid[0])-.038)/.032,0,1)
        sweight=np.maximum(np.abs(N[:,0])-.20,0)**2*side*.8*svalid
        total=fweight+sweight
        fc=np.clip(N[:,2]*2,0,1)*fvalid;sc=np.clip((np.abs(N[:,0])-.15)*1.8,0,1)*side*svalid
        coverage=1-(1-fc)*(1-sc)
        coverage*=k.smooth((p[:,1]-1.594)/.018)*(1-k.smooth((p[:,1]-1.772)/.018))
        coverage*=1-k.smooth((np.abs(p[:,0]-mid[0])-.080)/.018)
        # Never project onto the back of the head / underside of the jaw.
        coverage*=k.smooth((p[:,2]+.115)/.055)
        colour=(sample(c,fxy)*fweight[:,None]+sample(c,sxy)*sweight[:,None])/np.maximum(total[:,None],1e-8)
        old=result[rows,cols]
        # The fallback contained old photographed buzz-cut hair and a hard
        # nape edge. Replace that pigment with clean owned skin, smoothly in
        # 3D, including unobserved scalp. It must pass hair-hidden inspection.
        scalp=k.smooth((p[:,1]-1.738)/.035)
        back=k.smooth((-p[:,2]-.065)/.040)*k.smooth((p[:,1]-1.625)/.065)
        temple=k.smooth((np.abs(p[:,0]-mid[0])-.065)/.025)*k.smooth((p[:,1]-1.705)/.055)
        erase=np.maximum.reduce([scalp,back,temple])
        # Clear old opaque beard/eyebrow paint before applying observed colour;
        # unobserved facial returns receive skin, not the old dark full beard.
        face_clean=k.smooth((p[:,2]+.075)/.045)*k.smooth((p[:,1]-1.59)/.025)*(1-k.smooth((np.abs(p[:,0]-mid[0])-.075)/.020))*.72
        lip_region=k.smooth((.030-np.abs(p[:,0]-mid[0]))/.006)*k.smooth((p[:,1]-1.629)/.005)*(1-k.smooth((p[:,1]-1.650)/.005))
        face_clean*=1-lip_region
        erase=np.maximum(erase,face_clean)
        old=old*(1-erase[:,None])+clean_skin*erase[:,None]
        result[rows,cols]=old*(1-coverage[:,None])+colour*coverage[:,None]
        confidence[rows,cols]=np.maximum(confidence[rows,cols],coverage);front_conf[rows,cols]=fweight
        raster_triangles+=1
        if len(photo_facing)<220 and poly.index%61==0 and np.mean(coverage)>.55:photo_facing.append(np.mean(fxy,axis=0).tolist())
    # Tiny triangles / UV boundaries otherwise leave single-texel old-hair
    # pinholes. Three texels of neighbour-colour padding close only raster gaps
    # and immediate island borders, without blurring the observed facial hairs.
    before_valid=uv_valid.copy()
    for _ in range(3):
        count=np.zeros((height,width),np.float32);acc=np.zeros_like(result)
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            valid=np.roll(uv_valid,(dy,dx),(0,1));count+=valid;acc+=np.roll(result,(dy,dx),(0,1))*valid[...,None]
        fill=(~uv_valid)&(count>0);result[fill]=acc[fill]/count[fill,None];uv_valid[fill]=True
    rgba[:,:,:3]=np.uint8(np.clip(srgb(result)*255,0,255));paint=Image.fromarray(rgba,'RGBA')
    Image.fromarray(np.uint8(before_valid)*255).save(out/'head_uv_raster_coverage.png')
    old=bpy.data.images.get('SurfaceMap::kenny_head.png')
    if old:bpy.data.images.remove(old)
    image=k.store_map('kenny_head_reference_surface.png',paint);image.name='SurfaceMap::kenny_head.png';image['output_name']='kenny_head.png'
    outputs['kenny_head.png']=image.name;k.text('KennyOutputMaps',outputs)
    k.text('KennySurfaceSource',{'packed_head_map':image.name,'source_reference':ann['reference'],
           'reference_sha256':k.sha(photo_path),'accepted_geometry':'R7 clay draft2','cold_rebuild_reads_photo':False,
           'live_tint_chroma_compensated':[.73,.65,.59],'no_tint_brightness_bake':True,'body_bulk_baked':False})
    Image.fromarray(np.uint8(confidence*255)).save(out/'head_projection_coverage.png')
    paint.resize((1024,1024)).save(out/'head_surface_atlas_preview.png')
    photo_overlay=photo.copy();d=ImageDraw.Draw(photo_overlay)
    for x,y in photo_facing:d.ellipse((x-2,y-2,x+2,y+2),outline=(0,240,240),width=1)
    photo_overlay.save(out/'actual_mesh_projection_markers.png')
    audit={'geometry_basis':'Actual accepted Body positions and its existing per-loop UVs; no guessed brow atlas line',
           'photo_source':ann['reference'],'photograph_used_only_for_optional_authoring':True,
           'cold_regeneration':'Packed SurfaceMap::kenny_head.png restored directly; photo not read',
           'projection':'Corrected front iris registration plus independent profile registration; facing-angle blend on lateral tissue',
           'recipe_version':2,'source_skin_masks':{'front':front_polygon,'profile':profile_polygon,'feather_blur_px':5,'C1_thresholds':[.52,.95]},
           'partial_delighting':{'gaussian_radius_source_px':15,'luminance_exponent':.80,'gain_limits':[.72,2.25],'reference_patch':'Unshadowed front forehead [1220:1350,285:322]'},
           'live_tint_compensation':'Divide by srgb_to_linear([.73,.65,.59]), then normalize to identical per-pixel luminance; actual Godot pixel test verified source_color conversion',
           'effective_linear_tint':tint.tolist(),'scalp_fallback':'Clean owned skin replaces old hair pigment with C1 world-space masks, visible in hair-hidden review',
           'eye_colour':'Separate brown eye geometry/maps unchanged. Visible photographic eyeballs excluded from skin source.',
           'source_photo_detail_limit':'Portrait face about250px wide; this does not create scan/pore fidelity.',
           'map_dimensions':[width,height],'head_triangles_rasterized':raster_triangles,
           'covered_texels_over_half':int(np.count_nonzero(confidence>.5)),'maximum_projection_coverage':float(confidence.max()),
           'geometry_changes':False,'groom_changes':False,'new_materials':0,'reference_sha256':k.sha(photo_path)}
    k.text('KennyReferenceSurfaceAudit',audit);(out/'surface_authoring_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print('KENNY_SURFACE_AUTHOR',json.dumps(audit))
