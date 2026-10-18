"""Shared team/role pigment atlases; identity printing is separate at runtime.

Uses archived kit artwork and palette values. Keeper pattern reconstruction
is a first layout pass, not a claim of exact garment/graphic approval.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from build_shane_tailored_textures import RECTS,BLUE,BLACK

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/characters/textures/shared'
SOURCE=OUT.parent
SHEETS=ROOT/'games/beechlawn_rovers/references/source_uploads/drive_folder'

def artwork(name):return Image.open(SOURCE/name).convert('RGBA')
def paste(atlas,art,box):
    art=art.resize((box[2],box[3]),Image.Resampling.LANCZOS)
    atlas.alpha_composite(art,box[:2])

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    crest=artwork('beechlawn_crest_from_kit_reference.png')
    brand=artwork('uhlsport_wordmark_from_kit_reference.png')
    sponsor=artwork('thomas_loomes_sponsor_from_kit_reference.png')
    sheet=Image.open(SHEETS/'file_000000008a9881f49c8ce1ebe2521b75.png').convert('RGBA')
    bcrest=sheet.crop((1389,863,1481,1000))
    mask=Image.new('L',bcrest.size);ImageDraw.Draw(mask).polygon([(0,0),(91,0),(90,66),(82,104),(46,136),(10,104),(1,66)],fill=255)
    bcrest.putalpha(mask)
    fonts=Path('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf')
    for key in ('beechlawn_outfield','beechlawn_keeper','bordeaux_outfield','bordeaux_keeper','referee','spectator'):
        atlas=Image.new('RGBA',(2048,2048),BLACK+(255,))
        home=key.startswith('beechlawn');keeper=key.endswith('keeper')
        for panel in ('front','back'):
            x0,y0,x1,y1=RECTS[panel];w=x1-x0;h=y1-y0
            base=BLUE if home else (126,199,240)
            if keeper:base=(199,206,218) if home else (26,26,26)
            if key in ('referee','spectator'):base=(17,18,20) if key=='referee' else (83,66,48)
            im=Image.new('RGBA',(w,h),base+(255,));d=ImageDraw.Draw(im)
            if home and not keeper:
                for i in range(6):
                    if i%2==0:d.rectangle((i*w//6,0,(i+1)*w//6,h),fill=BLACK)
                for points in [[(0,0),(w*.36,0),(0,h*.34)],[(w,0),(w*.64,0),(w,h*.34)]]:d.polygon(points,fill=BLACK)
            elif keeper:
                if home:
                    for side in (-1,1):
                        points=[(w*.5+side*w*x,h*y) for x,y in ((0,.78),(.32,.48),(.25,.55),(.43,.28),(.29,.36),(.25,.1),(.13,.25),(0,.47))]
                        d.polygon(points,fill=(47,95,168))
                    d.polygon([(0,h*.78),(w,h*.60),(w,h*.63),(0,h*.81)],fill=(225,185,73))
                else:
                    for y in range(-80,h,110):
                        for x in range(0,w,150):d.polygon([(x,y),(x+130,y+30),(x+55,y+95),(x+80,y+40)],fill=(58,58,60))
            if panel=='front' and key not in ('referee','spectator'):
                badge=crest if home else bcrest
                paste(im,badge,(665,180,145,174))
                wordmark=brand.copy()
                if key=='bordeaux_outfield':
                    wordmark.putdata([(0,0,0,a) for r,g,b,a in wordmark.getdata()])
                paste(im,wordmark,(350,215,185,57))
                if home:paste(im,sponsor,(130,430,700,242))
                else:
                    d.text((w/2,470),'Boards.ie',font=ImageFont.truetype(str(fonts),110),anchor='mt',fill=(245,245,245) if keeper else (5,8,10))
            atlas.alpha_composite(im,(x0,y0))
        d=ImageDraw.Draw(atlas)
        for region in ('sleeve_l','sleeve_r'):
            color=(30,92,198) if home else (126,199,240)
            if keeper:color=(47,95,168) if home else (40,40,43)
            if key in ('referee','spectator'):color=(16,17,18) if key=='referee' else (83,66,48)
            d.rectangle(RECTS[region],fill=color)
        for region in ('shorts_front','shorts_back','black','boots'):d.rectangle(RECTS[region],fill=BLACK)
        d.rectangle(RECTS['blue'],fill=BLUE if home else (5,8,10))
        sock=(30,92,198) if key=='beechlawn_outfield' else (231,234,233) if key in ('beechlawn_keeper','bordeaux_outfield') else (16,17,18)
        d.rectangle(RECTS['socks'],fill=sock)
        atlas.convert('RGB').save(OUT/f'{key}.png')
    print('Shared kit atlases generated: six team/role materials, no player identity baked in.')

if __name__=='__main__':build()
