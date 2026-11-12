#!/usr/bin/env python3
"""Parity sheet: the reference video's frames over ours, beat for beat.

The owner (12 Nov): "score each of ours out of 10 in terms of parity with the
reference -- speed, cadence, smooth motion, like for like movements". This is
the evidence the reviewer scores from: one row of the AEW Fight Forever
tutorial at chosen timestamps, one row of our render at the matching 60 fps
frames, each labelled with its frame offset from contact so the two rows can
be read against each other directly.

    python3 game/tools/anim/parity_sheet.py \
        --video REF.mp4 --ref 63.633,63.75,63.95,64.05,64.30,64.70 \
        --contact-ref 63.95 \
        --ours DIR --ours-frames 0,13,32,38,52,70 --contact-ours 32 \
        --title "Front kick (body)" --out sheet.png

The reference is read with ffmpeg only (no code is run from its folder).
"""
import argparse
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

CELL = (480, 270)
LABEL_H = 26


def _font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _ref_frame(video, t, out):
    subprocess.run(["ffmpeg", "-v", "error", "-ss", "%.3f" % t, "-i", video,
                    "-frames:v", "1", "-y", out], check=True)
    return Image.open(out).convert("RGB")


def _fit(im):
    # Cover-crop to the cell, centred: both men stay in the middle of frame.
    w, h = im.size
    scale = max(CELL[0] / w, CELL[1] / h)
    im = im.resize((int(w * scale + 0.5), int(h * scale + 0.5)))
    x = (im.size[0] - CELL[0]) // 2
    y = (im.size[1] - CELL[1]) // 2
    return im.crop((x, y, x + CELL[0], y + CELL[1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--ref", required=True, help="comma list of seconds")
    ap.add_argument("--contact-ref", type=float, required=True)
    ap.add_argument("--ours", required=True, help="dir of fNNN.png")
    ap.add_argument("--ours-frames", required=True, help="comma list of 60 fps frames")
    ap.add_argument("--contact-ours", type=int, required=True)
    ap.add_argument("--title", default="")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    ref_t = [float(x) for x in a.ref.split(",")]
    ours_f = [int(x) for x in a.ours_frames.split(",")]
    cols = max(len(ref_t), len(ours_f))
    title_h = 34 if a.title else 0
    sheet = Image.new("RGB", (cols * CELL[0], title_h + 2 * (CELL[1] + LABEL_H)), (18, 20, 26))
    draw = ImageDraw.Draw(sheet)
    big, small = _font(22), _font(16)
    if a.title:
        draw.text((10, 6), a.title, fill=(240, 240, 240), font=big)

    with tempfile.TemporaryDirectory() as tmp:
        for i, t in enumerate(ref_t):
            im = _fit(_ref_frame(a.video, t, os.path.join(tmp, "r%d.png" % i)))
            x, y = i * CELL[0], title_h
            sheet.paste(im, (x, y + LABEL_H))
            off = round((t - a.contact_ref) * 60)
            draw.text((x + 8, y + 4), "REF %.2fs  contact%+d f" % (t, off),
                      fill=(255, 210, 80), font=small)
    for i, f in enumerate(ours_f):
        path = os.path.join(a.ours, "f%03d.png" % f)
        x, y = i * CELL[0], title_h + CELL[1] + LABEL_H
        if os.path.exists(path):
            sheet.paste(_fit(Image.open(path).convert("RGB")), (x, y + LABEL_H))
        draw.text((x + 8, y + 4), "OURS f%d  contact%+d f" % (f, f - a.contact_ours),
                  fill=(120, 200, 255), font=small)
    sheet.save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
