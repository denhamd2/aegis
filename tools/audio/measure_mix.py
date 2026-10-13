#!/usr/bin/env python3
"""Reads a recording's loudness back, so the mix cannot drift unnoticed.

    python3 tools/audio/measure_mix.py <sound.wav> [section_seconds]

Takes the soundtrack tools/capture/mix_sound_log.py rebuilds from a probe's
sound log (or any recording) and prints, by EBU R128 as ffmpeg measures it:
the integrated loudness of the whole, the loudest and median 3-second
(short-term) loudness, the true peak, and a short-term line per section, so a
quiet entrance or a buried chant shows up as a number.

Targets (MatchAudio's header): about -18 LUFS integrated over a match, short-
term peaks near -10 on a big pop, never past -1 dBTP.
"""
import re
import subprocess
import sys


def measure(path: str) -> dict:
	r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true",
			"-f", "null", "-"], capture_output=True, text=True).stderr
	rows = []
	for m in re.finditer(r"t:\s*([\d.]+)\s+TARGET.*?M:\s*(-?[\d.inf]+)\s+S:\s*(-?[\d.inf]+)", r):
		rows.append((float(m.group(1)), float(m.group(2)), float(m.group(3))))
	integrated = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])
	peak = re.findall(r"Peak:\s+(-?[\d.inf]+) dBFS", r)
	return {"rows": rows, "I": integrated, "peak": float(peak[-1]) if peak else float("nan")}


def main() -> None:
	path = sys.argv[1]
	section = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
	m = measure(path)
	short = sorted(s for _, _, s in m["rows"] if s > -70)
	print("integrated  %6.1f LUFS" % m["I"])
	if short:
		print("short-term  max %6.1f  median %6.1f LUFS" % (short[-1], short[len(short) // 2]))
	print("true peak   %6.1f dBTP" % m["peak"])
	end = m["rows"][-1][0] if m["rows"] else 0.0
	t = 0.0
	while t < end:
		s = [v for at, _, v in m["rows"] if t <= at < t + section and v > -70]
		if s:
			bar = "#" * max(0, int((sum(s) / len(s) + 40) / 1.0))
			print("%5.0f-%-5.0f s  %6.1f LUFS  %s" % (t, t + section, sum(s) / len(s), bar))
		t += section


if __name__ == "__main__":
	main()
