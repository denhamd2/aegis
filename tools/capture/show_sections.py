#!/usr/bin/env python3
"""Plans and cuts a show recording into what a QA reviewer reads, section by section.

    python3 tools/capture/show_sections.py plan <out_dir> [fps]
    python3 tools/capture/show_sections.py cut <out_dir> [fps]

Both read <out_dir>/frames/timeline.txt (written by tools/probe/title_video.gd:
"frame section detail" as each part of the show starts).

`plan` writes <out_dir>/frames/wanted.txt: every still below and every frame of
the motion clips, for title_video's --frames (the sparse render).

`cut` reads the JPEG frames that render saved, and <out_dir>/frames/sound.wav,
and writes:

    qa/NN_<section>/t<mm>m<ss>s_<frame>.jpg   stills spread through the section
    qa/NN_<section>.jpg                       a contact sheet of them, timestamped
    qa/index.md                               each section's span, length and stills
    clips/<name>.mp4                          the motion clips, with their sound

Sections: title, select, versus, entrances (match scene to the bell, one still
per entrance beat), match (bell to finish, one every MATCH_EVERY seconds plus
the last seconds before the finish), post_match (finish to the menu) and menu.
A reviewer opens the contact sheets first and the single stills for detail.

Needs Pillow.
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

# Seconds between match stills, and how many evenly spaced stills the short
# sections get. A 9-minute match at 20 s is ~28 stills: enough to see every
# phase of it without a reviewer paging through hundreds. Each 3D still costs
# 25 drawn frames (~75 s on the software renderer), so the count is the
# render pass's running time.
MATCH_EVERY = 20.0
SPREAD = {"title": 3, "select": 3, "versus": 3, "post_match": 8, "menu": 2}
# Entrance beats closer together than this share one still (the ringside
# beats re-cut every few frames as the man climbs in).
BEAT_MIN_GAP = 5.0
# Into each entrance beat before its still: past the cut, onto the shot.
BEAT_IN = 1.0
# The finish, closer: stills this many seconds before the finish.
FINISH_LEAD = (8.0, 4.0, 2.0, 0.5)
# Full-motion clips: (name, mark, seconds before it, seconds after). Motion is
# what stills cannot show -- the owner's "stop motion" and snap complaints were
# all about it -- so the clips sit on the opening exchange and the finish.
CLIPS = [
	("bell", "bell", 0.0, 10.0),
	("finish", "finish", 12.0, 3.0),
]
THUMB_W = 320
COLS = 4


def read_timeline(path: str) -> list:
	marks = []
	with open(path) as fh:
		for line in fh:
			parts = line.split(maxsplit=2)
			if len(parts) >= 2:
				marks.append((int(parts[0]), parts[1], parts[2].strip() if len(parts) > 2 else ""))
	return marks


def stamp(frame: int, fps: float) -> str:
	s = frame / fps
	return f"{int(s // 60):02d}m{s % 60:04.1f}s"


def sections(marks: list, total: int, fps: float) -> list:
	"""[(name, start, end, [frames to still])], in show order."""
	first = {}
	for frame, name, _ in marks:
		first.setdefault(name, frame)
	end = first.get("end", total)
	end = min(end, total)

	def span(a: str, b_names: tuple) -> tuple:
		start = first.get(a)
		if start is None:
			return None
		stop = min([first[b] for b in b_names if b in first] + [end])
		return start, max(start + 1, stop)

	out = []
	order = [
		("title", ("select",)),
		("select", ("versus",)),
		("versus", ("match_scene",)),
		("entrances", ("bell",)),
		("match", ("finish",)),
		("post_match", ("menu", "end")),
		("menu", ("end",)),
	]
	alias = {"entrances": "match_scene", "match": "bell", "post_match": "finish"}
	for name, nxt in order:
		s = span(alias.get(name, name), nxt)
		if s is None:
			continue
		a, b = s
		if name == "entrances":
			picks = [a + int(fps * 0.5)]
			for frame, kind, _ in marks:
				if kind == "entrance" and a <= frame < b \
						and frame - picks[-1] >= fps * BEAT_MIN_GAP - fps * BEAT_IN:
					picks.append(min(b - 1, frame + int(fps * BEAT_IN)))
		elif name == "match":
			step = int(fps * MATCH_EVERY)
			picks = list(range(a + int(fps), b, step))
			picks += [b - int(fps * lead) for lead in FINISH_LEAD]
		else:
			n = SPREAD.get(name, 3)
			picks = [a + (b - a) * (i + 0.5) / n for i in range(n)]
		picks = sorted({min(b - 1, max(a, int(p))) for p in picks})
		out.append((name, a, b, picks))
	return out


def clip_ranges(marks: list, fps: float, end: int) -> list:
	first = {}
	for frame, name, _ in marks:
		first.setdefault(name, frame)
	out = []
	for name, mark, before, after in CLIPS:
		if mark in first:
			a = max(0, first[mark] - int(fps * before))
			b = min(end, first[mark] + int(fps * after))
			if b > a:
				out.append((name, a, b))
	return out


def show_end(marks: list) -> int:
	return max([f for f, name, _ in marks if name == "end"] or [max(f for f, _, _ in marks)])


def plan(out: str, fps: float) -> None:
	frames_dir = os.path.join(out, "frames")
	marks = read_timeline(os.path.join(frames_dir, "timeline.txt"))
	end = show_end(marks)
	wanted = set()
	for _, _, _, picks in sections(marks, end, fps):
		wanted.update(picks)
	for _, a, b in clip_ranges(marks, fps, end):
		wanted.update(range(a, b))
	with open(os.path.join(frames_dir, "wanted.txt"), "w") as fh:
		fh.write("\n".join(str(f) for f in sorted(wanted)) + "\n")
	print(f"{len(wanted)} frames wanted of {end} ({stamp(end, fps)})")


def saved_frames(frames_dir: str) -> list:
	return sorted(int(f[2:7]) for f in os.listdir(frames_dir)
			if f.startswith("f_") and f.endswith(".jpg"))


def runs(frames: list, min_len: int) -> list:
	"""Consecutive stretches of saved frames at least `min_len` long: the clips."""
	out, start = [], None
	for i, f in enumerate(frames):
		if start is None:
			start = f
		if i + 1 == len(frames) or frames[i + 1] != f + 1:
			if f + 1 - start >= min_len:
				out.append((start, f + 1))
			start = None
	return out


def cut_clips(out: str, marks: list, fps: float, saved: list) -> None:
	"""Each long run of saved frames, named for the clip mark it holds. Cut from
	what was saved rather than from the plan: the drawn run can land its marks
	a few frames off the simulated one (the entrance cues follow the audio
	clock), so the planned range and the frames on disk need not agree."""
	frames_dir = os.path.join(out, "frames")
	clips = os.path.join(out, "clips")
	os.makedirs(clips, exist_ok=True)
	wav = os.path.join(frames_dir, "sound.wav")
	first = {}
	for frame, mark, _ in marks:
		first.setdefault(mark, frame)
	for a, b in runs(saved, int(fps * 2)):
		name = min(CLIPS, key=lambda c: abs(first.get(c[1], 1 << 30) - (a + b) // 2))[0]
		cmd = ["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(fps), "-start_number", str(a),
				"-i", os.path.join(frames_dir, "f_%05d.jpg")]
		if os.path.exists(wav):
			cmd += ["-ss", f"{a / fps:.4f}", "-t", f"{(b - a) / fps:.4f}", "-i", wav,
					"-c:a", "aac", "-b:a", "192k"]
		cmd += ["-frames:v", str(b - a), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
				"-movflags", "+faststart", os.path.join(clips, name + ".mp4")]
		subprocess.run(cmd, check=True)
		print(f"clip {name}: {stamp(a, fps)}-{stamp(b, fps)}")


def contact_sheet(stills: list, fps: float, path: str) -> None:
	if not stills:
		return
	first = Image.open(stills[0][1])
	h = int(first.height * THUMB_W / first.width)
	rows = (len(stills) + COLS - 1) // COLS
	sheet = Image.new("RGB", (COLS * THUMB_W, rows * h), (12, 12, 14))
	draw = ImageDraw.Draw(sheet)
	for i, (frame, src) in enumerate(stills):
		im = Image.open(src).convert("RGB").resize((THUMB_W, h), Image.LANCZOS)
		x, y = (i % COLS) * THUMB_W, (i // COLS) * h
		sheet.paste(im, (x, y))
		label = stamp(frame, fps)
		draw.rectangle((x, y, x + 8 * len(label) + 8, y + 16), fill=(0, 0, 0))
		draw.text((x + 4, y + 2), label, fill=(255, 255, 255))
	sheet.save(path, quality=88)


def cut(out: str, fps: float) -> None:
	frames_dir = os.path.join(out, "frames")
	marks = read_timeline(os.path.join(frames_dir, "timeline.txt"))
	total = show_end(marks)
	saved = saved_frames(frames_dir)
	clip_runs = runs(saved, int(fps * 2))
	qa = os.path.join(out, "qa")
	shutil.rmtree(qa, ignore_errors=True)
	os.makedirs(qa)
	lines = ["# Show recording: QA stills", "",
			f"{total} frames at {fps:g} fps = {stamp(total, fps)}.", "",
			"| # | section | from | to | length | stills |",
			"| --- | --- | --- | --- | --- | --- |"]
	for n, (name, a, b, picks) in enumerate(sections(marks, total, fps), 1):
		folder = f"{n:02d}_{name}"
		os.makedirs(os.path.join(qa, folder))
		stills = []
		# Every saved still in this section of the drawn run's own timeline,
		# plus one every two seconds out of any clip running through it.
		in_clip = {f for r in clip_runs for f in range(*r)}
		chosen = [f for f in saved if a <= f < b and (f not in in_clip or (f - a) % int(fps * 2) == 0)]
		for frame in chosen:
			src = os.path.join(frames_dir, f"f_{frame:05d}.jpg")
			dst = os.path.join(qa, folder, f"t{stamp(frame, fps)}_{frame:05d}.jpg")
			shutil.copyfile(src, dst)
			stills.append((frame, dst))
		contact_sheet(stills, fps, os.path.join(qa, folder + ".jpg"))
		lines.append(f"| {n} | {name} | {stamp(a, fps)} | {stamp(b, fps)} | "
				f"{(b - a) / fps:.1f} s | {len(stills)} |")
	lines += ["", "## Timeline", "", "| time | frame | mark | detail |", "| --- | --- | --- | --- |"]
	for frame, name, detail in marks:
		lines.append(f"| {stamp(frame, fps)} | {frame} | {name} | {detail} |")
	with open(os.path.join(qa, "index.md"), "w") as fh:
		fh.write("\n".join(lines) + "\n")
	print(f"qa stills -> {qa}")
	cut_clips(out, marks, fps, saved)


def main() -> None:
	mode, out = sys.argv[1], sys.argv[2]
	fps = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
	{"plan": plan, "cut": cut}[mode](out, fps)


if __name__ == "__main__":
	main()
