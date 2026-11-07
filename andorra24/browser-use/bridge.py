#!/usr/bin/env python3
"""Read-only outbound n8n control bridge for existing Browser Use/Playwright runner."""
import argparse, json, os, re, sqlite3, time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
import httpx

STATE=Path('/var/lib/andorra24-browser-use')
DB=Path(os.environ.get('A24_BRIDGE_DB', str(STATE/'bridge.sqlite3')))
ALLOWED={'ping','browser_health','runway_session_check'}
N8N_HOST='blaxxun.app.n8n.cloud'

def timestamp():
    return datetime.now(timezone.utc).isoformat()

def endpoint(value):
    p=urlparse(value)
    if p.scheme!='https' or p.hostname!=N8N_HOST or p.username or p.password or p.fragment or not p.path.startswith('/webhook/'):
        raise ValueError('n8n endpoint not authorized')
    return value

def normalize(job):
    if job in ({}, [], None, ''): return None
    if not isinstance(job,dict): raise ValueError('invalid job')
    jid=str(job.get('job_id',''))
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{2,127}', jid):
        raise ValueError('invalid job_id')
    action=job.get('action')
    if action not in ALLOWED: raise ValueError('action not permitted')
    edition=job.get('edition_key') or ''
    if edition and not re.fullmatch(r'20\d\d-\d\d-\d\d_(MATI|MIGDIA|TARDA|NIT|ESPECIAL)',str(edition)):
        raise ValueError('invalid edition')
    return {'job_id':jid,'action':action,'edition_key':str(edition)}

def connect_db():
    DB.parent.mkdir(parents=True,exist_ok=True)
    c=sqlite3.connect(DB)
    c.execute('PRAGMA journal_mode=WAL')
    c.execute('CREATE TABLE IF NOT EXISTS jobs(job_id TEXT PRIMARY KEY,edition_key TEXT,action TEXT,status TEXT,result_json TEXT,created_at TEXT,updated_at TEXT)')
    c.commit()
    return c

def action_run(action):
    if action=='ping':
        return {'ok':True,'runtime':'outbound-n8n-bridge','render':'DISABLED','time':timestamp()}
    if action=='browser_health':
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            b=p.chromium.launch(headless=True)
            pg=b.new_page()
            pg.goto('about:blank')
            healthy=pg.url=='about:blank'
            b.close()
        return {'ok':healthy,'chromium':'OK' if healthy else 'FAILED','render':'DISABLED'}
    if action=='runway_session_check':
        profile=STATE/'runway-profile'
        exists=profile.is_dir() and any(profile.iterdir())
        return {'profile_exists':exists,'runway_logged_in':'NOT_VERIFIED','web_automation':'DISABLED'}
    raise ValueError('unrecognized action')

def handle(c,raw):
    j=normalize(raw)
    if j is None: return None
    prior=c.execute('SELECT result_json FROM jobs WHERE job_id=?',(j['job_id'],)).fetchone()
    if prior:
        return json.loads(prior[0]) if prior[0] else {'job_id':j['job_id'],'status':'IN_PROGRESS','idempotent':True}
    n=timestamp()
    c.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?)',(j['job_id'],j['edition_key'],j['action'],'RUNNING',None,n,n))
    c.commit()
    try:
        result={'job_id':j['job_id'],'edition_key':j['edition_key'],'status':'COMPLETED','result':action_run(j['action']),'time':timestamp()}
    except Exception as ex:
        result={'job_id':j['job_id'],'status':'ERROR','error_type':type(ex).__name__,'time':timestamp()}
    c.execute('UPDATE jobs SET status=?,result_json=?,updated_at=? WHERE job_id=?',(result['status'],json.dumps(result),timestamp(),j['job_id']))
    c.commit()
    return result

def poll(c):
    pull=endpoint(os.environ['A24_N8N_PULL_URL'])
    ack=endpoint(os.environ['A24_N8N_RESULT_URL'])
    token=os.environ['A24_N8N_BRIDGE_TOKEN']
    if len(token)<24: raise ValueError('bridge token too short')
    headers={'Authorization':'Bearer '+token,'X-A24-Bridge':'v1'}
    with httpx.Client(timeout=15,follow_redirects=False,trust_env=False) as client:
        response=client.get(pull,headers=headers); response.raise_for_status()
        job=normalize(response.json())
        if job is None: return 'IDLE'
        result=handle(c,job)
        response=client.post(ack,headers=headers,json=result); response.raise_for_status()
        return 'ACKNOWLEDGED'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--selftest',action='store_true')
    parser.add_argument('--once',action='store_true')
    args=parser.parse_args()
    c=connect_db()
    if args.selftest:
        for job in [{'job_id':'bridge-health-v1','action':'ping'},
                    {'job_id':'bridge-chromium-v1','action':'browser_health'},
                    {'job_id':'bridge-profile-v1','action':'runway_session_check'}]:
            print(json.dumps(handle(c,job),sort_keys=True))
        return
    if args.once:
        print(json.dumps({'status':poll(c)}))
        return
    while True:
        try: print(json.dumps({'status':poll(c),'time':timestamp()}),flush=True)
        except Exception as e: print(json.dumps({'status':'BLOCKED','error_type':type(e).__name__,'time':timestamp()}),flush=True)
        time.sleep(60)

if __name__=='__main__':
    main()
