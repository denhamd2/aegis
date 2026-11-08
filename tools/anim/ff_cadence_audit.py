#!/usr/bin/env python3
"""Android-side reproduction of the clip-cadence metric in
game/tests/test_clip_cadence.gd.

Reads the shipped wrestling_clips.glb and samples every rotation track at
30 fps, summing the whole-body angular speed per frame. Reports the same
holds, snaps and jerk the Godot gate computes. No Godot or Blender needed.

The Godot test and game/tools/anim/clip_speeds.gd remain authoritative; this
exists so the Phase A/C audits can measure on Android/Termux, where neither
binary is available. Differences from the importer's sampling are possible;
treat this as ranking evidence and confirm on the Mac.

    python3 tools/anim/ff_cadence_audit.py
"""
import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "game/assets/animations/wrestling_clips.glb"

FPS = 30.0
STILL = 1.5
HOLD_FRAMES = 4
SNAP = 3.5
SNAP_WINDOW = 5

HERO = [
    "Cross_Rhodes_Attacker", "Cross_Rhodes_Defender",
    "Pedigree_Attacker", "Pedigree_Defender",
    "FF_Tiger_Driver_98_Attacker", "FF_Tiger_Driver_98_Defender",
    "Cody_Cutter_Attacker", "Cody_Cutter_Defender",
    "Disaster_Kick_Attacker", "Disaster_Kick_Defender",
    "Vertical_Suplex_Attacker", "Vertical_Suplex_Defender",
    "Powerslam_Attacker", "Powerslam_Defender",
    "Alabama_Slam_Attacker", "Alabama_Slam_Defender",
    "Run_Spear_Attacker", "Run_Spear_Defender",
    "Superman_Punch_Attacker", "Superman_Punch_Defender",
]
HERO_BUDGET = 952.0

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        with open(path, "rb") as f:
            magic, _version, _total = struct.unpack("<III", f.read(12))
            if magic != 0x46546C67:
                raise SystemExit("not a GLB")
            clen, _ctype = struct.unpack("<II", f.read(8))
            self.doc = json.loads(f.read(clen))
            blen, _btype = struct.unpack("<II", f.read(8))
            self.bin = f.read(blen)

    def accessor(self, idx):
        a = self.doc["accessors"][idx]
        bv = self.doc["bufferViews"][a["bufferView"]]
        fmt, size = COMP[a["componentType"]]
        n = NCOMP[a["type"]]
        stride = bv.get("byteStride") or size * n
        base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        out = []
        for i in range(a["count"]):
            vals = struct.unpack_from("<" + fmt * n, self.bin, base + i * stride)
            out.append(vals)
        return out

    def animations(self):
        return {a.get("name", ""): a for a in self.doc["animations"]}


def quat_at(times, quats, interp, t):
    if t <= times[0][0]:
        return quats[0]
    if t >= times[-1][0]:
        return quats[-1]
    lo, hi = 0, len(times) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if times[mid][0] <= t:
            lo = mid
        else:
            hi = mid
    if interp == "STEP":
        return quats[lo]
    t0, t1 = times[lo][0], times[hi][0]
    u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
    q0, q1 = quats[lo], quats[hi]
    dot = sum(a * b for a, b in zip(q0, q1))
    if dot < 0.0:
        q1 = tuple(-b for b in q1)
        dot = -dot
    dot = min(1.0, max(-1.0, dot))
    if dot > 0.9995:
        q = tuple(a + (b - a) * u for a, b in zip(q0, q1))
    else:
        theta0 = math.acos(dot)
        theta = theta0 * u
        s0 = math.sin(theta0 - theta) / math.sin(theta0)
        s1 = math.sin(theta) / math.sin(theta0)
        q = tuple(a * s0 + b * s1 for a, b in zip(q0, q1))
    n = math.sqrt(sum(c * c for c in q)) or 1.0
    return tuple(c / n for c in q)


def qangle_deg(a, b):
    dot = abs(sum(x * y for x, y in zip(a, b)))
    dot = min(1.0, max(-1.0, dot))
    return math.degrees(2.0 * math.acos(dot))


def speeds(glb, anim):
    times = [glb.accessor(s["input"]) for s in anim["samplers"]]
    quats = [glb.accessor(s["output"]) for s in anim["samplers"]]
    chans = []
    for ch in anim["channels"]:
        if ch["target"].get("path") != "rotation":
            continue
        s = anim["samplers"][ch["sampler"]]
        chans.append((times[ch["sampler"]], quats[ch["sampler"]],
                      s.get("interpolation", "LINEAR")))
    length = max(t[-1][0] for t, _, _ in chans) if chans else 0.0
    frames = int(round(length * FPS))
    out = []
    prev = None
    for f in range(frames + 1):
        t = min(f / FPS, length)
        now = [quat_at(ts, qs, it, t) for ts, qs, it in chans]
        if prev is not None:
            out.append(sum(qangle_deg(a, b) for a, b in zip(prev, now)))
        prev = now
    return length, out


def holds(speed):
    n = run = 0
    for f in range(len(speed)):
        if speed[f] < STILL:
            run += 1
        else:
            if run >= HOLD_FRAMES and f - run > 0:
                n += 1
            run = 0
    return n


def snaps(speed):
    n = 0
    for f in range(1, len(speed) - 1):
        near = []
        for g in range(max(0, f - SNAP_WINDOW), min(len(speed), f + SNAP_WINDOW + 1)):
            if g != f:
                near.append(speed[g])
        near.sort()
        med = near[len(near) // 2]
        if med > 2.0 and speed[f] > SNAP * med:
            n += 1
    return n


def jerk(speed):
    if len(speed) < 2:
        return 0.0
    return sum(abs(speed[f] - speed[f - 1]) for f in range(1, len(speed))) / (len(speed) - 1)


def main():
    glb = Glb(GLB)
    anims = glb.animations()
    names = sorted(n for n in anims if n.startswith("FF_"))
    total_h = total_s = 0
    print("clip,length,frames,holds,snaps,jerk")
    for name in names:
        length, sp = speeds(glb, anims[name])
        h, s, j = holds(sp), snaps(sp), jerk(sp)
        total_h += h
        total_s += s
        print("%s,%.3f,%d,%d,%d,%.1f" % (name, length, len(sp), h, s, j))
    print("FF totals holds %d snaps %d" % (total_h, total_s))
    hero_total = 0.0
    print("\nHERO_JERK")
    for name in HERO:
        length, sp = speeds(glb, anims[name])
        j = jerk(sp)
        hero_total += j
        print("%s,%.1f" % (name, j))
    print("HERO total %.1f (budget %.1f)" % (hero_total, HERO_BUDGET))


if __name__ == "__main__":
    sys.exit(main())
