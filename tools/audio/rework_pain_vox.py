"""Kenny/Cody/Roman's pain voices, reworked (the owner, 9 Nov: "The sounds of
wrestlers in pain sound awful, they sound like an elephant whaling. I want
authentic sounds of wrestler sounds after being hit.").

Measured (f0 by autocorrelation, "tonal" the normalised autocorrelation peak):
the light grunts and groans build_sfx.py cut from freesound 442288 sat at
270-390 Hz, held and tonal for up to 0.6 s -- a cry, not a man winded by a
blow. A hit man is low and breathy: the heavy grunts (Halgrimm, 95-131 Hz,
tonal 0.35-0.48) already are. So:

  grunt_light_* -- the onset of each heavy grunt, 0.2 s: a short "uh".
  groan_*       -- the four lowest, breathiest takes in OpenGameArt's CC0
                   "grunts of male death and pain" (thebardofblasphemy),
                   trimmed and taken down 12% at the same tempo.
  yell_*        -- the existing yells down 15% at the same tempo: a bark,
                   not a wail.

Deterministic: same inputs, same files. Run from the repo root:
  python3 tools/audio/rework_pain_vox.py
It reads the committed grunt_heavy_*/yell_* takes, so run it once on the
build_sfx.py output (it keeps the yells it reworks as tools/audio/sources/*_src.ogg).
"""
import os, shutil, subprocess, urllib.request

AUDIO = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "audio")
CACHE = os.path.expanduser("~/.cache/aegis_audio/oga")
PAIN_URL = "https://opengameart.org/sites/default/files/death%20pain%20grunts.wav"
## (start s, length s) in the CC0 file: its low, breathy takes (137-237 Hz).
GROANS = [(14.46, 0.85), (35.98, 0.80), (10.32, 0.80), (45.40, 0.40)]
GROAN_PITCH = 0.88
YELL_PITCH = 0.85
LIGHT_LENGTH = 0.20


def ff(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def pitch(ratio):
    return "asetrate=44100*%g,aresample=44100,atempo=%g" % (ratio, 1.0 / ratio)


SOURCES = os.path.join(os.path.dirname(__file__), "sources")


def src(name):
    """The take as build_sfx.py wrote it, kept (tools/audio/sources) so the
    rework never runs on its own output."""
    path = os.path.join(AUDIO, name + ".ogg")
    keep = os.path.join(SOURCES, name + "_src.ogg")
    os.makedirs(SOURCES, exist_ok=True)
    if not os.path.exists(keep):
        shutil.copyfile(path, keep)
    return keep


def out(name, inp, filt, extra=()):
    ff(list(extra) + ["-i", inp, "-ac", "1", "-ar", "44100", "-af", filt,
                      "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                      "-c:a", "libvorbis", "-q:a", "5", "-serial_offset", "0",
                      os.path.join(AUDIO, name + ".ogg")])


def main():
    os.makedirs(CACHE, exist_ok=True)
    pain = os.path.join(CACHE, "death_pain_grunts.wav")
    if not os.path.exists(pain):
        urllib.request.urlretrieve(PAIN_URL, pain)
    for i in range(4):
        heavy = os.path.join(AUDIO, "grunt_heavy_%d.ogg" % i)
        out("grunt_light_%d" % i, heavy,
            "silenceremove=start_periods=1:start_threshold=-40dB,atrim=0:%g,afade=t=out:st=%g:d=0.06,"
            "alimiter=limit=0.6" % (LIGHT_LENGTH, LIGHT_LENGTH - 0.06))
    for i, (t, n) in enumerate(GROANS):
        out("groan_%d" % i, pain, "atrim=%g:%g,asetpts=PTS-STARTPTS,%s,afade=t=in:d=0.01,"
            "afade=t=out:st=%g:d=0.15,alimiter=limit=0.7" % (t, t + n, pitch(GROAN_PITCH), n - 0.15))
    for i in range(4):
        y = src("yell_%d" % i)
        out("yell_%d" % i, y, "%s,alimiter=limit=0.8" % pitch(YELL_PITCH))


if __name__ == "__main__":
    main()
