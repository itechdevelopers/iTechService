#!/usr/bin/env python3
"""Run after developer approval on the existing local gateway VM as root.
Never prints passwords. Does not touch the production FreePBX automatically.
"""
import datetime, grp, json, os, re, secrets, shutil, subprocess
from pathlib import Path
EXTENSIONS = [str(n) for n in range(7771, 7781)]
ROOT = Path('/etc/asterisk')

def endpoint(extension):
    return f"""[{extension}]
type=endpoint
transport=transport-wss
context=ais-browser-outbound
disallow=all
allow=alaw,ulaw
webrtc=yes
media_encryption=dtls
dtls_auto_generate_cert=yes
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
auth=auth-{extension}
aors={extension}
callerid=AIS {extension} <{extension}>

[{extension}]
type=aor
max_contacts=1
remove_existing=yes
maximum_expiration=60
minimum_expiration=30
qualify_frequency=0

"""

def main():
    import argparse
    parser = argparse.ArgumentParser();parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    if not args.activate:
        print('Prepared extensions 7771-7780. Activation requires --activate after review.');return
    config = json.loads(Path('/etc/ais-telephony/config.json').read_text())
    assert len(config['shared_secret']) >= 32 and not config['shared_secret'].startswith('REPLACE')
    count = subprocess.check_output(['/usr/sbin/asterisk','-rx','core show channels count']).decode()
    assert '0 active channels' in count, 'Finish active calls first'
    pjsip = (ROOT/'pjsip.conf').read_text()
    assert 'ais-telephony-endpoints.conf' not in pjsip, 'Already provisioned: inspect before reapplying'
    backup = Path('/root/ais-telephony-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(mode=0o700)
    for name in ['pjsip.conf','extensions.conf','rtp.conf','cdr.conf','http.conf']:
        if (ROOT/name).exists():
            shutil.copy2(ROOT/name,backup/name);(backup/name).chmod(0o600)
    sections = re.split(r'(?m)(?=^\[)', pjsip)
    keep = []
    for section in sections:
        match = re.match(r'\[([^]]+)\]', section)
        if match and (match[1] in EXTENSIONS or match[1] in ['auth-' + e for e in EXTENSIONS]):continue
        keep.append(section)
    (ROOT/'pjsip.conf').write_text(''.join(keep) + '\n#include ais-telephony-endpoints.conf\n#include ais-telephony-auth.conf\n')
    (ROOT/'ais-telephony-endpoints.conf').write_text(''.join(endpoint(e) for e in EXTENSIONS))
    passwords = {e: secrets.token_urlsafe(32) for e in EXTENSIONS}
    state = Path('/var/lib/ais-telephony');state.mkdir(mode=0o700, exist_ok=True)
    (state/'auth.json').write_text(json.dumps({'passwords': passwords, 'contacts': {}}));(state/'auth.json').chmod(0o600)
    (ROOT/'ais-telephony-auth.conf').write_text(''.join('[auth-{}]\ntype=auth\nauth_type=userpass\nusername={}\npassword={}\n\n'.format(e,e,passwords[e]) for e in EXTENSIONS))
    for name in ['pjsip.conf','ais-telephony-auth.conf','ais-telephony-endpoints.conf']:
        (ROOT/name).chmod(0o640);os.chown(ROOT/name,0,grp.getgrnam('asterisk').gr_gid)
    extensions = (ROOT/'extensions.conf').read_text()
    # Replace only the pilot inbound context owned by this project.
    extensions = re.sub(r'(?ms)^\[from-pbx-pilot\]\n.*?(?=^\[|\Z)', '', extensions)
    (ROOT/'extensions.conf').write_text(extensions + '\n#include ais-telephony-dialplan.conf\n')
    (ROOT/'ais-telephony-dialplan.conf').write_text(Path('/opt/ais-telephony/gateway-dialplan.conf').read_text())
    (ROOT/'rtp.conf').write_text('[general]\nrtpstart=12000\nrtpend=12079\nicesupport=yes\n')
    cdr = '[general]\nenable=yes\nunanswered=yes\n[ csv ]\nusegmtime=yes\nloguniqueid=yes\nloguserfield=yes\n'
    (ROOT/'cdr.conf').write_text(cdr.replace('[ csv ]','[csv]'))
    http = (ROOT/'http.conf').read_text()
    for key, value in [('tlscertfile', config['certificate']), ('tlsprivatekey', config['private_key'])]:
        assert value.startswith('/etc/asterisk/keys/') and '\n' not in value
        http = re.sub(r'(?m)^' + key + r'=.*$', key + '=' + value, http)
    (ROOT/'http.conf').write_text(http)
    # Keep the existing VM ports/certificates. New HTTPS 8444 is automatically
    # forwarded by Lima to localhost:18444 when added to the VM configuration.
    subprocess.run(['systemctl','stop','ais-pilot-phone'],check=True)
    subprocess.run(['systemctl','disable','ais-pilot-phone'],check=True)
    subprocess.run(['systemctl','restart','asterisk'],check=True)
    subprocess.run(['/usr/sbin/asterisk','-rx','dialplan reload'],check=True)
    subprocess.run(['/usr/sbin/asterisk','-rx','module reload cdr_csv.so'],check=True)
    subprocess.run(['systemctl','enable','--now','ais-telephony-control','ais-telephony-gateway'],check=True)
    print('Gateway activated; backup:', backup)
if __name__ == '__main__':main()
