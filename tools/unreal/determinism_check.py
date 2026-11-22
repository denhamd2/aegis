"""Determinism check for the Unreal port: same seed, same end-state hash.

The port's counterpart to game/tests/test_determinism.gd, and the check behind
gauntlet/anchor/ARCHITECTURE.md's "Determinism (hard requirement)". Run inside
the UE 5.9 editor of the port project (the editor MCP's execute_python, which
allows top-level await).

It plays the same no-input match several times in PIE with aegis.Deterministic
on (the engine on fixed 1/60 s frames), and reads the hash UAegisMatchSim logs
every 300 ticks. It passes when:
  - every run with the same seed logs the same hash at every checkpoint, and
  - a different seed changes the match itself (the snapshot with the seed key
    removed), not just the hash, since the seed is part of the snapshot.

Optional globals, set before the script body:
    SEEDS = [7, 7, 8]    # runs, in order (default)
    TICKS = 1800         # how far each run goes (30 s of match)
"""
import asyncio
import json
import os
import re

import unreal

SEEDS = globals().get("SEEDS", [7, 7, 8])
TICKS = globals().get("TICKS", 1800)
EVERY = 300
LOG = os.path.join(unreal.Paths.project_log_dir(), "MyProject2.log")
LINE = re.compile(r"LogAegisSim: tick (\d+) seed (\d+) hash ([0-9a-f]+)")


def sim_for(world):
    for o in unreal.ObjectIterator(unreal.AegisMatchSim):
        if o.get_world() == world:
            return o
    return None


async def run(seed):
    for cmd in ["aegis.Deterministic 1", "aegis.Seed %d" % seed, "aegis.HashLogEveryTicks %d" % EVERY]:
        unreal.SystemLibrary.execute_console_command(None, cmd)
    start = os.path.getsize(LOG)
    await call_tool("EditorToolset.EditorAppToolset.StartPIE")
    snapshot = None
    try:
        for _ in range(4 * 600):
            await asyncio.sleep(0.25)
            world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
            sim = sim_for(world) if world else None
            if sim and sim.get_tick() >= TICKS:
                snapshot = sim.end_state_snapshot()
                break
    finally:
        await call_tool("EditorToolset.EditorAppToolset.StopPIE")
        unreal.SystemLibrary.execute_console_command(None, "aegis.Deterministic 0")
    await asyncio.sleep(1.0)
    with open(LOG, "rb") as f:
        f.seek(start)
        text = f.read().decode("utf-8", "replace")
    hashes = {int(t): h for t, s, h in LINE.findall(text) if int(s) == seed and int(t) <= TICKS}
    # the match, minus anything that depends on the exact tick it was read at
    gameplay = None
    if snapshot:
        drop = ("seed=", "tick=")
        gameplay = sorted(p for p in snapshot.split(",") if not p.startswith(drop) and "ticks_in_state" not in p)
    return {"seed": seed, "hashes": hashes, "gameplay": gameplay}


runs = [await run(s) for s in SEEDS]
problems = []
by_seed = {}
for r in runs:
    if len(r["hashes"]) < TICKS // EVERY:
        problems.append("seed %d logged %d of %d checkpoints" % (r["seed"], len(r["hashes"]), TICKS // EVERY))
    first = by_seed.setdefault(r["seed"], r)
    if first is not r and first["hashes"] != r["hashes"]:
        bad = sorted(t for t in first["hashes"] if first["hashes"].get(t) != r["hashes"].get(t))
        problems.append("seed %d diverged from its first run at tick %s" % (r["seed"], bad[0] if bad else "?"))
seeds = list(by_seed)
for a, b in zip(seeds, seeds[1:]):
    if by_seed[a]["gameplay"] == by_seed[b]["gameplay"]:
        problems.append("seeds %d and %d played the same match: the RNG is not reaching gameplay" % (a, b))
json.dumps({
    "pass": not problems,
    "problems": problems,
    "runs": [{"seed": r["seed"], "hash_at_%d" % TICKS: r["hashes"].get(TICKS)} for r in runs],
})
