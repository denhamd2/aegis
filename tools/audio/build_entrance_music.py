#!/usr/bin/env python3
"""Builds the entrance music in game/assets/audio/music/ from the owner's
titantron videos (game/assets/environment/video/*_entrance.ogv).

    python3 tools/audio/build_entrance_music.py

Why the music is its own file. It used to be the video's own audio track,
played once (StageVideo, loop off): Cody's runs 80 s and his entrance 86 s,
Roman's 115 s and his 154 s, so both went silent with the man still on his
way to the ring. A video cannot loop from part-way in -- Godot's Theora
player cannot seek -- but an Ogg Vorbis stream can (AudioStreamOggVorbis
loop_offset). So the music is cut out of the video, played on its own
player, and loops from LOOP_FROM back round from LOOP_TO for as long as the
entrance needs.

The loop points were found by matching spectra (a 2 s window either side of
the seam, ~23 ms frames), then the seam is made inaudible the standard way:
the last SEAM seconds before LOOP_TO are crossfaded into the SEAM seconds
before LOOP_FROM, so the audio heard just before the jump back is the audio
that leads into LOOP_FROM. The file ends at LOOP_TO; the game loops from
LOOP_FROM (StageVideo.ENTRANCES "loop_from" carries the same number).

Needs ffmpeg and numpy. Bit-exact across runs (libvorbis at a fixed quality,
no metadata). The game does not need this script: the .ogg files are
committed.
"""
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VIDEO = os.path.join(ROOT, "game", "assets", "environment", "video")
OUT = os.path.join(ROOT, "game", "assets", "audio", "music")
SR = 44100
SEAM = 0.4

# name -> (loop_from, loop_to), seconds. Cody: from the band's bar before
# the sung WHOAs back to the same bar 51.0 s on, before the outro fades.
# Roman: a bar after the slam, round 43.02 s, before his outro.
TRACKS = {
	"cody_entrance": (20.000, 71.000),
	"roman_entrance": (62.361, 105.379),
}


def load(path: str) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vn", "-f", "f32le",
			"-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).copy().reshape(-1, 2)


def save(name: str, x: np.ndarray) -> None:
	x = np.clip(x, -1.0, 1.0).astype(np.float32)
	path = os.path.join(OUT, name + ".ogg")
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR),
			"-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "6",
			"-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", path],
			input=x.tobytes(), check=True)
	print(f"  {name}.ogg  {len(x) / SR:6.2f}s  loop {TRACKS[name][0]:.3f}-{TRACKS[name][1]:.3f}")


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	for name, (loop_from, loop_to) in TRACKS.items():
		x = load(os.path.join(VIDEO, name + ".ogv"))
		a, b, n = int(round(loop_from * SR)), int(round(loop_to * SR)), int(SEAM * SR)
		out = x[:b].copy()
		# Equal-power crossfade: the tail fades out as the lead-in to
		# loop_from fades up.
		t = np.linspace(0.0, 1.0, n)[:, None]
		out[b - n:b] = x[b - n:b] * np.cos(t * np.pi / 2) + x[a - n:a] * np.sin(t * np.pi / 2)
		save(name, out)


if __name__ == "__main__":
	main()
