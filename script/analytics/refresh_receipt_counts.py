#!/usr/bin/env python3
"""Daily bounded refresh and retry of undelivered aggregate snapshots.

Install a scheduler ONLY after the new AIS endpoint is deployed. No AI calls.
Historical snapshots are loaded separately once and reconciled in a monthly job.
"""
import argparse
from datetime import datetime,timedelta
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
from zoneinfo import ZoneInfo
from deliver_receipt_counts import deliver


def run():
    p=argparse.ArgumentParser()
    p.add_argument('--connector',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--full',action='store_true')
    a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (a.output/'refresh.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        today=datetime.now(ZoneInfo('Asia/Vladivostok')).date()
        # Previous/current month catches late postings. Full history: explicit/monthly.
        first=(today.replace(day=1)-timedelta(days=1)).replace(day=1)
        if a.full:first=today.replace(year=today.year-6,month=1,day=1)
        subprocess.run([sys.executable,str(Path(__file__).with_name('receipt_counts.py')),
          '--connector',str(a.connector),'--output',str(a.output),'--from',str(first),'--refresh'],check=True)
        for state in sorted(a.output.glob('*.latest.json')):
            data=json.loads(state.read_text()); marker=a.output/(data['sha256']+'.delivered')
            if marker.exists():continue
            result=deliver(a.output/data['file'],a.connector)
            with os.fdopen(os.open(marker,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w') as stream:json.dump(result,stream)
            print(json.dumps(result),flush=True)

if __name__=='__main__':
    try:run()
    except Exception as exc:
        print('Refresh failed: '+type(exc).__name__,file=sys.stderr)
        raise SystemExit(1)
