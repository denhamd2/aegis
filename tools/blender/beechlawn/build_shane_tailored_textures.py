"""2K team-kit atlas: dedicated front/back/sleeve/short/sock/trim islands."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import json
import numpy as np
from build_shane_kit_texture import cut_brand_art, SHEET, back_prints, OUT

SIZE=2048
RECTS={"front":(32,32,992,1216),"back":(1056,32,2016,1216),
       "sleeve_l":(32,1280,992,1552),"sleeve_r":(1056,1280,2016,1552),
       "shorts_front":(32,1600,448,2016),"shorts_back":(480,1600,896,2016),
       "socks":(960,1600,1160,2016),"black":(1200,1600,1320,1700),
       "blue":(1360,1600,1480,1700),"boots":(1550,1600,1720,1800)}
BLUE=(30,92,198); BLACK=(11,11,11)


def main():
    crest_path,brand_path,sponsor_path=cut_brand_art(Image.open(SHEET).convert("RGB"))
    atlas=Image.new("RGBA",(SIZE,SIZE),BLACK+(255,))
    for panel in ("front","back"):
        x0,y0,x1,y1=RECTS[panel]; w=x1-x0; h=y1-y0
        im=Image.new("RGBA",(w,h),BLACK+(255,)); d=ImageDraw.Draw(im)
        for i in range(6):
            if i%2==1: d.rectangle((i*w//6,0,(i+1)*w//6,h),fill=BLUE)
        # Black raglan yoke at the shoulder; blue piping follows its outer edge.
        d.polygon([(0,0),(w*.36,0),(0,h*.34)],fill=BLACK)
        d.polygon([(w,0),(w*.64,0),(w,h*.34)],fill=BLACK)
        d.line([(0,h*.30),(w*.31,0)],fill=BLUE,width=15)
        d.line([(w,h*.30),(w*.69,0)],fill=BLUE,width=15)
        if panel=="front":
            crest=Image.open(crest_path).convert("RGBA").resize((145,174),Image.Resampling.LANCZOS)
            im.alpha_composite(crest,(665,180))
            brand=Image.open(brand_path).convert("RGBA"); brand=brand.crop(brand.getbbox()).resize((185,57),Image.Resampling.LANCZOS)
            im.alpha_composite(brand,((w-brand.width)//2,217))
            sponsor=Image.open(sponsor_path).convert("RGBA"); sponsor=sponsor.crop(sponsor.getbbox()).resize((700,242),Image.Resampling.LANCZOS)
            im.alpha_composite(sponsor,((w-sponsor.width)//2,430))
        else:
            name,number=back_prints()
            name=name.resize((620,98),Image.Resampling.LANCZOS)
            number=number.resize((310,505),Image.Resampling.LANCZOS)
            im.alpha_composite(name,((w-name.width)//2,170))
            im.alpha_composite(number,((w-number.width)//2,330))
        # Double needle hem seam, not a large shaded fold baked into colour.
        d.line((0,h-18,w,h-18),fill=(14,32,52),width=2)
        d.line((0,h-25,w,h-25),fill=(14,32,52),width=2)
        atlas.alpha_composite(im,(x0,y0))
    d=ImageDraw.Draw(atlas)
    for key in ("sleeve_l","sleeve_r"):
        x0,y0,x1,y1=RECTS[key]; h=y1-y0
        d.rectangle((x0,y0,x1,y1),fill=BLACK)
        d.rectangle((x0,y0,x1,y0+int(h*.14)),fill=BLUE)
        d.rectangle((x0,y1-int(h*.14),x1,y1),fill=BLUE)
    for key in ("shorts_front","shorts_back"):
        x0,y0,x1,y1=RECTS[key]
        d.rectangle((x0,y0,x1,y1),fill=(14,15,18))
        for y in range(y0+3,y0+27,5): d.line((x0,y,x1,y),fill=(20,21,24),width=2)
        d.line((x0,y1-9,x1,y1-9),fill=(24,25,28),width=2)
        if key=="shorts_front":
            crest=Image.open(crest_path).convert("RGBA").resize((64,78),Image.Resampling.LANCZOS)
            atlas.alpha_composite(crest,(x0+45,y1-126))
            brand=Image.open(brand_path).convert("RGBA"); brand=brand.crop(brand.getbbox()).resize((90,28),Image.Resampling.LANCZOS)
            atlas.alpha_composite(brand,(x1-130,y1-77))
    d.rectangle(RECTS["socks"],fill=BLUE); d.rectangle(RECTS["blue"],fill=BLUE)
    d.rectangle(RECTS["black"],fill=BLACK); d.rectangle(RECTS["boots"],fill=(13,14,16))
    x0,y0,x1,y1=RECTS["socks"]
    for x in range(x0,x1,4): d.line((x,y0,x,y1),fill=(28,86,184))
    for y in (y0+14,y0+22): d.line((x0,y,x1,y),fill=(24,77,163),width=2)
    # Micro-knit in pigment is deliberately below 1%; no painted lighting.
    data=np.asarray(atlas.convert("RGB")).astype(np.float32)
    yy,xx=np.mgrid[0:SIZE,0:SIZE]
    knit=(np.sin(xx*np.pi)+np.cos(yy*np.pi))*0.003
    data=np.clip(data*(1+knit[...,None]),0,255).astype(np.uint8)
    path=OUT.with_name("beechlawn_home_tailored_2k_albedo.png")
    Image.fromarray(data).save(path)
    OUT.with_name("beechlawn_home_tailored_atlas_layout.json").write_text(json.dumps({"size":SIZE,"rects":RECTS},indent=2)+"\n")
    # Tangent-space knitted relief and perceptually restrained roughness.
    normal=np.zeros((SIZE,SIZE,3),np.float32); normal[:,:,2]=1
    normal[:,:,0]=.5+.018*np.sin(xx*1.65+np.sin(yy*2.0))
    normal[:,:,1]=.5+.018*np.cos(yy*1.7+np.sin(xx*2.0))
    Image.fromarray((normal*255).astype(np.uint8)).resize((512,512)).save(OUT.with_name("beechlawn_home_knit_normal.png"))
    rough=np.full((SIZE,SIZE),205,dtype=np.uint8)
    Image.fromarray(rough).resize((512,512)).save(OUT.with_name("beechlawn_home_cloth_roughness.png"))
    print("TAILORED_KIT_ATLAS",path)


if __name__=="__main__": main()
