#!/usr/bin/env python3
"""Builds crowd_swell.ogg, the crowd's second walla layer, from the committed
crowd_walla_a.ogg (kyles, CC0 -- assets/audio/CREDITS.md).

    python3 tools/audio/build_crowd_swell.py

The layer it replaces, crowd_walla_b, was a lucha libre field recording with
a man on a horn over the crowd -- sustained narrow-band tones at 1-8 s and
44-47 s that the owner heard as "someone on a megaphone in the distance"
(2 Nov). This is the clean arena walla instead, pitched down 6 % (a different,
larger-sounding section of the house, not the same people again), started
from a different point, a presence lift at 2.5 kHz so it reads as voices
rather than room, and cut to 43 s: co-prime with the bed's 52 s and walla_a's
41 s, so no two seams line up for half an hour. Loudness-matched to the other
crowd loops (-16 LUFS, build_sfx.CROWD_LUFS). Needs ffmpeg.
"""
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, "game", "assets", "audio")
SRC = os.path.join(AUDIO, "crowd_walla_a.ogg")
OUT = os.path.join(AUDIO, "crowd_swell.ogg")
LENGTH = 43.0
FADE = 1.5
PITCH = 0.94
LUFS = -16.0


def _ffmpeg_pcm(args: list) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-v", "error"] + args + ["-f", "f32le", "-ac", "2", "-ar", "44100", "-"],
			capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).reshape(-1, 2)


def main() -> None:
	sr = 44100
	# Pitched down 6 % (resampled, so slower too), with the presence lift.
	src = _ffmpeg_pcm(["-i", SRC, "-af", f"asetrate={sr}*{PITCH},aresample={sr},"
			"equalizer=f=2500:t=q:w=0.9:g=3,highpass=f=70"])
	start = int(17.0 * sr)
	n = int(LENGTH * sr)
	f = int(FADE * sr)
	src = np.concatenate([src, src, src])
	seg = src[start:start + n + f].copy()
	# The tail crossfades onto the head (equal power), so the loop has no seam.
	t = np.linspace(0.0, 1.0, f, dtype=np.float32)[:, None]
	body = seg[:n].copy()
	body[:f] = body[:f] * np.sin(t * np.pi / 2) + seg[n:n + f] * np.cos(t * np.pi / 2)
	pcm = body.astype("<f4").tobytes()
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(sr), "-ac", "2", "-i", "-",
			"-af", f"loudnorm=I={LUFS}:TP=-2:LRA=11:linear=true", "-ar", str(sr),
			"-c:a", "libvorbis", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact",
			"-map_metadata", "-1", OUT], input=pcm, check=True)
	print("wrote", OUT)


if __name__ == "__main__":
	main()
