#!/usr/bin/env python3
"""Capture the actual roster head in the isolated Godot Web review scene."""
import argparse
import asyncio
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import threading
from playwright.async_api import async_playwright
from check_title_web import QuietHandler


async def capture(args):
    args.output.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(args.web.resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    errors, captures = [], []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage", "--use-gl=angle",
                      "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
            try:
                page = await browser.new_page(viewport={"width":1280,"height":720}, device_scale_factor=1)
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
                for view in args.views:
                    query = f"software=1&player={args.player}&view={view}&lighting=soft&clean=1"
                    if args.query:
                        query += "&" + args.query
                    async with asyncio.timeout(65):
                        await page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html?{query}", wait_until="domcontentloaded")
                        await page.wait_for_function("window.BEECHLAWN_REVIEW_READY === true", timeout=60000)
                        # A ready continuously redrawing SwiftShader canvas
                        # can still starve screenshot readback. Use the review
                        # scene's post-first-draw freeze hook, as match capture does.
                        await page.evaluate("window.BEECHLAWN_FREEZE_FRAME()")
                        await page.wait_for_timeout(350)
                        filename = f"{args.player}_{view}.png"
                        await page.screenshot(path=str(args.output/filename))
                        lighting = await page.evaluate("window.BEECHLAWN_REVIEW_LIGHTING")
                        captures.append({"file":filename,"view":view,"lighting":lighting})
                        print("CAPTURED", filename, flush=True)
                if errors:
                    raise RuntimeError("Godot/browser review errors: " + json.dumps(errors))
                report = {"result":"PASS", "player":args.player, "captures":captures,
                          "renderer":"Godot Compatibility / Chromium SwiftShader",
                          "console_errors":errors, "native_M1_performance":"not measured"}
                (args.output/"review.json").write_text(json.dumps(report, indent=2)+"\n")
            finally:
                await asyncio.wait_for(browser.close(), timeout=15)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("web", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--player", choices=("shane","des","referee","john","away_keeper","paddy"), required=True)
    parser.add_argument("--views", nargs="+", default=["portrait","threequarter_portrait","profile_portrait"])
    parser.add_argument("--query",default="",help="Additional review-only URL query, e.g. shadows=0")
    asyncio.run(capture(parser.parse_args()))
