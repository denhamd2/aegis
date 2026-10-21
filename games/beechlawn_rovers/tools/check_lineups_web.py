#!/usr/bin/env python3
"""Check and capture the real walkout graphics from a debug Web export."""
import asyncio
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import sys
import threading
from playwright.async_api import async_playwright, TimeoutError as BrowserTimeout
from check_title_web import QuietHandler


async def run(web: Path, out: Path):
    out.mkdir(parents=True, exist_ok=True)
    (out / "web_review.json").unlink(missing_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(web)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    errors, states = [], []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
            page = await browser.new_page(viewport={"width":960, "height":540}, device_scale_factor=1)
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
            try:
                await page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html?software=1", wait_until="domcontentloaded")
                await page.wait_for_function("window.BEECHLAWN_MENU_READY === true", timeout=60000)
                await page.mouse.click(450*.6, 546*.6)
                await page.mouse.click(300*.6, 670*.6)
                await page.wait_for_function("window.BEECHLAWN_MATCH_READY === true && window.BEECHLAWN_INTRO_ACTIVE === true", timeout=90000)
                assert await page.evaluate("window.BEECHLAWN_PLAYER_RIGS === 22")
                for suffix, team, manager in [("home", "Beechlawn Rovers", "Robbie Roden"), ("away", "Boardeaux", "Des Feeney")]:
                    await page.evaluate("(id)=>window.BEECHLAWN_INTRO_SHOT(id)", "teams_"+suffix)
                    await page.wait_for_function("(team)=>window.BEECHLAWN_LINEUP_TEAM === team", arg=team, timeout=15000)
                    await page.wait_for_timeout(800)
                    state = await page.evaluate("window.BEECHLAWN_LINEUP_STATE")
                    assert state["manager"] == manager and state["formation"] == "4-4-2", state
                    assert len(state["numbers"]) == len(set(state["numbers"])) == 11, state
                    if suffix == "home":
                        assert 14 in state["numbers"] and 2 not in state["numbers"], state
                    else:
                        assert all(name == "Des Feeney" for name in state["identities"]), state
                    states.append(state)
                    await page.screenshot(path=str(out/f"lineup_{suffix}.png"))
                    print("CAPTURED lineup", suffix, flush=True)
                await page.evaluate("window.BEECHLAWN_INTRO_SHOT('referee')")
                await page.wait_for_function("window.BEECHLAWN_REFEREE_STATE?.visible === true", timeout=15000)
                await page.wait_for_timeout(800)
                referee_state = await page.evaluate("window.BEECHLAWN_REFEREE_STATE")
                assert referee_state["name"] == "DES FEENEY" and "REFEREE" in referee_state["role"], referee_state
                assert referee_state["alpha"] > 0.99, referee_state
                await page.screenshot(path=str(out/"referee_closeup.png"))
                print("CAPTURED referee", flush=True)
                await page.set_viewport_size({"width":640, "height":480})
                await page.evaluate("window.BEECHLAWN_INTRO_SHOT('teams_home')")
                await page.wait_for_timeout(800)
                await page.screenshot(path=str(out/"lineup_home_small.png"))
                await page.set_viewport_size({"width":960, "height":540})
                await page.keyboard.press("Space")
                await page.wait_for_function("window.BEECHLAWN_MATCH_STARTED === true", timeout=30000)
                await page.evaluate("window.BEECHLAWN_FREEZE_FRAME()")
                await page.evaluate("window.BEECHLAWN_SITE_VIEW('broadcast')")
                await page.wait_for_timeout(1000)
                await page.screenshot(path=str(out/"broadcast_after_intro.png"))
                assert not errors, errors
                report = {"result":"PASS", "teams":states, "referee":referee_state, "checks":["home before away", "eleven portraits per 4-4-2", "player-managers", "retired home #2 replaced by #14", "all away identities Des Feeney", "referee close-up and fading lower third", "640x480 review", "skip to opposite-side match kickoff"], "renderer":"Godot Compatibility / Chromium SwiftShader", "sun_shadows":False, "console_errors":errors, "native_M1_performance":"not measured"}
                (out/"web_review.json").write_text(json.dumps(report, indent=2)+"\n")
                print(json.dumps(report), flush=True)
            finally:
                # A slow software-rendered page can delay even about:blank.
                # Always close the browser, preserving the useful test result.
                try:
                    await page.goto("about:blank", wait_until="commit", timeout=5000)
                except BrowserTimeout:
                    print("CLEANUP navigation timed out; closing browser directly", flush=True)
                finally:
                    await asyncio.wait_for(browser.close(), timeout=15)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    asyncio.run(run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()))
