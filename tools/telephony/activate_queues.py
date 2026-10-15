#!/usr/bin/env python3
"""Activate reviewed gateway queue release without restarting Asterisk.

Run from a staging directory after deploying approved AIS master. Quiescent
gateway required: broker restart revokes leases; staff must re-enable phones.
"""
import argparse
import datetime
import grp
import os
import re
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path('/etc/asterisk')
SOURCE = Path(__file__).resolve().parent


def run(*args):
    return subprocess.check_output(args).decode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--activate', action='store_true')
    if not parser.parse_args().activate:
        print('Prepared queue activation. Use --activate only after developer approval and AIS deployment.')
        return
    installed = Path('/opt/ais-telephony')
    assert SOURCE != installed, 'Use a separate staging directory so existing programs can be backed up'
    assert re.search(r'^0 active channels$', run('/usr/sbin/asterisk', '-rx', 'core show channels count'), re.M), 'Finish calls first'
    leases = run('/usr/sbin/asterisk', '-rx', 'database show ais-telephony')
    deadlines = re.findall(r'/ais-telephony/(?:777[1-9]|7780)/active\s*:\s*(\d+)', leases)
    assert not any(int(deadline) > time.time() for deadline in deadlines), 'Staff must disable browser phones before activation'
    assert not (ROOT/'ais-queue-review-dialplan.conf').exists(), 'Remove temporary test routes first'
    for name in ['gateway-dialplan.conf', 'gateway-queues.conf', 'queue_state.py', 'sip_control.py', 'gateway.py']:
        assert (SOURCE/name).is_file(), 'Missing reviewed source: ' + name
    backup = Path('/root/ais-queue-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(mode=0o700)
    for name in ['queues.conf', 'ais-telephony-dialplan.conf', 'ais-telephony-queues.conf']:
        if (ROOT/name).exists():
            shutil.copy2(ROOT/name, backup/name)
    (backup/'programs').mkdir()
    for name in ['queue_state.py', 'sip_control.py', 'gateway.py']:
        if (installed/name).exists():
            shutil.copy2(installed/name, backup/'programs'/name)
        shutil.copy2(SOURCE/name, installed/name)
        os.chown(installed/name, 0, 0)
        (installed/name).chmod(0o644)
    for source, target in [('gateway-queues.conf', 'ais-telephony-queues.conf'),
                           ('gateway-dialplan.conf', 'ais-telephony-dialplan.conf')]:
        shutil.copy2(SOURCE/source, ROOT/target)
        os.chown(ROOT/target, 0, grp.getgrnam('asterisk').gr_gid)
        (ROOT/target).chmod(0o640)
    path = ROOT/'queues.conf'
    include = '#include ais-telephony-queues.conf'
    if include not in path.read_text().splitlines():
        with path.open('a') as handle:
            handle.write('\n'+include+'\n')
    assert re.search(r'^0 active channels$', run('/usr/sbin/asterisk', '-rx', 'core show channels count'), re.M), 'New call started: do not restart services'
    run('/usr/sbin/asterisk', '-rx', 'queue reload all')
    assert 'ais-browser-all' in run('/usr/sbin/asterisk', '-rx', 'queue show ais-browser-all')
    run('/usr/sbin/asterisk', '-rx', 'dialplan reload')
    run('systemctl', 'restart', 'ais-telephony-control', 'ais-telephony-gateway')
    print('Gateway queues active; configuration backup:', backup)


if __name__ == '__main__':
    main()
