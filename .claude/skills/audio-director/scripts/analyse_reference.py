"""Turn a reference video's soundtrack into a timed, classified cue sheet.

    BLPY=/Applications/Blender.app/Contents/Resources/5.3/python/bin/python3.13
    $BLPY -I analyse_reference.py <video> <out_dir> [--start S] [--end S] [--frames N]

Only numpy and ffmpeg are needed (Blender's bundled Python has numpy; the
Mac's system python does not). Writes into <out_dir>:

  cues.json      every onset: time, class guess, confidence, features
  crowd.json     the crowd bed, 2 Hz: level (dBFS) and its rises (pops)
  cues.csv       the same cues, one row each, for a spreadsheet
  frames/        a 320 px frame at each kept cue (what was on screen)
  clips/         0.25 s before to 1.5 s after each kept cue, 44.1 kHz WAV
  audition.html  one row per cue: frame, player, class, features

The classes are a first pass from measured features, not a verdict:
impact (strike), body (fall/bump), bell, voice (wrestler/referee/commentary),
metal/wood (weapon-like), whoosh, other. The Audio Director confirms each
one by the frame and by the spectrum before it reaches the target sheet.

Everything this writes is REFERENCE ONLY. Do not copy a clip into the game:
the reference is someone else's mix. See ../SKILL.md, "Provenance".
"""
import argparse
import csv
import html
import json
import os
import subprocess
import sys

import numpy as np

SR = 22050
N_FFT = 1024
HOP = 256  # 11.6 ms
BANDS = {  # Hz
    "sub": (20, 120), "low": (120, 400), "lowmid": (400, 1500),
    "pres": (1500, 4000), "air": (4000, 11000),
}


def load(video, start, end):
    cmd = ["ffmpeg", "-v", "error"]
    if start:
        cmd += ["-ss", str(start)]
    if end:
        cmd += ["-to", str(end)]
    cmd += ["-i", video, "-vn", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, check=True, capture_output=True).stdout, np.float32)


def stft_mag(x):
    win = np.hanning(N_FFT).astype(np.float32)
    n = 1 + (len(x) - N_FFT) // HOP
    out = np.empty((n, N_FFT // 2 + 1), np.float32)
    step = 4096
    for i in range(0, n, step):
        j = min(n, i + step)
        idx = (np.arange(i, j) * HOP)[:, None] + np.arange(N_FFT)[None, :]
        out[i:j] = np.abs(np.fft.rfft(x[idx] * win, axis=1))
    return out


def db(v):
    return 20 * np.log10(np.maximum(v, 1e-9))


def rolling_median(v, width):
    """Median over a centred window, computed on a coarse grid then repeated."""
    step = max(1, width // 8)
    grid = np.arange(0, len(v), step)
    med = np.array([np.median(v[max(0, g - width // 2):g + width // 2 + 1]) for g in grid])
    return np.interp(np.arange(len(v)), grid, med)


def onsets(mag, min_gap_s=0.08, k=4.0):
    logm = np.log1p(mag * 50)
    flux = np.maximum(logm[1:] - logm[:-1], 0).sum(axis=1)
    flux = np.concatenate([[0], flux])
    base = rolling_median(flux, int(0.6 * SR / HOP))
    mad = rolling_median(np.abs(flux - base), int(0.6 * SR / HOP))
    thr = base + k * np.maximum(mad, 1e-3)
    peaks = np.where((flux > thr) & (flux >= np.roll(flux, 1)) & (flux >= np.roll(flux, -1)))[0]
    keep, last = [], -10 ** 9
    gap = int(min_gap_s * SR / HOP)
    for p in peaks:
        if p - last >= gap:
            keep.append(p)
            last = p
        elif flux[p] > flux[keep[-1]]:
            keep[-1] = p
            last = p
    return np.array(keep, int), flux, thr


def pitch_strength(seg):
    """Best normalised autocorrelation for F0 80-400 Hz, and that F0."""
    if len(seg) < 1024:
        return 0.0, 0.0
    seg = seg - seg.mean()
    ac = np.fft.irfft(np.abs(np.fft.rfft(seg, 2 * len(seg))) ** 2)[:len(seg)]
    if ac[0] <= 0:
        return 0.0, 0.0
    lo, hi = SR // 400, SR // 80
    lag = lo + int(np.argmax(ac[lo:hi]))
    return float(ac[lag] / ac[0]), SR / lag


def features(x, mag, freqs, bed_db, frame):
    """Measured on the residual: each frame minus the spectrum of the 0.45 s
    before the onset. A wrestling mix sits on a loud crowd bed; without this
    every event inherits the bed's sustain and the bed's colour."""
    t0 = frame * HOP
    pre = mag[max(0, frame - 40):max(1, frame - 4)].mean(axis=0)
    res = np.maximum(mag[frame:frame + int(2.0 * SR / HOP)] - pre, 0)
    head = res[:int(0.25 * SR / HOP)].mean(axis=0) + 1e-9
    band = {k: float(db(head[(freqs >= a) & (freqs < b)].mean())) for k, (a, b) in BANDS.items()}
    level = db(res.sum(axis=1) + 1e-9)
    peak = float(level[:6].max())
    # Decay ends 20 dB down or once the event is back within 6 dB of what
    # followed it (the crowd's swell after a hit is the crowd, not the hit).
    tail_floor = float(np.median(level[int(1.0 * SR / HOP):])) if len(level) > int(1.2 * SR / HOP) else -1e9
    below = np.where(level[3:] < max(peak - 20, tail_floor + 6))[0]
    decay = float((below[0] + 3) * HOP / SR) if len(below) else 2.0
    centroid = float((freqs * head).sum() / head.sum())
    flatness = float(np.exp(np.log(head).mean()) / head.mean())
    # A bell (or ringing metal) still holds a few narrow peaks 0.5 s on.
    late = res[int(0.5 * SR / HOP):int(0.65 * SR / HOP)]
    peaky = hold = 0.0
    if len(late):
        lr = late.mean(axis=0)
        if lr.sum() > 0:
            peaky = float(np.sort(lr)[-12:].sum() / lr.sum())
            hold = float(lr.sum() / head.sum())
    # A ring is a few *narrow lines* that persist: in each late frame a bin
    # stands far over its +-8-bin neighbourhood, and the same bin does so in
    # most frames. Broadband crowd residue never does either.
    lines = 0.0
    late2 = mag[frame + int(0.3 * SR / HOP):frame + int(0.8 * SR / HOP)]
    if len(late2) > 4:
        sel = (freqs > 500) & (freqs < 6000)
        lm = late2[:, sel] + 1e-9
        k = 17
        pad = np.pad(lm, ((0, 0), (k // 2, k // 2)), mode="edge")
        win = np.lib.stride_tricks.sliding_window_view(pad, k, axis=1)
        prom = lm / np.median(win, axis=-1)
        steady = np.median(prom, axis=0)  # a line must hold through the window
        lines = float(db(np.sort(steady)[-3:].mean()))
    ps, f0 = pitch_strength(x[t0 + int(0.03 * SR):t0 + int(0.23 * SR)])
    return {"above_bed_db": round(peak - float(db(pre.sum() + 1e-9)), 1), "decay_s": round(decay, 3),
            "centroid_hz": round(centroid), "flatness": round(flatness, 3),
            "tonal_peaky": round(peaky, 3), "tonal_hold": round(hold, 3), "line_db": round(lines, 1),
            "pitch_strength": round(ps, 2), "f0_hz": round(f0),
            "bands_db": {k: round(v, 1) for k, v in band.items()}}


def classify(f):
    b = f["bands_db"]
    bottom = max(b["sub"], b["low"])
    top = max(b["pres"], b["air"])
    # Lines 12 dB over their neighbours for half a second: bell or ringing
    # metal. A ring bell's lines start near 900 Hz; struck steel is brighter
    # and dies faster.
    if f["line_db"] >= 12 and f["above_bed_db"] >= 6:
        if f["decay_s"] >= 0.4:
            return "bell", min(1.0, f["line_db"] / 24)
        return "metal", min(1.0, f["line_db"] / 24)
    if f["pitch_strength"] > 0.55 and 85 <= f["f0_hz"] <= 380 and f["decay_s"] > 0.15:
        return "voice", f["pitch_strength"]
    if bottom - top > 6 and f["decay_s"] >= 0.12:
        return "body", min(1.0, (bottom - top) / 18)
    if f["decay_s"] < 0.15 and f["flatness"] > 0.15:
        return "impact", min(1.0, f["above_bed_db"] / 15)
    if f["flatness"] > 0.3 and f["decay_s"] > 0.3 and f["above_bed_db"] < 6:
        return "whoosh", 0.3
    if f["centroid_hz"] < 1200 and f["decay_s"] < 0.35:
        return "wood", 0.3
    return "other", 0.2


def crowd_curve(mag, freqs):
    """Crowd bed: 300 Hz-3 kHz energy, slow (1.5 s median), 2 Hz."""
    sel = (freqs >= 300) & (freqs < 3000)
    lvl = db(mag[:, sel].mean(axis=1))
    bed = rolling_median(lvl, int(1.5 * SR / HOP))
    step = int(0.5 * SR / HOP)
    pts = [round(float(v), 1) for v in bed[::step]]
    rises = []
    for i in range(4, len(pts)):
        jump = pts[i] - min(pts[i - 4:i])
        if jump >= 6 and (not rises or i * 0.5 - rises[-1]["t"] > 3):
            rises.append({"t": i * 0.5, "rise_db": round(jump, 1), "to_db": pts[i]})
    return {"rate_hz": 2, "level_db": pts, "pops": rises}


def write_clip(video, t, path, offset):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % (offset + max(0, t - 0.25)),
                    "-t", "1.75", "-i", video, "-vn", "-ac", "2", "-ar", "44100", path], check=True)


def write_frame(video, t, path, offset):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % (offset + t + 0.03), "-i", video,
                    "-frames:v", "1", "-vf", "scale=320:-1", path], check=True)


def audition(out, cues):
    rows = []
    for c in cues:
        if not c.get("clip"):
            continue
        f = c["features"]
        rows.append(
            "<tr><td>%s</td><td><img src='%s'></td><td><b>%s</b> %.2f<br><audio controls preload=none src='%s'></audio></td>"
            "<td>+%.1f dB, decay %.2f s<br>centroid %d Hz, flat %.2f<br>tonal %.2f/%.2f, pitch %.2f @ %d Hz</td><td></td></tr>"
            % (c["tc"], c["frame"], c["class"], c["confidence"], c["clip"], f["above_bed_db"], f["decay_s"],
               f["centroid_hz"], f["flatness"], f["tonal_peaky"], f["tonal_hold"], f["pitch_strength"], f["f0_hz"]))
    page = ("<!doctype html><meta charset=utf-8><title>Reference cues</title><style>body{font:13px system-ui;"
            "background:#111;color:#ddd}td{border-bottom:1px solid #333;padding:4px;vertical-align:top}img{width:240px}"
            "</style><h1>Reference cues (reference only, never shipped)</h1><table><tr><th>time</th><th>frame</th>"
            "<th>class</th><th>features</th><th>verdict</th></tr>%s</table>" % "".join(rows))
    with open(os.path.join(out, "audition.html"), "w") as fh:
        fh.write(page)


def tc(t):
    return "%02d:%06.3f" % (int(t // 60), t % 60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, default=None)
    ap.add_argument("--frames", type=int, default=400, help="frames/clips for the strongest N cues")
    ap.add_argument("--min-above-bed", type=float, default=6.0)
    a = ap.parse_args()
    os.makedirs(os.path.join(a.out, "frames"), exist_ok=True)
    os.makedirs(os.path.join(a.out, "clips"), exist_ok=True)

    x = load(a.video, a.start, a.end)
    mag = stft_mag(x)
    freqs = np.fft.rfftfreq(N_FFT, 1 / SR)
    level = db(mag.mean(axis=1))
    bed_db = rolling_median(level, int(2.0 * SR / HOP))
    peaks, _, _ = onsets(mag)

    cues = []
    for p in peaks:
        f = features(x, mag, freqs, bed_db, p)
        if f["above_bed_db"] < a.min_above_bed:
            continue
        cls, conf = classify(f)
        t = p * HOP / SR
        cues.append({"t": round(t, 3), "tc": tc(t + a.start), "class": cls,
                     "confidence": round(conf, 2), "features": f})
    strongest = sorted(cues, key=lambda c: -c["features"]["above_bed_db"])[:a.frames]
    for c in sorted(strongest, key=lambda c: c["t"]):
        stem = "%07.2f_%s" % (c["t"] + a.start, c["class"])
        c["frame"] = "frames/%s.jpg" % stem
        c["clip"] = "clips/%s.wav" % stem
        write_frame(a.video, c["t"], os.path.join(a.out, c["frame"]), a.start)
        write_clip(a.video, c["t"], os.path.join(a.out, c["clip"]), a.start)
    for c in cues:
        c["t"] = round(c["t"] + a.start, 3)

    crowd = crowd_curve(mag, freqs)
    for pop in crowd["pops"]:
        pop["t"] = round(pop["t"] + a.start, 1)
    with open(os.path.join(a.out, "cues.json"), "w") as fh:
        json.dump({"video": os.path.basename(a.video), "start": a.start, "cues": cues}, fh, indent=1)
    with open(os.path.join(a.out, "crowd.json"), "w") as fh:
        json.dump(crowd, fh)
    with open(os.path.join(a.out, "cues.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["t", "tc", "class", "confidence", "above_bed_db", "decay_s", "centroid_hz",
                    "flatness", "tonal_peaky", "tonal_hold", "pitch_strength", "f0_hz", "clip"])
        for c in cues:
            f = c["features"]
            w.writerow([c["t"], c["tc"], c["class"], c["confidence"], f["above_bed_db"], f["decay_s"],
                        f["centroid_hz"], f["flatness"], f["tonal_peaky"], f["tonal_hold"], f["pitch_strength"], f["f0_hz"],
                        c.get("clip", "")])
    audition(a.out, cues)
    counts = {}
    for c in cues:
        counts[c["class"]] = counts.get(c["class"], 0) + 1
    print(json.dumps({"seconds": round(len(x) / SR, 1), "cues": len(cues), "classes": counts,
                      "crowd_pops": len(crowd["pops"]), "out": a.out}))


if __name__ == "__main__":
    sys.exit(main())
