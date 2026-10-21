"""Generate original linear PBR data for the existing shared kit UV atlas.

Does not modify supplied references or pigment. Normal vectors come from a
small analytic knit height field, not photographic lighting or random pixels.
Run with system Python (numpy/Pillow); Blender is not required at game startup.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
TEXTURES = ROOT / 'games/beechlawn_rovers/assets/characters/textures'
OUT = TEXTURES / 'shared'
KITS = ('beechlawn_outfield', 'beechlawn_keeper', 'bordeaux_outfield',
        'bordeaux_keeper', 'referee', 'spectator')
SIZE = 2048
RECTS = json.loads((TEXTURES/'beechlawn_home_tailored_atlas_layout.json').read_text())['rects']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    protected = {kit: digest(OUT/f'{kit}.png') for kit in KITS}
    yy, xx = np.mgrid[:SIZE, :SIZE].astype(np.float32)
    normal = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    normal[:, :, 2] = 1
    variation = np.zeros((SIZE, SIZE), dtype=np.float32)
    rough = np.full((SIZE, SIZE), .81, dtype=np.float32)
    # The shirt is about 0.5 m wide: 300 stitch columns is approximately
    # 1.7 mm spacing. UV charts differ, so socks/shorts get their own density.
    for region, rect in RECTS.items():
        x0, y0, x1, y1 = rect
        if region == 'boots':
            rough[y0:y1, x0:x1] = .59
            continue
        columns, rows = (300, 360)
        base, strength = .79, .105
        if region.startswith('sleeve'):
            columns, rows = 320, 150
        elif region.startswith('shorts'):
            columns, rows, base, strength = 190, 220, .84, .075
        elif region == 'socks':
            columns, rows, base, strength = 100, 240, .89, .09
        elif region in ('black', 'blue'):
            columns, rows, base, strength = 32, 32, .83, .065
        u = (xx[y0:y1, x0:x1]-x0)/(x1-x0)
        v = (yy[y0:y1, x0:x1]-y0)/(y1-y0)
        a, b = u*columns*2*np.pi, v*rows*2*np.pi
        # Derivatives of a periodic loop height field. Negate image-down Y
        # derivative when converting into glTF/OpenGL's UV-up tangent space.
        dx = np.cos(a + .35*np.sin(b))
        dy = .35*np.cos(b)*dx + .65*np.cos(b+.35*np.sin(a))
        n = np.stack((-strength*dx, strength*dy, np.ones_like(dx)), axis=-1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        normal[y0:y1, x0:x1] = n
        weave = np.sin(a+.35*np.sin(b)) * np.sin(b)
        if region == 'socks':
            weave = .6*weave + .4*np.cos(u*60*2*np.pi)
        variation[y0:y1, x0:x1] = weave
        rough[y0:y1, x0:x1] = base + .016*weave
    # Extend chart edge pixels into the unused gutter for safe lower mips.
    for rect in RECTS.values():
        x0, y0, x1, y1 = rect
        for array in (normal, rough):
            array[y0-4:y1+4, x0-4:x1+4] = np.pad(
                array[y0:y1, x0:x1], ((4,4), (4,4)) + (((0,0),) if array.ndim == 3 else ()),
                mode='edge')
    data = np.round(np.clip(normal*.5+.5, 0, 1)*255).astype(np.uint8)
    Image.fromarray(data).save(OUT/'fabric_knit_normal.png', optimize=True)
    report = {'source': 'original analytic knit, existing UV charts and unchanged pigment',
              'normal_size': [SIZE, SIZE], 'normal_scale': .35,
              'roughness_size': [1024, 1024], 'roughness_channel': 'red',
              'shirt_stitch_spacing_estimate_mm': 1.7, 'roles': {}}
    for kit in KITS:
        r = rough.copy()
        pigment = np.asarray(Image.open(OUT/f'{kit}.png').convert('RGB'), dtype=np.float32)/255
        if kit not in ('referee', 'spectator'):
            # Restrict ink detection to authored front artwork. Never classify
            # a white sock or pale keeper panel as sponsor print.
            for box in ((382,247,567,304), (162,462,862,704)):
                x0,y0,x1,y1 = box
                rgb = pigment[y0:y1, x0:x1]
                white = np.clip((rgb.min(axis=-1)-.88)/.08, 0, 1)
                ink = white
                if kit == 'bordeaux_outfield':
                    ink = np.clip((.18-rgb.max(axis=-1))/.10, 0, 1)
                patch = r[y0:y1, x0:x1]
                r[y0:y1, x0:x1] = patch*(1-ink) + (.60+.006*variation[y0:y1,x0:x1])*ink
            # Existing badge is oval; retain cloth at the rectangle's corners.
            badge = ((xx-769.5)/72.5)**2 + ((yy-299)/87)**2 <= 1
            r[badge] = .70+.008*variation[badge]
        image = Image.fromarray(np.round(np.clip(r,0,1)*255).astype(np.uint8))
        image = image.resize((1024,1024), Image.Resampling.BOX)
        path = OUT/f'{kit}_roughness.png'
        image.save(path, optimize=True)
        values = np.asarray(image, dtype=np.float32)/255
        report['roles'][kit] = {'min': float(values.min()), 'max': float(values.max()),
                                'sha256': digest(path)}
        assert protected[kit] == digest(OUT/f'{kit}.png'), 'Pigment must remain unchanged'
    report['normal_sha256'] = digest(OUT/'fabric_knit_normal.png')
    report['pigment_sha256'] = protected
    (OUT/'fabric_maps.json').write_text(json.dumps(report, indent=2)+'\n')
    print('SHARED_FABRIC_MAPS', json.dumps(report))


if __name__ == '__main__':
    build()
