#!/usr/bin/env python3
"""Read-only headless Chromium smoke test, without provider access or credits."""
import asyncio
import importlib.metadata
import json
from datetime import datetime, timezone
from playwright.async_api import async_playwright

async def main():
    versions = {name: importlib.metadata.version(name) for name in ('browser-use', 'playwright')}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto('about:blank')
        await browser.close()
    print(json.dumps({
        'checked_at_utc': datetime.now(timezone.utc).isoformat(),
        'status': 'BROWSER_INSTALLED',
        'chromium_launch': 'OK',
        'versions': versions,
        'runway_web_session': 'NOT_VERIFIED',
        'n8n_bridge': 'NOT_VERIFIED',
        'media_generation': 'DISABLED_UNTIL_VERIFIED',
    }))

if __name__ == '__main__':
    asyncio.run(main())
