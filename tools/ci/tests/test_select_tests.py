#!/usr/bin/env python3
"""Self-tests for tools/ci/select_tests.py.

These run without Godot: the selector only reads text. They build a small
fixture project in a temporary directory so the real repository's growing
test list can never make them drift.

    python3 -m unittest discover -s tools/ci/tests -v
"""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import select_tests as sel  # noqa: E402


def _write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _suite(name: str, body: str) -> str:
    return "extends GdUnitTestSuite\n\n" + body + "\n"


class SelectorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="aegis-select-"))
        self.addCleanup(shutil.rmtree, self.root, True)
        _write(self.root, "game/project.godot",
               '[application]\n\nconfig/name="Fixture"\n\n'
               '[autoload]\n\nGameBus="*res://core/bus.gd"\n')
        _write(self.root, "game/core/bus.gd", "extends Node\n")
        _write(self.root, "game/core/widget.gd",
               "class_name Widget\nextends RefCounted\n")
        _write(self.root, "game/core/spinner.gd",
               "class_name Spinner\nextends RefCounted\n\nvar widget := Widget.new()\n")
        _write(self.root, "game/core/ui/screen.gd",
               "class_name Screen\nextends Control\n\nvar spinner := Spinner.new()\n")
        _write(self.root, "game/core/orphan.gd",
               "class_name Orphan\nextends RefCounted\n")
        _write(self.root, "game/scenes/match.tscn",
               '[gd_scene load_steps=2 format=3]\n\n'
               '[ext_resource type="Script" path="res://core/ui/screen.gd" id="1"]\n')
        _write(self.root, "game/tests/test_widget.gd",
               _suite("widget", "func test_it() -> void:\n\tvar w := Widget.new()\n"))
        _write(self.root, "game/tests/test_scene.gd",
               _suite("scene", 'const MATCH := preload("res://scenes/match.tscn")\n'))
        _write(self.root, "game/tests/test_bus.gd",
               _suite("bus", "func test_it() -> void:\n\tGameBus.ping()\n"))
        _write(self.root, "game/tests/helpers.gd", "extends RefCounted\n")
        _write(self.root, "README.md", "# Fixture\n")

    # --- the graph ---------------------------------------------------------

    def _select(self, *changed: str, max_fraction: float = 0.8) -> dict:
        return sel.select(self.root, list(changed), max_fraction, False)

    def test_a_direct_test_edit_selects_only_that_suite(self) -> None:
        report = self._select("game/tests/test_widget.gd")
        self.assertEqual(report["mode"], "subset")
        self.assertEqual(report["tests"], ["res://tests/test_widget.gd"])

    def test_class_name_use_reaches_the_test(self) -> None:
        # Widget is used by Spinner, Spinner by Screen, Screen by match.tscn,
        # and test_widget uses Widget directly.
        report = self._select("game/core/widget.gd")
        self.assertEqual(report["mode"], "subset")
        self.assertEqual(report["tests"],
                         ["res://tests/test_scene.gd", "res://tests/test_widget.gd"])

    def test_autoload_use_reaches_the_test(self) -> None:
        report = self._select("game/core/bus.gd")
        self.assertEqual(report["mode"], "subset")
        self.assertEqual(report["tests"], ["res://tests/test_bus.gd"])

    def test_a_scene_reference_reaches_its_test(self) -> None:
        report = self._select("game/scenes/match.tscn")
        self.assertEqual(report["mode"], "subset")
        self.assertEqual(report["tests"], ["res://tests/test_scene.gd"])

    def test_the_closure_is_transitive(self) -> None:
        report = self._select("game/core/ui/screen.gd")
        self.assertEqual(report["tests"], ["res://tests/test_scene.gd"])

    def test_a_name_inside_a_longer_word_is_not_a_use(self) -> None:
        # WidgetFactory must not be read as Widget.
        _write(self.root, "game/tests/test_factory.gd",
               _suite("factory", "func test_it() -> void:\n\tpass # WidgetFactory\n"))
        report = self._select("game/core/widget.gd")
        self.assertNotIn("res://tests/test_factory.gd", report["tests"])

    def test_an_unreached_game_file_falls_back_to_full(self) -> None:
        report = self._select("game/core/orphan.gd")
        self.assertEqual(report["mode"], "full")
        self.assertIn("no suite reaches", report["reason"])

    # --- the conservative fallbacks ---------------------------------------

    def test_a_non_game_change_selects_nothing(self) -> None:
        report = self._select("README.md", "gauntlet/refs/next_steps.md")
        self.assertEqual(report["mode"], "none")
        self.assertEqual(report["tests"], [])

    def test_project_settings_force_full(self) -> None:
        report = self._select("game/project.godot")
        self.assertEqual(report["mode"], "full")

    def test_a_shared_test_fixture_forces_full(self) -> None:
        report = self._select("game/tests/helpers.gd")
        self.assertEqual(report["mode"], "full")
        self.assertIn("shared test fixture", report["reason"])

    def test_a_game_change_that_is_not_indexed_forces_full(self) -> None:
        report = self._select("game/core/brand_new.gd")
        self.assertEqual(report["mode"], "full")
        self.assertIn("cannot resolve", report["reason"])

    def test_a_broad_selection_falls_back_to_full(self) -> None:
        # Every suite reaches Widget, so a low threshold must run everything.
        for name in ("test_a", "test_b", "test_c"):
            _write(self.root, "game/tests/%s.gd" % name,
                   _suite(name, "func test_it() -> void:\n\tWidget.new()\n"))
        report = self._select("game/core/widget.gd", max_fraction=0.5)
        self.assertEqual(report["mode"], "full")
        self.assertIn("threshold", report["reason"])

    # --- the command line --------------------------------------------------

    def _main(self, *argv: str) -> tuple[int, dict]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = sel.main(["--root", str(self.root), *map(str, argv)])
        return code, json.loads(out.getvalue())

    def test_cli_json_reports_the_selection(self) -> None:
        code, report = self._main("--changed", "game/core/widget.gd", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(report["mode"], "subset")
        self.assertEqual(report["selected"], 2)

    def test_cli_does_not_mangle_dot_directories(self) -> None:
        # Regression: lstrip("./") turned ".github/workflows/ci.yml" into
        # "github/workflows/ci.yml", which looked like a docs-only change and
        # skipped the whole suite for a workflow edit.
        code, report = self._main(
            "--changed", ".github/workflows/ci.yml", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(report["mode"], "full")
        self.assertEqual(report["changed"], [".github/workflows/ci.yml"])

    def test_cli_output_file_holds_res_paths(self) -> None:
        out = self.root / "tests.txt"
        code, _ = self._main(
            "--changed", "game/core/bus.gd", "--output", out, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(out.read_text(encoding="utf-8"),
                         "res://tests/test_bus.gd\n")

    def test_cli_full_keeps_every_suite(self) -> None:
        code, report = self._main("--full", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(report["mode"], "full")
        self.assertEqual(report["selected"], 3)

    def test_cli_requires_a_change_source(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            sel.main(["--root", str(self.root)])
        self.assertEqual(caught.exception.code, 2)


class GitDiffTest(unittest.TestCase):
    """Deletions must be reported, so an unresolved path can force a full run."""

    def setUp(self) -> None:
        if shutil.which("git") is None:
            self.skipTest("git is not installed")
        self.root = Path(tempfile.mkdtemp(prefix="aegis-select-git-"))
        self.addCleanup(shutil.rmtree, self.root, True)
        _write(self.root, "game/project.godot", "[application]\n")
        _write(self.root, "game/core/widget.gd", "class_name Widget\n")
        _write(self.root, "game/core/spare.gd", "extends RefCounted\n")
        _write(self.root, "game/tests/test_widget.gd",
               _suite("widget", "func test_it() -> void:\n\tWidget.new()\n"))
        self._git("init", "-q")
        self._git("add", "-A")
        self._git("commit", "-q", "-m", "fixture")

    def _git(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", "-c", "user.name=Aegis", "-c", "user.email=aegis@example.invalid",
             "-c", "commit.gpgsign=false", *args],
            cwd=self.root, check=True, capture_output=True, text=True)

    def test_a_deleted_file_is_reported_as_a_change(self) -> None:
        (self.root / "game/core/spare.gd").unlink()
        self._git("add", "-A")
        self._git("commit", "-q", "-m", "delete spare")
        changed = sel.git_changed(self.root, "HEAD~1", "HEAD")
        self.assertEqual(changed, ["game/core/spare.gd"])

    def test_a_deleted_game_file_forces_full(self) -> None:
        (self.root / "game/core/widget.gd").unlink()
        self._git("add", "-A")
        self._git("commit", "-q", "-m", "delete widget")
        changed = sel.git_changed(self.root, "HEAD~1", "HEAD")
        report = sel.select(self.root, changed, 0.8, False)
        self.assertEqual(report["mode"], "full")
        self.assertIn("cannot resolve", report["reason"])


if __name__ == "__main__":
    unittest.main()
