#!/usr/bin/env python3
"""Root-owned local socket; only the asterisk UID may update managed auth."""
import grp, json, os, pwd, re, secrets, socket, struct, subprocess, tempfile
from pathlib import Path
EXTENSIONS = {str(n) for n in range(7771, 7781)}
AUTH = Path('/etc/asterisk/ais-telephony-auth.conf')
STATE = Path('/var/lib/ais-telephony/auth.json')

def cli(command):
    subprocess.run(['/usr/sbin/asterisk', '-rx', command], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)

def rotate(extension, password):
    state = json.loads(STATE.read_text()) if STATE.exists() else {'passwords': {e: secrets.token_urlsafe(32) for e in EXTENSIONS}, 'contacts': {}}
    values = state['passwords']
    values[extension] = password
    STATE.write_text(json.dumps(state)); STATE.chmod(0o600)
    content = ''.join('[auth-{}]\ntype=auth\nauth_type=userpass\nusername={}\npassword={}\n\n'.format(e, e, values[e]) for e in sorted(values))
    with tempfile.NamedTemporaryFile(mode='w', dir=AUTH.parent, delete=False) as handle:
        handle.write(content)
        temporary = handle.name
    os.chmod(temporary, 0o640);os.chown(temporary, 0, grp.getgrnam('asterisk').gr_gid)
    os.replace(temporary, AUTH)
    cli('pjsip reload')

def handle(payload):
    extension = payload.get('extension')
    action = payload.get('action')
    if extension not in EXTENSIONS or action not in ('enable', 'heartbeat', 'disable'):
        raise ValueError()
    if action == 'disable':
        cli('database put ais-telephony {}/active 0'.format(extension))
        rotate(extension, secrets.token_urlsafe(32))
        output = subprocess.check_output(['/usr/sbin/asterisk', '-rx', 'core show channels concise'], timeout=10).decode()
        for line in output.splitlines():
            channel = line.split('!')[0]
            if re.fullmatch(r'PJSIP/' + extension + r'-[0-9a-f]+', channel):
                cli('channel request hangup ' + channel)
    else:
        until = payload.get('until')
        if type(until) is not int or until <= 0:
            raise ValueError()
        if action == 'enable':
            password = payload.get('password')
            if not isinstance(password, str) or not re.fullmatch(r'[A-Za-z0-9_-]{40,64}', password):
                raise ValueError()
            contact = payload.get('contact_user')
            if not isinstance(contact, str) or not re.fullmatch(extension + r'-[0-9a-f]{32}', contact):
                raise ValueError()
            cli('database put ais-telephony {}/active 0'.format(extension))
            rotate(extension, password)
            state = json.loads(STATE.read_text());state['contacts'][extension] = contact
            STATE.write_text(json.dumps(state));STATE.chmod(0o600)
        else:
            state = json.loads(STATE.read_text())
            contact = state['contacts'].get(extension)
            output = subprocess.check_output(['/usr/sbin/asterisk', '-rx', 'database show registrar'], timeout=10).decode()
            # A stale contact from a previous employee/session must never ring.
            if contact and ('sip:' + contact + '@') in output:
                cli('database put ais-telephony {}/active {}'.format(extension, until))
            else:
                cli('database put ais-telephony {}/active 0'.format(extension))

def main():
    STATE.parent.mkdir(mode=0o700, exist_ok=True)
    directory = Path('/run/ais-telephony');directory.mkdir(mode=0o755, exist_ok=True)
    path = directory / 'control.sock'
    path.unlink(missing_ok=True)
    uid = pwd.getpwnam('asterisk').pw_uid
    with socket.socket(socket.AF_UNIX) as server:
        server.bind(str(path));os.chown(path, uid, grp.getgrnam('asterisk').gr_gid);os.chmod(path, 0o600)
        server.listen(8)
        while True:
            client, _ = server.accept()
            with client:
                client.settimeout(5)
                try:
                    _, peer_uid, _ = struct.unpack('3i', client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                    if peer_uid != uid:raise ValueError()
                    data = bytearray()
                    while b'\n' not in data and len(data) < 4096:
                        part = client.recv(4096)
                        if not part:break
                        data.extend(part)
                    if len(data) >= 4096:raise ValueError()
                    handle(json.loads(data))
                    client.sendall(b'{"ok":true}\n')
                except (ValueError, TypeError, AttributeError, OSError, subprocess.SubprocessError):
                    client.sendall(b'{"ok":false}\n')
if __name__ == '__main__':main()
