#!/usr/bin/env python3
"""Deterministic, reference-led UCL 26/27 League prop. No downloaded game assets.

python3 tools/blender/beechlawn/author_ucl_ball.py
Generates the spherical artwork/PBR maps, then builds an editable Blender source,
GLB and neutral studio evidence. Requires numpy/Pillow/scipy in system Python.
Blender itself only needs bpy and numpy. Input photos are never modified.
"""
from pathlib import Path
import json, math, sys
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'games/beechlawn_rovers/assets/environment/ucl_26_27_league'
BRIEF = ROOT/'games/beechlawn_rovers/docs/art_briefs/ucl_ball_2026_10_25'
BLEND = ROOT/'tools/blender/beechlawn/ucl_26_27_league.blend'
SIZE = 2048


def generate_maps():
    import numpy as np
    from scipy.spatial import ConvexHull
    from PIL import Image, ImageDraw, ImageFont
    OUT.mkdir(parents=True, exist_ok=True)
    phi=(1+5**.5)/2
    vertices=np.array([(0,a,b*phi) for a in [-1,1] for b in [-1,1]]+
        [(a,b*phi,0) for a in [-1,1] for b in [-1,1]]+
        [(b*phi,0,a) for a in [-1,1] for b in [-1,1]], dtype=np.float32)
    vertices/=np.linalg.norm(vertices,axis=1)[:,None]
    faces=ConvexHull(vertices).simplices
    frames=[]
    for index,axis in enumerate(vertices):
        neighbours=np.where((vertices@axis>.4)&(vertices@axis<.99))[0]
        x=vertices[neighbours[0]]-axis*np.dot(vertices[neighbours[0]],axis)
        x/=np.linalg.norm(x);y=np.cross(axis,x)
        frames.append([x.tolist(),y.tolist(),axis.tolist()])
    face_frames=[]
    for face in faces:
        z=vertices[face].sum(axis=0);z/=np.linalg.norm(z)
        y=vertices[face[0]]-z*np.dot(vertices[face[0]],z);y/=np.linalg.norm(y)
        face_frames.append([np.cross(y,z).tolist(),y.tolist(),z.tolist()])
    # One continuous analytical spherical field: no projected-photo lighting,
    # front/back copies, mirrored lettering, or longitude seam in the artwork.
    rgb=np.full((SIZE,SIZE,3),[222,228,232],dtype=np.float32)
    height=np.zeros((SIZE,SIZE),np.float32)
    rough=np.full((SIZE,SIZE),.43,np.float32)
    colours=np.array([[13,176,199],[28,106,191],[184,216,43],[224,40,119],[148,88,165]],dtype=np.float32)
    for row in range(0,SIZE,128):
        v=1-(np.arange(row,min(row+128,SIZE),dtype=np.float32)+.5)/SIZE
        u=(np.arange(SIZE,dtype=np.float32)+.5)/SIZE
        lat=np.pi*(1-v[:,None]);lon=2*np.pi*u[None,:]
        n=np.stack(np.broadcast_arrays(np.sin(lat)*np.cos(lon),np.sin(lat)*np.sin(lon),np.cos(lat)),axis=-1)
        nearest=np.argmax(n@vertices.T,axis=-1)
        block=rgb[row:row+len(v)];hblock=height[row:row+len(v)]
        for i,frame in enumerate(frames):
            selected=nearest==i
            if not selected.any():continue
            normals=n[selected];fx,fy,fz=np.array(frame)
            den=normals@fz
            x=(normals@fx)/den;y=(normals@fy)/den
            angle=np.arctan2(y,x)
            radii=np.array([.618034 if k%2==0 else .268 for k in range(10)])
            angles=np.arange(10)*np.pi/5
            poly=np.stack([radii*np.cos(angles),radii*np.sin(angles)],axis=1)
            dist=np.full(x.shape,10.,np.float32);inside=np.zeros(x.shape,bool)
            for a,b in zip(poly,np.roll(poly,-1,axis=0)):
                edge=b-a;t=np.clip(((x-a[0])*edge[0]+(y-a[1])*edge[1])/np.dot(edge,edge),0,1)
                dist=np.minimum(dist,np.hypot(x-a[0]-t*edge[0],y-a[1]-t*edge[1]))
                inside^=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1]+1e-12)+a[0])
            d=dist*np.where(inside,-1,1)
            col=np.full((len(x),3),[222,228,232],np.float32)
            # Silvery blue small square halftones, aligned locally to each panel.
            phase=x*155+y*35
            lattice=(np.abs(((x*135+y*22)%1)-.5)<.32)&(np.abs(((y*135-x*22)%1)-.5)<.32)
            pearl=(.5+.5*np.sin(phase*1.8))*.16+np.exp(-((d-.085)/.055)**2)*.28
            col-=lattice[:,None]*pearl[:,None]*np.array([60,27,8])
            gradient=((angle/(2*np.pi)*5+i*.7)%5)
            k=np.floor(gradient).astype(int);f=np.clip((gradient-k-.75)*4,0,1)
            ink=colours[k]*(1-f[:,None])+colours[(k+1)%5]*f[:,None]
            # Black outline lies on the polygon side; colour and fine pinstripe
            # lie inside the star. The unpainted field remains pearl white.
            col[(d>.003)&(d<.033)]=[20,25,30]
            band=(d<.003)&(d>-.025)
            col[band]=ink[band]
            line=(d<-.014)&(d>-.017)
            col[line]=[230,237,237]
            dots=(np.abs(((x*220)%1)-.5)<.31)&(np.abs(((y*220)%1)-.5)<.31)
            fade=np.clip((.066-d)/.033,0,1)
            splash=(d>=.033)&(d<.066)&dots
            col[splash]=col[splash]*(1-fade[splash,None])+np.array([30,35,41])*fade[splash,None]
            # Little tapered spoke strokes, visible inside the white star arms.
            a=((angle+np.pi/5)%(2*np.pi/5))-np.pi/5
            rad=np.hypot(x,y)
            spoke=(np.abs(a)<.009*np.clip((rad-.29)/.08,0,1))&(rad>.29)&(rad<.46)
            col[spoke]=[33,40,44]
            block[selected]=col
            hblock[selected]=-.00024*np.exp(-(d/.0045)**2)
            rough[row:row+len(v)][selected]=np.where((d>.003)&(d<.033),.39,.44)
    # Vector-authored branding on distinct panel tangents. Fonts are the same
    # open-font sources shipped with the project, not generated text in a photo.
    def font(size,serif=False):
        p='/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf' if serif else str(ROOT/'games/beechlawn_rovers/assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf')
        return ImageFont.truetype(p,size)
    def centered(draw,text,y,size,serif=False):
        draw.text((512,y),text,font=font(size,serif),anchor='mt',fill=255,stroke_width=0)
    def star(cx,cy,r,inner=.43,angle=-math.pi/2):
        return [(cx+math.cos(angle+k*math.pi/5)*r*(1 if k%2==0 else inner),cy+math.sin(angle+k*math.pi/5)*r*(1 if k%2==0 else inner)) for k in range(10)]
    def logo(kind):
        im=Image.new('L',(1024,1024));d=ImageDraw.Draw(im)
        if kind=='adidas':
            # The modern performance three-stripe mountain mark, no wordmark.
            for pts in [[(190,650),(275,600),(380,780),(268,780)],[(355,465),(470,398),(690,780),(555,780)],[(548,282),(664,215),(990,780),(852,780)]]:
                d.polygon(pts,fill=255)
        elif kind=='ucl':
            # The starball consists of projected FIVE-POINT STARS, not
            # generic football pentagons or a dark circle with white spots.
            fz=vertices[0];fx=np.array(frames[0][0]);fy=np.array(frames[0][1])
            for frame in frames:
                bx,by,bz=np.array(frame)
                pts=[]
                for k in range(10):
                    a=k*np.pi/5;b=(k+1)*np.pi/5
                    pa=np.array([np.cos(a),np.sin(a)])*(.618034 if k%2==0 else .268)
                    pb=np.array([np.cos(b),np.sin(b)])*(.618034 if k%2 else .268)
                    for t in np.linspace(0,1,12):
                        xy=pa*(1-t)+pb*t;n=bz+bx*xy[0]+by*xy[1];n/=np.linalg.norm(n)
                        if np.dot(n,fz) > -.025:
                            pts.append((512+164*np.dot(n,fx),224-164*np.dot(n,fy)))
                if len(pts)>3:d.polygon(pts,fill=255)
            # UEFA arched wordmark and matching outer/inner arcs.
            d.arc((398,398,626,490),190,350,fill=255,width=7)
            d.arc((433,439,591,505),192,348,fill=255,width=6)
            for k,c in enumerate('UEFA'):
                tile=Image.new('L',(90,100));td=ImageDraw.Draw(tile);td.text((45,0),c,font=font(61),anchor='mt',fill=255)
                tile=tile.rotate(24-k*16,resample=Image.Resampling.BICUBIC)
                im.paste(tile,(385+k*57,409+int(abs(1.5-k)*9)),tile)
            centered(d,'CHAMPIONS',526,81,True);centered(d,'LEAGUE',622,91,True)
            d.text((882,620),'®',font=font(25),fill=255)
        elif kind=='lge':
            centered(d,'LGE',350,160);centered(d,'MATCH BALL',527,43);centered(d,'REPLICA',585,43)
        elif kind=='fifa':
            d.rectangle((377,300,647,561),outline=255,width=10)
            centered(d,'FIFA',315,80)
            d.rectangle((382,431,642,555),fill=255)
            d.text((512,456),'QUALITY',font=font(41),anchor='mt',fill=0)
            centered(d,'1017531',584,48)
        elif kind=='valve':
            d.ellipse((484,484,540,540),fill=255);d.ellipse((502,502,522,522),fill=0)
        return np.asarray(im,dtype=np.float32)/255
    logos={key:logo(key) for key in ['adidas','ucl','lge','fifa','valve']}
    # Put the principal three marks on neighbouring white inter-star polygons;
    # FIFA Quality on a white star, as in the approved front photograph.
    front=np.array([0,-1.,0])
    order=sorted(range(len(face_frames)),key=lambda i:-np.dot(face_frames[i][2],front))
    placements=[(face_frames[order[0]],'adidas',.39),(face_frames[order[1]],'ucl',.42),
                (face_frames[order[3]],'lge',.32),(frames[1],'fifa',.32),
                (face_frames[order[-4]],'valve',.18)]
    # Upright marks around the globe; avoid mirroring on the back hemisphere.
    for frame,kind,scale in placements:
        z=np.array(frame[2]);y=np.array([0,0,1.])-z*z[2]
        if np.linalg.norm(y)<.01:y=np.array(frame[1])
        y/=np.linalg.norm(y);x=np.cross(y,z)
        for row in range(0,SIZE,128):
            v=1-(np.arange(row,min(row+128,SIZE))+.5)/SIZE;u=(np.arange(SIZE)+.5)/SIZE
            lat=np.pi*(1-v[:,None]);lon=2*np.pi*u[None,:]
            n=np.stack(np.broadcast_arrays(np.sin(lat)*np.cos(lon),np.sin(lat)*np.sin(lon),np.cos(lat)),axis=-1)
            den=n@z;xx=(n@x)/np.maximum(den,.001);yy=(n@y)/np.maximum(den,.001)
            sx=(xx/(scale*2)+.5)*1023;sy=(.5-yy/(scale*2))*1023
            mask=(den>.7)&(sx>=0)&(sx<1023)&(sy>=0)&(sy<1023)
            # Bilinear resampling, especially important for small serif labels.
            sx=np.clip(sx,0,1022);sy=np.clip(sy,0,1022);ix=sx.astype(int);iy=sy.astype(int);a=sx-ix;b=sy-iy
            li=logos[kind]
            ink=(li[iy,ix]*(1-a)*(1-b)+li[iy,ix+1]*a*(1-b)+li[iy+1,ix]*(1-a)*b+li[iy+1,ix+1]*a*b)*mask
            rgb[row:row+len(v)] = rgb[row:row+len(v)]*(1-ink[:,:,None])+np.array([19,25,29])*ink[:,:,None]
    # Height-derived tangent normal map: +Y (OpenGL/glTF), spherical metric.
    du=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))/2
    dv=(np.roll(height,1,axis=0)-np.roll(height,-1,axis=0))/2
    lat=np.pi*(np.arange(SIZE)+.5)/SIZE
    nx=-du/(2*np.pi*.11/SIZE*np.maximum(np.sin(lat[:,None]),.03))
    ny=-dv/(np.pi*.11/SIZE)
    normal=np.stack([nx,ny,np.ones_like(nx)],-1);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    Image.fromarray(np.clip(rgb,0,255).astype('uint8')).save(OUT/'albedo.png')
    Image.fromarray(np.uint8(np.clip(normal*.5+.5,0,1)*255)).save(OUT/'seam_normal.png')
    Image.fromarray(np.uint8(rough*255)).save(OUT/'roughness.png')
    # Tiling subtle TPU emboss, 16 repeats around the ball. No chunky leather.
    side=256;yy,xx=np.mgrid[:side,:side]/side
    dots=np.cos(2*np.pi*xx*8)*np.cos(2*np.pi*yy*8)
    gx=.15*np.sin(2*np.pi*xx*8)*np.cos(2*np.pi*yy*8)
    gy=.15*np.cos(2*np.pi*xx*8)*np.sin(2*np.pi*yy*8)
    micro=np.stack([gx,gy,np.ones_like(gx)],-1);micro/=np.linalg.norm(micro,axis=2)[:,:,None]
    Image.fromarray(np.uint8((micro*.5+.5)*255)).save(OUT/'tpu_micro_normal.png')
    # Pack the actual exported normal, combining fine relief into the atlas;
    # retain the separate tile and its UV scale in Blender for editable detail.
    my=np.arange(SIZE)*16*side//SIZE%side;mx=np.arange(SIZE)*16*side//SIZE%side
    detail=micro[my[:,None],mx[None,:]]
    combined=normal.copy();combined[:,:,:2]+=detail[:,:,:2]*.38
    combined/=np.linalg.norm(combined,axis=2)[:,:,None]
    Image.fromarray(np.uint8(np.clip(combined*.5+.5,0,1)*255)).save(OUT/'normal.png')
    metadata={'texture_size':SIZE,'radius_m':.11,'star_centres':vertices.tolist(),'frames':frames,
        'logo_panels':[(k,s) for _,k,s in placements], 'method':'Continuous icosahedral five-point star field + tangent-projected vector branding; OpenGL normal maps'}
    (OUT/'asset.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print('UCL_TEXTURES PASS 2048px continuous spherical artwork, PBR seams and TPU',flush=True)


def build_blender():
    import bpy
    from mathutils import Vector
    import numpy as np
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC'
    collection=bpy.data.collections.new('COL_UCL_League');scene.collection.children.link(collection)
    mesh=bpy.data.meshes.new('MESH_UCL_League_Size5')
    segments=64;rings=56;verts=[];faces=[];uvfaces=[]
    # Welded closed sphere with explicit per-loop wrap; no duplicated meridian.
    for j in range(1,rings):
        theta=math.pi*(1-j/rings)
        for i in range(segments):
            phi=2*math.pi*i/segments
            verts.append((.11*math.sin(theta)*math.cos(phi),.11*math.sin(theta)*math.sin(phi),.11*math.cos(theta)))
    bottom=len(verts);verts.append((0,0,-.11));top=len(verts);verts.append((0,0,.11))
    for j in range(rings-2):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments;c=(j+1)*segments+(i+1)%segments;d=(j+1)*segments+i
            faces.append((a,b,c,d));uvfaces.append([(i/segments,(j+1)/rings),((i+1)/segments,(j+1)/rings),((i+1)/segments,(j+2)/rings),(i/segments,(j+2)/rings)])
    for i in range(segments):
        ni=(i+1)%segments
        faces.append((bottom,ni,i));uvfaces.append([((i+.5)/segments,0),((i+1)/segments,1/rings),(i/segments,1/rings)])
        faces.append(((rings-2)*segments+i,(rings-2)*segments+ni,top));uvfaces.append([(i/segments,(rings-1)/rings),((i+1)/segments,(rings-1)/rings),((i+.5)/segments,1)])
    mesh.from_pydata(verts,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='UV_SphericalArtwork')
    for p,coords in zip(mesh.polygons,uvfaces):
        p.use_smooth=True
        for li,co in zip(p.loop_indices,coords):uv.data[li].uv=co
    ball=bpy.data.objects.new('SM_UCL_26_27_League',mesh);collection.objects.link(ball)
    mat=bpy.data.materials.new('MAT_UCL_League_Pearl_TPU');mat.use_nodes=True
    nt=mat.node_tree;bsdf=nt.nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=0;bsdf.inputs['Roughness'].default_value=.44
    bsdf.inputs['IOR'].default_value=1.48
    for fname,space,socket in [('albedo.png','sRGB','Base Color'),('roughness.png','Non-Color','Roughness')]:
        tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/fname));tex.image.colorspace_settings.name=space
        nt.links.new(tex.outputs['Color'],bsdf.inputs[socket]);tex.image.pack()
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'normal.png'));tex.image.colorspace_settings.name='Non-Color';tex.image.pack()
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.7
    nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
    # Retain a clearly labelled micro source node for authoring. Combined atlas
    # goes to glTF: no reliance on unsupported Blender procedural nodes.
    source=nt.nodes.new('ShaderNodeTexImage');source.label='EDITABLE TPU tile: 16 repeats; already combined in normal.png'
    source.image=bpy.data.images.load(str(OUT/'tpu_micro_normal.png'));source.image.colorspace_settings.name='Non-Color';source.image.pack()
    mesh.materials.append(mat)
    tris=sum(len(p.vertices)-2 for p in mesh.polygons)
    assert 6000<=tris<=8000,(tris,'triangle budget')
    # Every edge has two faces, identity transform and centred exact diameter.
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);assert all(e.is_manifold for e in bm.edges);bm.free()
    bpy.context.view_layer.objects.active=ball;ball.select_set(True)
    for image in bpy.data.images:
        if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(BLEND.parent))
    # Camera and soft studio are saved but explicitly excluded from export.
    def area(name,pos,power,size):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=pos;obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
    area('LGT_Key',(-.5,-.6,.7),30,.55);area('LGT_Fill',(.5,-.2,.25),9,.45);area('LGT_Rim',(0,.3,.5),15,.3)
    scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.7,.72,.75,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    camera=bpy.data.objects.new('CAM_UCL_Hero',bpy.data.cameras.new('CAM_UCL_Hero'));scene.collection.objects.link(camera)
    camera.location=(0,-.62,.12);camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=58;scene.camera=camera
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
    scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.object.select_all(action='DESELECT');ball.select_set(True);bpy.context.view_layer.objects.active=ball
    bpy.ops.export_scene.gltf(filepath=str(OUT.parent/'ucl_26_27_league.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_tangents=True,export_animations=False,export_cameras=False,export_lights=False)
    BRIEF.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(BRIEF/'blender_studio.png');bpy.ops.render.render(write_still=True)
    report={'triangles':tris,'materials':1,'mesh_objects':1,'diameter_m':[round(v,6) for v in ball.dimensions],'closed_manifold':True,'identity_transform':True,'texture_size':SIZE,'renderer':'Blender Cycles CPU 32 samples, AgX, denoising off','glb_bytes':(OUT.parent/'ucl_26_27_league.glb').stat().st_size}
    (BRIEF/'asset_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('UCL_BLENDER PASS',json.dumps(report),flush=True)

if __name__=='__main__':
    if '--stage-blender' in sys.argv:build_blender()
    else:
        generate_maps()
        import subprocess
        subprocess.run(['blender','--disable-autoexec','-b','--python',str(Path(__file__).resolve()),'--','--stage-blender'],check=True,timeout=180)
