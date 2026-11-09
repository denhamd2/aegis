#!/usr/bin/env python3
"""Sound round 4: the sounds the sound judge cleared, built into
game/assets/audio/ from CC0 recordings.

    python3 tools/audio/build_sfx_round4.py            # every slot
    python3 tools/audio/build_sfx_round4.py bump glass # only these slots
    python3 tools/audio/build_sfx_round4.py --fetch    # download the sources

Nothing is synthesised: every sound is a cut or a layer of a real recording,
with trim, peak alignment, filters, a downward gate on room noise, fades, a
look-ahead limiter where the judge asked for one, and a loudness match. The
table of cuts is this file, and the same table always builds the same bytes
(Vorbis q5, bit-exact flags).

Sources, all CC0 and checked at download (the licence text on the page, or
the archive.org item's licenseurl), then pinned by sha256 below:

- BigSoundBank (Joseph SARDIN; "Boxing training" by Dorian CLAIR)
- Red Library on archive.org (the USC sound-effect archive: 1930s-40s
  Hollywood optical effects, USC Cinema / Sunset Editorial; band-limited)
- rubberduck's "25 CC0 bang / firework sfx" on OpenGameArt

They are cached in ~/.cache/aegis_audio/round4, not in the repo. A few slots
re-cut files that are already committed (their Freesound sources answer 403
from here); those read the file as it was at BASE, so a second run does not
add another Vorbis generation.

build_sfx.py is not re-run by this and must not be: it would overwrite these
slots with the round-3 files. game/assets/audio/CREDITS.md lists every source.

Needs ffmpeg and numpy. The game does not need this script.
"""
import hashlib
import json
import os
import re
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "audio")
CACHE = os.path.expanduser("~/.cache/aegis_audio/round4")
SR = 44100
## The commit whose audio the re-cut slots start from.
BASE = "e105d2b2"
## No take peaks above this (dBFS, before the encode).
CEILING = -1.5
IA = "ia/"
B = "bsb/"
RD = "oga/rubberduck/x/"

SHA256 = {
	"bsb/bsb_0387.wav": "54567de24967f81ba5131b0997190468865353d0e0d36b519d40b1f44f6f2673",
	"bsb/bsb_1084.wav": "635f9f57e8224e937863d04fff586003b61e05b2b76d577ec48c355784bd189f",
	"bsb/bsb_1341.wav": "828c16943d1bd1c2990c1cb56867b501ef650fda281f67d9da086b502e0a788f",
	"bsb/bsb_1342.wav": "bcef98d7a9f5f8baa0b10fc25adf7d72c0cde3001934333ee09b980b53d96758",
	"bsb/bsb_2039.wav": "29766911789b59660aa5cc034f1f4ed287bf36f30f1a812b4bf5b06820a2fc85",
	"bsb/bsb_2043.wav": "f820e0bc16168069a5114cda86c484405dad2d01b05120da1bf9ea9995f73de0",
	"bsb/bsb_2045.wav": "7fbafdc870c4cd061f02d067c482c02f6c77db2cd6a3c6061662ecefae348c62",
	"bsb/bsb_2445.wav": "86be2727c54b35cea22abbf40640eca3c5a6209efaa368bebcae7c3539b3d0a7",
	"bsb/bsb_2452.wav": "4770f7b32fcab7437c5b1ce79b80df592f3ff76885c49c62fb367d74a4f3430c",
	"bsb/bsb_2453.wav": "852d68dbf84df1399182dbb938594203a80eea24a681ac4ffe473dc0dca3b3ad",
	"bsb/bsb_2454.wav": "5fb4940962fcfd5f00c516c204f46036ae8046ddb201a2913e1eac557d8c2a08",
	"bsb/bsb_2455.wav": "a3ae2782efe4668afeaa3597afecc6d60df7ad5baa5c0e2ef46ae6dc1e8f8f67",
	"bsb/bsb_2456.wav": "e5935eea0693dcc41bf749fd0f51d3049e9e1e37e9f10d4de65b85baea20172b",
	"ia/Red_Library_Crashes/R28-13-Glass_Windows_Smashed.wav": "57a22dc6b37f0f644b04cbe29a7cc3ed9a0cb288304a174ac5c4e62dbab3113a",
	"ia/Red_Library_Crowds_Indoor_2/R07-20-Chorus_of_Boos.wav": "1dbc0c60b70dac6f418f8110ceaa8cf55ddcf92c8b47f6f443521ade4c1376d8",
	"ia/Red_Library_Crowds_Men/R08-34-Men_Booing.wav": "abe39132063cfbe678edc42a6a6d83f231c203447a0cea80af93392c3880923c",
	"ia/Red_Library_Fights/R15-12-Loud_Slaps_or_Whacks.wav": "775f7b9ea4b36747c75949165afa58c9b321568f17db22751913993d166572b0",
	"ia/Red_Library_Fire/R27-25-Large_Fire_Burning.wav": "0f49758f3bbeed6be71c7241b354c81d713331c497a7abdd87a9bd30011f6a5f",
	"ia/Red_Library_Fire/R28-08-Torch_or_Molotov_Cocktail.wav": "c1fa755ba174d003ae5694aeedb2f60ad558c7d0020f7aa41160b9b36007bd23",
	"ia/Red_Library_Impacts/R28-55-Thumps_on_Large_Hollow_Wooden_Surface.wav": "5e2e34c1e69af985cd3e4518b714a1ac37cb88208a76103dbd996161f00228f1",
	"ia/Red_Library_Metal/R15-07-Metal_Clangs_and_Hollow_Hits.wav": "5b4898c9c762e55dbba0b9134eecb83d948287b65c53e562b57ba31bc2565b9e",
	"ia/Red_Library_Metal/R16-34-Banging_Metal_Pipe.wav": "30b9ef9c8d11abfe79301114a8c2c67d18256dd73ce3233b87ac57bcb5cfe119",
	"ia/Red_Library_Metal/R16-31-Metal_Clank_and_Ring.wav": "08043c46c7cd620f4f578e77b9db23782c20ddac959daad15b3815232d3b0203",
	"ia/Red_Library_Voices_Men_1/R15-31-Man_Growling_and_Grunting.wav": "46f9c39d00f6bd50dd76723e7e9782e72499276c423fc7a8b1b190ed067ddd12",
	"ia/Red_Library_Voices_Men_1/R15-33-Man_Out_of_Breath.wav": "30db51fd46456181891d00e07fa37b8b340657e073b567e27732dfc59d068376",
	"ia/Red_Library_Voices_Men_1/R21-08-Man_Moans.wav": "0fac45f0a4a8d7fd6408e1b6a957d94890859160dc61a692516b823502414832",
	"ia/Red_Library_Voices_Men_1/R21-14-Man_Grunts_and_Struggles.wav": "0770b1ef52d6786037c0ccee8e3fb5d010141896d9827dfe9d4486555b8ef086",
	"oga/rubberduck/src.zip": "c0c9ecc11e2dc0d190f0cced755569858234b8528286bc83becb6314c663407f",
}

# BigSoundBank id -> page slug
BSB_PAGES = {"2452": "body-fall-1", "2453": "body-fall-2", "2454": "body-fall-3", "2455": "body-fall-4",
		"2456": "body-fall-5", "2445": "boxing-training", "1084": "shot-shovel",
		"2039": "bulb-bursting-1", "2043": "bulb-bursting-5", "2045": "bulb-bursting-7",
		"0387": "mirror-explodes", "1341": "gasoline-fire-2", "1342": "gasoline-fire-3"}
# archive.org Red Library item -> recordings (the WAV originals)
IA_ITEMS = {
	"Red_Library_Impacts": ["R28-55-Thumps on Large Hollow Wooden Surface"],
	"Red_Library_Fights": ["R15-12-Loud Slaps or Whacks"],
	"Red_Library_Voices_Men_1": ["R21-08-Man Moans", "R15-31-Man Growling and Grunting",
			"R21-14-Man Grunts and Struggles", "R15-33-Man Out of Breath"],
	"Red_Library_Metal": ["R15-07-Metal Clangs and Hollow Hits", "R16-31-Metal Clank and Ring",
			"R16-34-Banging Metal Pipe"],
	"Red_Library_Crashes": ["R28-13-Glass Windows Smashed"],
	"Red_Library_Fire": ["R28-08-Torch or Molotov Cocktail", "R27-25-Large Fire Burning"],
	"Red_Library_Crowds_Men": ["R08-34-Men Booing"],
	"Red_Library_Crowds_Indoor_2": ["R07-20-Chorus of Boos"],
}
OGA = {"rubberduck": ("https://opengameart.org/content/25-cc0-bang-firework-sfx",
		"https://opengameart.org/sites/default/files/25-CC0-bang-sfx.zip")}


# ---- fetch -----------------------------------------------------------------
def _get(url):
	# An honest client name. BigSoundBank has answered 403 to scripted clients;
	# if it does, download the WAV from the sound's page by hand into the cache
	# (the sha256 table below still checks it).
	ctx = ssl.create_default_context(cafile=os.environ.get("SSL_CERT_FILE") or None)
	req = urllib.request.Request(url, headers={"User-Agent": "audio-build-script/1.0"})
	with urllib.request.urlopen(req, timeout=300, context=ctx) as r:
		return r.read()


def fetch():
	"""Download what is missing, refusing anything whose page does not say CC0."""
	for sid, slug in BSB_PAGES.items():
		page = _get(f"https://bigsoundbank.com/{slug}-s{sid}.html").decode("utf8", "replace")
		if "License CC0" not in re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", page)):
			sys.exit(f"bigsoundbank {sid}: the page no longer says CC0")
		p = os.path.join(CACHE, B, f"bsb_{sid}.wav")
		os.makedirs(os.path.dirname(p), exist_ok=True)
		if not os.path.exists(p):
			open(p, "wb").write(_get(f"https://bigsoundbank.com/UPLOAD/bwf-en/{sid}.wav"))
	for item, names in IA_ITEMS.items():
		lic = json.loads(_get("https://archive.org/metadata/" + item))["metadata"].get("licenseurl", "")
		if "publicdomain/zero" not in lic:
			sys.exit(f"archive.org {item}: licence is {lic!r}, not CC0")
		os.makedirs(os.path.join(CACHE, IA, item), exist_ok=True)
		for n in names:
			p = os.path.join(CACHE, IA, item, re.sub(r"[^A-Za-z0-9._-]", "_", n) + ".wav")
			if not os.path.exists(p):
				open(p, "wb").write(_get(f"https://archive.org/download/{item}/" + urllib.parse.quote(n + ".wav")))
	for who, (page_url, zurl) in OGA.items():
		page = _get(page_url).decode("utf8", "replace")
		i = page.find("License(s):")
		lic = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", page[i:i + 1500]).replace("&nbsp;", " "))
		if not lic.replace("License(s):", "").strip().startswith("CC0"):
			sys.exit(f"opengameart {who}: the page no longer says CC0")
		d = os.path.join(CACHE, "oga", who)
		os.makedirs(d, exist_ok=True)
		if not os.path.exists(d + "/src.zip"):
			open(d + "/src.zip", "wb").write(_get(zurl))
		z = zipfile.ZipFile(d + "/src.zip")
		for m in z.namelist():
			if ".." in m or m.startswith("/"):
				sys.exit("unsafe zip member " + m)
		z.extractall(d + "/x")


_checked = set()


def src_path(rel):
	"""A cached source, after its sha256 has been checked against the table."""
	pin = "oga/rubberduck/src.zip" if rel.startswith(RD) else rel
	p = os.path.join(CACHE, pin)
	if pin not in _checked:
		if not os.path.exists(p):
			sys.exit(f"missing source {pin}: run with --fetch")
		if hashlib.sha256(open(p, "rb").read()).hexdigest() != SHA256[pin]:
			sys.exit(f"{pin}: sha256 does not match the pinned source")
		_checked.add(pin)
	return os.path.join(CACHE, rel)


# ---- io --------------------------------------------------------------------
def _decode(args, data=None, ch=1):
	raw = subprocess.run(["ffmpeg", "-v", "error"] + args + ["-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-"],
			input=data, capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).reshape(-1, ch).copy()


def load(rel, ch=1):
	return _decode(["-i", src_path(rel)], None, ch)


def _channels(args, data=None):
	out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels", "-of", "csv=p=0"] + args,
			input=data, capture_output=True).stdout.decode()
	return int(out.strip().split("\n")[0])


def load_native(rel):
	"""Keep the channels as they are (no ffmpeg up/down-mix gain)."""
	p = src_path(rel)
	return _decode(["-i", p], None, _channels([p]))


def repo(name):
	"""A committed sound as it was at BASE, before this round touched it."""
	data = subprocess.run(["git", "-C", ROOT, "show", f"{BASE}:game/assets/audio/{name}.ogg"],
			capture_output=True, check=True).stdout
	return _decode(["-i", "pipe:0"], data, _channels(["-i", "pipe:0"], data))


def save(name, x):
	x = np.clip(x, -1, 1).astype(np.float32)
	p = os.path.join(OUT, name + ".ogg")
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]),
			"-i", "-", "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1", "-fflags", "+bitexact",
			"-flags:a", "+bitexact", p], input=x.tobytes(), check=True)
	_import_file(name)
	print("  wrote", name)


def _import_file(name):
	"""A new sound's Godot .import, so the game finds it without the editor
	being opened first (SfxPool asks ResourceLoader). The uid comes from the
	name, so it is the same on every build; an existing .import is left alone."""
	p = os.path.join(OUT, name + ".ogg.import")
	if os.path.exists(p):
		return
	res = f"res://assets/audio/{name}.ogg"
	n = int.from_bytes(hashlib.sha256(res.encode()).digest()[:8], "big") >> 1
	uid = ""
	while n:
		uid = "abcdefghijklmnopqrstuvwxy012345678"[n % 34] + uid
		n //= 34
	dest = f"res://.godot/imported/{name}.ogg-{hashlib.md5(res.encode()).hexdigest()}.oggvorbisstr"
	open(p, "w").write(f"""[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"
uid="uid://{uid}"
path="{dest}"

[deps]

source_file="{res}"
dest_files=["{dest}"]

[params]

loop=false
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
""")


def ff(x, af):
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]),
			"-i", "-", "-af", af, "-f", "f32le", "-"], input=x.astype(np.float32).tobytes(),
			capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).reshape(-1, x.shape[1]).copy()

# ---- shaping ---------------------------------------------------------------
def cut(x, start, length):
	a = int(round(start * SR))
	return x[a:a + int(round(length * SR))].copy()


def peak_to(x, db):
	p = float(np.abs(x).max())
	return x * (10 ** (db / 20) / p) if p > 0 else x


def env_db(x, ms=10):
	h = int(ms / 1000 * SR)
	n = len(x) // h
	m = x[:n * h].mean(1)
	return 20 * np.log10(np.sqrt((m.reshape(n, h) ** 2).mean(1)) + 1e-12), h


def align_peak(x, at=0.010, search=0.4):
	"""Drop what comes before (peak - `at`): the loudest sample in the first
	`search` s then sits `at` s from the start. For one-shots that must hit
	on their frame (bumps, metal, glass, slaps)."""
	k = int(np.abs(x[:int(search * SR)]).max(1).argmax())
	return x[max(0, k - int(at * SR)):].copy()


def start_at(x, rel_db=-20.0, pre=0.002):
	"""Start `pre` s before the first sample of the channel mean that comes
	within `rel_db` of the peak -- the judge's on20 criterion -- so there is
	no leading silence or room noise."""
	a = np.abs(x.mean(1))
	i = int(np.argmax(a > np.abs(x).max() * 10 ** (rel_db / 20)))
	return x[max(0, i - int(pre * SR)):].copy()


def fade(x, fi=0.002, fo=0.05):
	n = len(x)
	a, b = min(int(fi * SR), n // 2), min(int(fo * SR), n // 2)
	if a:
		x[:a] *= np.linspace(0, 1, a)[:, None]
	if b:
		x[n - b:] *= (np.linspace(1, 0, b) ** 2)[:, None]
	return x


def trim_tail(x, below_db=-45.0):
	e = np.abs(x).max(1)
	loud = np.nonzero(e > e.max() * 10 ** (below_db / 20))[0]
	return x[:loud[-1] + 1] if len(loud) else x


def gate(x, rel_db=-32.0, depth_db=-40.0, release=0.08):
	"""Downward gate on the room noise: below `rel_db` re the take's peak (5 ms
	RMS) the gain slides to `depth_db`; 1 ms attack, `release` s release."""
	h = int(0.005 * SR)
	n = len(x) // h + 1
	m = np.pad(x.mean(1), (0, n * h - len(x)))
	e = 20 * np.log10(np.sqrt((m.reshape(n, h) ** 2).mean(1)) + 1e-12)
	want = np.where(e >= e.max() + rel_db, 0.0, depth_db)
	g = np.empty(n)
	cur = 0.0
	step = (abs(depth_db) * h / SR) / release
	for i, w in enumerate(want):
		cur = w if w > cur else max(w, cur - step)
		g[i] = cur
	lin = np.interp(np.arange(len(x)), np.arange(n) * h + h / 2, 10 ** (g / 20))
	return (x * lin[:, None]).astype(np.float32)


def layer(parts):
	"""[(seconds, clip, gain)] on one timeline."""
	end = max(int(t * SR) + len(c) for t, c, _ in parts)
	out = np.zeros((end, parts[0][1].shape[1]), np.float32)
	for t, c, g in parts:
		a = int(t * SR)
		out[a:a + len(c)] += c * g
	return out


def widen(x, ms=17.0, circular=False):
	m = x.mean(1)
	d = int(ms / 1000 * SR)
	r = np.roll(m, d) if circular else np.concatenate([np.zeros(d, np.float32), m[:-d]])
	return np.stack([m, r], 1)


def loop(x, cross=2.0):
	f = int(cross * SR)
	head, tail = x[:f], x[len(x) - f:]
	t = np.linspace(0, np.pi / 2, f)[:, None]
	body = x[:len(x) - f].copy()
	body[:f] = head * np.sin(t) + tail * np.cos(t)
	return body


def iloop(x):
	"""Integrated loudness of the clip played 10x end to end: a one-shot's own
	loudness, measurable even under the 400 ms EBU gating block."""
	raw = np.tile(x.astype(np.float32), (10, 1)).tobytes()
	r = subprocess.run(["ffmpeg", "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
						"-af", "ebur128", "-f", "null", "-"], input=raw, capture_output=True).stderr.decode()
	return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])


def level(x, target, ceiling=CEILING):
	g = target - iloop(x)
	g = min(g, ceiling - 20 * np.log10(float(np.abs(x).max()) + 1e-12))
	return x * 10 ** (g / 20)


def save_pool(items, desired, ceiling=CEILING, note=""):
	"""[(name, x)] all to one loop loudness: `desired`, or lower if a take's
	peak would pass `ceiling` -- so the pool stays within +-2 LU."""
	ach = [iloop(x) + ceiling - 20 * np.log10(float(np.abs(x).max()) + 1e-12) for _, x in items]
	t = min(desired, min(ach))
	print("  " + f"{note or items[0][0]}: pool level {t:.1f} LUFS-loop (wanted {desired:.1f}; "
				 f"peak-limited max per take {' '.join('%.1f' % a for a in ach)})")
	for n, x in items:
		save(n, x * 10 ** ((t - iloop(x)) / 20))



def limit(x, max_db=3.5, ceiling=CEILING):
	"""A look-ahead brickwall limiter that takes at most `max_db` off the
	loudest transient (1 ms look-ahead, 40 ms release), then puts the peak on
	`ceiling`: a peaky strike gains up to `max_db` of loudness."""
	x = peak_to(x, 0.0)
	y = ff(x, f"alimiter=level_in=1:level_out=1:limit={10 ** (-max_db / 20):.6f}:attack=1:release=40:asc=0:level=0")
	return peak_to(y, ceiling)


def fit(x, target, max_gr, ceiling=CEILING):
	"""`x` at `target` LUFS-loop under `ceiling`. If its peak would pass the
	ceiling, the limiter takes the transient down, in 0.5 dB steps and never by
	more than `max_gr`; a take that still cannot reach the target comes back
	as loud as it can go (and save_pool brings the pool down to it)."""
	y = level(x, target, ceiling)
	gr = 0.0
	while iloop(y) < target - 0.05 and gr < max_gr:
		gr = min(gr + 0.5, max_gr)
		y = level(limit(x, gr, ceiling), target, ceiling)
	if gr:
		print(f"    limiter: {gr:.1f} dB off the transient")
	return y


# ---- sources ---------------------------------------------------------------
_src = {}


def source(key):
	"""The recordings, loaded once each."""
	paths = {
		"deck": IA + "Red_Library_Impacts/R28-55-Thumps_on_Large_Hollow_Wooden_Surface.wav",
		"slaps": IA + "Red_Library_Fights/R15-12-Loud_Slaps_or_Whacks.wav",
		"moans": IA + "Red_Library_Voices_Men_1/R21-08-Man_Moans.wav",
		"growl": IA + "Red_Library_Voices_Men_1/R15-31-Man_Growling_and_Grunting.wav",
		"struggle": IA + "Red_Library_Voices_Men_1/R21-14-Man_Grunts_and_Struggles.wav",
		"breath": IA + "Red_Library_Voices_Men_1/R15-33-Man_Out_of_Breath.wav",
		"hollow": IA + "Red_Library_Metal/R15-07-Metal_Clangs_and_Hollow_Hits.wav",
		"pipe": IA + "Red_Library_Metal/R16-34-Banging_Metal_Pipe.wav",
		"smash": IA + "Red_Library_Crashes/R28-13-Glass_Windows_Smashed.wav",
		"molotov": IA + "Red_Library_Fire/R28-08-Torch_or_Molotov_Cocktail.wav",
		"bigfire": IA + "Red_Library_Fire/R27-25-Large_Fire_Burning.wav",
		"boos_men": IA + "Red_Library_Crowds_Men/R08-34-Men_Booing.wav",
		"boos_chorus": IA + "Red_Library_Crowds_Indoor_2/R07-20-Chorus_of_Boos.wav",
	}
	if key not in _src:
		_src[key] = load(paths[key] if key in paths else B + f"bsb_{key}.wav")
	return _src[key]


def thump():
	"""The body under a weapon hit: Body Fall #3, low-passed (the Freesound
	thump the round-3 build used answers 403 from here)."""
	t = fade(ff(align_peak(cut(source("2454"), 0.31, 0.4), 0.004), "lowpass=f=400"), 0.001, 0.08)[:int(0.15 * SR)]
	return peak_to(t, 0.0)


def voice(src, s, n, hp=80, tail=0.15):
	"""A take: from its -20 dB onset, `n` s of voice plus `tail` s in which the
	gate closes on the room (so the take ends in silence, not hiss)."""
	x = cut(src, s, n + tail + 0.15)
	x = ff(x, f"highpass=f={hp}")
	x = start_at(x, -20, 0.001)[:int((n + tail) * SR)]
	return fade(gate(x, -26, -45, 0.06), 0.001, tail)


# ---- slots -----------------------------------------------------------------
## The heavy grunts' median before this round (LUFS-loop). The voices aim at
## it; a take's peak holds its pool a little under.
HEAVY_BEFORE = -17.7


def slot_groan():
	"""P5 (approved). Low, breathy moans in place of the high cries: f0
	102-134 Hz, one pool level instead of a 19.7 LU spread."""
	moans, growl = source("moans"), source("growl")
	save_pool([(f"groan_{i}", voice(src, s, n)) for i, (src, s, n) in enumerate(
			((moans, 0.40, 0.45), (moans, 2.90, 0.85), (moans, 9.56, 0.77), (growl, 0.24, 0.40),
			(growl, 4.47, 0.45)))], HEAVY_BEFORE, note="groan_0..4")


def slot_wind():
	"""P13 (approved). A winded man's exhale, for after a heavy bump."""
	save_pool([(f"wind_{i}", voice(source("breath"), s, n, 100)) for i, (s, n) in enumerate(
			((2.24, 0.50), (4.88, 0.40), (6.03, 0.55), (7.52, 0.45)))], -22.0, note="wind_0..3")


def slot_count_slap():
	"""P16 (approved). The referee's hand on the canvas: a real slap (1-4 kHz)
	over a mat thump, at the level of the thud it replaces."""
	deck, slaps = source("deck"), source("slaps")
	mat = peak_to(ff(align_peak(cut(deck, 12.06, 0.3)), "lowpass=f=300"), 0.0)
	items = []
	for i, s in enumerate((4.425, 7.658, 10.845)):
		sl = peak_to(align_peak(cut(slaps, s - 0.02, 0.3)), 0.0)
		x = layer([(0.0, sl, 1.0), (0.002, mat, 0.35)])
		items.append((f"count_slap_{i}", fade(trim_tail(gate(x, -32, -45, 0.06), -50), 0.002, 0.06)))
	save_pool(items, -19.9, note="count_slap_0..2")


def _trim_lead(name, pre, fade_in):
	x = repo(name)
	y = fade(start_at(x, -20, pre), fade_in, 0.0)
	print(f"  {name}: {(len(x) - len(y)) / SR * 1000:.0f} ms of lead-in removed")
	save(name, peak_to(y, min(CEILING, 20 * np.log10(float(np.abs(y).max())))))


def slot_trims():
	"""P15. The lead-in silence off the committed files (their Freesound
	sources are unreachable, so this is one more Vorbis generation).
	pyro_boom lands on the burst and crowd_finish on the bell (approved)."""
	_trim_lead("pyro_boom", 0.002, 0.002)
	_trim_lead("crowd_finish", 0.03, 0.03)
	# The pops (revised): 150 ms of the crowd drawing breath is kept on every
	# one. crowd_pop fires on the landing frame, and a crowd that roars inside
	# 30 ms reacts before a person could; the 0.6-1.1 s on pops 2 and 4 was
	# simply late. The whoosh is not trimmed: its rise is what makes it one.
	for i in range(5):
		x = repo(f"crowd_pop_{i}")
		m = np.abs(x.mean(1))
		onset = int(np.argmax(m > m.max() * 0.1))      # -20 dB re the peak, on the mono sum
		y = fade(x[max(0, onset - int(0.150 * SR)):].copy(), 0.03, 0.0)
		print(f"  crowd_pop_{i}: {(len(x) - len(y)) / SR * 1000:.0f} ms of lead-in removed")
		save(f"crowd_pop_{i}", peak_to(y, min(CEILING, 20 * np.log10(float(np.abs(y).max())))))


def slot_bump():
	"""P1 (revised). bump_0..5: the boom on frame 0 (it used to land 0.5-1.0 s
	into the file) with a fast decay. Three layers, each peak-aligned 10 ms in:
	the hollow deck, a body fall, and the canvas slap -- then the broadcast EQ
	(1 kHz down, lows up). Six different deck thumps; the slap takes are not the
	count slap's; the pool sits with the kept bump_6..11 at -21.1."""
	deck, slaps = source("deck"), source("slaps")
	DECK = (0.518, 2.686, 9.182, 12.087, 14.879, 3.405)
	BODY = (("2452", 0.213, 0.55), ("2454", 0.322, 0.50), ("2455", 0.148, 0.55), ("2453", 0.452, 0.60),
			("2456", 0.795, 0.60), ("2452", 0.213, 0.55))
	SLAP = ((5.93, 0.14), (9.62, 0.25), (14.048, 0.12), (12.32, 0.30), (20.773, 0.12), (16.01, 0.25))
	items = []
	for i in range(6):
		d = peak_to(align_peak(cut(deck, DECK[i] - 0.03, 0.75)), 0.0)
		k, t, n = BODY[i]
		b = peak_to(align_peak(cut(source(k), t - 0.02, n + 0.02)), 0.0)
		sl = peak_to(ff(align_peak(cut(slaps, SLAP[i][0] - 0.02, 0.25)), "highpass=f=1500"), 0.0)
		x = layer([(0.0, d, 1.0), (0.0, b, 0.8), (0.0, sl, SLAP[i][1])])
		x = ff(x, "equalizer=f=1000:t=q:w=1:g=-3,lowshelf=f=110:g=4")
		x = fade(trim_tail(gate(x, -36, -45, 0.12), -50), 0.002, 0.15)
		items.append((f"bump_{i}", fit(x, -21.1, 2.0)))
	save_pool(items, -21.1, note="bump_0..5")


def _strike(src, at, length):
	"""One hit from a recording of several: from 20 ms before `at`, peak 10 ms in."""
	return peak_to(align_peak(cut(src, at - 0.02, length)), 0.0)


def slot_metal():
	"""P2 (revised). hit_metal_0..2: the lead pipe, shovel, stop sign, steps,
	pan and chain. The body used to bury the metal; now it is a steel shovel
	struck once (full-band), the ring of a banged pipe under it -- a different
	single strike on every take, left to ring out -- and a low body thump.
	Limited by at most 3.5 dB to -23 LUFS-loop; MatchAudio.HIT_TRIM_DB adds
	the last 3 dB."""
	shovel, pipe = source("1084"), source("pipe")
	items = []
	for i, (at, ring_at) in enumerate(((17.180, 2.190), (23.620, 9.275), (10.395, 12.120))):
		# The pipe's low clatter (and the recording's hum) stay out: its ring is the part above 900 Hz.
		ring = peak_to(fade(ff(_strike(pipe, ring_at, 1.2), "highpass=f=900"), 0.001, 0.3), 0.0)
		x = layer([(0.0, _strike(shovel, at, 1.0), 1.0), (0.0, ring, RING), (0.003, thump(), 0.35)])
		x = fade(trim_tail(gate(x, -46, -60, 0.3), -50), 0.002, 0.2)
		items.append((f"hit_metal_{i}", fit(x, -23.0, 3.5)))
	save_pool(items, -23.0, note="hit_metal_0..2")


## The ring layer's gain against the strike it sits under.
RING = 0.6


def slot_chair():
	"""P2 (revised). hit_chair_2..4 (0 and 1, real chairs, are kept): one
	hollow steel hit each -- single strikes, cut from between their neighbours
	-- with the top of a different shovel strike over it for the ring, and the
	body thump. At the kept chairs' level."""
	hollow, shovel = source("hollow"), source("1084")
	items = []
	for i, (at, ring_at) in zip((2, 3, 4), ((14.525, 0.185), (20.915, 3.235), (34.065, 6.935))):
		ring = peak_to(ff(_strike(shovel, ring_at, 1.0), "highpass=f=1500"), 0.0)
		x = layer([(0.0, _strike(hollow, at, 0.80), 1.0), (0.002, ring, 0.5), (0.003, thump(), 0.45)])
		x = fade(trim_tail(gate(x, -34, -60, 0.25), -50), 0.002, 0.15)
		items.append((f"hit_chair_{i}", fit(x, -24.0, 2.0)))
	save_pool(items, -24.0, note="hit_chair_2..4")


def resample(x, ratio):
	"""Play `x` `ratio` times as fast (pitch and length together), linear interpolation."""
	n = int(len(x) / ratio)
	t = np.arange(n) * ratio
	return np.stack([np.interp(t, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], 1).astype(np.float32)


def slot_glass():
	"""P3 (revised). hit_glass_0..2: the pane and the light tubes. The round-3
	files had nothing above 4 kHz, and the first proposal was band-limited to
	6 kHz by its optical smash. Now the shatter is full-band: a bulb bursting
	(its pop and its tinkle) and a mirror exploding, high-passed at 400 Hz with
	its top lifted 6 dB --
	the mirror has two bursts, used one each, and the third take plays the
	first 7% faster. The old window smash stays as the mid-range crash only
	(150 Hz - 5 kHz, which also drops its 60 Hz hum), over the body thump."""
	smash, mirror = source("smash"), source("0387")
	items = []
	for i, (bulb, bulb_at, mirror_at, speed, smash_at, smash_gain) in enumerate((
			("2043", 0.076, 0.050, 1.0, 12.626, 0.20), ("2045", 0.080, 0.555, 1.0, 8.570, 0.35),
			("2039", 0.010, 0.050, 1.07, 0.195, 0.35))):
		pop = peak_to(align_peak(cut(source(bulb), max(0, bulb_at - 0.02), 0.5)), 0.0)
		shards = resample(cut(mirror, max(0, mirror_at - 0.03), 0.85), speed)
		shards = peak_to(fade(ff(align_peak(shards), "highpass=f=400,highshelf=f=7000:g=6"), 0.001, 0.25), 0.0)
		crash = ff(align_peak(cut(smash, max(0, smash_at - 0.02), 1.0)), "highpass=f=150,lowpass=f=5000")
		x = layer([(0.0, pop, 1.0), (0.002, shards, 1.0), (0.004, peak_to(crash, 0.0), smash_gain), (0.004, thump(), 0.3)])
		x = fade(trim_tail(gate(x, -42, -50, 0.15), -55), 0.002, 0.15)
		items.append((f"hit_glass_{i}", fit(x, -23.0, 3.5)))
	save_pool(items, -23.0, note="hit_glass_0..2")


def slot_pyro_bang():
	"""P10 (revised). The lift charge: rubberduck's cannon_02, at -22 LUFS-loop,
	about 6 LU under the pyro_boom it launches -- up from 8.6 LU under, but
	still clearly the smaller sound."""
	x = start_at(cut(load_native(RD + "cannon_02.ogg"), 0.0, 1.3), -20, 0.001)
	save("pyro_bang", level(fade(trim_tail(x, -60), 0.001, 0.2), -22.0))


def slot_grunt_heavy():
	"""P13 (revised). Three more heavy grunts, each cut to ONE effort (a pool
	grunt fires on one blow), and the four kept ones re-levelled: they ran
	-16.0 to -20.2, a 4.2 LU spread, and now the pool of seven sits at -18.2."""
	strug = source("struggle")
	items = [(f"grunt_heavy_{i}", repo(f"grunt_heavy_{i}")) for i in range(4)]
	items += [(f"grunt_heavy_{4 + i}", voice(strug, s, n, 80, tail)) for i, (s, n, tail) in enumerate(
			((17.50, 0.40, 0.11), (25.45, 0.22, 0.13), (34.60, 0.22, 0.06)))]
	save_pool([(n, fit(x, -18.2, 2.0)) for n, x in items], -18.2, note="grunt_heavy_0..6")


def slot_bell():
	"""P7 (revised). The match bells play at their recorded pitch now (a 919 Hz
	ring bell; MatchAudio.MATCH_BELL_PITCH_SCALE 2.0 -> 1.0), so the tails that
	double speed used to halve are shortened here instead: a 2 s fade from 1.5 s
	after the last strike. bell_ding (the weapon) is untouched."""
	for name, last_strike in (("bell_start", 0.84), ("bell_end", 2.17)):
		x = repo(name)
		end = int((last_strike + 1.5 + 2.0) * SR)
		y = x[:end].copy()
		n = int(2.0 * SR)
		y[end - n:] *= (np.linspace(1, 0, n) ** 2)[:, None]
		# A bell's partials beat: 0.7 dB more headroom keeps the true peak under -1.
		save(name, peak_to(y, min(CEILING - 0.7, 20 * np.log10(float(np.abs(y).max())))))


SLOTS = {"bump": slot_bump, "metal": slot_metal, "chair": slot_chair, "glass": slot_glass, "groan": slot_groan, "wind": slot_wind, "count_slap": slot_count_slap, "trims": slot_trims,
		"pyro_bang": slot_pyro_bang, "grunt_heavy": slot_grunt_heavy, "bell": slot_bell}

if __name__ == "__main__":
	args = sys.argv[1:]
	if "--fetch" in args:
		fetch()
		args.remove("--fetch")
	unknown = [a for a in args if a not in SLOTS]
	if unknown:
		sys.exit(f"unknown slot {unknown}; slots: {' '.join(SLOTS)}")
	for name in args or list(SLOTS):
		print(name)
		SLOTS[name]()
