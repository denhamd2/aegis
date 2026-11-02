#!/usr/bin/env python3
"""Builds the match's crowd beds from the wrestling-crowd recordings only.

    /tmp/claude-0/bpyenv/bin/python tools/audio/build_crowd_beds.py

The owner, 2 Nov: "I still heard that crappy crowd audio throughout where it
sounds like either someone talking or distant on a megaphone. Remove that
completely and just use wrestling crowd audio." The old bed, its walla layer
and the swell built from it were all one recording -- a hall WALLA (kyles,
"crowd int large dense arena stadium hall"), and walla is, by definition, a
crowd murmuring and talking. So nothing here comes from it. Both beds are
made from the cheering, roaring and popping recordings already in
game/assets/audio (CC0 -- assets/audio/CREDITS.md):

  crowd_bed    53 s  the house: crowd_cheer pitched down 7 % (a bigger,
                     further-off room) under the pops and the finish pitched
                     down 4 %, low-passed at 5 kHz so it sits behind the
                     action, and levelled so it is a steady cheer rather
                     than a reaction.
  crowd_swell  43 s  what rises with the excitement: crowd_cheer at pitch,
                     crowd_pop_4 and crowd_finish laid end to end over it.
  crowd_roar   29 s  the full-house roar CrowdReaction fades up on a big
                     moment: the pops and the finish, end to end, a little
                     faster than the bed's.

The owner, later on 2 Nov: "The base crowd noise has a lot of clapping,
instead I want it to be primarily cheering." Measured (sharp transients in
the 1.5-6 kHz clap band, a 5 ms envelope over twice its 150 ms one): the old
crowd_roar (FoolBoyMedia, "Crowd Cheer") 22.9 per mille -- applause -- and
the bed that had it under the cheer 9.0; every other crowd recording 0. So
that recording is out of the crowd entirely: the bed is built from the
cheering and screaming recordings only, and the roar layer is rebuilt from
the pops and the finish.

Each loops with an equal-power crossfade, is cut to -16 LUFS like every crowd
loop (build_sfx.CROWD_LUFS), and has a length co-prime with the other's and
with the heat loops'. Deterministic: same inputs, byte-identical files.
Needs ffmpeg and numpy.
"""
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, "game", "assets", "audio")
SR = 44100
LUFS = -16.0
FADE = 1.5


def pcm(name: str, af: str = "") -> np.ndarray:
	args = ["ffmpeg", "-v", "error", "-i", os.path.join(AUDIO, name + ".ogg")]
	if af:
		args += ["-af", af]
	raw = subprocess.run(args + ["-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
			capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()


def pitched(name: str, ratio: float, extra: str = "") -> np.ndarray:
	af = f"asetrate={SR}*{ratio},aresample={SR}"
	return pcm(name, af + ("," + extra if extra else ""))


def tile(x: np.ndarray, n: int, start: int = 0) -> np.ndarray:
	reps = (start + n) // len(x) + 2
	return np.concatenate([x] * reps)[start:start + n]


def rms(x: np.ndarray) -> float:
	return float(np.sqrt(np.mean(x * x)) + 1e-9)


def level(x: np.ndarray, window: float = 0.75, strength: float = 0.6) -> np.ndarray:
	"""Even out the swells: divide by a smoothed envelope, partly."""
	w = int(window * SR)
	env = np.sqrt(np.convolve((x * x).mean(1), np.ones(w) / w, mode="same")) + 1e-6
	gain = (env.mean() / env) ** strength
	return x * gain[:, None]


def loop(x: np.ndarray, length: float) -> np.ndarray:
	n, f = int(length * SR), int(FADE * SR)
	x = tile(x, n + f)
	t = np.linspace(0.0, 1.0, f, dtype=np.float32)[:, None]
	body = x[:n].copy()
	body[:f] = body[:f] * np.sin(t * np.pi / 2) + x[n:n + f] * np.cos(t * np.pi / 2)
	return body


def save(name: str, x: np.ndarray) -> None:
	out = os.path.join(AUDIO, name + ".ogg")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
			"-af", f"loudnorm=I={LUFS}:TP=-2:LRA=11:linear=true", "-ar", str(SR),
			"-c:a", "libvorbis", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact",
			"-map_metadata", "-1", out], input=x.astype("<f4").tobytes(), check=True)
	print("wrote", out)


def main() -> None:
	n = int(56 * SR)
	cheer = pitched("crowd_cheer", 0.93, "lowpass=f=5000,highpass=f=80")
	screams = np.concatenate([pitched(p, 0.96, "lowpass=f=5000,highpass=f=80")
			for p in ("crowd_pop_1", "crowd_pop_2", "crowd_finish", "crowd_pop_3", "crowd_pop_4")])
	bed = tile(cheer, n) / rms(cheer) + 0.75 * tile(screams, n, int(6.0 * SR)) / rms(screams)
	save("crowd_bed", loop(level(bed), 53.0))

	cheer_hi = pcm("crowd_cheer")
	pops = np.concatenate([pcm("crowd_pop_4"), pcm("crowd_finish")])
	swell = tile(cheer_hi, n, int(9.0 * SR)) / rms(cheer_hi) + 0.7 * tile(pops, n) / rms(pops)
	save("crowd_swell", loop(level(swell, strength=0.4), 43.0))

	# The roar: the screaming pops and the finish at pitch, levelled less so
	# it still surges -- applause-free (see the docstring).
	n_roar = int(32 * SR)
	roar = np.concatenate([pcm(p) for p in ("crowd_pop_3", "crowd_finish", "crowd_pop_1",
			"crowd_pop_4", "crowd_pop_2")])
	save("crowd_roar", loop(level(tile(roar, n_roar), strength=0.3), 29.0))


if __name__ == "__main__":
	main()
