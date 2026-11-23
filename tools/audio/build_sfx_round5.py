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
Then new bumps from three CC0 layers (see BUMPS), downloaded to
~/.cache/aegis_audio/round5 and pinned by sha256.

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


def encode(wav, gain, dest):
    """Gain, a -1 dBTP-ish limiter, and Vorbis q5. Homebrew's ffmpeg has no
    libvorbis, so oggenc encodes; a fixed stream serial makes the file
    byte-identical run to run."""
    lim = wav + ".lim.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact",
                    "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89:attack=1:release=20:level=false",
                    "-c:a", "pcm_s16le", "-map_metadata", "-1", lim], check=True)
    subprocess.run(["oggenc", "-Q", "-q", "5", "-s", "1", "--discard-comments", "-o", dest, lim], check=True)
    os.remove(lim)


# --- New bumps: three layers, because no single CC0 recording has all three.
# The target fall (sub +10, pres -13 dB vs 120-400 Hz) is a man (the body), the
# ring's deck under him (the low end) and the canvas (a crack at 2-4 kHz).
#   body:   kyles 454221, a wrestler on a ring mat, 48 kHz/24-bit: 8 falls,
#           each the first transient of its group (the later onsets are his
#           breath, which is WrestlerVoice's job, so the cut ends before it).
#   deck:   Vrymaa 734629 (a heavy fall on wooden stairs) and courtneyeck
#           673424 (a body on a floor): sub +6..+9 dB, what the mat lacks.
#   canvas: our own hit_chop takes (CC0 slaps, already shipped), low in the mix.
CACHE = os.path.expanduser("~/.cache/aegis_audio/round5")
SOURCES = {  # downloaded 2026-11-23 with the owner's OK; CC0 on each page
    "kyles": ("454221__kyles__thud-impact-wrestling-ring-heavy-wrestler-fall-on-mat-breath-exhale.flac",
              "89c9789aa937d1d97cb71329a45367be03736c9f2c904d800e19ab6e4a897fc5"),
    "courtneyeck": ("673424__courtneyeck__falling-body-hits-the-floor.mp3",
                    "41af4ed6dbb88929275f45ad1050333473b19589cae32325c2ce1ed09d4cc5d7"),
    "vrymaa": ("734629__vrymaa__body-fall-heavy-dangerous.wav",
               "d09e84c22e2ac5fdc7799e149acfd945ba826dde9821d30e0f532c94541bb82f"),
}
BODY_LEN = 0.42  # s: the fall and its ring-out (target decay ~230 ms), before the exhale
# (body onset s, deck source, deck onset s, deck dB, canvas take, canvas dB)
BUMPS = [
    (12.18, "vrymaa", 2.67, -4, "hit_chop_0", -8),
    (18.98, "vrymaa", 4.17, -5, "hit_chop_1", -9),
    (25.10, "courtneyeck", 1.08, -3, "hit_chop_2", -8),
    (31.85, "vrymaa", 0.44, -3, "hit_chop_0", -10),
    (37.60, "vrymaa", 7.54, -5, "hit_chop_1", -8),
    (43.82, "courtneyeck", 1.08, -5, "hit_chop_2", -9),
    (50.56, "vrymaa", 2.67, -6, "hit_chop_1", -10),
    (55.01, "vrymaa", 4.17, -4, "hit_chop_2", -9),
]
# Then the same tilt the old bumps needed, gentler: these start full-band.
BUMP_EQ = "highpass=f=30,equalizer=f=70:t=o:w=1.2:g=4,equalizer=f=1000:t=o:w=1.2:g=3,equalizer=f=2800:t=o:w=1.2:g=7,highshelf=f=5000:g=4"


def build_new_bumps(out, names, pins):
    for key, (fn, digest) in SOURCES.items():
        p = os.path.join(CACHE, fn)
        if not os.path.exists(p) or sha(p) != digest:
            sys.exit(f"{key}: missing or not the pinned download ({p})")
    # Match the family: the median K-weighted RMS of the bumps that ship now.
    olds = sorted(lufs(os.path.join(AUDIO, f"bump_{i}.ogg")) for i in range(12))
    want = olds[len(olds) // 2]
    for (b_at, deck, d_at, d_db, chop, c_db), name in zip(BUMPS, names):
        chop_p = os.path.join(AUDIO, chop + ".ogg")
        if pins.get(chop + ".ogg") != sha(chop_p):
            sys.exit(f"{chop}: not the pinned input")
        pre = 0.008  # each cut starts 8 ms before its transient, so they line up
        fc = (f"[0:a]atrim={b_at - pre}:{b_at - pre + BODY_LEN},asetpts=N/SR/TB,aresample=48000,"
              f"aformat=sample_fmts=fltp:channel_layouts=mono[b];"
              f"[1:a]atrim={max(0, d_at - pre)}:{d_at - pre + BODY_LEN},asetpts=N/SR/TB,aresample=48000,"
              f"aformat=sample_fmts=fltp:channel_layouts=mono,volume={d_db}dB[d];"
              f"[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono,volume={c_db}dB[c];"
              f"[b][d][c]amix=inputs=3:normalize=0:duration=first,{BUMP_EQ},"
              f"afade=t=out:st={BODY_LEN - 0.24}:d=0.24")
        tmp = os.path.join(out, "._" + name + ".wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(CACHE, SOURCES["kyles"][0]),
                        "-i", os.path.join(CACHE, SOURCES[deck][0]), "-i", chop_p,
                        "-filter_complex", fc, "-c:a", "pcm_f32le", tmp], check=True)
        encode(tmp, want - lufs(tmp), os.path.join(out, name))
        os.remove(tmp)
        print(f"{name}: kyles@{b_at} + {deck}@{d_at} {d_db} dB + {chop} {c_db} dB, {want:.1f} dB RMS(K)")


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
            for i in range(3):  # the canvas layer of the new bumps (read, never rewritten)
                f.write(f"{sha(os.path.join(AUDIO, f'hit_chop_{i}.ogg'))}  hit_chop_{i}.ogg\n")
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
        encode(tmp, gain, os.path.join(out, name))
        os.remove(tmp)
        print(f"{name}: {want:.1f} dB RMS(K) kept, shape {fam}")
    # The new three-layer bumps. Shipped, they replace bump_0-5 (the
    # band-limited optical-library takes: air -37 dB vs the target's -25) and
    # add bump_12-13; as candidates they are bump_new_N.
    names = ([f"bump_{i}.ogg" for i in (0, 1, 2, 3, 4, 5, 12, 13)] if a.ship
             else [f"bump_new_{i}.ogg" for i in range(len(BUMPS))])
    build_new_bumps(out, names, pins)


if __name__ == "__main__":
    main()
