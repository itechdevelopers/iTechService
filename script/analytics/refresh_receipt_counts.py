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
import re
from pathlib import Path
import subprocess
import sys
from zoneinfo import ZoneInfo
from deliver_receipt_counts import deliver


def deliver_pending(output, connector):
    failed = False
    for state in sorted(output.glob('*.latest.json')):
        try:
            data = json.loads(state.read_text())
            if not isinstance(data.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', data['sha256']):
                raise ValueError('invalid_state_checksum')
            if not isinstance(data.get('file'), str) or Path(data['file']).name != data['file']:
                raise ValueError('invalid_snapshot_filename')
            marker = output / (data['sha256'] + '.delivered')
            if marker.exists():
                saved = json.loads(marker.read_text())
                if saved.get('delivery_id') == data['sha256']:
                    continue
                raise ValueError('invalid_delivery_marker')
            result = deliver(output / data['file'], connector, data['sha256'])
            if result.get('delivery_id') != data['sha256']:
                raise ValueError('delivery_checksum_mismatch')
            temporary = marker.with_suffix('.partial')
            with os.fdopen(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as stream:
                json.dump(result, stream)
            temporary.replace(marker)
            print(json.dumps(result), flush=True)
        except Exception as exc:
            # One invalid snapshot must not prevent retrying other pending months.
            failed = True
            print('Pending delivery failed: ' + type(exc).__name__, file=sys.stderr)
    return failed


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
        # Retry saved snapshots even if the source is unavailable today.
        failed = deliver_pending(a.output, a.connector)
        try:
            subprocess.run([sys.executable, str(Path(__file__).with_name('receipt_counts.py')),
                '--connector', str(a.connector), '--output', str(a.output), '--from', str(first), '--refresh'], check=True)
        except (subprocess.CalledProcessError, OSError):
            failed = True
        failed = deliver_pending(a.output, a.connector) or failed
        if failed:
            raise RuntimeError('collection_or_delivery_failed')

if __name__=='__main__':
    try:run()
    except Exception as exc:
        print('Refresh failed: '+type(exc).__name__,file=sys.stderr)
        raise SystemExit(1)
