#!/usr/bin/env python3
"""GET-only receipt count snapshots; use the installed, metadata-checked connector.

No credentials are copied. --connector points to the existing odata.py/.env.
Output contains aggregate counts only. Delivery to AIS is a separate step.
"""
import argparse
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from zoneinfo import ZoneInfo

ENTITY = 'Document_ЧекККМ'
FIELDS = ['Ref_Key', 'Date', 'Posted', 'DeletionMark', 'Статус', 'Склад_Key']
ZERO = '00000000-0000-0000-0000-000000000000'
FILTER = "Posted eq true and DeletionMark eq false and Статус eq 'Пробит'"


def collect(client, schema, start, end, depth=0):
    where = f"Date ge datetime'{start.isoformat(timespec='seconds')}' and Date lt datetime'{end.isoformat(timespec='seconds')}' and {FILTER}"
    rows = client.rows(schema, ENTITY, FIELDS, where, top=100, limit=1000)
    if client.truncated:
        if (end-start).total_seconds() <= 1 or depth >= 30:
            raise ValueError('incomplete_receipt_interval')
        seconds = int((end-start).total_seconds()) // 2
        middle = start + timedelta(seconds=seconds)
        return collect(client, schema, start, middle, depth+1) + collect(client, schema, middle, end, depth+1)
    return rows


def aggregate(rows, names, first, last):
    buckets = defaultdict(lambda: defaultdict(int))
    seen = set()
    for row in rows:
        key = row['Ref_Key']
        if key in seen:
            raise ValueError('duplicate_receipt')
        seen.add(key)
        if row['Posted'] is not True or row['DeletionMark'] is not False or row['Статус'] != 'Пробит':
            raise ValueError('invalid_receipt_status')
        day = date.fromisoformat(row['Date'][:10])
        if not first <= day <= last:
            raise ValueError('receipt_outside_interval')
        buckets[day][row.get('Склад_Key') or ZERO] += 1
    days = []
    current = first
    while current <= last:
        branches = [{'id': key, 'name': names.get(key, 'Неизвестный склад ' + key), 'quantity': qty}
                    for key, qty in sorted(buckets[current].items())]
        days.append({'date': current.isoformat(), 'quantity': sum(b['quantity'] for b in branches), 'branches': branches})
        current += timedelta(days=1)
    return days


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--connector', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--from', dest='first', type=date.fromisoformat, required=True)
    p.add_argument('--to', dest='last', type=date.fromisoformat)
    p.add_argument('--refresh', action='store_true', help='Create new versions even if month already loaded')
    p.add_argument('--pause', type=float, default=0.25)
    args = p.parse_args()
    yesterday = datetime.now(ZoneInfo('Asia/Vladivostok')).date()-timedelta(days=1)
    last = args.last or yesterday
    if not args.first <= last <= yesterday or args.pause < 0:
        raise ValueError('only_completed_date_range_allowed')
    args.output.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (args.output/'collector.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        sys.path.insert(0, str(args.connector.resolve()))
        from odata import Client, Schema, credentials, guid
        class ThrottledClient(Client):
            def request(self, *values, **kwargs):
                time.sleep(args.pause)
                return super().request(*values, **kwargs)
        client = ThrottledClient(credentials())
        schema = Schema(client.request('$metadata'))
        client.schema = schema
        names = {}
        first = args.first
        while first <= last:
            next_month = (first.replace(day=28)+timedelta(days=4)).replace(day=1)
            end = min(last, next_month-timedelta(days=1))
            state = args.output/(first.isoformat()+'_'+end.isoformat()+'.latest.json')
            if state.exists() and not args.refresh:
                saved=json.loads(state.read_text())
                raw=(args.output/saved['file']).read_bytes()
                if hashlib.sha256(raw).hexdigest()!=saved['sha256']:
                    raise ValueError('saved_snapshot_checksum_mismatch')
                print(json.dumps({'event':'already_complete','from':str(first),'to':str(end)}),flush=True)
                first=end+timedelta(days=1)
                continue
            stamp = datetime.now(timezone.utc)
            rows = collect(client, schema, datetime.combine(first,datetime.min.time()),datetime.combine(end+timedelta(days=1),datetime.min.time()))
            refs = sorted({r.get('Склад_Key') or ZERO for r in rows}-{ZERO}-names.keys())
            for ref in refs:
                part=client.rows(schema,'Catalog_Склады',['Ref_Key','Description'],"Ref_Key eq "+guid(ref),top=2,limit=2)
                for row in part:names[row['Ref_Key']]=row['Description']
            days=aggregate(rows,names,first,end)
            report={'schema_version':'activity-counts-1.0','metric':'receipts','methodology_version':'posted-receipts-1.0',
                    'period':{'from':str(first),'to':str(end)},'calculated_at':stamp.isoformat(),
                    'source':{'entity':ENTITY,'read_only':True,'http_methods':['GET']},
                    'checks':{'all_pages_received':True,'duplicates':0},'quantity':len(rows),'days':days}
            raw=json.dumps(report,ensure_ascii=False,separators=(',',':')).encode()
            filename=first.isoformat()+'_'+end.isoformat()+'_'+stamp.strftime('%Y%m%dT%H%M%S%fZ')+'.json'
            target=args.output/filename
            with os.fdopen(os.open(target,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'wb') as out:out.write(raw)
            state_data={'file':filename,'sha256':hashlib.sha256(raw).hexdigest()}
            temp=state.with_suffix('.partial')
            with os.fdopen(os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600),'w') as out:json.dump(state_data,out)
            temp.replace(state)
            print(json.dumps({'event':'complete','from':str(first),'to':str(end),'quantity':len(rows),'requests_so_far':len(client.stats),'file':filename}),flush=True)
            first=end+timedelta(days=1)

if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('STOP: '+type(exc).__name__,file=sys.stderr)
        sys.exit(1)
