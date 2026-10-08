#!/usr/bin/env python3
"""Read PBX CDR and gateway correlation, send idempotent batches to AIS.
Private config/state only. No calls, numbers, recordings or secrets in logs.
"""
import csv, datetime, fcntl, hashlib, hmac, json, os, re, subprocess, time, urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo


def browser_answers(text):
    answers = {}
    for row in csv.reader(text.splitlines()):
        if len(row) < 18 or row[14] != 'ANSWERED':continue
        match = re.fullmatch(r'ais:([0-9]{10}\.[0-9]+):(?:group|direct)', row[17])
        endpoint = re.match(r'PJSIP/(777[1-9]|7780)-', row[6])
        if match and endpoint:answers[match[1]] = endpoint[1]
    return answers


def call_from_cdr(row, answers, recording_root='/var/spool/asterisk/monitor', zone='Asia/Vladivostok'):
    uid = row['uniqueid']
    if not re.fullmatch(r'[0-9]{10}\.[0-9]+', uid) or row['channel'].startswith('Local/'):
        return None
    caller = row['src'] or 'Номер скрыт';called = row['dst']
    source_internal = bool(re.fullmatch(r'\d{3,4}', caller))
    target_internal = bool(re.fullmatch(r'\d{3,4}', called))
    direction = 'internal' if source_internal and target_internal else 'outgoing' if source_internal else 'incoming'
    status = {'ANSWERED':'answered','NO ANSWER':'missed','BUSY':'busy','FAILED':'failed'}.get(row['disposition'],'failed')
    target = re.match(r'(?:SIP|PJSIP)/(\d{3,4})-', row['dstchannel'])
    extension = (answers.get(uid) or (target[1] if target else None)) if status == 'answered' else None
    if status == 'answered' and direction == 'outgoing' and extension is None and re.fullmatch(r'[78]\d{10}', called):
        extension = called
    recording = row.get('recordingfile','')
    path = None
    if recording:
        # FreePBX stores a basename; its date comes from the call start date.
        date = datetime.datetime.strptime(row['calldate'],'%Y-%m-%d %H:%M:%S')
        if re.fullmatch(r'[A-Za-z0-9_.-]+\.wav', recording):
            path = recording_root.rstrip('/') + date.strftime('/%Y/%m/%d/') + recording
        elif recording.startswith(recording_root.rstrip('/') + '/') and '..' not in recording.split('/') and re.fullmatch(r'/[A-Za-z0-9_./-]+\.wav',recording):
            path = recording
    started = datetime.datetime.strptime(row['calldate'],'%Y-%m-%d %H:%M:%S').replace(tzinfo=ZoneInfo(zone)).isoformat()
    return {'call_unique_id':uid,'started_at':started,'caller_number':caller,'called_number':called,
            'answered_extension':extension,'direction':direction,'status':status,
            'duration':row['duration'],'billsec':row['billsec'],'recording_path':path}


def run(config, state):
    # The gateway CSV persists answered-extension/root-call correlation.
    gateway = subprocess.check_output(config['gateway_cdr_command'], timeout=30).decode()
    answers = browser_answers(gateway)
    zone = ZoneInfo(config.get('pbx_timezone','Asia/Vladivostok'))
    today = datetime.datetime.now(zone).date()
    day = datetime.date.fromisoformat(state.get('day',config['start_day']))
    while day <= today:
        offset = 0;rows = [];active_oldest = None
        while True:
            request = json.dumps({'day':day.isoformat(),'offset':offset}) + '\n'
            result = json.loads(subprocess.check_output(config['pbx_export_command'], input=request.encode(), timeout=60))
            rows.extend(result['rows']);oldest = result['active_oldest_epoch']
            if oldest is not None:active_oldest = min(active_oldest or oldest, oldest)
            if len(result['rows']) < 1000:break
            offset += 1000
        # Collapse multiple CDR segments under the same unique ID. Preserve a
        # successful answer and its recording when transfer legs add failures.
        calls = {}
        for row in rows:
            call = call_from_cdr(row, answers, config.get('recording_root','/var/spool/asterisk/monitor'),config.get('pbx_timezone','Asia/Vladivostok'))
            if call is None:continue
            previous = calls.get(call['call_unique_id'])
            if previous is None or (previous['status'] != 'answered' and call['status'] == 'answered') or (call['status']==previous['status'] and call['billsec']>previous['billsec']):
                calls[call['call_unique_id']] = call
        changed = []
        seen = state.setdefault('seen',{})
        for uid,call in calls.items():
            digest = hashlib.sha256(json.dumps(call,sort_keys=True).encode()).hexdigest()
            if seen.get(uid) != digest:changed.append((call,digest))
        for start in range(0,len(changed),100):
            batch = changed[start:start+100]
            body = json.dumps({'calls':[call for call,_ in batch]},ensure_ascii=False).encode()
            stamp = str(int(time.time()))
            signature = hmac.new(config['ingest_secret'].encode(), stamp.encode()+b'.'+body, hashlib.sha256).hexdigest()
            request = urllib.request.Request(config['ais_url'],data=body,headers={'Content-Type':'application/json','X-AIS-Timestamp':stamp,'X-AIS-Signature':signature})
            with urllib.request.urlopen(request,timeout=30) as response:
                accepted = json.loads(response.read())
                if accepted.get('accepted') != len(batch):raise RuntimeError('Batch not confirmed')
            for call,digest in batch:seen[call['call_unique_id']] = digest
            save_state(config['state_path'],state)
        fingerprint = hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest()
        day_end = datetime.datetime.combine(day+datetime.timedelta(days=1),datetime.time(),zone).timestamp()
        # Do not seal until the CDR set is stable on two runs and no active
        # channel could later write a CDR for this day. Late calls are retained.
        stable = state.get('fingerprints',{}).get(day.isoformat()) == fingerprint
        state.setdefault('fingerprints',{})[day.isoformat()] = fingerprint
        if day < today-datetime.timedelta(days=1) and stable and (active_oldest is None or active_oldest >= day_end) and state.get('day',config['start_day']) == day.isoformat():
            state['day'] = (day+datetime.timedelta(days=1)).isoformat()
            for uid in calls:seen.pop(uid,None)
            state['fingerprints'].pop(day.isoformat(),None)
        save_state(config['state_path'],state)
        day += datetime.timedelta(days=1)


def save_state(path, state):
    target = Path(path);target.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(state));temporary.chmod(0o600);os.replace(temporary,target)


def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--config',required=True);args=parser.parse_args()
    config=json.loads(Path(args.config).read_text())
    assert len(config['ingest_secret'])>=32 and not config['ingest_secret'].startswith('REPLACE')
    path=Path(config['state_path']);path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    with path.with_suffix('.lock').open('a') as handle:
        try:fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return
        state=json.loads(path.read_text()) if path.exists() else {}
        run(config,state)
if __name__=='__main__':main()
