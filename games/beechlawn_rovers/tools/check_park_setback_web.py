#!/usr/bin/env python3
"""Render the corrected park spacing in the actual 11v11 Web scene."""
import asyncio,json,shutil,sys,threading
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer
from playwright.async_api import async_playwright
from PIL import Image
from check_title_web import QuietHandler

async def run(web,evidence):
    evidence.mkdir(parents=True,exist_ok=True)
    (evidence/'web_review.json').unlink(missing_ok=True)
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(web)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    errors=[]
    try:
        async with async_playwright() as p:
            browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,
                args=['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            page=await browser.new_page(viewport={'width':1280,'height':720},device_scale_factor=1)
            page.on('pageerror',lambda e:errors.append(str(e)))
            page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
            try:
                await page.goto(f'http://127.0.0.1:{server.server_address[1]}/index.html?software=1',wait_until='domcontentloaded')
                await page.wait_for_function('window.BEECHLAWN_MENU_READY === true',timeout=60000)
                await page.mouse.click(450*.8,546*.8)
                await page.mouse.click(300*.8,670*.8)
                await page.wait_for_function('window.BEECHLAWN_MATCH_READY === true && window.BEECHLAWN_INTRO_ACTIVE === true',timeout=90000)
                assert await page.evaluate('window.BEECHLAWN_PLAYER_RIGS === 22')
                for shot in ['venue','fans']:
                    await page.evaluate('(id)=>window.BEECHLAWN_INTRO_SHOT(id)',shot)
                    await page.wait_for_timeout(700)
                    await page.screenshot(path=str(evidence/f'after_intro_{shot}.png'))
                    print('CAPTURED intro',shot,flush=True)
                await page.keyboard.press('Space')
                await page.wait_for_function('window.BEECHLAWN_MATCH_STARTED === true',timeout=30000)
                await page.evaluate("window.BEECHLAWN_FREEZE_FRAME()")
                await page.evaluate("window.BEECHLAWN_SITE_VIEW('broadcast')")
                await page.wait_for_timeout(1200)
                await page.screenshot(path=str(evidence/'after_broadcast.png'))
                print('CAPTURED broadcast',flush=True)
                await page.evaluate("window.BEECHLAWN_SITE_VIEW('overhead')")
                await page.wait_for_timeout(1200)
                await page.screenshot(path=str(evidence/'after_site_overhead.png'))
                print('CAPTURED whole site',flush=True)
                # A valid WebGL context alone does not establish that the ground
                # rendered. Catch sky/flat-grey pixels where turf should be.
                image=Image.open(evidence/'after_intro_venue.png').convert('RGB')
                pixels=list(image.crop((50,380,1230,590)).getdata())
                grass_fraction=sum(g > r*1.2 and g > b*1.3 and max(r,g,b)-min(r,g,b)>35 for r,g,b in pixels)/len(pixels)
                assert grass_fraction>0.25, f'Ground turf not visible: green coverage {grass_fraction:.3f}'
                assert not errors,errors
                report={'result':'PASS','renderer':'Godot Compatibility / Chromium SwiftShader',
                    'checks':['22 player rigs','intro venue composition','touchline spectator composition','AI kickoff after skip','close broadcast preserved','whole-site debug review'],
                    'grass_pixel_fraction':round(grass_fraction,3),'console_errors':errors,'native_M1_performance':'not measured','scope':'grass setback and placement; final venue fidelity remains open'}
                (evidence/'web_review.json').write_text(json.dumps(report,indent=2)+'\n')
                print(json.dumps(report),flush=True)
            finally:
                await page.goto('about:blank',wait_until='commit',timeout=5000)
                await browser.close()
    finally:
        server.shutdown();server.server_close()

if __name__=='__main__':asyncio.run(run(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve()))
