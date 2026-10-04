#!/usr/bin/env python3
"""Builds the game's sound effects in game/assets/audio/ from CC0 sources.

    python3 tools/audio/build_sfx.py

Every source is CC0 (public domain): Freesound uploads marked Creative Commons
0 and Kenney's Impact and Interface packs. They are downloaded into a cache
(~/.cache/aegis_audio, not the repo), then cut, trimmed, loudness-matched and
(for the crowd beds) made to loop without a seam. The cuts are written down
here -- which recording, which second -- so the output is reviewable and the
same table always builds the same files. game/assets/audio/CREDITS.md lists
every source.

Needs ffmpeg and numpy. The game does not need this script: the .ogg files it
writes are committed.
"""
import hashlib
import io
import os
import subprocess
import sys
import urllib.request
import zipfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "audio")
CACHE = os.path.expanduser("~/.cache/aegis_audio")
SR = 44100

# Freesound CC0 uploads: id -> (uploader, preview url). The HQ preview is the
# 192k Ogg the site streams; the originals need a login and are no better for
# a crowd bed heard under a match.
FREESOUND = {
	"706497": ("SEF7", "Rogers Arena - NHL game atmosphere"),
	"397434": ("FoolBoyMedia", "Crowd Cheer"),
	"829453": ("itmightgetloud", "Stadium Crowd Reaction Excited 01"),
	"264499": ("noah0189", "Crowd Ooohs and Ahhhs in Excitement"),
	"571096": ("TRP", "Boxing bell, various rings dings pulses"),
	"454221": ("kyles", "thud impact wrestling ring heavy wrestler fall on mat"),
	"208791": ("uEffects", "Punch Sounds"),
	"251759": ("misosound", "BOOMING PUNCHY EXPLOSION - close, big"),
	"336011": ("Rudmer_Rotteveel", "Sharp Explosion 4 (of 5)"),
	"683101": ("florianreichelt", "quick woosh"),
}
# archive.org CC0 field recordings (Red Library crowds): file -> description.
# The item's licenseurl is checked at download time.
ARCHIVE_ITEM = "Red_Library_Crowds_Outdoor"
ARCHIVE = {
	"R08-05-Large Group at Event": "walla",
	"R28-29-Large Crowd Quiet, Then Big Reaction": "walla, then a reaction",
	"R08-09-Large Unhappy Crowd": "boos",
	"R25-22-Large Excited Crowd": "cheering",
}
KENNEY = {
	"impact": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
	"interface": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
}


# --- fetching ---------------------------------------------------------------

def _get(url: str) -> bytes:
	req = urllib.request.Request(url, headers={"User-Agent": "aegis-build-sfx"})
	with urllib.request.urlopen(req, timeout=120) as r:
		return r.read()


def freesound(sid: str) -> str:
	path = os.path.join(CACHE, "freesound", sid + ".ogg")
	if os.path.exists(path):
		return path
	os.makedirs(os.path.dirname(path), exist_ok=True)
	user = FREESOUND[sid][0]
	page = _get(f"https://freesound.org/people/{user}/sounds/{sid}/").decode("utf8", "replace")
	import re
	m = re.search(r"https://cdn\.freesound\.org/previews/\d+/" + sid + r"_\d+-(?:hq|lq)\.(?:ogg|mp3)", page)
	if not m:
		sys.exit(f"no preview found for freesound {sid}")
	url = m.group(0).replace("-lq.", "-hq.").replace(".mp3", ".ogg")
	if "Creative Commons 0" not in page and "publicdomain/zero" not in page:
		sys.exit(f"freesound {sid} is no longer marked CC0 -- check before using it")
	with open(path, "wb") as f:
		f.write(_get(url))
	return path


def archive(name: str) -> str:
	"""A recording from the CC0 Red Library item on archive.org, cached."""
	import json
	import urllib.parse
	path = os.path.join(CACHE, "archive", name.replace(" ", "_").replace(",", "") + ".mp3")
	if os.path.exists(path):
		return path
	os.makedirs(os.path.dirname(path), exist_ok=True)
	meta = json.loads(_get(f"https://archive.org/metadata/{ARCHIVE_ITEM}"))
	if "publicdomain/zero" not in meta.get("metadata", {}).get("licenseurl", ""):
		sys.exit(f"archive.org {ARCHIVE_ITEM} is no longer marked CC0 -- check before using it")
	url = f"https://archive.org/download/{ARCHIVE_ITEM}/" + urllib.parse.quote(name + ".mp3")
	with open(path, "wb") as f:
		f.write(_get(url))
	return path


def kenney(pack: str, name: str) -> str:
	folder = os.path.join(CACHE, "kenney_" + pack)
	if not os.path.isdir(folder):
		os.makedirs(folder, exist_ok=True)
		zipfile.ZipFile(io.BytesIO(_get(KENNEY[pack]))).extractall(folder)
	return os.path.join(folder, "Audio", name + ".ogg")


# --- audio helpers ----------------------------------------------------------

def load(path: str, channels: int = 1) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le",
			"-ac", str(channels), "-ar", str(SR), "-"], capture_output=True, check=True).stdout
	x = np.frombuffer(raw, np.float32).copy()
	return x.reshape(-1, channels)


def save(name: str, x: np.ndarray) -> None:
	x = np.clip(x, -1.0, 1.0).astype(np.float32)
	path = os.path.join(OUT, name + ".ogg")
	# Bit-exact across runs: libvorbis at a fixed quality with no metadata
	# (ffmpeg's encoder tag would otherwise change with the ffmpeg version).
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR),
			"-ac", str(x.shape[1]), "-i", "-", "-c:a", "libvorbis", "-q:a", "5",
			"-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", path],
			input=x.tobytes(), check=True)
	print(f"  {name}.ogg  {len(x) / SR:5.2f}s  {x.shape[1]}ch")


def cut(x: np.ndarray, start: float, length: float) -> np.ndarray:
	a = int(start * SR)
	return x[a:a + int(length * SR)].copy()


def fade(x: np.ndarray, fade_in: float = 0.004, fade_out: float = 0.05) -> np.ndarray:
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


def rms_to(x: np.ndarray, db: float) -> np.ndarray:
	r = float(np.sqrt((x ** 2).mean()))
	return x * (10 ** (db / 20) / r) if r > 0 else x


def trim_tail(x: np.ndarray, below_db: float = -50.0) -> np.ndarray:
	"""Drops the silence after the sound, relative to its own peak."""
	env = np.abs(x).max(axis=1)
	loud = np.nonzero(env > float(env.max()) * 10 ** (below_db / 20))[0]
	return x[:loud[-1] + 1] if len(loud) else x


def onset(x: np.ndarray, near: float, window: float = 0.3) -> float:
	"""The attack nearest `near` seconds: where the level first jumps."""
	a, b = max(0, int((near - window) * SR)), int((near + window) * SR)
	env = np.abs(x[a:b]).max(axis=1)
	hit = np.nonzero(env > float(env.max()) * 0.25)[0]
	return (a + int(hit[0])) / SR - 0.005 if len(hit) else near


def loop(x: np.ndarray, cross: float = 2.0) -> np.ndarray:
	"""Folds the last `cross` seconds over the first, equal-power, so the clip
	loops with no seam: the end runs straight back into the start."""
	f = int(cross * SR)
	head, tail = x[:f], x[len(x) - f:]
	t = np.linspace(0.0, np.pi / 2, f)[:, None]
	body = x[:len(x) - f].copy()
	body[:f] = head * np.sin(t) + tail * np.cos(t)
	return body


def sweeten(x: np.ndarray, speed: float, hp: float = 160.0, lp: float = 4800.0) -> np.ndarray:
	"""Makes a field recording a wash of voices rather than anyone's words:
	resampled by `speed` (so any speech is slurred and every layer is a
	different pitch), band-limited, then smeared by a short diffuse tail."""
	n = int(len(x) / speed)
	idx = np.linspace(0, len(x) - 1, n)
	y = np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], 1)
	spec = np.fft.rfft(y, axis=0)
	freq = np.fft.rfftfreq(len(y), 1.0 / SR)
	gain = np.clip((freq - hp * 0.6) / (hp * 0.4), 0.0, 1.0) * \
			np.clip((lp * 1.3 - freq) / (lp * 0.3), 0.0, 1.0)
	y = np.fft.irfft(spec * gain[:, None], n=len(y), axis=0).astype(np.float32)
	out = y.copy()
	for ms, g in ((23, 0.5), (41, 0.4), (67, 0.3), (97, 0.22), (131, 0.15)):
		d = int(ms / 1000 * SR)
		out[d:] += y[:-d] * g
	return out


def split_on_silence(x: np.ndarray, floor_db: float, min_len: float = 0.6) -> list:
	hop = SR // 100
	n = len(x) // hop
	env = np.sqrt((x[:n * hop, 0].reshape(n, hop) ** 2).mean(1)) + 1e-12
	on = 20 * np.log10(env) > floor_db
	parts, start = [], None
	for i, v in enumerate(list(on) + [False]):
		if v and start is None:
			start = i
		elif not v and start is not None:
			if (i - start) * hop >= min_len * SR:
				parts.append(x[start * hop:i * hop].copy())
			start = None
	return parts


def layer(parts: list) -> np.ndarray:
	"""[(seconds, clip, gain)] mixed onto one timeline."""
	end = max(int(t * SR) + len(c) for t, c, _ in parts)
	out = np.zeros((end, parts[0][1].shape[1]), np.float32)
	for t, c, g in parts:
		a = int(t * SR)
		out[a:a + len(c)] += c * g
	return out


# --- the table --------------------------------------------------------------

def build() -> None:
	os.makedirs(OUT, exist_ok=True)
	print("crowd")
	# The bed: an NHL arena between plays -- a big room full of people, no
	# PA, no organ. Under everything, all night.
	bed = load(freesound("706497"), 2)
	save("crowd_bed", rms_to(loop(cut(bed, 0.5, 54.0)), -20))
	# The roar: a sustained full-house cheer, faded up with the excitement
	# CrowdReaction already tracks.
	roar = load(freesound("397434"), 2)
	save("crowd_roar", rms_to(loop(cut(roar, 0.3, 19.0), 1.5), -18))
	# Pops: six separate stadium reactions, each a rise and a long die-away.
	pops = split_on_silence(load(freesound("829453"), 2), -60.0, 3.0)
	for i, p in enumerate(pops[:5]):
		save(f"crowd_pop_{i}", rms_to(fade(trim_tail(p, -45), 0.01, 0.8), -17))
	# The longest, loudest one is kept for the finish.
	save("crowd_finish", rms_to(fade(trim_tail(pops[5], -45), 0.01, 1.5), -15))
	# Oohs: the near-fall gasp.
	oohs = [p for p in split_on_silence(load(freesound("264499"), 2), -40.0, 1.2)]
	for i, p in enumerate(oohs[:4]):
		save(f"crowd_ooh_{i}", rms_to(fade(p, 0.02, 0.4), -18))

	# Out-of-sync beds, so no loop point is ever heard: with the 52 s bed above
	# these run 52 / 23 / 41 s (pairwise co-prime; the cuts are sized so each loop
	# comes out at exactly that length, the crossfade seam included), slurred and
	# band-limited so no word in them is intelligible. MatchAudio rides them.
	walla = load(archive("R08-05-Large Group at Event"), 2)
	save("crowd_walla_a", rms_to(loop(sweeten(cut(walla, 4.0, 28.0), 1.12), 2.0), -21))
	rec = load(archive("R28-29-Large Crowd Quiet, Then Big Reaction"), 2)
	save("crowd_walla_b", rms_to(loop(sweeten(cut(rec, 1.0, 40.42), 0.94), 2.0), -21))
	# Boos for the heel and a cheer swell for the face, each a held layer.
	boo = load(archive("R08-09-Large Unhappy Crowd"), 2)
	save("crowd_boo", rms_to(loop(sweeten(cut(boo, 0.3, 24.0), 1.0, 120.0, 3600.0), 1.5), -17))
	cheer = load(archive("R25-22-Large Excited Crowd"), 2)
	save("crowd_cheer", rms_to(loop(sweeten(cut(cheer, 0.2, 21.5), 1.0, 160.0, 6500.0), 1.5), -17))

	print("bell")
	bell = load(freesound("571096"))
	ding = fade(trim_tail(cut(bell, onset(bell, 1.66), 8.5), -45), 0.002, 1.0)
	ding = peak_to(ding, -1.0)
	save("bell_ding", ding)
	# Timekeeper's rings: the opening bell a quick three, the finish a
	# longer run, each hit on the still-ringing last.
	save("bell_start", peak_to(layer([(t, ding, 1.0) for t in (0.0, 0.42, 0.84)]), -1.0))
	save("bell_end", peak_to(layer([(i * 0.36, ding, 1.0 - 0.04 * i) for i in range(8)]), -1.0))

	print("impacts")
	# Strikes: close punches, plus Kenney's heavier body punches.
	punch = load(freesound("208791"))
	for i, t in enumerate((0.37, 1.66, 2.71, 3.43, 4.00, 5.48)):
		save(f"hit_punch_{i}", peak_to(fade(trim_tail(cut(punch, onset(punch, t), 0.45), -40)), -3))
	for i in range(3):
		k = load(kenney("impact", f"impactPunch_heavy_00{i}"))
		save(f"hit_kick_{i}", peak_to(fade(trim_tail(k, -40)), -2))
	# Bumps: a wrestler landing flat on a ring -- canvas over boards, the
	# thud and the breath knocked out of him.
	mat = load(freesound("454221"))
	for i, t in enumerate((0.0, 5.66, 12.17, 18.96, 25.09, 31.86)):
		save(f"bump_{i}", peak_to(fade(trim_tail(cut(mat, onset(mat, t), 1.6), -38), 0.002, 0.15), -1))
	# The referee's hand on the mat, one per count.
	for i in range(3):
		k = load(kenney("impact", f"impactSoft_heavy_00{i}"))
		save(f"count_slap_{i}", peak_to(fade(trim_tail(k, -40)), -2))

	print("pyro")
	save("pyro_boom", peak_to(fade(trim_tail(load(freesound("251759"), 2), -50), 0.001, 0.4), -1))
	save("pyro_bang", peak_to(fade(trim_tail(load(freesound("336011"), 2), -50), 0.001, 0.2), -1))
	save("whoosh", peak_to(fade(trim_tail(load(freesound("683101"), 2), -45), 0.002, 0.1), -3))

	print("menu")
	for name, src in (("ui_move", "select_002"), ("ui_select", "confirmation_002"),
			("ui_back", "back_002")):
		save(name, peak_to(fade(trim_tail(load(kenney("interface", src)), -45)), -4))


if __name__ == "__main__":
	build()
	digest = hashlib.sha256()
	for f in sorted(os.listdir(OUT)):
		if f.endswith(".ogg"):
			with open(os.path.join(OUT, f), "rb") as fh:
				digest.update(fh.read())
	print("sha256", digest.hexdigest())
