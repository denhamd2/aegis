#!/usr/bin/env python3
"""Capture paused physics checkpoints, retaining real motion between them."""
import asyncio
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import sys
import threading

from playwright.async_api import async_playwright
from check_title_web import QuietHandler


async def run(web: Path, evidence: Path):
    evidence.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(web)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    report = {"renderer": "Godot Compatibility / Chromium SwiftShader", "scenarios": {}, "errors": []}
    try:
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
            try:
                for scenario, expected in [("pass", "pass"), ("shot", "shot"), ("keeper", "goalkeeper_save")]:
                    page = await browser.new_page(viewport={"width": 640, "height": 360}, device_scale_factor=1)
                    page.on("pageerror", lambda error: report["errors"].append(str(error)))
                    page.on("console", lambda message: report["errors"].append(message.text) if message.type == "error" else None)
                    directory = evidence / scenario
                    directory.mkdir(exist_ok=True)
                    snapshots = []
                    await page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html?software=1&scenario={scenario}", wait_until="domcontentloaded")
                    for tick in range(6, 49, 6):
                        await page.wait_for_function("(tick) => window.BR_GAMEPLAY_CAPTURE?.tick === tick", arg=tick, timeout=60000)
                        # Allow the paused final pose to reach the WebGL canvas.
                        await page.wait_for_timeout(150)
                        snapshots.append(await page.evaluate("window.BR_GAMEPLAY_CAPTURE"))
                        await page.locator("canvas").screenshot(path=str(directory / f"frame_{tick:03}.png"))
                        if tick < 48:
                            await page.evaluate("window.BR_GAMEPLAY_CONTINUE()")
                    events = snapshots[-1]["events"]
                    # Preserve a completed scenario even if a later scenario fails.
                    (directory / "snapshots.json").write_text(json.dumps(snapshots, indent=2) + "\n")
                    assert sum(event["event"] == expected for event in events) == 1, (scenario, events)
                    report["scenarios"][scenario] = snapshots
                    print("GAMEPLAY_WEB", scenario, events, flush=True)
                    await page.close()
            finally:
                await browser.close()
        assert not report["errors"], report["errors"]
        report["result"] = "PASS"
        (evidence / "web_motion_report.json").write_text(json.dumps(report, indent=2) + "\n")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    asyncio.run(run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()))
