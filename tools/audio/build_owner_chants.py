#!/usr/bin/env python3
"""The owner's crowd-chant recordings, made into match assets the same way
as crowd_cody_chant.ogg (assets/audio/CREDITS.md): loudness-matched to
TARGET_LUFS so every chant plays at the Cody chant's level, a 20 ms edge
fade so neither end clicks, Vorbis q5, stereo 48 kHz, metadata stripped.
The in-game fade in and out is CrowdChants'.

Run:  python3 tools/audio/build_owner_chants.py OTC.mp3 AWESOME.mp3 FU_ROMAN.mp3
(the owner's uploads, in that order; they are not kept in the repo)
"""

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "audio"
TARGET_LUFS = -20.0
NAMES = ["crowd_otc_chant", "crowd_this_is_awesome_chant", "crowd_fu_roman_chant"]


def lufs(path: pathlib.Path) -> float:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128=framelog=quiet",
                        "-f", "null", "-"], capture_output=True, text=True)
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)[-1])


def duration(path: pathlib.Path) -> float:
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json",
                        str(path)], capture_output=True, text=True)
    return float(json.loads(r.stdout)["format"]["duration"])


def main() -> None:
    for src, name in zip(sys.argv[1:], NAMES):
        src = pathlib.Path(src)
        gain = TARGET_LUFS - lufs(src)
        end = duration(src) - 0.02
        out = OUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
                        "-map_metadata", "-1", "-ac", "2", "-ar", "48000",
                        "-af", "volume=%.2fdB,alimiter=limit=0.89:level=false,afade=t=in:d=0.02,"
                               "afade=t=out:st=%.3f:d=0.02" % (gain, end),
                        "-c:a", "libvorbis", "-q:a", "5", "-fflags", "+bitexact", str(out)], check=True)
        print("%s: %+.1f dB -> %.1f LUFS, %.2f s" % (out.name, gain, lufs(out), duration(out)))


if __name__ == "__main__":
    main()
