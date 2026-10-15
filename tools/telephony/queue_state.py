"""Read-only, bounded projection of Asterisk queue_log for an authorised phone.

ABANDON can mean a parallel desk phone answered. Only the main PBX CDR may
declare the logical conversation missed; this projection never does that.
"""
import re
import time
from pathlib import Path

QUEUE_LOG = Path('/var/log/asterisk/queue_log')
QUEUES = {'ais-browser-all'} | {'ais-browser-' + str(n) for n in range(7771, 7781)}
TERMINAL = {'CONNECT': 'answered', 'ABANDON': 'left',
            'EXITWITHTIMEOUT': 'timeout', 'EXITEMPTY': 'left',
            'EXITWITHKEY': 'left', 'WITHDRAW': 'left',
            'COMPLETECALLER': 'answered', 'COMPLETEAGENT': 'answered',
            'TRANSFER': 'answered', 'BLINDTRANSFER': 'answered',
            'ATTENDEDTRANSFER': 'answered'}


def project(text, extension, now):
    allowed = {'ais-browser-all', 'ais-browser-' + extension}
    calls = {}
    for line in text.splitlines():
        parts = line.split('|')
        if len(parts) < 5:
            continue
        stamp, call_id, queue, agent, event = parts[:5]
        try:
            stamp = int(stamp)
        except ValueError:
            continue
        if event == 'QUEUESTART':
            for item in calls.values():
                if item['state'] == 'waiting':
                    item.update(state='unknown', updated_at=stamp)
            continue
        if queue not in allowed or queue not in QUEUES or not re.fullmatch(r'[0-9.]{1,64}', call_id):
            continue
        key = (queue, call_id)
        if event == 'ENTERQUEUE' and len(parts) >= 7:
            calls[key] = {'id': queue + ':' + call_id, 'queue': queue,
                          'number': parts[6][:128] or 'Номер скрыт',
                          'started_at': stamp, 'updated_at': stamp, 'state': 'waiting'}
        elif key in calls and event in TERMINAL:
            calls[key].update(state=TERMINAL[event], updated_at=stamp)
            match = re.fullmatch(r'(?:Local/)?(777[1-9]|7780)(?:@ais-browser-queue-member/n)?', agent)
            if match and TERMINAL[event] == 'answered':
                calls[key]['answered_extension'] = match[1]
    waiting, recent = [], []
    positions = {}
    for item in sorted(calls.values(), key=lambda entry: (entry['started_at'], entry['id'])):
        if item['state'] == 'waiting':
            # Parent FreePBX Dial is bounded to 120 seconds. Old incomplete log
            # entries (e.g. after a crash) must not remain live forever.
            if now - item['started_at'] > 180:
                continue
            positions[item['queue']] = positions.get(item['queue'], 0) + 1
            item.update(position=positions[item['queue']], wait_seconds=max(0, now-item['started_at']))
            waiting.append(item)
        elif now - item['updated_at'] <= 3600:
            recent.append(item)
    return {'waiting': waiting[:100],
            'recent': sorted(recent, key=lambda item: item['updated_at'], reverse=True)[:20]}


def snapshot(extension):
    with QUEUE_LOG.open('rb') as handle:
        size = handle.seek(0, 2)
        handle.seek(max(0, size - 1024 * 1024))
        if size > 1024 * 1024:
            handle.readline()  # discard a possibly partial first record
        text = handle.read().decode('utf-8', errors='replace')
    return project(text, extension, int(time.time()))
