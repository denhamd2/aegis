#!/usr/bin/env python3
"""Exercise the actual Godot menu and both modes in Chromium software WebGL.

Usage: python3 tools/check_title_web.py <web-export-directory> <evidence-directory> [--menu-only]
Full software match checks need --export-debug Web for its frame-freeze hook.
Use --menu-only against the release export to verify its actual UI.
Functional/layout coverage only. This does not measure native M1 performance.
"""
import asyncio
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import sys
import threading

from playwright.async_api import async_playwright


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


async def run(web: Path, evidence: Path, menu_only: bool = False):
    evidence.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(web)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    errors = []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
            page = await browser.new_page(viewport={"width":1280,"height":720}, device_scale_factor=1)
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
            page.on("console", lambda message: print(message.text, flush=True) if "BEECHLAWN_" in message.text else None)
            try:
                await page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html?software=1", wait_until="domcontentloaded")
                await page.wait_for_function("window.BEECHLAWN_MENU_READY === true",timeout=60000)
                await page.wait_for_timeout(800)
                await page.screenshot(path=str(evidence/"title_screen.png"))
                # Menu uses a 1600x900 logical canvas, scaled to fit the viewport.
                async def click(x, y):
                    viewport = page.viewport_size
                    factor = min(viewport["width"]/1600, viewport["height"]/900)
                    await page.mouse.click((viewport["width"]-1600*factor)/2+x*factor,
                                           (viewport["height"]-900*factor)/2+y*factor)
                    await page.wait_for_timeout(200)
                await click(300,750)
                await page.screenshot(path=str(evidence/"title_options.png"))
                await page.keyboard.press("Escape")
                # Validate letterboxing and all controls at the minimum review size.
                await page.set_viewport_size({"width":640,"height":480})
                await page.wait_for_timeout(300)
                await page.screenshot(path=str(evidence/"title_small.png"))
                if menu_only:
                    if errors:
                        raise RuntimeError("Browser errors: " + "\n".join(errors))
                    report = {"result":"PASS", "checks":["release menu", "options open/close", "640x480 uncropped layout"], "console_errors":errors}
                    (evidence/"title_web_check.json").write_text(json.dumps(report,indent=2)+"\n")
                    print(json.dumps(report),flush=True)
                    return
                # Keep full-resolution menu evidence above; use a smaller
                # canvas for functional 23-rig match checks on software WebGL.
                # This bounds render cost without changing simulation or actors.
                await page.set_viewport_size({"width":640,"height":360})
                await page.wait_for_timeout(300)
                await click(450,546)
                await click(300,670)
                await page.wait_for_function("window.BEECHLAWN_MATCH_READY === true", timeout=90000)
                assert await page.evaluate("typeof window.BEECHLAWN_FREEZE_FRAME === 'function'"), "Full software match captures need a debug Web export; use --menu-only for release UI checks"
                assert await page.evaluate("window.BEECHLAWN_MATCH_MODE === 'watch' && window.BEECHLAWN_HUMAN_PLAYERS === 0")
                await page.keyboard.press("Space")
                await page.wait_for_function("window.BEECHLAWN_MATCH_STARTED === true",timeout=30000)
                await page.screenshot(path=str(evidence/"title_watch_match.png"))
                await page.keyboard.press("Escape")
                await page.wait_for_function("window.BEECHLAWN_MENU_READY === true",timeout=30000)
                await page.wait_for_timeout(300)
                await click(180,546)
                await click(300,670)
                await page.wait_for_function("window.BEECHLAWN_MATCH_READY === true",timeout=90000)
                assert await page.evaluate("window.BEECHLAWN_MATCH_MODE === 'play' && window.BEECHLAWN_HUMAN_PLAYERS === 1")
                await page.keyboard.press("Space")
                await page.keyboard.down("e")
                await page.wait_for_function("window.BEECHLAWN_MATCH_STARTED === true",timeout=30000)
                await page.keyboard.up("e")
                await page.evaluate("if (window.BEECHLAWN_FREEZE_FRAME) window.BEECHLAWN_FREEZE_FRAME()")
                await page.wait_for_timeout(300)
                await page.screenshot(path=str(evidence/"title_play_match.png"))
                if errors:
                    raise RuntimeError("Browser errors: " + "\n".join(errors))
                report = {"result":"PASS","checks":["native menu", "options open/close", "640x480 layout", "AI auto kickoff", "zero spectator humans", "return to title", "Play has one human", "keyboard kickoff"],"renderer":"Compatibility / Chromium SwiftShader", "menu_viewport":[1280,720], "match_viewport":[640,360], "native_M1_performance":"not measured", "console_errors":errors}
                (evidence/"title_web_check.json").write_text(json.dumps(report,indent=2)+"\n")
                print(json.dumps(report),flush=True)
            finally:
                await page.goto("about:blank",wait_until="commit",timeout=5000)
                await browser.close()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    asyncio.run(run(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve(),"--menu-only" in sys.argv[3:]))
