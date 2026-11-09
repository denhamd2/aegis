#!/usr/bin/env python3
"""Pick the gdUnit suites a change can affect, for CI.

Why this exists
---------------
The suite has 151 suites and 50 of them instantiate `scenes/match.tscn`. A doc
edit, a workflow tweak or a change to one AI file does not need all of that;
running it anyway is what made every batch cost a full regression. The quality
plan (ID 7) asks for affected-subsystem selection while keeping full regressions
for broad changes, so this script must be biased towards running too much
rather than too little.

How a suite is judged affected
------------------------------
`game/` is indexed as a dependency graph:

* `res://` references in scripts, scenes and resources (the same paths Godot
  resolves), and
* global names: `class_name X` declarations and project autoloads used by name.

A changed file marks every file that can reach it, transitively, and any
`tests/test_*.gd` in that set is selected. A change that cannot be attributed
safely selects the whole suite:

* `project.godot`, `export_presets.cfg`, `game/addons/**`, this script, the CI
  workflow, and non-test files under `game/tests/**` (shared fixtures);
* a `game/` change that no suite reaches (silence is not evidence of safety);
* a selection at or above `--max-fraction` of all suites (the fixed cost of
  enumerating them is no longer worth it).

Changes outside `game/` (docs, tools, workflow notes) select no suites. That is
deliberate: they cannot alter the game the suites measure.

Usage
-----
    python3 tools/ci/select_tests.py --changed game/core/ai/wrestler_ai.gd
    python3 tools/ci/select_tests.py --base origin/main --head HEAD --json
    python3 tools/ci/select_tests.py --base HEAD~1 --output "$RUNNER_TEMP/tests.txt"

The `--output` file holds one `res://tests/...gd` path per line, ready for the
GdUnit `-a` arguments. `mode=full` means run `-a res://tests` instead.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

GAME_DIR = "game"
TEST_DIR = "tests"
SKIP_DIRS = {".godot", "addons", "reports", "build", "__pycache__"}
TEXT_SUFFIXES = {
    ".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".shader",
    ".gdshader", ".material", ".res", ".tres",
}

# Changing any of these can alter behaviour everywhere, so the graph answer is
# not trusted. Keep this short: each entry is a reason to pay for the full run.
FULL_SUITE_PATHS = {
    "game/project.godot",
    "game/export_presets.cfg",
    ".github/workflows/ci.yml",
    "tools/ci/select_tests.py",
    "tools/ci/profile_suite.py",
}
FULL_SUITE_PREFIXES = ("game/addons/",)

RES_REF = re.compile(r"res://[A-Za-z0-9_./%+@~-]+")
CLASS_NAME = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
AUTOLOAD_LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\"\*?(res://[^\"]+)\"",
                           re.MULTILINE)
# One identifier token, read in a single pass over each file. Testing every
# declared name separately (798 files x 120 names) re-read 70 MB of text 120
# times and took minutes; a token scan visits it once.
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def to_res(path: str) -> str:
    """Repo-relative `game/...` path -> `res://...`, or '' if outside game/."""
    if path == GAME_DIR:
        return "res://"
    if path.startswith(GAME_DIR + "/"):
        return "res://" + path[len(GAME_DIR) + 1:]
    return ""


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def index(root: Path):
    """Return (files, deps, class_names, autoloads) for the Godot project."""
    game = root / GAME_DIR
    files: set[str] = set()
    texts: dict[str, str] = {}
    for path in sorted(game.rglob("*")):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(game).parts):
            continue
        if path.suffix not in TEXT_SUFFIXES:
            continue
        res = to_res(rel(path, root))
        if not res:
            continue
        files.add(res)
        texts[res] = read(path)

    class_names: dict[str, str] = {}
    for res, text in texts.items():
        match = CLASS_NAME.search(text)
        if match and res.endswith(".gd"):
            class_names.setdefault(match.group(1), res)

    autoloads: dict[str, str] = {}
    project = texts.get("res://project.godot", "")
    if "[autoload]" in project:
        section = project.split("[autoload]", 1)[1].split("\n[", 1)[0]
        for name, res in AUTOLOAD_LINE.findall(section):
            autoloads[name] = res

    deps: dict[str, set[str]] = {res: set() for res in files}
    # Names a file can use without a res:// path: every class_name and every
    # autoload. One pass over each file's identifier tokens resolves all of
    # them (see IDENT).
    names: dict[str, str] = dict(autoloads)
    names.update(class_names)
    for res, text in texts.items():
        found = set(RES_REF.findall(text))
        # Resource paths can be written with a query/fragment or an extra
        # character from surrounding punctuation; keep only real files.
        for ref in found:
            ref = ref.rstrip(".,;:)")
            if ref in files:
                deps[res].add(ref)
        for token in IDENT.finditer(text):
            target = names.get(token.group(0))
            if target is not None and target != res:
                deps[res].add(target)
    return files, deps, class_names, autoloads


def all_tests(files: set[str]) -> list[str]:
    return sorted(
        f for f in files
        if f.startswith("res://" + TEST_DIR + "/")
        and f.endswith(".gd")
        and f.rsplit("/", 1)[-1].startswith("test_")
    )


def reverse_graph(deps: dict[str, set[str]]) -> dict[str, set[str]]:
    reverse: dict[str, set[str]] = {f: set() for f in deps}
    for src, targets in deps.items():
        for target in targets:
            reverse.setdefault(target, set()).add(src)
    return reverse


def dependents_of(changed: set[str], reverse: dict[str, set[str]]) -> set[str]:
    seen: set[str] = set()
    queue = deque(changed)
    while queue:
        current = queue.popleft()
        if current in seen:
            continue
        seen.add(current)
        queue.extend(reverse.get(current, ()))
    return seen


def full_reason(changed: list[str]) -> str | None:
    for path in changed:
        if path in FULL_SUITE_PATHS:
            return f"{path} can affect every suite"
        if any(path.startswith(prefix) for prefix in FULL_SUITE_PREFIXES):
            return f"{path} is shared engine/addon code"
        if path.startswith("game/" + TEST_DIR + "/"):
            name = path.rsplit("/", 1)[-1]
            if not name.startswith("test_"):
                return f"{path} is a shared test fixture"
    return None


def select(root: Path, changed: list[str], max_fraction: float, force_full: bool):
    reason = full_reason(changed)
    game_changed = [p for p in changed if to_res(p)]
    # A change that cannot reach game/ needs no index at all. This is the
    # common docs/workflow-only push, and indexing 70 MB of scripts for an
    # answer of "none" was seven seconds of the CI job.
    if not force_full and not reason and not game_changed:
        return {"mode": "none", "reason": "no game files changed", "tests": [],
                "selected": 0, "total": 0}

    files, deps, _, _ = index(root)
    tests = all_tests(files)
    if force_full:
        return {"mode": "full", "reason": "--full requested", "tests": tests,
                "selected": len(tests), "total": len(tests)}

    if reason:
        return {"mode": "full", "reason": reason, "tests": tests,
                "selected": len(tests), "total": len(tests)}

    changed_res = {to_res(p) for p in game_changed}
    # A path that is not indexed (new file, ignored suffix) cannot be resolved.
    unresolved = sorted(r for r in changed_res if r not in files)
    if unresolved:
        return {"mode": "full",
                "reason": "cannot resolve " + ", ".join(unresolved),
                "tests": tests, "selected": len(tests), "total": len(tests)}

    reachable = dependents_of(changed_res, reverse_graph(deps))
    selected = sorted(set(t for t in reachable if t in tests) | (changed_res & set(tests)))

    if not selected:
        return {"mode": "full",
                "reason": "no suite reaches " + ", ".join(sorted(changed_res)),
                "tests": tests, "selected": len(tests), "total": len(tests)}
    if tests and len(selected) / len(tests) >= max_fraction:
        return {"mode": "full",
                "reason": f"{len(selected)}/{len(tests)} suites affected "
                          f"(threshold {max_fraction:.0%})",
                "tests": tests, "selected": len(tests), "total": len(tests)}

    return {"mode": "subset",
            "reason": f"{len(selected)}/{len(tests)} suites reach the change",
            "tests": selected, "selected": len(selected), "total": len(tests)}


def git_changed(root: Path, base: str, head: str) -> list[str]:
    """Paths changed between base and head.

    Deletions are included on purpose: a deleted game file must reach select()
    so it can force a full run instead of looking like an unrelated change.
    Rename detection is disabled for the same reason: a game file moved out of
    game/ would otherwise be reported only as its new, harmless-looking path.
    """
    result = subprocess.run(
        # T (type change, e.g. a game file replaced by a symlink) is also a
        # change to the project even when the path stays the same.
        ["git", "diff", "--name-only", "--no-renames", "--diff-filter=ACMRDT",
         base, head],
        cwd=root, capture_output=True, text=True, check=True,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="repository root (default: the checkout containing this script)")
    parser.add_argument("--base", help="git revision to diff from")
    parser.add_argument("--head", default="HEAD", help="git revision to diff to (default HEAD)")
    parser.add_argument("--changed", action="append", default=[],
                        help="changed repo-relative path; repeatable. Overrides --base")
    parser.add_argument("--changed-file-list", type=Path,
                        help="file holding one changed path per line")
    parser.add_argument("--output", type=Path,
                        help="write selected res:// test paths, one per line")
    parser.add_argument("--json", action="store_true", help="print a JSON report")
    parser.add_argument("--full", action="store_true", help="force the full suite")
    parser.add_argument("--max-fraction", type=float, default=0.8,
                        help="run everything once this share of suites is affected")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    if not (root / GAME_DIR).is_dir():
        parser.error(f"{root} does not contain {GAME_DIR}/")

    changed = list(args.changed)
    if args.changed_file_list:
        changed += [line.strip() for line in
                    args.changed_file_list.read_text(encoding="utf-8").splitlines()
                    if line.strip()]
    if not changed and not args.full:
        if not args.base:
            parser.error("give --changed, --changed-file-list or --base")
        changed = git_changed(root, args.base, args.head)
    # Normalise separators and drop blank/absolute entries. Only a leading
    # "./" is ours to remove: lstrip("./") would also eat the dot in
    # ".github/workflows/ci.yml" and silently turn a full-suite trigger into
    # "no game files changed".
    normalised = set()
    for p in changed:
        p = p.strip().replace("\\", "/")
        while p.startswith("./"):
            p = p[2:]
        if p and not p.startswith("/"):
            normalised.add(p)
    changed = sorted(normalised)

    report = select(root, changed, args.max_fraction, args.full)
    report["changed"] = changed

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("".join(t + "\n" for t in report["tests"]),
                               encoding="utf-8")

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"{report['mode']}: {report['reason']}")
        for test in report["tests"]:
            print(test)
    return 0


if __name__ == "__main__":
    sys.exit(main())
