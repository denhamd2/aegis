#!/usr/bin/env python3
"""Capture actual WebGL intro compositions and gameplay cameras; no asset mockups."""
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

async def run(web, evidence):
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence/'broadcast_web_check.json').unlink(missing_ok=True)
    server = ThreadingHTTPServer(('127.0.0.1',0), partial(QuietHandler,directory=str(web)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    errors=[]
    checks=[]
    try:
        async with async_playwright() as p:
            browser=await p.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
                args=['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            page=await browser.new_page(viewport={'width':1280,'height':720},device_scale_factor=1)
            page.on('pageerror',lambda e: errors.append(str(e)))
            page.on('console',lambda m: errors.append(m.text) if m.type=='error' else None)
            try:
                await page.goto(f'http://127.0.0.1:{server.server_address[1]}/index.html?software=1',wait_until='domcontentloaded')
                await page.wait_for_function('window.BEECHLAWN_MENU_READY === true',timeout=60000)
                await page.mouse.click(300*.8,750*.8)
                await page.wait_for_timeout(700)
                await page.screenshot(path=str(evidence/'camera_options.png'))
                await page.keyboard.press('Escape')
                await page.mouse.click(450*.8,546*.8)
                await page.mouse.click(300*.8,670*.8)
                await page.wait_for_function('window.BEECHLAWN_MATCH_READY === true && window.BEECHLAWN_INTRO_ACTIVE === true',timeout=90000)
                # Actor count alone misses duplicated runtime-added visual rigs.
                assert await page.evaluate('window.BEECHLAWN_PLAYER_RIGS === 22')
                checks.append('one visible skeleton per player')
                # Debug callback holds each composition, while normal shipped intro
                # plays on its own timeline. This does not alter release behavior.
                for shot in ['venue','walk','goal','net','fans','lineup','portrait','keeper','pitch','ball','warmup','handoff']:
                    await page.evaluate('(id) => window.BEECHLAWN_INTRO_SHOT(id)',shot)
                    await page.wait_for_timeout(450)
                    await page.screenshot(path=str(evidence/f'intro_{shot}.png'))
                    checks.append('rendered intro '+shot)
                    print('CAPTURED',shot,flush=True)
                await page.keyboard.press('Space')
                await page.wait_for_function('window.BEECHLAWN_INTRO_DONE === true && window.BEECHLAWN_MATCH_STARTED === true',timeout=30000)
                checks.append('skip and AI kickoff')
                # Capture presets before play advances too far. Freeze callback
                # cannot be used because it pauses input too; C remains live here.
                for camera in ['close_broadcast','dynamic_wide','stadium','live_broadcast','fan_view','blimp','vertical','player','field_side']:
                    await page.wait_for_function('(id) => window.BEECHLAWN_CAMERA_PRESET === id',arg=camera,timeout=15000)
                    await page.wait_for_timeout(1000)
                    await page.screenshot(path=str(evidence/f'camera_{camera}.png'))
                    checks.append('rendered camera '+camera)
                    await page.keyboard.press('c')
                if errors:
                    raise RuntimeError('\n'.join(errors))
                report={'result':'PASS','renderer':'Godot Compatibility / Chromium SwiftShader','checks':checks,
                    'native_M1_performance':'not measured','console_errors':errors}
                (evidence/'broadcast_web_check.json').write_text(json.dumps(report,indent=2)+'\n')
                print(json.dumps(report),flush=True)
            finally:
                await page.goto('about:blank',wait_until='commit',timeout=5000)
                await browser.close()
    finally:
        server.shutdown()
        server.server_close()

if __name__=='__main__':
    asyncio.run(run(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve()))
