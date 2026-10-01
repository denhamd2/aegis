#!/usr/bin/env python3
"""Rebuilds a recording's soundtrack from its sound log.

    python3 tools/capture/mix_sound_log.py <out_dir> [fps] > /dev/null

tools/probe/title_video.gd writes <out_dir>/sound_log.txt beside the frames:
every audio player in the game as it starts, changes level and stops, by
frame. This plays the same files back at the same frames, the same pitch and
the same levels, and writes <out_dir>/sound.wav (48 kHz stereo) exactly as
long as the frames. Loops (the crowd beds) wrap; one-shots stop at their end
or when the voice is reused; the entrance videos contribute their own audio
track. A hard limit at -0.5 dBFS stands in for the game's master limiter.

Needs ffmpeg and numpy.
"""
import os
import subprocess
import sys

import numpy as np

SR = 48000
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")


def decode(res_path: str, cache: dict) -> np.ndarray:
	if res_path not in cache:
		path = os.path.join(GAME, res_path.replace("res://", ""))
		raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vn", "-f", "f32le",
				"-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
		cache[res_path] = np.frombuffer(raw, np.float32).reshape(-1, 2) if raw else np.zeros((1, 2), np.float32)
	return cache[res_path]


def main() -> None:
	out = sys.argv[1]
	fps = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
	frames = len([f for f in os.listdir(out) if f.startswith("f_") and f.endswith(".jpg")])
	if len(sys.argv) > 3:
		frames = int(sys.argv[3])
	spf = SR / fps
	total = int(round(frames * spf))
	mix = np.zeros((total, 2), np.float64)
	cache: dict = {}
	# id -> open segment: [path, loop, pitch, start_frame, [(frame, db), ...]]
	open_seg: dict = {}
	segments: list = []
	with open(os.path.join(out, "sound_log.txt")) as fh:
		for line in fh:
			p = line.split()
			if not p:
				continue
			kind, frame, sid = p[0], int(p[1]), p[2]
			if kind == "S":
				if sid in open_seg:
					segments.append(open_seg.pop(sid) + [frame])
				open_seg[sid] = [p[3], p[4] == "1", float(p[5]), frame, [(frame, float(p[6]))]]
			elif kind == "V" and sid in open_seg:
				open_seg[sid][4].append((frame, float(p[3])))
			elif kind == "E" and sid in open_seg:
				segments.append(open_seg.pop(sid) + [frame])
	for seg in open_seg.values():
		segments.append(seg + [frames])
	for path, loop, pitch, start, levels, end in segments:
		if not path or start >= frames:
			continue
		src = decode(path, cache)
		a = int(round(start * spf))
		b = min(int(round(end * spf)), total)
		n = b - a
		if n <= 0:
			continue
		idx = np.arange(n) * pitch
		if loop:
			idx = np.mod(idx, len(src) - 1)
		else:
			n = min(n, int((len(src) - 1) / pitch))
			idx = idx[:n]
		if n <= 0:
			continue
		i0 = idx.astype(np.int64)
		frac = (idx - i0)[:, None]
		chunk = src[i0] * (1 - frac) + src[np.minimum(i0 + 1, len(src) - 1)] * frac
		# The level, stepped at each logged frame and eased over 10 ms.
		kf = np.array([int(round(f * spf)) - a for f, _ in levels], np.float64)
		gains = np.array([10 ** (db / 20) for _, db in levels], np.float64)
		t = np.arange(n, dtype=np.float64)
		gain = gains[np.clip(np.searchsorted(kf, t, side="right") - 1, 0, len(gains) - 1)]
		smooth = int(SR * 0.01)
		if smooth > 1 and len(gain) > smooth:
			kernel = np.ones(smooth) / smooth
			gain = np.convolve(gain, kernel, mode="same")
		mix[a:a + n] += chunk * gain[:, None]
	peak = float(np.abs(mix).max()) or 1.0
	ceiling = 10 ** (-0.5 / 20)
	# A soft knee over the ceiling rather than a wall: a tanh above -6 dBFS.
	knee = 10 ** (-6 / 20)
	over = np.abs(mix) > knee
	mix[over] = np.sign(mix[over]) * (knee + (ceiling - knee)
			* np.tanh((np.abs(mix[over]) - knee) / (ceiling - knee)))
	wav = os.path.join(out, "sound.wav")
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2",
			"-i", "-", wav], input=mix.astype(np.float32).tobytes(), check=True)
	print(f"{len(segments)} sounds, {frames} frames, {total / SR:.1f}s, input peak {20 * np.log10(peak):.1f} dBFS -> {wav}")


if __name__ == "__main__":
	main()
