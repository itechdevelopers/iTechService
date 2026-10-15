"""Temporary live test routes only: 7798/7799 and synthetic Local/9797.

Never replaces working inbound contexts, SIP settings, or services. Invoke only
after checking 7778/7779 are unassigned. All temporary includes are removed.
"""
import json
import subprocess
import sys
from pathlib import Path
from queue_state import snapshot
from collector import browser_answers

ROOT = Path('/etc/asterisk')
HERE = Path(__file__).parent
MARKERS = [('queues.conf', 'ais-queue-review-queues.conf'),
           ('extensions.conf', 'ais-queue-review-dialplan.conf')]


def cli(command):
    return subprocess.check_output(['/usr/sbin/asterisk', '-rx', command]).decode()


def cancel():
    for row in cli('core show channels concise').splitlines():
        channel = row.split('!')[0]
        if channel.startswith('Local/9797@ais-queue-review-'):
            cli('channel request hangup ' + channel)


def remove():
    cancel()
    for base, include in MARKERS:
        path = ROOT / base
        path.write_text(path.read_text().replace('\n#include ' + include + '\n', ''))
        (ROOT / include).unlink(missing_ok=True)
    cli('queue reload all')
    cli('dialplan reload')


def install():
    assert 'No queues.' in cli('queue show'), 'Existing queues: inspect before running this test'
    for base, include in MARKERS:
        assert include not in (ROOT/base).read_text(), 'Review test is already installed'
    # Shared test queue may only ring the two verified unassigned phones.
    config = (HERE/'gateway-queues.conf').read_text()
    config = '\n'.join(line for line in config.splitlines()
                       if not line.startswith('member => ') or
                       line.startswith(('member => Local/7778@', 'member => Local/7779@'))) + '\n'
    (ROOT/MARKERS[0][1]).write_text(config)
    source = (HERE/'gateway-dialplan.conf').read_text()
    member = source[source.index('[ais-browser-queue-member]'):]
    call_id = source[source.index('[ais-browser-call-id]'):source.index('[ais-browser-group]')].replace('ais-browser-call-id', 'ais-review-call-id')
    (ROOT/MARKERS[1][1]).write_text('''[ais-browser-outbound]
exten => 7799,1,Goto(ais-queue-review,personal,1)
exten => 7798,1,Goto(ais-queue-review,shared,1)
[ais-queue-review]
exten => personal,1,Gosub(ais-review-call-id,s,1)
 same => n,Set(__AIS_CALL_KIND=direct)
 same => n,Progress()
 same => n,Queue(ais-browser-7778,i,,,120,,,ais-browser-queue-identity)
 same => n,Hangup()
exten => shared,1,Gosub(ais-review-call-id,s,1)
 same => n,Set(__AIS_CALL_KIND=group)
 same => n,Progress()
 same => n,Queue(ais-browser-all,i,,,120,,,ais-browser-queue-identity)
 same => n,Hangup()
exten => 9797,1,Set(CALLERID(num)=105)
 same => n,Goto(ais-queue-review,personal,1)
''' + member + call_id)
    for base, include in MARKERS:
        path = ROOT/base
        path.write_text(path.read_text()+'\n#include '+include+'\n')
    cli('queue reload all')
    cli('dialplan reload')
    assert 'ais-browser-7778' in cli('queue show ais-browser-7778')
    print('ISOLATED_QUEUE_ROUTES_INSTALLED')


if __name__ == '__main__':
    action = sys.argv[1]
    if action == 'install':
        try:
            install()
        except Exception:
            # Only clean up our includes; never restore entire shared configs.
            if any(include in (ROOT/base).read_text() for base, include in MARKERS):
                remove()
            raise
    elif action == 'remove':
        remove()
    elif action == 'cancel':
        cancel()
    elif action == 'answerproof':
        print(json.dumps(browser_answers(Path('/var/log/asterisk/cdr-csv/Master.csv').read_text()).get(sys.argv[2])))
    elif action == 'identityproof':
        rows = cli('core show channels concise').splitlines()
        channels = [row.split('!')[0] for row in rows]
        caller = [cli('core show channel ' + c) for c in channels if c.startswith('PJSIP/7779-')]
        agent = [cli('core show channel ' + c) for c in channels if c.startswith('PJSIP/7778-')]
        print(json.dumps({'caller': any('AIS_TRANSFER_EXTENSION=7778' in s for s in caller), 'agent': any('TRANSFER_CONTEXT=ais-browser-transfer' in s for s in agent)}))
    elif action == 'snapshot':
        print(json.dumps(snapshot(sys.argv[2])))
