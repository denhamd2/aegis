#!/usr/bin/env python3
"""Builds the entrance music in game/assets/audio/music/ from the owner's
full-length entrance videos.

    python3 tools/audio/build_entrance_music.py --source DIR

DIR holds the two mp4s the owner supplied (Google Drive, 2026-09-26; see
game/assets/environment/CREDITS.md), saved as cody_entrance.mp4 and
roman_entrance.mp4. They are not committed: 256 MB of video for two songs.

Why the music is its own file. It used to be the audio of the wall's
titantron clips (game/assets/environment/video/*.ogv), which were committed
as the first 80 s and 115 s of the owner's 3:38 videos, each with a fade --
so the song faded out with the man still on his way to the ring. The wall
only needs a picture that loops; the song has to run the whole entrance. So
the full song is cut from the full video here, played on its own player
(StageVideo), and the wall's clip plays silent.

The audio track and the wall clips share t = 0 (cross-correlated: zero
offset), so every beat the director cuts to the music is unchanged. Each
song plays once, straight through: 3:38 against entrances of 1:26 (Cody)
and 2:34 (Roman). Trailing silence is trimmed and the last FADE seconds
faded.

Needs ffmpeg and numpy. Bit-exact across runs (libvorbis at a fixed
quality, no metadata). The game does not need this script: the .ogg files
are committed.
"""
import argparse
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "audio", "music")
SR = 44100
FADE = 2.0
TRACKS = ("cody_entrance", "roman_entrance")


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
	print(f"  {name}.ogg  {len(x) / SR:6.2f}s")


def trim_tail(x: np.ndarray, below_db: float = -45.0) -> np.ndarray:
	env = np.abs(x).max(axis=1)
	loud = np.nonzero(env > float(env.max()) * 10 ** (below_db / 20))[0]
	return x[:loud[-1] + 1] if len(loud) else x


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--source", required=True, help="folder with the owner's mp4s")
	args = parser.parse_args()
	os.makedirs(OUT, exist_ok=True)
	for name in TRACKS:
		x = trim_tail(load(os.path.join(args.source, name + ".mp4")))
		n = int(FADE * SR)
		x[-n:] *= np.linspace(1.0, 0.0, n)[:, None] ** 2
		save(name, x)


if __name__ == "__main__":
	main()
