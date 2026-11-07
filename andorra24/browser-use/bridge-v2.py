#!/usr/bin/env python3
"""Outbound authenticated n8n jobs: diagnostics and bounded Playwright UI actions."""
import argparse,json,os,re,sqlite3,time
from datetime import datetime,timezone
from pathlib import Path
from urllib.parse import urlparse
import httpx
from browser_actions import run_task,verify_task

STATE=Path('/var/lib/andorra24-browser-use')
DB=Path(os.environ.get('A24_BRIDGE_DB',str(STATE/'bridge.sqlite3')))
ACTIONS={'ping','browser_health','runway_session_check','browser_task'}
def timestamp(): return datetime.now(timezone.utc).isoformat()
def endpoint(url):
 p=urlparse(url)
 if p.scheme!='https' or p.hostname!='blaxxun.app.n8n.cloud' or p.username or p.password or p.fragment or p.port not in (None,443) or not p.path.startswith('/webhook/'): raise ValueError('INVALID_N8N_ENDPOINT')
 return url
def normalize(j):
 if j in (None,{},[],''): return None
 if not isinstance(j,dict): raise ValueError('INVALID_JOB')
 jid=str(j.get('job_id',''))
 if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{2,127}',jid): raise ValueError('INVALID_JOB_ID')
 act=j.get('action')
 if act not in ACTIONS: raise ValueError('ACTION_NOT_ALLOWED')
 edition=j.get('edition_key') or ''
 if edition and not re.fullmatch(r'20\d\d-\d\d-\d\d_(MATI|MIGDIA|TARDA|NIT|ESPECIAL)',str(edition)): raise ValueError('INVALID_EDITION')
 payload=None
 if act=='browser_task':
  raw=j.get('payload_json','')
  if isinstance(raw,str) and 0<len(raw)<=18000: payload=json.loads(raw)
  elif isinstance(raw,dict): payload=raw
  else: raise ValueError('BROWSER_PAYLOAD_REQUIRED')
  verify_task(payload)
 return {'job_id':jid,'action':act,'edition_key':str(edition),'payload':payload}
def db_connect():
 DB.parent.mkdir(parents=True,exist_ok=True)
 c=sqlite3.connect(DB)
 c.execute('PRAGMA journal_mode=WAL')
 c.execute('CREATE TABLE IF NOT EXISTS jobs(job_id TEXT PRIMARY KEY,edition_key TEXT,action TEXT,status TEXT,result_json TEXT,created_at TEXT,updated_at TEXT)')
 c.commit()
 return c
def action_run(j):
 action=j['action']
 if action=='ping':return {'ok':True,'runtime':'outbound-n8n-bridge-v2','time':timestamp()}
 if action=='browser_health':
  from playwright.sync_api import sync_playwright
  with sync_playwright() as p:
   browser=p.chromium.launch(headless=True);page=browser.new_page();page.goto('about:blank');good=page.url=='about:blank';browser.close()
  return {'ok':good,'chromium':'OK' if good else 'FAILED'}
 if action=='runway_session_check':
  profile=STATE/'runway-profile';return {'profile_exists':profile.is_dir() and any(profile.iterdir()) if profile.exists() else False,'runway_logged_in':'NOT_VERIFIED'}
 if action=='browser_task':return run_task(j['payload'],j['job_id'])
 raise ValueError('ACTION_NOT_IMPLEMENTED')
def handle(c,j):
 old=c.execute('SELECT status,result_json FROM jobs WHERE job_id=?',(j['job_id'],)).fetchone()
 if old:return json.loads(old[1]) if old[1] else {'job_id':j['job_id'],'status':'ERROR','error_type':'ALREADY_IN_PROGRESS'}
 now=timestamp()
 c.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?)',(j['job_id'],j['edition_key'],j['action'],'RUNNING',None,now,now));c.commit()
 try:
  value=action_run(j)
  result={'job_id':j['job_id'],'edition_key':j['edition_key'],'status':'COMPLETED','result':value,'time':timestamp()}
  if len(json.dumps(result,ensure_ascii=False))>10500:
   result['result']={'ok':True,'truncated':True,'site':value.get('site'),'url':value.get('url'),'steps':value.get('steps')}
 except Exception as ex:
  result={'job_id':j['job_id'],'status':'ERROR','error_type':type(ex).__name__,'error':str(ex)[:350],'time':timestamp()}
 c.execute('UPDATE jobs SET status=?,result_json=?,updated_at=? WHERE job_id=?',(result['status'],json.dumps(result,ensure_ascii=False),timestamp(),j['job_id']));c.commit()
 return result
def poll(c):
 pull=endpoint(os.environ['A24_N8N_PULL_URL'])
 ack=endpoint(os.environ['A24_N8N_RESULT_URL'])
 token=os.environ['A24_N8N_BRIDGE_TOKEN']
 if not re.fullmatch(r'[A-Za-z0-9_\-.]{24,256}',token):raise ValueError('TOKEN_INVALID')
 headers={'Authorization':'Bearer '+token,'X-A24-Bridge':'v2'}
 with httpx.Client(timeout=25,follow_redirects=False,trust_env=False) as client:
  r=client.get(pull,headers=headers);r.raise_for_status();raw=r.json()
  if raw in (None,{},[],''):return 'IDLE'
  try:result=handle(c,normalize(raw))
  except Exception as ex:
   jid=raw.get('job_id','') if isinstance(raw,dict) else ''
   if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{2,127}',str(jid)):raise
   result={'job_id':jid,'status':'ERROR','error_type':type(ex).__name__,'error':str(ex)[:220],'time':timestamp()}
  r=client.post(ack,headers=headers,json=result);r.raise_for_status()
  return 'ACKNOWLEDGED'
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--selftest',action='store_true');parser.add_argument('--once',action='store_true');args=parser.parse_args()
 c=db_connect()
 if args.selftest:
  for jid,action in [('bridge-v2-ping','ping'),('bridge-v2-chromium','browser_health')]:
   print(json.dumps(handle(c,normalize({'job_id':jid,'action':action}))))
  return
 if args.once:
  print(json.dumps({'status':poll(c)}));return
 while True:
  try:print(json.dumps({'status':poll(c),'time':timestamp()}),flush=True)
  except Exception as ex:print(json.dumps({'status':'BLOCKED','error_type':type(ex).__name__,'time':timestamp()}),flush=True)
  time.sleep(15)
if __name__=='__main__':main()
