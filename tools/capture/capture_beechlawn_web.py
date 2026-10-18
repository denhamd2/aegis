#!/usr/bin/env python3
"""Capture a Beechlawn Web export without Chromium's blocking --screenshot mode.

Godot's WebGL canvas runs a continuous requestAnimationFrame loop, so Chromium's
CLI screenshot mode can wait indefinitely for virtual-time/idle completion. This
script owns the browser lifecycle and takes a frame explicitly after the canvas
is ready. The Web export uses Godot's Compatibility renderer; this is a
functional/layout capture, not a Mac Forward+/Metal look reference.

Requirements: Python Playwright and a local Chromium/Chrome executable.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import shutil
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from playwright.async_api import async_playwright


ROOT = Path(__file__).resolve().parents[2]
WEB_ROOT = ROOT / "games/beechlawn_rovers/build/web"


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        pass


async def capture(output: Path, width: int, height: int, wait_seconds: float,
                  web_root: Path = WEB_ROOT, query: str = "", ready_expression: str = "", start_match: bool = False) -> None:
    if not (web_root / "index.html").is_file():
        raise FileNotFoundError(f"Web export is missing: {web_root / 'index.html'}")
    chromium = os.environ.get("CHROMIUM_BIN") or shutil.which("chromium") \
        or shutil.which("chromium-browser") or shutil.which("google-chrome")
    if not chromium:
        raise FileNotFoundError("Install Chromium or set CHROMIUM_BIN to its executable")

    handler = partial(QuietHandler, directory=str(web_root))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_address[1]}/index.html" + ("?" + query if query else "")
    errors: list[str] = []
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(
                executable_path=chromium,
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--use-gl=angle",
                    "--use-angle=swiftshader",
                    "--enable-unsafe-swiftshader",
                    "--disable-background-networking",
                ],
            )
            try:
                page = await browser.new_page(
                    viewport={"width": width, "height": height}, device_scale_factor=1
                )
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("console", lambda message: print(message.text, flush=True)
                        if message.type == "error" or "SHANE_ASSET_REVIEW_READY" in message.text else None)
                page.on(
                    "console",
                    lambda message: errors.append(message.text)
                    if message.type == "error"
                    else None,
                )
                response = await page.goto(url, wait_until="domcontentloaded", timeout=90000)
                if response is None or response.status != 200:
                    raise RuntimeError(f"Web export returned HTTP {response.status if response else 'no response'}")
                await page.wait_for_function(
                    "document.querySelector('canvas') && document.querySelector('canvas').width > 0",
                    timeout=90000,
                )
                if ready_expression:
                    await page.wait_for_function(ready_expression, timeout=60000)
                if start_match:
                    await page.evaluate("document.querySelector('canvas').focus()")
                    await page.keyboard.down('e')
                    await page.wait_for_function("window.BEECHLAWN_MATCH_STARTED === true",timeout=30000)
                    await page.keyboard.up('e')
                await page.wait_for_timeout(max(0.0, wait_seconds) * 1000)
                await page.evaluate("if (window.BEECHLAWN_FREEZE_FRAME) window.BEECHLAWN_FREEZE_FRAME()")
                await page.wait_for_timeout(1200)
                await page.screenshot(path=str(output), timeout=30000)
                print(f"Captured {width}x{height} WebGL canvas: {output}")
                if errors:
                    raise RuntimeError("Browser console errors:\n" + "\n".join(errors))
                print("Browser page errors: none")
            finally:
                # Stop the game's perpetual WebGL/requestAnimationFrame loop
                # before closing Chromium. Otherwise teardown can wait on the
                # active WebAssembly page even though the PNG is already saved.
                try:
                    await page.goto("about:blank", wait_until="commit", timeout=5000)
                except Exception:
                    pass
                await browser.close()
    finally:
        server.shutdown()
        server.server_close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="PNG destination")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--wait", type=float, default=3.0, help="settle time after the Godot canvas starts")
    parser.add_argument("--web-root", type=Path, default=WEB_ROOT, help="isolated export directory")
    parser.add_argument("--query", default="", help="optional review-scene query, e.g. view=portrait")
    parser.add_argument("--ready-expression", default="", help="optional JavaScript first-frame readiness check")
    parser.add_argument("--start-match", action="store_true", help="press the real kickoff key after readiness")
    args = parser.parse_args()
    asyncio.run(capture(args.output.resolve(), args.width, args.height, args.wait,
                        args.web_root.resolve(), args.query, args.ready_expression, args.start_match))


if __name__ == "__main__":
    main()
