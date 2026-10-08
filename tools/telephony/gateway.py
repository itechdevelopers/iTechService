#!/usr/bin/env python3
"""Local HTTPS broker. Never serves credentials without a signed AIS ticket."""
import base64, hashlib, hmac, http.server, json, secrets, socket, ssl, threading, time
from pathlib import Path

EXTENSIONS = {str(n) for n in range(7771, 7781)}

class Denied(Exception):
    pass


def verify_ticket(ticket, secret, now=None):
    now = int(time.time()) if now is None else now
    try:
        encoded, signature = ticket.split('.')
        expected = hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise Denied()
        payload = json.loads(base64.urlsafe_b64decode(encoded + '=' * (-len(encoded) % 4)))
        if (payload.get('v') != 1 or payload.get('aud') != 'ais-telephony-gateway'
                or payload.get('extension') not in EXTENSIONS
                or type(payload.get('user_id')) is not int or payload['user_id'] <= 0
                or type(payload.get('iat')) is not int or type(payload.get('exp')) is not int
                or payload['exp'] <= now or payload['iat'] > now + 5
                or payload['exp'] - payload['iat'] != 60
                or not isinstance(payload.get('jti'), str)):
            raise Denied()
        return payload
    except (ValueError, TypeError, KeyError, AttributeError):
        raise Denied() from None


def control(action, extension, password=None, until=0, contact_user=None):
    payload = {'action': action, 'extension': extension, 'until': until}
    if contact_user is not None:
        payload['contact_user'] = contact_user
    if password is not None:
        payload['password'] = password
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(10)
        sock.connect('/run/ais-telephony/control.sock')
        sock.sendall(json.dumps(payload).encode() + b'\n')
        reply = sock.recv(1024)
        if json.loads(reply).get('ok') is not True:
            raise RuntimeError('SIP control failed')


class LeaseStore:
    def __init__(self, controller=control, clock=time.time):
        self.leases = {}
        self.lock = threading.Lock()
        self.controller = controller
        self.clock = clock

    def enable(self, claims):
        extension = claims['extension']
        with self.lock:
            existing = self.leases.get(extension)
            if existing and existing['until'] > self.clock():
                raise Denied('Телефон уже включён в другом окне.')
            password = secrets.token_urlsafe(32)
            lease = {'user_id': claims['user_id'], 'token': secrets.token_urlsafe(32),
                     'until': min(self.clock() + 60, claims['exp'])}
            # A new SIP password is granted only to the current lease.
            contact_user = extension + '-' + secrets.token_hex(16)
            self.controller('enable', extension, password, int(lease['until']), contact_user)
            self.leases[extension] = lease
            return {'user': extension, 'password': password, 'token': lease['token'], 'contact_uri': 'sip:' + contact_user + '@localhost;transport=ws'}

    def update(self, action, claims, token):
        extension = claims['extension']
        with self.lock:
            lease = self.leases.get(extension)
            if (not lease or lease['until'] <= self.clock()
                    or lease['user_id'] != claims['user_id']
                    or not hmac.compare_digest(str(token), lease['token'])):
                raise Denied('Сессия телефона завершена.')
            if action == 'disable':
                self.controller('disable', extension)
                del self.leases[extension]
            else:
                lease['until'] = min(self.clock() + 60, claims['exp'])
                self.controller('heartbeat', extension, until=int(lease['until']))
            return {'ok': True}

    def expire(self):
        with self.lock:
            for extension, lease in list(self.leases.items()):
                if lease['until'] <= self.clock():
                    self.controller('disable', extension)
                    del self.leases[extension]


def main():
    config = json.loads(Path('/etc/ais-telephony/config.json').read_text())
    if len(config['shared_secret']) < 32 or config['shared_secret'].startswith('REPLACE') or config['turn_secret'].startswith('COPY'):
        raise RuntimeError('Shared secret too short')
    store = LeaseStore()
    # Restart invalidates all old leases and their SIP credentials.
    for extension in sorted(EXTENSIONS):
        control('disable', extension)

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def valid_origin(self):
            return (self.headers.get('Host') == config['gateway_host']
                    and self.headers.get('Origin') == config['ais_origin'])

        def reply(self, status, payload=None):
            data = json.dumps(payload or {}).encode()
            self.send_response(status)
            if self.valid_origin():
                self.send_header('Access-Control-Allow-Origin', config['ais_origin'])
                self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type')
                self.send_header('Vary', 'Origin')
                self.send_header('Access-Control-Allow-Private-Network', 'true')
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_OPTIONS(self):
            self.reply(204 if self.valid_origin() else 403)

        def do_GET(self):
            self.reply(404)

        def do_POST(self):
            if (not self.valid_origin() or self.headers.get('Content-Type') != 'application/json'
                    or self.path not in ('/ais/enable', '/ais/heartbeat', '/ais/disable')):
                return self.reply(403)
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 8192:
                    return self.reply(400)
                payload = json.loads(self.rfile.read(size))
                claims = verify_ticket(payload.get('ticket'), config['shared_secret'])
                if self.path == '/ais/enable':
                    result = store.enable(claims)
                    username = str(int(time.time()) + 3600) + ':' + claims['extension']
                    credential = base64.b64encode(hmac.new(config['turn_secret'].encode(), username.encode(), hashlib.sha1).digest()).decode()
                    result.update({'wss': config['wss'], 'uri': 'sip:' + claims['extension'] + '@localhost',
                                   'pcConfig': {'iceTransportPolicy': 'relay', 'iceServers': [
                                       {'urls': config['turn_url'], 'username': username, 'credential': credential}]}})
                else:
                    result = store.update(self.path.split('/')[-1], claims, payload.get('token'))
                self.reply(200, result)
            except Denied as exc:
                self.reply(409, {'error': str(exc) or 'Доступ к телефонии не подтверждён.'})
            except (ValueError, TypeError, AttributeError):
                self.reply(400)
            except (OSError, RuntimeError):
                self.reply(503, {'error': 'Шлюз временно недоступен.'})

    def sweep():
        while True:
            time.sleep(5)
            try:
                store.expire()
            except (OSError, RuntimeError):
                pass  # Retried; dialplan also enforces the absolute lease deadline.
    threading.Thread(target=sweep, daemon=True).start()
    server = http.server.ThreadingHTTPServer(('0.0.0.0', config.get('port', 8444)), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(config['certificate'], config['private_key'])
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()

if __name__ == '__main__':
    main()
