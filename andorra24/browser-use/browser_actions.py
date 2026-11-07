#!/usr/bin/env python3
"""Controlled browser operations using local authenticated Playwright profiles."""
import re
from pathlib import Path
from urllib.parse import urlparse
STATE=Path('/var/lib/andorra24-browser-use')
SITE_HOSTS={
 'n8n':{'blaxxun.app.n8n.cloud'},
 'runway':{'app.runwayml.com'},
 'youtube':{'studio.youtube.com','www.youtube.com','youtube.com'},
 'drive':{'drive.google.com','docs.google.com'},
}
ASSETS=STATE/'approved-assets'
SHOTS=STATE/'browser-task-screenshots'
DOWNLOADS=STATE/'approved-downloads'
OPS={'navigate','click','fill','press','select','check','uncheck','upload','download','wait','inspect','screenshot'}

def check_url(url,site):
 if not isinstance(url,str) or len(url)>2048: raise ValueError('URL_INVALID')
 p=urlparse(url)
 if p.scheme!='https' or p.hostname not in SITE_HOSTS[site] or p.username or p.password or p.port not in (None,443):
  raise ValueError('URL_OUTSIDE_AUTHORIZED_SITE')
 return url

def verify_task(payload):
 if not isinstance(payload,dict): raise ValueError('PAYLOAD_MUST_BE_OBJECT')
 site=payload.get('site')
 if site not in SITE_HOSTS: raise ValueError('UNKNOWN_SITE')
 steps=payload.get('steps')
 if not isinstance(steps,list) or not (1<=len(steps)<=20): raise ValueError('INVALID_STEPS_COUNT')
 if len(str(payload))>18000: raise ValueError('PAYLOAD_TOO_LARGE')
 for s in steps:
  if not isinstance(s,dict) or s.get('op') not in OPS: raise ValueError('OPERATION_NOT_ALLOWED')
  if s['op']=='navigate': check_url(s.get('url'),site)
  if s['op'] in {'click','fill','press','select','check','uncheck','upload','download','wait'} and not any(k in s for k in ('css','role','label','placeholder','text')): raise ValueError('SELECTOR_REQUIRED')
  for k in ('css','role','name','label','placeholder','text','value','key'):
   if k in s and (not isinstance(s[k],str) or len(s[k])>1200): raise ValueError('FIELD_INVALID')
  if s['op']=='upload':
   name=s.get('file')
   if not isinstance(name,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_. -]{0,180}',name) or name.startswith('.'): raise ValueError('UPLOAD_FILENAME_INVALID')
 return site,steps

def selector(page,s):
 if 'css' in s: return page.locator(s['css']).first
 if 'role' in s: return page.get_by_role(s['role'],name=s.get('name'),exact=bool(s.get('exact',False))).first
 if 'label' in s: return page.get_by_label(s['label']).first
 if 'placeholder' in s: return page.get_by_placeholder(s['placeholder']).first
 if 'text' in s: return page.get_by_text(s['text'],exact=bool(s.get('exact',False))).first
 raise ValueError('SELECTOR_REQUIRED')

def run_task(payload,job_id):
 site,steps=verify_task(payload)
 from playwright.sync_api import sync_playwright
 for folder in (ASSETS,SHOTS,DOWNLOADS): folder.mkdir(mode=0o700,parents=True,exist_ok=True)
 profile=(STATE/'runway-profile') if site=='runway' else (STATE/'profiles'/site)
 profile.mkdir(mode=0o700,parents=True,exist_ok=True)
 safe=re.sub(r'[^A-Za-z0-9_.-]','_',job_id)
 observations=[]
 with sync_playwright() as p:
  context=p.chromium.launch_persistent_context(str(profile),headless=True,accept_downloads=True,viewport={'width':1440,'height':900})
  context.set_default_timeout(10000)
  page=context.pages[0] if context.pages else context.new_page()
  def guard(route):
   if route.request.is_navigation_request():
    try: check_url(route.request.url,site)
    except ValueError: return route.abort()
   return route.continue_()
  page.route('**/*',guard)
  page.on('popup',lambda popup:popup.close())
  try:
   start={'n8n':'https://blaxxun.app.n8n.cloud/','runway':'https://app.runwayml.com/','youtube':'https://studio.youtube.com/','drive':'https://drive.google.com/'}[site]
   page.goto(start,wait_until='domcontentloaded',timeout=30000)
   for i,s in enumerate(steps):
    op=s['op']
    if op=='navigate': page.goto(check_url(s['url'],site),wait_until='domcontentloaded',timeout=30000)
    elif op=='inspect':
     observations.append({'step':i,'op':'inspect','url':page.url,'title':page.title()[:150],'text':page.locator('body').inner_text(timeout=10000)[:4000]})
    elif op=='screenshot':
     path=SHOTS/f'{safe}-{i}.png';page.screenshot(path=str(path),full_page=False,timeout=12000)
     observations.append({'step':i,'op':'screenshot','stored_on_runner':str(path)})
    else:
     el=selector(page,s)
     if op=='click': el.click(timeout=10000)
     elif op=='fill': el.fill(s.get('value',''),timeout=10000)
     elif op=='press': el.press(s.get('key','Enter'),timeout=10000)
     elif op=='select': el.select_option(s.get('value',''),timeout=10000)
     elif op=='check': el.check(timeout=10000)
     elif op=='uncheck': el.uncheck(timeout=10000)
     elif op=='upload':
      asset=(ASSETS/s['file']).resolve()
      if ASSETS.resolve() not in asset.parents or not asset.is_file() or asset.stat().st_size>500*1024*1024: raise ValueError('UPLOAD_ASSET_NOT_APPROVED')
      el.set_input_files(str(asset),timeout=15000)
     elif op=='download':
      with page.expect_download(timeout=30000) as info: el.click()
      d=info.value;target=DOWNLOADS/f'{safe}-{i}-{Path(d.suggested_filename).name}';d.save_as(str(target))
      observations.append({'step':i,'op':'download','stored_on_runner':str(target)})
     elif op=='wait': el.wait_for(state=s.get('state','visible'),timeout=15000)
    if page.url not in ('about:blank',''): check_url(page.url,site)
   return {'ok':True,'site':site,'url':page.url,'title':page.title()[:150],'steps':len(steps),'observations':observations}
  finally: context.close()
