#!/usr/bin/env python3
"""One-time HUMAN login to Runway Web in an isolated, persistent Chromium profile.

No bot actions, no payment, no video generation, no credential extraction.
Stop runway-login-browser.service normally after completing login to flush cookies.
"""
import asyncio
import signal
from pathlib import Path
from playwright.async_api import async_playwright

PROFILE = Path("/var/lib/andorra24-browser-use/runway-profile")

async def main():
    PROFILE.mkdir(mode=0o700, parents=True, exist_ok=True)
    finished = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, finished.set)
    async with async_playwright() as playwright:
        context = await playwright.chromium.launch_persistent_context(
            user_data_dir=str(PROFILE),
            headless=False,
            viewport={"width": 1360, "height": 760},
            accept_downloads=False,
            args=["--no-first-run"],
        )
        try:
            page = context.pages[0] if context.pages else await context.new_page()
            try:
                await page.goto("https://app.runwayml.com/", wait_until="domcontentloaded", timeout=60000)
            except Exception as exc:
                print(f"Runway navigation not yet ready: {type(exc).__name__}", flush=True)
            print("HUMAN_LOGIN_BROWSER_READY; user must authenticate using official Runway UI", flush=True)
            await finished.wait()
        finally:
            await context.close()
            print("HUMAN_LOGIN_BROWSER_CLOSED; profile retained privately", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
