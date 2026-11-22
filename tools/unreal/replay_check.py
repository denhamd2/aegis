"""Replay round trip for the Unreal port: record a match, play it back.

The port's counterpart to game/tests/test_replay_roundtrip.gd, checking
ARCHITECTURE.md's "same seed + same replay must always produce the same
end-state hash" on a real match with real input. Run inside the UE 5.9 editor
of the port project (the editor MCP's execute_python, which allows top-level
await).

1. Record: aegis.ReplayRecord NAME, then a PIE match in which this script
   plays the player's man from outside the sim, the way a pad would: a
   seeded-random walk (AddMovementInput most frames), with strikes, grapple
   attempts, move cycling and jumps mixed in. When PIE stops, UAegisMatchSim
   writes Saved/AegisReplays/NAME.aegisreplay with the seed, the last tick
   and the end-state hash.
2. Play: aegis.ReplayPlay NAME, then a second PIE match. The script keeps
   feeding the player a *different* random input, which the replay must
   ignore, and waits for the sim's verdict at the recorded last tick.

3. Control: the same recording with every movement vector reversed is played
   too, and must come out DIVERGED.

It passes when the verdict is MATCH, the hashes logged every EVERY ticks agree
between the two runs at every checkpoint, the recording actually holds
movement and actions, and the mirrored control diverges (a replay whose
movement never reached gameplay would match trivially).

Optional globals, set before the script body:
    NAME = "roundtrip"   SEED = 5   TICKS = 900
"""
import asyncio
import json
import math
import os
import random
import re

import unreal

NAME = globals().get("NAME", "roundtrip")
SEED = globals().get("SEED", 5)
TICKS = globals().get("TICKS", 900)
EVERY = 150
LOG = os.path.join(unreal.Paths.project_log_dir(), "MyProject2.log")
HASH = re.compile(r"LogAegisSim: tick (\d+) seed (\d+) hash ([0-9a-f]+)")
FILE = os.path.join(unreal.Paths.project_saved_dir(), "AegisReplays", NAME + ".aegisreplay")


def cmd(c):
    unreal.SystemLibrary.execute_console_command(None, c)


def world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()


def sim_for(w):
    for o in unreal.ObjectIterator(unreal.AegisMatchSim):
        if o.get_world() == w:
            return o
    return None


def drive(me, rng):
    """One frame of a made-up player: mostly walking, sometimes acting."""
    a = rng.uniform(0, 6.283)
    me.add_movement_input(unreal.Vector(math.cos(a), math.sin(a), 0.0), rng.uniform(0.3, 1.0), False)
    roll = rng.random()
    if roll < 0.04:
        me.strike()
    elif roll < 0.07:
        me.try_grapple()
    elif roll < 0.08:
        me.cycle_grapple_move()
    elif roll < 0.09:
        me.jump()
    elif roll < 0.10:
        me.stop_jumping()


async def run(mode, input_seed, name=NAME):
    cmd("aegis.Seed %d" % SEED)
    cmd("aegis.HashLogEveryTicks %d" % EVERY)
    cmd('aegis.ReplayRecord "%s"' % (name if mode == "record" else ""))
    cmd('aegis.ReplayPlay "%s"' % (name if mode == "play" else ""))
    start = os.path.getsize(LOG)
    rng = random.Random(input_seed)
    out = {"mode": mode}
    await call_tool("EditorToolset.EditorAppToolset.StartPIE")
    try:
        me = None
        for _ in range(4 * 60 * 20):
            await asyncio.sleep(0.03)
            w = world()
            sim = sim_for(w) if w else None
            if not sim:
                continue
            if me is None:
                ws = unreal.GameplayStatics.get_all_actors_of_class(w, unreal.AegisWrestlerCharacter)
                mine = [a for a in ws if not a.actor_has_tag("Opponent")]
                me = mine[0] if mine else None
                if me:
                    out["start_pos"] = [round(v, 1) for v in (me.get_actor_location().x, me.get_actor_location().y)]
            if me:
                drive(me, rng)
            if mode == "record" and sim.get_tick() >= TICKS:
                break
            if mode == "play" and sim.get_replay_verdict():
                break
        out["verdict"] = sim.get_replay_verdict() if sim else None
        out["tick"] = sim.get_tick() if sim else None
        if me:
            out["end_pos"] = [round(v, 1) for v in (me.get_actor_location().x, me.get_actor_location().y)]
    finally:
        await call_tool("EditorToolset.EditorAppToolset.StopPIE")
        cmd('aegis.ReplayRecord ""')
        cmd('aegis.ReplayPlay ""')
    await asyncio.sleep(1.5)
    with open(LOG, "rb") as f:
        f.seek(start)
        text = f.read().decode("utf-8", "replace")
    out["hashes"] = {int(t): h for t, s, h in HASH.findall(text) if int(s) == SEED}
    return out


rec = await run("record", 1)
frames = moves = actions = 0
end_tick = None
if os.path.exists(FILE):
    for line in open(FILE):
        p = line.split()
        if p and p[0] == "f":
            frames += 1
            moves += any(float(v) != 0.0 for v in p[4:7])
            actions += int(p[3]) != 0 or int(p[7]) != 0
        elif p and p[0] == "end_tick":
            end_tick = int(p[1])
play = await run("play", 2)

# Negative control: the same recording with every movement vector turned
# around must NOT match -- otherwise the replayed movement never reached
# gameplay and the MATCH above proved nothing.
MIRROR = NAME + "_mirrored"
with open(FILE) as src, open(os.path.join(os.path.dirname(FILE), MIRROR + ".aegisreplay"), "w") as dst:
    for line in src:
        p = line.split()
        if p and p[0] == "f":
            p[4], p[5] = repr(-float(p[4])), repr(-float(p[5]))
            line = " ".join(p) + "\n"
        dst.write(line)
mirrored = await run("play", 3, MIRROR)

problems = []
if not os.path.exists(FILE):
    problems.append("no recording written at %s" % FILE)
if moves < 100 or actions < 5:
    problems.append("the recording is too thin to prove anything (%d movement frames, %d action frames)" % (moves, actions))
if play["verdict"] != "MATCH":
    problems.append("playback verdict %r at tick %s" % (play["verdict"], play["tick"]))
if mirrored["verdict"] != "DIVERGED":
    problems.append("the mirrored recording gave %r: replayed movement is not reaching gameplay" % mirrored["verdict"])
shared = sorted(t for t in rec["hashes"] if t in play["hashes"] and t <= (end_tick or 0))
bad = [t for t in shared if rec["hashes"][t] != play["hashes"][t]]
if bad:
    problems.append("hashes diverge from tick %d" % bad[0])
if len(shared) < (end_tick or 0) // EVERY:
    problems.append("only %d of %d checkpoints compared" % (len(shared), (end_tick or 0) // EVERY))
json.dumps({
    "pass": not problems,
    "problems": problems,
    "recording": {"file": FILE, "end_tick": end_tick, "frames": frames, "movement_frames": moves, "action_frames": actions,
                  "player_moved": [rec.get("start_pos"), rec.get("end_pos")]},
    "playback": {"verdict": play["verdict"], "tick": play["tick"], "player_end": play.get("end_pos")},
    "mirrored_control": mirrored["verdict"],
    "checkpoints": len(shared),
})
