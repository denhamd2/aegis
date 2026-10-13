#!/usr/bin/env python3
"""Builds the crowd's chants in game/assets/audio/ from free voices.

    python3 -m venv ~/.cache/aegis_audio/piper_env
    ~/.cache/aegis_audio/piper_env/bin/pip install piper-tts
    ~/.cache/aegis_audio/piper_env/bin/python tools/audio/build_chants.py

There is no free recording of an arena chanting "Co-dy" or "O-T-C", and real
broadcast audio is not ours to use. So the crowd is built: every syllable of a
chant is spoken by dozens of different people -- the 904 speakers of the
LibriTTS-R Piper voice (CC BY 4.0, credited in assets/audio/CREDITS.md) --
each shouted (pitched up, driven, band-limited), placed on the chant's beat
a little early or late the way a real crowd is, spread across the room, then
put in an arena-sized reverb with a crowd's hand claps on the off-beats.

The voice engine is not bit-reproducible run to run, so every spoken syllable
is cached (~/.cache/aegis_audio/chant_takes) and the mix-down from that cache
is: same cache, same table, same files. The .ogg files are committed; the game
never runs this.

Family recordings drop straight in: put WAVs named <token>_<anything>.wav in
~/.cache/aegis_audio/chant_takes/real/ (one shout of the syllable each) and
they are mixed in among the synthetic voices, weighted up.
"""
import glob
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_sfx as B  # noqa: E402  (shared fetch, load and save)

SR = B.SR
CACHE = os.path.join(B.CACHE, "chant_takes")
VOICE = os.path.join(B.CACHE, "voices", "en_US-libritts_r-medium.onnx")
VOICE_URL = ("https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/"
		"libritts_r/medium/en_US-libritts_r-medium.onnx")
SPEAKERS = 904

# How a word is spoken: the text Piper reads and how drawn out. Whole words,
# not syllables: "Coh!" on its own, shouted, reads as "Go" -- the consonants
# need the word around them. A word sung across several beats is split at the
# gaps between its syllables (see syllables()) and each placed on its beat.
TOKENS = {
	"cody": ("Cody!", 1.6), "lets_go": ("Let's go!", 1.2), "sucks": ("sucks!", 1.1),
	"otc": ("O. T. C.", 1.2), "roman": ("Roman!", 1.6),
	"this_is": ("This is", 1.2), "awesome": ("awesome!", 1.3),
	"you_deserve_it": ("You deserve it!", 1.3), "one_more_match": ("One more match!", 1.3),
	"ho": ("Hoe", 1.0), "lee": ("lee", 0.9), "cow": ("cow!", 1.1),
	"oh": ("Oh!", 1.1), "tee": ("Tee!", 1.1), "see": ("See!", 1.1),
	"roe": ("Roe!", 1.1), "man": ("man!", 1.1), "tables": ("Tables!", 1.6), "boring": ("Boring!", 1.5),
	"one": ("One!", 1.0), "two": ("Two!", 1.0), "three": ("Three!", 1.0),
	"whoa": ("Whoa!", 2.6), "whoa_oh": ("oh!", 1.6),
}

# Claps on a bar: the "clap clap clap" after a name, and the five of
# "clap clap clap-clap-clap".
CLAP3 = [("clap", 2.0), ("clap", 2.5), ("clap", 3.0)]
CLAP5 = [("clap", 0.0), ("clap", 1.0), ("clap", 2.0), ("clap", 2.5), ("clap", 3.0)]


def bar(*hits):
	return list(hits)


# name -> (bpm, bars, crowd size). Each bar is four beats: a list of
# (token, beat) or (token, (beat, beat, ...)) -- one beat per syllable.
CHANTS = {
	"chant_cody": (108, [bar(("cody", 0), *CLAP3)] * 6, 64),
	"chant_lets_go_cody": (116, [bar(("lets_go", (0, 1)), ("cody", 2)),
			bar(("cody", 0), ("sucks", 1.5))] * 4, 56),
	"chant_otc": (104, [bar(("oh", 0), ("tee", 1), ("see", 2))] * 6, 40, dict(jitter=0.008, wet=0.5)),
	"chant_this_is_awesome": (112, [bar(("this_is", (0, 1)), ("awesome", (2, 3))),
			bar(*CLAP5)] * 3, 64, dict(jitter=0.01)),
	"chant_you_deserve_it": (112, [bar(("you_deserve_it", (0, 1, 1.5, 2))), bar(*CLAP5)] * 3, 64),
	"chant_one_more_match": (112, [bar(("one_more_match", (0, 1, 2))), bar(*CLAP5)] * 3, 64),
	"chant_holy_cow": (112, [bar(("ho", 0), ("lee", 1), ("cow", 2)), bar(*CLAP5)] * 2, 64),
	"chant_tables": (116, [bar(("tables", 0), *CLAP3)] * 5, 60),
	"chant_boring": (96, [bar(("boring", 0), ("boring", 2))] * 3, 36),
	"chant_whoa": (92, [bar(("whoa", 0), ("whoa_oh", 2.5))] * 4, 80),
}
# One-shots: the crowd counting along with the referee.
SHOUTS = {"crowd_count_1": "one", "crowd_count_2": "two", "crowd_count_3": "three",
		# The building singing the WHOA in Cody's music with it (CrowdChants).
		"crowd_whoa": "whoa"}
TAKES = 3

# How tight the crowd is, and how big the room. Tuned until a speech
# recogniser (Whisper small.en) reads the words back off the finished mix:
# looser than this and "Co-dy" came back as "Go D".
JITTER = 0.014
LAG = (-0.01, 0.03)
FAR_TOP = (3500.0, 10000.0)
WET = 0.8
SHOUT_PITCH = (1.02, 1.14)   # a shout sits a little above the speaking voice

# What each chant must be heard as. A take is kept only if a speech
# recogniser hears its words in the finished mix at least `times` times
# (once for a phrase: the recogniser folds a repeated phrase into one; the
# crowd can bury a word as surely as a muddy mix can); takes are drawn
# until TAKES pass or MAX_TRIES runs out. Words a recogniser has no hope with
# (a sung "whoa") are not checked.
HEARD = {
	"chant_cody": ("cody", 2), "chant_lets_go_cody": ("lets go cody", 1), "chant_otc": (("otc", "ohtc", "otsee", "ohteesee"), 1),
"chant_this_is_awesome": ("this is awesome", 1),
	"chant_you_deserve_it": ("you deserve it", 1), "chant_one_more_match": ("one more match", 1),
	"chant_holy_cow": ("holy cow", 1), "chant_tables": ("tables", 2), "chant_boring": ("boring", 2),
	# a shouted number comes back as a digit or a homophone, and that is the
	# number heard
	"crowd_count_1": (("one", "1", "won"), 1), "crowd_count_2": (("two", "2", "too", "to"), 1),
	"crowd_count_3": (("three", "3"), 1),
}
MAX_TRIES = 16
## Rebuild every take even if it is on disk (`--fresh`).
FRESH = "--fresh" in sys.argv
FAILED = []


# --- voices -----------------------------------------------------------------

_voice = None


def _piper():
	global _voice
	if _voice is None:
		from piper import PiperVoice  # only when a take is missing from the cache
		if not os.path.exists(VOICE):
			os.makedirs(os.path.dirname(VOICE), exist_ok=True)
			for suffix in ("", ".json"):
				with open(VOICE + suffix, "wb") as f:
					f.write(B._get(VOICE_URL + suffix))
		_voice = PiperVoice.load(VOICE)
	return _voice


def spoken(token: str, speaker: int) -> np.ndarray:
	"""One person saying `token`, mono at SR, from the cache or Piper."""
	path = os.path.join(CACHE, "%s_%03d.npy" % (token, speaker))
	if os.path.exists(path):
		return np.load(path)
	from piper import SynthesisConfig
	text, length = TOKENS[token]
	voice = _piper()
	cfg = SynthesisConfig(speaker_id=speaker, length_scale=length)
	x = np.concatenate([c.audio_float_array for c in voice.synthesize(text, syn_config=cfg)])
	x = resample(x.astype(np.float32), voice.config.sample_rate, SR)
	os.makedirs(CACHE, exist_ok=True)
	np.save(path, x)
	return x


def real_takes(token: str) -> list:
	"""Recorded shouts of `token` (family recordings), if any were dropped in."""
	out = []
	for path in sorted(glob.glob(os.path.join(CACHE, "real", token + "_*.wav"))):
		out.append(B.load(path)[:, 0])
	return out


# --- signal helpers ---------------------------------------------------------

def resample(x: np.ndarray, sr_from: float, sr_to: float) -> np.ndarray:
	n = int(round(len(x) * sr_to / sr_from))
	return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def one_pole(x: np.ndarray, cutoff: float, high: bool = False) -> np.ndarray:
	"""A gentle 6 dB/oct filter (applied by FFT; a sample loop is too slow here)."""
	low = one_pole_fast(x, cutoff)
	return x - low if high else low


def shout(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
	"""A spoken syllable made a shouted one: up in pitch, driven, thinned."""
	x = resample(x, SR * rng.uniform(*SHOUT_PITCH), SR)
	x = x / (np.max(np.abs(x)) + 1e-9)
	drive = rng.uniform(2.0, 4.0)
	x = np.tanh(x * drive) / np.tanh(drive)
	x = one_pole(x, rng.uniform(140.0, 260.0), high=True)
	# Distance: the back of the hall loses its top end.
	x = one_pole(x, rng.uniform(*FAR_TOP))
	return x


def onset(x: np.ndarray) -> int:
	loud = np.abs(x) > 0.15 * np.max(np.abs(x))
	return int(np.argmax(loud))


def syllables(x: np.ndarray, n: int) -> list:
	"""`x` cut into `n` syllables at the quietest points between them: the
	n-1 deepest dips of its 20 ms level, each searched for in its own share
	of the voiced span. Every part starts at its own attack."""
	if n == 1:
		return [x]
	hop = SR // 200
	m = len(x) // hop
	env = np.sqrt((x[: m * hop].reshape(m, hop) ** 2).mean(1))
	env = np.convolve(env, np.ones(4) / 4, "same")
	voiced = np.nonzero(env > 0.08 * env.max())[0]
	a, b = int(voiced[0]), int(voiced[-1])
	cuts = []
	for k in range(1, n):
		centre = a + (b - a) * k / n
		lo, hi = int(centre - (b - a) / (2 * n)), int(centre + (b - a) / (2 * n))
		cuts.append((lo + int(np.argmin(env[lo:hi]))) * hop)
	edges = [0] + cuts + [len(x)]
	parts = []
	for i in range(n):
		p = x[edges[i]: edges[i + 1]].copy()
		f = min(len(p) // 4, int(0.01 * SR))
		if f:
			p[:f] *= np.linspace(0, 1, f)
			p[-f:] *= np.linspace(1, 0, f)
		parts.append(p)
	return parts


def pan(x: np.ndarray, p: float) -> np.ndarray:
	angle = (p + 1.0) * np.pi / 4.0
	return np.stack([x * np.cos(angle), x * np.sin(angle)], axis=1)


def place(out: np.ndarray, x: np.ndarray, at: float) -> None:
	i = int(round(at * SR))
	if i < 0:
		x = x[-i:]
		i = 0
	end = min(len(out), i + len(x))
	if end > i:
		out[i:end] += x[: end - i]


def room(seconds: float, rng: np.random.Generator) -> np.ndarray:
	"""An arena's impulse response: decorrelated noise tails, 2 s to -60 dB."""
	n = int(seconds * SR)
	t = np.arange(n) / SR
	decay = np.exp(-6.9 * t / 2.0)[:, None]
	ir = rng.standard_normal((n, 2)).astype(np.float32) * decay
	ir[: int(0.025 * SR)] = 0.0                       # pre-delay
	# Darker as it decays: air absorbs the top end of a big room.
	ir[:, 0] = one_pole_fast(ir[:, 0], 3500.0)
	ir[:, 1] = one_pole_fast(ir[:, 1], 3500.0)
	return ir / np.sqrt(np.sum(ir ** 2) / 2.0)


def one_pole_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
	"""Low-pass by FFT (for long signals, where the loop is too slow)."""
	f = np.fft.rfftfreq(len(x), 1.0 / SR)
	return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1.0 + (f / cutoff) ** 2), len(x)).astype(np.float32)


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
	n = len(x) + len(ir) - 1
	size = 1 << (n - 1).bit_length()
	out = np.zeros((n, 2), np.float32)
	for c in range(2):
		out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], size) * np.fft.rfft(ir[:, c], size), size)[:n]
	return out


# --- claps ------------------------------------------------------------------

_claps = None


def claps() -> list:
	"""Single hand claps cut from a CC0 recording of a crowd clapping in time."""
	global _claps
	if _claps is None:
		x = B.load(B.freesound("424793"))[:, 0]
		env = np.convolve(np.abs(x), np.ones(64) / 64, "same")
		hits, last = [], -SR
		thresh = 0.35 * np.max(env)
		for i in np.nonzero(env > thresh)[0]:
			if i - last > int(0.12 * SR):
				hits.append(i)
				last = i
		_claps = []
		for i in hits:
			c = x[max(0, i - int(0.005 * SR)): i + int(0.09 * SR)].copy()
			c *= np.linspace(1.0, 0.0, len(c)) ** 2
			_claps.append(c / (np.max(np.abs(c)) + 1e-9))
	return _claps


# --- the mix ----------------------------------------------------------------

def build_chant(name: str, bpm: float, bars: list, size: int, take: int,
		jitter: float = -1.0, wet: float = -1.0) -> np.ndarray:
	jitter = JITTER if jitter < 0.0 else jitter
	wet = WET if wet < 0.0 else wet
	seed = B.hashlib.sha256(("%s/%d" % (name, take)).encode()).digest()[:4]
	rng = np.random.default_rng(int.from_bytes(seed, "little"))
	beat = 60.0 / bpm
	length = len(bars) * 4 * beat + 2.5
	dry = np.zeros((int(length * SR), 2), np.float32)
	speakers = rng.choice(SPEAKERS, size, replace=False)
	# Each person's habits: where they stand, how loud, how late.
	people = [dict(spk=int(s), pan=rng.uniform(-1.0, 1.0), gain=10 ** (rng.uniform(-9, 0) / 20),
			lag=rng.uniform(*LAG)) for s in speakers]
	clap_bank = claps()
	for b, hits in enumerate(bars):
		# Joins in over the first two bars, the way a chant catches on, and
		# the last bar trails off.
		joined = min(1.0, 0.35 + 0.35 * b)
		if b == len(bars) - 1:
			joined *= 0.7
		for token, at in hits:
			t0 = 0.4 + (b * 4 + (at[0] if isinstance(at, tuple) else at)) * beat
			for who in people:
				if rng.random() > joined:
					continue
				when = t0 + who["lag"] + rng.normal(0.0, jitter)
				if token == "clap":
					c = clap_bank[rng.integers(len(clap_bank))]
					c = resample(c, SR * rng.uniform(0.85, 1.2), SR)
					place(dry, pan(c * who["gain"] * 1.3, who["pan"]), when)
					continue
				beats = at if isinstance(at, tuple) else (at,)
				x = shout(spoken(token, who["spk"]), rng)
				for part, on in zip(syllables(x, len(beats)), beats):
					t = t0 + (on - beats[0]) * beat + who["lag"] + rng.normal(0.0, jitter)
					place(dry, pan(part * who["gain"], who["pan"]), t - onset(part) / SR)
		for token, at in hits:
			beats = at if isinstance(at, tuple) else (at,)
			for x in real_takes(token):          # family recordings, louder
				for _ in range(6):
					y = shout(x, rng)
					for part, on in zip(syllables(y, len(beats)), beats):
						place(dry, pan(part * 0.9, rng.uniform(-1, 1)),
								0.4 + (b * 4 + on) * beat + rng.normal(0, 0.02) - onset(part) / SR)
	room_tail = convolve(dry, room(2.6, rng))[: len(dry)]
	mix = dry / (np.max(np.abs(dry)) + 1e-9) + wet * room_tail / (np.max(np.abs(room_tail)) + 1e-9)
	return B.fade(mix, 0.05, 1.5)


def build_shout(token: str, size: int, take: int) -> np.ndarray:
	long = 3.4 if token == "whoa" else 2.2
	return build_chant("shout_" + token, 120, [[(token, 0)]], size, take)[: int(long * SR)]


_asr = None


def heard(x: np.ndarray, name: str) -> str:
	"""What a speech recogniser makes of `x`, or None with none installed."""
	global _asr
	if _asr is None:
		try:
			from faster_whisper import WhisperModel
		except ImportError:
			_asr = False
		else:
			_asr = WhisperModel("small.en", device="cpu", compute_type="int8")
	if _asr is False:
		return None
	import tempfile
	with tempfile.NamedTemporaryFile(suffix=".wav") as f:
		B.subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR),
				"-ac", "2", "-i", "-", f.name], input=x.astype(np.float32).tobytes(), check=True)
		segs, _ = _asr.transcribe(f.name, beam_size=5, language="en")
		text = " ".join(seg.text for seg in segs)
	return " ".join("".join(c for c in w.lower() if c.isalnum()) for w in text.split())


def passes(x: np.ndarray, name: str) -> bool:
	if name not in HEARD:
		return True
	text = heard(x, name)
	if text is None:
		return True
	words, times = HEARD[name]
	squashed = text.replace(" ", "")
	options = words if isinstance(words, tuple) else (words,)
	ok = max(squashed.count(o.replace(" ", "")) for o in options) >= times
	print("    %s heard: %s%s" % (name, text[:70], "" if ok else "  (rejected)"))
	return ok


def keep(name: str, make, takes: int) -> None:
	kept, tries = 0, 0
	# Takes already built and checked stay; only the missing ones are drawn,
	# from seeds past any that were tried (CHANT_FIRST_TRY).
	while os.path.exists(os.path.join(B.OUT, "%s_%d.ogg" % (name, kept))) and not FRESH:
		kept += 1
	tries = int(os.environ.get("CHANT_FIRST_TRY", "0"))
	last = tries + MAX_TRIES
	while kept < takes and tries < last:
		x = make(tries)
		tries += 1
		if passes(x, name):
			B.save("%s_%d" % (name, kept), x)
			kept += 1
	if kept < takes:
		FAILED.append("%s: only %d of %d takes were heard as %r" % (name, kept, takes, HEARD[name][0]))


def main() -> None:
	os.makedirs(B.OUT, exist_ok=True)
	only = set(a for a in sys.argv[1:] if not a.startswith("--"))
	for name, spec in CHANTS.items():
		if not only or name in only:
			bpm, bars, size = spec[:3]
			extra = spec[3] if len(spec) > 3 else {}
			keep(name, lambda k: B.peak_to(build_chant(name, bpm, bars, size, k, **extra), -1.0), TAKES)
	for name, token in SHOUTS.items():
		if not only or name in only:
			keep(name, lambda k: B.peak_to(B.fade(build_shout(token, 72, k), 0.01, 0.6), -1.0), 2)
	if FAILED:
		sys.exit("\n".join(FAILED))


if __name__ == "__main__":
	main()
