#!/usr/bin/env python3
"""Generates gauntlet/status/gauntlet-status.html from gauntlet/status/slices.json.

Each gauntlet round updates slices.json (round count, verdict, current
largest gap, 1-10 trend score) for its slice; this script re-renders the
static status page from that data. The loop does not stop on its own —
this page exists so a human can supervise it (see ARCHITECTURE.md).

Usage: generate_status_page.py [slices.json] [output.html]
"""
import html
import json
import sys
from pathlib import Path

DEFAULT_SLICES = Path(__file__).resolve().parents[2] / "gauntlet/status/slices.json"
DEFAULT_OUTPUT = Path(__file__).resolve().parents[2] / "gauntlet/status/gauntlet-status.html"

TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Gauntlet Status</title>
<style>
  body {{ font-family: -apple-system, sans-serif; margin: 2rem; background: #111; color: #eee; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ border: 1px solid #333; padding: 0.5rem 0.75rem; text-align: left; }}
  th {{ background: #1c1c1c; }}
  .verdict-ours {{ color: #7cd67c; }}
  .verdict-theirs {{ color: #e08080; }}
  .verdict-pending {{ color: #ccc; }}
  caption {{ text-align: left; margin-bottom: 0.5rem; color: #999; }}
</style>
</head>
<body>
<h1>Gauntlet Status</h1>
<table>
<caption>Generated from gauntlet/status/slices.json. Ratchet keeps the best candidate; replaced only on head-to-head win.</caption>
<thead>
<tr><th>Slice</th><th>Round</th><th>Verdict</th><th>Trend</th><th>Largest gap</th></tr>
</thead>
<tbody>
{rows}
</tbody>
</table>
</body>
</html>
"""

ROW = """<tr>
<td>{name}</td>
<td>{round}</td>
<td class="verdict-{verdict_class}">{verdict}</td>
<td>{trend}/10</td>
<td>{gap}</td>
</tr>"""


def verdict_class(verdict: str) -> str:
    v = verdict.lower()
    if "ours" in v:
        return "ours"
    if "theirs" in v or "reference" in v:
        return "theirs"
    return "pending"


def render(slices: list[dict]) -> str:
    rows = []
    for s in slices:
        rows.append(ROW.format(
            name=html.escape(s.get("name", "?")),
            round=s.get("round", 0),
            verdict=html.escape(s.get("verdict", "pending")),
            verdict_class=verdict_class(s.get("verdict", "pending")),
            trend=s.get("trend", "-"),
            gap=html.escape(s.get("largest_gap", "-")),
        ))
    return TEMPLATE.format(rows="\n".join(rows))


def main() -> int:
    slices_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SLICES
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT

    slices = json.loads(slices_path.read_text()) if slices_path.exists() else []
    output_path.write_text(render(slices))
    print(f"wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
