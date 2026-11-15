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
    skin=c[390:455,1195:1240];median=float(np.median(skin@W))
    gain=np.clip((median/np.maximum(illum,.025))**.55,.72,1.65)
    c*=gain[...,None]
    # Chroma-only compensation for the known LIVE Kenny tint, in linear light.
    # Match each pixel's luminance; this is not a brightness/light change.
    lum=c@W;c/=np.array([.73,.65,.59]);c*=lum[...,None]/np.maximum((c@W)[...,None],1e-8)
    c=np.clip(c,0,1)
    photo_processed=Image.fromarray(np.uint8(np.clip(srgb(c)*255,0,255)))
    out=k.evidence_dir(7);out.mkdir(parents=True,exist_ok=True)
    photo_processed.save(out/'source_delighted_preview.jpg',quality=92)

    outputs=k.data('KennyOutputMaps')
    # Start each authoring attempt from the owned pre-projection R3/R6 map,
    # never feed the last projected/generated result back into itself.
    fallback_map=bpy.data.images.get('Map::kenny_head.png') or k.seed_image('kenny_head.png')
    fallback=Image.open(io.BytesIO(bytes(fallback_map.packed_file.data))).convert('RGBA')
    rgba=np.array(fallback);height,width=rgba.shape[:2];result=linear(rgba[:,:,:3]/255.)
    confidence=np.zeros((height,width),np.float32);front_conf=np.zeros_like(confidence)
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
        if np.max(P[:,1])<1.59 or np.min(P[:,1])>1.787 or np.max(P[:,2])<-.13:continue
        U=np.array([uv[i].uv[:] for i in poly.loop_indices]);U=np.c_[U[:,0]*width,(1-U[:,1])*height]
        lo=np.maximum(np.floor(U.min(axis=0)-1).astype(int),[0,0]);hi=np.minimum(np.ceil(U.max(axis=0)+1).astype(int),[width-1,height-1])
        if np.any(hi<lo):continue
        u,v,w=U;matrix=np.column_stack([v-u,w-u]);det=np.linalg.det(matrix)
        if abs(det)<1e-7:continue
        yy0,xx0=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];Q=np.c_[xx0.ravel()+.5,yy0.ravel()+.5]
        bc=(Q-u)@np.linalg.inv(matrix).T;weights=np.c_[1-bc.sum(axis=1),bc]
        inside=np.all(weights>=-.002,axis=1)
        if not inside.any():continue
        weights=weights[inside];rows=yy0.ravel()[inside];cols=xx0.ravel()[inside];p=weights@P
        N=weights@normals[list(poly.loop_indices)];N/=np.maximum(np.linalg.norm(N,axis=1)[:,None],1e-9)
        x=fp[0]+(p[:,0]-mid[0])*sf;y=fp[1]-(p[:,1]-mid[1])*sf+slope*(x-fp[0]);fxy=np.c_[x,y]
        sxy=np.c_[ann['profile_eye'][0]-(p[:,2]-mid[2])*sp,ann['profile_eye'][1]-(p[:,1]-mid[1])*sp]
        fweight=np.maximum(N[:,2],0)**3
        # Profile supplies lateral cheek/temple colour; frontal tissue receives
        # frontal pigment, avoiding a side-photo silhouette painted on the nose.
        side=np.clip((np.abs(p[:,0]-mid[0])-.038)/.032,0,1)
        sweight=np.maximum(np.abs(N[:,0])-.20,0)**3*side*.8
        fweight*=((x>1135)&(x<1425)&(y>268)&(y<585));sweight*=((sxy[:,0]>123)&(sxy[:,0]<345)&(sxy[:,1]>265)&(sxy[:,1]<578))
        total=fweight+sweight;coverage=np.clip(total*1.8,0,1)
        coverage*=k.smooth((p[:,1]-1.594)/.018)*(1-k.smooth((p[:,1]-1.772)/.018))
        coverage*=1-k.smooth((np.abs(p[:,0]-mid[0])-.080)/.018)
        # Never project onto the back of the head / underside of the jaw.
        coverage*=k.smooth((p[:,2]+.115)/.055)
        colour=(sample(c,fxy)*fweight[:,None]+sample(c,sxy)*sweight[:,None])/np.maximum(total[:,None],1e-8)
        old=result[rows,cols];result[rows,cols]=old*(1-coverage[:,None])+colour*coverage[:,None]
        confidence[rows,cols]=np.maximum(confidence[rows,cols],coverage);front_conf[rows,cols]=fweight
        raster_triangles+=1
        if len(photo_facing)<220 and poly.index%61==0 and np.mean(coverage)>.55:photo_facing.append(np.mean(fxy,axis=0).tolist())
    rgba[:,:,:3]=np.uint8(np.clip(srgb(result)*255,0,255));paint=Image.fromarray(rgba,'RGBA')
    # Dilate only into atlas padding, not into other material islands. Existing
    # fallback remains elsewhere and all map dimensions/material keys are held.
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
           'partial_delighting':{'gaussian_radius_source_px':15,'luminance_exponent':.55,'gain_limits':[.72,1.65]},
           'live_tint_compensation':'Inverse chroma in linear light, normalized to identical per-pixel luminance; runtime tint remains live',
           'eye_colour':'Separate brown eye geometry/maps unchanged. Visible photographic eyeballs excluded from skin source.',
           'source_photo_detail_limit':'Portrait face about250px wide; this does not create scan/pore fidelity.',
           'map_dimensions':[width,height],'head_triangles_rasterized':raster_triangles,
           'covered_texels_over_half':int(np.count_nonzero(confidence>.5)),'maximum_projection_coverage':float(confidence.max()),
           'geometry_changes':False,'groom_changes':False,'new_materials':0,'reference_sha256':k.sha(photo_path)}
    k.text('KennyReferenceSurfaceAudit',audit);(out/'surface_authoring_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print('KENNY_SURFACE_AUTHOR',json.dumps(audit))
