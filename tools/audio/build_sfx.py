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
## Every crowd loop is cut to this integrated loudness; MatchAudio's levels
## then set the mix (see measure_mix.py for what that comes to).
CROWD_LUFS = -16.0

# Freesound CC0 uploads: id -> (uploader, preview url). The HQ preview is the
# 192k Ogg the site streams; the originals need a login and are no better for
# a crowd bed heard under a match.
FREESOUND = {
	"397434": ("FoolBoyMedia", "Crowd Cheer"),
	"829453": ("itmightgetloud", "Stadium Crowd Reaction Excited 01"),
	"264499": ("noah0189", "Crowd Ooohs and Ahhhs in Excitement"),
	"571096": ("TRP", "Boxing bell, various rings dings pulses"),
	"454221": ("kyles", "thud impact wrestling ring heavy wrestler fall on mat"),
	"251759": ("misosound", "BOOMING PUNCHY EXPLOSION - close, big"),
	"336011": ("Rudmer_Rotteveel", "Sharp Explosion 4 (of 5)"),
	"683101": ("florianreichelt", "quick woosh"),
	# Indoor arenas and a real wrestling crowd (the crowd round 2 beds).
	"635492": ("kyles", "crowd int large dense arena stadium hall"),
	"141704": ("felix.blume", "Mexican Lucha Libre: crowd yelling, whistling"),
	"504621": ("NeoSpica", "Booing Crowd"),
	"557189": ("Julien_Matthey", "JM_AMB_INT_Crowd Sport 01 - Booing"),
	"480725": ("craigsmith", "R08-24-Large Crowd Screaming and Whistling"),
	"764273": ("ShangusBurger", "CRWDCheer_Cheering, Whistling, No Clapping"),
	"424793": ("johnnyguitar01", "crowd clap rhythmic"),
	# Round 3 (the owner, 19 Oct: every hit as real as it can be, and the men
	# heard): two layers to a body shot, the ring, the weapons by what they are,
	# and the voices. Picked by measurement (attack, centroid, low-end share).
	"853588": ("Wigglesworth", "Punches/hits"),
	"478155": ("bspiller5", "BPS-BOXING-PUNCHES-Realistic-Various Body Hits"),
	"460509": ("florianreichelt", "Hitting in a Face"),
	"444407": ("MootMcnoodles", "Slap"),
	"564230": ("njjjjjjjjjjjjjjjjjjjjjjjj", "Huge Slap in the Face"),
	"128103": ("Project_Trident", "Wooden Floor Body Slams"),
	"125137": ("connersaw8", "Chair Hit 2"),
	"115918": ("issalcake", "Chair Thrown, Crash, bolt fell out after crash"),
	"115923": ("issalcake", "Single Chair hits floor, bounce"),
	"512218": ("Mateusz_Chenc", "Breaking wooden table"),
	"434146": ("NeoSpica", "Table Smash"),
	"115917": ("issalcake", "Weak table crash, break"),
	"114683": ("Qat", "whack02"),
	"44871": ("stomachache", "trashcan"),
	"706979": ("JesterWhoo", "Hitting a brick with a sledgehammer"),
	"372877": ("Hakren", "Iron-Wood Slam"),
	"54850": ("qubodup", "Rubber Metal Wood Impact Collision Bang"),
	"442288": ("rockittt", "male pain sound effects"),
	"218895": ("Halgrimm", "human grunts 3"),
	"556976": ("marc3122", "Male Screams [1]"),
	"325548": ("Archeos", "Man screaming"),
	"166943": ("qubodup", "Moans and screams of agony of military soldiers"),
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


def lufs(x: np.ndarray) -> float:
	"""Integrated loudness (EBU R128 / ITU BS.1770), measured by ffmpeg."""
	import re
	r = subprocess.run(["ffmpeg", "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac",
			str(x.shape[1]), "-i", "-", "-af", "ebur128", "-f", "null", "-"],
			input=np.ascontiguousarray(x, np.float32).tobytes(), capture_output=True).stderr.decode()
	return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])


def lufs_to(x: np.ndarray, target: float, ceiling: float = -1.5) -> np.ndarray:
	"""Gain to an integrated loudness: how loud it sounds, not its RMS -- but
	never past `ceiling` dBFS on its peak (the Vorbis encode adds a little)."""
	gain = (target - lufs(x))
	gain = min(gain, ceiling - 20 * np.log10(float(np.abs(x).max()) + 1e-12))
	return x * 10 ** (gain / 20)


def even_out(x: np.ndarray, window: float = 1.5, most_db: float = 9.0) -> np.ndarray:
	"""Takes a dynamic field recording's long swells and lulls out (a slow
	gain riding the 1.5 s level toward its median) while every yell inside a
	second stays. MatchAudio makes the swells; the bed must not bring its own."""
	hop = int(window * SR / 4)
	n = len(x) // hop
	env = np.sqrt((x[:n * hop].reshape(n, hop, -1) ** 2).mean(axis=(1, 2))) + 1e-9
	k = 4
	env = np.convolve(env, np.ones(k) / k, "same")
	db = 20 * np.log10(env)
	gain = np.clip(np.median(db) - db, -most_db, most_db)
	g = np.interp(np.arange(len(x)), np.arange(n) * hop + hop / 2, 10 ** (gain / 20))
	return (x * g[:, None]).astype(np.float32)


def widen(x: np.ndarray, ms: float = 17.0) -> np.ndarray:
	"""Mono (or narrow) to wide: the right channel a few ms behind the left."""
	m = x.mean(axis=1)
	d = int(ms / 1000 * SR)
	return np.stack([m, np.concatenate([np.zeros(d, np.float32), m[:-d]])], 1)


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


def ff_filter(x: np.ndarray, af: str) -> np.ndarray:
	"""Run `x` through an ffmpeg audio filter chain (e.g. "highpass=f=90")."""
	ch = x.shape[1]
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", str(ch),
			"-i", "-", "-af", af, "-f", "f32le", "-"], input=x.astype(np.float32).tobytes(),
			capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).reshape(-1, ch).copy()


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
	# The crowd, all four layers indoor arena recordings at one loudness, so
	# MatchAudio's levels are the mix (tools/audio/measure_mix.py reads it back).
	# Loop lengths 52 / 41 / 47 s, pairwise co-prime: no two seams ever line up.
	#
	# The hall: a dense indoor crowd. Use it for the bed too, slowed, filtered
	# and smeared into non-verbal room tone. The previous Celtics-game bed had
	# a recognizable "Defense" call in the shipped cut, which does not belong
	# in a wrestling broadcast.
	hall = load(freesound("635492"), 2)[:, ::-1]
	hall_cut = cut(hall, 10.0, 43.0)
	bed = sweeten(hall_cut, speed=43.0 / 54.0, hp=120.0, lp=3600.0)
	save("crowd_bed", lufs_to(loop(bed), CROWD_LUFS))
	# The hall walla stays at its original pace and width above the softer bed.
	save("crowd_walla_a", lufs_to(loop(hall_cut), CROWD_LUFS))
	# The wrestling crowd: lucha libre in Mexico City -- yells, whistles, the
	# odd scream -- with its long swells levelled out. Rides the excitement.
	lucha = load(freesound("141704"), 2)
	save("crowd_walla_b", lufs_to(loop(even_out(cut(lucha, 52.0, 49.0))), CROWD_LUFS))
	# The roar: a sustained full-house cheer, faded up with the excitement
	# CrowdReaction already tracks.
	roar = load(freesound("397434"), 2)
	save("crowd_roar", lufs_to(loop(cut(roar, 0.3, 19.0), 1.5), CROWD_LUFS))
	# Boos for the heel and a cheer for the face: each two indoor recordings
	# laid together so it is a building, not a section.
	boo = load(freesound("504621"), 2)
	boo2 = load(freesound("557189"), 2)
	boos = cut(boo, 2.0, 26.0)
	boos[:len(boo2) - int(0.5 * SR)] += 0.7 * cut(boo2, 0.5, 26.0)[:len(boos)]
	save("crowd_boo", lufs_to(loop(boos, 1.5), CROWD_LUFS))
	cheer = widen(load(freesound("480725"), 2))
	cheer2 = load(freesound("764273"), 2)
	cheers = cut(cheer, 20.0, 23.0)
	cheers[:len(cheer2)] += 0.6 * cheer2[:len(cheers)]
	save("crowd_cheer", lufs_to(loop(cheers, 1.5), CROWD_LUFS))
	# Pops: six separate stadium reactions, each a rise and a long die-away.
	pops = split_on_silence(load(freesound("829453"), 2), -60.0, 3.0)
	for i, p in enumerate(pops[:5]):
		save(f"crowd_pop_{i}", lufs_to(fade(trim_tail(p, -45), 0.01, 0.8), CROWD_LUFS + 2))
	# The longest, loudest one is kept for the finish.
	save("crowd_finish", lufs_to(fade(trim_tail(pops[5], -45), 0.01, 1.5), CROWD_LUFS + 3))
	# Oohs: the near-fall gasp.
	oohs = [p for p in split_on_silence(load(freesound("264499"), 2), -40.0, 1.2)]
	for i, p in enumerate(oohs[:4]):
		save(f"crowd_ooh_{i}", lufs_to(fade(p, 0.02, 0.4), CROWD_LUFS + 1))

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
	# Strikes, two layers to every body shot (the owner, 19 Oct): the hand or
	# boot on skin, close and bright, over the thump of the body under it.
	# Wigglesworth's punches are the hand (300-500 Hz, 2-15 ms attack),
	# bspiller5's boxing body hits the thump (80-150 Hz, under 1 ms), the
	# slaps the skin of a chop. Takes measured, not guessed.
	hand = load(freesound("853588"))
	thump = load(freesound("478155"))
	face = load(freesound("460509"))
	slap = load(freesound("444407"))
	big_slap = load(freesound("564230"))

	def take(x, t, n):
		# Each layer peak-matched before it is mixed, so a gain below is the
		# layer's share of the hit: the thump source peaks 10 dB over the
		# hand's, and unmatched it buried the hand (centroid 75-120 Hz on
		# every punch). onset() can land a hair before zero on a first take.
		return peak_to(cut(x, max(0.0, onset(x, t)), n), 0.0)

	hands = (0.96, 2.05, 3.26, 8.41, 9.57, 10.74, 12.00, 13.17)
	thumps = (0.09, 1.68, 3.43, 4.84, 6.18, 7.69, 9.16, 10.53, 12.32, 14.18)
	# The thump is short -- a body thud is over in a seventh of a second; left
	# at 0.28 s its boom outweighed the hand, which then read as a dull thud.
	# A trace of slap on top is the knuckles on skin.
	skin = ff_filter(take(slap, 0.0, 0.08), "highpass=f=1500")
	for i in range(6):
		h = take(hand, hands[i], 0.32)
		b = fade(take(thump, thumps[i], 0.14), 0.002, 0.08)
		save(f"hit_punch_{i}", peak_to(fade(trim_tail(layer([(0.0, h, 1.0), (0.003, b, 0.2),
				(0.0, skin, 0.15)]), -42)), -3))
	# A kick: the boot's weight -- the thump leads, the face hit on it.
	for i, t in enumerate((0.39, 1.68, 2.97)):
		b = fade(take(thump, thumps[6 + i], 0.18), 0.002, 0.1)
		f = take(face, t, 0.28)
		save(f"hit_kick_{i}", peak_to(fade(trim_tail(layer([(0.0, b, 0.6), (0.002, f, 1.0)]), -42)), -2))
	# A chop: the open hand across the chest, the slap on top.
	for i, (sk, hk) in enumerate(((slap, 3), (big_slap, 4), (slap, 5))):
		st = 0.0 if sk is slap else 0.22
		sl = take(sk, st, 0.25)
		h = take(hand, hands[hk], 0.25)
		save(f"hit_chop_{i}", peak_to(fade(trim_tail(layer([(0.0, sl, 1.0), (0.004, h, 0.35)]), -42)), -2))
	# A forearm or an elbow: the heavier hand takes and a full thump.
	for i in range(3):
		h = take(hand, hands[5 + i], 0.32)
		b = fade(take(thump, thumps[7 + i], 0.16), 0.002, 0.09)
		save(f"hit_forearm_{i}", peak_to(fade(trim_tail(layer([(0.0, h, 1.0), (0.002, b, 0.3)]), -42)), -2))
	# Bumps: a wrestler landing flat on a ring -- canvas over boards, the
	# thud and the breath knocked out of him.
	mat = load(freesound("454221"))
	for i, t in enumerate((0.0, 5.66, 12.17, 18.96, 25.09, 31.86)):
		save(f"bump_{i}", peak_to(fade(trim_tail(cut(mat, onset(mat, t), 1.6), -38), 0.002, 0.15), -1))
	# The referee's hand on the mat, one per count.
	for i in range(3):
		k = load(kenney("impact", f"impactSoft_heavy_00{i}"))
		save(f"count_slap_{i}", peak_to(fade(trim_tail(k, -40)), -2))

	# Weapons: Kenney's metal, wood and glass hits, each over a body punch --
	# a chair shot is the clang and the man under it.
	body = [load(kenney("impact", f"impactPunch_heavy_00{i}")) for i in range(3)]
	for fam, src in (("hit_metal", "impactMetal_heavy"), ("hit_wood", "impactWood_heavy"),
			("hit_glass", "impactGlass_heavy")):
		for i in range(3):
			k = load(kenney("impact", f"{src}_00{i}"))
			save(f"{fam}_{i}", peak_to(fade(trim_tail(layer([(0.0, k, 1.0), (0.004, body[i], 0.55)]), -42)), -2))
	# More of the ring: a man landing on boards, Project_Trident's wooden-floor
	# body slams (300-500 Hz, the deck's boom).
	slams = load(freesound("128103"))
	for i, t in enumerate((0.42, 4.38, 9.99, 18.82, 21.19, 27.80)):
		save(f"bump_{6 + i}", peak_to(fade(trim_tail(take(slams, t, 1.2), -38), 0.002, 0.15), -1))

	print("weapons by what they are")
	# A chair shot: the hollow clang and the man under it.
	for i, (sid, t, n) in enumerate((("125137", 0.0, 0.5), ("115918", 3.25, 0.9), ("115923", 3.25, 0.9))):
		c = take(load(freesound(sid)), t, n)
		b = take(thump, thumps[i], 0.3)
		save(f"hit_chair_{i}", peak_to(fade(trim_tail(layer([(0.0, c, 1.0), (0.003, b, 0.45)]), -42)), -2))
	# A kendo stick: a sharp crack across the back.
	whack = load(freesound("114683"))
	for i, (gain, sk) in enumerate(((0.35, slap), (0.5, big_slap))):
		w = take(whack, 0.07, 0.36)
		sl = take(sk, 0.0 if sk is slap else 0.22, 0.2)
		save(f"hit_kendo_{i}", peak_to(fade(trim_tail(layer([(0.0, w, 1.0), (0.002, sl, gain)]), -42)), -2))
	# A trash can: tin, and the body under it.
	can = take(load(freesound("44871")), 0.0, 1.2)
	save("hit_can_0", peak_to(fade(trim_tail(layer([(0.0, can, 1.0), (0.004, take(thump, thumps[3], 0.3), 0.5)]),
			-42)), -2))
	# A sledgehammer: a dead, heavy hit.
	sledge = load(freesound("706979"))
	for i, t in enumerate((0.99, 3.06, 5.05)):
		save(f"hit_sledge_{i}", peak_to(fade(trim_tail(layer([(0.0, take(sledge, t, 0.25), 1.0),
				(0.002, fade(take(thump, thumps[4 + i], 0.2), 0.002, 0.1), 0.45)]), -42)), -2))
	# A ladder: aluminium and the slam of it.
	slam = take(load(freesound("372877")), 0.05, 1.0)
	bang = load(freesound("54850"))
	for i, t in enumerate((0.18, 1.49)):
		save(f"hit_ladder_{i}", peak_to(fade(trim_tail(layer([(0.0, take(bang, t, 0.3), 1.0),
				(0.01, slam, 0.8)]), -42)), -2))
	# A table going: the boards cracking and splintering, the man on the boards.
	# 115917's splinter swells in over 25 ms, so the sharp 512218 crack goes
	# first and the splinter rides on it.
	snap = take(load(freesound("512218")), 0.02, 0.6)
	for i, (sid, t, n) in enumerate((("512218", 0.02, 0.6), ("434146", 0.0, 0.6), ("115917", 1.82, 0.9))):
		crack = take(load(freesound(sid)), t, n)
		body = take(slams, (0.42, 9.99, 21.19)[i], 1.0)
		lead = [(0.0, snap, 0.8)] if sid == "115917" else []
		save(f"table_crack_{i}", peak_to(fade(trim_tail(layer(lead + [(0.012 if lead else 0.0, crack, 1.0),
				(0.02, body, 0.5)]), -40), 0.002, 0.15), -1))
	# The announce desk: heavier -- the top giving, the monitors, the glass.
	desk_top = take(load(freesound("115917")), 1.82, 0.9)
	glass = load(kenney("impact", "impactGlass_heavy_000"))
	save("desk_crash_0", peak_to(fade(trim_tail(layer([(0.0, snap, 0.9), (0.012, desk_top, 1.0),
			(0.01, take(bang, 4.34, 0.3), 0.8),
			(0.05, peak_to(glass, 0.0), 0.5), (0.02, take(slams, 18.82, 1.1), 0.55)]), -40), 0.002, 0.2), -1))

	print("voices")
	# The men heard (the owner, 19 Oct): a grunt on a blow, a groan when it
	# hurts, a yell for the worst of it, and a burning man screaming until he
	# is put out. All CC0 performers; no wrestler's or commentator's voice.
	pain = load(freesound("442288"))
	grunts = ff_filter(load(freesound("218895")), "highpass=f=90")
	screams = load(freesound("556976"))
	for i, (t, n) in enumerate(((0.16, 0.26), (3.43, 0.25), (6.42, 0.27), (1.37, 0.33))):
		save(f"grunt_light_{i}", peak_to(fade(trim_tail(take(pain, t, n), -42)), -4))
	for i, (t, n) in enumerate(((1.22, 0.63), (2.64, 0.43), (5.79, 0.42), (9.75, 0.56))):
		save(f"grunt_heavy_{i}", peak_to(fade(trim_tail(take(grunts, t, n), -42)), -3))
	for i, (t, n) in enumerate(((1.97, 0.56), (4.53, 0.63), (5.35, 0.74), (6.81, 0.65))):
		save(f"groan_{i}", peak_to(fade(trim_tail(take(pain, t, n), -42), 0.004, 0.12), -3))
	for i, (t, n) in enumerate(((7.93, 0.5), (9.51, 0.55), (10.96, 0.59), (12.54, 0.53))):
		save(f"yell_{i}", peak_to(fade(trim_tail(take(screams, t, n), -42), 0.004, 0.12), -2))
	burn = [(screams, 0.62, 2.4), (screams, 4.04, 2.3)]
	archeos = load(freesound("325548"))
	burn += [(archeos, 1.07, 1.9), (archeos, 4.65, 2.2), (archeos, 19.17, 2.6)]
	agony = load(freesound("166943"))
	burn += [(agony, 0.0, 4.7)]
	for i, (src, t, n) in enumerate(burn):
		save(f"burn_scream_{i}", peak_to(fade(trim_tail(take(src, t, n), -42), 0.01, 0.25), -2))

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
