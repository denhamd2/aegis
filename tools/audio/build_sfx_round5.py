#!/usr/bin/env python3
"""Round 5: re-shape the strike and bump families toward a measured target.

The Audio Director's pass over a finisher reel (reference only; none of its
audio is used here) measured the shape of its strikes and falls relative to
their own 120-400 Hz band, against the same analysis of ours
(.claude/skills/audio-director/scripts/analyse_reference.py):

                 decay   sub   lowmid  pres   air    (dB vs 120-400 Hz)
  target strike  35 ms   +4    -6      -14    -25
  ours punch     93 ms   +2    -11     -20    -31
  ours forearm   99 ms   +4    -12     -22    -33
  ours kick     104 ms   +15   -14     -18    -22
  target fall   232 ms   +10   -7      -13    -25
  ours bump     221 ms   -2    -14     -23    -37

So: strikes ring two to three times too long and are dull in the "smack"
(400-1500 Hz) and presence bands; the kick is all boom; the bump lacks the
board's low end and the canvas slap. This script re-shapes the shipped CC0
takes (no new sources): EQ toward the target, a fast envelope on strikes, the
loudness of each original kept (integrated LUFS, -1 dBTP ceiling) so the
audition compares shape, not level.

Inputs are pinned by sha256 so a re-run on re-shaped files fails loudly.
Default output is a candidates folder; --ship writes over game/assets/audio.

  python3 tools/audio/build_sfx_round5.py --out <dir>
  python3 tools/audio/build_sfx_round5.py --ship
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "game", "assets", "audio")

# A strike: the smack forward, the ring 20 dB down by ~65 ms (target 35 ms
# under a crowd bed and broadcast compression; ours plays over a quieter bed).
STRIKE_ENV = "volume='if(lt(t,0.015),1,exp(-(t-0.015)/0.022))':eval=frame"
SHAPES = {
    "hit_punch": "equalizer=f=900:t=o:w=1.2:g=6,equalizer=f=2600:t=o:w=1.2:g=6,highshelf=f=5000:g=3," + STRIKE_ENV,
    "hit_forearm": "equalizer=f=900:t=o:w=1.2:g=6,equalizer=f=2600:t=o:w=1.2:g=7,highshelf=f=5000:g=3," + STRIKE_ENV,
    "hit_kick": "equalizer=f=55:t=o:w=1.5:g=-9,equalizer=f=900:t=o:w=1.2:g=7,equalizer=f=2600:t=o:w=1.2:g=4," + STRIKE_ENV,
    # A fall: the deck's low end and the canvas slap; its decay already matches.
    "bump": "equalizer=f=65:t=o:w=1.2:g=9,equalizer=f=900:t=o:w=1.2:g=5,equalizer=f=2800:t=o:w=1.2:g=6",
}
# hit_chop already sits on the target's presence (centroid 3.2 kHz): skipped.

PIN_FILE = os.path.join(os.path.dirname(__file__), "round5_inputs.sha256")


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def inputs():
    out = []
    for fam in SHAPES:
        i = 0
        while os.path.exists(os.path.join(AUDIO, f"{fam}_{i}.ogg")):
            out.append((fam, f"{fam}_{i}.ogg"))
            i += 1
    return out


def lufs(path):
    """Loudness to match on. Integrated LUFS gates out anything under 400 ms
    (most strikes), so this is the K-weighted RMS over the sound instead: the
    same weighting ebur128 uses, without its gate."""
    r = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af",
                        "highshelf=f=1500:g=4,highpass=f=60,astats=metadata=0:measure_perchannel=none",
                        "-f", "null", "-"], capture_output=True, text=True).stderr
    return float(re.findall(r"RMS level dB:\s+(-?[\d.]+)", r)[-1])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", help="candidates folder")
    ap.add_argument("--ship", action="store_true", help="write over game/assets/audio")
    ap.add_argument("--pin", action="store_true", help="record the current inputs' sha256 (first run only)")
    a = ap.parse_args()
    files = inputs()
    if a.pin:
        with open(PIN_FILE, "w") as f:
            for _, name in files:
                f.write(f"{sha(os.path.join(AUDIO, name))}  {name}\n")
        print(f"pinned {len(files)} inputs")
        return
    pins = dict(reversed(l.split()) for l in open(PIN_FILE) if l.strip())
    out = AUDIO if a.ship else a.out
    if not out:
        sys.exit("--out <dir> or --ship")
    os.makedirs(out, exist_ok=True)
    src_dir = AUDIO
    if a.ship:  # read from a copy: the outputs overwrite the inputs
        import shutil
        import tempfile
        src_dir = tempfile.mkdtemp()
        for _, name in files:
            shutil.copy(os.path.join(AUDIO, name), src_dir)
    for fam, name in files:
        src = os.path.join(src_dir, name)
        if pins.get(name) != sha(src):
            sys.exit(f"{name}: not the pinned input (already re-shaped?)")
        want = lufs(src)
        tmp = os.path.join(out, "._" + name + ".wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", SHAPES[fam], "-c:a", "pcm_f32le", tmp], check=True)
        gain = want - lufs(tmp)
        lim = tmp + ".lim.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89:attack=1:release=20:level=false",
                        "-c:a", "pcm_s16le", "-map_metadata", "-1", lim], check=True)
        # libvorbis q5 via oggenc (Homebrew's ffmpeg has no libvorbis); a fixed
        # stream serial makes the file byte-identical run to run.
        subprocess.run(["oggenc", "-Q", "-q", "5", "-s", "1", "--discard-comments", "-o",
                        os.path.join(out, name), lim], check=True)
        os.remove(lim)
        os.remove(tmp)
        print(f"{name}: {want:.1f} dB RMS(K) kept, shape {fam}")


if __name__ == "__main__":
    main()
