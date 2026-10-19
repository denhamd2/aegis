#!/usr/bin/env python3
"""A listening reel and a review sheet for the match sounds, so a round of
sound work can be judged by ear and by eye without running the game.

    python3 tools/audio/listening_reel.py <reel.ogg> <sheet.png>

The reel lays each kind of hit and voice over the crowd bed at the level the
match plays it (MatchAudio.BED_DB, MatchAudio.hit_volume's range,
WrestlerVoice.LEVEL_DB), a beat apart, ending on a man on fire who is put out.
The sheet shows one take per family: its waveform, its spectrogram (0-8 kHz)
and where it came from. Reads game/assets/audio/ only; needs ffmpeg.
"""
import os
import subprocess
import sys
import textwrap

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, "game", "assets", "audio")
SR = 44100
BED_DB = -5.0

# (label, sound, level dB, gap after, s) -- in the order a match might go.
REEL = [
	("jab", "hit_punch_0", -6.0, 0.7), ("right hand", "hit_punch_2", -2.0, 0.5),
	("  grunt", "grunt_light_1", -6.0, 0.9),
	("chop", "hit_chop_0", -2.0, 0.6), ("chop", "hit_chop_2", -2.0, 0.9),
	("forearm", "hit_forearm_0", -1.0, 0.25), ("  hard grunt", "grunt_heavy_0", -3.0, 0.9),
	("kick", "hit_kick_0", -1.0, 0.25), ("  hard grunt", "grunt_heavy_2", -3.0, 1.0),
	("back bump", "bump_6", 0.0, 0.45), ("  groan", "groan_0", -4.0, 1.2),
	("slam", "bump_8", 0.0, 0.5), ("  groan", "groan_2", -4.0, 1.2),
	("chair shot", "hit_chair_0", -1.0, 0.25), ("  hard grunt", "grunt_heavy_1", -3.0, 1.0),
	("kendo stick", "hit_kendo_0", -1.0, 0.8), ("kendo stick", "hit_kendo_1", -1.0, 1.0),
	("trash can", "hit_can_0", -1.0, 1.0), ("sledgehammer", "hit_sledge_0", -1.0, 0.25),
	("  yell", "yell_0", -1.0, 1.2), ("ladder", "hit_ladder_0", -1.0, 1.2),
	("through a table", "table_crack_0", 0.0, 1.4), ("through a table", "table_crack_2", 0.0, 1.4),
	("announce desk", "desk_crash_0", 0.0, 1.6),
	("on fire", "burn_scream_0", 0.0, 0.18), ("on fire", "burn_scream_3", 0.0, 0.18),
	("put out", "groan_1", -4.0, 1.5),
]

# One take per family on the sheet, and where each family came from.
SHEET = [
	("hit_punch_0", "Punch", "Freesound 853588 Wigglesworth (hand) + 478155 bspiller5 (thump) + 444407 MootMcnoodles"),
	("hit_chop_0", "Chop", "Freesound 444407 MootMcnoodles / 564230 (slap) + 853588 (hand)"),
	("hit_forearm_0", "Forearm / elbow / lariat", "Freesound 853588 + 478155"),
	("hit_kick_0", "Kick / stomp / knee", "Freesound 460509 florianreichelt (face) + 478155"),
	("bump_6", "Bump (boards)", "Freesound 128103 Project_Trident"),
	("hit_chair_0", "Steel chair", "Freesound 125137 connersaw8 / 115918, 115923 issalcake + 478155"),
	("hit_kendo_0", "Kendo / hockey stick", "Freesound 114683 Qat + 444407"),
	("hit_can_0", "Trash can / cookie sheet", "Freesound 44871 stomachache + 478155"),
	("hit_sledge_0", "Sledgehammer", "Freesound 706979 JesterWhoo + 478155"),
	("hit_ladder_0", "Ladder", "Freesound 54850 qubodup + 372877 Hakren"),
	("table_crack_2", "Table breaking", "Freesound 512218 Mateusz_Chenc, 434146 NeoSpica, 115917 issalcake + 128103"),
	("desk_crash_0", "Announce desk", "Freesound 512218 + 115917 + 54850, Kenney impactGlass + 128103"),
	("grunt_light_0", "Grunt (light)", "Freesound 442288 rockittt"),
	("grunt_heavy_0", "Grunt (heavy)", "Freesound 218895 Halgrimm"),
	("groan_0", "Groan", "Freesound 442288 rockittt"),
	("yell_0", "Yell", "Freesound 556976 marc3122"),
	("burn_scream_0", "Burning scream", "Freesound 556976 marc3122, 325548 Archeos, 166943 qubodup"),
]


def load(name: str) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(AUDIO, name + ".ogg"), "-ac", "2",
			"-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def gain(db: float) -> float:
	return 10.0 ** (db / 20.0)


def reel(out: str) -> None:
	t = 1.0
	events = []
	for label, sound, db, gap in REEL:
		x = load(sound) * gain(db)
		events.append((t, x))
		t += len(x) / SR + gap
	n = int((t + 1.0) * SR)
	mix = np.zeros((n, 2), dtype=np.float32)
	bed = load("crowd_bed")
	reps = int(np.ceil(n / len(bed)))
	mix += np.tile(bed, (reps, 1))[:n] * gain(BED_DB)
	for start, x in events:
		i = int(start * SR)
		mix[i:i + len(x)] += x[:n - i]
	# the master limiter's ceiling (SfxPool.guard_master), crudely
	mix = np.clip(mix, -0.94, 0.94)
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
			"-c:a", "libvorbis", "-q:a", "6", out], input=mix.tobytes(), check=True)
	print(f"reel {out}: {t:.1f} s")
	for (label, sound, _, _), (start, _) in zip(REEL, events):
		print(f"  {start:5.1f}s  {label.strip():16s} {sound}")


def spectrogram(x: np.ndarray, w: int, h: int) -> Image.Image:
	mono = x.mean(axis=1)
	win = 1024
	hop = max(64, (len(mono) - win) // w) if len(mono) > win else 64
	frames = [mono[i:i + win] * np.hanning(win) for i in range(0, max(1, len(mono) - win), hop)] or [np.zeros(win)]
	spec = np.abs(np.fft.rfft(np.array(frames), axis=1)).T
	freqs = np.fft.rfftfreq(win, 1.0 / SR)
	spec = spec[freqs <= 8000]
	db = 20.0 * np.log10(spec + 1e-6)
	db = np.clip((db - (db.max() - 70.0)) / 70.0, 0.0, 1.0)
	img = (np.stack([db ** 0.8, db ** 1.6, db ** 3.0 * 0.6 + db * 0.2], axis=-1) * 255).astype(np.uint8)
	return Image.fromarray(img[::-1]).resize((w, h), Image.BILINEAR)


def sheet(out: str) -> None:
	row_h, wave_w, spec_w, label_w = 74, 520, 520, 420
	width = label_w + wave_w + spec_w + 40
	height = 90 + row_h * len(SHEET) + 30
	img = Image.new("RGB", (width, height), (18, 20, 24))
	d = ImageDraw.Draw(img)
	bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
	font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
	small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
	d.text((16, 14), "Step 5 - match sound: hits, bumps, weapons, tables, pain voices", fill=(240, 240, 240), font=bold)
	d.text((16, 48), "One take per family. Waveform (left) and spectrogram 0-8 kHz (right). All sources CC0.",
			fill=(170, 170, 180), font=font)
	for r, (sound, label, src) in enumerate(SHEET):
		y = 90 + r * row_h
		x = load(sound)
		mono = x.mean(axis=1)
		d.text((16, y + 6), label, fill=(240, 240, 240), font=font)
		d.text((16, y + 26), f"{sound}.ogg  {len(mono) / SR:.2f} s", fill=(150, 200, 255), font=small)
		for k, line in enumerate(textwrap.wrap(src, 62)[:2]):
			d.text((16, y + 42 + 13 * k), line, fill=(150, 150, 160), font=small)
		x0, h = label_w, row_h - 10
		d.rectangle([x0, y, x0 + wave_w, y + h], fill=(28, 31, 38))
		cols = np.array_split(np.abs(mono), wave_w)
		for i, c in enumerate(cols):
			v = float(c.max()) if len(c) else 0.0
			d.line([x0 + i, y + h / 2 - v * h / 2, x0 + i, y + h / 2 + v * h / 2], fill=(110, 220, 160))
		img.paste(spectrogram(x, spec_w, h), (x0 + wave_w + 20, y))
	img.save(out)
	print(f"sheet {out}")


if __name__ == "__main__":
	reel(sys.argv[1])
	sheet(sys.argv[2])
