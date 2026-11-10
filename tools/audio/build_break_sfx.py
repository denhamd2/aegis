#!/usr/bin/env python3
"""Builds the break sounds: a table, a pane of glass and the announce desk
going, in game/assets/audio/ (the owner, Nov: "table breaks ... should
spectacularly break, look realistic and make a loud crash sound").

    python3 -I tools/audio/build_break_sfx.py            # fetch if needed, build
    python3 -I tools/audio/build_break_sfx.py --fetch    # only fetch

Every source is a real recording from the Red Library sound effects on
archive.org, released CC0 (each item's licenseurl is checked at download,
the same check build_sfx.archive() makes). Nothing is synthesised: every file
is cuts of those recordings, aligned, layered, filtered and levelled. The cuts
are written down here -- which recording, which second -- so the same table
always builds byte-identical files. game/assets/audio/CREDITS.md lists every
source.

Downloads are untrusted data: each archive.org item is cached in its own
directory under ~/.cache/aegis_audio/breaks/<item>/, nothing in them is ever
executed, and this script reads them only as audio through ffmpeg. Run it
with `python3 -I`.

Writes (each a family SfxPool.play_any picks from):
  table_break_0..2   the wooden table: the board cracking through, the
                     splinters, the legs going, the man landing on the wood
  glass_break_0..2   the pane: the sheet bursting, the shards raining onto
                     the floor, the man through it
  desk_break_0..1    the announce desk: the worktop and panels caving, the
                     monitors' glass and their plastic clattering, the man

Needs ffmpeg and numpy. The game does not need this script: the .ogg files it
writes are committed.
"""
import hashlib
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "audio")
CACHE = os.path.expanduser("~/.cache/aegis_audio/breaks")
SR = 44100
CC0 = "publicdomain/zero"

# archive.org Red Library items (CC0) -> the recordings used from each.
SOURCES = {
	"Red_Library_Crashes": [
		"R01-01-Long Sustained Wood Crash",
		"R25-09-Big Sustained Crash - Wood and Metal",
		"R27-24-Crashes - Wood and Glass",
		"R28-09-Big Glass Breaks",
		"R28-11-Glass Windows Break",
		"R28-12-Glass Windows Break",
		"R28-13-Glass Windows Smashed",
		"R29-04-Crashing Collapse of Wood Building",
		"R29-32-Large Quick Interior Crash",
		"R29-34-Big Object Falls and Crashes in Room",
	],
	"Red_Library_Foley_Props_2": ["R22-32-Chop and Smash Wood Objects"],
	"Red_Library_Foley_Props_5": ["R29-30-Breaking Wooden Poles"],
	"Red_Library_Fights": [
		"R09-76-Two Falls on Wooden Floor",
		"R09-82-Falling on Muffled Wood",
		"R15-19-Muffled Body Fall",
	],
	"Red_Library_Impacts": ["R28-55-Thumps on Large Hollow Wooden Surface"],
}


# --- fetching ---------------------------------------------------------------

def _get(url: str) -> bytes:
	req = urllib.request.Request(url, headers={"User-Agent": "aegis-build-break-sfx"})
	with urllib.request.urlopen(req, timeout=300) as r:
		return r.read()


def fetch_all() -> None:
	for item, names in SOURCES.items():
		folder = os.path.join(CACHE, item)
		missing = [n for n in names if not os.path.exists(os.path.join(folder, n + ".wav"))
				or os.path.getsize(os.path.join(folder, n + ".wav")) == 0]
		if not missing:
			continue
		meta = json.loads(_get(f"https://archive.org/metadata/{item}"))
		if CC0 not in meta.get("metadata", {}).get("licenseurl", ""):
			sys.exit(f"archive.org {item} is no longer marked CC0 -- check before using it")
		os.makedirs(folder, exist_ok=True)
		listed = {f["name"]: f for f in meta.get("files", [])}
		for name in missing:
			url = f"https://archive.org/download/{item}/" + urllib.parse.quote(name + ".wav")
			data = _get(url)
			if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
				sys.exit(f"{item}/{name}.wav is not a WAV file")
			want = listed.get(name + ".wav", {})
			if "md5" in want and hashlib.md5(data).hexdigest() != want["md5"]:
				sys.exit(f"{item}/{name}.wav does not match the item's md5 -- a broken download?")
			# written whole or not at all: a cut-off download is never cached
			path = os.path.join(folder, name + ".wav")
			with open(path + ".part", "wb") as f:
				f.write(data)
			os.replace(path + ".part", path)
			print(f"  fetched {item}/{name}.wav  {len(data) // 1024} KiB")


def src(name: str) -> str:
	for item, names in SOURCES.items():
		if name in names:
			return os.path.join(CACHE, item, name + ".wav")
	raise KeyError(name)


# --- audio helpers (as build_sfx.py's) --------------------------------------

def load(name: str) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", src(name), "-f", "f32le",
			"-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).copy().reshape(-1, 1)


def save(name: str, x: np.ndarray) -> None:
	x = np.clip(x, -1.0, 1.0).astype(np.float32)
	path = os.path.join(OUT, name + ".ogg")
	# Bit-exact across runs: libvorbis at a fixed quality, no metadata.
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR),
			"-ac", str(x.shape[1]), "-i", "-", "-c:a", "libvorbis", "-q:a", "6",
			"-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", path],
			input=x.tobytes(), check=True)
	print(f"  {name}.ogg  {len(x) / SR:5.2f}s  {x.shape[1]}ch  {lufs(x):6.1f} LUFS")


def cut(x: np.ndarray, start: float, length: float) -> np.ndarray:
	a = int(start * SR)
	return x[a:a + int(length * SR)].copy()


def fade(x: np.ndarray, fade_in: float = 0.002, fade_out: float = 0.25) -> np.ndarray:
	n = len(x)
	fi, fo = min(int(fade_in * SR), n // 2), min(int(fade_out * SR), n // 2)
	if fi:
		x[:fi] *= np.linspace(0.0, 1.0, fi)[:, None]
	if fo:
		x[n - fo:] *= np.linspace(1.0, 0.0, fo)[:, None] ** 2
	return x


def peak_to(x: np.ndarray, db: float) -> np.ndarray:
	p = float(np.abs(x).max())
	return x * (10 ** (db / 20) / p) if p > 0 else x


def lufs(x: np.ndarray) -> float:
	import re
	r = subprocess.run(["ffmpeg", "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac",
			str(x.shape[1]), "-i", "-", "-af", "ebur128", "-f", "null", "-"],
			input=np.ascontiguousarray(x, np.float32).tobytes(), capture_output=True).stderr.decode()
	found = re.findall(r"I:\s+(-?[\d.]+) LUFS", r)
	return float(found[-1]) if found else -70.0


def ff(x: np.ndarray, af: str) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac",
			str(x.shape[1]), "-i", "-", "-af", af, "-f", "f32le", "-"],
			input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).reshape(-1, x.shape[1]).copy()


def trim_tail(x: np.ndarray, below_db: float = -48.0) -> np.ndarray:
	env = np.abs(x).max(axis=1)
	loud = np.nonzero(env > float(env.max()) * 10 ** (below_db / 20))[0]
	return x[:loud[-1] + 1] if len(loud) else x


def onset(x: np.ndarray, near: float, window: float = 0.35) -> float:
	"""The attack nearest `near` seconds: where the level first jumps."""
	a, b = max(0, int((near - window) * SR)), int((near + window) * SR)
	env = np.abs(x[a:b]).max(axis=1)
	hit = np.nonzero(env > float(env.max()) * 0.25)[0]
	return max(0.0, (a + int(hit[0])) / SR - 0.004) if len(hit) else near


def take(x: np.ndarray, t: float, n: float) -> np.ndarray:
	"""A cut from the attack nearest `t`, `n` seconds long, peak-matched so a
	gain in layer() is that layer's share of the crash."""
	return peak_to(cut(x, onset(x, t), n), 0.0)


def layer(parts: list) -> np.ndarray:
	"""[(seconds, clip, gain)] mixed onto one timeline."""
	end = max(int(t * SR) + len(c) for t, c, _ in parts)
	out = np.zeros((end, 1), np.float32)
	for t, c, g in parts:
		a = int(t * SR)
		out[a:a + len(c)] += c * g
	return out


def widen(x: np.ndarray, ms: float = 11.0) -> np.ndarray:
	"""Mono to a wide stereo crash: the right channel a few ms behind."""
	m = x[:, 0]
	d = int(ms / 1000 * SR)
	return np.stack([m, np.concatenate([np.zeros(d, np.float32), m[:-d]])], 1)


def slam(x: np.ndarray) -> np.ndarray:
	"""Loud, not just peaky: the dry crash with a heavily compressed copy of
	itself under it (parallel compression -- the transient stays, the body of
	the crash comes up), then levelled to -2 dBFS (the Vorbis decode overshoots a peak by about 1.5 dB). ffmpeg's acompressor is
	deterministic sample for sample."""
	squash = ff(x, "acompressor=threshold=0.03:ratio=12:attack=2:release=180:makeup=4")
	return peak_to(peak_to(x, 0.0) + 0.85 * peak_to(squash, 0.0), -2.0)


# --- the crashes ------------------------------------------------------------

def build() -> None:
	print("table breaks")
	# The wooden folding table: a sharp crack of the board going (the poles
	# snapping, the chopped-and-smashed wood), the long splintering crash
	# behind it, and the man landing on wood -- the boom of a hollow wooden
	# top under him and the body fall.
	poles = load("R29-30-Breaking Wooden Poles")
	smash = load("R22-32-Chop and Smash Wood Objects")
	wood_crash = load("R01-01-Long Sustained Wood Crash")
	collapse = load("R29-04-Crashing Collapse of Wood Building")
	room = load("R29-34-Big Object Falls and Crashes in Room")
	hollow = ff(load("R28-55-Thumps on Large Hollow Wooden Surface"), "lowpass=f=900")
	falls = load("R09-76-Two Falls on Wooden Floor")
	muffled = load("R09-82-Falling on Muffled Wood")
	body_fall = load("R15-19-Muffled Body Fall")
	TABLE = (
		# (crack: source, s), (splinters: source, s, len), (boom s), (fall: source, s)
		((poles, 13.54), (wood_crash, 14.12, 1.5), 3.40, (falls, 1.83)),
		((smash, 4.95), (collapse, 0.10, 1.7), 12.09, (muffled, 1.51)),
		((poles, 10.65), (room, 0.18, 1.6), 0.52, (body_fall, 2.59)),
	)
	for i, ((ck, ct), (sp, st, sn), boom, (bd, bt)) in enumerate(TABLE):
		crack = ff(take(ck, ct, 0.5), "highpass=f=180")
		splinters = fade(take(sp, st, sn), 0.004, 0.6)
		thud = fade(take(hollow, boom, 0.9), 0.002, 0.4)
		body = fade(ff(take(bd, bt, 0.7), "lowpass=f=2500"), 0.002, 0.3)
		x = layer([(0.0, crack, 1.0), (0.008, thud, 0.9), (0.012, body, 0.7), (0.03, splinters, 0.75)])
		save(f"table_break_{i}", widen(slam(fade(trim_tail(x), 0.002, 0.35))))

	print("glass breaks")
	# The pane: the sheet bursting (a big glass break, close), the shards
	# raining onto the floor after it (the windows smashed), and the man
	# through it onto the mat -- the body fall under the glass, low-passed so
	# it is felt under the brightness, not a second crash.
	big = load("R28-09-Big Glass Breaks")
	win_a = load("R28-11-Glass Windows Break")
	win_b = load("R28-12-Glass Windows Break")
	smashed = load("R28-13-Glass Windows Smashed")
	GLASS = (
		((big, 8.27), (smashed, 12.63, 1.7), (falls, 4.76)),
		((win_a, 4.50), (smashed, 8.55, 1.7), (muffled, 1.51)),
		((win_b, 9.42), (big, 1.41, 1.8), (body_fall, 2.59)),
	)
	for i, ((bk, bt0), (rn, rt, rnl), (bd, bt)) in enumerate(GLASS):
		burst = fade(take(bk, bt0, 1.4), 0.002, 0.5)
		rain = fade(ff(take(rn, rt, rnl), "highpass=f=1200"), 0.004, 0.7)
		body = fade(ff(take(bd, bt, 0.6), "lowpass=f=1200"), 0.002, 0.3)
		x = layer([(0.0, burst, 1.0), (0.006, body, 0.65), (0.10, rain, 0.55)])
		save(f"glass_break_{i}", widen(slam(fade(trim_tail(x), 0.002, 0.4)), 13.0))

	print("desk breaks")
	# The announce desk: heavier and longer than a table -- the worktop and
	# its panels caving (the big wood-and-metal crash, the interior crash),
	# the monitors' glass, their housings and the kit clattering down, and
	# the man landing in it.
	wm = load("R25-09-Big Sustained Crash - Wood and Metal")
	interior = load("R29-32-Large Quick Interior Crash")
	wood_glass = load("R27-24-Crashes - Wood and Glass")
	DESK = (
		((interior, 0.10), (wm, 6.02, 2.4), (win_a, 0.68), (wood_glass, 8.69, 1.4), (falls, 1.83)),
		((room, 0.18), (wm, 7.28, 2.4), (win_b, 3.97), (wood_glass, 0.43, 1.4), (body_fall, 2.59)),
	)
	for i, ((hk, ht), (cr, ct, cn), (gl, gt), (cl, clt, cln), (bd, bt)) in enumerate(DESK):
		hit = take(hk, ht, 1.6)
		crash = fade(take(cr, ct, cn), 0.004, 0.8)
		monitors = fade(ff(take(gl, gt, 1.2), "highpass=f=700"), 0.002, 0.5)
		clatter = fade(take(cl, clt, cln), 0.004, 0.6)
		thud = fade(take(hollow, 3.40 if i == 0 else 12.09, 0.9), 0.002, 0.4)
		body = fade(ff(take(bd, bt, 0.7), "lowpass=f=2000"), 0.002, 0.3)
		x = layer([(0.0, hit, 1.0), (0.004, thud, 0.9), (0.01, body, 0.6), (0.02, crash, 0.8),
				(0.05, monitors, 0.55), (0.25, clatter, 0.5)])
		save(f"desk_break_{i}", widen(slam(fade(trim_tail(x), 0.002, 0.5)), 15.0))


if __name__ == "__main__":
	fetch_all()
	if "--fetch" in sys.argv:
		sys.exit(0)
	build()
	digest = hashlib.sha256()
	for f in sorted(os.listdir(OUT)):
		if f.startswith(("table_break_", "glass_break_", "desk_break_")) and f.endswith(".ogg"):
			with open(os.path.join(OUT, f), "rb") as fh:
				digest.update(fh.read())
	print("sha256", digest.hexdigest())
