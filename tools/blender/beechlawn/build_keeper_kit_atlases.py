"""Pack reference-led pattern art and exact supplied decals into shared UVs.

Technical atlas assembly only. Pattern artwork is generated from the archived
keeper boards; original references remain unchanged. Does not rebuild players.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT/'games/beechlawn_rovers'
OUT = PROJECT/'assets/characters/textures/shared'
ART = Path(__file__).parent/'keeper_patterns'
REF = PROJECT/'references/source_uploads'
RECTS = json.loads((OUT.parent/'beechlawn_home_tailored_atlas_layout.json').read_text())['rects']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ink(image, color=(245,245,243), threshold=100):
    """Extract the supplied wordmark glyph mask, preserving its letterforms."""
    rgb = np.asarray(image.convert('RGB'),dtype=np.float32)
    alpha = np.clip((rgb.mean(axis=-1)-threshold)/(255-threshold),0,1)
    art = Image.new('RGBA', image.size, color+(255,))
    art.putalpha(Image.fromarray(np.round(alpha*255).astype(np.uint8)))
    return art.crop(art.getbbox())


def oval_crest():
    image = Image.open(REF/'chat_attachments/club_crest/69032.jpg').convert('RGBA').crop((297,135,986,1110))
    alpha=Image.new('L',image.size);ImageDraw.Draw(alpha).ellipse((0,0,image.width-1,image.height-1),fill=255)
    image.putalpha(alpha)
    return image


def shield_crest(sheet):
    image=sheet.crop((1386,862,1480,1000)).convert('RGBA')
    alpha=Image.new('L',image.size)
    ImageDraw.Draw(alpha).polygon([(0,0),(93,0),(93,67),(85,103),(47,137),(9,103),(0,67)],fill=255)
    image.putalpha(alpha)
    return image


def stamp(atlas, image, box):
    x,y,w,h=box
    atlas.alpha_composite(image.resize((w,h),Image.Resampling.LANCZOS),(x,y))


def build():
    unaffected={kit:sha(OUT/f'{kit}.png') for kit in ('beechlawn_outfield','bordeaux_outfield','referee','spectator')}
    away_ref=Image.open(REF/'drive_folder/file_00000000654c81f488f863c6c1a412ab.png').convert('RGB')
    wordmark=ink(away_ref.crop((1313,567,1401,594)))
    sponsor=Image.open(OUT.parent/'thomas_loomes_sponsor_from_kit_reference.png').convert('RGBA')
    sponsor=sponsor.crop(sponsor.getbbox())
    boards=ink(away_ref.crop((1120,705,1518,779)))
    layout={}
    for kit,source,split in (('beechlawn_keeper','beechlawn_panels.png',761),('bordeaux_keeper','bordeaux_panels.png',627)):
        home=kit=='beechlawn_keeper'
        sheet=Image.open(ART/source).convert('RGBA')
        atlas=Image.new('RGBA',(2048,2048),(11,11,11,255))
        # Generator quadrants are not assumed equal: the home artwork's
        # horizontal divider is at y=761, confirmed by visual inspection.
        crops={'front':(2,2,625,split-2),'back':(629,2,1252,split-2),
               'sleeve_l':(2,split+2,625,1252),'sleeve_r':(629,split+2,1252,1252)}
        for region,box in crops.items():
            x0,y0,x1,y1=RECTS[region]
            stamp(atlas,sheet.crop(box),(x0,y0,x1-x0,y1-y0))
        draw=ImageDraw.Draw(atlas)
        # Matte inner-side panels, black collar/cuff/raglan swatches. The sock
        # binding uses its own sock chart after the shared UV repair.
        for name in ('front','back'):
            x0,y0,x1,y1=RECTS[name]
            draw.rectangle((x0,y0+250,x0+24,y1),fill=(11,11,11))
            draw.rectangle((x1-24,y0+250,x1,y1),fill=(11,11,11))
        for name in ('shorts_front','shorts_back','black','blue','boots'):
            draw.rectangle(RECTS[name],fill=(11,11,11))
        x0,y0,x1,y1=RECTS['socks']
        sock=(234,235,232) if home else (14,15,17)
        draw.rectangle((x0,y0,x1,y1),fill=sock)
        # Subdued top elastic bands, no baked lighting or muscle shading.
        band=(222,224,222) if home else (116,118,121)
        for y in (y0+16,y0+27):draw.line((x0,y,x1,y),fill=band,width=3)
        crest=oval_crest() if home else shield_crest(away_ref)
        crest_box=(718,182,122,173) if home else (718,182,122,174)
        mark_box=(390,195,218,54) if home else (175,225,205,51)
        word=wordmark.copy()
        if home:
            word.paste((12,13,16),(0,0,word.width,word.height),word.getchannel('A'))
            # Preserve the source glyph alpha after recolouring to black.
            word.putalpha(wordmark.getchannel('A'))
        stamp(atlas,crest,crest_box)
        stamp(atlas,word,mark_box)
        sponsor_box=(162,462,700,242) if home else (182,453,660,123)
        stamp(atlas,sponsor if home else boards,sponsor_box)
        stamp(atlas,crest,(74,1857,57,81))
        stamp(atlas,wordmark,(311,1938,100,25))
        sock_mark=wordmark.copy()
        if home:
            solid=Image.new('RGBA',sock_mark.size,(16,17,20,255));solid.putalpha(sock_mark.getchannel('A'));sock_mark=solid
        stamp(atlas,sock_mark,(1017,1700,86,22))
        if home:
            for name in ('shorts_front','shorts_back'):
                a,b,c,d=RECTS[name]
                draw.line((a+8,b+30,a+8,d-8),fill=(213,218,226),width=9)
                draw.line((c-8,b+30,c-8,d-8),fill=(213,218,226),width=9)
        # Extend edge pixels into atlas gutters for the existing mip filtering.
        for x0,y0,x1,y1 in RECTS.values():
            panel=atlas.crop((x0,y0,x1,y1))
            atlas.paste(panel.crop((0,0,1,panel.height)).resize((4,panel.height)),(x0-4,y0))
            atlas.paste(panel.crop((panel.width-1,0,panel.width,panel.height)).resize((4,panel.height)),(x1,y0))
            atlas.paste(panel.crop((0,0,panel.width,1)).resize((panel.width,4)),(x0,y0-4))
            atlas.paste(panel.crop((0,panel.height-1,panel.width,panel.height)).resize((panel.width,4)),(x0,y1))
        atlas.convert('RGB').save(OUT/f'{kit}.png',optimize=True)
        layout[kit]={'source_art':source,'source_sha256':sha(ART/source),'crops':crops,
                     'manufacturer':{'box':list(mark_box),'ink':'dark' if home else 'light'},
                     'sponsor':{'box':list(sponsor_box),'ink':'light'},
                     'crest':{'box':list(crest_box),'shape':'oval' if home else 'shield'},
                     'atlas_sha256':sha(OUT/f'{kit}.png')}
    assert all(sha(OUT/f'{kit}.png')==expected for kit,expected in unaffected.items())
    (OUT/'keeper_atlas_layout.json').write_text(json.dumps(layout,indent=2)+'\n')
    print('KEEPER_ATLASES',json.dumps(layout))


if __name__=='__main__':
    build()
